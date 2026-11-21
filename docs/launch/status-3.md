GO-WITH-FIXES

The v0.0.6 download and cask are ready to share with the first-launch warning in the post itself. The prepared social preview is already live. The owner still has a demo to record and a disabled private reporting link to restore. [Posting checklist](publish-checklist.md)

## Evidence · 2026-11-21 KST

| Check | Observed result |
| --- | --- |
| Checkout and host | `docs/publish-ready` started at `27008f9`, the clone’s `origin/main`. `uname -m` returned `arm64`. `sw_vers` reported macOS 27.2.1 (26B131). |
| Public release | GitHub returned `tag_name=v0.0.6`, `draft=false`, `prerelease=false`, published `2026-11-21T12:30:35Z`. Downloaded both assets from this release into a fresh directory. [Release API](https://api.github.com/repos/mytrashcan/applemusic-menubar-lyrics/releases/tags/v0.0.6) |
| ZIP integrity | The published checksum, API ZIP digest, independently hashed ZIP and cask all gave `27c33f63a1f7a88416f3e146cae57f1ab6bccc563f2d2ddac6d57ff1af20117c`. |
| Bundle | `ditto -x -k` succeeded. The extracted root contained `Music Lyrics Bar.app`. Its executable reported `x86_64 arm64`. The bundle version/build were `0.0.6` / `8`. The plist and both Mach-O deployment targets declared macOS 13.0. |
| Signature and Gatekeeper | Strict verification succeeded across both architectures. Signature inspection reported `adhoc` and no Team ID. The host Gatekeeper service returned `rejected` (exit 3). Neither a clean Finder launch nor playback on physical Intel or macOS 13 was tested in this run. |
| Homebrew | `ruby -c Casks/music-lyrics-bar.rb` printed `Syntax OK`. The resolved URL, asset basename, SHA, version, `app "Music Lyrics Bar.app"` and `depends_on macos: :ventura` matched the download. Local and public default-branch cask blob IDs both equaled `9547a672758868478b7a6d7bb771b770fafa6d88`. The maintainer’s prior install recorded `com.apple.quarantine`; this pass checked the pin without reinstalling Homebrew. [Cask](../../Casks/music-lyrics-bar.rb) · [Install report](https://github.com/mytrashcan/applemusic-menubar-lyrics/pull/23) |
| Credential-free tag | The v0.0.6 push built successfully. Its log showed `READY: false`; signing and strict enforcement skipped, and artifact `universal-adhoc` uploaded. The jobs API returned `publish / skipped` with no steps. The public run summary HTML contained the skipped job link and artifact name. Both public release assets list `mytrashcan` as uploader. [Run summary](https://github.com/mytrashcan/applemusic-menubar-lyrics/actions/runs/44904114630) · [Publish job](https://github.com/mytrashcan/applemusic-menubar-lyrics/actions/runs/44904114630/job/136846203734) |
| Actions UI and dispatch | **Actions → Universal release → v0.0.6 push → Summary** reaches the observed result. **Run workflow** on `main` is a branch rehearsal. Only a manual dispatch can request the strict missing-credentials failure after upload. The API also returned a successful `workflow_dispatch` on `main` with `publish` skipped. [Branch run](https://github.com/mytrashcan/applemusic-menubar-lyrics/actions/runs/44902629975) · [Workflow conditions](../../.github/workflows/release.yml) |
| PR checks and local tests | The CI workflow subscribes to `pull_request` without path filters. The PR run for the cask pin reported success for native unit tests, native packaging and universal packaging. Both local native test bundles passed with `bash scripts/test.sh`. The private-cache integration case was skipped. [CI](../../.github/workflows/ci.yml) · [PR run](https://github.com/mytrashcan/applemusic-menubar-lyrics/actions/runs/44904364794) |
| Preview and topics | GitHub returned `usesCustomOpenGraphImage: true`. The served PNG and the 1280 × 640 repository PNG matched byte for byte (SHA-256 `a88b5914b57e1523a23ae7f29ebf4320b09d2a3f39dc47a3554278451ac13570`). The repository API returned the audit’s target topics. [PNG](../images/social-preview.png) · [Topics](https://api.github.com/repos/mytrashcan/applemusic-menubar-lyrics/topics) |
| Post lengths | Counts with the full URL, in file order, are 279, 279 and 278 Unicode characters. The separate demo caption is 106 characters. [X copy](x-post.md) |

### Public-asset check transcript

`gh release download v0.0.6` selected the versioned ZIP and `SHA256SUMS`. Results below are from those files. The signature display and plist output are excerpted. The strict verification and extraction commands had no output and exited 0.

```console
$ cat SHA256SUMS
27c33f63a1f7a88416f3e146cae57f1ab6bccc563f2d2ddac6d57ff1af20117c  MusicLyricsBar-v0.0.6-macOS-universal.zip
$ shasum -a 256 -c SHA256SUMS
MusicLyricsBar-v0.0.6-macOS-universal.zip: OK
$ ditto -x -k MusicLyricsBar-v0.0.6-macOS-universal.zip extracted
$ ls -A extracted
Music Lyrics Bar.app
$ cd extracted
$ app='Music Lyrics Bar.app'
$ lipo -archs "$app/Contents/MacOS/MusicLyricsBar"
x86_64 arm64
$ plutil -p "$app/Contents/Info.plist"
  "CFBundleShortVersionString" => "0.0.6"
  "CFBundleVersion" => "8"
  "LSMinimumSystemVersion" => "13.0"
$ codesign --verify --deep --strict --all-architectures "$app"
$ codesign -dvv "$app"
Signature=adhoc
TeamIdentifier=not set
$ spctl --assess --type execute -vv "$app"
Music Lyrics Bar.app: rejected
$ echo $?
3
```

The initial sandboxed assessment returned `internal error in Code Signing subsystem` (exit 1). The transcript uses the subsequent host assessment with access to the macOS policy service. [Repeat the checks](release-runbook.md)

## Copy sweep at 27008f9

Line numbers refer to the [starting tree](https://github.com/mytrashcan/applemusic-menubar-lyrics/tree/27008f9), so they identify the text before correction. Searched tracked files case-insensitively for `0.0.5`, `Apple Silicon only`, `arm64 ZIP`, `build from source`, `staged for a future` and `cannot install the current`. Also checked architecture, cask, signing and first-launch wording, including both Chinese drafts. The last two literal phrases had no matches.

| Original file and lines | Finding and disposition |
| --- | --- |
| `docs/launch/reddit-macapps.md:17,21` | Restricted the ZIP to Apple Silicon, sent Intel users to source and left the warning without the Settings step. Corrected the body and author reply. |
| `docs/launch/show-hn.md:17` | Called the public ZIP Apple Silicon only. Supplied both slices and the first-launch path in the comment draft. |
| `docs/launch/hellogithub.zh.md:23` · `docs/launch/ruanyf-weekly.zh.md:9` | Both described an Apple Silicon ZIP and an Intel source-build workaround. Both now describe the universal ZIP and identify Open Anyway in Chinese and English. |
| `docs/launch/x-post.md:3,7,11` | No obsolete architecture claim, but someone seeing only the post would miss the trust decision. All three variants now include the platform, warning and Settings path. |
| `docs/launch/README.md:3,7,13,18,23–25` | The old index sent Intel users to source, linked the prior release for timing, treated the cask and public README as pending, and left signing, preview and topics on the action list. Replaced the calendar with a link to the current checklist. |
| `docs/launch/audit.md:3,5,13,15,17–40` | Former baseline and credentialed release procedure read as current blockers. Kept the original findings and distinguished the fixed instructions from the remaining Gatekeeper rejection. |
| `docs/launch/audit.md:42,44,46,48` | The original Intel finding, local build and handoff predated the public x86_64 slice. Marked the download fix with fresh evidence and retained the hardware-test boundary. |
| `docs/launch/audit.md:50,52,54–64,77,79,83,98` | Cask mismatch and future HTTP check superseded by the public pin. Kept the historical version, ZIP names and digests as a labeled comparison. Replaced the old release-note pointer, pending card and topic actions with current evidence. |
| `docs/launch/release-runbook.md:1–33,36,41,43,47,65–66,74,76` | Offered v0.0.6 as an available tag, centered credential setup, expected Gatekeeper acceptance and described the pin as a draft. Replaced with the existing tag UI path, dispatch distinction and ad-hoc verification results. |
| `docs/launch/status.md:3,13–19,34,38,40–42,52,58,69,87,92,94` | Old post lengths, arm64 ZIP, seeded-cache install, draft pin and future handoff belong to the initial audit. Marked the report historical and preserved its original commands and results. |
| `docs/launch/status-2.md:3,8–11,16–17,35,79,140,148,172,178` | The arm64 launch guidance, pending hosted run, pending social card and pending public install are superseded. Old build output, checksums and cask rehearsal remain valid as historical evidence. |
| `LEARN.md:397–399` | Right-click → Open is obsolete guidance for a downloaded unnotarized app on newer macOS. Replaced with the per-app Settings path. [Apple’s Sequoia change](https://developer.apple.com/news/?id=saqachfa) |
| `README.md:92` | “Build from source” is a general developer section. Lines 61–79 already give the universal download, cask and first-launch instructions. |
| `Resources/Info.plist:9–10` | Source builds still use `0.0.5` / `5`. The tag job stamps the checked-out plist from the tag and adds the run number. The downloaded bundle reports `0.0.6` / `8`. |

The public release notes still tell tap users to re-pin the cask. The default-branch cask already pins this ZIP. Readers can use the two README commands as written. [Release notes](https://github.com/mytrashcan/applemusic-menubar-lyrics/releases/tag/v0.0.6) · [Install guide](../../README.md#getting-started)

## Findings in the two protected files

- `SECURITY.md:32–33` sends readers to **Report a vulnerability**. The repository’s private vulnerability reporting API returned `{"enabled":false}`. The checklist gives the owner the UI fix. [Policy](../../SECURITY.md#reporting-a-vulnerability) · [Setting](https://api.github.com/repos/mytrashcan/applemusic-menubar-lyrics/private-vulnerability-reporting)
- `docs/HOW-IT-WORKS.md:89` attributes “Waiting for Music” to Automation denial. Denial sets `isConnected = false`, opens the status window with a permission message and selects the “Connect to Music” label. “Waiting for Music” is the connected state without a sample. [App state and label](../../Sources/MusicLyricsBar/App.swift) · [Permission message](../../Sources/MusicLyricsBar/MusicReader.swift)

## Files changed

| Files | Change |
| --- | --- |
| `docs/launch/reddit-macapps.md`, `docs/launch/show-hn.md`, `docs/launch/x-post.md`, `docs/launch/hellogithub.zh.md`, `docs/launch/ruanyf-weekly.zh.md` | Updated public copy for both architectures and the first-launch warning. |
| `docs/launch/README.md`, `docs/launch/audit.md`, `docs/launch/release-runbook.md` | Updated owner navigation, P0 dispositions and hosted workflow verification. |
| `docs/launch/status.md`, `docs/launch/status-2.md` | Labeled the two earlier verification records. |
| `LEARN.md` | Corrected first-launch instructions. |
| `docs/launch/publish-checklist.md`, `docs/launch/status-3.md` | Added the posting package and this verification record. |

**Biggest remaining risk.** A listener may reasonably decline the Gatekeeper exception and leave before hearing the song with lyrics in the menu bar.
