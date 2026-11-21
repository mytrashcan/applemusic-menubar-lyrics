# Launch follow-up verification

**The remaining release blocker for a first post promising a normal Gatekeeper launch is a publicly downloadable, Developer ID–signed and notarized universal build.** The owner can already share the current arm64 release with its documented first-launch exception.

| Item | Status | Evidence or owner action |
| --- | --- | --- |
| 1. [Release automation](../../.github/workflows/release.yml) | DONE | Actionlint and PyYAML passed. The tag build and fallback shell steps ran locally. A credential-free tag produces Actions artifacts only. The publish job requires a successful signing step and a tag. |
| 1. Hosted artifact upload, signing, notarization, stapling and publication | NOT DONE | This Mac has zero valid identities and no notary profile. No workflow was dispatched or tag created. Owner should run the strict branch rehearsal, inspect the download, then tag the reviewed commit. |
| 2. [Owner runbook](release-runbook.md) | DONE | Includes annual membership, certificate and private-key export, local profile, all five matching workflow secrets, tag, public ZIP checks and cask installation. |
| 3. [Social card](../images/social-preview.png) | DONE | Opaque 1280 × 640 PNG, 107,418 bytes. Both English lines and the two lyric shades are readable at 320 × 160. [Capture and crop](../images/README.md) |
| 3. Repository social preview | NOT DONE | Owner should upload the PNG under Settings → Social preview → Edit, then inspect a fresh shared link. |
| 4. [Bug form](../../.github/ISSUE_TEMPLATE/bug-report.yml) | DONE | Replaced the existing form. Five required fields cover the two versions, current track's lyrics panel, status text and bar behavior. Both YAML files parsed. |
| 5. Intel link diagnostics | PARTIAL | Both slices link for macOS 13. The deprecated native build engine eliminates the stale search paths. Both engines encounter the arm-only compatibility archive. |
| 5. Intel test diagnostic and native regression | DONE | The explicit Intel request exits before compilation with the toolchain requirement. Both native test bundles passed, with the opt-in private-cache test skipped. |
| 5. Physical Intel and minimum-OS playback | NOT DONE | Owner should run the tests on Intel, then exercise the shipped ZIP on Intel and macOS 13. The runbook includes the playback sequence. Check first Finder launch on clean accounts on macOS 15 and 26 as identified in the audit. |
| 6. [Cask draft](../../Casks/README.md) | DONE | Ruby syntax passed. Homebrew parsed the final cask and installed the exact previously pinned local ZIP from a seeded cache. |
| 6. Public tap install | NOT DONE | The v0.0.5 universal asset does not exist. Publish the new ZIP, pin its verified digest on the default branch and run the two documented commands on a clean Homebrew install. |
| 7. Verification report | DONE | Local commands and observed results follow. No push, PR, tag, GitHub release, secret or repository setting was created or changed. |

## Starting state

The branch started at `0217135`. Only `ci.yml` existed in `.github/workflows`. Reused the audit's downloaded files. The checks below used local macOS 27.2.1 (26B131) with Apple Swift 6.4.2 on arm64. The work directory for this follow-up was `/private/tmp/lyrics-release-2.WfFXyS`.

```sh
w=/private/tmp/lyrics-release-2.WfFXyS
old=/private/tmp/music-lyrics-launch.IeQCtJ
security find-identity -v -p codesigning
xcrun notarytool history --keychain-profile ac-notary
(cd "$old" && shasum -a 256 -c SHA256SUMS && shasum -a 256 *arm64.zip)
codesign -dvv "$old/published/Music Lyrics Bar.app"
spctl --assess --type execute --verbose=4 "$old/published/Music Lyrics Bar.app"
shasum -a 256 dist/*universal.zip
```

The normal macOS keychain and assessment services reported `0 valid identities found`, `No Keychain password item found for profile: ac-notary` and `rejected` (assessment exit 3). The public ZIP checksum passed, the signature was `adhoc` and `TeamIdentifier=not set`. The rehashed public arm64 ZIP was `bbf49d3535d0bfacb1af059618d603db62cb1d49a13e779ba1225a04d36a2d33`. The original local universal ZIP was `3f31dbe614e3fe519f3229154d682856888c64af52e34f64fde030ab8ef91b97`.

## Workflow and form

Installed actionlint in the disposable directory and used the local Python installation with PyYAML. The Go install required network access. These validation commands exited 0. A separate structural check found all five secret names in the runbook and confirmed that artifact upload precedes the strict check.

