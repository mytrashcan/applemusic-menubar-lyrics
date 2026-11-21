# Homebrew cask draft

The cask targets the universal ZIP. It cannot install the current public v0.0.5 release, which offers an arm64 ZIP under a different filename. The checked-in SHA-256 identifies one locally built archive. The final pin becomes available after signing, notarization, stapling and packaging.

Once the universal asset is published and the verified version and digest are on the tap's default branch, install with these commands. [Release and verification steps](../docs/launch/release-runbook.md)

```sh
brew tap mytrashcan/lyrics https://github.com/mytrashcan/applemusic-menubar-lyrics.git
brew install --cask mytrashcan/lyrics/music-lyrics-bar
```
