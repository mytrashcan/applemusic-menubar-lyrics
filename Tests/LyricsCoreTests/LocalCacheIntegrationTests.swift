import Foundation
import Testing
import CSQLite
@testable import LyricsCore

struct LocalCacheIntegrationTests {
    /// Opt-in only: reads local metadata in memory and reports counts, never lyrics or titles.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["MUSIC_LYRICS_CACHE_INTEGRATION"] == "1"))
    func parsesExistingMusicCache() throws {
        let cache = MusicCache()
        var connection: OpaquePointer?
        try #require(sqlite3_open_v2(cache.directory.appendingPathComponent("Cache.db").path,
                                    &connection, SQLITE_OPEN_READONLY, nil) == SQLITE_OK)
        defer { sqlite3_close(connection) }
        var statement: OpaquePointer?
        let sql = """
        SELECT d.isDataOnFS, d.receiver_data FROM cfurl_cache_response r
        JOIN cfurl_cache_receiver_data d USING(entry_ID)
        WHERE r.request_key LIKE '%lyrics%' ORDER BY r.entry_ID DESC LIMIT 20
        """
        try #require(sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK)
        defer { sqlite3_finalize(statement) }
        var verified = 0
        while sqlite3_step(statement) == SQLITE_ROW {
            let data: Data
            if sqlite3_column_int(statement, 0) == 1 {
                guard let text = sqlite3_column_text(statement, 1) else { continue }
                let name = String(cString: text)
                guard !name.contains("/"), name != "..",
                      let payload = try? Data(contentsOf: cache.directory.appendingPathComponent("fsCachedData/" + name)) else { continue }
                data = payload
            } else {
                guard let bytes = sqlite3_column_blob(statement, 1) else { continue }
                data = Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, 1)))
            }
            guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let songs = root["data"] as? [[String: Any]] else { continue }
            for song in songs {
                guard song["type"] as? String == "songs",
                      let attributes = song["attributes"] as? [String: Any],
                      let title = attributes["name"] as? String,
                      let artist = attributes["artistName"] as? String,
                      let album = attributes["albumName"] as? String,
                      let duration = attributes["durationInMillis"] as? Double else { continue }
                let track = Track(id: "local-check", title: title, artist: artist, album: album, duration: duration / 1000)
                if let lyrics = try cache.lyrics(for: track) {
                    #expect(!lyrics.lines.isEmpty)
                    #expect(lyrics.lines.allSatisfy { $0.start >= 0 && $0.end > $0.start })
                    verified += 1
                }
            }
        }
        #expect(verified > 0, "Open a song's lyrics in Music to populate the local cache first.")
        print("Verified \(verified) cached song responses; no lyrics exported.")
    }
}
