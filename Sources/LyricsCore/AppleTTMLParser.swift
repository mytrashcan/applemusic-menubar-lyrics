import Foundation

public enum TTMLParseError: Error, Equatable {
    case invalidXML
    case noTimedLines
}

/// Music's cached TTML uses song-absolute times, including on paragraphs inside timed divs.
/// This intentionally parses Apple's dialect, not every TTML timing/container mode.
public enum AppleTTMLParser {
    public static func parse(_ xml: String) throws -> Lyrics {
        let delegate = TimedTextDelegate()
        let parser = XMLParser(data: Data(xml.utf8))
        parser.shouldProcessNamespaces = true
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        guard parser.parse() else { throw TTMLParseError.invalidXML }
        guard !delegate.lines.isEmpty else { throw TTMLParseError.noTimedLines }
        return Lyrics(lines: delegate.lines)
    }

    public static func seconds(_ input: String) -> TimeInterval? {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasSuffix("ms") {
            return valid(Double(value.dropLast(2)).map { $0 / 1000 })
        }
        if value.hasSuffix("s") { return valid(Double(value.dropLast())) }
        let parts = value.split(separator: ":", omittingEmptySubsequences: false)
        guard (1...3).contains(parts.count) else { return nil }
        let numbers = parts.compactMap { Double($0) }
        guard numbers.count == parts.count,
              numbers.allSatisfy({ $0.isFinite && $0 >= 0 }),
              numbers.dropFirst().allSatisfy({ $0 < 60 }) else { return nil }
        return valid(numbers.reduce(0) { $0 * 60 + $1 })
    }

    private static func valid(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value >= 0 else { return nil }
        return value
    }
}

private final class TimedTextDelegate: NSObject, XMLParserDelegate {
    private struct Span {
        let start: Double?
        let end: Double?
        let offset: Int
        var hasTimedChild = false
    }
    var lines: [LyricLine] = []
    private var inBody = false
    private var paragraph: (start: Double?, end: Double?, text: String)?
    private var words: [LyricWord] = []
    private var spans: [Span] = []

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String]) {
        if name == "body" { inBody = true }
        guard inBody else { return }
        if name == "p" {
            let start = attributes["begin"].flatMap(AppleTTMLParser.seconds)
            var end = attributes["end"].flatMap(AppleTTMLParser.seconds)
            if end == nil, let start, let duration = attributes["dur"].flatMap(AppleTTMLParser.seconds) {
                end = start + duration
            }
            paragraph = (start, end, "")
            words = []
            spans = []
        } else if name == "span", let paragraph {
            let start = attributes["begin"].flatMap(AppleTTMLParser.seconds)
            var end = attributes["end"].flatMap(AppleTTMLParser.seconds)
            if end == nil, let start, let duration = attributes["dur"].flatMap(AppleTTMLParser.seconds) {
                end = start + duration
            }
            if let start, let end, end > start {
                for index in spans.indices { spans[index].hasTimedChild = true }
            }
            spans.append(Span(start: start, end: end, offset: paragraph.text.utf16.count))
        } else if name == "br" {
            paragraph?.text += "\n"
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        paragraph?.text += string
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        if name == "span", let span = spans.popLast(), let paragraph,
           !span.hasTimedChild, let start = span.start, let end = span.end, end > start {
            let length = paragraph.text.utf16.count - span.offset
            if length > 0 {
                words.append(LyricWord(start: start, end: end, range: NSRange(location: span.offset, length: length)))
            }
        }
        if name == "p", let current = paragraph {
            let text = current.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if let start = current.start, let end = current.end,
               end > start, !text.isEmpty {
                let contentRange = (current.text as NSString).range(of: text)
                let adjustedWords = words.compactMap { word -> LyricWord? in
                    let range = NSIntersectionRange(word.range, contentRange)
                    guard range.length > 0 else { return nil }
                    return LyricWord(start: word.start, end: word.end,
                                     range: NSRange(location: range.location - contentRange.location, length: range.length))
                }.sorted { $0.range.location < $1.range.location }
                lines.append(LyricLine(start: start, end: end, text: text, words: adjustedWords))
            }
            paragraph = nil
        }
        if name == "body" { inBody = false }
    }
}
