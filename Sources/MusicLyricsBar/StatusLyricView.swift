import AppKit
import LyricsCore
import QuartzCore

/// Dim original text is revealed by a compositor mask using Apple's timed spans.
/// Interpolation inside a span does not invent word timestamps.
@MainActor
final class StatusLyricView: NSView {
    var animatesTransitions = true

    private let icon = NSImageView()
    private let dimmed = NSTextField(labelWithString: "")
    private let highlighted = NSTextField(labelWithString: "")
    private let highlightMask = CAShapeLayer()
    private let textClip = NSView()
    private let textContent = NSView()
    private var displayedLines: [LyricLine] = []
    private var runs: [LyricTextLayout.Run] = []
    private var previousProgress: [Double] = []
    private var previousPosition: Double?
    private let font = NSFont.systemFont(ofSize: 13)
    private var textWidth: CGFloat = 0
    private var previousViewport: NSSize = .zero
    private var hasWordTiming = false
    private var lineDuration = 8.0
    private var followOffset: CGFloat = 0
    private var scrollEpoch = 0.0
    private var scrollTravel = 1.0

    override init(frame: NSRect) {
        super.init(frame: frame)
        autoresizingMask = [.width, .height]
        icon.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)
        icon.contentTintColor = .labelColor
        addSubview(icon)
        textClip.wantsLayer = true
        textClip.layer?.masksToBounds = true
        textContent.wantsLayer = true
        addSubview(textClip)
        textClip.addSubview(textContent)
        for label in [dimmed, highlighted] {
            label.font = font
            label.lineBreakMode = .byClipping
            label.maximumNumberOfLines = 1
            label.wantsLayer = true
            textContent.addSubview(label)
        }
        dimmed.textColor = NSColor.labelColor.withAlphaComponent(0.4)
        highlighted.textColor = .labelColor
        highlightMask.fillColor = NSColor.black.cgColor
        highlighted.layer?.mask = highlightMask
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        let iconFrame = NSRect(x: 3, y: (bounds.height - 16) / 2, width: 16, height: 16)
        if icon.frame != iconFrame { icon.frame = iconFrame }
        let textFrame = NSRect(x: 24, y: (bounds.height - 17) / 2, width: max(0, bounds.width - 28), height: 17)
        if textClip.frame != textFrame { textClip.frame = textFrame }
        let contentFrame = NSRect(x: 0, y: 0, width: max(textWidth, textFrame.width), height: 17)
        if textContent.frame != contentFrame { textContent.frame = contentFrame }
        let labelFrame = NSRect(origin: .zero, size: contentFrame.size)
        if dimmed.frame != labelFrame { dimmed.frame = labelFrame }
        if highlighted.frame != labelFrame { highlighted.frame = labelFrame }
        if highlightMask.frame != highlighted.bounds {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            highlightMask.frame = highlighted.bounds
            CATransaction.commit()
            previousProgress = []
        }
        if previousViewport != textClip.bounds.size {
            previousViewport = textClip.bounds.size
            configureScrolling()
        }
    }

    // Leave all menu interaction to the native NSStatusBarButton.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func update(lines: [LyricLine], fallback: String, position: Double, isPlaying: Bool) {
        let pausePrefix = !isPlaying && !lines.isEmpty ? "Ⅱ " : ""
        let text = lines.isEmpty ? fallback : pausePrefix + lines.map { Self.singleLine($0.text) }.joined(separator: " / ")
        let changed = displayedLines != lines || dimmed.stringValue != text
        if changed {
            displayedLines = lines
            dimmed.stringValue = text
            highlighted.stringValue = text
            runs = makeRuns(lines: lines, fallback: text, prefix: pausePrefix)
            textWidth = (text as NSString).size(withAttributes: [.font: font]).width + 6
            hasWordTiming = lines.contains { !$0.words.isEmpty }
            lineDuration = lines.map { $0.end - $0.start }.max() ?? 8
            needsLayout = true
            configureScrolling()
            previousProgress = []
        }
        let progress = runs.map { $0.word?.progress(at: position) ?? 1 }
        if !animatesTransitions && !hasWordTiming { updateTicker() }
        defer { previousPosition = position }
        guard progress != previousProgress else { return }
        previousProgress = progress
        updateFollow(progress: progress, isPlaying: isPlaying)
        let path = CGMutablePath()
        for (index, run) in runs.enumerated() {
            path.addRect(CGRect(x: 2 + run.x, y: 0, width: run.width * progress[index], height: 24))
        }
        let advancingNormally = previousPosition.map { position >= $0 && position - $0 < 0.3 } ?? false
        let animate = animatesTransitions && !changed && isPlaying && advancingNormally &&
            !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let oldPath = highlightMask.presentation()?.path ?? highlightMask.path
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        highlightMask.path = path
        CATransaction.commit()
        highlightMask.removeAnimation(forKey: "singing")
        if animate, let oldPath {
            let animation = CABasicAnimation(keyPath: "path")
            animation.fromValue = oldPath
            animation.toValue = path
            animation.duration = 0.1
            animation.timingFunction = CAMediaTimingFunction(name: .linear)
            highlightMask.add(animation, forKey: "singing")
        }
    }

    private func configureScrolling() {
        textContent.layer?.removeAnimation(forKey: "marquee")
        textContent.layer?.removeAnimation(forKey: "follow")
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        textContent.layer?.transform = CATransform3DIdentity
        CATransaction.commit()
        followOffset = 0
        previousProgress = []
        let distance = max(0, textWidth - textClip.bounds.width)
        guard distance > 1, !hasWordTiming,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        let pause = 1.0
        let travel = min(max(1, Double(distance) / 32), max(2, lineDuration - pause))
        scrollEpoch = ProcessInfo.processInfo.systemUptime
        scrollTravel = travel
        guard animatesTransitions else { return }
        let duration = 2 * (travel + pause)
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.values = [0, 0, -distance, -distance, 0]
        animation.keyTimes = [0, NSNumber(value: pause / duration),
                             NSNumber(value: (pause + travel) / duration),
                             NSNumber(value: (2 * pause + travel) / duration), 1]
        animation.duration = duration
        animation.repeatCount = .infinity
        textContent.layer?.add(animation, forKey: "marquee")
    }

    private func updateFollow(progress: [Double], isPlaying: Bool) {
        guard hasWordTiming else { return }
        let sungEdge = runs.enumerated().filter { progress[$0.offset] > 0 }
            .map { $0.element.x + $0.element.width * progress[$0.offset] }.max() ?? 0
        let target = min(max(0, textWidth - textClip.bounds.width), max(0, sungEdge - textClip.bounds.width * 0.7))
        guard abs(target - followOffset) > 0.25 else { return }
        let oldOffset = (textContent.layer?.presentation()?.transform.m41) ?? -followOffset
        followOffset = target
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        textContent.layer?.transform = CATransform3DMakeTranslation(-target, 0, 0)
        CATransaction.commit()
        textContent.layer?.removeAnimation(forKey: "follow")
        if animatesTransitions && isPlaying && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            let animation = CABasicAnimation(keyPath: "transform.translation.x")
            animation.fromValue = oldOffset
            animation.toValue = -target
            animation.duration = 0.12
            textContent.layer?.add(animation, forKey: "follow")
        }
    }

    private func updateTicker() {
        let distance = max(0, textWidth - textClip.bounds.width)
        guard distance > 1, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        let elapsed = (ProcessInfo.processInfo.systemUptime - scrollEpoch)
            .truncatingRemainder(dividingBy: 2 * (scrollTravel + 1))
        let fraction: Double
        if elapsed < 1 { fraction = 0 }
        else if elapsed < 1 + scrollTravel { fraction = (elapsed - 1) / scrollTravel }
        else if elapsed < 2 + scrollTravel { fraction = 1 }
        else { fraction = 1 - (elapsed - 2 - scrollTravel) / scrollTravel }
        let target = distance * fraction
        guard abs(target - followOffset) > 0.25 else { return }
        followOffset = target
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        textContent.layer?.transform = CATransform3DMakeTranslation(-target, 0, 0)
        CATransaction.commit()
    }

    private func makeRuns(lines: [LyricLine], fallback: String, prefix: String) -> [LyricTextLayout.Run] {
        LyricTextLayout(lines: lines, fallback: fallback, isPlaying: prefix.isEmpty).runs
    }

    private static func singleLine(_ text: String) -> String {
        text.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ")
    }
}
