# Where a new listener gets stuck

**First priority: the downloaded app stops before it can show a lyric.** Gatekeeper rejected the published bundle on the audit Mac. Intel users face an earlier stop because the release executable is arm64 only.

The GitHub API and worktree agreed on `main` at `b7f8999`. GitHub reported a public WTFPL repository with **0 stars, 0 watchers** (subscribers) and no custom social preview. Latest was **v0.0.5**, published **2026-11-01**, with a ZIP and checksum file. There is no DMG in that release. These are starting observations. The effect of any individual fix on stars is **unverified**. [Repository API](https://api.github.com/repos/mytrashcan/applemusic-menubar-lyrics) · [Release](https://github.com/mytrashcan/applemusic-menubar-lyrics/releases/tag/v0.0.5) · [License](../../LICENSE)

## P0 · Blocks installation or first launch

### A downloaded app gets a security alert

A browser-downloaded, quarantined copy can be stopped on its first Finder launch. On **macOS 15 Sequoia and macOS 26 Tahoe**, expect an alert that Apple cannot verify the developer or check the app for malicious software. Apple illustrates **Done** and **Move to Trash**. Control-click → Open ceased to be an override with Sequoia. The original README disclosed ad-hoc signing but started its instructions *after* this decision. [Apple’s warning examples](https://support.apple.com/en-us/102445) · [Sequoia change](https://developer.apple.com/news/?id=saqachfa)

**Fix in this branch.** Extract the official ZIP, move the app to Applications, try opening it and dismiss the verification warning. A user who trusts that download can open System Settings → Privacy & Security → Security, find the blocked app, choose **Open Anyway**, then authenticate or confirm as prompted. This creates a per-app exception. A damage or malware-detected alert calls for stopping and checking the download. The installer guide links to Apple’s examples.

**Evidence boundary.** The downloaded bundle identified itself as ad-hoc with no Team ID. Its code signature verified, and `spctl --assess` rejected it on macOS 27.2.1. Exact dialog wording for this ZIP on 15 and 26 is **unverified**. Owner: on clean accounts on each OS, download with Safari, extract in Finder, open from Applications, capture the first warning and confirm the Settings path. Repeat with the eventual notarized ZIP and confirm a normal first launch.

**Durable fix, owner release procedure.** Use a Developer ID Application certificate with its private key and a saved notarytool keychain profile. Set `SIGNING_IDENTITY` and `NOTARY_PROFILE` to those local names. Bump the bundle version/build for the new release. From the repo root run the following in a shell with error checking. Proceed past submission only when Apple reports **Accepted**. Signing or stapling changes the bytes that the cask must pin. [Certificate setup](https://developer.apple.com/help/account/certificates/create-developer-id-certificates) · [Apple’s notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)

```bash
set -e
bash scripts/build-app.sh --universal
app="dist/universal/Music Lyrics Bar.app"
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")
asset="MusicLyricsBar-v${version}-macOS-universal.zip"
codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp \
  --entitlements Resources/MusicLyricsBar.entitlements "$app"
codesign --verify --deep --strict --all-architectures "$app"
ditto -c -k --sequesterRsrc --keepParent "$app" dist/for-notary.zip
xcrun notarytool submit dist/for-notary.zip --keychain-profile "$NOTARY_PROFILE" --wait
```

After acceptance, staple the **app**, validate it, and package the final bytes:

```bash
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute --verbose "$app"
ditto -c -k --sequesterRsrc --keepParent "$app" "dist/$asset"
(cd dist && shasum -a 256 "$asset" > SHA256SUMS && shasum -a 256 -c SHA256SUMS)
```

### An Intel owner downloads a binary their Mac cannot run

**Today:** the downloadable executable has only the arm64 slice. Every older ZIP in the [release inventory](https://api.github.com/repos/mytrashcan/applemusic-menubar-lyrics/releases) is also named for arm64. Intel owners have a source path with a macOS- and Intel-compatible Swift 6 toolchain: follow **Build from source** and run `bash scripts/build-app.sh` on the Intel Mac. macOS 13 is the deployment floor. Toolchain host requirements can differ from the packaged app’s floor. Execution on Intel hardware and on the minimum OS is **unverified**. [Package manifest](../../Package.swift) · [Bundle metadata](../../Resources/Info.plist) · [Getting started](../../README.md#getting-started)

**Fix in this branch:** `bash scripts/build-app.sh --universal` builds arm64 and x86_64 in separate SwiftPM scratch directories, combines the executables, checks both slices, then signs and archives the bundle. Native builds and CI keep their existing output paths. The extracted local universal app verified across both architectures. Both Mach-O slices declare macOS 13.0. Native unit tests passed on Apple Silicon. The Intel link completed with a missing Intel compatibility-library slice warning. The optional cross-architecture tests could not link the installed Swift Testing framework for Intel. [Build script](../../scripts/build-app.sh) · [Exact verification](status.md)

**Owner hardware check:** extract the final universal ZIP on an Intel Mac and on a Mac running the minimum OS. Check the app opens, connect to Music, grant automation, open lyrics for a playing track, hide Music, then pause, seek and switch tracks. Record the architecture, macOS and Music versions and whether the status window found a match. Publish exactly the ZIP that passed. Until then keep the release label and posts explicit about arm64.

### A Homebrew user cannot install from the public repo

The tap file is in this branch. The public v0.0.5 asset has a different name **and** different bytes from the cask target. A plain `brew install --cask music-lyrics-bar` is not the launch instruction.

| Check | Public release | Local cask candidate |
| --- | --- | --- |
| Tag or bundle version | v0.0.5 | Built from bundle version 0.0.5 |
| ZIP basename | `MusicLyricsBar-v0.0.5-macOS-arm64.zip` | `MusicLyricsBar-v0.0.5-macOS-universal.zip` |
| Top-level app in ZIP | `Music Lyrics Bar.app` | `Music Lyrics Bar.app` |
| Executable slices | arm64 | x86_64 and arm64 |
| SHA-256 | `bbf49d3535d0bfacb1af059618d603db62cb1d49a13e779ba1225a04d36a2d33` | `3f31dbe614e3fe519f3229154d682856888c64af52e34f64fde030ab8ef91b97` |

The public digest matched both downloaded `SHA256SUMS` and the rehashed ZIP. The universal digest is from **this local archive**. The cask installed that exact ZIP from a seeded cache in a disposable Homebrew tap and app directory. The future HTTP download remains unverified. [Published assets](https://github.com/mytrashcan/applemusic-menubar-lyrics/releases/tag/v0.0.5) · [Cask](../../Casks/music-lyrics-bar.rb)

**Owner release handoff.** Use a fresh version and matching `v<version>` tag for the final bundle. Attach `MusicLyricsBar-v<version>-macOS-universal.zip` and its `SHA256SUMS` to that release. Download both from Releases into an empty directory, run `shasum -a 256 -c SHA256SUMS`, extract with `ditto -x -k`, and verify the app name, slices and signature again. Set the cask’s `version` and `sha256` to that release and its final ZIP digest. Put the cask on the public default branch. On a clean Homebrew installation run the following, open the installed app, then replace the README’s draft notice with the tested commands. The explicit Git URL matters because the repository name lacks the usual `homebrew-` prefix. [Homebrew tap conventions](https://docs.brew.sh/Taps)

```sh
brew tap mytrashcan/lyrics https://github.com/mytrashcan/applemusic-menubar-lyrics.git
brew install --cask mytrashcan/lyrics/music-lyrics-bar
```

## P1 · Blocks a first lyric or a reason to star

| What a stranger sees | Fix or owner action |
| --- | --- |
| “Control Music” sounds like access to their whole library. Denial stops the connection. | The app reads track metadata and playback position through Apple Events. The cache is read-only, and it does not open the Music library database or require Accessibility or Screen Recording. The install steps give the Automation settings path and tell the user to connect again. [Music reader](../../Sources/MusicLyricsBar/MusicReader.swift) · [Cache reader](../../Sources/LyricsCore/MusicCache.swift) |
| The app opens, but “Waiting for Music” or “No synced lyrics” looks like a broken install. | Play a track in Music, open **that track’s** lyrics panel, let the app retry, then choose **Reload Lyrics Cache**. Open **Show Status** to distinguish permission, playback and cache problems. A mismatch, missing entry or changed private format can leave the bar empty. Ask for the status message and OS version only. [App menu and states](../../Sources/MusicLyricsBar/App.swift) · [Observed cache delays](../VALIDATION.md) |
| A line appears without word shading, or only a music note fits. | Explain that word/syllable timestamps are recording-specific. With line timing the app displays the line. On a crowded bar click the note for the lyric, or right-click it for the menu and **Lyrics Width**. The README and release already cover this. [Release notes](https://github.com/mytrashcan/applemusic-menubar-lyrics/releases/tag/v0.0.5) |
| “I already have a lyrics app.” | **Use LyricsX if you also want Spotify, try LyricFever for translations or fullscreen lyrics, and use Music Lyrics Bar if you want the words Apple Music has already cached for this recording directly in your menu bar.** [LyricsX](https://github.com/ddddxxx/LyricsX) · [LyricFever](https://github.com/aviwad/LyricFever) |
| A shared repo URL shows a generic GitHub card before the visitor sees a working menu bar. | GitHub GraphQL returned `usesCustomOpenGraphImage: false`. Create and upload the card below. The existing README hero already shows the interaction when the visitor clicks through. [GitHub social preview](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/customizing-your-repositorys-social-media-preview) |

### Social card and silent demo

**Social card, owner.** Export an opaque **1280 × 640 px PNG under 1 MB**. Put “Music Lyrics Bar” and “Apple Music lyrics in your menu bar” above an enlarged crop of the actual menu bar; leave enough of the surrounding bar to show where the words live. Choose a frame with both sung and upcoming text. Use a recording whose displayed lyric you can share. Keep unrelated menu items, album art and account details outside the crop. Upload at repository **Settings → Social preview → Edit → Upload an image**. Open a fresh link preview and confirm the lyric and app name remain legible at thumbnail size. [GitHub’s image guidance](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/customizing-your-repositorys-social-media-preview) · [Existing capture provenance](../images/README.md)

**Demo shot list, owner.** Aim for a **16-second** silent cut. The timings below are editorial targets. Start on motion, crop close enough for a phone and keep the menu item in the same place across cuts.

| Time | Click or cut | What the viewer should see |
| --- | --- | --- |
| 0–4 s | Start mid-phrase with a document in front. No title card. | Bright words advance across a dim line at the top of the document. |
| 4–8 s | Cut to Music. Click the lyrics button on the same playing song. | Music’s panel and the menu item show the same phrase. Caption: “Open the song’s lyrics once.” |
| 8–12 s | Hide Music with ⌘H and return to the document. | Hold through a line change. The menu bar keeps following the song. |
| 12–16 s | Click the lyric item, choose **Show Status**, and frame its preview beside the item. | The preview and menu bar agree. End on the moving words with the app name; use the [X caption](x-post.md). |

Select a track with timed words ahead of the take and clear unrelated windows. Cut idle cursor travel. Keep the real playback speed and omit commercial audio. The existing GIF is an eight-second actual playback capture; the longer clip remains an owner recording. [Capture notes](../images/README.md)

## P2 · Discovery and posting polish

**Topics.** A visitor browsing Apple Music or timed-text projects gets little signal from `collaborate` or `github`. Remove those two. Under repository **About → Edit → Topics**, set exactly: `apple-music`, `lyrics`, `synced-lyrics`, `ttml`, `macos`, `macos-app`, `menu-bar`, `appkit`, `swift`, `open-source`. Save and read the topic chips back. The remaining original topics already describe the project. [Current repository topics](https://api.github.com/repos/mytrashcan/applemusic-menubar-lyrics/topics) · [TTML parser](../../Sources/LyricsCore/AppleTTMLParser.swift)

**Submission format.** A post can disappear before anyone sees the GIF. Use the App Pile unless the owner qualifies for the Reddit main feed. Use the HN draft as notes for a personally written comment. HelloGitHub’s default form title starts with `[开源推荐]`; a recent self-submission uses the requested `[开源自荐]`. The weekly’s recent issues often use full-width brackets and a short introduction. Both drafts use the requested ASCII prefix. HelloGitHub gets individual form fields and the weekly gets a standalone pitch. [Reddit rules](https://www.reddit.com/r/macapps/about/rules/) · [HN guidelines](https://news.ycombinator.com/newsguidelines.html) · [HelloGitHub form](https://github.com/521xueweihan/HelloGitHub/blob/master/.github/ISSUE_TEMPLATE/submit-cn.yaml) · [HelloGitHub self-submission](https://github.com/521xueweihan/HelloGitHub/issues/4431) · [HelloGitHub Mac utility](https://github.com/521xueweihan/HelloGitHub/issues/4434) · [Weekly developer intro](https://github.com/ruanyf/weekly/issues/13600) · [Weekly demo-led pitch](https://github.com/ruanyf/weekly/issues/13595)
