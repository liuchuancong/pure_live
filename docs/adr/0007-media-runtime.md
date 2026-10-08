# ADR 0007:媒体运行时(Media Runtime)

- 状态:已接受(2026-10-08)

## 背景

播放故障恢复(过期/403/断网/卡顿)在 v1 分散于各域,行为不一致且不可观测。

## 决策

建 MediaRuntime 统一承载:MediaPlan(编排)/PlaybackSession(会话)/PlaybackQueue(队列)/Recovery(分级恢复阶梯:票据→线路→画质→引擎→退避)/Watchdog(心跳与过期看门狗)/SegmentScheduler(录制分段)。恢复阶梯每级有时限与上限,全事件进诊断。见 [../media/media-architecture.md](../media/media-architecture.md)。

## 后果

- 正:播放稳定性策略一处实现全局一致;"某站播不了"可导出证据链。
- 负:内核交互抽象层成本(由 media_core 契约对齐消化)。
