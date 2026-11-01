import AppKit
import LyricsCore

/// Cached text rasters carry alpha shading; macOS applies the native foreground color.
@MainActor
final class StatusImageRenderer {
    /// Geometry of the status image: a music note on the left, then a clipped text viewport.
    enum Metrics {
        static let iconSize: CGFloat = 16
        static let iconX: CGFloat = 3
        static let textX: CGFloat = 24
        static let textTrailingInset: CGFloat = 4
        static var textInsets: CGFloat { textX + textTrailingInset }
        /// Reveal widths are quantized to half points, the finest step a 2x display shows.
        static let revealScale: CGFloat = 2
        static let dimmedAlpha: CGFloat = 0.4
        /// Keep the word being sung around this fraction of the viewport from the left edge.
        static let sungAnchor: CGFloat = 0.7
        /// Redraw cadence while a word reveals or untimed text scrolls.
        static let animationInterval: TimeInterval = 0.1
        static let tickerPointsPerSecond: Double = 32
        /// Longer or taller text skips the raster cache and draws straight into the viewport.
        static let maximumRasterWidth: CGFloat = 4096
        static let maximumRasterHeight: CGFloat = 64
    }

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
        if !layout.hasWordTiming, layout.width > max(1, width - Metrics.textInsets),
           !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { return Metrics.animationInterval }
        var next = Double.infinity
        for run in layout.runs {
            guard let word = run.word, word.end > word.start else { continue }
            if word.start > position { next = min(next, word.start - position) }
            else if word.end > position { next = min(next, Metrics.animationInterval, word.end - position) }
        }
        return next.isFinite ? next : nil
    }

    /// Forces the next `image` call to return an image even when nothing changed, for a caller
    /// that showed something else meanwhile.
    func invalidate() {
        lastSize = .zero
    }

    /// Returns a new image when the visible pixels changed, or nil when the previous image is
    /// still correct and the caller should keep showing it.
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
            let pixels = Int((run.width * progress * Metrics.revealScale).rounded(.down))
            if revealedPixels[index] != pixels { revealedPixels[index] = pixels; pixelsChanged = true }
            if pixels > 0 { sungEdge = max(sungEdge, run.x + CGFloat(pixels) / Metrics.revealScale) }
        }
        let viewport = max(1, size.width - Metrics.textInsets)
        let overflow = max(0, layout.width - viewport)
        let offset: CGFloat
        if layout.hasWordTiming {
            offset = min(overflow, max(0, sungEdge - viewport * Metrics.sungAnchor))
        } else if isPlaying, overflow > 0, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            let travel = min(max(1, Double(overflow) / Metrics.tickerPointsPerSecond), max(2, layout.duration - 1))
            let elapsed = (ProcessInfo.processInfo.systemUptime - epoch).truncatingRemainder(dividingBy: 2 * (travel + 1))
            if elapsed < 1 { offset = 0 }
            else if elapsed < 1 + travel { offset = overflow * (elapsed - 1) / travel }
            else if elapsed < 2 + travel { offset = overflow }
            else { offset = overflow * (1 - (elapsed - 2 - travel) / travel) }
        } else { offset = 0 }
        let offsetPixel = Int(offset * Metrics.revealScale)
        guard changed || pixelsChanged || offsetPixel != lastOffset || size != lastSize else { return nil }
        lastOffset = offsetPixel
        lastSize = size
        if rasterHeight != size.height {
            rasterHeight = size.height
            dimmed = nil
            highlighted = nil
            if layout.width <= Metrics.maximumRasterWidth, size.height <= Metrics.maximumRasterHeight {
                dimmed = raster(layout: layout, height: size.height, alpha: Metrics.dimmedAlpha)
                highlighted = raster(layout: layout, height: size.height, alpha: 1)
            }
        }
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }
        icon?.draw(in: NSRect(x: Metrics.iconX, y: (size.height - Metrics.iconSize) / 2,
                              width: Metrics.iconSize, height: Metrics.iconSize))
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: NSRect(x: Metrics.textX, y: 0, width: viewport, height: size.height)).addClip()
        let origin = NSPoint(x: Metrics.textX - CGFloat(offsetPixel) / Metrics.revealScale, y: 0)
        drawText(raster: dimmed, layout: layout, origin: origin, height: size.height, alpha: Metrics.dimmedAlpha)
        let mask = NSBezierPath()
        for (index, run) in layout.runs.enumerated() where revealedPixels[index] > 0 {
            mask.appendRect(NSRect(x: origin.x + run.x, y: 0,
                                   width: CGFloat(revealedPixels[index]) / Metrics.revealScale, height: size.height))
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
