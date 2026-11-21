# Where a new listener gets stuck

## P0 · Installation and first launch

| Original finding | v0.0.6 disposition | Evidence |
| --- | --- | --- |
| A verification warning stopped the first launch before the listener could see a lyric. The README started after that decision. | **Instructions fixed. Gatekeeper warning remains.** Both install routes deliver an ad-hoc signed, unnotarized app. Dismiss the first verification alert. If you trust the download, find Music Lyrics Bar under **System Settings → Privacy & Security**, choose **Open Anyway** and confirm. Stop at a damage or malware alert. | The public bundle passed strict signature verification. Gatekeeper returned `Music Lyrics Bar.app: rejected` (exit 3). [Verification](status-3.md) · [Install guide](../../README.md#getting-started) · [Apple’s warning examples](https://support.apple.com/en-us/102445) |
| An Intel owner could only download an arm64 executable. | **Fixed.** Intel and Apple Silicon share the same universal ZIP. Both slices declare macOS 13.0. Physical Intel and minimum-OS playback still need field reports. | `lipo -archs` on the executable extracted from Releases printed `x86_64 arm64`. [Release](https://github.com/mytrashcan/applemusic-menubar-lyrics/releases/tag/v0.0.6) · [Host and bundle checks](status-3.md) |
| The cask pointed at a local candidate whose name and bytes differed from the public asset. | **Fixed.** The public tap now pins the exact v0.0.6 ZIP and lists Ventura as the floor. Homebrew retains quarantine. | The downloaded ZIP, checksum file and cask agree. Ruby printed `Syntax OK`. The maintainer recorded the installed app’s `com.apple.quarantine` attribute. [Cask](../../Casks/music-lyrics-bar.rb) · [Install verification](https://github.com/mytrashcan/applemusic-menubar-lyrics/pull/23) |

### Original v0.0.5 baseline

At `b7f8999`, the original audit compared the arm64 download with the universal candidate below. The public tap install was still outstanding. These are the original measurements, retained to show what changed. [Initial audit record](status.md)

| Check | Published v0.0.5 | Local candidate at the original audit |
| --- | --- | --- |
| Tag or bundle version | v0.0.5 | Built from bundle version 0.0.5 |
| ZIP basename | `MusicLyricsBar-v0.0.5-macOS-arm64.zip` | `MusicLyricsBar-v0.0.5-macOS-universal.zip` |
| Top-level app in ZIP | `Music Lyrics Bar.app` | `Music Lyrics Bar.app` |
| Executable slices | arm64 | x86_64 and arm64 |
| SHA-256 | `bbf49d3535d0bfacb1af059618d603db62cb1d49a13e779ba1225a04d36a2d33` | `3f31dbe614e3fe519f3229154d682856888c64af52e34f64fde030ab8ef91b97` |

## P1 · Blocks a first lyric or a reason to star

| What a stranger sees | Fix or owner action |
| --- | --- |
| “Control Music” sounds like access to their whole library. Denial stops the connection. | The app reads track metadata and playback position through Apple Events. The cache is read-only, and it does not open the Music library database or require Accessibility or Screen Recording. The install steps give the Automation settings path and tell the user to connect again. [Music reader](../../Sources/MusicLyricsBar/MusicReader.swift) · [Cache reader](../../Sources/LyricsCore/MusicCache.swift) |
| The app opens, but “Waiting for Music” or “No synced lyrics” looks like a broken install. | Play a track in Music, open **that track’s** lyrics panel, let the app retry, then choose **Reload Lyrics Cache**. Open **Show Status** to distinguish permission, playback and cache problems. A mismatch, missing entry or changed private format can leave the bar empty. Ask for the status message and OS version only. [App menu and states](../../Sources/MusicLyricsBar/App.swift) · [Observed cache delays](../VALIDATION.md) |
| A line appears without word shading, or only a music note fits. | Explain that word/syllable timestamps are recording-specific. With line timing the app displays the line. On a crowded bar click the note for the lyric, or right-click it for the menu and **Lyrics Width**. [Menu-bar controls](../../README.md#make-room-for-your-lyrics) |
| “I already have a lyrics app.” | **Use LyricsX if you also want Spotify, try LyricFever for translations or fullscreen lyrics, and use Music Lyrics Bar if you want the words Apple Music has already cached for this recording directly in your menu bar.** [LyricsX](https://github.com/ddddxxx/LyricsX) · [LyricFever](https://github.com/aviwad/LyricFever) |
| A shared repo URL shows a generic GitHub card before the visitor sees a working menu bar. | **Fixed.** The original audit found `usesCustomOpenGraphImage: false`. The API now returns `true`, and the served PNG matches the prepared image byte for byte. The existing README hero already shows the interaction when the visitor clicks through. [GitHub social preview](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/customizing-your-repositorys-social-media-preview) |

### Social card and silent demo

**Social card.** The [ready PNG](../images/social-preview.png) is already live. For a replacement, use repository **Settings → Social preview → Edit → Upload an image** and check the resulting preview at thumbnail size. [Image provenance](../images/README.md) · [Verification](status-3.md)

**Demo shot list, owner.** Aim for a **16-second** silent cut. The timings below are editorial targets. Start on motion, crop close enough for a phone and keep the menu item in the same place across cuts.

| Time | Click or cut | What the viewer should see |
| --- | --- | --- |
| 0–4 s | Start mid-phrase with a document in front. No title card. | Bright words advance across a dim line at the top of the document. |
| 4–8 s | Cut to Music. Click the lyrics button on the same playing song. | Music’s panel and the menu item show the same phrase. Caption: “Open the song’s lyrics once.” |
| 8–12 s | Hide Music with ⌘H and return to the document. | Hold through a line change. The menu bar keeps following the song. |
| 12–16 s | Click the lyric item, choose **Show Status**, and frame its preview beside the item. | The preview and menu bar agree. End on the moving words with the app name; use the [X caption](x-post.md). |

Select a track with timed words ahead of the take and clear unrelated windows. Cut idle cursor travel. Keep the real playback speed and omit commercial audio. The existing GIF is an eight-second actual playback capture; the longer clip remains an owner recording. [Capture notes](../images/README.md)

## P2 · Discovery and posting polish

**Topics fixed.** The [topics returned by GitHub](https://api.github.com/repos/mytrashcan/applemusic-menubar-lyrics/topics) match the original target set: `apple-music`, `lyrics`, `synced-lyrics`, `ttml`, `macos`, `macos-app`, `menu-bar`, `appkit`, `swift`, `open-source`.

**Submission format.** A post can disappear before anyone sees the GIF. Use the App Pile unless the owner qualifies for the Reddit main feed. Use the HN draft as notes for a personally written comment. HelloGitHub’s default form title starts with `[开源推荐]`; a recent self-submission uses the requested `[开源自荐]`. The weekly’s recent issues often use full-width brackets and a short introduction. Both drafts use the requested ASCII prefix. HelloGitHub gets individual form fields and the weekly gets a standalone pitch. [Reddit rules](https://www.reddit.com/r/macapps/about/rules/) · [HN guidelines](https://news.ycombinator.com/newsguidelines.html) · [HelloGitHub form](https://github.com/521xueweihan/HelloGitHub/blob/master/.github/ISSUE_TEMPLATE/submit-cn.yaml) · [HelloGitHub self-submission](https://github.com/521xueweihan/HelloGitHub/issues/4431) · [HelloGitHub Mac utility](https://github.com/521xueweihan/HelloGitHub/issues/4434) · [Weekly developer intro](https://github.com/ruanyf/weekly/issues/13600) · [Weekly demo-led pitch](https://github.com/ruanyf/weekly/issues/13595)
