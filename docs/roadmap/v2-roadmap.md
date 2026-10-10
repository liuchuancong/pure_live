# v2 路线图

> 波次按依赖序排列;每波有独立验收。**第一阶段不追插件数量,追一条完整链。**
>
> **2026-10-10 重排**:产品形态改为"一个 App 一个功能"(`pure_live` / `pure_bili` / `pure_music` /
> `pure_tvbox`),共享层下沉到 `packages/`。决策见 [../adr/0022-multi-app-one-feature-each.md](../adr/0022-multi-app-one-feature-each.md),
> 需求与包消费矩阵见 [../architecture/application-portfolio.md](../architecture/application-portfolio.md)。
> 下面每波的"应用面"据此按 App 分道;W2 的插件/外部生态线只服务 `pure_tvbox`。

## W0 — 架构冻结(已完成)

Capability / ContentRef / MediaTicket / PluginManifest / Permission / Provider 契约定稿(本 docs/ 体系)。

## W1 — Foundation

melos 化、包脚手架、架构护栏、契约测试框架、核心模型(ContentRef/MediaTicket 等)。

> 2026-10-09 重建:按当前状态从 W1 重新出发,清基线、收欠账、应用壳成为真应用,demo 源打通
> 注册 → 能力注册表 → Feed 聚合 → 首页整条链,见 [w1-rebuild-progress.md](w1-rebuild-progress.md)。

**实现前置**:契约与模型按 [../contracts/platform-contracts.md](../contracts/platform-contracts.md) / [platform-models.md](../contracts/platform-models.md) 执行;动手前先跑 **media_core 复用盘点**(models §2:MediaTrack/TaskCancelToken/错误分类等直接复用,SourceDescriptor 命名冲突经接线层别名);最小首切片模型清单见 models §19。

## W2 — Plugin Runtime + Extension Gateway

ExtensionGateway(统一入口:注册/发现/类型识别/Runtime 选择/生命周期)/ PluginRuntime / Registry / Permission / Sandbox / ExternalRuntime 框架(仅接口;首个外部运行时 TvBox 在 W7 落地)。TaskScheduler 随 W3 一并落地。

## W3 — Media

MediaTicket / MediaPlan / PlayerKernel 接线 / Recovery / Watchdog。

> **按 [../adr/0020-media-core-owns-recovery.md](../adr/0020-media-core-owns-recovery.md) 修正范围**:Recovery、Fallback、
> 任务队列与看门狗的检测—切换循环在 media_core 里已存在,W3 不再造第二套;本波只做票据↔源与策略映射、
> 到期预取调度,并用假引擎打通播放。实测盘点见 [w3-progress.md](w3-progress.md) §1。

## W4 — 第一参考插件:Bilibili

覆盖 Live / VOD / Search / Feed / Danmaku / Auth —— 用它验证完整生态链(内容链 + 媒体链)。

> 前置与缺口记录见 [w4-progress.md](w4-progress.md):`CapabilityRegistry`(六处文档引用而代码里不存在的发现入口)已落;
> Bilibili 适配仍卡在两处 —— 真实响应录制通道(provider-contract §1 规则 5 要求 fixtures 是录制的,不是猜的)与
> Danmaku / Auth 的方法集(capability-contract §3 只定义了内容类四个方法集,定它们是改契约而不是写实现)。

## W5 — Universal Content

ContentRef 业务面:History / Favorite / Playlist / Feed / Search / Link。

> 进度见 [w5-progress.md](w5-progress.md):收藏(Favorites)已落,先于 W4 的 provider 是因为
> W4 剩下的部分要外部输入(录制授权、danmaku/auth 契约定稿),而这一面不吃它们。跳波不是改序。

## W6 — Music

MusicIdentity / MusicResolver / 内置源 / Lyric / Playlist。**LX Music 源直接导入**(LxMusicRuntime 兼容运行环境,原接口保持原样,不转换插件)。

## W7 — TVBox

单仓 / 多仓 / JSON / M3U / EPG / Universal VOD。全部**直接导入直接运行**(TvBoxRuntime External Source 路径),不转换成 PureLive 插件(见 [../architecture/external-ecosystem.md](../architecture/external-ecosystem.md))。

## W8 — 直播生态铺量

逐步迁移 33+ 直播站(协议词典:v1 / pure_live_TV)。

## W9 — IPTV / Recorder / Download / Cast

## W10 — 插件生态

JS 插件 SDK 文档 / Data 插件 / 插件 Repository / 主题插件 / 安全打磨。

## W11 — 平台

Android / Android TV / iOS / macOS / Windows / Linux 全平台验收。

## W12 — Release

迁移器 / 性能 / 诊断面板 / 文档 / 插件开发者指南 / v2 首版发布。

## 波次落点(2026-10-10 重排后)

各波的**内容**不变,变的是**落在哪个 App**上;验收也按 App 分道,不再要求一个产物覆盖全部。

| 波 | 落点 App | 说明 |
|---|---|---|
| W2 插件运行时 + 扩展网关 | `pure_tvbox` | permission / extension / plugin_api / plugin_host / js_runtime 整线只服务 TVBox 兼容壳;`pure_live` 的组合根里不出现它们 |
| W3 媒体 | 全部四个 | `integrations/media` 是唯一播放入口(I2),各 App 各自装配 `MediaKernelHost` |
| W4 Bilibili 参考实现 | `pure_live`(live 能力)+ `pure_bili`(vod 能力) | 同一个 `providers/bilibili` 包,两个 App 只注册自己要的那组能力 |
| W5 Universal Content | 全部四个 | 机制共享、数据不共享:收藏/历史/歌单每 App 一份文件(portfolio §4 第 4 条) |
| W6 Music | `pure_music` | lx 音源 + bmsc 式 B 站音源/歌单导入 |
| W7 TVBox | `pure_tvbox` | 导入即运行,壳内不写站点 |
| W8 直播铺量 | `pure_live` | **native Dart 源**(签名/Cookie 租约/低延迟换源不走沙箱),受同一 capability 契约约束 |
| W9 IPTV/Recorder/Download/Cast | `pure_live` + `pure_tvbox` | 频道墙与录制按这两个 App 的交互分别验收 |
| W10 插件生态 | `pure_tvbox` | JS SDK / data 插件 / repository / 安全打磨 |
| W11 平台 | 按 App | live+tvbox:Android / Android TV / Windows;bili+music:Android / iOS |
| W12 Release | 按 App 四条发布线 | 版本、产物、更新源各自独立 |
