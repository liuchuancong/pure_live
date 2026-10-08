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

## 边界

- **不建第二套恢复/回退/调度**:见 [docs/adr/0020-media-core-owns-recovery.md](../../../docs/adr/0020-media-core-owns-recovery.md)。
- 映射是显式逐字段(不是反射),任一侧加字段这里就编译不过或测试就红。
- 本包不 import flutter 之外的宿主能力;引擎适配(media_kit / ijk / better_player)与"假引擎"测试台尚未落,
  当前只有票据 → 源/策略。

## 验证

- 分析:`flutter analyze`;测试:`flutter test`(media_core 依赖 Flutter,所以走 Flutter runner,不是 `dart test`)。
- 本包 15 测试已在真实 `flutter test` 上跑绿(对钉住的 media_core ref,不是对桩)。
