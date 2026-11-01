# Local validation — 2026-10-29

Environment: macOS 27.2 (26B123), Apple Silicon, Swift 6.4. One local development machine; this is not a compatibility matrix or an audio-latency benchmark. No copyrighted lyrics or listening-history fixtures are included in this report.

## Observed with Music running

| Check | Evidence |
| --- | --- |
| Connection and cache matching | Current song metadata received; consecutive songs loaded 34 and 47 timed lines respectively. |
| Paused line agreement | At 43.70 seconds, Music's highlighted line agreed with the displayed lyric. Ten further polls kept position at 43.70. |
| Forward/backward seeking | Clicking a later lyric moved the app to 57.76 seconds; clicking an earlier lyric returned it to 43.07 seconds and the corresponding text. |
| Song changes | Previous lyrics cleared and the next song's lyrics replaced them. |
| Music hidden | After hiding Music, position advanced from 53.87 to 67.87 seconds and the displayed line changed. |
| Word shading | A source containing 513 timed spans displayed already-sung text brightly and remaining words dimly. A second source exposed 497 spans. |
| Native left expansion | The macOS 27 MenuBarAgent overflow control expanded the status item into the left region, but later collapsed again. This does not establish permanent left placement. |
| Width preference | Selecting 600pt in the status window updated the control and the saved preference. |
| Cache/poll independence | While a slow cache read remained pending, playback polls increased from 1 to 24 and position continued advancing. |

## Automated coverage

`MUSIC_LYRICS_CACHE_INTEGRATION=1 bash scripts/test.sh` passes 16 tests: 14 core tests (including the opt-in local-cache check), scripting compilation, and a native-image rendering test. The rendering test checks actual alpha coverage before, during, and after word timestamps. The gap regression checks previous-line retention, the next line's exact start boundary, and backwards seeks.

The latest opt-in scan verified 18 local cached song responses. Earlier scans verified 19; the cache contents change while Music is running. These counts are responses, not a guarantee of distinct songs or catalog coverage.

## Limits and findings

- Apple Events reads were typically around 150–170ms in observed snapshots. This is request duration, not sound-to-screen latency.
- Initial cache reads ranged from about 1.5 seconds to 55.6 seconds in observed runs. Profiling caught a pending SQLite open in the system call. The underlying cause is not proven. Warm lookups around 28–41ms were also observed. Cache I/O runs independently from playback polling.
- The first connection repeatedly timed out with `-1712`. Music automation was initially disabled. After explicit user approval, enabling it and restarting Music, connection succeeded. The exact cause of the repeated timeout was not isolated.
- A transient missing-track error (`-1728`) was seen around changing playback. Polling now retries transient read errors; an explicit permission denial still stops it.
- Custom animated status views on macOS 27 were costly: intermediate builds showed roughly 28–50% CPU in short `ps` samples with the status window open. A profile included AppKit's replicated-status-view snapshot path. The menu bar now uses cached native template images rather than a continuously animated custom view. The status window retains a preview.
- A subsequent native-image build produced five short samples of 1.8–14.4% CPU and about 117–118MiB RSS with the status window open. These were not controlled same-song benchmark runs; do not interpret them as a precise reduction percentage or an idle/background budget.
- The app keeps native menu-bar placement. Native overflow expansion does not establish permanent left placement, and an item can still be hidden when menu-bar space is insufficient. No separate overlay is included.
- Fullscreen, multiple displays, long-duration stability, and the minimum supported macOS version still need separate validation. Hiding Music was tested; minimizing and fullscreen behavior are not established by that test.
- Sources without timed words retain line-level display. Progress within a multi-character span is interpolation, not an independently verified timestamp for each character.

## Compact fixed-width placement experiment

The app now reserves the selected width across lyric changes, with a new 200pt
option and a 200pt default for fresh preferences. Existing saved widths remain
available. The accessibility identifier and label stay fixed; the current lyric
is exposed as the accessibility value.

- At 200pt in the original leftmost status-item position, the item still entered
  native overflow after other status items appeared. Width reduction alone did
  not solve hiding on this machine.
- The user Command-dragged the lyric item to the right of ChatGPT. With the native
  overflow area collapsed, both short and long Japanese lyric lines remained
  visible; long text scrolled within the fixed viewport with word shading.
- The item remained visible in observed ChatGPT and Goodnotes foreground states.
  This is a small set of observed layouts, not a guarantee for every app menu.
- After terminating and relaunching the app process once, 200pt and the user's
  right-side placement persisted. Reconnecting loaded 47 lines and 257 timed
  spans, and the lyric item stayed outside the collapsed overflow area.

This supports compact width plus user-controlled right-side placement as a
practical mitigation on the tested layout. It does not establish an always-visible
API or behavior under arbitrary icon counts, display changes, or fullscreen.

# Crowded menu bar — 2026-11-01

Environment: macOS 27.2 (26B123), 14-inch MacBook Pro with notch (1710 × 1107pt,
menu bar region right of the notch starts at x = 947.5), Swift 6.4.2, Command Line
Tools. Observations come from a stand-alone probe (`NSStatusItem` plus filler items)
and from the app’s own `menubar-fit` and `floating-bar` log categories. No lyrics or
track names are included.

