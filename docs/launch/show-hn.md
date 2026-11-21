## Title

Show HN: Apple Music’s cached lyrics, in the macOS menu bar

## Submission URL

https://github.com/mytrashcan/applemusic-menubar-lyrics

## First comment draft

I wanted to hide the Music window and still see which word was being sung. The interesting part turned out to be the copy of the lyrics Music leaves on disk after you open its lyrics panel.

Music Lyrics Bar reads the current recording and playback position through Apple Events, then opens Music’s cache read-only and parses the timed text (TTML). When the recording includes timed words or syllables, the menu bar can brighten them as playback advances. Some recordings only give it lines.

The cache is private. Matching can fail even when you can see lyrics in Music, and Apple could change the format underneath the app. I’d be interested in cases where the status window sees playback but can’t match the recording. The macOS version and status message would help. Please keep your cache files private.

The GIF shows actual playback. The current ZIP is Apple Silicon only and unnotarized. There’s also a local Swift build.

## Owner posting note

Use the draft as technical notes and write the submission in your own words. HN asks authors to avoid generated text. Submit the repository URL and stay available for questions. Every Show HN starts on shownew. A front-page appearance is a minority outcome. Plan for anything from silence to a useful cache report. [HN guidelines](https://news.ycombinator.com/newsguidelines.html) · [Show HN guidelines](https://news.ycombinator.com/showhn.html) · [Discussion of front-page outcomes](https://news.ycombinator.com/item?id=36590226)
