import AppKit
import Testing
@testable import MusicLyricsBar

struct StatusWindowTests {
    @MainActor @Test func closingReleasesTheControllerWindowAndViews() {
        _ = NSApplication.shared
        weak var closedWindow: NSWindow?
        weak var closedContent: NSView?
        weak var closedController: StatusWindow?
        autoreleasepool {
            let target = NSObject()
            let unusedAction = #selector(NSObject.description)
            var controller: StatusWindow? = StatusWindow(target: target, connect: unusedAction,
                reload: unusedAction, openMusic: unusedAction, changeWidth: unusedAction)
            closedController = controller
            closedWindow = controller?.window
            closedContent = controller?.window?.contentView
            controller?.onClose = { controller = nil }
            controller?.close()
            #expect(controller == nil)
        }
        #expect(closedController == nil)
        #expect(closedWindow == nil)
        #expect(closedContent == nil)
    }
}
