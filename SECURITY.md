# Security policy

## Scope

Music Lyrics Bar is a local menu-bar app. It has no server component, no account and no
telemetry. The security-relevant surface is small and can be stated in full:

- **Reads playback state** from `com.apple.Music` with Apple Events: player state, current
  track metadata, playback position. This is the only reason the app asks for Automation
  permission.
- **Reads Apple's Music lyrics cache read-only**: `~/Library/Caches/com.apple.Music/Cache.db`
  and `fsCachedData/`, opened with `SQLITE_OPEN_READONLY`. The app never writes to that
  directory, never opens the Music library database, and never reads request or response
  headers or account tokens from the cache.
- **Makes no network requests.** There is no HTTP client in the target and no update check.
- **Requests no other permissions**: no Accessibility, no Screen Recording, no Full Disk
  Access, no login item.

Payload handling is bounded and path-checked: cached payloads over 8 MB are ignored, and a
`fsCachedData` file is only read after the resolved path is confirmed to sit directly
inside that directory. See [docs/HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md) for the full path
from Apple Event to rendered lyric.

## Distributions

Packaged releases are ad-hoc signed unless the release notes say otherwise, and are not
notarized. Verify the download against the release's `SHA256SUMS` before opening it, and
expect macOS to warn on first launch. Builds from source carry no distribution signature.

## Reporting a vulnerability

Open a private report through GitHub's **Security → Report a vulnerability** on this
repository. Please include the app version, the macOS version, and the smallest set of
steps that reproduces the problem. Do not attach your Music cache files or anything that
contains account or library data.

There is no bug bounty. Acknowledgement is best effort; this is a single-maintainer
project.

## Supported versions

Only the latest release receives fixes. The app targets macOS 13 and later; older systems
are untested.
