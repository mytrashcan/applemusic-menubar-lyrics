import AppKit
import os

/// A click-through strip inside the menu bar's left region, right after the frontmost app's
/// menu titles, showing the same rendered lyric image. Opt-in; it joins every Space and
/// full-screen app, and hides while the menu bar itself is hidden.
@MainActor
final class FloatingLyricsPanel {
    /// Pure placement so the geometry is unit-testable without screens.
    struct Placement: Equatable {
        static let inset: CGFloat = 4
        /// Space kept after the last menu title and before the notch or status area.
        static let gap: CGFloat = 12
        static let margin: CGFloat = 8
        /// Below this the strip would show only the note icon; it hides instead.
        static let minimumWidth: CGFloat = 80
        /// Menu bar height assumed on displays without a notch while the bar is hidden.
        static let fallbackMenuBarHeight: CGFloat = 24

        /// The menu bar strip left of the notch (`auxiliaryTopLeftArea`), or on other displays
        /// the strip from the left edge up to the status area.
        var region: CGRect
        /// Screen x where the frontmost app's last menu title ends; nil without Accessibility access.
        var titlesRightEdge: CGFloat?
        var contentWidth: CGFloat
        var contentHeight: CGFloat

        /// Without Accessibility access the titles are unknown. Typical menus end before the
        /// middle of the region, so start there, or later when the content fits right-aligned.
        var fallbackStart: CGFloat {
            max(region.midX, region.maxX - Self.margin - contentWidth - 2 * Self.inset)
        }

        /// The panel frame, or nil when the room after the titles is too small to be useful.
        var frame: CGRect? {
            let height = min(contentHeight + 2 * Self.inset, region.height)
            let start = titlesRightEdge.map { max(region.minX, $0 + Self.gap) } ?? fallbackStart
            let width = min(contentWidth + 2 * Self.inset, region.maxX - Self.margin - start)
            guard width >= Self.minimumWidth else { return nil }
            return CGRect(x: start.rounded(), y: (region.midY - height / 2).rounded(), width: width.rounded(), height: height)
        }

        /// The usable strip: the area left of the notch, or else the menu bar from the left
        /// edge to the status area (our own item at best; the middle of the screen if unknown).
        static func region(screenFrame: CGRect, visibleFrame: CGRect, leftArea: CGRect?, statusAreaMinX: CGFloat?) -> CGRect {
            if let leftArea { return leftArea }
            let height = max(Self.fallbackMenuBarHeight, screenFrame.maxY - visibleFrame.maxY)
            let end = statusAreaMinX.map { min($0, screenFrame.maxX) } ?? screenFrame.midX
            return CGRect(x: screenFrame.minX, y: screenFrame.maxY - height, width: max(0, end - screenFrame.minX), height: height)
        }

        init(screen: NSScreen, statusAreaMinX: CGFloat?, titlesRightEdge: CGFloat?, contentWidth: CGFloat, contentHeight: CGFloat) {
            region = Self.region(screenFrame: screen.frame, visibleFrame: screen.visibleFrame,
                                 leftArea: screen.auxiliaryTopLeftArea, statusAreaMinX: statusAreaMinX)
            self.titlesRightEdge = titlesRightEdge
            self.contentWidth = contentWidth
            self.contentHeight = contentHeight
        }

        init(region: CGRect, titlesRightEdge: CGFloat?, contentWidth: CGFloat, contentHeight: CGFloat) {
            self.region = region
            self.titlesRightEdge = titlesRightEdge
            self.contentWidth = contentWidth
            self.contentHeight = contentHeight
        }
    }

    private static let logger = Logger(subsystem: "io.github.mytrashcan.MusicLyricsBar", category: "floating-bar")
    private let panel: NSPanel
    private let preview = NSImageView()
    private var observer: NSObjectProtocol?
    /// The width the user chose; the strip narrows when the menu titles leave less room.
    private(set) var preferredWidth: CGFloat
    /// The width the rendered image should have: the strip's content area after layout.
    private(set) var contentWidth: CGFloat
    private var isEnabled = false
    private var isSuppressed = false
    private var lastPlacement: Placement?
    /// Called on the main actor when the strip starts or stops being drawn on screen.
    var onVisibilityChange: (() -> Void)?

