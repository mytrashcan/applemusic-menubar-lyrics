import AppKit
import Vision

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

// Use the app's real cache reader and TTML parser, including its on-disk
// payload resolution and its title/artist/album/duration matching rules.
func selectTrack(_ library: String) throws {
    let data = try Data(contentsOf: URL(fileURLWithPath: library))
    guard let columns = try JSONSerialization.jsonObject(with: data) as? [[Any]],
          columns.count == 5, columns.allSatisfy({ $0.count == columns[0].count }) else {
        fail("Music returned inconsistent library metadata. Run the capture again.")
    }
    let cache = MusicCache()
    for i in columns[0].indices {
        guard let id = columns[0][i] as? String, let title = columns[1][i] as? String,
              let artist = columns[2][i] as? String, let seconds = columns[4][i] as? Double else { continue }
        let track = Track(id: id, title: title, artist: artist, album: columns[3][i] as? String ?? "", duration: seconds)
        guard let lyrics = try cache.lyrics(for: track) else { continue }
        for line in lyrics.lines where line.words.count >= 4 && line.text.count >= 10 {
            let cue = line.words[line.words.count / 3].start
            guard cue >= 5, cue + 24 < seconds, line.end > cue + 0.5,
                  lyrics.lines.contains(where: { $0.start > cue && $0.start < cue + 14 && $0.words.count >= 2 }) else { continue }
            FileHandle.standardError.write(Data(
                "Selected \(title) — \(artist) (\(seconds)s) from \(columns[0].count) library tracks. The app matched its cached metadata, parsed \(line.words.count) timed spans on the opening line, and found another timed line within 14s of cue \(cue)s.\n".utf8))
            print(id)
            print(cue)
            return
        }
    }
    fail("No matching library track with a usable syllable-timed passage. See scripts/demo/README.md.")
}

func visibleWindows() -> [[String: Any]] {
    CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
}

func statusFrame(pid: Int) -> CGRect? {
    for window in visibleWindows() where window[kCGWindowOwnerPID as String] as? Int == pid {
        guard let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
              let x = bounds["X"], let y = bounds["Y"], let w = bounds["Width"], let h = bounds["Height"],
              y >= 0, y < 12, (180...650).contains(w), (16...50).contains(h),
              CGDisplayBounds(CGMainDisplayID()).contains(CGRect(x: x, y: y, width: w, height: h)) else { continue }
        return CGRect(x: x, y: y, width: w, height: h)
    }
    return nil
}

// Recent macOS versions composite items into the Window Server's Menubar.
// Locate the app's actual idle label when there is no per-item window.
func idleLabelRegion(in screenshot: String) throws -> String? {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: screenshot) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
    let screen = CGDisplayBounds(CGMainDisplayID())
    let scale = CGFloat(image.width) / screen.width
    let top = CGRect(x: 0, y: 0, width: CGFloat(image.width), height: 40 * scale)
    guard let strip = image.cropping(to: top) else { return nil }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    try VNImageRequestHandler(cgImage: strip).perform([request])
    for observation in request.results ?? [] {
        guard let candidate = observation.topCandidates(1).first,
              let phrase = candidate.string.range(of: "Waiting for Music", options: .caseInsensitive),
              let bounds = try candidate.boundingBox(for: phrase) else { continue }
        let left = Int(bounds.boundingBox.minX * screen.width) - 28
        guard left >= 0, left + 208 <= Int(screen.width) else { continue }
        return "\(left),0,208,124"
    }
    return nil
}

// An ordinary foreground reading window, owned only by this process. Its
// opaque document surface covers other apps across the capture rectangle.
func showDocument() {
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    guard let screen = NSScreen.screens.first else { fail("No main screen") }
    let window = NSWindow(contentRect: screen.visibleFrame, styleMask: [.titled, .closable, .resizable],
                          backing: .buffered, defer: false)
    window.title = "Field Notes"
    window.setFrame(screen.visibleFrame, display: true)
    let text = NSTextField(wrappingLabelWithString: """
        Field Notes

        The garden is quiet in the early morning. Rain gathers on the leaves before the paths begin to dry.

        Along the wall, new shoots lean toward the light. The first walkers pause at the gate.
        """)
    text.font = .systemFont(ofSize: 15)
    text.textColor = .labelColor
    guard let content = window.contentView, let x = Double(CommandLine.arguments[2]) else { fail("Missing document layout") }
    text.frame = CGRect(x: max(0, x - window.frame.minX + 8), y: content.bounds.height - 219, width: 255, height: 212)
    content.addSubview(text)
    window.makeKeyAndOrderFront(nil)
    app.activate(ignoringOtherApps: true)
    withExtendedLifetime(window) { app.run() }
}

let args = CommandLine.arguments
switch args.dropFirst().first {
case "select" where args.count == 3:
    try selectTrack(args[2])
case "region" where args.count == 4:
    if let pid = Int(args[2]), let frame = statusFrame(pid: pid) {
        print("\(Int(frame.minX)),0,\(Int(frame.width)),\(Int(frame.maxY) + 90)")
    } else if let region = try idleLabelRegion(in: args[3]) {
        print(region)
    } else {
        fail("Cannot locate the lyric window or Waiting for Music label. Check Automation, menu-bar placement and DEMO_REGION.")
    }
case "document" where args.count == 3:
    showDocument()
case "front":
    print(NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1)
case "display-width":
    print(Int(CGDisplayBounds(CGMainDisplayID()).width))
case "prompt":
    // Do not click, dismiss or obscure consent sheets.
    for w in visibleWindows() {
        let owner = w[kCGWindowOwnerName as String] as? String ?? ""
        if ["UserNotificationCenter", "SecurityAgent", "CoreServicesUIAgent"].contains(owner),
           (w[kCGWindowLayer as String] as? Int ?? 0) != 0 || owner != "UserNotificationCenter" {
            fail("A system dialog is visible (\(owner)). Stop and inspect it before continuing.")
        }
    }
default:
    fail("Expected select LIBRARY, region APP_PID, document X, front, or prompt")
}
