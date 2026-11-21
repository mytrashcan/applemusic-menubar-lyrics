#!/bin/bash
# Called on a disposable macOS runner after build-app.sh --universal.
set -euo pipefail
app=${1:?expected path to the built app}
archive=${2:?expected output ZIP path}
umask 077
work=$(mktemp -d "${RUNNER_TEMP:?}/music-lyrics-sign.XXXXXX")
keychain="$work/release.keychain-db"
cleanup() {
    security delete-keychain "$keychain" >/dev/null 2>&1 || true
    rm -rf "$work"
}
trap cleanup EXIT

keychain_password=$(openssl rand -hex 32)
security create-keychain -p "$keychain_password" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$keychain_password" "$keychain"
printf '%s' "$DEVELOPER_ID_P12_BASE64" | base64 -D > "$work/identity.p12"
security import "$work/identity.p12" -k "$keychain" -P "$DEVELOPER_ID_P12_PASSWORD" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple: -s -k "$keychain_password" "$keychain" >/dev/null

# Select the Developer ID Application certificate for the notary team.
identity=$(security find-identity -v -p codesigning "$keychain" |
    awk -v team="$APPLE_TEAM_ID" '/"Developer ID Application: / && index($0, "(" team ")\"") {print $2}')
if [[ ! "$identity" =~ ^[[:xdigit:]]{40}$ ]]; then
    echo 'Expected exactly one valid Developer ID Application identity for APPLE_TEAM_ID.' >&2
    exit 1
fi
codesign --force --keychain "$keychain" --sign "$identity" --options runtime --timestamp \
    --entitlements Resources/MusicLyricsBar.entitlements "$app"
codesign --verify --deep --strict --all-architectures "$app"

ditto -c -k --sequesterRsrc --keepParent "$app" "$work/submission.zip"
xcrun notarytool store-credentials release --keychain "$keychain" \
    --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_SPECIFIC_PASSWORD"
xcrun notarytool submit "$work/submission.zip" --wait --keychain-profile release --keychain "$keychain" \
    --output-format plist | tee "$work/submission.plist"
status=$(/usr/libexec/PlistBuddy -c 'Print status' "$work/submission.plist")
submission=$(/usr/libexec/PlistBuddy -c 'Print id' "$work/submission.plist")
echo "Notary submission $submission: $status"
[[ "$status" == Accepted ]]

xcrun stapler staple "$app"
xcrun stapler validate "$app"
ditto -c -k --sequesterRsrc --keepParent "$app" "$work/final.zip"
ditto -x -k "$work/final.zip" "$work/extracted"
extracted="$work/extracted/$(basename "$app")"
codesign --verify --deep --strict --all-architectures "$extracted"
xcrun stapler validate "$extracted"
spctl --assess --type execute --verbose=4 "$extracted"
mv "$work/final.zip" "$archive"
