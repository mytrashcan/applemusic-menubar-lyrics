# LEARN.md — Build a macOS menu bar lyrics app from scratch

Music Lyrics Bar shows Apple Music lyrics in the menu bar, with the words already
sung drawn brighter than the words still coming. It never touches the network and
never writes to Apple's cache: it reads the track and playback position through
Apple Events, opens Music's local lyrics cache read-only, parses the TTML inside,
and rasterizes one line into a status item image.

This guide rebuilds it component by component, with the files to read and the
commands to run. It is a learning document: it includes the dead ends.

Read the [README](README.md) if you just want to install the app.

---

## What you will learn

- How to read a private Apple cache safely, and why "read-only" is a design
  requirement rather than a nice property.
- How to talk to Music with native Apple Events instead of AppleScript, and why
  that is roughly three times faster per read.
- How to parse Apple's TTML lyrics (lines, words, syllable spans) with `XMLParser`.
- How to draw partially highlighted text into a menu bar item without burning CPU.
- How to schedule polling around playback events instead of a fixed timer.
- How to package a SwiftPM executable as a `.app` with ad-hoc signing.

## What you need

| Requirement | Notes |
| --- | --- |
| macOS 13+ | `Package.swift` declares `.macOS(.v13)` |
| Xcode 15+ or Command Line Tools with Swift 6 | `swift --version` should print 6.x |
| Music.app with lyrics you can open | the app has nothing to show otherwise |
| One song with cached lyrics | open the lyrics panel once in Music |

No third-party dependencies. That is deliberate: the app exists to be small,
offline, and reviewable.

Time: an afternoon for a working prototype, a weekend for the scheduling and
rendering work that makes it quiet.

---

## How the pieces fit

```text
Music.app ── Apple Events ──► track / position ─┐
                                                │
Music cache (SQLite, read-only) ──► match ──► TTML parse ──► Lyrics model
                                                │
                                     menu bar rendering ──► NSStatusItem
```

| Module | File(s) | Responsibility |
| --- | --- | --- |
| Lyrics model | `Sources/LyricsCore/Lyrics.swift` | `Track`, `LyricLine`, `LyricWord`, `Lyrics`, playback math |
| TTML parser | `Sources/LyricsCore/AppleTTMLParser.swift` | XML → timed lines and spans |
| Cache reader | `Sources/LyricsCore/MusicCache.swift` | SQLite read-only scan, payload matching |
| Music reader | `Sources/MusicLyricsBar/MusicReader.swift` | native Apple Events reads |
| Scheduling | `Sources/MusicLyricsBar/Scheduling.swift` | poll policy, cache rescan policy |
| Rendering | `Sources/MusicLyricsBar/StatusImageRenderer.swift`, `LyricTextLayout.swift` | rasterized status item images |
| Menu bar | `Sources/MusicLyricsBar/App.swift`, `MenuBarFit.swift` | status item, shrinking, popover |
| Packaging | `scripts/build-app.sh`, `Resources/Info.plist` | `.app`, codesign, zip |

Two targets: `LyricsCore` is a library with no AppKit dependency, so it is
testable in isolation; `MusicLyricsBar` is the executable.

---

## Step 1 — Find out what Music leaves on disk

Before writing code, look at the data. Apple Music does not expose lyrics through
an API, but when a song's lyrics are displayed once, Music caches the response in
its URL cache:

```text
~/Library/Caches/com.apple.Music/Cache.db
~/Library/Caches/com.apple.Music/fsCachedData/
```

Open a copy, not the live file, and look at the schema:

```bash
sqlite3 ~/Library/Caches/com.apple.Music/Cache.db \
  ".tables" \
  "SELECT count(*) FROM cfurl_cache_response;"
```

Two tables matter: `cfurl_cache_response` (the request key and timestamp) and
`cfurl_cache_receiver_data` (the payload, either a blob or a file on disk flagged
by `isDataOnFS`). Lyrics responses are the ones whose `request_key` mentions
lyrics. The payload is JSON shaped roughly like:

```text
{ "data": [ { "attributes": {...},
              "relationships": {
                "syllable-lyrics": { "data": [ { "attributes": { "ttml": "<tt ...>" } } ] },
                "lyrics":          { "data": [ ... ] } } } ] }
```

`ttml` (or `ttmlLocalizations`) is the actual timed lyric document.

Write down three rules before you write a line of Swift:

1. **Read-only.** `sqlite3_open_v2(..., SQLITE_OPEN_READONLY, ...)`. Never write,
   never "repair", never migrate Apple's database.
2. **Minimum data.** Do not read account tokens, request headers, or the Music
   library database. You need response index rows and payloads, nothing else.
