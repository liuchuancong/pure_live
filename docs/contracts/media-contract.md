# 媒体契约(Media Contract)

> 所有可播放内容最终进入统一媒体管线(I6);详见 [../media/media-architecture.md](../media/media-architecture.md)。

## 1. 管线

```text
ContentRef → Provider → MediaResolver → MediaTicket → MediaPlan
→ PlayerSession → PlayerKernel → PlayerAdapter → Engine
```

## 2. MediaTicket

原 StreamTicket 升级为通用 MediaTicket,适用于 Live / VOD / Music / IPTV / Recorder / TVBox:

```text
MediaTicket
├── urls            备选地址(多线路)
├── expiresAt       过期时间 → 宿主到期预取
├── refreshBefore   建议提前量(如 T-45s)
├── format          hls/flv/dash/mp4/…
├── headers/cookies 请求所需
├── quality / line
├── refreshPolicy   自动/手动/禁止
└── capabilities    danmaku/subtitle/chapter 附加句柄
```

`StreamTicket` 作为 Live 场景的语义别名保留。

## 3. RefreshReason

`expiring` / `expired` / `networkError` / `http403` / `http404` / `decodeError` / `manual` / `qualityChanged` / `lineChanged`

职责划分:Provider 负责 `resolve()/refresh()`(怎么拿地址);PlayerKernel 负责 detect → request refresh → receive → switch/reconnect(怎么换);**Provider 永不调用播放器实现,内核永不知道内容来源**(I1/I2)。

## 4. MediaPlan

一次播放的编排声明:起播参数、预取策略、兜底线路、引擎偏好、诊断标签。由 MediaRuntime 按 Ticket + 用户设置生成,Session 执行。
