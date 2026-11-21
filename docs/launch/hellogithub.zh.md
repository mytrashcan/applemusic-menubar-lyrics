# [开源自荐] Music Lyrics Bar：在 Mac 菜单栏跟着 Apple Music 看歌词

### 项目地址

https://github.com/mytrashcan/applemusic-menubar-lyrics

### 类别

Swift

### 项目标题

在 Mac 菜单栏看 Apple Music 的逐词歌词

### 项目描述

我是 Music Lyrics Bar 的作者。用 Mac 看书时，想看清刚唱过去的那句词，又不想来回切窗口，就写了这个菜单栏小工具。在 Apple Music 里播放一首歌，点开一次歌词面板，再切回书页。抬头看菜单栏，就能看到正唱到哪一句。

### 亮点

- 直接读「音乐」已经缓存在本机的歌词，不用申请 API 密钥。缓存里带有词或音节的时间戳时，唱过的部分会逐渐亮起来；只有行时间戳时就逐行显示。
- 想看实现的话，可以从 Swift 代码里看到它怎样用 Apple Events 读取播放进度，再从本地缓存匹配同一录音。缓存是苹果的私有格式，系统更新后可能失效，匹配不上时也不会去别处补词。
- v0.0.6 提供通用版 ZIP，内含 Apple Silicon 和 Intel 两种架构，适用于 macOS 13 及以上版本。应用采用临时签名，未经苹果公证。首次打开时，先关闭系统验证提示。如果你信任下载来源，请到「系统设置 → 隐私与安全性」，为 Music Lyrics Bar 选择「仍要打开」（Open Anyway）并确认。

### 截图或演示视频

![实机录屏：唱过的词在菜单栏里逐渐亮起](https://raw.githubusercontent.com/mytrashcan/applemusic-menubar-lyrics/main/docs/images/menu-bar.gif)
