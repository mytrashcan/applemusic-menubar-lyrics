# Resource optimization — measured 2026-10-30–31

Environment: macOS 27.2 (26B123), Apple Silicon. Measurements use release builds
on one development machine. CPU is a percentage of one core derived from process
CPU-time deltas, not the moving average shown by `ps`. Physical footprint and RSS
are reported separately; shared resident framework pages make them different.

## Baseline: v0.0.2

Each row is one 20-second observation, with the status window visible.

| State | CPU, one core | Median physical footprint | Median RSS |
| --- | ---: | ---: | ---: |
| Disconnected | 0.006% | 19.70 MiB | 84.23 MiB |
| Playing, timed lyrics loaded | 0.242% | 34.91 MiB | 92.70 MiB |
| Paused, timed lyrics loaded | 0.037% | 35.28 MiB | 98.59 MiB |

These samples are not a controlled long-duration benchmark. The playing and
paused samples used the same recording, but different positions.

## Implemented changes

- Replace the AppleScript interpreter with direct native Apple Event property
  reads. Cache unchanged track metadata and verify track identity around a read.
- Use Music playback notifications for immediate refresh, with fallback reads
  after 0.5 seconds while playing, two seconds while paused, and ten seconds when
  stopped or Music is absent. Transient errors retain the fast retry path.
- Stop the display timer while paused or disconnected. Between timed words,
  schedule the next relevant word or line boundary instead of waking at 10 Hz.
- Rasterize text once per lyric change, quantize reveal widths to half points,
  and avoid allocating replacement images when the pixels are unchanged. Bound
  cached rasters for unusually long source text.
- Reuse the menu bar image in the status preview instead of a second animated
  text view. Release the status controller and views when its window closes.
- Remember an explicit connection for later launches, so subsequent launches can
  connect without constructing a status window. The menu exposes an opt-out.
- Release JSON payload objects between cache rows. Check cancellation before
  queued cache work opens a database and between rows of a scan.

## Verified behavior

- Twenty deterministic tests passed, plus the opt-in local-cache integration
  test (19 cached responses parsed without exporting lyrics). Coverage includes
  status-window/controller/view release, native Apple Event
  references and replies, automation denial, pixel shading, unchanged-frame reuse,
  word-gap scheduling, overlapping-line boundaries, and cancelled cache reads.
- Direct property reads were observed against Music: a paused position of 99.45s
  agreed with the earlier script-based reader. Warm reads were observed around
  42–67ms, compared with roughly 160–172ms script-based reads in earlier snapshots.
  These are query durations, not sound-to-screen latency.
- Music resume notifications incremented the event counter and triggered reads;
  track-change notifications were also observed.
- An optimized disconnected build with its status window visible accumulated
  97 microseconds of CPU time in 20 seconds (below 0.001% of one core), with zero
  package idle wakeups. Median physical footprint was 19.97 MiB and RSS 84.25 MiB.
  This is an idle observation, not a playback result or a RAM reduction claim.

## Synthetic renderer comparison

Run `python3 scripts/benchmark-renderer.py --frames 12000` to compare the current
renderer with the renderer at tag `v0.0.2`. Both are compiled with optimization and
run in separate processes. The fixture contains 50 synthetic 20-word phrases,
advances at 100ms steps, and includes word gaps and phrase boundaries. It does not
read Music, cached lyrics, or listening history.

| Renderer | CPU time | CPU per requested frame | Images produced |
| --- | ---: | ---: | ---: |
| v0.0.2 | 1.140392s | 95.03 μs | 8050 |
| Optimized | 0.507030s | 42.25 μs | 8050 |

The renderer used 55.5% less CPU time in this run. This isolates image
rendering; it does not establish the same reduction for the whole app or Music.

## Whole-app observations

| Optimized state | Duration | CPU, one core | Median physical footprint | Median RSS |
| --- | ---: | ---: | ---: | ---: |
| Disconnected, window open | 20s | <0.001% | 19.97 MiB | 84.25 MiB |
| Paused, timed lyrics loaded, window open | 30s | 0.005% | 24.27 MiB | 98.23 MiB |
| Playing, timed lyrics loaded, window open | 30s | 0.226% | 25.67 MiB | 103.20 MiB |
| Playing, timed lyrics loaded, window closed | 60s | 0.049% | 26.49 MiB | 99.53 MiB |
| Fresh launch, playing, timed lyrics loaded, window never opened | 60s | 0.163% | 14.69 MiB | 79.58 MiB |
| Same fresh process, paused, window never opened | 30s | 0.003% | 14.69 MiB | 80.88 MiB |

The closed-window sample included a natural track transition. Its maximum physical
footprint was 26.99 MiB; the fresh-launch sample peaked at 15.22 MiB.
The different runs show that working-set history and song position matter.
These are short observations, not long-term leak or
energy measurements. The baseline and optimized visible-window samples used the
same recording at different positions and durations; no precise whole-app
improvement percentage is inferred. RSS did not consistently decrease. The smaller
physical footprint is the relevant observed memory result, not a claim of zero RAM.

Original timed lyrics, progressive word shading, line changes, pause/resume,
seeking, and track changes were observed on the optimized build. Closing the
status window left the native menu bar updating. On a fresh launch on October 31,
the app reconnected without constructing its status window and displayed timed
lyrics. The default 200pt viewport and scrolling keep image allocations bounded;
macOS can still place the item in its overflow area when the menu bar is crowded.

## Cache-open limitation

Some initial cache opens were exceptionally slow during this session. A sampled
thread was blocked in the system file-open path. Independent SQLite and plain
read-only file probes also blocked, so this was not established as parser work or
an optimization regression. Pending probes eventually completed after unlocking;
a later app lookup took about 649 seconds and completed after Music was brought
forward. Neither event establishes the cause. A warm track lookup took 19.4ms,
and a subsequent local-cache integration run completed in 0.117s.

A separate cold paused sample used 13.52 MiB physical footprint while the cache was
still loading; it is excluded from the loaded-lyrics table. No security settings
or file attributes were changed. Initial cache availability remains a limitation;
these resource measurements do not establish an upper bound on loading latency.

Raw local profiles and listening data are not included in the repository.
