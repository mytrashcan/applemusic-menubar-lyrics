import AppKit
import Carbon
import LyricsCore
import os

enum MusicReaderError: Error, LocalizedError {
    case permissionDenied
    case failed(Int)
    case invalidSample

    var errorDescription: String? {
        switch self {
        case .permissionDenied: "Music automation permission is required. Check System Settings → Privacy & Security → Automation."
        case .failed(let code): "Could not read Music playback information (\(code)). Please reconnect."
        case .invalidSample: "Music returned invalid playback information."
        }
    }
}

/// Four-character codes from Music's installed scripting dictionary.
enum MusicProperty {
    static let playerState = code("pPlS")
    static let currentTrack = code("pTrk")
    static let persistentID = code("pPIS")
    static let name = code("pnam")
    static let artist = code("pArt")
    static let album = code("pAlb")
    static let duration = code("pDur")
    static let position = code("pPos")
    static let playingState = code("kPSP")
    static let stoppedState = code("kPSS")

    static func code(_ text: StaticString) -> OSType {
        text.withUTF8Buffer { bytes in
            precondition(bytes.count == 4, "Four-character code expected")
            return bytes.reduce(OSType(0)) { $0 << 8 | OSType($1) }
        }
    }
}

/// Reads Music's scripting properties directly, without loading the AppleScript runtime.
/// Each Apple Event blocks its thread for up to the reply timeout, so reads run on a
/// dedicated queue rather than the cooperative pool. The actor serializes callers and
/// remembers the last track so unchanged metadata is not re-read every poll.
actor MusicReader {
    private static let logger = Logger(subsystem: "io.github.mytrashcan.MusicLyricsBar", category: "playback")
    private let queue = BlockingQueue(label: "io.github.mytrashcan.MusicLyricsBar.music-events", qos: .userInitiated)
    private var cachedTrack: Track?

    func sample(refreshMetadata: Bool = false) async throws -> PlaybackSample? {
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: MusicEvents.bundleIdentifier).isEmpty else {
            cachedTrack = nil
            return nil
        }
        if refreshMetadata { cachedTrack = nil }
        let knownTrack = cachedTrack
        do {
            let sample = try await queue.run { _ in try MusicEvents.readSample(knownTrack: knownTrack) }
            cachedTrack = sample?.track
            return sample
        } catch {
            cachedTrack = nil
            Self.logger.error("Playback read failed: \(String(describing: error), privacy: .public)")
            throw error
        }
    }
}

enum MusicEvents {
    static let bundleIdentifier = "com.apple.Music"
    private static let replyTimeout: TimeInterval = 2

    /// One consistent snapshot of playback. Returns nil when Music is stopped or when the
    /// track changed between reads, so a mixed snapshot never reaches the display.
    static func readSample(knownTrack: Track?) throws -> PlaybackSample? {
        try autoreleasepool {
            let target = NSAppleEventDescriptor(bundleIdentifier: bundleIdentifier)
            let state = try read(MusicProperty.playerState, target: target).enumCodeValue
            guard state != MusicProperty.stoppedState else { return nil }
            let currentTrack = try property(MusicProperty.currentTrack)
            let id = try string(MusicProperty.persistentID, of: currentTrack, target: target)
            let track: Track
            if let knownTrack, knownTrack.id == id {
                track = knownTrack
            } else {
                track = Track(id: id,
                              title: try string(MusicProperty.name, of: currentTrack, target: target),
                              artist: try string(MusicProperty.artist, of: currentTrack, target: target),
                              album: try string(MusicProperty.album, of: currentTrack, target: target),
                              duration: try number(MusicProperty.duration, of: currentTrack, target: target))
            }
            let position = try number(MusicProperty.position, target: target)
            guard try string(MusicProperty.persistentID, of: currentTrack, target: target) == id,
                  track.duration > 0 else { return nil }
            return PlaybackSample(track: track, position: position, isPlaying: state == MusicProperty.playingState,
                                  sampledAt: ProcessInfo.processInfo.systemUptime)
        }
    }

    private static func string(_ code: OSType, of container: NSAppleEventDescriptor = .null(),
                               target: NSAppleEventDescriptor) throws -> String {
        guard let value = try read(code, of: container, target: target).stringValue else { throw MusicReaderError.invalidSample }
        return value
    }

    private static func number(_ code: OSType, of container: NSAppleEventDescriptor = .null(),
                               target: NSAppleEventDescriptor) throws -> Double {
        guard let number = try read(code, of: container, target: target).coerce(toDescriptorType: typeIEEE64BitFloatingPoint),
              number.doubleValue.isFinite else { throw MusicReaderError.invalidSample }
        return number.doubleValue
    }

    private static func read(_ code: OSType, of container: NSAppleEventDescriptor = .null(),
                             target: NSAppleEventDescriptor) throws -> NSAppleEventDescriptor {
        let event = NSAppleEventDescriptor.appleEvent(withEventClass: kAECoreSuite, eventID: kAEGetData,
            targetDescriptor: target, returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID))
        event.setParam(try property(code, of: container), forKeyword: keyDirectObject)
        do {
            return try value(from: event.sendEvent(options: [.waitForReply, .neverInteract, .dontRecord], timeout: replyTimeout))
        } catch let error as MusicReaderError {
            throw error
        } catch {
            throw readerError(code: (error as NSError).code)
        }
    }

    static func property(_ code: OSType, of container: NSAppleEventDescriptor = .null()) throws -> NSAppleEventDescriptor {
        let specifier = NSAppleEventDescriptor.record()
        specifier.setDescriptor(NSAppleEventDescriptor(typeCode: typeProperty), forKeyword: AEKeyword(keyAEDesiredClass))
        specifier.setDescriptor(NSAppleEventDescriptor(enumCode: OSType(formPropertyID)), forKeyword: AEKeyword(keyAEKeyForm))
        specifier.setDescriptor(NSAppleEventDescriptor(typeCode: code), forKeyword: AEKeyword(keyAEKeyData))
        specifier.setDescriptor(container, forKeyword: AEKeyword(keyAEContainer))
        // Coercing a record to an object specifier gives Music the same reference
        // shape that its scripting dictionary defines, without compiling a script.
        guard let reference = specifier.coerce(toDescriptorType: typeObjectSpecifier) else { throw MusicReaderError.invalidSample }
        return reference
    }

    static func value(from reply: NSAppleEventDescriptor) throws -> NSAppleEventDescriptor {
        if let error = reply.paramDescriptor(forKeyword: keyErrorNumber), error.int32Value != 0 {
            throw readerError(code: Int(error.int32Value))
        }
        guard let value = reply.paramDescriptor(forKeyword: keyDirectObject) else { throw MusicReaderError.invalidSample }
        return value
    }

    private static func readerError(code: Int) -> MusicReaderError {
        code == Int(errAEEventNotPermitted) ? .permissionDenied : .failed(code)
    }
}
