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
    private var sample: PlaybackSample?
    private var lyrics: Lyrics?
    private var nextCacheRead: TimeInterval = 0
    private var message = "메뉴에서 Music을 연결해 주세요."
    private var currentText = ""
    private var isConnected = false
    private var statusWindow: StatusWindow?
    private var sampleCount = 0
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
        }
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.render() }
        }
        RunLoop.main.add(timer, forMode: .common)
        displayTimer = timer
        render()
        showStatus()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showStatus()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        pollTask?.cancel()
        cacheTask?.cancel()
        displayTimer?.invalidate()
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
                let context = NSMenuItem(title: "주변 가사", action: nil, keyEquivalent: "")
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
        addAction(isConnected ? "Music 다시 연결" : "Music 연결…", action: #selector(connect), to: menu)
        addAction("상태 보기", action: #selector(showStatus), to: menu)
        let widthItem = NSMenuItem(title: "가사 표시 폭", action: nil, keyEquivalent: "")
        let widths = NSMenu()
        for (title, width) in [("좁게 · 240pt", 240.0), ("보통 · 360pt", 360.0), ("넓게 · 600pt", 600.0)] {
            let entry = NSMenuItem(title: title, action: #selector(changeWidth(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = width
            entry.state = maximumWidth == width ? .on : .off
            widths.addItem(entry)
        }
        widthItem.submenu = widths
        menu.addItem(widthItem)
        addAction("가사 캐시 다시 읽기", action: #selector(reloadLyrics), to: menu)
        addAction("Music 열기", action: #selector(openMusic), to: menu)
        menu.addItem(.separator())
        add("가사 출처: 이 Mac의 Apple Music 캐시", to: menu)
        addAction("종료", action: #selector(quit), to: menu, key: "q")
    }

    @objc private func connect() {
        pollTask?.cancel()
        cacheTask?.cancel()
        cacheTask = nil
        isConnected = true
        sample = nil
        lyrics = nil
        sampleCount = 0
        message = "Music에 연결하는 중…"
        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    let sampleStarted = ProcessInfo.processInfo.systemUptime
                    let result = try await music.sample()
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
                        message = "Music에서 노래를 재생해 주세요."
                    }
                    render()
                } catch {
                    guard !Task.isCancelled else { return }
                    cacheTask?.cancel()
                    cacheTask = nil
                    sample = nil
                    lyrics = nil
                    message = error.localizedDescription
                    let permissionDenied = (error as? MusicReaderError).map {
                        if case .permissionDenied = $0 { return true }
                        return false
                    } ?? false
                    isConnected = !permissionDenied
                    render()
                    if permissionDenied { return }
                }
                do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            }
        }
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
        message = "Music 캐시에서 가사를 확인하는 중…"
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
                    ? "동기화 가사 없음 · Music에서 이 곡의 가사를 열어 주세요."
                    : "Apple Music 가사 · 재생 위치에 맞춰 표시합니다."
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

    private var maximumWidth: Double {
        let saved = UserDefaults.standard.double(forKey: "lyricsWidth")
        return [240.0, 360.0, 600.0].contains(saved) ? saved : 360
    }

    @objc private func changeWidth(_ sender: NSMenuItem) {
        guard let width = sender.representedObject as? Double else { return }
        UserDefaults.standard.set(width, forKey: "lyricsWidth")
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
        lastStatusUpdate = 0
        render()
        statusWindow?.present()
    }

    private func render() {
        guard let item else { return }
        let position = sample?.position(at: ProcessInfo.processInfo.systemUptime) ?? 0
        let lines = lyrics?.displayLines(at: position) ?? []
        currentText = lines.map(\.text).joined(separator: " / ")
        let label: String
        if let sample {
            label = (sample.isPlaying ? "" : "Ⅱ ") + (currentText.isEmpty ? sample.track.title : currentText)
        } else {
            label = isConnected ? "Music 대기 중" : "Music 연결"
        }
        let singleLine = label.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ")
        let button = item.button
        let titleChanged = displayedTitle != singleLine
        if titleChanged {
            displayedTitle = singleLine
            button?.setAccessibilityLabel("Music Lyrics Bar: " + singleLine)
            // Keep a predictable width so lyrics do not crowd other menu bar controls.
            let width = (singleLine as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 13)]).width + 34
            let available = (button?.window?.screen ?? NSScreen.main)?.visibleFrame.width ?? 1000
            item.length = min(max(80, width), min(maximumWidth, available * 0.45))
        }
        let tooltip = currentText.isEmpty ? message : currentText
        if let image = statusImageRenderer.image(lines: lines, fallback: singleLine, position: position,
                                                 isPlaying: sample?.isPlaying ?? false,
                                                 size: NSSize(width: item.length, height: NSStatusBar.system.thickness)) {
            button?.image = image
        }
        statusWindow?.updateKaraoke(lines: lines, fallback: singleLine, position: position, isPlaying: sample?.isPlaying ?? false)
        if button?.toolTip != tooltip { button?.toolTip = tooltip }
        let uptime = ProcessInfo.processInfo.systemUptime
        // The menu bar keeps its 10 Hz timeline. Diagnostic counters need only 1 Hz.
        guard let statusWindow,
              lastStatusUpdate == 0 || (statusWindow.window?.isVisible == true &&
                  (titleChanged || uptime - lastStatusUpdate >= 1)) else { return }
        lastStatusUpdate = uptime
        let playback = sample.map { $0.isPlaying ? "재생" : "일시정지" } ?? "대기"
        statusWindow.update(
            track: sample.map { "\($0.track.title) — \($0.track.artist)" } ?? "Music Lyrics Bar",
            lyric: currentText.isEmpty ? singleLine : currentText,
            status: message,
            metrics: String(format: "%@ · 위치 %.2f초 · 조회 %d회\n재생 조회 %.1fms · 캐시 조회 %.1fms · 가사 %d줄 · 단어 타이밍 %d개",
                            playback, position, sampleCount, sampleMilliseconds, cacheMilliseconds, lyrics?.lines.count ?? 0,
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
