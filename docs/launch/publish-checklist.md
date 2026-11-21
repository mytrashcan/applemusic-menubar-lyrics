# Owner’s v0.0.6 posting checklist

## Do first, in the owner UI

1. **Check the social preview.** Open repository **Settings → Social preview**. The live image already matches [docs/images/social-preview.png](../images/social-preview.png). If the preview has changed, choose **Edit → Upload an image** and select that PNG. Check the title and lyric are legible in the preview.
2. **Record the demo.** Follow the [16-second silent shot list](audit.md#social-card-and-silent-demo) with a track you have permission to show. Capture the sung words, open the same track’s lyrics panel, hide Music, then show the status window. Crop unrelated windows and account details. Play back the clip at phone size before attaching it.
3. **Restore the private reporting link before sharing.** GitHub reports the route named in the security policy is disabled. In repository **Settings → Advanced Security → Private vulnerability reporting**, choose **Enable**. Open **Security → Advisories** and confirm **Report a vulnerability** is available. [Security policy](../../SECURITY.md#reporting-a-vulnerability) · [GitHub settings guide](https://docs.github.com/en/code-security/how-tos/report-and-fix-vulnerabilities/configure-vulnerability-reporting/configure-for-a-repository)
4. **Start the posts.** D is the first day you can stay for a full hour. Use the slots below as appointments in Korea Standard Time. Before each post, open the [v0.0.6 release API](https://api.github.com/repos/mytrashcan/applemusic-menubar-lyrics/releases/tags/v0.0.6), find the universal ZIP under `assets`, and note its `download_count` and the KST time. Keep that tab for the half-hour check.

## What NOT to say

- “Notarized” or “Apple verified it” misstates the ad-hoc signature and the Gatekeeper rejection.
- “Works on Intel without a warning” promises a first launch the Intel slice cannot provide. The ZIP and cask both require the trust decision.
- “Available on the App Store” gives readers the wrong destination. Link the GitHub project and its release.
- Star targets and trending predictions have no measured basis. Report only an observed count and its observation time when needed.
- “댓글에서 Open Anyway 안내” leaves the reader without install instructions if they never open the replies. Put **System Settings → Privacy & Security → Open Anyway** in the post itself.

## Posting order

### D · 19:48 KST · r/macapps

Open [r/macapps](https://www.reddit.com/r/macapps/), find the current App Pile and check you have not used this month’s entry. In Markdown mode, paste the title and body below as **one comment**. The project link is in Pricing. Use this venue once. The [owner note](reddit-macapps.md#owner-posting-note) covers eligibility if you choose the main feed instead.


```text
[OS] I made Music Lyrics Bar to follow Apple Music lyrics without switching windows

**Problem:** I wanted to catch the line I’d just misheard without leaving what I was reading.

I made Music Lyrics Bar for that. Play a track in Music, open its lyrics panel once, then go back to your window. The current line sits in the menu bar. If the recording has word timing, the words brighten as they’re sung.

It reads the timed lyrics Music has already cached on your Mac. If Music hasn’t saved a matching entry, the bar has nothing to show. Apple could change that cache in a macOS update.

**Comparison:** I like this approach because I get the words for the recording I’m already hearing, without looking them up elsewhere. I’d use LyricsX if I also wanted Spotify, or LyricFever if I wanted a fullscreen view or translations.

**Pricing:** Free. The GIF, source and download are on [GitHub](https://github.com/mytrashcan/applemusic-menubar-lyrics).

The v0.0.6 ZIP contains one universal app for Apple Silicon and Intel on macOS 13+. It’s ad-hoc signed and unnotarized. On first launch, dismiss the verification warning. If you trust the download, go to **System Settings → Privacy & Security → Open Anyway** and confirm. Homebrew installs the same app with the same warning.
```

**First hour.** Stay in the App Pile thread. Answer the first-launch and LyricsX questions below. If someone sees playback but no lyric, use this author reply. Run the half-hour check before leaving the thread.


```text
Author here. If Music shows lyrics but the bar stays empty, choose **Show Status**. I’d love to know your macOS version and what the status message says, with the song title and lyrics removed.
```

### D+1 · 19:48 KST · X

Open the [composer](https://x.com/compose/post), attach the silent clip and post this single text block. X has no separate title. Use the caption as on-screen text for the closing shot. The other [two variants](x-post.md) are alternatives for this slot.


```text
Timed words light up in the menu bar using Apple Music’s cached lyrics. Intel & Apple Silicon, macOS 13+. Unnotarized. If you trust the ZIP, dismiss the warning and choose System Settings → Privacy & Security → Open Anyway. https://github.com/mytrashcan/applemusic-menubar-lyrics
```

**Demo caption**

```text
Watch the menu bar as Music is hidden. The bright words follow the song while the document stays in front.
```

**First hour.** Play the posted clip on a phone, open its project link, and answer Intel or Gatekeeper questions in the original thread. Check issues and ZIP downloads at 20:18 KST.

### D+2 · 19:48 KST · Show HN

Open the [Show HN submission form](https://news.ycombinator.com/submit). Paste the repository URL in the URL field. Use the title and first-comment draft below as a factual reference, then enter your own words. HN asks people to write their own submissions and comments. Keep the private-cache limitation and Open Anyway path in your final text. [HN guidelines](https://news.ycombinator.com/newsguidelines.html)

**Title draft**

```text
Show HN: Apple Music’s cached lyrics, in the macOS menu bar
```

**Submission URL**

```text
https://github.com/mytrashcan/applemusic-menubar-lyrics
```

**First comment draft**

```text
I wanted to hide the Music window and still see which word was being sung. The interesting part turned out to be the copy of the lyrics Music leaves on disk after you open its lyrics panel.

Music Lyrics Bar reads the current recording and playback position through Apple Events, then opens Music’s cache read-only and parses the timed text (TTML). When the recording includes timed words or syllables, the menu bar can brighten them as playback advances. Some recordings only give it lines.

The cache is private. Matching can fail even when you can see lyrics in Music, and Apple could change the format underneath the app. I’d be interested in cases where the status window sees playback but can’t match the recording. The macOS version and status message would help. Please keep your cache files private.

The GIF shows actual playback. The v0.0.6 ZIP includes arm64 and x86_64 for macOS 13+. It’s ad-hoc signed and unnotarized. On first launch, dismiss the verification warning. If you trust the download, choose System Settings → Privacy & Security → Open Anyway and confirm. The Homebrew cask carries the same quarantine flag as a browser download.

The whole path — Apple Events for playback, the title/artist/duration match, the TTML dialect — is written up in https://github.com/mytrashcan/applemusic-menubar-lyrics/blob/main/docs/HOW-IT-WORKS.md
```

**First hour.** Add your own first comment as soon as you submit. Stay on the discussion page and explain a failed match using the cache reply below. If someone offers to send a cache, ask for the redacted status message instead. Check issues and downloads at 20:18 KST.

### D+3 · 19:48 KST · HelloGitHub

Search [HelloGitHub](https://hellogithub.com) and its [submission issues](https://github.com/521xueweihan/HelloGitHub/issues) for the project URL first. If there is a submission, follow that thread and skip creating a duplicate. Otherwise open [提交项目](https://github.com/521xueweihan/HelloGitHub/issues/new?template=submit-cn.yaml). Replace the default issue title, select Swift in the category dropdown and paste the other fields separately. Leave optional 示例代码 empty.

**Issue title**

```text
[开源自荐] Music Lyrics Bar：在 Mac 菜单栏跟着 Apple Music 看歌词
```

**项目地址**

```text
https://github.com/mytrashcan/applemusic-menubar-lyrics
```

**类别**

```text
Swift
```

**项目标题**

```text
在 Mac 菜单栏看 Apple Music 的逐词歌词
```

**项目描述**

```text
我是 Music Lyrics Bar 的作者。用 Mac 看书时，想看清刚唱过去的那句词，又不想来回切窗口，就写了这个菜单栏小工具。在 Apple Music 里播放一首歌，点开一次歌词面板，再切回书页。抬头看菜单栏，就能看到正唱到哪一句。
```

**亮点**

```text
- 直接读「音乐」已经缓存在本机的歌词，不用申请 API 密钥。缓存里带有词或音节的时间戳时，唱过的部分会逐渐亮起来；只有行时间戳时就逐行显示。
- 想看实现的话，可以从 Swift 代码里看到它怎样用 Apple Events 读取播放进度，再从本地缓存匹配同一录音。缓存是苹果的私有格式，系统更新后可能失效，匹配不上时也不会去别处补词。
- v0.0.6 提供通用版 ZIP，内含 Apple Silicon 和 Intel 两种架构，适用于 macOS 13 及以上版本。应用采用临时签名，未经苹果公证。首次打开时，先关闭系统验证提示。如果你信任下载来源，请到「系统设置 → 隐私与安全性」，为 Music Lyrics Bar 选择「仍要打开」（Open Anyway）并确认。
```

**截图或演示视频**

```text
![实机录屏：唱过的词在菜单栏里逐渐亮起](https://raw.githubusercontent.com/mytrashcan/applemusic-menubar-lyrics/main/docs/images/menu-bar.gif)
```

**First hour.** Check the GIF in the submitted form preview and watch the issue for editor questions. For an Intel or cache question, use the Chinese replies below. Check your own repository’s issues and downloads at 20:18 KST.

### D+4 · 19:48 KST · 科技爱好者周刊

Search the [weekly issues](https://github.com/ruanyf/weekly/issues) for the project URL. If it is new, open a [new issue](https://github.com/ruanyf/weekly/issues/new). Paste the title and body separately. The body contains both the project and demo URLs.

**Issue title**

```text
[开源自荐] Music Lyrics Bar：把正在唱的那句歌词放到 Mac 菜单栏
```

**Issue body**

```text
阮老师好，自荐一个我写的 Mac 小工具。

**Music Lyrics Bar** 把 Apple Music 正在唱的那句词放进菜单栏。比如写东西时没听清一句，抬眼就能看，不用切回「音乐」。有逐词时间戳的歌，唱到哪里，文字就亮到哪里。

它的做法有点取巧：先在「音乐」里点开这首歌的歌词面板，等歌词缓存在本机，再根据播放进度显示。整个过程不用额外的歌词服务，也不用填 API 密钥。代价是，如果「音乐」没缓存这份歌词，或者苹果改了缓存格式，小工具就可能显示不出来。

v0.0.6 提供通用版 ZIP，内含 Apple Silicon 和 Intel 两种架构，适用于 macOS 13 及以上版本。应用采用临时签名，未经苹果公证。首次打开时，先关闭系统验证提示。如果你信任下载来源，请到「系统设置 → 隐私与安全性」，为 Music Lyrics Bar 选择「仍要打开」（Open Anyway）并确认。

项目地址：https://github.com/mytrashcan/applemusic-menubar-lyrics

![实际播放时，菜单栏里的歌词随音乐逐词亮起](https://raw.githubusercontent.com/mytrashcan/applemusic-menubar-lyrics/main/docs/images/menu-bar.gif)
```

**First hour.** Verify the project link and the rendered GIF. Watch the issue, answer installation questions in Chinese and check for bug reports at 20:18 KST.

## Replies to keep nearby

| Reader asks | Reply |
| --- | --- |
| How does it get lyrics? | Open the playing track’s lyrics in Music once. My app reads playback through Apple Events and looks for that recording’s timed lyrics in Music’s local cache. If nothing matches, it has no lyric to show. |
| Why not LyricsX? | LyricsX is a good choice for Spotify. I wanted the timings Music already cached for the Apple Music recording I’m hearing, right above the window I’m using. |
| Is it safe? | The ZIP is ad-hoc signed and unnotarized. The checksum lets you compare your ZIP with the published bytes. macOS warns on first open. If you trust that download, dismiss the warning, then choose System Settings → Privacy & Security → Open Anyway and confirm. The app reads Music’s cache read-only and makes no network requests. |
| Intel? | Yes, the v0.0.6 ZIP has an x86_64 slice as well as arm64 and targets macOS 13+. I verified the slices. Physical Intel playback is still unconfirmed. Homebrew installs the same app with quarantine. |
| 为什么看不到歌词？ | 请先在「音乐」里打开当前歌曲的歌词面板，再点 Music Lyrics Bar 菜单里的 Reload Lyrics Cache。如果还是空白，请告诉我系统版本和 Show Status 的提示，删去歌名和歌词即可。 |
| Intel 能用吗？首次打开为什么有提示？ | 通用版含 Intel 和 Apple Silicon 两种架构，最低为 macOS 13。应用未经苹果公证。确认信任来源后，先关闭验证提示，再到「系统设置 → 隐私与安全性」选择「仍要打开」（Open Anyway）。Homebrew 安装也有这一步。 |

## At +30 minutes on every channel

| Open | Record | Repository response |
| --- | --- | --- |
| [Release API](https://api.github.com/repos/mytrashcan/applemusic-menubar-lyrics/releases/tags/v0.0.6) and the post link | Compare the ZIP’s current `download_count` with the count immediately before this post. Record time and delta. Treat unavailable data as **unknown**. Download activity alone cannot establish installs or channel attribution. | Follow the link as a reader. If it is broken, correct the release link in the README and the affected post. A flat counter on its own calls for no repo change. |
| [New bug reports](https://github.com/mytrashcan/applemusic-menubar-lyrics/issues?q=is%3Aissue+label%3Abug) | Read macOS version, Music version, whether that track’s panel was opened, status message and bar behavior. For a launch failure, ask for the exact alert and architecture. | Reproduce with the published build. Clarify a missing setup step in **Getting started**. For a reproducible cache or playback defect, track the fix and test it with synthetic data. Keep private caches and lyrics out of issues. |
| The original thread or submission issue | Group objections about first launch, Automation, alternatives, Intel and missing matches. Distinguish the verification warning from a damage or malware alert. | Correct ambiguous copy in the affected draft and public post. Add a repeatable install answer to the README. When tracking a hardware result, include architecture, OS and Music version. |

## Stop rule

**Pause the next channel** if the official ZIP or cask fails its checksum, a required asset or architecture is missing, macOS reports damage or malware, or a supported Mac reproducibly cannot open the verified app after the documented trust step. Stop directing readers to the affected download, record the exact failure, and acknowledge it in the existing thread. Resume only after a fresh public download passes verification and the failing install path has been retested. An ordinary first-launch verification warning has the documented Open Anyway path. A cache miss on one recording belongs in the bug form.
