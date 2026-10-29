import AppKit
import Testing
@testable import MusicLyricsBar

struct MusicScriptTests {
    /// Compile against Music's installed scripting dictionary without executing Apple Events.
    @MainActor @Test func playbackScriptCompiles() throws {
        let script = try #require(NSAppleScript(source: MusicReader.source))
        var error: NSDictionary?
        #expect(script.compileAndReturnError(&error), "Music playback script must compile.")
        #expect(error == nil)
    }
}
