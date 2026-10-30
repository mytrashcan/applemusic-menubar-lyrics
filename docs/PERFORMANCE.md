# Resource optimization — preliminary validation, 2026-10-30

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

## Verified so far

- Nineteen deterministic tests passed. Coverage includes native Apple Event
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

## Pending live verification

The Mac became locked before final playback measurements. The UI tool requires
manual unlocking. A local-cache integration run and independent SQLite and plain
read-only file probes remain pending on the real Music cache. A sampled app thread
was blocked in the system file-open path. Closing Music did not release the probes.
Whether the lock is the cause has not been established.

Live timed-lyrics rendering, full-app playback CPU and footprint, closed-window
resource use, cold background launch, seek responsiveness, and a multi-track soak
must still be verified after unlocking. The optimization goal remains open.

Raw local profiles and listening data are not included in the repository.
