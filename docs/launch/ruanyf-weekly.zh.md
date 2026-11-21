# [开源自荐] Music Lyrics Bar：把正在唱的那句歌词放到 Mac 菜单栏

阮老师好，自荐一个我写的 Mac 小工具。

**Music Lyrics Bar** 把 Apple Music 正在唱的那句词放进菜单栏。比如写东西时没听清一句，抬眼就能看，不用切回「音乐」。有逐词时间戳的歌，唱到哪里，文字就亮到哪里。

它的做法有点取巧：先在「音乐」里点开这首歌的歌词面板，等歌词缓存在本机，再根据播放进度显示。整个过程不用额外的歌词服务，也不用填 API 密钥。代价是，如果「音乐」没缓存这份歌词，或者苹果改了缓存格式，小工具就可能显示不出来。

v0.0.6 提供通用版 ZIP，内含 Apple Silicon 和 Intel 两种架构，适用于 macOS 13 及以上版本。应用采用临时签名，未经苹果公证。首次打开时，先关闭系统验证提示。如果你信任下载来源，请到「系统设置 → 隐私与安全性」，为 Music Lyrics Bar 选择「仍要打开」（Open Anyway）并确认。

项目地址：https://github.com/mytrashcan/applemusic-menubar-lyrics

![实际播放时，菜单栏里的歌词随音乐逐词亮起](https://raw.githubusercontent.com/mytrashcan/applemusic-menubar-lyrics/main/docs/images/menu-bar.gif)
