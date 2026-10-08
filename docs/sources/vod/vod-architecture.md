# VOD 架构

> 点播域:以 Bilibili 为参考实现,以 TVBox 为生态扩展;业务模型全部走统一 Content Model。

## 1. VOD 平台至少支持

Video / Episode / Movie / Series / Bangumi / UP·User / Related / Comment / Subtitle / Danmaku / History / WatchLater / Favorite / Chapter / PlaybackProgress

## 2. 解耦

播放器不感知 Bilibili:

```text
VodProvider → ContentRef → MediaTicket → MediaPlan
```

连播 = PlaybackQueue;进度/历史 = services 基于 ContentRef;弹幕/字幕 = 附加 capability。

## 3. 参考实现

- Bilibili:[bilibili.md](bilibili.md)(W4 参考插件,协议词典 pure_live_TV modules/vod)
- TVBox 生态:[tvbox.md](tvbox.md)(单仓/多仓/JSON/M3U,Universal Source Adapter)