    var isVisible: Bool { panel.isVisible }
    /// Rendering is wasted while the strip is hidden or fully covered.
    var wantsUpdates: Bool { panel.isVisible && panel.occlusionState.contains(.visible) }

    init(width: CGFloat) {
        preferredWidth = width
        contentWidth = width
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: width, height: NSStatusBar.system.thickness),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.ignoresMouseEvents = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.isExcludedFromWindowsMenu = true
        panel.setAccessibilityIdentifier("MusicLyricsBar.FloatingLyrics")
        let background = NSVisualEffectView()
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        // The menu bar's own text color follows the wallpaper; a fixed dark pill with light
        // text stays readable in either appearance.
        background.appearance = NSAppearance(named: .darkAqua)
        background.wantsLayer = true
        background.layer?.cornerRadius = 6
        background.layer?.masksToBounds = true
        preview.imageScaling = .scaleNone
        preview.imageAlignment = .alignLeft
        preview.contentTintColor = .labelColor
        preview.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(preview)
        NSLayoutConstraint.activate([
            preview.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: Placement.inset),
            preview.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -Placement.inset),
            preview.topAnchor.constraint(equalTo: background.topAnchor, constant: Placement.inset),
            preview.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -Placement.inset)
        ])
        panel.contentView = background
        observer = NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification,
                                                          object: panel, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.onVisibilityChange?() }
        }
    }

    /// Hides the strip and stops observing. The owner calls this before letting go.
    func invalidate() {
        isEnabled = false
        orderOut()
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        onVisibilityChange = nil
    }

    /// Turns the strip on; it appears once `layout` finds room for it.
    func enable(width: CGFloat) {
        isEnabled = true
        preferredWidth = width
    }

    /// Hidden while the menu bar is (full screen, auto-hide), shown again when it returns.
    func setSuppressed(_ suppressed: Bool) {
        guard isSuppressed != suppressed else { return }
        isSuppressed = suppressed
        if suppressed { orderOut() } else { orderFrontIfPlaced() }
    }

    /// Places the strip for the given screen and menu titles; hides it when there is no room.
    func layout(on screen: NSScreen?, statusAreaMinX: CGFloat?, titlesRightEdge: CGFloat?) {
        guard isEnabled, let screen = screen ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let placement = Placement(screen: screen, statusAreaMinX: statusAreaMinX, titlesRightEdge: titlesRightEdge,
                                  contentWidth: preferredWidth, contentHeight: NSStatusBar.system.thickness)
        guard placement != lastPlacement else {
            orderFrontIfPlaced()
            return
        }
        lastPlacement = placement
        guard let frame = placement.frame else {
            Self.logger.info("Floating lyrics bar has no room after the menu titles (titles end at \(Int(titlesRightEdge ?? -1), privacy: .public), region to \(Int(placement.region.maxX), privacy: .public))")
            orderOut()
            return
        }
        contentWidth = frame.width - 2 * Placement.inset
        if panel.frame != frame { panel.setFrame(frame, display: true) }
        Self.logger.info("Floating lyrics bar placed at \(NSStringFromRect(frame), privacy: .public) (titles end at \(Int(titlesRightEdge ?? -1), privacy: .public), \(titlesRightEdge == nil ? "fallback" : "measured", privacy: .public))")
        orderFrontIfPlaced()
    }

    func update(image: NSImage?) {
        guard wantsUpdates, preview.image !== image else { return }
        preview.image = image
    }

    private func orderFrontIfPlaced() {
        guard isEnabled, !isSuppressed, lastPlacement?.frame != nil, !panel.isVisible else { return }
        panel.orderFrontRegardless()
        onVisibilityChange?()
    }

    private func orderOut() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        preview.image = nil
        onVisibilityChange?()
    }
}
