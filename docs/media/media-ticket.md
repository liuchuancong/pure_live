# MediaTicket

> 原 StreamTicket 升级为通用媒体凭据;适用于 Live / VOD / Music / IPTV / Recorder / TVBox。

## 1. 结构

```text
MediaTicket
├── urls             备选地址(多线路)
├── expiresAt        过期时间(如实给出)
├── refreshBefore    建议提前量(如 45s)
├── format           hls/flv/dash/mp4/…
├── headers/cookies  请求所需
├── quality / line   画质与线路标识
├── refreshPolicy    auto / manual / forbidden
└── capabilities     附加句柄(danmaku/subtitle/chapter)
```

## 2. 刷新原因(RefreshReason)

`expiring` / `expired` / `networkError` / `http403` / `http404` / `decodeError` / `manual` / `qualityChanged` / `lineChanged`

## 3. 职责划分

- **Provider**:`resolve(ContentRef, quality?, line?) → MediaTicket`;`refresh(expired, reason) → MediaTicket`。
- **内核(detect → request refresh → receive → switch/reconnect)**:发现过期/故障后向 MediaRuntime 请求新 Ticket;拿到后在关键帧/安全点无缝切换。
- **MediaRuntime(宿主)**:按 `refreshBefore` 调度预取(如 T-45s),失败走恢复阶梯(见 [recovery.md](recovery.md))。

## 4. 规则

- 换链失败 → 下一线路 → 引擎回退 → 退避重连(逐级降级)。
- Ticket 过期刷新的是**票据**,不是播放会话:会话、弹幕、进度全部保留。
- Ticket 不落盘;跨会话恢复播放 = 用 ContentRef 重新 resolve。
