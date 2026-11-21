## Title

[OS] I made Music Lyrics Bar to follow Apple Music lyrics without switching windows

## Body

**Problem:** I wanted to catch the line I’d just misheard without leaving what I was reading.

I made Music Lyrics Bar for that. Play a track in Music, open its lyrics panel once, then go back to your window. The current line sits in the menu bar. If the recording has word timing, the words brighten as they’re sung.

It reads the timed lyrics Music has already cached on your Mac. If Music hasn’t saved a matching entry, the bar has nothing to show. Apple could change that cache in a macOS update.

**Comparison:** I like this approach because I get the words for the recording I’m already hearing, without looking them up elsewhere. I’d use LyricsX if I also wanted Spotify, or LyricFever if I wanted a fullscreen view or translations.

**Pricing:** Free. The GIF, source and download are on [GitHub](https://github.com/mytrashcan/applemusic-menubar-lyrics).

The downloadable app is for Apple Silicon, targets macOS 13+, and is ad-hoc signed and unnotarized. Intel owners can build from source. I’d especially like to hear where you got stuck if Music showed the lyrics but the bar stayed empty.

## First comment

Author here. Music automation gives my app the track and playback position. It opens Music’s local cache read-only and makes no network requests. I’d pick LyricsX for Spotify. If you’d rather inspect what you run, the Swift source and build steps are in the repo. The ZIP is ad-hoc signed, so expect a Gatekeeper warning.

## Owner posting note

Use the **body as a comment in the current App Pile** by default. Lead it with the title text. The required Problem, Comparison and Pricing fields are already there.

For a main-feed post, first check the account-age, karma, posting interval and approval requirements. Use the title above, the Free flair, and add the required **Trust:** line with your actual qualifying evidence. The repository’s star count alone does not qualify. If using the GitHub + LinkedIn route, include your own qualifying profile link and the moderator’s “Not SN” disclosure. Pick a single venue for this launch. [Moderator instructions](https://www.reddit.com/r/macapps/comments/1xo5ky1/) · [Posting rules](https://www.reddit.com/r/macapps/about/rules/)
