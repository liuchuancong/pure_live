# W3 进度(媒体管线接线)

> 验收口径来自 [milestones.md](milestones.md) 的 M2 另一半:媒体管线能播一个假源。
> 波次范围来自 [v2-roadmap.md](v2-roadmap.md) W3:MediaTicket / MediaPlan / PlayerKernel 接线 / Recovery / Watchdog。
> 动手前置:按 [../contracts/platform-models.md](../contracts/platform-models.md) §2 先做 media_core 复用盘点 —— 本文 §1 就是那份盘点。
> 工程规范按 [../DEVELOPMENT_STANDARDS.md](../DEVELOPMENT_STANDARDS.md)。

## 1. media_core 复用盘点(实测,不是照抄 §2)

盘点对象:pub git 缓存里应用钉住的那个 ref
(`apps/pure_live/pubspec.yaml` 钉 `5b047145422758d983a3724e689d8aa4b7d06863`,即
`Pub/Cache/git/media_core-5b04714…/packages/media_core/lib`)。共 26 个 `media_core*` 包,内核包有 30 个能力目录。

### 1.1 §2 表格逐条核对

| §2 的说法 | 实测 | 结论 |
|---|---|---|
| `lib/source/media_track.dart` 已有 MediaTrack | ✅ `source/media_track.dart:39 final class MediaTrack extends Equatable` | 按 ADR 0016 镜像 + 接线层映射(内核包依赖 Flutter,平台包必须纯 Dart) |
| `lib/task/` 已有 TaskCancelToken / TaskId | ✅ `task/task_cancel_token.dart:31`、`task/task_id.dart:9`(且整个 `task/` 还有 `TaskManager`、`TaskScheduler`、`TaskQueue`、`TaskState`、`TaskPriority`、`TaskContext`) | 见 §1.3:不是"直接复用",而是**镜像 + 映射**,且两侧词汇表并不一一对应 |
| kernel/session/playback 的 PlayerHandle、PlayerSession、SessionManager、PlaybackCommand、PlaybackPosition、Rate 已有 | ✅ `kernel/player_handle.dart`、`session/{player_session,session_manager}.dart`、`playback/{playback_command,playback_position,playback_rate}.dart` | 平台**不定义**这些;平台只到 MediaTicket 为止(models §2 正确) |
| `lib/{source,planning}/` 的 MediaSource / MediaSourcePlan / MediaSourcePlanner / ProgressiveMediaSource | ✅ `source/media_source.dart:55 sealed class MediaSource`、`planning/media_source_plan.dart:30 sealed`(Direct / Composite / Unsupported 三种 plan)、`planning/{media_source_planner,default_media_source_planner}.dart`、`source/progressive_media_source.dart` | 平台不重定义;`MediaTicket → MediaSource` 的转换是 W3 的核心工作 |
| `lib/error/` 的 PlayerErrorCode / PlayerErrorCategory / ErrorPolicy | ✅ `error/{player_error_code,player_error_category,error_policy,error_classifier}.dart` | 平台 `PlatformErrorInfo` 通过 `media.player.*` 命名空间与之互译 |
| `lib/source/source_descriptor.dart` 同名但语义不同 | ✅ 存在(媒体源描述) | 与 §2 的警告一致:两侧同名,别名在 `pure_live_media` 处理 |
| `lib/identity/` 的 GenerationId / OperationId / RequestId / SessionId / SlotId | ✅ 全在,另有 `player_id.dart`、`source_id.dart` | 关键差异:**这些是值对象**(`final class SourceId extends Equatable implements Comparable<SourceId>`),不是 String;而平台侧是 `typedef SourceId = String`。命名空间分离因此不只是文档约定,映射时必然要做 String ↔ 值对象转换 |

### 1.2 盘点发现的自身缺陷(已修)

`MediaTrack.kind`:ADR 0016 声称字段级镜像,但平台侧把 `kind` 写成了 `MediaKind`(live/vod/music/file),
而 media_core 用的是 `MediaTrackType{video, audio, subtitle}`
(`source/media_track_type.dart:24`)。语义也不同层:`MediaKind` 说"这段资源整体是什么",
`MediaTrackType` 说"这一条流是哪种 essence"。按原样接线,DASH 的音频 essence 会被标成 `vod`。

已改:平台新增 `MediaTrackType{video, audio, subtitle}` 并把 `MediaTrack.kind` 换成它,`MediaTicket.kind`
保持 `MediaKind`;测试补了 essence 往返与未知值回退两条(platform 82 全绿)。
ADR 0016 的"字段级镜像"表述随之更正。

