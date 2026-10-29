import Foundation

public struct Track: Equatable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let artist: String
    public let album: String
    public let duration: TimeInterval

    public init(id: String, title: String, artist: String, album: String, duration: TimeInterval) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
    }
}

public struct LyricLine: Equatable, Sendable {
    public let start: TimeInterval
    public let end: TimeInterval
    public let text: String

    public init(start: TimeInterval, end: TimeInterval, text: String) {
        self.start = start
        self.end = end
        self.text = text
    }
}

public struct Lyrics: Equatable, Sendable {
    public let lines: [LyricLine]

    public init(lines: [LyricLine]) {
        self.lines = lines.sorted { $0.start < $1.start }
    }

    /// End-exclusive intervals avoid keeping an old line through an instrumental gap.
    /// Overlapping duet lines remain visible together in source order.
    public func activeLines(at position: TimeInterval) -> [LyricLine] {
        guard position.isFinite, position >= 0 else { return [] }
        return lines.filter { $0.start <= position && position < $0.end }
    }
}

public struct PlaybackSample: Sendable {
    public let track: Track
    public let position: TimeInterval
    public let isPlaying: Bool
    public let sampledAt: TimeInterval

    public init(track: Track, position: TimeInterval, isPlaying: Bool, sampledAt: TimeInterval) {
        self.track = track
        self.position = position
        self.isPlaying = isPlaying
        self.sampledAt = sampledAt
    }

    /// Use system uptime, not wall time. Stop extrapolating after a stalled reader.
    public func position(at uptime: TimeInterval) -> TimeInterval {
        let elapsed = isPlaying ? min(1.5, max(0, uptime - sampledAt)) : 0
        return min(track.duration, max(0, position + elapsed))
    }
}
