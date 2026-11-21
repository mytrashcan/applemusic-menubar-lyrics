#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

build_binary() {
    swift build -c release --product MusicLyricsBar "$@" >&2 || return
    local bin_dir
    bin_dir="$(swift build -c release --show-bin-path "$@")" || return
    printf '%s/MusicLyricsBar\n' "$bin_dir"
}

case "$#:${1:-}" in
    0:)
        app_dir="$PWD/dist/Music Lyrics Bar.app"
        archive="$PWD/dist/MusicLyricsBar.zip"
        ;;
    1:--universal)
        version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)
        app_dir="$PWD/dist/universal/Music Lyrics Bar.app"
        archive="$PWD/dist/MusicLyricsBar-v${version}-macOS-universal.zip"
        ;;
    *)
        echo "Usage: $0 [--universal]" >&2
        exit 2
        ;;
esac
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
executable="$app_dir/Contents/MacOS/MusicLyricsBar"
if [[ "${1:-}" == --universal ]]; then
    # Some SwiftPM toolchains use the same release bin path for both architectures.
    arm_binary="$(build_binary --arch arm64 --scratch-path .build/universal/arm64)"
    intel_binary="$(build_binary --arch x86_64 --scratch-path .build/universal/x86_64)"
    lipo -create "$arm_binary" "$intel_binary" -output "$executable"
    lipo "$executable" -verify_arch arm64
    lipo "$executable" -verify_arch x86_64
else
    binary="$(build_binary)"
    cp "$binary" "$executable"
fi
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
cp LICENSE "$app_dir/Contents/Resources/LICENSE"
codesign --force --sign - --options runtime \
    --entitlements Resources/MusicLyricsBar.entitlements "$app_dir"
codesign --verify --strict "$app_dir"
ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$archive"
printf 'Built %s\nPackaged %s\n' "$app_dir" "$archive"
