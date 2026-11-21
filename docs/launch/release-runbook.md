# Verify the v0.0.6 universal release

The [public release](https://github.com/mytrashcan/applemusic-menubar-lyrics/releases/tag/v0.0.6) ships an ad-hoc signed, unnotarized app. The owner distributes this build directly. The tag workflow’s publish job skipped. The release API attributes both public assets to `mytrashcan`. [Observed results](status-3.md)

## Find the tag build in Actions

1. Open **Actions → Universal release**. Select the **push** run for tag **v0.0.6** (run **#3**). The run title is the commit subject. [Tag run summary](https://github.com/mytrashcan/applemusic-menubar-lyrics/actions/runs/44904114630)
2. In **Jobs**, open **build**. **Test and build universal app** and the digest check succeeded. **Sign, notarize and repackage** and **Enforce requested notarization** were skipped. The summary lists **universal-adhoc** under **Artifacts**. That Actions download wraps the release ZIP and checksum. [Build job](https://github.com/mytrashcan/applemusic-menubar-lyrics/actions/runs/44904114630/job/136845957579)
3. The **publish** job shows **Skipped**. A tag alone cannot run it. The workflow also requires a successful signing step, which requires all five credentials. The public release is a separate distribution step for this launch. [Skipped job](https://github.com/mytrashcan/applemusic-menubar-lyrics/actions/runs/44904114630/job/136846203734) · [Workflow](../../.github/workflows/release.yml)

**Manual rehearsal.** An owner with write access can use **Actions → Universal release → Run workflow**, select **main** and leave **require-notarization** unchecked. A branch run names its inner ZIP with `universal-dispatch<run>` and skips publication. Checking the box on a credential-free dispatch fails the build *after* artifact upload. A tag push has no checkbox. Inspecting the existing runs is sufficient for this release. [Recorded branch rehearsal](https://github.com/mytrashcan/applemusic-menubar-lyrics/actions/runs/44902629975)

## Recheck the assets on a Mac

In a fresh shell, run the commands below. The digest and signature checks must succeed. Expect version `0.0.6`, build `8`, architectures `x86_64 arm64`, minimum OS `13.0`, `Signature=adhoc` and `TeamIdentifier=not set`.

```sh
set -e
work=$(mktemp -d)
cd "$work"
asset=MusicLyricsBar-v0.0.6-macOS-universal.zip
gh release download v0.0.6 --repo mytrashcan/applemusic-menubar-lyrics \
  --pattern "$asset" --pattern SHA256SUMS
shasum -a 256 -c SHA256SUMS
ditto -x -k "$asset" .
app="Music Lyrics Bar.app"
lipo -archs "$app/Contents/MacOS/MusicLyricsBar"
plutil -p "$app/Contents/Info.plist"
codesign -dvv "$app"
codesign --verify --deep --strict --all-architectures "$app"
```

Then run `spctl --assess --type execute -vv "Music Lyrics Bar.app"` in that directory. The expected result on the verification Mac was `rejected` (exit 3). An internal assessment error is inconclusive. For a trusted browser download, try opening the app from Applications, dismiss the verification warning, then choose **System Settings → Privacy & Security → Open Anyway** and confirm. [Apple’s first-launch guide](https://support.apple.com/en-us/102445)

## Check the cask and playback

Compare the ZIP basename and SHA-256 with the [cask](../../Casks/music-lyrics-bar.rb). Its app stanza must match the extracted bundle name. From the checkout, run `ruby -c Casks/music-lyrics-bar.rb`. The [Homebrew instructions](../../Casks/README.md) include the explicit tap URL and qualified cask name. The installed app retains quarantine and needs the same first-launch step.

For a physical Intel or macOS 13 playback report, use the shipped ZIP. Connect to Music, allow Automation, play a track, open its lyrics panel, then hide Music, pause, seek and switch tracks. Record the architecture, OS, Music version and redacted **Show Status** message. [Compatibility thread](https://github.com/mytrashcan/applemusic-menubar-lyrics/discussions/5)
