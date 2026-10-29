import Testing
@testable import LyricsCore

struct TimedLyricsTests {
    @Test func testAppleAbsoluteTimesNestedSpansEntitiesAndMetadata() throws {
        let xml = """
        <tt xmlns="http://www.w3.org/ns/ttml"><head><metadata>
        <p begin="0" end="90">Not lyrics</p></metadata></head>
        <body dur="1:00"><div begin="10" end="30">
        <p begin="10.25" end="12"><span>Original</span> <span>words &amp; 音楽</span></p>
        <p begin="14" dur="2">Next<br/>line</p>
        </div></body></tt>
        """
        let lyrics = try AppleTTMLParser.parse(xml)
        #expect(lyrics.lines == [
            LyricLine(start: 10.25, end: 12, text: "Original words & 音楽"),
            LyricLine(start: 14, end: 16, text: "Next\nline")
        ])
        #expect(lyrics.activeLines(at: 10).isEmpty)
        #expect(lyrics.activeLines(at: 10.25).count == 1)
        #expect(lyrics.activeLines(at: 12).isEmpty)
        #expect(lyrics.activeLines(at: 14).first?.text == "Next\nline")
        #expect(lyrics.activeLines(at: 16).isEmpty)
    }

    @Test func testClockFormatsAndInvalidTimes() {
        for (source, expected) in [("00:01:02.345", 62.345), ("1:02.345", 62.345),
                                   ("62.345", 62.345), ("234ms", 0.234), ("3.5s", 3.5)] {
            #expect(abs(AppleTTMLParser.seconds(source)! - expected) < 0.00001)
        }
        for value in ["", "NaN", "inf", "-1", "1:60", "1::2", "00:00:00:24", "-2ms"] {
            #expect(AppleTTMLParser.seconds(value) == nil, "Invalid time: \(value)")
        }
    }

    @Test func testRejectsMalformedAndUntimedDocuments() {
        #expect(throws: (any Error).self) { try AppleTTMLParser.parse("<tt><body>") }
        #expect(throws: (any Error).self) { try AppleTTMLParser.parse("<tt><body><p>Untimed</p></body></tt>") }
        #expect(throws: (any Error).self) { try AppleTTMLParser.parse("<tt><body><p begin=\"3\" end=\"2\">Invalid</p></body></tt>") }
    }

    @Test func testDuetsAndBackwardsSeek() {
        let lyrics = Lyrics(lines: [LyricLine(start: 5, end: 8, text: "Second voice"),
                                    LyricLine(start: 2, end: 6, text: "First voice")])
        #expect(lyrics.activeLines(at: 5).map(\.text) == ["First voice", "Second voice"])
        #expect(lyrics.activeLines(at: 2).map(\.text) == ["First voice"])
        #expect(lyrics.activeLines(at: .nan).isEmpty)
    }

    @Test func testPlaybackClockPausesSeeksAndBoundsStaleSamples() {
        let track = Track(id: "test", title: "Example", artist: "Example", album: "", duration: 30)
        let playing = PlaybackSample(track: track, position: 10, isPlaying: true, sampledAt: 100)
        #expect(abs(playing.position(at: 100.4) - 10.4) < 0.001)
        #expect(playing.position(at: 110) == 11.5)
        let paused = PlaybackSample(track: track, position: 4, isPlaying: false, sampledAt: 101)
        #expect(paused.position(at: 110) == 4)
        let end = PlaybackSample(track: track, position: 29.8, isPlaying: true, sampledAt: 100)
        #expect(end.position(at: 101) == 30)
    }
}
