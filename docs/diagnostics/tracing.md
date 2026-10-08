# Tracing(追踪)

> 关键流程结构化事件,可关联成轨迹。

## 事件模型

`DiagnosticSession` → `DiagnosticEvent { ts, domain, name, attrs }`

## 播放轨迹事件

`play.request → play.resolve → play.ticket → play.prepare → play.started → buffering → ticket.refresh → line.switch → engine.switch → play.error`

其余域:auth.expired、plugin.load/crash、sync.completed、download.completed、record.segment。

## 指标(生态核心)

`play_success_rate` / `play_start_latency` / `buffering_rate` / `ticket_refresh_success_rate` / `line_switch_success_rate` / `engine_fallback_rate` / `auth_refresh_success_rate` / `plugin_error_rate` / `plugin_timeout_rate` / `search_success_rate`

本地聚合;生态成熟后可建统一诊断面板。
