# PureLive Platform Contracts(平台契约)

> Version: 0.1.0(Draft)
> Scope: PureLive v2 平台基础设施
> 上游:[platform-infrastructure.md](../architecture/platform-infrastructure.md) · 数据模型:[platform-models.md](platform-models.md)
> **阅读须知:本文所有 Dart 代码块均为契约规格示例(spec),不是实现;W1 实现以本文语义为准。**

---

## 1. 目的

定义平台基础设施组件之间的**稳定契约**,使以下系统可独立演进:PureLive Plugins、External Sources、External Runtimes、Source 管理、Repository、Provider/Capability、Content Identity、Resolver、MediaTicket、Permission、Task、Diagnostics、Media Core。

平台必须同时支持:

```text
PureLive Plugin
External Source(TVBox / LX Music / M3U / XMLTV / 未来协议)
```

**External ecosystems MUST NOT be forced to convert into a PureLive Plugin**(见 [../architecture/external-ecosystem.md](../architecture/external-ecosystem.md))。

## 2. 架构与依赖方向

```text
Extension Gateway
 → Plugin Runtime / External Runtime
 → Source → Repository → Provider(+Capability)
 → ContentRef → Identity → Resolver → MediaTicket
 → Media Core → Player
```

横向平台服务:Permission / Task / Diagnostics / Cache / Storage / Network / Configuration——**MUST NOT 成为业务专属依赖**。

### 2.1 禁止的反向依赖

```text
Media Core → Repository
Player → Source
UI → Runtime internals
Repository → GoRouter
Source → Widget
Resolver → Widget
Plugin → App-specific feature
External Runtime → PureLive UI
```

### 2.2 UI 无关

平台契约 **MUST NOT** import:`flutter/material.dart`、`flutter/widgets.dart`、`go_router`、Riverpod、GetX、ScreenUtil、DPad。平台模型必须是纯 Dart;UI 适配属于平台层之上。

### 2.3 Runtime 无关

Runtime MUST NOT 知道:内容显示在哪个页面、用哪个播放器 widget、用哪个路由、激活什么主题、历史 UI 怎么实现。Runtime 只提供数据与能力。

## 3. 核心标识符

```dart
typedef ExtensionId = String;
typedef RuntimeId = String;
typedef SourceId = String;      // ⚠ 与 media_core identity/source_id.dart 的 SourceId 属不同命名空间
typedef RepositoryId = String;
typedef ProviderId = String;
typedef ContentId = String;
typedef IdentityId = String;
typedef TaskId = String;        // ⚠ media_core task/task_id.dart 已有 Player 域 TaskId
typedef DiagnosticId = String;
```

ID 必须:稳定、可序列化、不依赖内存地址、不含 UI 状态、不随启动变化。**命名空间规则**:media_core 侧 ID 属 `media_core.player.*` 域,平台侧属 `purelive.*` 域,映射关系在 `pure_live_media` 接线层完成。

## 4. Extension

```dart
abstract interface class Extension {
  ExtensionDescriptor get descriptor;
  Future<void> initialize(ExtensionContext context);
  Future<void> start();
  Future<void> stop();
  Future<void> dispose();
}
```

