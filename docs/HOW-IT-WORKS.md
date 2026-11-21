# How Music Lyrics Bar finds your lyrics

The app has no lyrics service, no account and no network code. It reconstructs the
current line from two local sources: what Music is playing, and what Music has already
downloaded and cached on this Mac.

## 1. Reading playback

`Sources/MusicLyricsBar/MusicReader.swift`

Playback is read with Apple Events, not with AppleScript. `NSAppleEventDescriptor`
targets `com.apple.Music` and requests individual scripting properties by their
four-character codes (`pPlS` player state, `pTrk` current track, `pPIS` persistent ID,
`pnam`/`pArt`/`pAlb`/`pDur`, `pPos` position). Opening a track's properties through the
scripting dictionary avoids compiling or running AppleScript text.

- Each Apple Event blocks its thread until Music replies, with a 2-second timeout, so
  reads run on a dedicated queue rather than the cooperative thread pool.
- The persistent ID is read before and after the other properties. If Music switched
  tracks mid-read the two IDs differ and the sample is discarded, so a mixed snapshot
  never reaches the display.
- When the persistent ID matches the last sample, the title/artist/album/duration are
  reused instead of being re-requested on every poll.

This is the only reason macOS asks for **Automation** permission for Music. Denying it
stops the app from reading playback; it reads nothing else.

## 2. Matching the cache to the playing track

`Sources/LyricsCore/MusicCache.swift`

Music writes the responses it downloads into a CoreFoundation URL cache:

```
~/Library/Caches/com.apple.Music/Cache.db
~/Library/Caches/com.apple.Music/Cache.db-wal
~/Library/Caches/com.apple.Music/Cache.db-shm
~/Library/Caches/com.apple.Music/fsCachedData/
```

The app opens `Cache.db` with `SQLITE_OPEN_READONLY` and a busy timeout, and reads only
`cfurl_cache_response` joined to `cfurl_cache_receiver_data` for rows whose `request_key`
contains `lyrics`. The newest 512 rows are bounded work, not a full scan. Payloads up to
8 MB are taken either from the row blob or from the file it points at under
`fsCachedData/`, and that path is resolved and checked so a crafted row cannot escape the
directory.

A payload is a JSON document of candidate songs. A candidate counts as the playing
recording only when all of these hold:

| Field | Rule |
| :--- | :--- |
| `type` | `songs` |
| `name` | equals the playing title after Unicode precomposition, case- and width-insensitive folding, and whitespace collapse |
| `artistName` | same normalized comparison against the playing artist |
| `durationInMillis` | within ±2 seconds of the Music track's duration |
| `albumName` | same comparison, only when the track has an album |

Matching on title *and* artist *and* duration is what keeps a live version, a remaster
or a cover from borrowing the wrong timings. When nothing matches, the bar shows nothing
rather than approximating.

## 3. Parsing the timed text

`Sources/LyricsCore/AppleTTMLParser.swift`

The matched record exposes `ttml` (occasionally `ttmlLocalizations`) under
`relationships.syllable-lyrics` or `relationships.lyrics`. That is Apple's TTML dialect:
times are song-absolute, including paragraphs inside timed containers, so the parser is
deliberately scoped to this dialect rather than to every TTML timing mode.

- `p` elements become lines, `span` elements become words or syllables.
- Times accept `ms`, `s`, and `hh:mm:ss` / `mm:ss` forms; invalid or negative values are
  dropped instead of clamped.
- A line without word spans still displays; it just advances at line granularity.

## 4. Rendering

`Sources/MusicLyricsBar/StatusImageRenderer.swift`, `MenuBarFit.swift`

The line is rendered to an image and set as the menu-bar item, which is what lets the
app work inside an arbitrary menu bar width. `MenuBarFit` shrinks the item when the bar
is crowded; the popover shows the full line.

## Why this can fail, and what it tells you

| Symptom | Cause |
| :--- | :--- |
| "Waiting for Music" | Music is not running, or Automation permission was denied |
| "No synced lyrics" | The track's lyrics panel was never opened, so nothing was cached, or the cached copy is for a different recording |
| Empty after a macOS update | Apple changed the private cache layout or the TTML dialect |

A missed match is ordinary: the cache only holds what this Mac has requested. Open the
song's lyrics panel in Music once and the app retries on the next poll.

## Privacy

No network code, no analytics, no account. The cache is opened read-only and never
written. The app never opens the Music library database, never reads request or response
headers, and asks for no Accessibility or Screen Recording permission. See
[SECURITY.md](../SECURITY.md) for the reporting path.
