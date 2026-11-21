# Launch kit status

**Ready locally:** the copy, install guide, native and universal packaging paths, and checksum-pinned cask draft. The public release still contains the arm64 ZIP only.

| Deliverable | Status | Evidence or remaining work |
| --- | --- | --- |
| [Index and timeline](README.md) | DONE | D−7 through D+14 in KST, with owner, channel, cost, possible outcomes and current state. |
| [Conversion audit](audit.md) | DONE | Severity-ordered findings, exact release checksum and bundle, alternatives, topics, social-card spec, demo shots and owner release steps. |
| [r/macapps](reddit-macapps.md) | DONE | Title, body and author reply. The App Pile is usable without establishing main-feed eligibility. |
| [Show HN](show-hn.md) | DONE | Title, URL and first-comment draft. HN requests human-written posts, so the owner should put the draft in their own words. |
| [HelloGitHub](hellogithub.zh.md) | DONE | Simplified Chinese fields checked against the submission form and recent issues. |
| [ruanyf/weekly](ruanyf-weekly.zh.md) | DONE | Simplified Chinese self-recommendation modeled on recent issues. |
| [X copy](x-post.md) | DONE | The variants contain 226, 210 and 236 characters including their full URLs. A separate caption accompanies the demo. |
| [Cask](../../Casks/music-lyrics-bar.rb) | DONE | Ruby syntax, Homebrew parsing, checksum and install to an isolated app directory verified. The candidate digest is local. |
| [Universal build path](../../scripts/build-app.sh) | DONE | Native and universal ZIPs built, extracted and verified. Both universal slices declare macOS 13.0. |
| [Install/launch README](../../README.md#getting-started) | DONE | Download link identifies Apple Silicon. Intel source path, Gatekeeper, Automation recovery, universal build and Homebrew availability are documented. |
| Build and runtime validation | PARTIAL | Apple Silicon synthetic tests passed. Intel test frameworks lack an x86_64 slice here. Physical Intel playback, minimum-OS execution and clean Finder launches on 15/26 remain unverified. |
| Social preview upload, topic changes, video recording and channel posts | NOT DONE | Owner actions. The audit contains the upload path, exact topics and timed capture instructions. |
| Public universal ZIP, notarization and remote cask installation | NOT DONE | Requires an owner release. The current public ZIP is ad-hoc signed; the cask’s universal URL is staged. |
| Git delivery | DONE | One local conventional commit on `feat/launch-kit`. No push, PR, tag, public submission or settings change. |

## Verification commands

Run build commands from the repository root. The checks used Swift 6.4.2 on arm64 macOS 27.2.1. Swift needed its normal user compiler cache outside the workspace sandbox. The native test command succeeded before and after the packaging changes. The opt-in private Music cache test was skipped.

```bash
bash -n scripts/build-app.sh
ruby -c Casks/music-lyrics-bar.rb
bash scripts/test.sh
bash scripts/build-app.sh
bash scripts/build-app.sh --universal
```

The native output is `dist/MusicLyricsBar.zip`. The versioned universal ZIP is a separate local candidate. These commands inspected the published ZIP and both local packages. `work` is the temporary verification directory used for this run.

```bash
work=/private/tmp/music-lyrics-launch.IeQCtJ
gh release download v0.0.5 --repo mytrashcan/applemusic-menubar-lyrics --dir "$work"
(cd "$work" && shasum -a 256 -c SHA256SUMS)
(cd "$work" && unzip -Z1 MusicLyricsBar-v0.0.5-macOS-arm64.zip)
(cd "$work" && ditto -x -k MusicLyricsBar-v0.0.5-macOS-arm64.zip published)
ditto -x -k dist/MusicLyricsBar-v0.0.5-macOS-universal.zip "$work/universal"
ditto -x -k dist/MusicLyricsBar.zip "$work/native"
for package in published native universal; do
  app="$work/$package/Music Lyrics Bar.app"
  codesign --verify --deep --strict --all-architectures "$app"
  lipo -archs "$app/Contents/MacOS/MusicLyricsBar"
  /usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist"
  cmp LICENSE "$app/Contents/Resources/LICENSE"
done
xcrun vtool -show-build "$work/universal/Music Lyrics Bar.app/Contents/MacOS/MusicLyricsBar"
(cd dist && shasum -a 256 MusicLyricsBar-v0.0.5-macOS-universal.zip) > "$work/SHA256SUMS-universal"
(cd dist && shasum -a 256 -c "$work/SHA256SUMS-universal")
(cd "$work" && codesign -dvv 'published/Music Lyrics Bar.app')
(cd "$work" && spctl --assess --type execute --verbose=4 'published/Music Lyrics Bar.app')
```

The release and native binaries reported arm64. The universal binary reported x86_64 and arm64. All three extracted signatures and bundled licenses verified. Gatekeeper rejected the public download on this host. A separate `syspolicy_check distribution 'published/Music Lyrics Bar.app'` stalled and was stopped. Neither command reproduces the Finder dialog on the target OS versions.

The following extra tests **did not pass**. Starting the entire toolchain under Rosetta failed because libxcrun is arm-only. Cross-compiling the tests with the native toolchain failed while linking the Intel test bundles because the installed Testing frameworks lack that architecture. The release executable linked, with warnings about an unavailable Intel slice of libswiftCompatibilityPacks and missing CLT search directories.

```bash
arch -x86_64 /bin/bash scripts/test.sh --arch x86_64 --scratch-path .build/test-x86_64
bash scripts/test.sh --arch x86_64 --scratch-path .build/test-x86_64
```

### Homebrew install rehearsal

Homebrew 7.0.14 rejected a loose cask pathname in `brew info`. For the successful test, a disposable copy of the installed Homebrew files loaded the cask by its qualified tap name. Its cache was seeded with the exact universal ZIP because the remote asset does not exist. The following commands show the setup and checks used, with the final cask in place.

```bash
work=/private/tmp/music-lyrics-launch.IeQCtJ
prefix="$work/brew"
mkdir -p "$prefix/bin" "$prefix/Library/Taps/mytrashcan/homebrew-lyrics/Casks"
cp /opt/homebrew/bin/brew "$prefix/bin/"
cp -cR /opt/homebrew/Library/Homebrew "$prefix/Library/"
cp Casks/music-lyrics-bar.rb "$prefix/Library/Taps/mytrashcan/homebrew-lyrics/Casks/"
export XDG_CONFIG_HOME="$work/config" HOMEBREW_TEMP="$work/brew-tmp"
export HOMEBREW_CACHE="$work/brew-cache" HOMEBREW_LOGS="$work/brew-logs"
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_FROM_API=1 HOMEBREW_NO_ANALYTICS=1
mkdir -p "$XDG_CONFIG_HOME/homebrew" "$work/brew-tmp" "$work/brew-cache" "$work/apps"
brew_bin="$prefix/bin/brew"
"$brew_bin" trust --cask mytrashcan/lyrics/music-lyrics-bar
"$brew_bin" info --cask --json=v2 mytrashcan/lyrics/music-lyrics-bar > "$work/cask.json"
archive_cache=$("$brew_bin" --cache --cask mytrashcan/lyrics/music-lyrics-bar)
mkdir -p "$(dirname "$archive_cache")"
cp dist/MusicLyricsBar-v0.0.5-macOS-universal.zip "$archive_cache"
"$brew_bin" install --cask --appdir="$work/apps" mytrashcan/lyrics/music-lyrics-bar
codesign --verify --deep --strict --all-architectures "$work/apps/Music Lyrics Bar.app"
```

Homebrew resolved the macOS floor to `>= 13`, accepted the digest and moved `Music Lyrics Bar.app` into the temporary app directory. The [audit](audit.md) lists the future release and public tap checks.

**Biggest remaining blocker:** Gatekeeper rejects the current public app, so even a visitor with a supported Apple Silicon Mac must decide whether to make a security exception before seeing a lyric.