ExtensionDescriptor 字段见 [platform-models.md §4](platform-models.md#4-extension-models);id 约定:

```text
purelive.builtin.bilibili
purelive.external.tvbox
purelive.external.lxmusic
purelive.external.m3u
purelive.external.xmltv
```

## 5. Extension Capability

```dart
enum ExtensionCapability {
  live, vod, music, playlist, epg, search,
  resolve, lyrics, download, account, recommendation,
}
```

Capability 必须是**声明式**的;平台必须能在启动插件之前判定其能力。

## 6. Extension Gateway

```dart
abstract interface class ExtensionGateway {
  Future<void> register(ExtensionDescriptor descriptor);
  Future<void> load(ExtensionId id);
  Future<void> start(ExtensionId id);
  Future<void> stop(ExtensionId id);
  Future<void> unload(ExtensionId id);
  Future<void> disable(ExtensionId id);
  ExtensionHandle? find(ExtensionId id);
  List<ExtensionHandle> getAll();
}
```

生命周期:`DISCOVER → IDENTIFY → SELECT_RUNTIME → LOAD → VALIDATE → REGISTER → READY → RUNNING → DISABLE → UNLOAD`(完整语义见 [../architecture/platform-infrastructure.md](../architecture/platform-infrastructure.md) §3)。

## 7. Runtime

```dart
abstract interface class ExtensionRuntime {
  String get id;
  String get version;
  bool canHandle(ExtensionDescriptor descriptor);
  Future<RuntimeInstance> load(ExtensionDescriptor descriptor);
}

abstract interface class RuntimeInstance {
  ExtensionDescriptor get descriptor;
  Future<void> initialize();
  Future<void> start();
  Future<void> stop();
  Future<void> dispose();
  List<Source> get sources();
}
```

示例:PluginRuntime / TvBoxRuntime / LxMusicRuntime / M3uRuntime / XmlTvRuntime。

## 8. Source

Source 是用户配置或内置的真实源(URL/文件/脚本/内置)。

```dart
abstract interface class Source {
  SourceDescriptor get descriptor;
  SourceState get state;
  Future<void> initialize();
  Future<void> refresh();
  Future<void> dispose();
}
```

SourceType:`url / file / script / builtin / repository`。生命周期与状态见 [platform-models.md §6](platform-models.md#6-source-models)。

⚠ **命名冲突**:media_core `lib/source/source_descriptor.dart` 已有 Player 域的 `SourceDescriptor`(媒体源描述)。平台侧 SourceDescriptor(外部源配置)与其语义不同——实现时经 `pure_live_media` 接线层做映射,平台 barrel 导出名保持 `SourceDescriptor`,media_core 侧以 alias 引用。

## 9. Repository

```dart
abstract interface class Repository {
  RepositoryDescriptor get descriptor;
  List<Provider> get providers;
  Future<void> initialize();
  Future<void> refresh();
  Future<void> dispose();
}
```

Repository MUST NOT 暴露 UI 模型。TVBox 应暴露 `VodProvider / SearchProvider / ResolveProvider`,而不是 `TvBoxMovieWidget / TvBoxPage / TvBoxRoute`。

## 10. Provider 与 Capability

Provider 暴露一个具体能力;**Provider 是实现侧,Capability 是平台侧**:

```text
TvBoxVodProvider → VodCapability
LxMusicSearchProvider → MusicSearchCapability
```

这阻止 Feature 直接依赖 TVBox / LX Music 实现细节。接口示例(VodProvider.list/detail、SearchProvider.search、ResolveProvider.resolve)见上游规格;签名一律走 `ResolveRequest/ResolveResult`(Request 对象模式,**禁止**在既有方法上加位置参数式扩展——见 §13 API 演进)。

## 11. ContentRef / ContentIdentity

定义见 [platform-models.md §9-18](platform-models.md#9-content-models)。要点:

- ContentRef 是**源相对**的,不得假设全局唯一。
- ContentIdentity(Canonical)通过 IdentityResolver 解析;**Identity 解析不得是播放的前置条件**——`ContentRef → Resolver` 永远有效,Identity 是增强层(缓存/去重/换源)。

## 12. Resolver

```dart
abstract interface class Resolver {
  ResolverDescriptor get descriptor;
  bool canResolve(ContentRef ref);
  Future<ResolveResult> resolve(ResolveRequest request);
}
```

类型:Live / Vod / Music / Iptv / Local / Download。注册与候选选择经 ResolverRegistry(见 [../architecture/platform-infrastructure.md](../architecture/platform-infrastructure.md))。

## 13. ResolveRequest / ResolveResult / MediaTicket

最终形态(字段定义见 [platform-models.md §23-33](platform-models.md#23-resolver-models)):

```dart
class ResolveRequest {
  final ContentRef ref;
  final ResolveContext context;      // intent/画质/语言/地区/计费网络
  final bool allowFallback;
  final CancellationToken? cancellation; // runtime-only,不序列化
}

class ResolveResult {
  final ContentRef source;
  final List<MediaTicket> tickets;
  final MediaSelectionPolicy selection;
  final DateTime createdAt;
  final Map<String, Object?> metadata;
}
```

**MediaTicket 是平台基础设施与 Media Core 之间的桥**;结构定义见 [platform-models.md §26-33](platform-models.md#26-mediamodels-ticket)。要点:

- MediaKind(语义:live/vod/music/file)与 MediaProtocol(传输:http/hls/dash/rtmp/…)是两个枚举,**不得合并**。
- MediaTicketPolicy(allowRedirect/allowRefresh/allowRetry/allowLineFallback/allowEngineFallback/seamlessRefresh/retryDelay):**平台层描述播放要求,Media Core 决定如何执行**。
- MediaTicket MUST NOT 含播放状态(position/volume/speed/engine)——那是 Media Core 的(见 models §88)。

## 14. Ticket Refresh

```dart
abstract interface class MediaTicketRefresher {
  bool canRefresh(MediaTicket ticket);
  Future<MediaTicket> refresh(MediaTicket ticket);
}
```

刷新 MUST NOT 重建 feature/页面;media_core 支持无缝替换时会话保持稳定。

## 15. Permission / Network / Cookie

- PermissionManager:`check/request/revoke`(Permission/PermissionState/PermissionGrant/PermissionScope 模型见 models §34-37;网络权限带 Host 白名单作用域)。
- ExtensionNetwork:插件唯一网络出口(NetworkRequest/NetworkResponse 模型);平台强制 host/timeout/大小/并发/诊断。
- ExtensionCookieStore:`get/set/clear(host)`;插件 MUST NOT 直接访问全局 Cookie 数据库。

## 16. Task

统一后台任务(Source 刷新/仓库更新/EPG/插件更新/下载/同步/备份/Cookie 刷新/Ticket 刷新/缓存清理):

```dart
abstract interface class Task {
  TaskDescriptor get descriptor;
  Future<TaskResult> run(TaskContext context);
  Future<void> cancel();
}

abstract interface class TaskScheduler {
  Future<TaskHandle> submit(Task task);
  Future<void> cancel(TaskId id);
  Future<void> pause(TaskId id);
  Future<void> resume(TaskId id);
  TaskHandle? find(TaskId id);
  List<TaskHandle> running();
  List<TaskHandle> pending();
}
```

相同 `deduplicationKey`(如 `source:tvbox_001:refresh`)MUST NOT 并发执行。⚠ media_core 已有 Player 域 Task/TaskContext/TaskCancelToken——平台的 TaskScheduler 调度模型独立,但 **CancelToken 与 ID 直接复用 media_core 定义**,经映射层转换。

## 17. Diagnostics

诊断是平台契约的一部分,≠ 日志。平台提供:Logs / Events / Traces / Metrics / Errors。

- DiagnosticEvent / DiagnosticTrace / DiagnosticSpan 模型见 models §46-50。
- 每个重要操作必须产生 Trace:Extension load / Source refresh / Repository query / Search / Resolve / MediaTicket 创建 / Task 执行 / Permission request / Network request。
- 事件必须尽量携带:extensionId/sourceId/repositoryId/providerId/contentId/resolverId/taskId/traceId。
- **脱敏**:password / access_token / refresh_token / private cookie / authorization header 不得记录,除非显式 redact。

## 18. Error Model / Retry / Cancellation / Timeout

- 所有平台错误实现 `PlatformError`(code/message/cause/retryable/recoverable/metadata);分类与标准错误码清单见 models §51-53(自定义码必须带插件命名空间,如 `tvbox.parse_failed`)。
- 错误 MUST NOT 直接触发 UI 行为:`Error → Classify → Recovery Policy → Retry/Fallback/Abort`(NetworkError→retry 同源;ResolverError→line fallback;MediaError→engine fallback;PermissionError→请求授权;AuthError→刷新账号)。
- **取消不是错误**:长操作一律支持 `CancellationToken`(media_core 已有 TaskCancelToken,复用),独立于失败表达。
- 超时必须在操作边界显式声明:Network 15s / Source 校验 15s / Resolve 30s / Repository 刷新 60s;协议 Runtime 可覆写;超时必须产生 `NetworkError.timeout` 或对应域错误。

## 19. Cache / Storage / ExtensionContext

- PlatformCache:`get/put/remove/clear(namespace,key,ttl)`;命名空间必须含属主(例 `extension.tvbox.source_001.repository`)。
- PlatformStorage:持久配置,与缓存分离;插件 MUST NOT 直接访问 Drift/Hive/SQLite/SharedPreferences/应用文件系统——实现可换而 Extension API 不变。
- **ExtensionContext 是插件的主依赖注入边界**:

```dart
class ExtensionContext {
  final ExtensionDescriptor descriptor;
  final ExtensionNetwork network;
  final ExtensionCookieStore cookies;
  final PlatformCache cache;
  final PlatformStorage storage;
  final PermissionManager permissions;
  final TaskScheduler tasks;
  final DiagnosticTracer diagnostics;
}
```

**禁止全局服务访问**(I 扩展):GlobalPlayerService / GlobalRouter / GlobalTheme / GlobalDatabase / GlobalCookieStore / GlobalHttpClient / GlobalCacheManager / GlobalSettings —— 一律 `Extension → ExtensionContext → Platform Contract`。

## 20. Feature / UI 层

- Feature 消费平台契约,可依赖 Repository/Provider/Content/Identity/Resolver;MUST NOT 依赖 TVBox internals / LX Music internals / M3U parser internals / Plugin Runtime internals。
- UI 消费 feature 模型(ContentCard → ContentRef → Feature Controller → Repository);UI 不得直接调 TvBoxParser / LxMusicParser / M3uParser。

## 21. 四个垂直切片(实现顺序)

1. **TVBox 单仓**:URL → Gateway → TvBoxRuntime → Source → Repository → VodProvider → ContentRef → IdentityResolver → Resolver → MediaTicket → Media Core → Player。先证明 Runtime/Source/Repository/Provider/ContentRef/Resolver/MediaTicket/Permission/Diagnostics 九件事。
2. **TVBox 多仓**:多 Source 独立失败 / 优先级 / 去重 / 分页 / 搜索 / resolve + RepositoryAggregator(聚合不得修改底层协议)。
3. **LX Music**:同一套平台契约无改动工作。
4. **M3U + XMLTV**:LiveRepository/LiveProvider + EpgRepository/EpgProvider,经 Identity 关联 LiveChannel ↔ EpgProgram。

## 22. 存量直播源迁移

现有 33+ 直播源最终成为 Source/Repository/Provider/Resolver,不再与 feature 页面紧耦合。模式:`旧 Source → Adapter → 新 Provider 契约`;**不要一次性重写全部**。

## 23. 契约演进与稳定集

- 语义化版本;Patch=修 bug,Minor=向后兼容新增,Major=破坏性;插件声明 `platformApiVersion`,不兼容者进入 `INCOMPATIBLE` 态并给结构化错误。
- **API 演进偏好**:新增可选能力 > 修改既有签名;一律用 Request 对象(ResolveRequest)而非堆位置参数。
- **核心稳定契约**(改动必须走 ADR):ExtensionDescriptor、ExtensionRuntime、Source、Repository、Provider、ContentRef、ContentIdentity、Resolver、ResolveRequest、ResolveResult、MediaTicket、Permission、Task、DiagnosticEvent、PlatformError。
- 不作为公共契约暴露:Flutter Widget / GoRouter Route / Riverpod Provider / GetX Controller / MediaKit / ExoPlayer / Fijk / 数据库实现 / HTTP 客户端实现 / 缓存实现 / 平台通道实现。
