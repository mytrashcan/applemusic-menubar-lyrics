# Contributing to Music Lyrics Bar

Small, focused contributions are welcome. You do not need to write Swift to help:
[report compatibility results](https://github.com/mytrashcan/applemusic-menubar-lyrics/discussions/5),
improve setup instructions, or check accessibility on your Mac.

## Choose a place to start

- [Q&A](https://github.com/mytrashcan/applemusic-menubar-lyrics/discussions/categories/q-a): setup and usage questions.
- [Ideas](https://github.com/mytrashcan/applemusic-menubar-lyrics/discussions/categories/ideas): discuss a workflow or proposal before a large change.
- [Issues](https://github.com/mytrashcan/applemusic-menubar-lyrics/issues): reproducible bugs and scoped feature requests. Search existing reports first.
- [Good first issues](https://github.com/mytrashcan/applemusic-menubar-lyrics/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22good%20first%20issue%22): bounded starting points. Comment before substantial work to avoid duplication.

English and Korean are welcome in issues and discussions. Use English for source
comments, documentation, commits, and pull requests.

## Local development

Use macOS 13+ and Swift 6+ from Xcode or Command Line Tools. Fork and clone the
repository, create a focused branch from the latest `main`, then run:

```sh
bash scripts/test.sh
bash scripts/build-app.sh
open "dist/Music Lyrics Bar.app"
```

The build is ad-hoc signed for local use. Connect to Music, grant automation
permission, play a track, and open its lyrics panel once. Lyrics must already
exist in Music's cache; this project does not fetch them from a lyrics API.

`Sources/LyricsCore` contains parsing, playback models, and read-only cache access.
`Sources/MusicLyricsBar` contains native Apple Events and AppKit UI.
`Tests` contains synthetic fixtures and regression coverage. No external Swift
package dependencies are required.

## Tests and evidence

Run `bash scripts/test.sh` after changes. For a bug fix, add a focused synthetic
regression case when possible. For UI or playback changes, also check pause/resume,
forward/backward seek, track changes, long lines, and closing the status window.
State what you tested and what you could not test; CI does not run live Music.

The optional local-cache test is explicit opt-in:

```sh
MUSIC_LYRICS_CACHE_INTEGRATION=1 bash scripts/test.sh
```

It reads your own local cache and does not print lyrics or track titles. Never
commit cache databases, copied commercial lyrics, account tokens, request headers,
or listening-history exports. Use invented text in tests. Crop screenshots to the
relevant UI and remove personal information before uploading.

For performance changes, follow [the measurement report](docs/PERFORMANCE.md):
record duration, playback state, loaded lyrics, and window visibility. Report
physical footprint separately from RSS and distinguish synthetic renderer results
from whole-app measurements.

## Pull requests

Keep one PR focused on one problem. Use a Conventional Commit title such as
`fix(macos): preserve lyric position after a seek`. Explain the trigger, resulting
behavior, validation, and any limitations; link related issues. Include an actual
screenshot for visible UI changes. Do not claim a macOS version was validated
based only on the package's minimum deployment target.

Maintain read-only cache access, original-lyrics matching, native menu bar behavior,
and the no-network design. Discuss new permissions, dependencies, external
services, or distribution changes before implementing them.

Follow the [community guidelines](CODE_OF_CONDUCT.md). Maintainer review and
response times depend on availability; opening a proposal does not guarantee it
will be implemented.