3. **Bounded work.** The cache can be large and old. Scan only recent
   lyrics-looking rows with a hard limit (this project uses 512), and check for
   cancellation between rows.

That is the whole privacy story of the app, and it belongs in the code, not only
in the README.

---

## Step 2 — Scaffold the Swift package

`Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MusicLyricsBar",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "MusicLyricsBar", targets: ["MusicLyricsBar"]),
        .library(name: "LyricsCore", targets: ["LyricsCore"]),
    ],
    targets: [
        .systemLibrary(name: "CSQLite"),
        .target(name: "LyricsCore", dependencies: ["CSQLite"]),
        .executableTarget(name: "MusicLyricsBar", dependencies: ["LyricsCore"]),
        .testTarget(name: "LyricsCoreTests", dependencies: ["LyricsCore", "CSQLite"]),
        .testTarget(name: "MusicLyricsBarTests", dependencies: ["MusicLyricsBar", "LyricsCore"]),
    ]
)
```

`Sources/CSQLite/module.modulemap` exposes the system library:

```text
module CSQLite [system] {
    header "shim.h"
    link "sqlite3"
    export *
}
```

`shim.h` just includes `<sqlite3.h>`. Doing it this way avoids a package
dependency for one C library, and keeps the "no dependencies" property.

**Pitfall worth copying:** some Command Line Tools releases ship the Swift Testing
macros but not their plugin search path. `scripts/test.sh` detects a CLT toolchain
and passes `-load-plugin-library` explicitly:

```bash
developer_dir="$(xcode-select -p)"
testing_plugin="$developer_dir/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
if [[ "$developer_dir" == */CommandLineTools && -f "$testing_plugin" ]]; then
    swift test --disable-xctest -Xswiftc -load-plugin-library -Xswiftc "$testing_plugin" "$@"
else
    swift test --disable-xctest "$@"
fi
```

---

## Step 3 — Model the lyrics, then parse TTML

Start with the model you wish you had, and let the parser fill it.

```swift
public struct LyricWord: Equatable, Sendable {
    public let start: TimeInterval
    public let end: TimeInterval
    public let range: NSRange      // range inside the line's text
}

public struct LyricLine: Equatable, Sendable {
    public let start: TimeInterval
    public let end: TimeInterval
    public let text: String
    public let words: [LyricWord]
}
```

Two decisions in that shape:

- `range` is an `NSRange` into the line's text, not a substring per word. One
  attributed string per line, shaded by ranges, is far cheaper to draw than one
  draw call per word.
- Words are optional (empty array). Plenty of sources only provide line timing;
  the app then shades whole lines instead of pretending to know word boundaries.

The parser (`AppleTTMLParser`) is a small `XMLParser` delegate: track `<p>` begin
and end times, collect characters into the current line, and record `<span>`
ranges for word or syllable timing. It handles clock forms (`HH:MM:SS.mmm`,
`MM:SS.mmm`, seconds with fractions) with one `seconds(_:)` function, tolerates
malformed XML by throwing `TTMLParseError`, and keeps non-timed break elements as
line breaks.

Then put the playback math on the model, where it is trivially testable:

```swift
lyrics.displayLines(at: position)        // what to show now
lyrics.nextLineBoundary(after: position) // when to wake up next
lyrics.activeLines(at: position)         // overlapping treatments
```

`nextLineBoundary` is what lets the UI sleep instead of polling at 10 Hz. That is
covered in Step 7.

**Test fixtures:** synthetic TTML strings only. Do not commit real lyrics. The
repository's tests build small documents inline and a temporary SQLite database,
so they are deterministic and have no copyright exposure.

---

## Step 4 — Read the current track from Music

There are two ways to ask Music: AppleScript, or native Apple Events. This project
tries AppleScript first, measures it, and replaces it.

AppleScript through `NSAppleScript` costs an interpreter round trip per read. The
native path sends a single AE get-data event per property, using four-character
codes from Music's scripting dictionary:

```swift
enum MusicProperty {
    static let playerState  = code("pPlS")
    static let currentTrack = code("pTrk")
    static let persistentID = code("pPIS")
    static let name         = code("pnam")
    static let artist       = code("pArt")
    static let album        = code("pAlb")
    static let duration     = code("pDur")
    static let position     = code("pPos")
}
```

Observed on one machine: warm native reads around **42–67 ms**, script-based reads
around **160–172 ms**. That is a query duration, not sound-to-screen latency —
word it that way in your own measurements too.

Two things that are easy to get wrong:

- **Permissions.** Add `NSAppleEventsUsageDescription` to `Info.plist` and the
  `com.apple.security.automation.apple-events` entitlement. Until the user allows
  automation, reads fail; the app surfaces a reconnect path instead of silently
  displaying nothing. First connection here repeatedly timed out with error
  `-1712` while automation was disabled, and succeeded after approval and a Music
  restart. Transient `-1728` (missing track) appears around track changes, so
  reads retry instead of treating it as fatal.
