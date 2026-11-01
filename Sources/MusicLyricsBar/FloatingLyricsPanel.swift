import AppKit
import os

/// A click-through strip just below the menu bar that shows the same rendered lyric image.
/// Opt-in; it joins every Space and full-screen app, so lyrics stay visible when the menu bar
/// item cannot.
@MainActor
final class FloatingLyricsPanel {
    /// Pure placement so the geometry is unit-testable without screens.
    struct Placement: Equatable {
        static let inset: CGFloat = 4
        static let horizontalMargin: CGFloat = 8
        static let verticalMargin: CGFloat = 6

        var screenFrame: CGRect
        var visibleFrame: CGRect
        var safeAreaTop: CGFloat
        /// `auxiliaryTopLeftArea.maxX` and `auxiliaryTopRightArea.minX` on a notched display.
        var notch: ClosedRange<CGFloat>?
        var contentWidth: CGFloat
        var contentHeight: CGFloat

        var size: CGSize {
            CGSize(width: min(contentWidth + 2 * Self.inset, screenFrame.width - 2 * Self.horizontalMargin),
                   height: contentHeight + 2 * Self.inset)
        }

        /// The menu bar's height even while it is hidden (full screen, auto-hide), so the strip
        /// never jumps.
        var menuBarHeight: CGFloat {
            if safeAreaTop > 0 { return safeAreaTop }
            return max(contentHeight + 2, screenFrame.maxY - visibleFrame.maxY)
        }

        /// Under the notch when there is one, otherwise at the right edge under the menu bar.
        var frame: CGRect {
            let size = size
            let y = screenFrame.maxY - menuBarHeight - Self.verticalMargin - size.height
            var x: CGFloat
            if let notch {
                x = (notch.lowerBound + notch.upperBound) / 2 - size.width / 2
            } else {
                x = screenFrame.maxX - Self.horizontalMargin - size.width
            }
            x = min(max(x, screenFrame.minX + Self.horizontalMargin), screenFrame.maxX - Self.horizontalMargin - size.width)
            return CGRect(x: x.rounded(), y: y.rounded(), width: size.width, height: size.height)
        }

        init(screen: NSScreen, contentWidth: CGFloat, contentHeight: CGFloat) {
            screenFrame = screen.frame
            visibleFrame = screen.visibleFrame
            safeAreaTop = screen.safeAreaInsets.top
            if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea, left.maxX < right.minX {
                notch = left.maxX...right.minX
            } else {
                notch = nil
            }
            self.contentWidth = contentWidth
            self.contentHeight = contentHeight
        }

        init(screenFrame: CGRect, visibleFrame: CGRect, safeAreaTop: CGFloat, notch: ClosedRange<CGFloat>?,
             contentWidth: CGFloat, contentHeight: CGFloat) {
            self.screenFrame = screenFrame
            self.visibleFrame = visibleFrame
            self.safeAreaTop = safeAreaTop
            self.notch = notch
            self.contentWidth = contentWidth
            self.contentHeight = contentHeight
        }
    }

    private static let logger = Logger(subsystem: "io.github.mytrashcan.MusicLyricsBar", category: "floating-bar")
    private let panel: NSPanel
    private let preview = NSImageView()
    private var observer: NSObjectProtocol?
    private(set) var contentWidth: CGFloat
    /// Called on the main actor when the panel starts or stops being drawn on screen.
    var onVisibilityChange: (() -> Void)?

    var isVisible: Bool { panel.isVisible }
    /// Rendering is wasted while the strip is hidden or fully covered.
    var wantsUpdates: Bool { panel.isVisible && panel.occlusionState.contains(.visible) }

    init(width: CGFloat) {
        contentWidth = width
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: width, height: NSStatusBar.system.thickness),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.ignoresMouseEvents = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.isExcludedFromWindowsMenu = true
        panel.setAccessibilityIdentifier("MusicLyricsBar.FloatingLyrics")
        let background = NSVisualEffectView()
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 8
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
        hide()
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        onVisibilityChange = nil
    }

    func show(on screen: NSScreen?, width: CGFloat) {
        contentWidth = width
        layout(on: screen)
        guard !panel.isVisible else { return }
        panel.orderFrontRegardless()
        Self.logger.info("Floating lyrics bar shown at \(NSStringFromRect(self.panel.frame), privacy: .public)")
        onVisibilityChange?()
    }

    func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        preview.image = nil
        Self.logger.info("Floating lyrics bar hidden")
        onVisibilityChange?()
    }

    func layout(on screen: NSScreen?) {
        guard let screen = screen ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let placement = Placement(screen: screen, contentWidth: contentWidth, contentHeight: NSStatusBar.system.thickness)
        let frame = placement.frame
        guard panel.frame != frame else { return }
        panel.setFrame(frame, display: true)
        if panel.isVisible {
            Self.logger.info("Floating lyrics bar moved to \(NSStringFromRect(frame), privacy: .public)")
        }
    }

    func update(image: NSImage?) {
        guard wantsUpdates, preview.image !== image else { return }
        preview.image = image
    }
}
