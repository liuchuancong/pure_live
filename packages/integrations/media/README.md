# pure_live_media

> 职责:media_core 播放内核接线:MediaTicket 与内核源/计划/策略的映射,引擎适配与假引擎测试台

| 项 | 规则 |
|---|---|
| 层 | integrations(见 [依赖规则](../../../docs/architecture/dependency-rules.md)) |
| 允许依赖 | -> L0 foundation;厂商 SDK 只允许出现在本层(此处即 media_core,git 依赖钉 ref);另可读取共享模型伞包 `pure_live_platform`(见 [docs/adr/0018](../../../docs/adr/0018-contract-package-split.md)) |
| 禁止依赖 | 任何反向依赖;禁止依赖应用壳(唯一组合根,I9);同层互依(除规则明示例外) |
| 公共面 | 只有 `lib/pure_live_media.dart`;内部实现放 `lib/src/` |

## 结构

- `lib/src/media_track_mapping.dart` —— 平台 `MediaTrack` ↔ 内核 `MediaTrack`
- `lib/src/ticket_source.dart` —— `MediaTicket` → `MediaSource`(Progressive / Composite)
- `lib/src/ticket_policy.dart` —— `MediaTicketPolicy` → 内核 `RecoveryPolicy` / `FallbackPolicy`
- `lib/src/watchdog.dart` —— 播放看门狗:票据到期/预取、位置停滞、起播超时

media_core 钉的是应用 pubspec 里同一个 ref(`5b04714542…`),全 workspace 共用一份 checkout。

## 映射规则

| 平台侧 | 内核侧 | 说明 |
|---|---|---|
| `MediaTrack.kind`(`MediaTrackType`) | `MediaTrack.kind`(`MediaTrackType`) | 逐值映射;**不是** `MediaKind`(ADR 0016 修订:essence ≠ 资源语义类型) |
| `MediaTrack.headers`(`Map`) | `MediaTrack.headers`(`SourceHeaders?`) | 空 map → **null**:内核里"没写"是继承源级头,"空"是明确不发头 |
| 无 tracks 的 ticket | `ProgressiveMediaSource(url)` | essence 由 `MediaKind` 推:`music → audio`,其余 `video`;`platform.media_kind` / `platform.protocol` / `platform.live` 放进 track metadata 以便内核侧日志能还原 |
| 单条 track | `ProgressiveMediaSource(track)` | 单 essence  regardless 类型;不硬凑 composite |
| 多条 track | `CompositeMediaSource(video/audio/subtitle 分组)` | **保序**:平台的顺序就是内核的候选优先级 |
| 只有字幕的多条 | `ProgressiveMediaSource(url)` | `CompositeMediaSource` 断言至少要有一条 video 或 audio |
| `kind == live \|\| metadata.isLive` | `MediaSource.live` | |
| `policy.allowRetry` | `RecoveryPolicy.enabled` | 重试**次数/退避**沿用内核默认(平台票据没有这两个字段) |
| `policy.retryDelay` | `RecoveryPolicy.retryDelay` | |
| `policy.allowRefresh` | `RecoveryPolicy.allowSourceFallback` | 不许重取票据的源,也不该换源 |
| `policy.allowEngineFallback` | `RecoveryPolicy.allowBackendFallback` + `FallbackPolicy.allowBackendFallback` | 引擎 = backend |
| `policy.allowLineFallback` | `FallbackPolicy.allowLineFallback` | |
| —(无对应) | `FallbackPolicy.downgradeQualityOnFailure = false` | 换画质在 PureLive 是"带另一个 `SelectionRef` 重新 resolve",不是播放中降级 |
| `policy.allowRedirect` / `seamlessRefresh` | 无内核对应 | 留在平台侧:前者是网络出口策略,后者是换链调度 |

## 看门狗(docs/media/watchdog.md)

`docs/media/watchdog.md` 列了五项监控,**本包只实现平台看得见的两项**;其余三项(帧心跳、适配器错误、
缓冲率细节)内核已经在报,再判一遍就是 ADR 0020 反对的"多方同时救火"。

| 监控项 | 判定 | 动作 |
|---|---|---|
| 票据过期 | `now >= expiresAt` | `refreshTicket` → `onTicketRefresh(RefreshReason.expired)` |
| 到期预取 | `expiresAt - prefetchLead < now < expiresAt` 且 `policy.allowRefresh` | `prefetchTicket` → `onTicketRefresh(expiring)` |
| 无进度心跳 | 位置不变 + `phase == buffering` 且停滞 ≥ `stallTimeout` | `reportStall` → `handle.reportFailure(source: watchdog)` |
| 起播超时 | `phase == preparing` 且已超 `startTimeout` 无首帧 | `reportStartTimeout` → 同上 |

判定规则里刻意"不做"的部分:

- **`paused` / `idle` 下时钟冻结不算故障**:那是用户意图(AGENTS.md 保 pause 意图),否则看门狗会在观众
  背后把播放继续下去。
- **票据没说 `expiresAt` 就不猜**:静态 m3u8 永不过期,若把"没有 TTL"当成"快过期",就会对一条好流反复换链。
- **`policy.allowRefresh == false` 时不预取**:换链是被源禁止的,提前请求只是浪费一次解析。
- 到期**优先于**停滞:链路已经死了,先换链再谈心跳。
- 一次只允许一个换链在飞:`_refreshInFlight`,否则一条 30 秒才回来的重解析会被每个采样点各催一次。
- 看门狗**只发起**恢复:它不执行阶梯,阶梯归 `handle.reportFailure` 之后的内核。

注入形式是 `reportFailure: handle.reportFailure`(函数而非 `PlayerHandle`):`PlayerHandle` 是 final class
不许 implement,而持有 handle 的一方本来就该决定故障送到哪里。

## 边界

- **不建第二套恢复/回退/调度**:见 [docs/adr/0020-media-core-owns-recovery.md](../../../docs/adr/0020-media-core-owns-recovery.md)。
- 映射是显式逐字段(不是反射),任一侧加字段这里就编译不过或测试就红。
- 本包不 import flutter 之外的宿主能力;引擎适配(media_kit / ijk / better_player)与"假引擎"测试台尚未落,
  当前只有票据 → 源/策略。

## 验证

- 分析:`flutter analyze`;测试:`flutter test`(media_core 依赖 Flutter,所以走 Flutter runner,不是 `dart test`)。
- 本包 15 测试已在真实 `flutter test` 上跑绿(对钉住的 media_core ref,不是对桩)。
