import AppKit
import LyricsCore

/// Cached text rasters carry alpha shading; macOS applies the native foreground color.
@MainActor
final class StatusImageRenderer {
    private var lines: [LyricLine] = []
    private var layout: LyricTextLayout?
    private var playing = false
    private var fallback = ""
    private var epoch = 0.0
    private var revealedPixels: [Int] = []
    private var lastOffset = -1
    private var lastSize = NSSize.zero
    private var rasterHeight: CGFloat = 0
    private var dimmed: NSImage?
    private var highlighted: NSImage?
    private let icon = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)

    /// No display wakeups while paused, between words, or after a completed phrase.
    func nextUpdateDelay(at position: Double, isPlaying: Bool, width: CGFloat) -> Double? {
        guard isPlaying, let layout else { return nil }
        if !layout.hasWordTiming, layout.width > max(1, width - 28),
           !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { return 0.1 }
        var next = Double.infinity
        for run in layout.runs {
            guard let word = run.word, word.end > word.start else { continue }
            if word.start > position { next = min(next, word.start - position) }
            else if word.end > position { next = min(next, 0.1, word.end - position) }
        }
        return next.isFinite ? next : nil
    }

    func image(lines: [LyricLine], fallback: String, position: Double, isPlaying: Bool, size: NSSize) -> NSImage? {
        let changed = self.lines != lines || playing != isPlaying || (lines.isEmpty && self.fallback != fallback)
        if changed || layout == nil {
            self.lines = lines
            self.playing = isPlaying
            self.fallback = lines.isEmpty ? fallback : ""
            layout = LyricTextLayout(lines: lines, fallback: fallback, isPlaying: isPlaying)
            epoch = ProcessInfo.processInfo.systemUptime
            revealedPixels = Array(repeating: -1, count: layout?.runs.count ?? 0)
            rasterHeight = 0
        }
        guard let layout else { return nil }
        var pixelsChanged = false
        var sungEdge: CGFloat = 0
        for (index, run) in layout.runs.enumerated() {
            let progress = run.word?.progress(at: position) ?? 1
            let pixels = Int((run.width * progress * 2).rounded(.down))
            if revealedPixels[index] != pixels { revealedPixels[index] = pixels; pixelsChanged = true }
            if pixels > 0 { sungEdge = max(sungEdge, run.x + CGFloat(pixels) / 2) }
        }
        let viewport = max(1, size.width - 28)
        let overflow = max(0, layout.width - viewport)
        let offset: CGFloat
        if layout.hasWordTiming {
            offset = min(overflow, max(0, sungEdge - viewport * 0.7))
        } else if isPlaying, overflow > 0, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            let travel = min(max(1, Double(overflow) / 32), max(2, layout.duration - 1))
            let elapsed = (ProcessInfo.processInfo.systemUptime - epoch).truncatingRemainder(dividingBy: 2 * (travel + 1))
            if elapsed < 1 { offset = 0 }
            else if elapsed < 1 + travel { offset = overflow * (elapsed - 1) / travel }
            else if elapsed < 2 + travel { offset = overflow }
            else { offset = overflow * (1 - (elapsed - 2 - travel) / travel) }
        } else { offset = 0 }
        let offsetPixel = Int(offset * 2)
        guard changed || pixelsChanged || offsetPixel != lastOffset || size != lastSize else { return nil }
        lastOffset = offsetPixel
        lastSize = size
        if rasterHeight != size.height {
            rasterHeight = size.height
            // Bound raster storage for unusual, very long source lines. Those
            // lines fall back to drawing directly into the bounded viewport.
            dimmed = nil
            highlighted = nil
            if layout.width <= 4096, size.height <= 64 {
                dimmed = raster(layout: layout, height: size.height, alpha: 0.4)
                highlighted = raster(layout: layout, height: size.height, alpha: 1)
            }
        }
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }
        icon?.draw(in: NSRect(x: 3, y: (size.height - 16) / 2, width: 16, height: 16))
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: NSRect(x: 24, y: 0, width: viewport, height: size.height)).addClip()
        let origin = NSPoint(x: 24 - CGFloat(offsetPixel) / 2, y: 0)
        drawText(raster: dimmed, layout: layout, origin: origin, height: size.height, alpha: 0.4)
        let mask = NSBezierPath()
        for (index, run) in layout.runs.enumerated() where revealedPixels[index] > 0 {
            mask.appendRect(NSRect(x: origin.x + run.x, y: 0,
                                   width: CGFloat(revealedPixels[index]) / 2, height: size.height))
        }
        if !mask.isEmpty {
            mask.addClip()
            drawText(raster: highlighted, layout: layout, origin: origin, height: size.height, alpha: 1)
        }
        NSGraphicsContext.restoreGraphicsState()
        image.isTemplate = true
        return image
    }

    private func raster(layout: LyricTextLayout, height: CGFloat, alpha: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: layout.width, height: height))
        image.lockFocus()
        drawText(raster: nil, layout: layout, origin: .zero, height: height, alpha: alpha)
        image.unlockFocus()
        return image
    }

    private func drawText(raster: NSImage?, layout: LyricTextLayout, origin: NSPoint, height: CGFloat, alpha: CGFloat) {
        if let raster { raster.draw(at: origin, from: .zero, operation: .sourceOver, fraction: 1) }
        else {
            (layout.text as NSString).draw(at: NSPoint(x: origin.x, y: (height - layout.height) / 2),
                withAttributes: [.font: LyricTextLayout.font, .foregroundColor: NSColor.black.withAlphaComponent(alpha)])
        }
    }
}
