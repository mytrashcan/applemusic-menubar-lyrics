# Homebrew cask

Installs the universal build from the latest release.

```sh
brew tap mytrashcan/lyrics https://github.com/mytrashcan/applemusic-menubar-lyrics.git
brew install --cask mytrashcan/lyrics/music-lyrics-bar
```

The pinned `version` and `sha256` refer to the published asset
`MusicLyricsBar-v<version>-macOS-universal.zip`. Every release must re-pin both, because
signing and packaging change the bytes: after publishing, take the digest from that
release's `SHA256SUMS`.

Homebrew installs the app with a quarantine flag, so this is **not** a way around
Gatekeeper. The build is ad-hoc signed and not notarized, so the first launch still asks
the user to open System Settings → Privacy & Security and choose **Open Anyway**.

[Release and verification steps](../docs/launch/release-runbook.md)
