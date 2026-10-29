import AppKit
import LyricsCore

/// Template alpha carries both lyric shades, so macOS applies its own menu-bar
/// foreground color. Native images avoid macOS 27's custom-view snapshot loop.
@MainActor
final class StatusImageRenderer {
    private var lines: [LyricLine] = []
    private var layout: LyricTextLayout?
    private var epoch = 0.0
    private var lastProgress: [Double] = []
    private var lastOffset = -1
    private var lastSize = NSSize.zero
    private let icon = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)

    func image(lines: [LyricLine], fallback: String, position: Double, isPlaying: Bool, size: NSSize) -> NSImage? {
        let text = LyricTextLayout.text(lines: lines, fallback: fallback, isPlaying: isPlaying)
        let changed = self.lines != lines || layout?.text != text
        if changed {
            self.lines = lines
            layout = LyricTextLayout(lines: lines, fallback: fallback, isPlaying: isPlaying)
            epoch = ProcessInfo.processInfo.systemUptime
        }
        guard let layout else { return nil }
        let progress = layout.runs.map { $0.word?.progress(at: position) ?? 1 }
        let viewport = max(1, size.width - 28)
        let overflow = max(0, layout.width - viewport)
        let offset: CGFloat
        if layout.hasWordTiming {
            let sungEdge = layout.runs.enumerated().filter { progress[$0.offset] > 0 }
                .map { $0.element.x + $0.element.width * progress[$0.offset] }.max() ?? 0
            offset = min(overflow, max(0, sungEdge - viewport * 0.7))
        } else if overflow > 0, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            let travel = min(max(1, Double(overflow) / 32), max(2, layout.duration - 1))
            let elapsed = (ProcessInfo.processInfo.systemUptime - epoch).truncatingRemainder(dividingBy: 2 * (travel + 1))
            if elapsed < 1 { offset = 0 }
            else if elapsed < 1 + travel { offset = overflow * (elapsed - 1) / travel }
            else if elapsed < 2 + travel { offset = overflow }
            else { offset = overflow * (1 - (elapsed - 2 - travel) / travel) }
        } else { offset = 0 }
        let offsetPixel = Int(offset * 2)
        guard changed || progress != lastProgress || offsetPixel != lastOffset || size != lastSize else { return nil }
        lastProgress = progress
        lastOffset = offsetPixel
        lastSize = size
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }
        icon?.draw(in: NSRect(x: 3, y: (size.height - 16) / 2, width: 16, height: 16))
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: NSRect(x: 24, y: 0, width: viewport, height: size.height)).addClip()
        let source = layout.text as NSString
        let textHeight = source.size(withAttributes: [.font: LyricTextLayout.font]).height
        let origin = NSPoint(x: 24 - offset, y: (size.height - textHeight) / 2)
        source.draw(at: origin, withAttributes: [.font: LyricTextLayout.font,
                                                .foregroundColor: NSColor.black.withAlphaComponent(0.4)])
        let mask = NSBezierPath()
        for (index, run) in layout.runs.enumerated() where progress[index] > 0 {
            mask.appendRect(NSRect(x: origin.x + run.x, y: 0, width: run.width * progress[index], height: size.height))
        }
        if !mask.isEmpty {
            mask.addClip()
            source.draw(at: origin, withAttributes: [.font: LyricTextLayout.font, .foregroundColor: NSColor.black])
        }
        NSGraphicsContext.restoreGraphicsState()
        image.isTemplate = true
        return image
    }
}
