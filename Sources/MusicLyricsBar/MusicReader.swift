import AppKit
import LyricsCore

enum MusicReaderError: Error, LocalizedError {
    case permissionDenied
    case failed(Int)
    case invalidSample

    var errorDescription: String? {
        switch self {
        case .permissionDenied: "Music 자동화 권한이 필요합니다. 시스템 설정 → 개인정보 보호 및 보안 → 자동화를 확인해 주세요."
        case .failed(let code): "Music 재생 정보를 읽지 못했습니다 (\(code)). 다시 연결해 주세요."
        case .invalidSample: "Music에서 올바른 재생 정보를 받지 못했습니다."
        }
    }
}

/// Serial actor keeps synchronous Apple Events off the UI thread and prevents overlapping reads.
actor MusicReader {
    private var script: NSAppleScript?

    func sample() throws -> PlaybackSample? {
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty else {
            return nil
        }
        if script == nil { script = NSAppleScript(source: Self.source) }
        guard let script else { throw MusicReaderError.invalidSample }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            let code = (error[NSAppleScript.errorNumber] as? NSNumber)?.intValue ?? 0
            if code == -1743 { throw MusicReaderError.permissionDenied }
            throw MusicReaderError.failed(code)
        }
        if result.numberOfItems == 0 { return nil }
        guard result.numberOfItems == 7,
              let id = result.atIndex(1)?.stringValue,
              let title = result.atIndex(2)?.stringValue,
              let artist = result.atIndex(3)?.stringValue,
              let album = result.atIndex(4)?.stringValue,
              let duration = result.atIndex(5)?.doubleValue,
              let position = result.atIndex(6)?.doubleValue,
              let playing = result.atIndex(7)?.booleanValue,
              duration.isFinite, duration > 0, position.isFinite else {
            throw MusicReaderError.invalidSample
        }
        return PlaybackSample(
            track: Track(id: id, title: title, artist: artist, album: album, duration: duration),
            position: position, isPlaying: playing, sampledAt: ProcessInfo.processInfo.systemUptime
        )
    }

    static let source = """
    with timeout of 2 seconds
        tell application id "com.apple.Music"
            if player state is stopped then return {}
            set playbackTrack to current track
            set songID to persistent ID of playbackTrack
            set songName to name of playbackTrack
            set songArtist to artist of playbackTrack
            set songAlbum to album of playbackTrack
            set songDuration to duration of playbackTrack
            set songPosition to player position
            set songPlaying to (player state is playing)
            if persistent ID of current track is not songID then return {}
            return {songID, songName, songArtist, songAlbum, songDuration, songPosition, songPlaying}
        end tell
    end timeout
    """
}

actor CacheReader {
    private let cache = MusicCache()

    func lyrics(for track: Track) throws -> Lyrics? {
        try cache.lyrics(for: track)
    }
}
