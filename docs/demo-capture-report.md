# Demo capture report

Recorded on 2026-11-21 at 22:30 KST on the owner's Mac. The clip in
`docs/images/demo-16s.mp4` came from this run.

## What produced it

```bash
bash scripts/demo/capture-demo.sh --review-dir /tmp/demo-review
bash scripts/demo/postprocess.sh /tmp/demo-review/region.mkv 0 /tmp/demo-final
```

The second command re-encoded the accepted take with a 0-second trim, because the first
pass trimmed one second from a 16.83-second recording and produced 15.83 seconds. The
default in `capture-demo.sh` is now 0.

- Song: **How Sweet — 뉴진스**, 219.03 s, matched in both the local library and the
  syllable-timed cache (5 timed spans on the opening line, another timed line within 14 s
  of the cue at 8.243 s).
- Region: `1041,0,223,124` display points → 1080×596 output pixels at 2× backing scale.
- Recording: `screencapture -v -V35 -R…`, 35.017 s of region video, no audio track.
- Encode: H.264, `yuv420p`, 30 fps, 480 frames, 16.000 s, 253,011 bytes.

## Machine checks that ran

```
ffprobe: width=1080 height=596 nb_frames=480 duration=16.000000 size=253011
audio streams: 0
dark pixel count (menu-bar text), t=0 → 8 → 12 s: 24173 → 27490 → 30091
frame mean absolute difference, 0→4 → 8→12 s: 2.94 → 3.99
```

The text pixels change across the clip, which is what rules out a still frame. OCR was
tried on the menu-bar strip and returned nothing — the label is small and low-contrast for
tesseract — so visual acceptance was the owner's: he watched the file and confirmed the
lyric advances.

## Fixes this session added to the scripts

1. The item-locator guard demanded a fixed x position. The item is right-aligned and its
   width follows the label, so the x legitimately moves; the capture now records the union
   of the pre- and post-document rectangles.
2. A full-display recording plus an arithmetic crop produced an empty grey region (mean
   brightness 204, zero dark pixels). `screencapture -V -R` now records the region itself.
3. `set -u` failed on `x` because the coordinate parse sat after the recording call.
4. The 1-second default trim left 15.83 s; the default is now 0.

## Not verified

- No second display, no increased-contrast mode, no Intel Mac was tried.
- The clip's first frame was not checked for a partially drawn line; acceptance was by
  watching the whole file.
- Lyrics belong to the recording shown; publishing the clip is the owner's rights call.
