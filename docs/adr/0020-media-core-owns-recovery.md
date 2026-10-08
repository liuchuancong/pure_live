# ADR 0020:恢复、回退与任务调度沿用 media_core,平台只做映射

- 状态:已接受(2026-10-08)
- 相关:[0016-platform-media-track-mirror.md](0016-platform-media-track-mirror.md) · [../roadmap/w3-progress.md](../roadmap/w3-progress.md) §1 · [../contracts/platform-models.md](../contracts/platform-models.md) §2 · [../media/recovery.md](../media/recovery.md) · [../media/watchdog.md](../media/watchdog.md)

## 背景

`v2-roadmap.md` 把 W3 写成"MediaTicket / MediaPlan / PlayerKernel 接线 / **Recovery** / **Watchdog**",
`docs/media/recovery.md` 与 `docs/media/watchdog.md` 又把恢复阶梯和看门狗描述成 PureLive 要建的组件。

按 `platform-models.md` §2 的要求,W3 动手前先对钉住的 media_core ref(`5b04714…`)做了实测盘点,结论是这些
能力**内核里已经成体系存在**:

```text
recovery/   RecoveryReason(Network/Timeout/Decoder/Renderer/Source/Resource/Initialization/Interrupted/Unknown,
            自带字符串线索分类)+ RecoveryLadder / RecoveryStep / RecoverySession / RecoveryAction /
            RecoveryCandidateProvider / RecoverySnapshot / RecoveryState
fallback/   LineFallback / QualityFallback / BackendFallback + FallbackManager
policy/     RecoveryPolicy / PlaybackPolicy / FallbackPolicy / PreloadPolicy / ResourcePolicy …
runtime/    PlayerRuntime + PlayerPlaybackBinding
reconciler/ PlayerReconciler / ReconcileScheduler / ReconcilePlan
task/       TaskManager / TaskScheduler / TaskQueue / TaskState / TaskPriority / TaskCancelToken / TaskId
preload/    PreloadManager / PreloadScheduler
kernel/     player_handle_recovery.dart
```

如果照 roadmap 的措辞再建一套 PureLive 恢复引擎,就会有两套阶梯、两套重试点、两套"谁决定切线路"的判断,
而它们对同一个失败给出不同答案 —— 这正是 Invariant 10(Media Core 拥有播放状态)要防的事。

## 决策

1. **W3 不建第二套 Recovery / Watchdog / Fallback / 任务队列。** 接线层只做两件事:
   - **输入映射**:把只有平台侧才知道的失败来源(票据到期、权限被拒、解析器失败、来源优先级与健康度)翻译成
     media_core 的 `RecoveryReason` / fallback 理由;
   - **策略映射**:把 `MediaTicketPolicy`(`allowRefresh` / `allowRetry` / `allowLineFallback` /
     `allowEngineFallback` / `seamlessRefresh` / `retryDelay`)翻译成内核的 policy 对象。
2. **看门狗只保留"到期预取"这一层**:即按 `expiresAt`(与后续的 `refreshBefore`)提前换链的调度。
   检测—请求—接收—切换的循环归内核(`platform-contracts.md` §13 的职责划分已是这个意思,本节把它讲死)。
3. **任务词汇表不假装 1:1。** 平台侧 `pure_live_task` 保留自有枚举(纯 Dart 包不可能 import 依赖 Flutter 的
   media_core),映射规则写进 `pure_live_media`:
   - `TaskPriority`:`critical→highest`、`high→high`、`normal→normal`、`low→low`、`background→lowest`;
   - `TaskState`:内核的 `created` 与 `queued` 都映射成平台的 `pending`;
   - 平台的 `paused` **在内核没有对应态**,因此"暂停"只对平台调度器里的待执行任务成立,已进入内核的任务只能
     取消(与 `pure_live_task` README 第 5 条一致);
   - `TaskId` 是 String typedef,而内核是 `final class TaskId extends Equatable implements Comparable`,
     跨层必经显式转换,命名空间按 `platform-contracts.md` §3 分离(`purelive.*` / `media_core.player.*`)。
4. `docs/media/{recovery,watchdog,line-switch,media-plan,media-architecture}.md` 与本文冲突的表述按本文修订,
   并注明机制在 media_core。

## 后果

- 正:一套阶梯、一套重试点、一套"谁切线路"的判断;平台只在它真正独有的信息上作决定。
- 正:W3 的交付从"再造一个播放恢复系统"缩成"票据↔源映射 + 预取调度 + 假引擎打通",工作量与风险都下降。
- 负:恢复行为的可观察性依赖 media_core 的 `RecoverySnapshot` / `recovery_ladder_event`,PureLive 侧要经
  `DiagnosticTracer` 转发才进得了自己的诊断面;这是接线层的固定成本。
- 负:`paused` 这类平台独有态在内核侧没有落点,读代码的人可能误以为任何任务都能暂停。§3 的映射表与
  `pure_live_task` README 必须与之同批维护。
- 负:roadmap 的措辞与实际交付不一致,需在 `v2-roadmap.md` W3 一栏回指本文。