```sh
env GOBIN="$w/bin" GOMODCACHE="$w/go-mod" GOCACHE="$w/go-build" go install github.com/rhysd/actionlint/cmd/actionlint@v1.7.12
"$w/bin/actionlint" .github/workflows/release.yml
py=/Library/Frameworks/Python.framework/Versions/3.12/bin/python3
"$py" -c 'import yaml; assert yaml.safe_load(open(".github/workflows/release.yml"))["on"]["push"]["tags"] == ["v*"]'
"$py" - <<'PY'
import yaml
for path in [".github/ISSUE_TEMPLATE/bug-report.yml", ".github/ISSUE_TEMPLATE/config.yml"]:
    data = yaml.safe_load(open(path))
    print(path, "OK")
    if "body" in data:
        fields = [f for f in data["body"] if "id" in f]
        assert len(fields) == 5 and all(f["validations"]["required"] for f in fields)
PY
bash -n scripts/notarize-app.sh
bash -n scripts/test.sh
git diff --exit-code 0217135 -- .github/workflows/ci.yml
```

For the ad-hoc rehearsal, extracted the workflow's actual shell steps with PyYAML. The source copy came from the pre-existing commit and uses the same universal builder. The tag name and run number below were shell inputs. Git's tag store was untouched.

```sh
mkdir "$w/checkout"
git archive HEAD | tar -x -C "$w/checkout"
"$py" - <<'PY'
from pathlib import Path
import yaml
w = Path("/private/tmp/lyrics-release-2.WfFXyS")
steps = yaml.safe_load(open(".github/workflows/release.yml"))["jobs"]["build"]["steps"]
for key, name in [(1, "build"), (2, "credentials"), (4, "checksum"), (6, "enforce")]:
    (w / (name + ".sh")).write_text(steps[key]["run"])
PY
(cd "$w/checkout" && GITHUB_REF_TYPE=tag GITHUB_REF_NAME=v0.0.6 GITHUB_RUN_NUMBER=1 GITHUB_OUTPUT="$w/build.out" bash -eo pipefail "$w/build.sh")
READY=false GITHUB_OUTPUT="$w/credentials.out" bash -eo pipefail "$w/credentials.sh"
(cd "$w/checkout/dist" && ASSET=MusicLyricsBar-v0.0.6-macOS-universal.zip bash -eo pipefail "$w/checksum.sh")
bash -eo pipefail "$w/enforce.sh"
```

The build emitted `asset=MusicLyricsBar-v0.0.6-macOS-universal.zip`. The missing-credentials step warned and returned `ready=false` with exit 0. The checksum step printed `MusicLyricsBar-v0.0.6-macOS-universal.zip: OK`. Invoking the strict step directly printed `::error::Notarization was required. Configure all five release secrets.` and exited 1. Repeating the build step with `GITHUB_REF_NAME=vbad` exited 1 before compilation. GitHub event routing, artifact transport and Apple service responses still need a hosted run.

```sh
asset=MusicLyricsBar-v0.0.6-macOS-universal.zip
ditto -x -k "$w/checkout/dist/$asset" "$w/extracted"
app="$w/extracted/Music Lyrics Bar.app"
codesign --verify --deep --strict --all-architectures "$app"
codesign -dvv "$app"
lipo -archs "$app/Contents/MacOS/MusicLyricsBar"
xcrun vtool -show-build "$app/Contents/MacOS/MusicLyricsBar"
/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$app/Contents/Info.plist"
```

The extracted app verified, was ad-hoc signed, reported version `0.0.6` and build `6`, and contained `x86_64 arm64` with `minos 13.0` in both slices.

## Social preview

Generated the card from the repository GIF using Pillow, then ran the following checks.

```sh
"$py" "$w/card.py"
sips -g pixelWidth -g pixelHeight -g hasAlpha docs/images/social-preview.png
stat -f '%z bytes' docs/images/social-preview.png
sips -z 160 320 docs/images/social-preview.png --out "$w/thumbnail.png"
```

Observed `pixelWidth: 1280`, `pixelHeight: 640`, `hasAlpha: no` and `107418 bytes`. In the actual downscaled copy I could read “Music Lyrics Bar” and “Apple Music lyrics in your menu bar”. The note remained distinct from the Japanese line. Its first characters were dark and the upcoming characters were pale gray on white.

## Toolchain and regression checks

```sh
d=$(xcode-select -p)
xcrun lipo -archs "$d/usr/lib/swift/macosx/libswiftCompatibilityPacks.a"
for f in Testing _Testing_Foundation; do
  xcrun lipo -archs "$d/Library/Developer/Frameworks/$f.framework/$f"
done
ls -d "$d/Developer/Library/Frameworks" "$d/Developer/usr/lib"
swift build -c release --product MusicLyricsBar --arch x86_64 --build-system native --scratch-path "$w/native-engine" -v
bash scripts/test.sh --arch x86_64
bash scripts/test.sh
bash scripts/build-app.sh --universal
```

