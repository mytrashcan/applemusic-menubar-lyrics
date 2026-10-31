# Music Lyrics Bar

A native macOS app that displays **Apple Music’s original lyrics** in the menu bar, synchronized with playback.

**Status: early implementation with experimental cache integration.** The app reads local TTML lyrics and timing data already downloaded by Music. It does not use external lyrics services. Apple’s cache format is private and may change with macOS or Music updates.

## Getting started

Building requires macOS 13 or later and Xcode or Command Line Tools with Swift 6 or later.

```sh
git clone https://github.com/mytrashcan/applemusic-menubar-lyrics.git
cd applemusic-menubar-lyrics
bash scripts/test.sh
bash scripts/build-app.sh
open "dist/Music Lyrics Bar.app"
```

1. Click **Connect to Music…** in the status window or menu bar menu. The app remembers this choice for future launches; turn off **Connect on Launch** in the menu to disable it.
2. Allow Music automation when macOS prompts. The app reads the current track and playback position.
3. Play a song in Music and **open its lyrics panel once** so Music can cache the lyrics.
4. The app retries automatically when the cache becomes available. Use **Reload Lyrics Cache** to retry manually.

The build produces `dist/Music Lyrics Bar.app` and `dist/MusicLyricsBar.zip`. The app uses an ad-hoc signature for local use; it is not Developer ID signed or notarized. GitHub Actions also runs tests and packaging.

## Features

- Current lyrics in the menu bar, scrolling for long lines, full-text tooltips, and a nearby-lyrics menu.
- Bright sung text and dim upcoming text using Apple TTML word or syllable timestamps.
- Scrolling that follows the sung portion for word-timed lyrics, or moves back and forth for line-timed lyrics.
- A status window with a menu bar preview, playback position, query durations, and timing counts.
- Direct native Apple Event reads with cached track metadata, a 0.5-second polling delay during playback, and monotonic-clock interpolation between reads. Playback notifications refresh immediately; paused and stopped fallback reads are less frequent.
- Pause, seek, and track-change handling.
- Previous-line retention during lyric gaps and combined display of overlapping lines.
- Track matching by title, artist, album, and duration to avoid mixing recording versions.
- Cache and permission status messages, with failed cache lookups retried every three seconds.
- Independent cache reads so slow cache access does not block playback polling.

## Long lyrics and menu bar placement

Choose **Lyrics Width** in the menu or the width control in the status window: 200, 240, 360, or 600pt. The default is 200pt. The selected width stays fixed across lyric changes, and overflowing text scrolls instead of being replaced with an ellipsis. With the system’s Reduce Motion setting enabled, automatic ticker motion is disabled. Full lyrics remain available in the tooltip and status window.

The app uses a standard macOS status item. On macOS 27.2, the native `<<` overflow button can expand hidden items into the left region. This expansion can collapse again and does not provide permanent left placement.

If lyrics are hidden, select **200pt**, expand the native overflow area, then **hold ⌘ and drag the lyric item to the right**. In local observations, right-side placement kept lyrics visible after collapsing overflow and restarting the app. Reducing width alone did not solve hiding. Items may still be hidden when space is insufficient. Width preferences persist across launches. There is no separate fixed overlay.

## Resource use

The display timer stops while paused or disconnected and sleeps until the next relevant boundary between timed words. Static text does not trigger continuous redraws. The menu bar and status preview share one cached image; text is rasterized once per lyric change. Closing the status window releases its controller and views. Subsequent launches can connect without constructing the status window.

Music playback notifications trigger immediate reads, with periodic fallbacks to recover from missed notifications. Cache reads remain independent, and cancelled requests stop before queued work proceeds. JSON payloads are released between cache rows rather than accumulating during a scan.

Measure CPU time and physical memory footprint locally with the standard-library helper:

```sh
python3 scripts/measure-process.py <PID> --seconds 60
```

The helper reports CPU as a percentage of one core and physical footprint separately from RSS. Shared resident framework pages mean RSS is not the same as the app’s physical memory footprint. Playback, pauses, and visible diagnostic windows should be measured separately.

See [measured results and limitations](docs/PERFORMANCE.md) for playback, pause, and cold-launch observations.

## Data flow and privacy

```text
Music.app ── Apple Events ── Current track / playback position
                                             │
Local Music cache ── Read-only ── Track matching → TTML parsing
                                             │
                                      Menu bar display
```

Cache locations:

```text
~/Library/Caches/com.apple.Music/Cache.db
~/Library/Caches/com.apple.Music/fsCachedData/
```

The app makes no network requests. It opens the cache database read-only and does not read account tokens, request headers, or the Music library database. It does not save or transmit lyrics or listening history. Accessibility and Screen Recording permissions are not required.

`LyricsCore` contains lyric models, the Apple TTML parser, the playback clock, and SQLite cache access. `MusicLyricsBar` performs Apple Events and cache reads in serial actors and updates the AppKit UI on the main thread. There are no third-party package dependencies.

## Validation

```sh
# Deterministic tests with synthetic lyrics and temporary SQLite databases
bash scripts/test.sh

# Optional: verify parsing and matching against this Mac’s Music cache
MUSIC_LYRICS_CACHE_INTEGRATION=1 bash scripts/test.sh
```

Tests cover time formats, timed spans and line breaks, Unicode and entity ranges, word progress, gap retention, metadata exclusion, malformed XML, overlapping lyrics, pauses and backward seeks, cache-miss retries, recording mismatches, read-only cache access, and file-path checks. Native Apple Event object references, reply decoding, and automation denial handling are tested without contacting Music. Repository fixtures contain only synthetic text. The optional local integration test does not print lyrics or track titles.

Local playback checks confirmed lyric agreement, stable paused positions, forward and backward seeks, track changes, and continued updates with Music hidden. A source with 513 timed spans showed bright sung text and dim upcoming words. These observations are not a millisecond-level sound-to-screen latency benchmark. Further manual checks include:

- Comparing the menu bar line with Music’s highlighted lyric during playback.
- Pausing, seeking in both directions, and changing tracks.
- Hiding or minimizing Music after its lyrics are cached.
- Denying automation permission and reconnecting afterward.

See the [local validation report](docs/VALIDATION.md) for observations and remaining limits.

## Current limitations

- Lyrics must already be downloaded by Music. The app does not request lyrics from an API.
- At most 512 recent lyrics-related cache responses are scanned. Reopen lyrics in Music if only older cache entries remain.
- Metadata differences or unsupported cache formats may prevent matching. The app does not substitute lyrics from a guessed track.
- Word highlighting requires word or syllable timestamps. Sources without them use line-level display. Translation and pronunciation display are not implemented.
- Progress within a multi-character span is interpolated; Apple does not necessarily provide a timestamp for each character.
- Initial cache reads have taken tens of seconds in local observations. Playback polling continues independently while lyrics load.
- After the first connection, subsequent launches connect in the background unless **Connect on Launch** is disabled. Launch at login and a notarized installer are not provided. The width preference is saved.
- The Music cache is not a public API. App Store distribution has not been evaluated.

## References

Prior local-cache projects: [apple-music-lyrics](https://github.com/Takpap/apple-music-lyrics) and [applyrx](https://github.com/rakei076/applyrx). This implementation is based on cache structures inspected locally.

This is an unofficial project, unaffiliated with Apple. Lyrics and related content belong to their respective rights holders.

## License

[MIT License](LICENSE) © 2026 JEONG KITAE. Lyrics and Apple-related content are not covered by this software’s MIT license.
