#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --product MusicLyricsBar
bin_dir="$(swift build -c release --show-bin-path)"
app_dir="$PWD/dist/Music Lyrics Bar.app"
mkdir -p "$app_dir/Contents/MacOS"
cp "$bin_dir/MusicLyricsBar" "$app_dir/Contents/MacOS/MusicLyricsBar"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
codesign --force --sign - --options runtime \
    --entitlements Resources/MusicLyricsBar.entitlements "$app_dir"
codesign --verify --strict "$app_dir"
ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$PWD/dist/MusicLyricsBar.zip"
printf 'Built %s\n' "$app_dir"
