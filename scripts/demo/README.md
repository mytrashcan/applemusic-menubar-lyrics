# Record the menu-bar demo

Run from a macOS graphical login with Music open and stopped. Quit any running Music Lyrics Bar first. The script builds and opens the checkout's signed app bundle. It uses the Swift command-line tools, Python 3, and FFmpeg with `ffprobe`, FFV1 and libx264.

```bash
bash scripts/demo/capture-demo.sh
```

Allow Screen Recording for the terminal or host running the script. Both that host and Music Lyrics Bar need Automation access to Music. If macOS displays a permission dialog, stop and let the Mac's owner read and approve it. Quit the demo app and rerun after approval. The neutral “Field Notes” document is an ordinary AppKit window in a temporary helper process. It requires no TextEdit or System Events permission.

The AppleScript takes one bulk library inventory per run. The selector uses the same cache reader and TTML parser as the app, including filename-backed `fsCachedData` responses. It chooses the first library track with matching metadata, multiple timed spans and another timed line in the next 14 seconds. The terminal prints the song, duration and cue. If no track qualifies, add a song with time-synced lyrics to your library, play it in Music, open its lyrics to populate the cache, then stop it and rerun. The song must be playable in Music on this Mac.

Keep the main display awake with its menu bar visible. The script locates the idle lyric item by its window bounds or by reading “Waiting for Music” in the menu bar. If the item is hidden, make room or move it to a visible position. To supply its measured bounds yourself, set `DEMO_REGION=x,0,width,height` in **logical display points**, including about 90 points below the bar. Choose a rectangle containing only the lyric item and neutral document. Silence notifications before recording.

The script plays the selected library track by persistent ID, seeks five seconds before the cue, waits four seconds for lyrics, then records the located region itself with `screencapture -v -V35 -R…` (35 seconds, enough for the 16-second trim). Recording the region directly replaced a full-display movie plus an arithmetic crop, which produced an empty frame when the point-to-pixel math drifted. `-V` does not map one-to-one to seconds on every host, so check the printed `region.mkv` duration before trusting a short value. It stops playback and closes the temporary document before encoding. The original movie lives in a private temporary directory that the exit trap removes. Only a lossless region movie, an encoded candidate, its first frame and probe results remain in the printed review directory.

### Review and install

Watch the candidate through the end. Check for bright and dim words on frame one, visible lyric progression, readable text at 1080 pixels wide, and any private content. Type `ACCEPT` in the terminal to install the reviewed MP4 and poster in `docs/images/`. A rejected take stays outside the repository. Limit a failed recording session to three takes.

For inspection without opening a player, pass `--review-dir /path/to/a/new/private-directory`. This mode skips installation. To change the opening frame, rerun the encoder against the same lossless crop, choosing a start time that leaves at least 16 seconds. Review both outputs again before copying them.

```bash
bash scripts/demo/postprocess.sh "$review/region.mkv" 1 "$review"
```

### FFmpeg commands

`x`, `width` and `height` are the measured region in points. `display_width` is the main display width in points. The first command converts those values to the actual recording pixel grid and discards everything outside the region.

```bash
crop="crop=trunc(iw*$width/$display_width/2)*2:trunc(iw*$height/$display_width/2)*2:trunc(iw*$x/$display_width/2)*2:0"
ffmpeg -nostdin -hide_banner -loglevel error -i "$work/screen.mov" -map 0:v:0 -an \
    -vf "$crop" -c:v ffv1 -map_metadata -1 "$review/region.mkv"

ffmpeg -nostdin -hide_banner -loglevel error -y -ss "$start" -i "$raw" -t 16 \
    -map 0:v:0 -an -sn -dn -map_metadata -1 \
    -vf 'crop=iw-4:ih-4:2:2,fps=30,scale=1080:-2:flags=lanczos,setsar=1' \
    -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -movflags +faststart \
    "$out/demo-16s.mp4"
ffmpeg -nostdin -hide_banner -loglevel error -y -i "$out/demo-16s.mp4" \
    -map 0:v:0 -frames:v 1 -update 1 "$out/demo-poster.png"
```

`raw` is the lossless region movie. `start` defaults to 0 seconds (`DEMO_TRIM_START` overrides it); a 1-second default left only 15.83 seconds of a 16.83-second recording and the encoder rejected it. The encoder checks for one H.264 video stream, 480 frames, exactly 16 seconds and a file below 4,000,000 bytes.

The accepted take is `docs/images/demo-16s.mp4` with its poster frame; `docs/demo-capture-report.md` records the song, region, commands and what was not verified.
