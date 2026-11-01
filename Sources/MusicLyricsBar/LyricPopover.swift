import AppKit

/// Shows the current line under the icon while the menu bar item is reduced to its icon.
@MainActor
final class LyricPopover {
    static let padding: CGFloat = 12

    private let popover = NSPopover()
    private let title = NSTextField(labelWithString: "Music Lyrics Bar")
    private let preview = NSImageView()
    private let previewWidth: NSLayoutConstraint

    var isShown: Bool { popover.isShown }

    init(width: CGFloat) {
        title.font = .systemFont(ofSize: 11, weight: .medium)
        title.textColor = .secondaryLabelColor
        title.lineBreakMode = .byTruncatingTail
        title.setAccessibilityIdentifier("popoverTrack")
        preview.imageScaling = .scaleNone
        preview.imageAlignment = .alignLeft
        preview.contentTintColor = .labelColor
        preview.setAccessibilityIdentifier("popoverLyric")
        let stack = NSStackView(views: [title, preview])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: Self.padding, left: Self.padding, bottom: Self.padding, right: Self.padding)
        previewWidth = preview.widthAnchor.constraint(equalToConstant: width)
        let controller = NSViewController()
        controller.view = stack
        NSLayoutConstraint.activate([
            previewWidth,
            preview.heightAnchor.constraint(equalToConstant: NSStatusBar.system.thickness),
            title.widthAnchor.constraint(lessThanOrEqualTo: preview.widthAnchor)
        ])
        popover.contentViewController = controller
        popover.behavior = .transient
    }

    func toggle(relativeTo view: NSView) {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        popover.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
    }

    func close() {
        if popover.isShown { popover.performClose(nil) }
    }

    func setWidth(_ width: CGFloat) {
        previewWidth.constant = width
    }

    func update(title: String, image: NSImage?) {
        guard popover.isShown else { return }
        if self.title.stringValue != title { self.title.stringValue = title }
        if preview.image !== image { preview.image = image }
    }
}
