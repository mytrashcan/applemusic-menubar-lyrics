import Foundation
import CSQLite

public enum MusicCacheError: Error, LocalizedError {
    case unavailable
    case unreadable

    public var errorDescription: String? {
        switch self {
        case .unavailable: "No Music lyrics cache yet. Open lyrics in Music first."
        case .unreadable: "Cannot read the Music cache. Check permissions or the cache format."
        }
    }
}

/// Opens only the response index and payloads. Never reads request/response headers,
/// account tokens, or the Music library database, and never writes to Apple's cache.
public struct MusicCache: Sendable {
    public let directory: URL
    private static let maximumPayloadSize = 8 * 1024 * 1024

    public init(directory: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Caches/com.apple.Music", isDirectory: true)) {
        self.directory = directory
    }

    public func lyrics(for track: Track) throws -> Lyrics? {
        let database = directory.appendingPathComponent("Cache.db")
        guard FileManager.default.fileExists(atPath: database.path) else { throw MusicCacheError.unavailable }
        var connection: OpaquePointer?
        guard sqlite3_open_v2(database.path, &connection, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            if let connection { sqlite3_close(connection) }
            throw MusicCacheError.unreadable
        }
        defer { sqlite3_close(connection) }
        sqlite3_busy_timeout(connection, 250)

        // Bound work on large caches. Missing or evicted payloads are ordinary cache misses.
        let sql = """
        SELECT d.isDataOnFS, d.receiver_data
        FROM cfurl_cache_response r JOIN cfurl_cache_receiver_data d USING(entry_ID)
        WHERE r.request_key LIKE '%lyrics%'
        ORDER BY r.time_stamp DESC, r.entry_ID DESC LIMIT 512
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK else {
            throw MusicCacheError.unreadable
        }
        defer { sqlite3_finalize(statement) }

        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_DONE { return nil }
            guard result == SQLITE_ROW else { throw MusicCacheError.unreadable }
            guard let payload = payload(from: statement),
                  let root = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
                  let songs = root["data"] as? [[String: Any]] else { continue }
            for song in songs {
                guard Self.matches(song, track: track),
                      let relationships = song["relationships"] as? [String: Any] else { continue }
                for key in ["syllable-lyrics", "lyrics"] {
                    guard let relationship = relationships[key] as? [String: Any],
                          let records = relationship["data"] as? [[String: Any]] else { continue }
                    for record in records {
                        guard let attributes = record["attributes"] as? [String: Any] else { continue }
                        for field in ["ttml", "ttmlLocalizations"] {
                            if let xml = attributes[field] as? String,
                               let lyrics = try? AppleTTMLParser.parse(xml) { return lyrics }
                        }
                    }
                }
            }
        }
    }

    private func payload(from statement: OpaquePointer?) -> Data? {
        let byteCount = Int(sqlite3_column_bytes(statement, 1))
        guard byteCount > 0, byteCount <= Self.maximumPayloadSize else { return nil }
        if sqlite3_column_int(statement, 0) == 0 {
            guard let bytes = sqlite3_column_blob(statement, 1) else { return nil }
            return Data(bytes: bytes, count: byteCount)
        }
        guard let nameBytes = sqlite3_column_text(statement, 1) else { return nil }
        let name = String(cString: nameBytes)
        guard !name.isEmpty, name != ".", name != "..", !name.contains("/"), !name.contains("\\") else { return nil }
        let folder = directory.appendingPathComponent("fsCachedData", isDirectory: true).resolvingSymlinksInPath()
        let file = folder.appendingPathComponent(name).resolvingSymlinksInPath()
        guard file.deletingLastPathComponent() == folder,
              let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size <= Self.maximumPayloadSize else { return nil }
        return try? Data(contentsOf: file, options: .mappedIfSafe)
    }

    private static func matches(_ song: [String: Any], track: Track) -> Bool {
        guard song["type"] as? String == "songs",
              let attributes = song["attributes"] as? [String: Any],
              let title = attributes["name"] as? String,
              let artist = attributes["artistName"] as? String,
              let milliseconds = attributes["durationInMillis"] as? Double,
              normalized(title) == normalized(track.title),
              normalized(artist) == normalized(track.artist),
              abs(milliseconds / 1000 - track.duration) <= 2 else { return false }
        if !track.album.isEmpty {
            guard let album = attributes["albumName"] as? String,
                  normalized(album) == normalized(track.album) else { return false }
        }
        return true
    }

    private static func normalized(_ value: String) -> String {
        value.precomposedStringWithCanonicalMapping
            .folding(options: [.caseInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
