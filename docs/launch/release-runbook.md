# Ship a notarized universal release

The public v0.0.5 ZIP contains an ad-hoc signed Apple Silicon app. Nothing in this repository fixes Gatekeeper for that download. A normal first launch requires distributing a new build with a Developer ID Application signature and an accepted notarization ticket. The Apple Developer Program is a paid annual membership. [Apple membership](https://developer.apple.com/programs/whats-included/) · [Developer ID distribution](https://developer.apple.com/developer-id/)

## Set up the owner's Mac once

1. Enroll in the Apple Developer Program or use your existing team. As Account Holder, open Keychain Access → Certificate Assistant → Request a Certificate From a Certificate Authority. Enter your email and common name, select **Saved to disk**, and save the certificate signing request.
2. In the developer account, open **Certificates, Identifiers & Profiles → Certificates → + → Developer ID Application**. Follow Apple's certificate assistant, upload the request, download the issued certificate, and double-click it on the Mac that created the request. In Keychain Access → login → My Certificates, expand **Developer ID Application** and confirm its private key is present. [Apple certificate instructions](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/)
3. Run `security find-identity -v -p codesigning`. Confirm the Developer ID Application identity is valid and shows your team ID. Export that identity and its private key from My Certificates as a password-protected `.p12`. Keep the file and password outside the checkout.
4. At **account.apple.com → Sign-In and Security → App-Specific Passwords**, generate a password for notarization. Copy your team ID from the developer account's membership details. On your Mac, substitute your Apple Account email and team ID below. Enter the app-specific password at the secure prompt. Successful validation and a history response confirm the profile works. [Apple notary workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)

```sh
xcrun notarytool store-credentials ac-notary --apple-id 'YOUR_APPLE_EMAIL' --team-id 'YOUR_TEAM_ID'
xcrun notarytool history --keychain-profile ac-notary
```

## Add the repository secrets

Open **Settings → Secrets and variables → Actions → New repository secret**. The hosted runner creates its own temporary keychain and notary profile from these five values. Your local profile stays on your Mac. [GitHub signing setup](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications)

| Repository secret | Value |
| --- | --- |
| `DEVELOPER_ID_P12_BASE64` | Base64 of the exported identity. To send it directly, run `base64 -i /path/to/identity.p12 \| gh secret set DEVELOPER_ID_P12_BASE64 --repo mytrashcan/applemusic-menubar-lyrics` on the owner's Mac. |
| `DEVELOPER_ID_P12_PASSWORD` | The password chosen during the .p12 export. |
| `APPLE_ID` | The Apple Account email used for notarization. |
| `APPLE_TEAM_ID` | The team ID on the certificate. |
| `APPLE_APP_SPECIFIC_PASSWORD` | The app-specific password used for the local notary profile. |

## Tag the release

Put the reviewed workflow on the public default branch first. To rehearse, select **Actions → Universal release → Run workflow**, choose that branch and enable **require-notarization**. A branch run produces Actions artifacts. Check the notarized artifact on an Intel Mac and on the minimum supported macOS before making hardware compatibility claims.

From the reviewed commit on the owner's Mac, choose a fresh `vMAJOR.MINOR.PATCH` tag. For example, if v0.0.6 is available, run these commands. The workflow stamps the runner's bundle version from the tag and adds the workflow run number to the checked-in build number.

```sh
tag=v0.0.6
git tag -a "$tag" -m "Music Lyrics Bar $tag"
git push origin "refs/tags/$tag"
```

Watch **Actions → Universal release**. The signing step checks Apple's acceptance, staples the app, reopens the final ZIP and assesses the extracted app. The publish job verifies the digest again and attaches the ZIP and `SHA256SUMS` to the tag. The GitHub CLI stages the assets in a draft before publishing them together. [GitHub CLI release creation](https://cli.github.com/manual/gh_release_create)

With any secret missing, a tag run uploads `universal-adhoc` and skips publication. With **require-notarization** enabled, a missing secret also fails the run after artifact upload. Invalid credentials or a rejected submission fail the signing step. Fix the credentials and rerun the workflow for the same tag. For a rejected submission, inspect the submission ID in the log with `xcrun notarytool log SUBMISSION_ID --keychain-profile ac-notary`. If a GitHub upload was interrupted, inspect Releases for an incomplete draft before retrying. A public release should contain both verified files.

## Verify the public download

Run this on macOS in the same shell with the new tag. Stop if any command fails. The ZIP must pass the published checksum, contain both architectures, have the expected bundle version and Developer ID team, pass Gatekeeper assessment, and carry a valid stapled ticket.

```sh
set -e
verify_dir=$(mktemp -d)
asset="MusicLyricsBar-${tag}-macOS-universal.zip"
gh release download "$tag" --repo mytrashcan/applemusic-menubar-lyrics \
  --pattern "$asset" --pattern SHA256SUMS --dir "$verify_dir"
cd "$verify_dir"
shasum -a 256 -c SHA256SUMS
ditto -x -k "$asset" .
app="Music Lyrics Bar.app"
lipo -archs "$app/Contents/MacOS/MusicLyricsBar"
lipo "$app/Contents/MacOS/MusicLyricsBar" -verify_arch arm64
lipo "$app/Contents/MacOS/MusicLyricsBar" -verify_arch x86_64
test "$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")" = "${tag#v}"
codesign -dvv "$app"
codesign --verify --deep --strict --all-architectures "$app"
spctl --assess --type execute --verbose=4 "$app"
xcrun stapler validate "$app"
shasum -a 256 "$asset"
```

On a physical Intel Mac with full Xcode and Intel Swift Testing frameworks, check out the release tag and run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash scripts/test.sh --arch x86_64`. For the user-facing test, download the published ZIP with Safari and open the extracted app from Applications on a clean account. Connect to Music, play a track, open its lyrics panel, hide Music, then pause, seek and switch tracks. Record the Mac architecture, OS and Music versions, and the message in **Show Status**. Repeat the launch and playback checks on macOS 13.

## Pin and install the cask

Back in the repository, set `version` in `Casks/music-lyrics-bar.rb` to the published version without `v`. Set `sha256` to the final digest printed above and remove the draft-pin comment. Run `ruby -c Casks/music-lyrics-bar.rb` and put the updated cask on the public default branch. Signing, timestamps and stapling change the ZIP bytes.

On a clean Homebrew installation with an empty download cache, run the two commands below. The explicit Git URL selects this repository as the tap. If Homebrew asks you to trust the cask, review the cask and follow the displayed trust prompt, then repeat the install. Open the installed app and confirm the first lyric before updating the README's draft-install notice. [Cask handoff](../../Casks/README.md)

```sh
brew tap mytrashcan/lyrics https://github.com/mytrashcan/applemusic-menubar-lyrics.git
brew install --cask mytrashcan/lyrics/music-lyrics-bar
```
