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
    var lines: [LyricLine] = []
    private var inBody = false
    private var paragraph: (start: Double?, end: Double?, text: String)?

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
        } else if name == "br" {
            paragraph?.text += "\n"
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        paragraph?.text += string
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        if name == "p", let current = paragraph {
            let text = current.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if let start = current.start, let end = current.end,
               end > start, !text.isEmpty {
                lines.append(LyricLine(start: start, end: end, text: text))
            }
            paragraph = nil
        }
        if name == "body" { inBody = false }
    }
}
