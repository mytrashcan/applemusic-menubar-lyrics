import Foundation
import LyricsCore

/// Cache scans open SQLite and memory-map payloads; both have blocked for a long time on a cold
/// cache, so they run on a dedicated queue and poll cancellation between rows.
actor CacheReader {
    private let cache = MusicCache()
    private let queue = BlockingQueue(label: "io.github.mytrashcan.MusicLyricsBar.cache", qos: .utility)

    func stamp() async throws -> MusicCacheStamp? {
        let cache = cache
        return try await queue.run { _ in cache.stamp() }
    }

    func lyrics(for track: Track) async throws -> Lyrics? {
        let cache = cache
        return try await queue.run { isCancelled in try cache.lyrics(for: track, isCancelled: isCancelled) }
    }
}
