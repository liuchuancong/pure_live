# Changelog

All notable changes to this package are documented here. Version numbers are managed by the
repository-wide release train, see docs/architecture/package-architecture.md section 3.

## Unreleased

- 票据映射:`media_track_mapping.dart`(essence 与语义 kind 分开)、`ticket_source.dart`
  (`MediaTicket` → Progressive/Composite `MediaSource`,多字幕组合退回单 url)、`ticket_policy.dart`
  (只映射票据真有的意图,画质降级显式关给内核的线路降级)。
- 假引擎端到端播放测试(对 media_core 自带 `testing/library.dart`,证明到引擎的接线,不代表真机在播)。
- `watchdog.dart`:平台侧只看的四项(到期/预取/位置停滞/起播超时),故障经 `PlayerHandle.reportFailure`
  交给内核阶梯;预取提前量改为「逐票建议优先、全局默认兜底」。
- `playback_trace.dart`:一次播放的证据链与可导出报告,脱敏强制(票据只留 host、query 全删、自由文本过
  `redactText`),`classifyFault` 把故障归给能修它的一方。
- `ticket_swap.dart`:`TicketSwapper` —— 先取票再动播放器,失败不开、直播不 seek 回 0、暂停不 resume、
  并发合并成一次;取票逻辑由组合根以回调注入(本包不得反向依赖 L1 的 resolver)。
