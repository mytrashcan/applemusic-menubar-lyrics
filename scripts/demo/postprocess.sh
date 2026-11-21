#!/bin/bash
set -euo pipefail

if [[ $# != 3 ]]; then
    echo "Usage: $0 REGION.mov START_SECONDS REVIEW_DIRECTORY" >&2
    exit 2
fi
raw=$1 start=$2 out=$3
mkdir -p "$out"
# The input is already a privacy-bounded menu-bar rectangle in display points.
# Trim the two outside pixels on each edge and standardize phone playback at 1080px.
ffmpeg -nostdin -hide_banner -loglevel error -y -ss "$start" -i "$raw" -t 16 \
    -map 0:v:0 -an -sn -dn -map_metadata -1 \
    -vf 'crop=iw-4:ih-4:2:2,fps=30,scale=1080:-2:flags=lanczos,setsar=1' \
    -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -movflags +faststart \
    "$out/demo-16s.mp4"
ffmpeg -nostdin -hide_banner -loglevel error -y -i "$out/demo-16s.mp4" \
    -map 0:v:0 -frames:v 1 -update 1 "$out/demo-poster.png"
ffprobe -v error -count_frames -show_entries \
    'stream=index,codec_type,codec_name,width,height,pix_fmt,nb_read_frames:format=duration,size' \
    -of json "$out/demo-16s.mp4" | tee "$out/probe.json"
python3 - "$out/probe.json" <<'PY'
import json
import sys

with open(sys.argv[1]) as source:
    info = json.load(source)
streams = info["streams"]
if len(streams) != 1:
    sys.exit("Expected exactly one video stream and zero other streams")
v = streams[0]
if (v["codec_name"], v["pix_fmt"], v["width"], v["nb_read_frames"]) != ("h264", "yuv420p", 1080, "480"):
    sys.exit("Unexpected video format or incomplete recording")
if v["height"] % 2 or float(info["format"]["duration"]) != 16 or int(info["format"]["size"]) >= 4_000_000:
    sys.exit("Output failed height, duration or size check")
PY
