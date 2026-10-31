import AppKit
import LyricsCore

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
    private let music = MusicReader()
    private let cache = CacheReader()
    private var item: NSStatusItem!
    private var pollTask: Task<Void, Never>?
    private var cacheTask: Task<Void, Never>?
    private var displayTimer: Timer?
    private var pollTimer: Timer?
    private var sampleRequested = false
    private var metadataRequested = false
    private var observers: [NSObjectProtocol] = []
    private var distributedObservers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var sample: PlaybackSample?
    private var lyrics: Lyrics?
    private var nextCacheRead: TimeInterval = 0
    private var message = "Connect to Music from the menu."
    private var currentText = ""
    private var isConnected = false
    private var statusWindow: StatusWindow?
    private var sampleCount = 0
    private var playbackNotifications = 0
    private var sampleMilliseconds = 0.0
    private var cacheMilliseconds = 0.0
    private var lastStatusUpdate = 0.0
    private let statusImageRenderer = StatusImageRenderer()
    private var displayedTitle = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = "MusicLyricsBar.Lyrics"
        if let button = item.button {
            button.imagePosition = .imageOnly
            button.setAccessibilityIdentifier("MusicLyricsBar.Lyrics")
            button.setAccessibilityLabel("Music Lyrics Bar")
        }
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        updateItemWidth()
        observePlaybackChanges()
        render()
        if UserDefaults.standard.bool(forKey: "connectOnLaunch") { connect() }
        else { showStatus() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showStatus()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        pollTask?.cancel()
        cacheTask?.cancel()
        displayTimer?.invalidate()
        pollTimer?.invalidate()
        for observer in workspaceObservers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        for observer in distributedObservers { DistributedNotificationCenter.default().removeObserver(observer) }
    }

    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        add(sample.map { "\($0.track.title) — \($0.track.artist)" } ?? "Music Lyrics Bar", to: menu)
        add(message, to: menu)
        menu.addItem(.separator())
        if !currentText.isEmpty { add(currentText, to: menu); menu.addItem(.separator()) }
        if let lyrics, let sample {
            let position = sample.position(at: ProcessInfo.processInfo.systemUptime)
            if let index = lyrics.lines.lastIndex(where: { $0.start <= position }) {
                let context = NSMenuItem(title: "Nearby Lyrics", action: nil, keyEquivalent: "")
                let submenu = NSMenu()
                for i in max(0, index - 2)...min(lyrics.lines.count - 1, index + 2) {
                    let line = lyrics.lines[i]
                    let active = lyrics.displayLines(at: position).contains(line)
                    add((active ? "♪ " : "") + line.text, to: submenu)
                }
                context.submenu = submenu
                menu.addItem(context)
            }
        }
        addAction(isConnected ? "Reconnect to Music" : "Connect to Music…", action: #selector(connect), to: menu)
        addAction("Show Status", action: #selector(showStatus), to: menu)
        let reconnect = NSMenuItem(title: "Connect on Launch", action: #selector(toggleConnectOnLaunch), keyEquivalent: "")
        reconnect.target = self
        reconnect.state = UserDefaults.standard.bool(forKey: "connectOnLaunch") ? .on : .off
        menu.addItem(reconnect)
        let widthItem = NSMenuItem(title: "Lyrics Width", action: nil, keyEquivalent: "")
        let widths = NSMenu()
        for (title, width) in [("Compact · 200pt", 200.0), ("Narrow · 240pt", 240.0), ("Medium · 360pt", 360.0), ("Wide · 600pt", 600.0)] {
            let entry = NSMenuItem(title: title, action: #selector(changeWidth(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = width
            entry.state = displayWidth == width ? .on : .off
            widths.addItem(entry)
        }
        widthItem.submenu = widths
        menu.addItem(widthItem)
        addAction("Reload Lyrics Cache", action: #selector(reloadLyrics), to: menu)
        addAction("Open Music", action: #selector(openMusic), to: menu)
        menu.addItem(.separator())
        add("Lyrics source: Apple Music cache on this Mac", to: menu)
        addAction("Quit", action: #selector(quit), to: menu, key: "q")
    }

    @objc private func connect() {
        UserDefaults.standard.set(true, forKey: "connectOnLaunch")
        pollTask?.cancel()
        cacheTask?.cancel()
        cacheTask = nil
        isConnected = true
        sample = nil
        lyrics = nil
        sampleCount = 0
        message = "Connecting to Music…"
        pollTimer?.invalidate()
        pollTask = nil
        requestSample(refreshMetadata: true)
    }

    @objc private func toggleConnectOnLaunch() {
        let enabled = UserDefaults.standard.bool(forKey: "connectOnLaunch")
        UserDefaults.standard.set(!enabled, forKey: "connectOnLaunch")
    }

    private func requestSample(refreshMetadata: Bool = false) {
        guard isConnected else { return }
        pollTimer?.invalidate()
        metadataRequested = metadataRequested || refreshMetadata
        guard pollTask == nil else { sampleRequested = true; return }
        let refreshMetadata = metadataRequested
        metadataRequested = false
        sampleRequested = false
        pollTask = Task { [weak self] in
            guard let self else { return }
            var retryAfterFailure = false
            do {
                let sampleStarted = ProcessInfo.processInfo.systemUptime
                let result = try await music.sample(refreshMetadata: refreshMetadata)
                guard !Task.isCancelled else { return }
                sampleMilliseconds = (ProcessInfo.processInfo.systemUptime - sampleStarted) * 1000
                sampleCount += 1
                if result?.track != sample?.track {
                    cacheTask?.cancel()
                    cacheTask = nil
                    lyrics = nil
                    nextCacheRead = 0
                }
                sample = result
                if let result {
                    let now = ProcessInfo.processInfo.systemUptime
                    if lyrics == nil, cacheTask == nil, now >= nextCacheRead {
                        loadLyrics(for: result.track)
                    }
                } else {
                    message = "Play a song in Music."
                }
                render()
            } catch {
                guard !Task.isCancelled else { return }
                cacheTask?.cancel()
                cacheTask = nil
                sample = nil
                lyrics = nil
                message = error.localizedDescription
                retryAfterFailure = true
                let permissionDenied = (error as? MusicReaderError).map {
                    if case .permissionDenied = $0 { return true }
                    return false
                } ?? false
                isConnected = !permissionDenied
                if permissionDenied {
                    UserDefaults.standard.set(false, forKey: "connectOnLaunch")
                    showStatus()
                }
                render()
            }
            pollTask = nil
            guard isConnected else { return }
            if sampleRequested {
                requestSample()
            } else {
                // Notifications wake paused/stopped playback immediately. These
                // low-rate fallbacks also recover if Music omits a notification.
                let delay = retryAfterFailure || sample?.isPlaying == true ? 0.5 : (sample == nil ? 10.0 : 2.0)
                let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
                    MainActor.assumeIsolated { self?.requestSample() }
                }
                timer.tolerance = delay * 0.1
                RunLoop.main.add(timer, forMode: .common)
                pollTimer = timer
            }
        }
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
            // Workspace observers have a separate center and are removed with
            // the controller's application lifetime.
            workspaceObservers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                if name == NSWorkspace.didWakeNotification || app?.bundleIdentifier == "com.apple.Music" {
                    MainActor.assumeIsolated { self?.requestSample(refreshMetadata: true) }
                }
            })
        }
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateItemWidth(); self?.render() }
        })
    }

    @objc private func reloadLyrics() {
        cacheTask?.cancel()
        cacheTask = nil
        lyrics = nil
        nextCacheRead = 0
        if !isConnected { connect() }
        render()
    }

    private func loadLyrics(for track: Track) {
        let started = ProcessInfo.processInfo.systemUptime
        nextCacheRead = started + 3
        message = "Looking for lyrics in the Music cache…"
        // Cache I/O must never stop playback polling. Reject a late result after
        // a track change or refresh, even when synchronous SQLite work finishes late.
        cacheTask = Task { [weak self] in
            guard let self else { return }
            do {
                let loaded = try await cache.lyrics(for: track)
                guard !Task.isCancelled, sample?.track == track else { return }
                cacheMilliseconds = (ProcessInfo.processInfo.systemUptime - started) * 1000
                lyrics = loaded
                message = loaded == nil
                    ? "No synced lyrics · Open this song’s lyrics in Music."
                    : "Apple Music lyrics · Synced to playback."
            } catch {
                guard !Task.isCancelled, sample?.track == track else { return }
                message = error.localizedDescription
            }
            cacheTask = nil
            render()
        }
    }

    @objc private func openMusic() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Music") {
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }

    private var displayWidth: Double = {
        let saved = UserDefaults.standard.double(forKey: "lyricsWidth")
        return [200.0, 240.0, 360.0, 600.0].contains(saved) ? saved : 200
    }()

    @objc private func changeWidth(_ sender: NSMenuItem) {
        guard let width = sender.representedObject as? Double else { return }
        displayWidth = width
        UserDefaults.standard.set(width, forKey: "lyricsWidth")
        updateItemWidth()
        statusWindow?.setWidth(width)
        displayedTitle = ""
        render()
    }

    @objc private func changeWidthControl(_ sender: NSPopUpButton) {
        if let selected = sender.selectedItem { changeWidth(selected) }
    }

    @objc private func showStatus() {
        if statusWindow == nil {
            statusWindow = StatusWindow(target: self, connect: #selector(connect),
                                        reload: #selector(reloadLyrics), openMusic: #selector(openMusic),
                                        changeWidth: #selector(changeWidthControl(_:)))
        }
        statusWindow?.onClose = { [weak self] in self?.statusWindow = nil }
        lastStatusUpdate = 0
        statusWindow?.present()
        render()
    }

    private func updateItemWidth() {
        guard let item else { return }
        let screenWidth = (item.button?.window?.screen ?? NSScreen.main)?.frame.width ?? 1000
        item.length = min(displayWidth, screenWidth * 0.45)
    }

    private func render() {
        autoreleasepool { renderFrame() }
    }

    private func renderFrame() {
        displayTimer?.invalidate()
        displayTimer = nil
        guard let item else { return }
        let position = sample?.position(at: ProcessInfo.processInfo.systemUptime) ?? 0
        let lines = lyrics?.displayLines(at: position) ?? []
        currentText = lines.map(\.text).joined(separator: " / ")
        let label: String
        if let sample {
            label = (sample.isPlaying ? "" : "Ⅱ ") + (currentText.isEmpty ? sample.track.title : currentText)
        } else {
            label = isConnected ? "Waiting for Music" : "Connect to Music"
        }
        let singleLine = label.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ")
        let button = item.button
        let titleChanged = displayedTitle != singleLine
        if titleChanged {
            displayedTitle = singleLine
            button?.setAccessibilityValue(singleLine)
        }
        let tooltip = currentText.isEmpty ? message : currentText
        if let image = statusImageRenderer.image(lines: lines, fallback: singleLine, position: position,
                                                 isPlaying: sample?.isPlaying ?? false,
                                                 size: NSSize(width: item.length, height: NSStatusBar.system.thickness)) {
            button?.image = image
        }
        statusWindow?.updatePreview(image: button?.image)
        if sample?.isPlaying == true {
            let delay = min(lyrics?.nextLineBoundary(after: position).map { $0 - position } ?? .infinity,
                            statusImageRenderer.nextUpdateDelay(at: position, isPlaying: true,
                                                               width: item.length) ?? .infinity)
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
        let uptime = ProcessInfo.processInfo.systemUptime
        // Diagnostic counters only need an update while the status window is open.
        guard let statusWindow,
              lastStatusUpdate == 0 || (statusWindow.window?.isVisible == true &&
                  (titleChanged || uptime - lastStatusUpdate >= 1)) else { return }
        lastStatusUpdate = uptime
        let playback = sample.map { $0.isPlaying ? "Playing" : "Paused" } ?? "Waiting"
        statusWindow.update(
            track: sample.map { "\($0.track.title) — \($0.track.artist)" } ?? "Music Lyrics Bar",
            lyric: currentText.isEmpty ? singleLine : currentText,
            status: message,
            metrics: String(format: "%@ · Position %.2fs · Polls %d · Events %d\nPlayback %.1fms · Cache %.1fms · Lines %d · Timed spans %d",
                            playback, position, sampleCount, playbackNotifications, sampleMilliseconds, cacheMilliseconds, lyrics?.lines.count ?? 0,
                            lyrics?.lines.reduce(0) { $0 + $1.words.count } ?? 0),
            connected: isConnected)
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
}
