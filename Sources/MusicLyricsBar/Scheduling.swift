import Foundation
import LyricsCore

/// Decides when the next playback read happens and coalesces requests that arrive while one
/// is in flight. Pure state with no timers, so the policy is unit-testable.
struct PollScheduler: Equatable {
    enum Next: Equatable {
        case pollNow
        case wait(TimeInterval)
    }

    static let playingInterval: TimeInterval = 0.5
    static let pausedInterval: TimeInterval = 2
    static let idleInterval: TimeInterval = 10
    static let failureInterval: TimeInterval = 0.5
    static let maximumFailureInterval: TimeInterval = 10

    private(set) var isPolling = false
    private var pending = false
    private var pendingMetadata = false
    private var consecutiveFailures = 0

    /// Returns whether the read that starts now should refresh track metadata, or nil when a
    /// read is already in flight. A coalesced request is served as soon as that read finishes.
    mutating func request(refreshMetadata: Bool) -> Bool? {
        pendingMetadata = pendingMetadata || refreshMetadata
        guard !isPolling else {
            pending = true
            return nil
        }
        isPolling = true
        pending = false
        defer { pendingMetadata = false }
        return pendingMetadata
    }

    /// Notifications wake paused or stopped playback immediately; these low-rate fallbacks also
    /// recover if Music omits a notification. Repeated failures back off instead of spinning.
    mutating func finish(sample: PlaybackSample?, failed: Bool) -> Next {
        isPolling = false
        consecutiveFailures = failed ? consecutiveFailures + 1 : 0
        if pending { return .pollNow }
        if failed {
            let backoff = Self.failureInterval * pow(2, Double(consecutiveFailures - 1))
            return .wait(min(Self.maximumFailureInterval, backoff))
        }
        guard let sample else { return .wait(Self.idleInterval) }
        return .wait(sample.isPlaying ? Self.playingInterval : Self.pausedInterval)
    }

    mutating func reset() {
        self = PollScheduler()
    }
}

/// Avoids rescanning the Music cache every few seconds while a song has no cached lyrics.
/// After a miss, a full scan runs again only when the cache files changed or a long safety
/// interval passed; in between, only a cheap file stamp is read.
struct CacheRescanPolicy: Equatable {
    static let probeInterval: TimeInterval = 3
    static let fullScanInterval: TimeInterval = 60

    private var missStamp: MusicCacheStamp?
    private var lastScan: TimeInterval = -.infinity

    func shouldScan(stamp: MusicCacheStamp?, now: TimeInterval) -> Bool {
        lastScan == -.infinity || stamp != missStamp || now - lastScan >= Self.fullScanInterval
    }

    mutating func recordMiss(stamp: MusicCacheStamp?, now: TimeInterval) {
        missStamp = stamp
        lastScan = now
    }

    mutating func reset() {
        self = CacheRescanPolicy()
    }
}
