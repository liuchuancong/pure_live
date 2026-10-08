# Lyric(歌词)

> 歌词 = 附加 Capability(LyricCapability),与音乐源解耦。

## 1. 能力

- 按 identity/ContentRef 拉取歌词(源提供或独立歌词源)。
- 格式:LRC / 逐字(译文/罗马音多轨)。
- 渲染:`pure_live_lyric` 组件(滚动/点击跳转/样式随主题)。

## 2. 规则

- 歌词时间轴与播放 position 对齐(media 会话);seek 时歌词跟随。
- 无歌词源 → UI 优雅留白;多来源命中时用户可选并记忆。
- 桌面歌词(跟随播放的悬浮歌词)是 ui/adaptive 的桌面形态,复用同一数据面。
