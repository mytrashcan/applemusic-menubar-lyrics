import Foundation
import Testing
import CSQLite
@testable import LyricsCore

final class MusicCacheTests {
    private let directory: URL
    private let track = Track(id: "persistent-test", title: "Example", artist: "Artist", album: "Album", duration: 30)

    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("fsCachedData"),
                                              withIntermediateDirectories: true)
        try execute("""
        CREATE TABLE cfurl_cache_response(entry_ID INTEGER PRIMARY KEY, request_key TEXT, time_stamp TEXT);
        CREATE TABLE cfurl_cache_receiver_data(entry_ID INTEGER PRIMARY KEY, isDataOnFS INTEGER, receiver_data BLOB);
        """)
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    @Test func testReadsInlineLyricsWithoutChangingDatabase() throws {
        try insert(id: 1, data: payload())
        let database = directory.appendingPathComponent("Cache.db")
        let before = try Data(contentsOf: database)
        #expect(try MusicCache(directory: directory).lyrics(for: track)?.lines.first?.text == "Synthetic text")
        #expect(try Data(contentsOf: database) == before)
    }

    @Test func testReadsFilePayloadAndSkipsEvictedAndMalformedEntries() throws {
        try Data(payload()).write(to: directory.appendingPathComponent("fsCachedData/valid"))
        try insert(id: 1, data: Data("valid".utf8), file: true)
        try insert(id: 2, data: Data("evicted".utf8), file: true)
        try insert(id: 3, data: Data("invalid JSON".utf8))
        #expect(try MusicCache(directory: directory).lyrics(for: track)?.lines.count == 1)
    }

    @Test func testRejectsOtherArtistsAlbumsAndVersions() throws {
        try insert(id: 1, data: payload(artist: "Other artist"))
        try insert(id: 2, data: payload(album: "Live album"))
        try insert(id: 3, data: payload(duration: 50_000))
        #expect(try MusicCache(directory: directory).lyrics(for: track) == nil)
    }

    @Test func testRetriesMissAfterMusicPopulatesCache() throws {
        let cache = MusicCache(directory: directory)
        #expect(try cache.lyrics(for: track) == nil)
        try insert(id: 1, data: payload())
        #expect(try cache.lyrics(for: track) != nil)
    }

    @Test func testRejectsTraversalAndExternalSymlinkPayloads() throws {
        let external = directory.appendingPathComponent("outside.json")
        try payload().write(to: external)
        try FileManager.default.createSymbolicLink(at: directory.appendingPathComponent("fsCachedData/link"),
                                                  withDestinationURL: external)
        try insert(id: 1, data: Data("../outside.json".utf8), file: true)
        try insert(id: 2, data: Data("link".utf8), file: true)
        #expect(try MusicCache(directory: directory).lyrics(for: track) == nil)
    }

    @Test func testReportsMissingAndUnsupportedDatabase() throws {
        #expect(throws: (any Error).self) { try MusicCache(directory: directory.appendingPathComponent("missing")).lyrics(for: track) }
        try execute("DROP TABLE cfurl_cache_receiver_data")
        #expect(throws: (any Error).self) { try MusicCache(directory: directory).lyrics(for: track) }
    }

    private func payload(artist: String = "Artist", album: String = "Album", duration: Double = 30_000) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["data": [[
            "id": "123", "type": "songs",
            "attributes": ["name": "Example", "artistName": artist, "albumName": album, "durationInMillis": duration],
            "relationships": ["syllable-lyrics": ["data": [["attributes": [
                "ttmlLocalizations": "<tt><body><div><p begin=\"1\" end=\"3\">Synthetic text</p></div></body></tt>"
            ]]]]]
        ]]])
    }

    private func insert(id: Int, data: Data, file: Bool = false) throws {
        let hex = data.map { String(format: "%02x", $0) }.joined()
        try execute("""
        INSERT INTO cfurl_cache_response VALUES(\(id), 'https://example.invalid/songs?include=lyrics', '2026-01-01');
        INSERT INTO cfurl_cache_receiver_data VALUES(\(id), \(file ? 1 : 0), X'\(hex)');
        """)
    }

    private func execute(_ sql: String) throws {
        var connection: OpaquePointer?
        #expect(sqlite3_open(directory.appendingPathComponent("Cache.db").path, &connection) == SQLITE_OK)
        defer { sqlite3_close(connection) }
        guard sqlite3_exec(connection, sql, nil, nil, nil) == SQLITE_OK else {
            throw NSError(domain: "SyntheticCache", code: 1)
        }
    }
}

struct CacheCancellationTests {
    @Test func cancelledReadDoesNotOpenTheDatabase() async {
        let cache = MusicCache(directory: URL(fileURLWithPath: "/nonexistent-music-cache"))
        let track = Track(id: "cancelled", title: "Synthetic", artist: "Test", album: "", duration: 30)
        let task = Task {
            while !Task.isCancelled { await Task.yield() }
            #expect(throws: CancellationError.self) { try cache.lyrics(for: track) }
        }
        task.cancel()
        await task.value
    }
}
