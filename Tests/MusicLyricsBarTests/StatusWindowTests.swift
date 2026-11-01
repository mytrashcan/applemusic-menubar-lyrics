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
                reload: unusedAction, openMusic: unusedAction, changeWidth: unusedAction, width: .compact)
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

struct LyricPopoverTests {
    @MainActor @Test func sizesItsContentToThePreviewWidth() {
        _ = NSApplication.shared
        let popover = LyricPopover(width: 240)
        #expect(popover.contentSize.width >= 240 + 2 * LyricPopover.padding)
        #expect(popover.contentSize.height > NSStatusBar.system.thickness)
        popover.setWidth(600)
        #expect(popover.contentSize.width >= 600 + 2 * LyricPopover.padding)
    }
}
