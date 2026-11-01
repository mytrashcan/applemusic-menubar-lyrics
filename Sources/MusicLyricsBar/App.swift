import AppKit
import LyricsCore
import os

@main
enum MusicLyricsBarApp {
    @MainActor static func main() {
        let application = NSApplication.shared
        let delegate = AppController()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor
final class AppController: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let logger = Logger(subsystem: "io.github.mytrashcan.MusicLyricsBar", category: "app")
    private let music = MusicReader()
    private let cache = CacheReader()
    private let preferences = Preferences()
    private let statusImageRenderer = StatusImageRenderer()
    /// Renders the preferred width for the popover and the status preview while the menu bar
    /// item itself is reduced to its icon.
    private let detailRenderer = StatusImageRenderer()
    private static let iconImage = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Music Lyrics Bar")
    private let menu = NSMenu()
    private var item: NSStatusItem?
    private var fit: StatusItemFitObserver?
    private var popover: LyricPopover?
    private var detailImage: NSImage?
    private var isShowingIconMenu = false
    private var statusWindow: StatusWindow?
    private lazy var displayWidth = preferences.lyricsWidth

    // Playback polling.
    private var poller = PollScheduler()
    private var pollTask: Task<Void, Never>?
    private var pollTimer: Timer?
    private var isConnected = false
    private var sample: PlaybackSample?

    // Lyrics lookup.
    private var rescan = CacheRescanPolicy()
    private var cacheTask: Task<Void, Never>?
    private var nextCacheProbe: TimeInterval = 0
    private var lyrics: Lyrics?

    // Display.
    private var displayTimer: Timer?
    private var message = "Connect to Music from the menu."
    private var currentText = ""
    private var displayedTitle = ""
    private var lastStatusUpdate = 0.0

    // Diagnostics shown in the status window.
    private var sampleCount = 0
    private var playbackNotifications = 0
    private var sampleMilliseconds = 0.0
    private var cacheMilliseconds = 0.0

    private var observers: [NSObjectProtocol] = []
    private var distributedObservers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []

    private var uptime: TimeInterval { ProcessInfo.processInfo.systemUptime }

    // MARK: Application lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = "MusicLyricsBar.Lyrics"
        if let button = item.button {
            button.imagePosition = .imageOnly
            button.setAccessibilityIdentifier("MusicLyricsBar.Lyrics")
            button.setAccessibilityLabel("Music Lyrics Bar")
        }
        menu.delegate = self
        item.menu = menu
        self.item = item
        let fit = StatusItemFitObserver(item: item, preferred: displayWidth)
        fit.isEnabled = preferences.shrinkWhenCrowded
        fit.onChange = { [weak self] in self?.applyItemMode() }
        self.fit = fit
        applyItemMode()
        observePlaybackChanges()
        render()
        if preferences.connectOnLaunch { connect() } else { showStatus() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showStatus()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        cancelPolling()
        cancelLyricsLookup()
        displayTimer?.invalidate()
        fit?.invalidate()
        fit = nil
        for observer in workspaceObservers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        for observer in distributedObservers { DistributedNotificationCenter.default().removeObserver(observer) }
    }

    private func observePlaybackChanges() {
        for name in ["com.apple.Music.playerInfo", "com.apple.iTunes.playerInfo"] {
            distributedObservers.append(DistributedNotificationCenter.default().addObserver(
                forName: Notification.Name(name), object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.playbackNotifications += 1
                    self?.requestSample(refreshMetadata: true)
                }
            })
        }
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.didWakeNotification] {
            workspaceObservers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                if name == NSWorkspace.didWakeNotification || app?.bundleIdentifier == MusicEvents.bundleIdentifier {
                    MainActor.assumeIsolated { self?.requestSample(refreshMetadata: true) }
                }
            })
        }
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyItemMode() }
        })
    }

    // MARK: Menu

    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        add(trackTitle, to: menu)
        add(message, to: menu)
        if let fit, fit.isReduced {
            add(fit.isIconOnly ? "Menu bar crowded · click the note for lyrics"
                               : "Menu bar crowded · showing \(Int(fit.length))pt", to: menu)
        }
        menu.addItem(.separator())
        if !currentText.isEmpty {
            add(currentText, to: menu)
            menu.addItem(.separator())
        }
        if let lyrics, let sample {
            let position = sample.position(at: uptime)
            if let index = lyrics.lines.lastIndex(where: { $0.start <= position }) {
                let shown = lyrics.displayLines(at: position)
                let context = NSMenuItem(title: "Nearby Lyrics", action: nil, keyEquivalent: "")
                let submenu = NSMenu()
                for i in max(0, index - 2)...min(lyrics.lines.count - 1, index + 2) {
                    let line = lyrics.lines[i]
                    add((shown.contains(line) ? "♪ " : "") + line.text, to: submenu)
                }
                context.submenu = submenu
                menu.addItem(context)
            }
        }
        addAction(isConnected ? "Reconnect to Music" : "Connect to Music…", action: #selector(connect), to: menu)
        addAction("Show Status", action: #selector(showStatus), to: menu)
        let reconnect = NSMenuItem(title: "Connect on Launch", action: #selector(toggleConnectOnLaunch), keyEquivalent: "")
        reconnect.target = self
        reconnect.state = preferences.connectOnLaunch ? .on : .off
        menu.addItem(reconnect)
        let widthItem = NSMenuItem(title: "Lyrics Width", action: nil, keyEquivalent: "")
        let widths = NSMenu()
        for option in LyricsWidth.allCases {
            let entry = NSMenuItem(title: option.menuTitle, action: #selector(changeWidth(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = option.rawValue
            entry.state = displayWidth == option ? .on : .off
            widths.addItem(entry)
        }
        widthItem.submenu = widths
        menu.addItem(widthItem)
        let shrink = NSMenuItem(title: "Shrink When Crowded", action: #selector(toggleShrinkWhenCrowded), keyEquivalent: "")
        shrink.target = self
        shrink.state = preferences.shrinkWhenCrowded ? .on : .off
        menu.addItem(shrink)
        addAction("Reload Lyrics Cache", action: #selector(reloadLyrics), to: menu)
        addAction("Open Music", action: #selector(openMusic), to: menu)
        menu.addItem(.separator())
        add("Lyrics source: Apple Music cache on this Mac", to: menu)
        addAction("Quit", action: #selector(quit), to: menu, key: "q")
    }

    /// Icon-only mode owns the clicks: the left button opens the lyric popover, the right
    /// button (or Control-click) the menu. Otherwise the status item shows the menu itself.
    func menuDidClose(_ menu: NSMenu) {
        if !showsLyricsInItem { item?.menu = nil }
    }

    private func add(_ title: String, to menu: NSMenu) {
        let entry = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        entry.isEnabled = false
        menu.addItem(entry)
    }

    private func addAction(_ title: String, action: Selector, to menu: NSMenu, key: String = "") {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: key)
        entry.target = self
        menu.addItem(entry)
    }

    // MARK: Actions

    @objc private func connect() {
        preferences.connectOnLaunch = true
        cancelPolling()
        cancelLyricsLookup()
        isConnected = true
        sample = nil
        lyrics = nil
        sampleCount = 0
        message = "Connecting to Music…"
        requestSample(refreshMetadata: true)
    }

    @objc private func toggleConnectOnLaunch() {
        preferences.connectOnLaunch.toggle()
    }

    @objc private func toggleShrinkWhenCrowded() {
        preferences.shrinkWhenCrowded.toggle()
        fit?.isEnabled = preferences.shrinkWhenCrowded
    }

    @objc private func iconClicked() {
        guard let item, let button = item.button else { return }
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            guard !isShowingIconMenu else { return }
            isShowingIconMenu = true
            defer { isShowingIconMenu = false }
            item.menu = menu
            button.performClick(nil)
            item.menu = nil
            return
        }
        if popover == nil { popover = LyricPopover(width: displayWidth.points) }
        popover?.toggle(relativeTo: button)
        render()
    }

    @objc private func reloadLyrics() {
        cancelLyricsLookup()
        lyrics = nil
        if !isConnected { connect() }
        render()
    }

    @objc private func openMusic() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: MusicEvents.bundleIdentifier) {
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func changeWidth(_ sender: NSMenuItem) {
        guard let points = sender.representedObject as? Double, let width = LyricsWidth(rawValue: points) else { return }
        displayWidth = width
        preferences.lyricsWidth = width
        fit?.setPreferred(width)
        popover?.setWidth(width.points)
        statusWindow?.setWidth(width)
        displayedTitle = ""
        applyItemMode()
    }

    @objc private func changeWidthControl(_ sender: NSPopUpButton) {
        if let selected = sender.selectedItem { changeWidth(selected) }
    }

    @objc private func showStatus() {
        if statusWindow == nil {
            statusWindow = StatusWindow(target: self, connect: #selector(connect),
                                        reload: #selector(reloadLyrics), openMusic: #selector(openMusic),
                                        changeWidth: #selector(changeWidthControl(_:)), width: displayWidth)
        }
        statusWindow?.onClose = { [weak self] in self?.statusWindow = nil }
        lastStatusUpdate = 0
        statusWindow?.present()
        render()
    }

    // MARK: Playback polling

    private func requestSample(refreshMetadata: Bool = false) {
        guard isConnected else { return }
        pollTimer?.invalidate()
        pollTimer = nil
        guard let refreshMetadata = poller.request(refreshMetadata: refreshMetadata) else { return }
        pollTask = Task { [weak self] in
            guard let self else { return }
            var failed = false
            do {
                let started = uptime
                let result = try await music.sample(refreshMetadata: refreshMetadata)
                guard !Task.isCancelled else { return }
                sampleMilliseconds = (uptime - started) * 1000
                sampleCount += 1
                if result?.track != sample?.track {
                    cancelLyricsLookup()
                    lyrics = nil
                }
                sample = result
                if let result { lookUpLyricsIfNeeded(for: result.track) } else { message = "Play a song in Music." }
            } catch {
                guard !Task.isCancelled else { return }
                failed = true
                handleSampleFailure(error)
            }
            render()
            pollTask = nil
            guard isConnected else { return }
            switch poller.finish(sample: sample, failed: failed) {
            case .pollNow: requestSample()
            case .wait(let delay): schedulePoll(after: delay)
            }
        }
    }

    /// A transient read error (for example a track change mid-read) keeps the last sample on
    /// screen; its clock stops extrapolating on its own. Only a denied permission disconnects.
    private func handleSampleFailure(_ error: Error) {
        message = error.localizedDescription
        guard case .permissionDenied? = error as? MusicReaderError else { return }
        isConnected = false
        preferences.connectOnLaunch = false
        cancelLyricsLookup()
        sample = nil
        lyrics = nil
        showStatus()
    }

    private func schedulePoll(after delay: TimeInterval) {
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.requestSample() }
        }
        timer.tolerance = delay * 0.1
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func cancelPolling() {
        pollTask?.cancel()
        pollTask = nil
        pollTimer?.invalidate()
        pollTimer = nil
        poller.reset()
    }

    // MARK: Lyrics lookup

    private func lookUpLyricsIfNeeded(for track: Track) {
        let now = uptime
        guard lyrics == nil, cacheTask == nil, now >= nextCacheProbe else { return }
        nextCacheProbe = now + CacheRescanPolicy.probeInterval
        // Cache I/O must never stop playback polling. Reject a late result after
        // a track change or refresh, even when synchronous SQLite work finishes late.
        cacheTask = Task { [weak self] in
            guard let self else { return }
            let started = uptime
            let stamp = try? await cache.stamp()
            guard !Task.isCancelled, sample?.track == track else { return }
            guard rescan.shouldScan(stamp: stamp, now: started) else {
                cacheTask = nil
                return
            }
            message = "Looking for lyrics in the Music cache…"
            do {
                let loaded = try await cache.lyrics(for: track)
                guard !Task.isCancelled, sample?.track == track else { return }
                cacheMilliseconds = (uptime - started) * 1000
                lyrics = loaded
                if let loaded {
                    rescan.reset()
                    message = "Apple Music lyrics · Synced to playback."
                    Self.logger.info("Lyrics found: \(loaded.lines.count, privacy: .public) lines in \(self.cacheMilliseconds, format: .fixed(precision: 1), privacy: .public) ms")
                } else {
                    rescan.recordMiss(stamp: stamp, now: uptime)
                    message = "No synced lyrics · Open this song’s lyrics in Music."
                    Self.logger.info("Lyrics miss in \(self.cacheMilliseconds, format: .fixed(precision: 1), privacy: .public) ms")
                }
            } catch {
                guard !Task.isCancelled, sample?.track == track else { return }
                rescan.recordMiss(stamp: stamp, now: uptime)
                message = error.localizedDescription
                Self.logger.error("Lyrics lookup failed: \(String(describing: error), privacy: .public)")
            }
            cacheTask = nil
            render()
        }
    }

    private func cancelLyricsLookup() {
        cacheTask?.cancel()
        cacheTask = nil
        nextCacheProbe = 0
        rescan.reset()
    }

    // MARK: Menu bar fit

    private var itemScreen: NSScreen? { item?.button?.window?.screen ?? NSScreen.main }

    private var trackTitle: String {
        sample.map { "\($0.track.title) — \($0.track.artist)" } ?? "Music Lyrics Bar"
    }

    /// Lyrics draw in the menu bar item unless it is reduced to its icon.
    private var showsLyricsInItem: Bool { !(fit?.isIconOnly ?? false) }

    /// Applies the width the fit policy chose and switches the item between showing its menu
    /// directly and icon-only click handling.
    private func applyItemMode() {
        guard let item, let button = item.button else { return }
        let length = fit?.length ?? displayWidth.points
        let screenWidth = itemScreen?.frame.width ?? 1000
        let capped = min(length, screenWidth * 0.45)
        if item.length != capped { item.length = capped }
        if showsLyricsInItem {
            popover?.close()
            button.target = nil
            button.action = nil
            if item.menu == nil { item.menu = menu }
            // Coming back from the bare icon: the renderer may believe its last image is current.
            if button.image === Self.iconImage { statusImageRenderer.invalidate() }
        } else {
            item.menu = nil
            button.target = self
            button.action = #selector(iconClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        render()
    }

    // MARK: Display

    private func render() {
        autoreleasepool { renderFrame() }
    }

    private func renderFrame() {
        displayTimer?.invalidate()
        displayTimer = nil
        guard let item else { return }
        let position = sample?.position(at: uptime) ?? 0
        let lines = lyrics?.displayLines(at: position) ?? []
        currentText = LyricTextLayout.fullText(lines)
        let label: String
        if let sample {
            label = LyricTextLayout.label(lines: lines, title: sample.track.title, isPlaying: sample.isPlaying)
        } else {
            label = isConnected ? "Waiting for Music" : "Connect to Music"
        }
        let button = item.button
        let titleChanged = displayedTitle != label
        if titleChanged {
            displayedTitle = label
            button?.setAccessibilityValue(label)
        }
        let tooltip = currentText.isEmpty ? message : currentText
        let isPlaying = sample?.isPlaying ?? false
        let thickness = NSStatusBar.system.thickness
        let showsLyricsInItem = showsLyricsInItem
        if showsLyricsInItem {
            if let image = statusImageRenderer.image(lines: lines, fallback: label, position: position, isPlaying: isPlaying,
                                                     size: NSSize(width: item.length, height: thickness)) {
                button?.image = image
            }
        } else if button?.image !== Self.iconImage {
            button?.image = Self.iconImage
        }
        // The preferred-width image is only drawn while the popover or the status preview shows it.
        let wantsDetail = popover?.isShown == true || (!showsLyricsInItem && statusWindow?.window?.isVisible == true)
        if wantsDetail, let image = detailRenderer.image(lines: lines, fallback: label, position: position, isPlaying: isPlaying,
                                                         size: NSSize(width: displayWidth.points, height: thickness)) {
            detailImage = image
        }
        popover?.update(title: trackTitle, image: detailImage)
        statusWindow?.updatePreview(image: showsLyricsInItem ? button?.image : detailImage)
        if isPlaying {
            var delay = lyrics?.nextLineBoundary(after: position).map { $0 - position } ?? .infinity
            if showsLyricsInItem {
                delay = min(delay, statusImageRenderer.nextUpdateDelay(at: position, isPlaying: true, width: item.length) ?? .infinity)
            }
            if wantsDetail {
                delay = min(delay, detailRenderer.nextUpdateDelay(at: position, isPlaying: true, width: displayWidth.points) ?? .infinity)
            }
            if delay.isFinite {
                let timer = Timer(timeInterval: max(0.01, delay), repeats: false) { [weak self] _ in
                    MainActor.assumeIsolated { self?.render() }
                }
                timer.tolerance = min(0.01, delay * 0.1)
                RunLoop.main.add(timer, forMode: .common)
                displayTimer = timer
            }
        }
        if button?.toolTip != tooltip { button?.toolTip = tooltip }
        let now = uptime
        // Diagnostic counters only need an update while the status window is open.
        guard let statusWindow,
              lastStatusUpdate == 0 || (statusWindow.window?.isVisible == true &&
                  (titleChanged || now - lastStatusUpdate >= 1)) else { return }
        lastStatusUpdate = now
        let playback = sample.map { $0.isPlaying ? "Playing" : "Paused" } ?? "Waiting"
        statusWindow.update(
            track: trackTitle,
            lyric: currentText.isEmpty ? label : currentText,
            status: message,
            metrics: String(format: "%@ · Position %.2fs · Polls %d · Events %d\nPlayback %.1fms · Cache %.1fms · Lines %d · Timed spans %d",
                            playback, position, sampleCount, playbackNotifications, sampleMilliseconds, cacheMilliseconds, lyrics?.lines.count ?? 0,
                            lyrics?.lines.reduce(0) { $0 + $1.words.count } ?? 0),
            connected: isConnected)
    }
}
