# v2 路线图

> 波次按依赖序排列;每波有独立验收。**第一阶段不追插件数量,追一条完整链。**

## W0 — 架构冻结(已完成)

Capability / ContentRef / MediaTicket / PluginManifest / Permission / Provider 契约定稿(本 docs/ 体系)。

## W1 — Foundation

melos 化、包脚手架、架构护栏、契约测试框架、核心模型(ContentRef/MediaTicket 等)。

## W2 — Plugin Runtime

PluginRuntime / Registry / Permission / Sandbox。

## W3 — Media

MediaTicket / MediaPlan / PlayerKernel 接线 / Recovery / Watchdog。

## W4 — 第一参考插件:Bilibili

覆盖 Live / VOD / Search / Feed / Danmaku / Auth —— 用它验证完整生态链(内容链 + 媒体链)。

## W5 — Universal Content

ContentRef 业务面:History / Favorite / Playlist / Feed / Search / Link。

## W6 — Music

MusicIdentity / MusicResolver / 内置源 / Lyric / Playlist。

## W7 — TVBox

单仓 / 多仓 / JSON / M3U / EPG / Universal VOD。

## W8 — 直播生态铺量

逐步迁移 33+ 直播站(协议词典:v1 / pure_live_TV)。

## W9 — IPTV / Recorder / Download / Cast

## W10 — 插件生态

JS 插件 SDK 文档 / Data 插件 / 插件 Repository / 主题插件 / 安全打磨。

## W11 — 平台

Android / Android TV / iOS / macOS / Windows / Linux 全平台验收。

## W12 — Release

迁移器 / 性能 / 诊断面板 / 文档 / 插件开发者指南 / v2 首版发布。
