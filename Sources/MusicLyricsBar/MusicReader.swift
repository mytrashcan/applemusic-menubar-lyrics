import AppKit
import Carbon
import LyricsCore

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

/// Read Music's scripting properties directly, without loading the AppleScript runtime.
/// Property codes come from Music's installed scripting dictionary.
actor MusicReader {
    private var cachedTrack: Track?

    func sample(refreshMetadata: Bool = false) throws -> PlaybackSample? {
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty else {
            cachedTrack = nil
            return nil
        }
        if refreshMetadata { cachedTrack = nil }
        return try autoreleasepool {
            let state = try readProperty(0x70506c53).enumCodeValue // pPlS
            guard state != 0x6b505353 else { cachedTrack = nil; return nil } // kPSS
            let currentTrack = try MusicEvents.property(0x7054726b) // pTrk
            let id = try stringProperty(0x70504953, of: currentTrack) // pPIS
            let track: Track
            if let cachedTrack, cachedTrack.id == id {
                track = cachedTrack
            } else {
                track = Track(id: id,
                    title: try stringProperty(0x706e616d, of: currentTrack), // pnam
                    artist: try stringProperty(0x70417274, of: currentTrack), // pArt
                    album: try stringProperty(0x70416c62, of: currentTrack), // pAlb
                    duration: try numberProperty(0x70447572, of: currentTrack)) // pDur
            }
            let position = try numberProperty(0x70506f73) // pPos
            // Reject a mixed snapshot if playback changed tracks during the reads.
            guard try stringProperty(0x70504953, of: currentTrack) == id,
                  track.duration > 0 else { return nil }
            cachedTrack = track
            return PlaybackSample(track: track, position: position, isPlaying: state == 0x6b505350,
                                  sampledAt: ProcessInfo.processInfo.systemUptime) // kPSP
        }
    }

    private func stringProperty(_ code: OSType, of container: NSAppleEventDescriptor = .null()) throws -> String {
        guard let value = try readProperty(code, of: container).stringValue else { throw MusicReaderError.invalidSample }
        return value
    }

    private func numberProperty(_ code: OSType, of container: NSAppleEventDescriptor = .null()) throws -> Double {
        guard let number = try readProperty(code, of: container).coerce(toDescriptorType: typeIEEE64BitFloatingPoint),
              number.doubleValue.isFinite else { throw MusicReaderError.invalidSample }
        return number.doubleValue
    }

    private func readProperty(_ code: OSType, of container: NSAppleEventDescriptor = .null()) throws -> NSAppleEventDescriptor {
        let event = NSAppleEventDescriptor.appleEvent(withEventClass: kAECoreSuite, eventID: kAEGetData,
            targetDescriptor: NSAppleEventDescriptor(bundleIdentifier: "com.apple.Music"),
            returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
        event.setParam(try MusicEvents.property(code, of: container), forKeyword: keyDirectObject)
        do {
            return try MusicEvents.value(from: event.sendEvent(options: [.waitForReply, .neverInteract, .dontRecord], timeout: 2))
        } catch let error as MusicReaderError { throw error }
        catch {
            let code = (error as NSError).code
            if code == -1743 { throw MusicReaderError.permissionDenied }
            throw MusicReaderError.failed(code)
        }
    }
}

enum MusicEvents {
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
            if error.int32Value == -1743 { throw MusicReaderError.permissionDenied }
            throw MusicReaderError.failed(Int(error.int32Value))
        }
        guard let value = reply.paramDescriptor(forKeyword: keyDirectObject) else { throw MusicReaderError.invalidSample }
        return value
    }
}

actor CacheReader {
    private let cache = MusicCache()

    func lyrics(for track: Track) throws -> Lyrics? {
        try Task.checkCancellation()
        return try cache.lyrics(for: track)
    }
}
