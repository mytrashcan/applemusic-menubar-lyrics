import AppKit
import LyricsCore

@MainActor
struct LyricTextLayout {
    struct Run {
        let word: LyricWord?
        let x: CGFloat
        let width: CGFloat
    }

    static let font = NSFont.systemFont(ofSize: 13)
    /// Shown before the text while playback is paused.
    static let pausePrefix = "Ⅱ "
    /// Joins overlapping lines (duets) into one menu bar string.
    static let lineSeparator = " / "

    let text: String
    let runs: [Run]
    let width: CGFloat
    let height: CGFloat
    let hasWordTiming: Bool
    let duration: Double

    /// The text the renderer draws: lyric lines when there are any, otherwise the fallback as is.
    static func text(lines: [LyricLine], fallback: String, isPlaying: Bool) -> String {
        lines.isEmpty ? fallback : prefix(lines: lines, isPlaying: isPlaying) + joined(lines)
    }

    /// The menu bar label: lyrics while they exist, otherwise the track title, both marked when paused.
    static func label(lines: [LyricLine], title: String, isPlaying: Bool) -> String {
        (isPlaying ? "" : pausePrefix) + (lines.isEmpty ? singleLine(title) : joined(lines))
    }

    /// Lines joined for tooltips and menus, keeping their own line breaks.
    static func fullText(_ lines: [LyricLine]) -> String {
        lines.map(\.text).joined(separator: lineSeparator)
    }

    private static func joined(_ lines: [LyricLine]) -> String {
        lines.map { singleLine($0.text) }.joined(separator: lineSeparator)
    }

    private static func prefix(lines: [LyricLine], isPlaying: Bool) -> String {
        !isPlaying && !lines.isEmpty ? pausePrefix : ""
    }

    init(lines: [LyricLine], fallback: String, isPlaying: Bool) {
        text = Self.text(lines: lines, fallback: fallback, isPlaying: isPlaying)
        hasWordTiming = lines.contains { !$0.words.isEmpty }
        duration = lines.map { $0.end - $0.start }.max() ?? 8
        let attributes: [NSAttributedString.Key: Any] = [.font: Self.font]
        let textSize = (text as NSString).size(withAttributes: attributes)
        width = textSize.width + 6
        height = textSize.height
        var result: [Run] = []
        var prefix = Self.prefix(lines: lines, isPlaying: isPlaying)
        if !prefix.isEmpty {
            result.append(Run(word: nil, x: 0, width: (prefix as NSString).size(withAttributes: attributes).width))
        }
        for line in lines {
            let source = Self.singleLine(line.text) as NSString
            let offset = (prefix as NSString).size(withAttributes: attributes).width
            if line.words.isEmpty {
                result.append(Run(word: nil, x: offset, width: source.size(withAttributes: attributes).width + 4))
            } else {
                for word in line.words where word.range.location >= 0 && NSMaxRange(word.range) <= source.length {
                    let before = source.substring(to: word.range.location) as NSString
                    let through = source.substring(to: NSMaxRange(word.range)) as NSString
                    let left = before.size(withAttributes: attributes).width
                    let right = through.size(withAttributes: attributes).width
                    result.append(Run(word: word, x: offset + left, width: max(0, right - left)))
                }
            }
            prefix += (source as String) + Self.lineSeparator
        }
        if lines.isEmpty { result.append(Run(word: nil, x: 0, width: width)) }
        runs = result
    }

    private static func singleLine(_ text: String) -> String {
        text.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ")
    }
}
