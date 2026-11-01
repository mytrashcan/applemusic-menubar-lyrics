import AppKit
import os

/// What AppKit reports about the status item's window, reduced to the fields that tell an item
/// macOS pushed out of the menu bar apart from one whose menu bar is merely hidden.
///
/// Measured on macOS 27.2 (see docs/VALIDATION.md): `NSStatusItem.isVisible` and
/// `NSWindow.isVisible` stay true in every case. A crowded-out item loses `.visible` from its
/// window's `occlusionState` and its frame moves left, over or past the notch; an item that never
/// got a slot is parked at (0, -34) with no screen. When a full-screen app hides the menu bar the
/// window is occluded too, but its frame stays exactly where it was.
struct StatusItemPlacement: Equatable, Sendable {
    /// `occlusionState` lacks `.visible`.
    var isOccluded: Bool
    /// `button.window?.frame`; nil without a window.
    var frame: CGRect?
    /// False when `window.screen` is nil, which is how macOS parks an item it never placed.
    var hasScreen: Bool
    /// Left edge of the menu bar region right of the notch (`auxiliaryTopRightArea.minX`);
    /// nil on displays without a notch.
    var visibleRegionMinX: CGFloat?
    /// The frame last seen while the item was visible, if any.
    var lastVisibleFrame: CGRect?

    /// True when the item was pushed out of the menu bar rather than hidden with it.
    var isClipped: Bool {
        guard isOccluded else { return false }
        guard let frame, hasScreen else { return true }
        // Left of the notch region is certainly out. The converse does not hold: a 200pt item
        // was observed occluded at x 951 on a display whose region starts at 947.5, so an item
        // right of the boundary still has to pass the movement test below.
        if let visibleRegionMinX, frame.minX < visibleRegionMinX - 1 { return true }
        guard let lastVisibleFrame else { return true }
        // A resize of our own keeps the right edge; a right edge that moved while occluded
        // means macOS relocated the item. A hidden menu bar leaves the frame where it was.
        return abs(frame.maxX - lastVisibleFrame.maxX) > 0.5
    }
}

/// Steps the status item down through the width options when macOS pushes it out of the menu
/// bar, and probes back up with exponential backoff once it is visible again. Pure state with
/// no timers or AppKit, so the policy is unit-testable.
struct MenuBarFitPolicy: Equatable {
    enum Level: Equatable {
        case width(LyricsWidth)
        case iconOnly
    }

    /// What the caller should do after an update: resize the item and/or evaluate again later.
    struct Decision: Equatable {
        var length: CGFloat?
        var checkAfter: TimeInterval?
    }

    static let iconOnlyLength: CGFloat = 22
    /// Time for AppKit to lay the menu bar out again after a resize before the result is read.
    static let settleInterval: TimeInterval = 0.75
    static let initialRetryInterval: TimeInterval = 20
    static let maximumRetryInterval: TimeInterval = 600
    /// A clip this soon after a grow counts as a failed probe and doubles the retry interval.
    static let probeWindow: TimeInterval = 5
    /// A display change may have freed space: probe again after the menu bar settles.
    static let screenChangeDelay: TimeInterval = 2

    let preferred: LyricsWidth
    private(set) var steps = 0
    private var retryInterval = MenuBarFitPolicy.initialRetryInterval
    private var retryDue: TimeInterval?
    private var lastGrow: TimeInterval = -.infinity
    private var probeFailed = false

    init(preferred: LyricsWidth) {
        self.preferred = preferred
    }

    var level: Level {
        let options = LyricsWidth.allCases
        let index = (options.firstIndex(of: preferred) ?? 0) - steps
        return index >= 0 ? .width(options[index]) : .iconOnly
    }

    var length: CGFloat {
        switch level {
        case .width(let width): width.points
        case .iconOnly: Self.iconOnlyLength
        }
    }

    var isIconOnly: Bool { level == .iconOnly }
    var isReduced: Bool { steps > 0 }

    /// Feeds the latest observation. Clipped: shrink one step and look again once the menu bar
    /// settles. Visible but reduced: grow one step when the retry is due, otherwise say when.
    mutating func update(clipped: Bool, now: TimeInterval) -> Decision {
        if clipped {
            guard !isIconOnly else {
                retryDue = nil
                return Decision()
            }
            if now - lastGrow < Self.probeWindow {
                probeFailed = true
                retryInterval = min(Self.maximumRetryInterval, retryInterval * 2)
            } else {
                probeFailed = false
                retryInterval = Self.initialRetryInterval
            }
            steps += 1
            retryDue = now + retryInterval
            return Decision(length: length, checkAfter: Self.settleInterval)
        }
        guard isReduced else {
            retryDue = nil
            return Decision()
        }
        guard let due = retryDue else {
            retryDue = now + retryInterval
            return Decision(checkAfter: retryInterval)
        }
        guard now >= due else { return Decision(checkAfter: due - now) }
        // The previous grow survived its probe window, so the backoff starts over.
        if lastGrow.isFinite, !probeFailed { retryInterval = Self.initialRetryInterval }
        probeFailed = false
        lastGrow = now
        steps -= 1
        retryDue = isReduced ? now + retryInterval : nil
        return Decision(length: length, checkAfter: Self.settleInterval)
    }

