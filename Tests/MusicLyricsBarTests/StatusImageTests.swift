import AppKit
import Testing
import LyricsCore
@testable import MusicLyricsBar

struct StatusImageTests {
    @MainActor @Test func nativeTemplateImageRevealsSungWords() throws {
        let line = LyricLine(start: 1, end: 6, text: "Alpha Beta", words: [
            LyricWord(start: 1, end: 2, range: NSRange(location: 0, length: 5)),
            LyricWord(start: 3, end: 4, range: NSRange(location: 6, length: 4))
        ])
        let renderer = StatusImageRenderer()
        let size = NSSize(width: 180, height: 24)
        let before = try #require(renderer.image(lines: [line], fallback: "", position: 0, isPlaying: true, size: size))
        let partial = try #require(renderer.image(lines: [line], fallback: "", position: 2, isPlaying: true, size: size))
        let complete = try #require(renderer.image(lines: [line], fallback: "", position: 4, isPlaying: true, size: size))
        #expect(before.isTemplate && partial.isTemplate && complete.isTemplate)
        #expect(try textAlpha(before) < textAlpha(partial))
        #expect(try textAlpha(partial) < textAlpha(complete))
    }

    @MainActor private func textAlpha(_ image: NSImage) throws -> Double {
        let data = try #require(image.tiffRepresentation)
        let bitmap = try #require(NSBitmapImageRep(data: data))
        let start = Int(24 * CGFloat(bitmap.pixelsWide) / image.size.width)
        var alpha = 0.0
        for x in start..<bitmap.pixelsWide {
            for y in 0..<bitmap.pixelsHigh { alpha += Double(bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) }
        }
        return alpha
    }
}
