import AppKit
import Carbon
import Testing
@testable import MusicLyricsBar

struct MusicEventTests {
    @Test func nestedPropertyReferenceUsesNativeObjectSpecifiers() throws {
        let track = try MusicEvents.property(0x7054726b)
        let title = try MusicEvents.property(0x706e616d, of: track)
        #expect(title.descriptorType == typeObjectSpecifier)
        #expect(title.forKeyword(AEKeyword(keyAEDesiredClass))?.typeCodeValue == typeProperty)
        #expect(title.forKeyword(AEKeyword(keyAEKeyForm))?.enumCodeValue == OSType(formPropertyID))
        #expect(title.forKeyword(AEKeyword(keyAEKeyData))?.typeCodeValue == 0x706e616d)
        #expect(title.forKeyword(AEKeyword(keyAEContainer))?.forKeyword(AEKeyword(keyAEKeyData))?.typeCodeValue == 0x7054726b)
    }

    @Test func extractsReplyValuesAndPreservesAutomationDenial() throws {
        let reply = NSAppleEventDescriptor.appleEvent(withEventClass: kCoreEventClass, eventID: kAEAnswer,
            targetDescriptor: nil, returnID: 0, transactionID: 0)
        reply.setParam(NSAppleEventDescriptor(double: 12.5), forKeyword: keyDirectObject)
        #expect(try MusicEvents.value(from: reply).doubleValue == 12.5)
        reply.setParam(NSAppleEventDescriptor(int32: -1743), forKeyword: keyErrorNumber)
        do {
            _ = try MusicEvents.value(from: reply)
            Issue.record("Automation denial must propagate")
        } catch MusicReaderError.permissionDenied { }
    }
}
