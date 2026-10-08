# 系统总览

> 自上而下看一遍 PureLive v2:一个 App 壳 + 一个生态运行时 + 一条统一媒体管线。

## 1. 运行时全景

```text
PureLiveRuntime
├── PluginRuntime        插件装载/沙箱/生命周期/权限(见 ../plugin/)
├── CapabilityRuntime    能力注册与发现(CapabilityRegistry)
├── ContentRuntime       ContentRef/ContentItem/Collection/Playlist
├── MediaRuntime         MediaTicket/MediaPlan/Session/Queue/Recovery/Watchdog
├── AccountRuntime       多平台账号/会话/auth.expired 事件
├── SyncRuntime          多设备同步(firebase/WebDAV/LAN)
├── CacheRuntime         命名空间化缓存(image/media/music/subtitle/danmaku/plugin/metadata)
├── ThemeRuntime         主题令牌→WindThemeData/ColorScheme
└── DiagnosticRuntime    日志/追踪/播放诊断/诊断报告导出
```

App 只是 Runtime 的一个宿主。未来可存在 PureLive Mobile / TV / Desktop / Web 多个宿主共享同一生态核心。

## 2. 一次典型播放(全链路)

```text
用户点击直播间卡片(ContentRef: douyu://live/123456)
 → LiveCapabilityProvider.resolve() → MediaTicket(urls, expiresAt, quality, line)
 → MediaPlan(编排:起播参数/预取策略/兜底线路)
 → PlaybackSession 创建 → PlayerKernel → PlayerAdapter(mpv)→ 出画
 → Watchdog 监控卡顿/过期 → ticket.refresh(before expiresAt)→ 无缝换链
 → 退出 → History 记录(ContentRef + position)
```

## 3. 进程内边界

| 边界 | 规则 |
|---|---|
| Plugin ↔ Player | 插件永远不触碰 PlayerAdapter,只生产 MediaTicket |
| Player ↔ 内容源 | 内核永远不知道 Bilibili/Douyu/TVBox |
| Feature ↔ 站点 | Feature 不解析第三方网站,只消费 ContentRef |
| JS 插件 ↔ 网络 | 只能走 PluginNetwork(白名单/限速/日志),拿不到裸 socket |
| 业务 ↔ 文件 | 业务 Repository 不直接操作底层文件 |

完整不变量清单见 [dependency-rules.md](dependency-rules.md)。

## 4. 目标平台

Android / Android TV / iOS / iPadOS / macOS / Windows / Linux。平台差异只允许出现在 `platform`、media adapter、filesystem、background、cast 五处封装内;业务层禁止平台判断。TV 专属能力(DPad/Focus/Leanback 布局)属于 Experience 层(见 [../ui/tv.md](../ui/tv.md)),不得污染 Provider/Repository。