The selected developer directory was `/Library/Developer/CommandLineTools`. All three libraries reported `arm64 arm64e`. Swift Build added both missing `Developer/…` search paths. The clean alternate-engine build printed `Build of product 'MusicLyricsBar' complete! (21.94s)`. It removed the search-path warnings, retained the compatibility archive warning and flagged `--build-system native` as deprecated. There is no full Xcode installed here. A search-path flag cannot supply the missing machine code. Disabling Swift runtime compatibility autolinking would change backward-deployment behavior for the macOS 13 target. The shipping build keeps the toolchain defaults.

The Intel test request exited 1 with this message:

```text
x86_64 test bundles require a toolchain with Intel Testing frameworks; use a physical Intel Mac.
```

The sandbox initially denied Swift's Clang module-cache write. With compiler-cache access, the native test command passed. These lines are from the test and build immediately following the diagnostic change:

```text
✔ Test run with 27 tests in 9 suites passed after 0.175 seconds.
➜ Test parsesExistingMusicCache() skipped.
✔ Test run with 18 tests in 4 suites passed after 0.151 seconds.
Build complete! (17.35초)
Build complete! (3.08초)
Built /tmp/applemusic-launch/dist/universal/Music Lyrics Bar.app
Packaged /tmp/applemusic-launch/dist/MusicLyricsBar-v0.0.5-macOS-universal.zip
```

The universal build exited 0 with these linker diagnostics:

```text
/private/tmp/applemusic-launch/Package.swift: MusicLyricsBar-product: ld: warning: search path '/Library/Developer/CommandLineTools/Developer/usr/lib' not found
/private/tmp/applemusic-launch/Package.swift: MusicLyricsBar-product: ld: warning: search path '/Library/Developer/CommandLineTools/Developer/Library/Frameworks' not found
/private/tmp/applemusic-launch/Package.swift: MusicLyricsBar-product: ld: warning: ignoring file '/Library/Developer/CommandLineTools/usr/lib/swift/macosx/libswiftCompatibilityPacks.a': fat file missing arch 'x86_64', file has 'arm64,arm64e'
```

Copied the rebuilt ZIP to `$w/rebuild/`, extracted it with `ditto -x -k`, and verified it with `codesign --verify --deep --strict --all-architectures`. Its slices were `x86_64 arm64`. Its digest was `d9dab7757cdbbf8f46123f7e2c3ffa1ce97b1dc8559322cfba92da03650a0b02`. Restored the saved, draft-pinned local ZIP to its original `dist/` path and rehashed both files. The different digests illustrate why the cask must eventually pin the exact published ZIP.

## Cask rehearsal

```sh
ruby -c Casks/music-lyrics-bar.rb
prefix="$w/brew"
tap="$prefix/Library/Taps/mytrashcan/homebrew-lyrics"
cask=mytrashcan/lyrics/music-lyrics-bar
mkdir -p "$prefix/bin" "$tap/Casks" "$w/apps" "$w/config/homebrew" "$w/brew-tmp" "$w/brew-cache"
cp /opt/homebrew/bin/brew "$prefix/bin/"
cp -cR /opt/homebrew/Library/Homebrew "$prefix/Library/"
cp Casks/music-lyrics-bar.rb "$tap/Casks/"
export XDG_CONFIG_HOME="$w/config" HOMEBREW_TEMP="$w/brew-tmp"
export HOMEBREW_CACHE="$w/brew-cache" HOMEBREW_LOGS="$w/brew-logs"
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_FROM_API=1 HOMEBREW_NO_ANALYTICS=1
brew_bin="$prefix/bin/brew"
"$brew_bin" trust --cask "$cask"
"$brew_bin" info --cask --json=v2 "$cask" > "$w/cask.json"
cache=$("$brew_bin" --cache --cask "$cask")
mkdir -p "$(dirname "$cache")"
cp "$w/MusicLyricsBar-v0.0.5-macOS-universal.zip" "$cache"
"$brew_bin" install --cask --appdir="$w/apps" "$cask"
codesign --verify --deep --strict --all-architectures "$w/apps/Music Lyrics Bar.app"
lipo -archs "$w/apps/Music Lyrics Bar.app/Contents/MacOS/MusicLyricsBar"
```

Ruby printed `Syntax OK`. Homebrew resolved the qualified cask to version `0.0.5`, the universal URL and the original local digest. The first install reached Homebrew's nested extractor and failed with `sandbox_apply: Operation not permitted`. Repeating the installation with access to that sandbox kept the same disposable prefix, cache and app directory. The install then printed `🍺  music-lyrics-bar was successfully installed!`. The installed app verified and printed `x86_64 arm64`. The public HTTP download awaits the final release.