- **Threading.** Apple Events and SQLite run on dedicated serial actors/threads,
  not the Swift concurrency pool. Blocking calls on the cooperative pool starve
  the UI updates that are also structured concurrency tasks.

Cache the track metadata and verify track identity (persistent ID) around a
position read; otherwise a track change between two reads produces a position
belonging to a different song.

---

## Step 5 — Match the cache entry, and stop rescanning

Given a `Track`, find the cached lyrics that belong to it:

```sql
SELECT d.isDataOnFS, d.receiver_data
FROM cfurl_cache_response r JOIN cfurl_cache_receiver_data d USING(entry_ID)
WHERE r.request_key LIKE '%lyrics%'
ORDER BY r.time_stamp DESC, r.entry_ID DESC LIMIT 512
```

For each row: decode the payload (blob, or file contents when `isDataOnFS = 1`),
walk `data[].relationships`, compare track metadata, and try
`syllable-lyrics` then `lyrics`, parsing `ttml` then `ttmlLocalizations`.

Rules that keep this honest:

- **Never substitute a guess.** If metadata does not match, return nothing. Showing
  another recording's lyrics is worse than showing none.
- **Return early on a match.** One hit is enough; the scan is newest-first.
- **Make misses cheap.** After a miss, do not rescan every few seconds. Read a
  cheap stamp (mtime + size of `Cache.db` and `fsCachedData/`) every 3 seconds;
  rescan only when the stamp changes, or after a safety interval of a minute.
- **Expect slowness.** Initial cache scans here ranged from about 1.5 s to 55.6 s.
  That is why playback polling runs independently of cache work and why cache
  reads are cancellable.

`autoreleasepool` around each row's parse keeps memory flat on long scans, and
releases the JSON payload between rows rather than accumulating dictionaries.

---

## Step 6 — Draw one line into the menu bar

The display is an `NSStatusItem`, and the content is an image, not a live view.

- Choose widths 200 / 240 / 360 / 600 pt (200 default). A fixed width means the
  item does not jump around as lines change; long lines scroll inside it instead
  of turning into an ellipsis.
- Rasterize the line once per lyric change: draw the dim text, then clip to the
  revealed width and draw the bright text on top. Quantize reveal widths to half
  points so most frames produce identical pixels.
- Cache the image and skip redraws when the pixels would not change. The status
  window preview reuses the same image instead of rendering a second animated
  view.
- Set the image as a template where appropriate so it adapts to light/dark menu
  bars, and keep the full text in the tooltip and popover.
- Respect **Reduce Motion**: disable ticker motion and the popover animation.

The first version used a continuously animated custom status view. Short `ps`
samples showed roughly **28–50% CPU** with the status window open, and a profile
pointed at AppKit's replicated-status-view snapshot path. Cached native template
images fixed it; measured results are in
[docs/PERFORMANCE.md](docs/PERFORMANCE.md).

**Crowded menu bars.** There is no public API to pin or prioritize a status item.
The app watches its own window: macOS marks a crowded-out item as occluded and
moves its frame left of the notch region or parks it off screen, while a hidden
menu bar (full-screen app) leaves the frame in place. Only the first case triggers
a shrink: 600 → 360 → 240 → 200 → ♪ icon, then a step back up after 20 s, with the
wait doubling up to 10 minutes if it gets clipped again. Width alone did not solve
hiding on the test machine; **⌘-dragging** the item to the right of other items
did. Document that honestly rather than promising an always-visible item.

---

## Step 7 — Keep it quiet in the background

A lyrics display that polls at 10 Hz will show up in `Activity Monitor`. Invert the
control: wake at boundaries, not on a timer.

`PollScheduler` is pure state with no timers, so the policy is unit-testable:

| State | Next read |
| --- | --- |
| playing | 0.5 s |
| paused | 2 s |
| stopped / Music absent | 10 s |
| transient failure | 0.5 s, doubling to a 10 s cap |

On top of that, Music's distributed notifications
(`com.apple.Music.playerInfo`, `com.apple.iTunes.playerInfo`) trigger an immediate
read, and the periodic reads above are only a fallback for missed notifications.

For display updates, sleep until `lyrics.nextLineBoundary(after:)` — or the next
word boundary when words are timed — instead of waking on a fixed interval. Stop
the display timer entirely while paused or disconnected.

Measure it with the standard-library helper rather than eyeballing Activity
Monitor:

```bash
python3 scripts/measure-process.py <PID> --seconds 60
```

