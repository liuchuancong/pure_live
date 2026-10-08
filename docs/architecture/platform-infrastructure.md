# Platform Infrastructure(平台扩展基础设施)

> 文档状态:定稿 / Architecture Decision
> 定位:独立于具体业务的**平台扩展基础设施**——Extension Gateway 是最上层入口,Source → Repository → Provider → Resolver → MediaTicket 是核心数据链,Identity / Permission / Task / Diagnostics 是贯穿全链的横向基础设施。
> 核心范围:Extension Gateway、External Runtime、Source、Repository、Resolver、Identity、Permission、Task、Diagnostics。

## 1. 概述

PureLive v2 要承载的不只是更多直播源,而是一个统一生态:**直播平台 / VOD / Bilibili Live·VOD / 音乐 / LX Music Source / IPTV / TVBox 单仓 / TVBox 多仓 / M3U / XMLTV·EPG / PureLive Native Plugin / PureLive JS Plugin / 第三方社区扩展 / 本地媒体 / 下载与录制**。

```text
                       PureLive Platform
                              │
                    Extension Gateway
                              │
             ┌────────────────┼────────────────┐
             │                │                │
      PureLive Plugin   External Runtime   Built-in Source
             │        ┌───────┼────────┐       │
             │      TVBox   LXMusic   M3U     │
             └────────┴───────┴────────┴───────┘
                              │
                  Capability → Repository → Provider
                              │
                    Resolver → Content Identity
                              │
                         MediaTicket → Media Core → Player
```

核心原则:

> **所有可扩展能力统一接入,但不同生态不要求转换成 PureLive Plugin。**

即:不是"外部协议 → 转成 PureLive Plugin",而是"External Protocol → External Runtime → Unified Capability"。TVBox / LX Music / M3U / XMLTV / PureLive Plugin 使用各自的 Runtime,最终都进入统一平台模型。

## 2. 九大基础设施

```text
1. Extension Gateway    2. External Runtime    3. Source
4. Repository           5. Resolver            6. Identity
7. Permission           8. Task                9. Diagnostics
```

它们不是九个孤立工具,而是一条完整链路(关系图见 §8)。

## 3. Extension Gateway(最上层入口)

统一入口,所有扩展必经:PureLive Plugin / TVBox / LX Music / M3U / XMLTV / Built-in Source / Community Extension。

**职责**:Extension 注册、发现、类型识别、Runtime 选择、Capability 注册、Permission 初始化、Lifecycle 管理、Source 管理、Task 注册、Diagnostics 注册、Extension 隔离、卸载。**不负责业务逻辑。**

生命周期:

```text
DISCOVER → IDENTIFY → SELECT RUNTIME → LOAD → VALIDATE → REGISTER
→ READY → RUNNING → DISABLE → UNLOAD
异常:LOAD → ERROR → DIAGNOSTICS → RETRY / DISABLE
```

统一扩展描述:

```dart
class ExtensionDescriptor {
  final String id;                    // tvbox.example / lxmusic.example / bilibili
  final String type;                  // tvbox / lx_music / pure_live_plugin / m3u / xmltv
  final String version;
  final String? uri;
  final Map<String, dynamic> metadata;
}
```

## 4. External Runtime(外部协议运行时)

Runtime 负责理解外部协议,而**不要求外部协议遵循 PureLive API**:

```dart
abstract interface class ExternalRuntime {
  String get type;
  String get version;
  bool canHandle(ExtensionDescriptor descriptor);
  Future<RuntimeInstance> load(ExtensionDescriptor descriptor);
}
```

```text
Extension Gateway
 ├── PureLivePluginRuntime
 ├── TvBoxRuntime        ─┐
 ├── LxMusicRuntime       ├→ 各自独立包:pure_live_external_tvbox / lx_music / m3u / xmltv
 ├── M3uRuntime          ─┘
 └── XmlTvRuntime
```

不同 Runtime 最终输出同一组统一模型:Capability / Repository / Provider / Resolver / Content / MediaTicket。

## 5. Source 与 Repository

