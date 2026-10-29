import AppKit
import LyricsCore

@MainActor
final class StatusWindow: NSWindowController {
    private let track = NSTextField(labelWithString: "Music Lyrics Bar")
    private let lyric = NSTextField(wrappingLabelWithString: "Music을 연결해 주세요.")
    private let status = NSTextField(wrappingLabelWithString: "")
    private let metrics = NSTextField(wrappingLabelWithString: "")
    private let connectButton: NSButton
    private let preview = StatusLyricView(frame: NSRect(x: 0, y: 0, width: 360, height: 24))
    private let widthControl = NSPopUpButton(frame: .zero, pullsDown: false)

    init(target: AnyObject, connect: Selector, reload: Selector, openMusic: Selector, changeWidth: Selector) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 450),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Music Lyrics Bar · 상태"
        window.isReleasedWhenClosed = false
        connectButton = NSButton(title: "Music 연결…", target: target, action: connect)
        super.init(window: window)
        track.font = .systemFont(ofSize: 14, weight: .semibold)
        track.lineBreakMode = .byTruncatingTail
        lyric.font = .systemFont(ofSize: 21, weight: .medium)
        lyric.setAccessibilityIdentifier("currentLyric")
        status.textColor = .secondaryLabelColor
        metrics.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        metrics.setAccessibilityIdentifier("playbackMetrics")
        for (title, width) in [("폭 240pt", 240.0), ("폭 360pt", 360.0), ("폭 600pt", 600.0)] {
            widthControl.addItem(withTitle: title)
            widthControl.lastItem?.representedObject = width
        }
        widthControl.target = target
        widthControl.action = changeWidth
        setWidth(UserDefaults.standard.double(forKey: "lyricsWidth"))
        let buttons = NSStackView(views: [connectButton,
            NSButton(title: "가사 다시 읽기", target: target, action: reload),
            NSButton(title: "Music 열기", target: target, action: openMusic), widthControl])
        buttons.spacing = 10
        let previewLabel = NSTextField(labelWithString: "메뉴바 미리보기 · 단어 타이밍이 있는 곡에서 밝기가 진행됩니다.")
        previewLabel.font = .systemFont(ofSize: 11)
        previewLabel.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [track, lyric, previewLabel, preview, status, metrics, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        let content = NSView()
        content.addSubview(stack)
        window.contentView = content
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -24),
            lyric.widthAnchor.constraint(equalTo: stack.widthAnchor),
            status.widthAnchor.constraint(equalTo: stack.widthAnchor),
            metrics.widthAnchor.constraint(equalTo: stack.widthAnchor),
            preview.widthAnchor.constraint(equalToConstant: 360),
            preview.heightAnchor.constraint(equalToConstant: 24)
        ])
        window.center()
    }

    required init?(coder: NSCoder) { nil }

    func update(track: String, lyric: String, status: String, metrics: String, connected: Bool) {
        if self.track.stringValue != track { self.track.stringValue = track }
        if self.lyric.stringValue != lyric { self.lyric.stringValue = lyric }
        if self.status.stringValue != status { self.status.stringValue = status }
        if self.metrics.stringValue != metrics { self.metrics.stringValue = metrics }
        let buttonTitle = connected ? "Music 다시 연결" : "Music 연결…"
        if connectButton.title != buttonTitle { connectButton.title = buttonTitle }
    }

    func present() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func updateKaraoke(lines: [LyricLine], fallback: String, position: Double, isPlaying: Bool) {
        guard window?.isVisible == true else { return }
        preview.update(lines: lines, fallback: fallback, position: position, isPlaying: isPlaying)
    }

    func setWidth(_ width: Double) {
        let index = [240.0, 360.0, 600.0].firstIndex(of: width) ?? 1
        widthControl.selectItem(at: index)
    }

}