    /// Display configuration changed: forget the backoff and probe soon if the item is reduced.
    mutating func screenChanged(now: TimeInterval) -> Decision {
        retryInterval = Self.initialRetryInterval
        probeFailed = false
        guard isReduced else { return Decision() }
        retryDue = now + Self.screenChangeDelay
        return Decision(checkAfter: Self.screenChangeDelay)
    }
}

/// Watches the status item's window and drives `MenuBarFitPolicy` from what AppKit reports.
@MainActor
final class StatusItemFitObserver {
    /// Coalesces the burst of window notifications AppKit posts while it lays the menu bar out.
    static let debounceInterval: TimeInterval = 0.3
    private static let logger = Logger(subsystem: "io.github.mytrashcan.MusicLyricsBar", category: "menubar-fit")

    private let item: NSStatusItem
    private(set) var policy: MenuBarFitPolicy
    private var observers: [NSObjectProtocol] = []
    private var checkTimer: Timer?
    private var lastVisibleFrame: CGRect?
    private var lastLength: CGFloat?
    /// Called on the main actor whenever the policy picks a different length.
    var onChange: (() -> Void)?

    /// Off when the user turned the feature off; the policy then stays at the preferred width.
    var isEnabled = true {
        didSet {
            guard isEnabled != oldValue else { return }
            if isEnabled { scheduleCheck(after: Self.debounceInterval) } else { reset() }
        }
    }

    var length: CGFloat { policy.length }
    var isIconOnly: Bool { policy.isIconOnly }
    var isReduced: Bool { policy.isReduced }

    private var uptime: TimeInterval { ProcessInfo.processInfo.systemUptime }

    init(item: NSStatusItem, preferred: LyricsWidth) {
        self.item = item
        policy = MenuBarFitPolicy(preferred: preferred)
        lastLength = policy.length
        let center = NotificationCenter.default
        for name in [NSWindow.didChangeOcclusionStateNotification, NSWindow.didMoveNotification,
                     NSWindow.didResizeNotification, NSWindow.didChangeScreenNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                let sender = (notification.object as AnyObject?).map(ObjectIdentifier.init)
                MainActor.assumeIsolated {
                    guard let self, let window = self.item.button?.window, ObjectIdentifier(window) == sender else { return }
                    self.scheduleCheck(after: Self.debounceInterval)
                }
            })
        }
        observers.append(center.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                            object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isEnabled else { return }
                self.lastVisibleFrame = nil
                self.apply(self.policy.screenChanged(now: self.uptime))
            }
        })
        // AppKit posts a burst of window notifications at launch; this covers a quiet launch too.
        scheduleCheck(after: MenuBarFitPolicy.settleInterval)
    }

    /// Stops observing and the pending check. The owner calls this before letting go.
    func invalidate() {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers.removeAll()
        checkTimer?.invalidate()
        checkTimer = nil
        onChange = nil
    }

    func setPreferred(_ width: LyricsWidth) {
        policy = MenuBarFitPolicy(preferred: width)
        checkTimer?.invalidate()
        notifyIfChanged()
        if isEnabled { scheduleCheck(after: MenuBarFitPolicy.settleInterval) }
    }

    /// The current observation, from the live window state.
    func placement() -> StatusItemPlacement {
        let window = item.button?.window
        let screen = window?.screen
        return StatusItemPlacement(
            isOccluded: !(window?.occlusionState.contains(.visible) ?? false),
            frame: window?.frame,
            hasScreen: screen != nil,
            visibleRegionMinX: screen.flatMap { $0.auxiliaryTopRightArea?.minX },
            lastVisibleFrame: lastVisibleFrame)
    }

    func evaluate() {
        checkTimer?.invalidate()
        checkTimer = nil
        guard isEnabled else { return }
        let placement = placement()
        if !placement.isOccluded, let frame = placement.frame { lastVisibleFrame = frame }
        let before = policy.length
        let decision = policy.update(clipped: placement.isClipped, now: uptime)
        if decision.length != nil, policy.length != before {
            Self.logger.info("Status item \(placement.isClipped ? "clipped" : "visible", privacy: .public) at \(Int(before), privacy: .public)pt (occluded \(placement.isOccluded, privacy: .public), x \(Int(placement.frame?.minX ?? -1), privacy: .public)); now \(Int(self.policy.length), privacy: .public)pt")
        }
        apply(decision)
    }

    private func reset() {
        checkTimer?.invalidate()
        checkTimer = nil
        policy = MenuBarFitPolicy(preferred: policy.preferred)
        notifyIfChanged()
    }

    private func apply(_ decision: MenuBarFitPolicy.Decision) {
        if decision.length != nil { notifyIfChanged() }
        if let delay = decision.checkAfter { scheduleCheck(after: delay) }
    }

    private func notifyIfChanged() {
        guard lastLength != policy.length else { return }
        lastLength = policy.length
        onChange?()
    }

    private func scheduleCheck(after delay: TimeInterval) {
        checkTimer?.invalidate()
        let timer = Timer(timeInterval: max(0.05, delay), repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.evaluate() }
        }
        timer.tolerance = min(0.1, delay * 0.1)
        RunLoop.main.add(timer, forMode: .common)
        checkTimer = timer
    }
}
