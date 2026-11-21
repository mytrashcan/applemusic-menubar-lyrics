# [开源自荐] Music Lyrics Bar：把正在唱的那句歌词放到 Mac 菜单栏

阮老师好，自荐一个我写的 Mac 小工具。

**Music Lyrics Bar** 把 Apple Music 正在唱的那句词放进菜单栏。比如写东西时没听清一句，抬眼就能看，不用切回「音乐」。有逐词时间戳的歌，唱到哪里，文字就亮到哪里。

它的做法有点取巧：先在「音乐」里点开这首歌的歌词面板，等歌词缓存在本机，再根据播放进度显示。整个过程不用额外的歌词服务，也不用填 API 密钥。代价是，如果「音乐」没缓存这份歌词，或者苹果改了缓存格式，小工具就可能显示不出来。

适用于 macOS 13 及以上版本。现成的 ZIP 仅支持 Apple Silicon，尚未经过苹果公证；Intel 用户可以尝试自行编译，真机播放效果待验证。

项目地址：https://github.com/mytrashcan/applemusic-menubar-lyrics

![实际播放时，菜单栏里的歌词随音乐逐词亮起](https://raw.githubusercontent.com/mytrashcan/applemusic-menubar-lyrics/main/docs/images/menu-bar.gif)
