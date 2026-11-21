## Title

Show HN: Apple Music’s cached lyrics, in the macOS menu bar

## Submission URL

https://github.com/mytrashcan/applemusic-menubar-lyrics

## First comment draft

I wanted to hide the Music window and still see which word was being sung. The interesting part turned out to be the copy of the lyrics Music leaves on disk after you open its lyrics panel.

Music Lyrics Bar reads the current recording and playback position through Apple Events, then opens Music’s cache read-only and parses the timed text (TTML). When the recording includes timed words or syllables, the menu bar can brighten them as playback advances. Some recordings only give it lines.

The cache is private. Matching can fail even when you can see lyrics in Music, and Apple could change the format underneath the app. I’d be interested in cases where the status window sees playback but can’t match the recording. The macOS version and status message would help. Please keep your cache files private.

The GIF shows actual playback. The v0.0.6 ZIP includes arm64 and x86_64 for macOS 13+. It’s ad-hoc signed and unnotarized. On first launch, dismiss the verification warning. If you trust the download, choose System Settings → Privacy & Security → Open Anyway and confirm. The Homebrew cask carries the same quarantine flag as a browser download.

The whole path — Apple Events for playback, the title/artist/duration match, the TTML dialect — is written up in https://github.com/mytrashcan/applemusic-menubar-lyrics/blob/main/docs/HOW-IT-WORKS.md

## Owner posting note

Use the title and first comment as notes. Write the final submission and replies yourself and link the repository. HN asks authors to use their own words and be available to discuss what they built. [HN guidelines](https://news.ycombinator.com/newsguidelines.html) · [Show HN guidelines](https://news.ycombinator.com/showhn.html)
