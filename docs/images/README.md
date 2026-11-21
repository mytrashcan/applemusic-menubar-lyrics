# Screenshot provenance

`menu-bar.gif`, `menu-bar.png`, and `status-window.png` are actual captures of Music Lyrics Bar
running on macOS 27.2 (26B123), Apple Silicon, on October 31, 2026. The app was built
from the implementation merged in PR #3 (`74c3307`). The native menu bar overflow
area was expanded to make the lyric item visible during capture.

The GIF contains 80 sequential screen captures sampled at 10 frames per second
for eight seconds during actual playback, encoded as a looping GIF at the same
nominal rate. It has no audio. Word shading and line changes are produced by
the running app, not composited or generated. The static image is available for
readers who prefer no animation.

The menu bar images are cropped to the lyric item. The status image trims unused
space below the controls. Neither image replaces or fabricates UI or lyrics.
The bright and dim text in the status preview comes from live word timing.
Screenshots show a moment in playback, not a timing or performance benchmark.

The displayed recording is 百花繚乱 by Lilas. Lyrics and Apple-related content
remain the property of their respective rights holders and are not covered by
the repository's WTFPL software license. Do not use these images as test fixtures.

## Social preview

[Social preview PNG](social-preview.png) uses frame 24 of the existing `menu-bar.gif` (zero-based). The frame shows a dark note and sung characters beside lighter upcoming characters. In capture-pixel coordinates, the crop runs from (8, 0) up to, but excluding, (328, 68). Pillow enlarged those pixels from 320 × 68 to 1120 × 238 with Lanczos resampling and rounded the outer blank corners. The lettering and shading inside the capture come directly from playback.

The crop sits at (80, 332) on an opaque 1280 × 640 plum gradient. The title and one-line description above it use Avenir Next. The finished PNG is 107,418 bytes. At 320 × 160, both English lines, the note, and the transition from dark `やってきた` to pale `この場所は` are visible.
