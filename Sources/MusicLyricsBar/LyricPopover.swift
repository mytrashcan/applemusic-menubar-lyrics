import AppKit

/// Shows the current line under the icon while the menu bar item is reduced to its icon.
@MainActor
final class LyricPopover {
    static let padding: CGFloat = 12

    private let popover = NSPopover()
    private let title = NSTextField(labelWithString: "Music Lyrics Bar")
    private let preview = NSImageView()
    private let stack: NSStackView
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
        stack = NSStackView(views: [title, preview])
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
        fitContent()
    }

    /// A popover takes its size from `contentSize`, not from the stack's constraints; left at
    /// zero it opens as an empty bubble.
    private func fitContent() {
        stack.layoutSubtreeIfNeeded()
        let fitting = stack.fittingSize
        // The stack's fitting width drops its trailing inset; the preview plus both insets is the floor.
        let size = NSSize(width: max(fitting.width, previewWidth.constant + 2 * Self.padding), height: fitting.height)
        stack.frame = NSRect(origin: .zero, size: size)
        popover.contentSize = size
    }

    /// The popover's content size, for tests.
    var contentSize: NSSize { popover.contentSize }

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
        fitContent()
    }

    func update(title: String, image: NSImage?) {
        guard popover.isShown else { return }
        if self.title.stringValue != title { self.title.stringValue = title }
        if preview.image !== image { preview.image = image }
    }
}
