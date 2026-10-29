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
    private var displayTimer: Timer?
    private var sample: PlaybackSample?
    private var lyrics: Lyrics?
    private var nextCacheRead: TimeInterval = 0
    private var message = "메뉴에서 Music을 연결해 주세요."
    private var currentText = ""
    private var isConnected = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Music Lyrics Bar")
            button.imagePosition = .imageLeading
            button.font = .systemFont(ofSize: 13)
            button.cell?.lineBreakMode = .byTruncatingTail
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
    }

    func applicationWillTerminate(_ notification: Notification) {
        pollTask?.cancel()
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
                    let active = line.start <= position && position < line.end
                    add((active ? "♪ " : "") + line.text, to: submenu)
                }
                context.submenu = submenu
                menu.addItem(context)
            }
        }
        addAction(isConnected ? "Music 다시 연결" : "Music 연결…", action: #selector(connect), to: menu)
        addAction("가사 캐시 다시 읽기", action: #selector(reloadLyrics), to: menu)
        addAction("Music 열기", action: #selector(openMusic), to: menu)
        menu.addItem(.separator())
        add("가사 출처: 이 Mac의 Apple Music 캐시", to: menu)
        addAction("종료", action: #selector(quit), to: menu, key: "q")
    }

    @objc private func connect() {
        pollTask?.cancel()
        isConnected = true
        sample = nil
        lyrics = nil
        message = "Music에 연결하는 중…"
        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    let result = try await music.sample()
                    guard !Task.isCancelled else { return }
                    if result?.track != sample?.track {
                        lyrics = nil
                        nextCacheRead = 0
                    }
                    sample = result
                    if let result {
                        let now = ProcessInfo.processInfo.systemUptime
                        if lyrics == nil, now >= nextCacheRead {
                            nextCacheRead = now + 3
                            do {
                                let loaded = try await cache.lyrics(for: result.track)
                                guard !Task.isCancelled else { return }
                                lyrics = loaded
                                message = loaded == nil
                                    ? "동기화 가사 없음 · Music에서 이 곡의 가사를 열어 주세요."
                                    : "Apple Music 가사 · 재생 위치에 맞춰 표시합니다."
                            } catch {
                                guard !Task.isCancelled else { return }
                                message = error.localizedDescription
                            }
                        }
                    } else {
                        message = "Music에서 노래를 재생해 주세요."
                    }
                    render()
                } catch {
                    guard !Task.isCancelled else { return }
                    sample = nil
                    lyrics = nil
                    message = error.localizedDescription
                    isConnected = false
                    render()
                    return
                }
                do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            }
        }
    }

    @objc private func reloadLyrics() {
        lyrics = nil
        nextCacheRead = 0
        if !isConnected { connect() }
        render()
    }

    @objc private func openMusic() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Music") {
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }

    private func render() {
        guard let item else { return }
        let position = sample?.position(at: ProcessInfo.processInfo.systemUptime) ?? 0
        currentText = lyrics?.activeLines(at: position).map(\.text).joined(separator: " / ") ?? ""
        let label: String
        if let sample {
            label = (sample.isPlaying ? "" : "Ⅱ ") + (currentText.isEmpty ? sample.track.title : currentText)
        } else {
            label = isConnected ? "Music 대기 중" : "Music 연결"
        }
        let singleLine = label.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let button = item.button
        button?.title = " " + singleLine
        button?.toolTip = currentText.isEmpty ? message : currentText
        button?.setAccessibilityLabel("Music Lyrics Bar: " + singleLine)
        // Keep a predictable width so lyrics do not crowd other menu bar controls.
        let width = (singleLine as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 13)]).width + 34
        let available = (button?.window?.screen ?? NSScreen.main)?.visibleFrame.width ?? 1000
        item.length = min(max(80, width), min(360, available * 0.3))
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