It reports CPU as a percentage of one core from CPU-time deltas, and physical
footprint separately from RSS (shared framework pages make them different). On the
development machine: playing 0.226% of one core with 25.67 MiB footprint; paused
0.005%; disconnected below 0.001%. State those as single-machine observations, not
budgets.

---

## Step 8 — Package it as a `.app`

SwiftPM produces an executable, not an app bundle. `scripts/build-app.sh` is short
and worth reading in full:

```bash
swift build -c release --product MusicLyricsBar
bin_dir="$(swift build -c release --show-bin-path)"
app_dir="$PWD/dist/Music Lyrics Bar.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$bin_dir/MusicLyricsBar" "$app_dir/Contents/MacOS/MusicLyricsBar"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
codesign --force --sign - --options runtime \
    --entitlements Resources/MusicLyricsBar.entitlements "$app_dir"
codesign --verify --strict "$app_dir"
ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$PWD/dist/MusicLyricsBar.zip"
```

`Info.plist` details that matter:

- `LSUIElement = true` — menu bar agent, no Dock icon.
- `LSMinimumSystemVersion = 13.0`.
- `NSAppleEventsUsageDescription` — the string the automation prompt shows.
- A bundle identifier you control, since automation permissions are granted per
  bundle identity.

Ad-hoc signing (`--sign -`) is enough to run locally, and it means the app is not
notarized: first launch needs a right-click → Open, or a Gatekeeper exception. Say
so in the README instead of letting users discover it.

---

## Step 9 — Test what you can, verify by hand what you cannot

Deterministic tests (`bash scripts/test.sh`) use synthetic TTML and temporary
databases, and cover:

- clock formats, timed spans, line breaks, entity and Unicode ranges;
- word progress interpolation, gaps between lines, overlapping lines;
- pauses and backward seeks, next-boundary scheduling;
- cache miss retry policy, metadata mismatch, read-only access, path checks;
- Apple Event object references and reply decoding without contacting Music;
- rendering: alpha coverage before, during, and after a word's timestamps, and
  unchanged-frame reuse.

Optional local check against the real cache — it prints no lyrics and no titles:

```bash
MUSIC_LYRICS_CACHE_INTEGRATION=1 bash scripts/test.sh
```

Manual checklist (things automation cannot prove): line agreement with Music's
highlight, pause and seek in both directions, track changes, Music hidden, lyrics
opened only after a cache miss, and automation permission denied then re-granted.

Results and limits live in [docs/VALIDATION.md](docs/VALIDATION.md). Write that
file before you are tempted to claim the app is "accurate": it lists what was
observed, on which machine, and what was not tested (fullscreen, multiple displays,
long-duration stability, minimum macOS).

---

## Problems this project actually hit

| Symptom | Cause | Fix |
| --- | --- | --- |
| First connection timed out (`-1712`) repeatedly | Music automation not yet approved | Ask for permission, restart Music, retry; keep the failure visible in the UI |
| ~28–50% CPU with the status window open | Continuously animated custom status view | Cached, rasterized native template images; preview shares the image |
| First lyrics took a minute to appear | Initial cache scans measured 1.5–55.6 s | Keep polling independent, make scans cancellable, show the wait |
| Status item disappeared behind other items | No public pinning API; width alone insufficient | Shrink-when-crowded policy plus user ⌘-drag to the right |
| Highlighting drifted on some songs | Sources without word timings | Fall back to line-level display; interpolate only within a timed span |
| Memory grew during long scans | JSON payloads accumulated per row | `autoreleasepool` per row, release payload between rows |

## What I would do differently

- Instrument CPU and footprint from the first prototype. The animated-view
  approach looked fine until it was measured.
- Write the cache read-only guarantee into the code path and the tests, not only
  into the README. It is the feature that makes the app acceptable.
- Treat "no cached lyrics yet" as the normal first-run state in the UI, since it is
  the most common reason a user sees nothing.
- Avoid depending on a private cache layout without documenting the risk in the
  README. macOS updates can change it.

## Where to go next

- Measured performance and method: [docs/PERFORMANCE.md](docs/PERFORMANCE.md).
- Observed behaviour and limits: [docs/VALIDATION.md](docs/VALIDATION.md).
- Tests and live playback notes: developer notes in the [README](README.md).
- Ideas that are not implemented: translation, pronunciation, last.fm scrobbling,
  launch at login, a notarized installer.

## License and provenance

WTFPL v2 — see [LICENSE](LICENSE). This is an unofficial project, unaffiliated
with Apple. Lyrics and Apple-related content belong to their rights holders and
are not covered by this software's license. Prior local-cache projects that
informed the cache layout: [apple-music-lyrics](https://github.com/Takpap/apple-music-lyrics)
and [applyrx](https://github.com/rakei076/applyrx).
