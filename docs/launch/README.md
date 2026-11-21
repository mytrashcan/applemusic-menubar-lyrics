# Music Lyrics Bar launch kit

Send visitors to the [repository](https://github.com/mytrashcan/applemusic-menubar-lyrics). Its first screen already shows real playback. The current download is for **Apple Silicon only**. Point Intel users to the source build and keep the private-cache limitation in every long-form post.

| Owner material | Use it for |
| --- | --- |
| [Conversion audit](audit.md) | Release checks, notarization, topics, social card and video shot list |
| [r/macapps](reddit-macapps.md) | App Pile entry, conditional main-feed title and author reply |
| [Show HN](show-hn.md) | Submission URL, title and technical first-comment draft to put in your own words |
| [HelloGitHub](hellogithub.zh.md) | Chinese submission form fields |
| [科技爱好者周刊](ruanyf-weekly.zh.md) | Standalone Chinese issue for the weekly |
| [X](x-post.md) | Choose a single post and attach the captioned clip |
| [Release runbook](release-runbook.md) | Set up the signing identity, publish a verified download and pin the cask |
| [Initial audit status](status.md) · [Release verification](status-2.md) | Tested artifacts, exact commands and remaining owner checks |

## Owner calendar

D is the day you first share the project. These are proposed appointments in **KST**, not measured peak traffic times. The evening slot uses the KST publication time of the [existing release](https://github.com/mytrashcan/applemusic-menubar-lyrics/releases/tag/v0.0.5). Move an appointment if you cannot stay for replies. “In branch” requires the owner to make the commit available before linking to its changes.

| Day / KST | Channel | What to do and current state | Who | Plausible effect range | Cost |
| --- | --- | --- | --- | --- | --- |
| D−7 19:48 | GitHub | **Done on main:** hero GIF, status screenshot, cache caveat and release ZIP. Record stars, watchers, ZIP downloads and unique visitors before promotion. | Owner | Baseline only to a useful comparison later | Insights and API read |
| D−5 19:48 | Releases / README | **In branch:** verify the install guide, cask draft and universal script. Rehearse the public ZIP on a clean Mac. Decide whether to wait for notarization or disclose the exception. | Owner | Discover a launch blocker to confirm a working first run | Test Mac, download and setup time. Signing requires developer credentials |
| D−3 19:48 | GitHub About / Settings | Apply the topic list and upload the [social card](../images/social-preview.png). Inspect the rendered link preview. **Pending.** | Owner | No referral change to a recognizable shared link | Repository admin time |
| D−1 19:48 | Local capture / GitHub | Record the demo with the shot list. Check current release architecture and signing against each draft. Make the README install changes public before directing visitors to them. **Copy prepared in branch.** | Owner | Catch stale copy to give a stranger a reproducible first run | Capture, editing and review time |
| D 19:48 | r/macapps | Enter the current App Pile, or use the main feed only if eligible. Answer install and comparison questions. | Owner | No replies to a thread with first-run reports | Posting and reply time |
| D+1 19:48 | X | Attach the clip to one variant. Link the repo directly and answer questions on the original post. | Owner | No clicks to clicks and shares | Upload and reply time |
| D+2 19:48 | Show HN | Submit the runnable project and explain the cache trade-off in your own words. Be available to discuss matching failures. | Owner | A quiet shownew entry to technical feedback. Front page is uncommon | Writing and discussion time |
| D+3 19:48 | HelloGitHub | Search for an existing submission, then fill the Chinese form if the project is new. | Owner | No editorial response to inclusion in a later issue | Duplicate check and editing time |
| D+4 19:48 | ruanyf/weekly | Search for the repo URL in issues, then submit the weekly pitch if new. | Owner | No response to a roundup mention | Submission and follow-up time |
| D+7 19:48 | GitHub / channel replies | Save traffic and referrers while visible. Group reports by launch warning, permission denial or missing lyrics. Correct a reproducible setup problem in the public instructions. | Owner | No reports to a specific fix | Triage and reproduction time |
| D+14 19:48 | GitHub Insights / Releases | Compare unique visitors, ZIP download deltas and net stars with the saved snapshots. Revisit unanswered reports and record which channel produced usable feedback. | Owner | Inconclusive attribution to an identifiable referral or repeated failure | Analysis and support time |

Reach, install completion and stars attributable to any channel are **unverified**. The ranges above describe possible outcomes. GitHub Traffic uses UTC and a rolling 14-day window, so save snapshots along the way. A ZIP download does not establish that the app opened. [GitHub Traffic](https://docs.github.com/en/repositories/viewing-activity-and-data-for-your-repository/viewing-traffic-to-a-repository)
