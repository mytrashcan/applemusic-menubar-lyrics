#!/bin/bash
set -euo pipefail
umask 077
root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$root"
demo="$root/scripts/demo"
if [[ $# == 0 ]]; then
    review=$(mktemp -d "${TMPDIR:-/tmp}/lyrics-review.XXXXXXXX")
elif [[ $# == 2 && $1 == --review-dir && ! -e $2 ]]; then
    mkdir -m 700 "$2"
    review=$(cd "$2" && pwd)
else
    echo "Usage: $0 [--review-dir NEW_DIRECTORY]" >&2
    exit 2
fi
work=$(mktemp -d "${TMPDIR:-/tmp}/lyrics-capture.XXXXXXXX")
app_pid= doc_pid= started=
cleanup() {
    local result=$?
    trap - EXIT
    if [[ -n $started ]]; then osascript -e 'tell application "Music" to stop' || result=1; fi
    if [[ -n $doc_pid ]]; then kill "$doc_pid" || result=1; wait "$doc_pid" || :; fi
    if [[ -n $app_pid ]]; then kill "$app_pid" || result=1; fi
    rm -rf -- "$work"
    exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT TERM
die() { echo "$*" >&2; exit 1; }
for tool in screencapture osascript ffmpeg ffprobe python3 swiftc; do command -v "$tool" >/dev/null || die "Missing $tool"; done
if pgrep -x MusicLyricsBar >/dev/null; then die "Quit the running Music Lyrics Bar before capture."; fi
[[ $(osascript -e 'tell application "Music" to get player state') == stopped ]] || die "Stop Music before capture."
screencapture -x -m "$work/preflight.png"
[[ -s "$work/preflight.png" ]] || die "Screen Recording preflight failed."
bash scripts/build-app.sh
swiftc -O -I Sources/CSQLite Sources/LyricsCore/*.swift "$demo/main.swift" -o "$work/helper"
helper="$work/helper"
osascript "$demo/library.applescript" > "$work/library.json"
"$helper" select "$work/library.json" > "$work/selection"
track_id=$(sed -n '1p' "$work/selection")
cue=$(sed -n '2p' "$work/selection")
"$helper" prompt
open -n -g -a "$root/dist/Music Lyrics Bar.app" --args -connectOnLaunch YES -lyricsWidth 200
for ((i=0; i<30; i++)); do
    app_pid=$(pgrep -x MusicLyricsBar || :)
    [[ -z $app_pid ]] || break
    sleep 0.2
done
[[ $app_pid =~ ^[0-9]+$ ]] || die "Expected one newly launched MusicLyricsBar process."
sleep 3
if ! "$helper" prompt; then
    app_pid=  # Leave the requester alive for the owner to answer.
    die "Check the pending macOS dialog for Music Lyrics Bar → Music."
fi
current_region() {
    screencapture -x -m "$work/idle.png" || return
    "$helper" region "$app_pid" "$work/idle.png"
}
region=${DEMO_REGION:-$(current_region)}
[[ $region =~ ^([0-9]+),0,([0-9]+),([0-9]+)$ ]] || die "Invalid menu-bar rectangle: $region"
(( BASH_REMATCH[2] >= 180 && BASH_REMATCH[2] <= 660 && BASH_REMATCH[3] >= 60 && BASH_REMATCH[3] <= 180 )) || die "Unsafe recording dimensions"
"$helper" document "${region%%,*}" &
doc_pid=$!
sleep 1
[[ $("$helper" front) == "$doc_pid" ]] || die "Neutral document did not become frontmost."
if [[ -z ${DEMO_REGION:-} ]]; then
    updated=$(current_region)
    IFS=, read -r old_x _ old_w old_h <<< "$region"
    IFS=, read -r new_x _ new_w _ <<< "$updated"
    # The item is right-aligned and its width follows the label ("Waiting for Music" vs a
    # lyric line), and macOS reflows neighbours when the document becomes frontmost. So the
    # edges legitimately move: record the union of both rectangles instead of demanding a
    # fixed position, and keep a sanity bound on the result.
    union_x=$(( new_x < old_x ? new_x : old_x ))
    union_right=$(( new_x + new_w > old_x + old_w ? new_x + new_w : old_x + old_w ))
    region="$union_x,0,$(( union_right - union_x )),$old_h"
    (( union_right - union_x <= 900 )) || die "Union region is too wide: $region"
fi
started=yes
osascript - "$track_id" "$cue" <<'APPLESCRIPT'
on run argv
    set songID to item 1 of argv
    set cue to (item 2 of argv) as real
    tell application "Music"
        play (first track of library playlist 1 whose persistent ID is songID)
        repeat 40 times
            if player state is playing and persistent ID of current track is songID then exit repeat
            delay 0.25
        end repeat
        if player state is not playing or persistent ID of current track is not songID then error "Selected library track did not start."
        set player position to cue - 5
    end tell
end run
APPLESCRIPT
sleep 4
"$helper" prompt
[[ $("$helper" front) == "$doc_pid" ]] || die "Document lost focus before capture."
IFS=, read -r x y width height <<< "$region"
echo "Recording $region (display points) starting $(date '+%Y-%m-%d %H:%M:%S %Z')"
# Record the region itself: a full-display movie plus an arithmetic crop depended on
# keeping points and pixels straight, and a mismatch produced a privacy-bounded but empty
# frame. -R takes display points and records exactly those pixels.
# -V counts in a way that yields ~0.63x the requested seconds on this host (3 -> 1.9 s,
# 23 -> 16.3 s), so ask for 35 to leave room for the 16-second trim.
screencapture -x -v -V35 -R"$x,0,$width,$height" -D1 "$work/region.mov"
echo "Recording ended $(date '+%Y-%m-%d %H:%M:%S %Z')"
osascript -e 'tell application "Music" to stop'
started=
kill "$doc_pid"
wait "$doc_pid" || :
doc_pid=
IFS=, read -r x y width height <<< "$region"
ffmpeg -nostdin -hide_banner -loglevel error -i "$work/region.mov" -map 0:v:0 -an \
    -c:v ffv1 -map_metadata -1 "$review/region.mkv"
# Trim from 0: the recording starts after the app has already matched the track, and the
# earlier 1-second default left fewer than 16 seconds on this host (15.83 s).
bash "$demo/postprocess.sh" "$review/region.mkv" "${DEMO_TRIM_START:-0}" "$review"
echo "Review the opening shading, moving lyrics and privacy across the whole clip in $review"
if [[ $# == 0 ]]; then
    open "$review/demo-16s.mp4"
    read -r -p 'Type ACCEPT after visual review to install the video and poster: ' answer
    [[ $answer == ACCEPT ]] || die "Candidate kept in $review"
    install -m 644 "$review/demo-16s.mp4" "$review/demo-poster.png" docs/images/
fi
