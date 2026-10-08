# ADR 0013:诊断系统(Diagnostics)

- 状态:已接受(2026-10-08)

## 背景

"某站播不了"是最高频反馈,但 v1 无证据链,定位靠猜。

## 决策

结构化诊断:DiagnosticSession/Event;播放轨迹事件链(play.request→…→play.error);核心指标(play_success_rate/起播延迟/buffering_rate/ticket_refresh_success_rate 等);**一键导出诊断报告**(轨迹+环境,强制脱敏);EventBus 只做广播不做依赖。见 [../diagnostics/](../diagnostics/)。

## 后果

- 正:反馈闭环成立;指标驱动稳定性优先级。
- 负:关键路径埋点纪律(契约测试覆盖事件完整性)。
