# Accessibility

This page separates what the code does from what has been observed on hardware.
Nothing here was tested with VoiceOver by a screen-reader user on a physical machine —
those rows say **unverified**, and the open issue is
[#6](https://github.com/mytrashcan/applemusic-menubar-lyrics/issues/6).

## Menu bar item

`Sources/MusicLyricsBar/App.swift`

| Behavior | State |
| :--- | :--- |
| Accessibility identifier | `MusicLyricsBar.Lyrics` — set |
| Accessibility label | `Music Lyrics Bar` — set |
| Accessibility value | Updated whenever the displayed line changes: the track title plus the current lyric line, or `Waiting for Music` / `Connect to Music` when there is no sample |
| Keyboard reach | Status items are reachable with macOS menu-bar navigation (Control-F8 by default), then arrow keys and Space to open the menu. That is system behavior, not app code — **unverified in this app** |

Because the menu bar shows a rendered image, the string VoiceOver reads is the
accessibility **value**, not the pixels. Word-level highlighting is not exposed per word:
a screen reader hears the current line, not which word is being sung.

## Song popover

`Sources/MusicLyricsBar/LyricPopover.swift`

- Track title is a normal text field and is announced as text.
- The lyric preview is an image view; it now carries the label `Current lyric`.
- With **Reduce Motion** enabled, `popover.animates` is set to `false`, so the popover
  opens without the animation.

## Status window

`Sources/MusicLyricsBar/StatusWindow.swift`

| Control | Announced as |
| :--- | :--- |
| Current lyric | text field, identifier `currentLyric` |
| Playback position and timing | identifier `playbackMetrics`, label `Playback position and timing` |
| Connect / Reconnect | button title `Connect to Music…` |
| Width | popup button with the width titles as items |
| Close | standard window close button |

Tab order and full keyboard traversal of these controls are **unverified**.

## Reduce Motion: what actually moves

Two different things move, and Reduce Motion only affects one of them.

1. **The popover animation** — suppressed, as above.
2. **The lyric itself** — the sung words brighten as playback advances, and long lines
   scroll inside the menu bar item. This is the product, not decoration, so it keeps
   moving when Reduce Motion is on. Hiding it would remove the only thing the app does.

Only **line changes and word brightening inside a still item** are motion here; there is
no sliding or scaling animation in the menu bar item itself. The exact visual rate on a
long line with word timing versus a line without timing has not been measured on
hardware — **unverified**.

## Known gaps

- No per-word announcement; a screen reader hears the line only.
- VoiceOver reading order of the status window, and whether every control is reachable by
  keyboard, are untested.
- No high-contrast or increase-contrast check has been done.
- The app is not localized; all UI strings are English.

## How to verify

Build `main`, then with VoiceOver (⌘F5) focus the menu bar item with Control-F8 and
listen to the announced value while playback advances; open the popover and the status
window and walk every control with VO-Right. Record the macOS version, the app commit,
and the track used. Report anything that reads wrong as a new issue with the announced
string, not with a screenshot of your lyrics.
