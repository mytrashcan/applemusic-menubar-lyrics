#!/usr/bin/env python3
"""Compare the current native renderer with v0.0.2 using synthetic timed lyrics."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--frames", type=int, default=12000)
    args = parser.parse_args()
    if args.frames <= 0:
        parser.error("--frames must be positive")
    old = subprocess.check_output(
        ["git", "show", "v0.0.2:Sources/MusicLyricsBar/StatusImageRenderer.swift"], cwd=ROOT, text=True
    )
    new = (ROOT / "Sources/MusicLyricsBar/StatusImageRenderer.swift").read_text()
    model = (ROOT / "Sources/LyricsCore/Lyrics.swift").read_text()
    layout = (ROOT / "Sources/MusicLyricsBar/LyricTextLayout.swift").read_text()
    with tempfile.TemporaryDirectory(prefix="lyrics-render-benchmark-") as temporary:
        folder = Path(temporary)
        parts = [model, layout, old.replace("class StatusImageRenderer", "class BaselineRenderer"),
                 new.replace("class StatusImageRenderer", "class OptimizedRenderer")]
        sources = []
        for i, part in enumerate(parts):
            path = folder / f"Source{i}.swift"
            path.write_text(part.replace("import LyricsCore\n", ""))
            sources.append(str(path))
        main_source = folder / "Benchmark.swift"
        main_source.write_text('''import AppKit
import Darwin

@main enum Benchmark {
    @MainActor static func main() {
        let frames = Int(CommandLine.arguments[2])!
        let baseline = CommandLine.arguments[1] == "baseline"
        let old = baseline ? BaselineRenderer() : nil
        let new = baseline ? nil : OptimizedRenderer()
        let text = Array(repeating: "Synthetic", count: 20).joined(separator: " ")
        let phrases = (0..<50).map { phrase -> [LyricLine] in
            let start = Double(phrase * 24)
            let words = (0..<20).map { LyricWord(start: start + Double($0), end: start + Double($0) + 0.8,
                                                 range: NSRange(location: $0 * 10, length: 9)) }
            return [LyricLine(start: start, end: start + 24, text: text, words: words)]
        }
        let size = NSSize(width: 200, height: 24)
        var first = rusage()
        getrusage(RUSAGE_SELF, &first)
        let started = ProcessInfo.processInfo.systemUptime
        var images = 0
        for frame in 0..<frames {
            autoreleasepool {
                let phrase = (frame / 240) % phrases.count
                let position = Double(phrase * 240 + frame % 240) / 10
                let lines = phrases[phrase]
                let image: NSImage?
                if let old { image = old.image(lines: lines, fallback: "", position: position, isPlaying: true, size: size) }
                else { image = new!.image(lines: lines, fallback: "", position: position, isPlaying: true, size: size) }
                if image != nil { images += 1 }
            }
        }
        var last = rusage()
        getrusage(RUSAGE_SELF, &last)
        let cpu = Double(last.ru_utime.tv_sec - first.ru_utime.tv_sec + last.ru_stime.tv_sec - first.ru_stime.tv_sec)
            + Double(last.ru_utime.tv_usec - first.ru_utime.tv_usec + last.ru_stime.tv_usec - first.ru_stime.tv_usec) / 1e6
        let result: [String: Any] = ["frames": frames, "images": images, "cpu_seconds": cpu,
            "wall_seconds": ProcessInfo.processInfo.systemUptime - started,
            "cpu_microseconds_per_frame": cpu * 1e6 / Double(frames)]
        print(String(data: try! JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]), encoding: .utf8)!)
    }
}
''')
        binary = folder / "benchmark"
        subprocess.run(["swiftc", "-O", "-parse-as-library", *sources, str(main_source), "-o", str(binary)], check=True)
        results = {}
        for variant in ("baseline", "optimized"):
            results[variant] = json.loads(subprocess.check_output([str(binary), variant, str(args.frames)], text=True))
        print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