## How a clipped or overflowed status item reports itself

| State | `item.isVisible` | `window.isVisible` | `occlusionState` | `window.frame` | `window.screen` |
| --- | --- | --- | --- | --- | --- |
| Visible, 22pt | true | true | contains `.visible` (8194) | (1240, 1073, 38, 34) | main |
| Visible, 240pt | true | true | contains `.visible` | (1022, 1073, 256, 34) | main |
| Pushed out by crowding, 600pt | true | true | no `.visible` (8192) | (654, 1073, 616, 34), left of the notch region | main |
| Pushed out by crowding, 150pt filler | true | true | no `.visible` | (848, 1073, 166, 34) | main |
| Never placed (no room at creation) | true | true | no `.visible` (8) | (0, -34, 166, 34) | nil |
| Menu bar hidden by a full-screen app | true | true | no `.visible` | unchanged (1240, 1073, 38, 34) | main |

- `isVisible` on the item and on its window never changes; neither is a signal.
- `NSWindowDidChangeOcclusionStateNotification` fires on the item’s window when it
  is pushed out or comes back, and `NSWindowDidMoveNotification` /
  `NSWindowDidResizeNotification` fire when macOS relocates or resizes it. Launch
  posts a burst of these within the first 100ms.
- Entering full screen also posts `NSApplication.didChangeScreenParametersNotification`
  and leaves `NSScreen.main.visibleFrame` at the same top edge; `NSMenu.menuBarVisible()`
  only reflects this app, not the frontmost one.
- macOS hides the newest (leftmost) items first and remembers each item’s slot by
  autosave name, so an item that has been ⌘-dragged to the right keeps its slot
  across launches even when newer items appear.

The app therefore treats an item as clipped only when its window is occluded **and**
its frame moved: no screen, or `minX` left of `auxiliaryTopRightArea.minX` on a
notched display, or a right edge that differs from the last frame seen while
visible. An occluded window whose frame did not move is a hidden menu bar and
leaves the width alone.

A later run on the owner's real, fuller menu bar (v0.0.4 installed in
Applications) added one row: a 200pt item that did not fit was parked at
x 951, just right of the region start at 947.5, and stayed occluded there at
every retry. The notch boundary alone therefore proves "out" but not "in", and
the right-edge comparison now applies on notched displays too; without it the
app looped 200 → 240 → clipped → 200 and never reached the icon.

## Auto-shrink, observed in the app

Preferred width 360pt. The item’s own slot on this Mac fits 240pt but not 360pt.

```text
18:03:59.846  clipped at 360pt (occluded true, x 894); now 240pt
18:04:19.946  visible at 240pt (occluded false, x 1022); now 360pt
18:04:20.321  clipped at 360pt (occluded true, x 894); now 240pt
18:05:00.421  visible at 240pt; now 360pt      ← retry after 40 s
18:05:00.804  clipped at 360pt; now 240pt
18:06:20.904  visible at 240pt; now 360pt      ← retry after 80 s
18:06:21.266  clipped at 360pt; now 240pt
```

With six 150pt filler items created first and a fresh autosave name, the item was
never placed (x 0, no screen) and stepped down to the icon; removing the fillers
brought it back one step per retry interval:

```text
18:10:11.834  clipped at 360pt (occluded true, x 0); now 240pt
18:10:12.634  clipped at 240pt (occluded true, x 0); now 200pt
18:10:13.461  clipped at 200pt (occluded true, x 0); now 22pt
              (fillers removed at 18:10:23)
18:10:43.988  visible at 22pt (occluded false, x 1240); now 200pt
18:11:04.070  visible at 200pt (occluded false, x 1062); now 240pt
18:11:24.146  visible at 240pt (occluded false, x 1022); now 360pt
18:11:24.510  clipped at 360pt (occluded true, x 894); now 240pt
```

Each shrink step waited the 0.75 s settle interval; each grow waited the 20 s retry
interval; a grow that was clipped within its 5 s probe window doubled the next wait.

## Floating lyrics bar (removed)

A click-through strip inside the menu bar's left region, placed after the
frontmost app's menu titles read through the Accessibility API, was built and
observed working with Music playing (titles measured at 316–460pt, strip 12pt
after them, left of the notch). The owner preferred the menu bar item alone, so
the mode, its Accessibility use, and its preference key were removed; the
auto-shrink above is what remains.

Two findings from that work still apply to any future permission-based feature:
a hidden menu bar (full screen, auto-hide) shows as the status item's window
being occluded without moving, and an ad-hoc signed rebuild changes the code
hash so TCC keeps a stale requirement until the record is reset
(`tccutil reset <service> io.github.mytrashcan.MusicLyricsBar`).

## Not verified here

- Music playback during these runs: Music automation was blocked by a pending
  consent dialog on this machine, so the shrink and floating runs showed the
  fallback label rather than timed lyrics. The rendering path is unchanged.
- Clicking the icon (popover) and right-clicking it (menu) need a pointer; they
  were not driven in this session.
- Displays without a notch and external displays.