另一处已在代码注释里说明、无需改:`headers` 在 media_core 是值对象 `SourceHeaders`
(`source/source_headers.dart:8`,内部不可变 map,给 `toMap()`),平台镜像用 `Map<String, String>` ——
映射即构造时包一层,不改模型。

### 1.3 W3 范围的削减结论(最重要的一条)

文档把 W3 写成"MediaTicket / MediaPlan / PlayerKernel 接线 / **Recovery** / **Watchdog**",但 media_core
里这些**已经存在且成体系**:

```text
recovery/    RecoveryReason(union:Network/Timeout/Decoder/Renderer/Source/Resource/Initialization/
             Interrupted/Unknown,带字符串线索分类)+ RecoveryLadder / RecoveryStep / RecoverySession /
             RecoveryAction / RecoveryCandidateProvider / RecoverySnapshot / RecoveryState
fallback/    LineFallback / QualityFallback / BackendFallback + FallbackManager / FallbackContext
policy/      RecoveryPolicy / PlaybackPolicy / FallbackPolicy / PreloadPolicy / ResourcePolicy …
runtime/     PlayerRuntime + PlayerPlaybackBinding / PlayerGeometryBinding
reconciler/  PlayerReconciler / ReconcileScheduler / ReconcilePlan …
task/        TaskManager / TaskScheduler / TaskQueue(自带优先级与状态)
preload/     PreloadManager / PreloadScheduler(到期预取可复用)
kernel/      player_handle_recovery.dart(内核侧恢复入口)
```

因此 W3 **不再造第二套恢复/回退/看门狗**。平台的贡献只有内核不知道的那些信息来源:票据到期、权限被拒、
解析器失败、来源优先级 —— 把它们映射成 media_core 的 `RecoveryReason` / `FallbackReason`,并把
`MediaTicketPolicy`(allowRefresh / allowRetry / allowLineFallback / allowEngineFallback / seamlessRefresh /
retryDelay)翻译成 media_core 的策略对象。这条结论单独记 ADR(0020),因为它改变了 W3 的交付内容。

### 1.4 任务词汇表不对应(映射表,别当 1:1)

| 平台(`pure_live_task` / models §13) | media_core `task/` | 映射 |
|---|---|---|
| `TaskPriority{critical, high, normal, low, background}` | `TaskPriority` 值对象:`lowest(-100) / low(-10) / normal(0) / high(10) / highest(100)` + `custom(int)` | critical→highest,high→high,normal→normal,low→low,background→lowest;**没有 critical 的同号位,也没有第五档以下的区分** |
| `TaskState{pending, running, paused, completed, failed, cancelled}` | `TaskState{created, queued, running, completed, failed, cancelled}` | 平台 `pending` ← media_core `created`+`queued` 两者合一;**`paused` 在 media_core 无对应**,故暂停只在平台调度器一侧成立,内核态任务无法暂停 |
| `CancellationToken`(平台侧) | `TaskCancelToken` + `TaskCancelledException` | 纯 Dart 侧必须自有类型(media_core 依赖 Flutter),按 ADR 0016 的镜像+映射处理;"取消不是失败"(models §20 不变量 9)两侧一致 |
| `TaskId = String`(typedef) | `final class TaskId extends Equatable implements Comparable<TaskId>` | 跨层必做 String ↔ 值对象转换;命名空间按 contracts §3 分开(`media_core.player.*` / `purelive.*`) |

## 2. 下一步(W3 实际要写的东西)

前置结论清楚之后,W3 的候选工作顺序:

1. `pure_live_media`:`MediaTicket → MediaSource/SourceDescriptor` 映射(含 `MediaTrackType` 与
   `SourceHeaders`)、`MediaTicketPolicy → 内核策略` 映射、错误与恢复原因互译。
2. `MediaPlan`:平台侧只保留"选哪条 ticket / 何时预取换链"的编排,不落第二套 plan 模型(models §2 已定)。
3. 假引擎跑通"播一个假源":M2 的另一半验收口径;media_core 有 `testing/` 目录,先查它有没有现成假引擎再用
   自己的。
4. Watchdog:先用 media_core 的 recovery/ + `player_handle_recovery.dart`,只在"票据到期预取"这一层加平台侧
   调度(docs/media/watchdog.md 与 recovery.md 的对应关系要按 §1.3 重写,不能照原样实现)。

## 3. 已知欠账

- docs/media/{watchdog,recovery,line-switch,media-plan,media-architecture}.md 是在盘点之前写的,里面把 Recovery /
  Watchdog 描述成 PureLive 要建的东西。§1.3 的结论与它们冲突,需要按 ADR 0020 修订,不能让文档继续指向一套
  不该存在的实现。
- 本波尚未运行任何真实播放器;全部结论来自源码盘点。
