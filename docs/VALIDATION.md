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