**Source 是外部数据来源**(https://…/tvbox.json、/source.js、/list.m3u、/epg.xml),**不是 Repository**:

```dart
class Source {
  final String id;
  final String type;
  final String uri;
  final SourceStatus status;
  final DateTime? lastFetchedAt;
  final DateTime? nextRefreshAt;
  final Map<String, dynamic> metadata;
}
```

Source 生命周期:`ADD → DETECT → VALIDATE → LOAD → READY → REFRESH → ERROR → RETRY`;用户可启用/禁用/刷新/编辑/删除。

**Repository 是 Source 加载后形成的内容集合**:TVBox Source → TVBox Repository;M3U Source → IPTV Repository。对 Feature 提供统一数据访问:list / search / detail / category / recommendation / resolve;**不负责** UI / 播放器 / 页面路由 / 主题。

关系:`Repository → Provider → Capability`。Provider 是具体能力实现——TvBoxRepository 派生 VodProvider/SearchProvider/ResolveProvider;LxMusicRepository 派生 MusicSearchProvider/MusicDetailProvider/LyricProvider/MusicResolveProvider。

多仓场景:Gateway 下可同时挂 TVBox A/B/C、LX Source A/B;系统用统一的 SourceManager / RepositoryManager / ResolverManager / IdentityManager 管理,**不是每种生态自己一套 Manager**。

Source 治理:priority / enabled / weight / health(healthy / degraded / unavailable / expired / disabled)/ latency / failureRate——Resolver 按优先级、健康度、响应时间、历史成功率自动选源降级。

## 6. Resolver 与核心数据链

不能让 UI 直接使用 URL/String/Map——播放必须经统一解析:

```text
ContentRef
 ↓ Identity Resolve → Repository Resolve → Provider Resolve → URL/Stream Resolve
 ↓ MediaTicket → MediaPlan → Media Core
```

Resolver 类型:Live / Vod / Music / Iptv / Local / Download。Resolver 可按能力选择 Primary / Fallback / Alternative。

四条参考调用链:

- **TVBox**:Gateway → TvBoxRuntime → TvBoxSource → TvBoxRepository → VodProvider → ContentRef → Identity → TvBoxResolver → MediaTicket → Media Core → Player
- **LX Music**:Gateway → LxMusicRuntime → LxMusicSource → MusicRepository → MusicProvider → MusicIdentity → MusicResolver → MediaTicket → Media Core → Player
- **M3U/IPTV**:M3U → M3uRuntime → M3uSource → IptvRepository → LiveProvider → ContentRef → Resolver → MediaTicket → Player
- **Native Plugin**:Gateway → Plugin Runtime → Capability → Provider → ContentRef → Resolver → MediaTicket → Media Core

**与 Media Core 的边界**:平台层只回答"我要播放什么,以及如何获得它";Media Core 回答"如何播放它"——`Resolver → MediaTicket → PureLive Media Layer → media_core → Adapter → Player Engine`。

## 7. 横向基础设施(贯穿全链)

### 7.1 Identity

不同来源可能描述同一内容(Bilibili BV123 / TVBox movie_456 / YouTube abc123)。必须区分 **Source Identity / Canonical Identity / User Identity**:

```text
ContentRef → IdentityResolver → CanonicalIdentity
```

匹配输入:标题 / 作者 / 艺人 / 专辑 / 年份 / 季 / 集 / ISRC / ISBN / 外部 ID。用途:历史 / 收藏 / 稍后观看 / 播放列表 / 搜索去重 / 推荐 / 跨源解析 / 源切换 / 同步。

**用户数据与 Source 解耦(重要原则)**:收藏不得绑定 TVBox Repository ID,而应绑定 ContentIdentity → Source Mapping——用户删除 TVBox 仓库后收藏仍在,并可重新寻找其他 Source。删除 Source 时:Disable → 停 Task → 释放 Runtime → 清 Repository → **保留/迁移 Identity** → 清 Cache → Diagnostics;History/Favorite/Playlist 是否删除由用户策略决定。

### 7.2 Permission

统一权限模型:`network / cookie / account / storage / cache / notification / background / clipboard / local_server / media / device`;作用域:Extension / Source / Account / Runtime(例:LX Music Source → network=allow, cookie=allow, storage=limited, account=deny, device=deny)。

**网络权限**:第三方 Source 不得直接获得完整 HTTP 能力——`Extension → ExtensionNetwork → Network Policy → Dio/HTTP`,控制 Host / Headers / Cookies / Proxy / Redirect / Timeout / Response Size / Concurrency / User-Agent。

**Script Sandbox**:脚本型 Source(LX Music 等)默认禁止:文件系统 / 任意进程 / Native API / FFI / 系统命令 / 任意 Socket。

### 7.3 Task System

统一 TaskScheduler 承接:Source 更新 / 仓库刷新 / EPG 更新 / 插件更新 / 下载 / 同步 / 备份 / MediaTicket 刷新 / Cookie 刷新 / 缓存清理。

- 类型:OneShot / Periodic / Background / Network / Media / Maintenance
- 生命周期:CREATED → QUEUED → RUNNING → SUCCESS;FAILED → RETRY;终态 SUCCESS / FAILED / CANCELLED / COMPLETED
- 优先级:Critical(播放 URL 刷新)/ High(当前播放恢复、用户主动刷新仓库)/ Normal(EPG 更新)/ Low(缓存清理)/ Background(旧图片清理)
- **去重**:同一 Source 的刷新任务必须合并复用,不允许三个 "Refresh TVBox A" 并行

### 7.4 Diagnostics

Logs + Events + Trace + Metrics + Error,五维可观测。

- **DiagnosticSession**:一次完整操作一个会话——播放会话含 play.request / source.resolve / repository.resolve / resolver.start / network.request / ticket.created / player.prepare / player.started / playback.ready。
- **Trace 关联**:traceId / sessionId / extensionId / sourceId / contentId / taskId 全链可关联。
- **DiagnosticEvent**:`{ name, timestamp, traceId?, extensionId?, sourceId?, data }`;事件如 extension.load/error、source.fetch/refresh/error、repository.load/error、resolver.start/success/error、ticket.refresh/expired、playback.started/error/recovered。
- **统一 Error Model**:PlatformError / ExtensionError / SourceError / RepositoryError / ResolverError / NetworkError / PermissionError / AuthError / MediaError / TaskError,携带 `code / message / cause / retryable / recoverable / metadata`。
- **Recovery 指导**:诊断不只记录,还要告诉 Runtime——是否重试 / 刷新 Source / 刷新 Ticket / 切线路 / 重新登录 / 禁用 Source(例:HTTP 403 → TicketRefresh → 失败 → AlternativeLine → 失败 → ResolverFallback)。
- **诊断报告过滤**:报告可含 App Version / Platform / Runtime / Source / Repository / Resolver / HTTP Status / MediaTicket / Player Engine / Error Code / Recovery Steps;**必须过滤 Cookie / Token / Password / Account Credential / Personal Data**。

故障处理标准(全基础设施统一):`Detect → Classify → Retry → Fallback → Recover → Report`。

## 8. 横纵关系图

```text
                     Extension Gateway
                            │
                    ┌───────┴───────┐
                    │               │
              PureLive Plugin   External Runtime
                    │               │
                    │             Source
                    │               │
                    │           Repository
                    │               │
                    │            Provider
                    │               │
                    │            Resolver
                    │        ┌──────┴──────┐
                    │     Identity      Permission
                    │        └──────┬──────┘
                    └───────────────┤
                               MediaTicket
                                    │
                                Media Core
```

横向:Task(Task Scheduler:Source 刷新 / Repository 更新 / 插件更新 / Ticket 刷新 / Cache 维护);Diagnostics 覆盖 Gateway / Runtime / Source / Repository / Resolver / Permission / Task / Media。

## 9. 包划分

```text
packages/
├── pure_live_extension/      # gateway / runtime / source / repository / provider 内部目录
├── pure_live_resolver/
├── pure_live_identity/
├── pure_live_permission/
├── pure_live_task/
├── pure_live_diagnostics/
├── pure_live_content/
├── pure_live_capability/
├── pure_live_media/
└── pure_live_external_tvbox/ pure_live_external_lx_music/
    pure_live_external_m3u/   pure_live_external_xmltv   # 外部协议各自独立包,只实现对应协议
```

缓存边界(统一 CacheStore,不各自实现):Source → source metadata;Repository → category/detail/search;Resolver → short-lived MediaTicket;Diagnostics → trace/event。持久化:Drift(Domain Database:Source/Repository/Identity/Account/Task/Permission/History/Favorite/Playlist)、SettingsStore(KV)、FileStore/CacheStore(文件/媒体)——职责分开。

## 10. 依赖与版本规则

依赖方向:`External Runtime → Extension → Capability → Content`。禁止:`TVBox Runtime → TV UI`、`LX Music Runtime → Music UI`、`Source → Player`、`Repository → GoRouter`、`Resolver → Widget`——业务层不得反向依赖 UI。

版本管理必须分离:App Version / Extension API Version / Runtime Version / Source Version / Repository Version / Schema Version(例:PureLive 4.0 / Extension API 1 / TVBox Runtime 2 / Schema 5)。External Runtime 声明 `protocolVersion / runtimeVersion / minAppVersion / maxAppVersion`;协议变化可并存 `TvBoxRuntimeV1 / V2`。

更新机制不混淆:插件更新(Gateway:发现→下载→校验→权限检查→安装→Migration→启用)≠ Source 刷新(刷新→检测变化→更新 Repository)。

隔离边界:Extension / Runtime / Task / Network / Permission 五重隔离——一个 LX Source A 崩溃不得导致主进程崩溃。

统一基础状态语义:`idle / loading / ready / refreshing / degraded / error / disabled / disposed`(模块可扩展,语义不各自发明)。

离线:Source → Cache → Repository Snapshot → Offline UI(可看历史/收藏/播放列表/最近内容/部分 Repository);网络恢复 → Sync / Refresh / Revalidate。

## 11. Rust 的位置

Rust 不属于九大基础设施的必选依赖。Runtime 实现保留 `Dart Runtime / Native Runtime / Rust Runtime` 三选项;未来可用于 JS Sandbox / 高速 Parser / Download Engine / 复杂协议 / 高性能 Cache。

> **Rust 是 Runtime 实现选项,而不是平台架构前提。**

## 12. 核心原则总结

1. 扩展统一入口(Extension Gateway)
2. 外部协议原生兼容(直接导入直接运行,不转换成 PureLive Plugin)
3. 统一领域模型(ContentRef / ContentIdentity / MediaItem / MediaTicket / Capability)
4. 业务与协议分离(External Runtime 管协议,Feature 管体验)
5. 解析与播放分离(Resolver → MediaTicket → Media Core)
6. 权限默认最小化
7. 任务统一调度(TaskScheduler)
8. 所有关键链路可观测(Diagnostics)
9. 用户数据与来源解耦(绑定 ContentIdentity 而非 Source)
10. Rust 是实现选项

> **PureLive v2 的核心不是"插件系统",而是一个能够同时容纳 PureLive 原生扩展和现有第三方生态的统一运行平台。**
