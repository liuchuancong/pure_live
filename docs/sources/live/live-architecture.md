# 直播架构

> 直播是 PureLive 的核心业务;协议复杂度(签名/风控/ protobuf 弹幕/URL TTL)由 Provider 承载,播放稳定性由宿主统一保障。

## 1. 标准流程

```text
LiveContent → LiveProvider → StreamTicket(= MediaTicket 别名)
→ Prefetch(到期前)→ Playback → Watchdog
→ Refresh / LineSwitch / Reconnect(Recovery 阶梯)
```

## 2. 直播必须支持

多线路、质量切换、URL TTL、无缝切换、断线重连、鉴权过期、Host 变化、协议变化。

URL 过期:T-45s 预取 → 新 Ticket → 关键帧接续(无感);失败 → 重连 → 线路回退 → 引擎回退 → 退避。

## 3. 直播特有语义

- **追帧**:播放位置落后直播间实时进度时自动快进追上。
- **弹幕时钟**:弹幕时间轴与直播事实时钟对齐(danmaku 包)。
- **开播状态**:房间直播/下播/回放中(ContentKind 区分),Feed 只聚合开播源。

## 4. 站点实现

33+ 站一站一包(`plugins/<site>`);协议词典 = v1 `lib/shared/platforms`(endpoint/风控头/签名/弹幕协议);每站 fixtures 快照 + 契约测试。B 站直播在 [../vod/bilibili.md](../vod/bilibili.md) 一并覆盖。
