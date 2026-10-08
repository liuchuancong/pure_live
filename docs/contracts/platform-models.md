# PureLive Platform Models(平台数据模型)

> Version: 0.1.0(Draft)
> Scope: PureLive v2 平台基础设施
> 依赖:[platform-contracts.md](platform-contracts.md)(契约=对象能做什么;模型=对象携带什么数据)
> **阅读须知:本文 Dart 块均为模型规格示例,不是实现;字段语义为准。**

---

## 1. 模型原则

- 模型描述**数据**(identity/state/configuration/metadata/references/policies/results),行为属于 Runtime/Repository/Provider/Resolver/Service。
- 模型必须**可传输**(存储/序列化/缓存/日志/同步/isolate 传递):禁止 BuildContext/Widget/Controller/StreamController/播放器对象/数据库对象/HTTP 客户端/文件句柄/Socket/平台通道。
- 必须:UI 无关、播放器无关、Runtime 无关、数据库无关、平台无关、尽量可序列化、可版本化、跨包安全。

## 2. 与 media_core 的复用边界(先查再定义)

实现前先对照 media_core 已有定义,**能复用不重定义**:

| 平台模型 | media_core 已有 | 处理 |
|---|---|---|
| MediaTrack / MediaTrackType | `media_core/lib/source/media_track.dart` 已有 | **直接复用**(经 pure_live_media 导出),平台不重定义 |
| TaskCancelToken / TaskId | `media_core/lib/task/` 已有 | 复用;平台 TaskScheduler 的 ID/取消令牌与之一致 |
| PlayerHandle(内核句柄)/ PlayerSession / SessionManager / PlaybackCommand / PlaybackPosition / Rate | `media_core/lib/{kernel,session,playback}/` 已有 | Media Core 侧概念,平台**不定义**(平台只到 MediaTicket) |
| MediaSource / MediaSourcePlan / MediaSourcePlanner / ProgressiveMediaSource | `media_core/lib/{source,planning}/` 已有 | 平台 ResolveResult→MediaTicket 后由 media_core 规划;平台不定义 MediaPlan 数据模型 |
| PlayerErrorCode / PlayerErrorCategory / ErrorPolicy | `media_core/lib/error/` 已有 | 平台 PlatformErrorInfo 携带映射(`media.player.*` 命名空间) |
| SourceDescriptor | `media_core/lib/source/source_descriptor.dart` 已有(**语义不同**:媒体源描述) | 平台同名模型指"外部源配置";两侧行业经 pure_live_media 别名映射,平台 barrel 导出名保留 |
| identity ID 族(GenerationId/OperationId/RequestId/SessionId/SlotId) | `media_core/lib/identity/` 已有 | 命名空间分离:`media_core.player.*` vs `purelive.*`;映射在接线层 |

**净新增(仅平台定义)**:Extension/ExtensionGateway/ExternalSourceRuntime、Permission 体系、Repository、ContentRef/ContentKind/ContentIdentity/IdentityResolver/IdentityConfidence、ResolveRequest/ResolveResult/ResolveCandidate/MediaAlternative/ResolveContext/PlaybackIntent、**MediaTicket 及其 Policy**(媒体凭据是平台↔内核边界)、SourceImport 检测/校验、EpgProgram/LiveChannel/MusicTrack(platform 版)/LyricsData。

## 3. 标识符类型

```dart
typedef ExtensionId = String;   typedef RuntimeId = String;
typedef SourceId = String;      typedef RepositoryId = String;
typedef ProviderId = String;    typedef ResolverId = String;
typedef ContentId = String;     typedef IdentityId = String;
typedef TaskId = String;        typedef TraceId = String;
typedef DiagnosticId = String;  typedef AccountId = String;
typedef PermissionId = String;
```

要求:稳定、尽量确定性、命名空间内全局唯一、可序列化。

## 4. Extension 模型

### ExtensionDescriptor

```dart
class ExtensionDescriptor {
  final ExtensionId id;
  final String name;
  final String version;
  final String protocol;
  final String protocolVersion;
  final String platformApiVersion;
  final ExtensionType type;                       // builtin | plugin | external
  final Set<ExtensionCapability> capabilities;    // live/vod/music/playlist/epg/search/resolve/lyrics/download/account/recommendation/metadata
  final Set<Permission> permissions;
  final ExtensionMetadata metadata;               // description/author/homepage/repository/icon/extra
}
```

### RuntimeDescriptor

```dart
class RuntimeDescriptor {
  final RuntimeId id;
  final String name;
  final String version;
  final Set<String> protocols;
  final Set<ExtensionType> supportedTypes;
}
// 例:pure_live_plugin_runtime / pure_live_tvbox_runtime / pure_live_lxmusic_runtime
//     pure_live_m3u_runtime / pure_live_xmltv_runtime
```

### 健康与生命周期

```dart
enum RuntimeHealth { healthy, degraded, unavailable }

class RuntimeStatus { final RuntimeHealth health; final DateTime? lastCheckAt; final PlatformErrorInfo? error; }

enum ExtensionLifecycleState {
  discovered, identified, loading, validating, ready, running,
  stopping, disabled, unloading, unloaded, incompatible, error,
}

class ExtensionStatus {
  final ExtensionId extensionId;
  final ExtensionLifecycleState lifecycle;
  final RuntimeHealth health;
  final PlatformErrorInfo? error;
}
```

## 5. Source 模型

```dart
class SourceDescriptor {
  final SourceId id;
  final ExtensionId extensionId;
  final RuntimeId runtimeId;
  final String uri;
  final String? name;
  final SourceType type;           // url | file | script | builtin | repository
  final SourceConfig config;
}

class SourceConfig {
  final bool enabled;                              // 默认 true
  final Duration refreshInterval;                  // 默认 6h
  final Map<String, String> headers;               // Authorization/Cookie 不得明文持久化(走安全存储)
  final String? userAgent;
  final Map<String, Object?> options;
}

enum SourceState {
  created, detecting, validating, loading, ready,
  refreshing, degraded, error, disabled, disposed,
}

class SourceStatus {
  final SourceState state;
  final DateTime? lastUpdatedAt;
  final DateTime? nextRefreshAt;
  final PlatformErrorInfo? error;
  final Map<String, Object?> metadata;
}
```

状态语义:created=未启动;detecting=协议识别中;validating=格式/配置校验中;loading=初次加载;ready=可用;refreshing=更新中;degraded=部分可用;error=失败;disabled=被用户/平台禁用;disposed=运行时资源已释放。

## 6. Repository / Provider 模型

```dart
class RepositoryDescriptor {
  final RepositoryId id;
  final SourceId sourceId;
  final String name;
  final String version;
  final Set<RepositoryCapability> capabilities;   // list/detail/search/category/recommendation/resolve/playlist/epg
  final Map<String, Object?> metadata;
}

class ProviderDescriptor {
  final ProviderId id;
  final RepositoryId repositoryId;
  final String name;
  final ProviderType type;        // live/vod/music/album/artist/lyrics/playlist/epg/search/detail/resolve/recommendation
  final String version;
}
```

## 7. Content 模型

```dart
enum ContentKind {
  liveChannel, liveRoom,
  vod, movie, series, episode,
  music, album, artist, playlist,
  stream, epgProgram, localMedia,
}

class ContentRef {
  final SourceId sourceId;
  final String contentId;
  final ContentKind kind;
  final String? parentId;
  final String? providerId;
  final Map<String, Object?> metadata;
}
// 源相对;MUST NOT 假设全局唯一;不得包含 repository/provider/runtime 实例与 HTTP 客户端(保持轻量,§90)

class ContentSummary {          // 列表/卡片用
  final ContentRef ref;
  final String title;
  final String? subtitle;
  final String? cover;
  final String? description;
  final ContentMetadata metadata;
}                               // MUST NOT 含 UI 状态(isFocused/isSelected/route/widgetKey…§89)

class ContentDetail {
  final ContentSummary summary;
  final String? description;
  final List<ContentRef> children;
  final List<ContentTag> tags;
  final Map<String, Object?> metadata;
}

class ContentMetadata {
  final String? year; final String? region; final String? language;
  final Duration? duration; final double? rating; final int? popularity;
  final Map<String, Object?> extra;
}

class ContentTag { final String id; final String name; }
```

## 8. ContentIdentity 模型

```dart
class ContentIdentity {
  final IdentityId id;
  final ContentKind kind;
  final String canonicalKey;
  final Set<ContentRef> references;     // 多源引用并存的聚合锚点(§91)
  final IdentityConfidence confidence;  // exact/high/medium/low/unknown
  final DateTime? updatedAt;
}

enum IdentityConfidence { exact, high, medium, low, unknown }
// exact=同一官方 ID;high=同一稳定外部标识;medium=强元数据匹配;low=弱标题匹配;unknown=信息不足
// 不确定匹配 MUST NOT 视为 exact

class IdentityMatch {
  final ContentRef ref;
  final ContentIdentity identity;
  final IdentityConfidence confidence;
  final List<String> reasons;
}
```

Identity 失效不阻止播放(Invariant 7)。

## 9. 查询/分页/搜索模型

```dart
class SearchQuery  { final String keyword; final int page; final int pageSize; final ContentKind? kind; final Map<String, Object?> filters; }
class PageRequest  { final int page; final int pageSize; }                     // 默认 1 / 20
class PageResult<T>{ final List<T> items; final int page; final int pageSize; final bool hasMore; final int? total; }
class ContentQuery { final String? category; final String? keyword; final PageRequest page; final Map<String, Object?> filters; final ContentSort? sort; }
enum ContentSort { relevance, latest, popularity, rating, title }
```

外部协议内部分页不同 → Runtime 适配到本模型。

## 10. Resolver 模型

```dart
class ResolveContext {
  final PlaybackIntent intent;      // normal/audioOnly/background/cast/external/preview —— 是解析输入,不是播放器状态
  final String? preferredQuality;
  final String? preferredLanguage;
  final String? region;
  final bool networkMetered;
  final Map<String, Object?> metadata;
}

class ResolveRequest {
  final ContentRef ref;
  final ResolveContext context;
  final bool allowFallback;         // 默认 true
  final CancellationToken? cancellation;   // ⚠ runtime-only,禁止序列化(media_core TaskCancelToken 复用)
}

class ResolveResult {
  final ContentRef source;
  final List<MediaTicket> tickets;
  final MediaSelectionPolicy selection;
  final DateTime createdAt;
  final Map<String, Object?> metadata;
}

class MediaSelectionPolicy {
  final String? preferredQuality; final String? preferredProtocol; final String? preferredFormat;
  final bool preferLowLatency; final bool preferStable;
}

class ResolveCandidate {            // 最终 Ticket 之前可暴露候选
  final String id; final ContentRef source; final String? quality; final String? format;
  final MediaProtocol protocol; final int priority; final Map<String, Object?> metadata;
}
```

## 11. MediaTicket 模型

```dart
class MediaTicket {
  final String id;
  final Uri uri;                    // 内部一律 Uri;裸字符串仅出现在导入/配置边界(§85)
  final MediaKind kind;             // live | vod | music | file(语义类型)
  final MediaProtocol protocol;     // http/https/hls/dash/rtmp/rtsp/websocket/file/unknown(传输方式)——两者不得合并(§28)
  final Map<String, String> headers;
  final List<MediaTrack> tracks;    // 复用 media_core MediaTrack(§2)
  final DateTime createdAt;
  final DateTime? expiresAt;
  final MediaTicketPolicy policy;
  final MediaPlaybackMetadata metadata;   // title/artist/album/cover/duration/isLive/extra
}

class MediaTicketPolicy {
  final bool allowRedirect; final bool allowRefresh; final bool allowRetry;
  final bool allowLineFallback; final bool allowEngineFallback;
  final bool seamlessRefresh; final Duration retryDelay;   // 默认 2s
}

class MediaTicketRefreshInfo { final bool supported; final DateTime? expiresAt; final Duration? refreshBefore; }

class MediaAlternative { final MediaTicket ticket; final String? label; final String? quality; final int priority; }
// 1080p/720p/480p/audio-only 多候选
```

**MediaTicket MUST NOT 含**:currentPosition/bufferPosition/volume/playbackSpeed/playing/paused/playerEngine/playerInstance(§88,归 Media Core)。

## 12. Permission / Network / Cookie 模型

```dart
enum Permission { network, cookie, account, storage, cache, notification, background, clipboard, localServer, media, device }
enum PermissionState { unknown, denied, granted, restricted }

class PermissionGrant {
  final ExtensionId extensionId; final Permission permission; final PermissionState state;
  final DateTime? grantedAt; final DateTime? expiresAt; final PermissionScope scope;
}
class PermissionScope { final Set<String> hosts; final Set<String> paths; final Map<String, Object?> constraints; }
// network 限定 hosts: example.com + api.example.com 优于无限制网络

class NetworkRequest  { final String method; final Uri uri; final Map<String, String> headers; final Object? body; final Duration? timeout; final bool followRedirects; }
class NetworkResponse { final int statusCode; final Map<String, String> headers; final List<int> body; final Uri finalUri; }  // 大响应可用流式抽象

class Cookie { final String name; final String value; final String domain; final String? path; final DateTime? expiresAt; final bool secure; final bool httpOnly; }
// Cookie 值敏感,诊断必须脱敏
```

## 13. Task 模型

```dart
class TaskDescriptor {
  final TaskId id; final String type; final TaskPriority priority;   // critical/high/normal/low/background
  final bool networkRequired; final bool backgroundAllowed;
  final String? deduplicationKey;                                    // 同 key 不得并发(§27 of contracts)
  final Map<String, Object?> metadata;
}
enum TaskState { pending, running, paused, completed, failed, cancelled }
class TaskStatus { final TaskState state; final double? progress; final DateTime? startedAt; final DateTime? completedAt; final PlatformErrorInfo? error; final Map<String, Object?> metadata; }  // progress 可空:多数任务无意义
class TaskResult { final bool success; final Object? value; final PlatformErrorInfo? error; final Map<String, Object?> metadata; }
```

## 14. Diagnostics / Error 模型

```dart
enum DiagnosticLevel { debug, info, warning, error, fatal }

class DiagnosticEvent {
  final DiagnosticId id; final TraceId? traceId; final DateTime timestamp;
  final DiagnosticLevel level; final String name;
  final ExtensionId? extensionId; final SourceId? sourceId; final RepositoryId? repositoryId;
  final ProviderId? providerId; final ResolverId? resolverId; final TaskId? taskId;
  final ContentRef? content; final Map<String, Object?> metadata;
}

class DiagnosticTrace { final TraceId id; final String operation; final DateTime startedAt; DateTime? completedAt; final Map<String, Object?> metadata; }

class DiagnosticSpan {
  final String id; final TraceId traceId; final String operation;
  final DateTime startedAt; final DateTime? completedAt;
  final DiagnosticSpanStatus status;   // running/success/failed/cancelled
  final Map<String, Object?> metadata;
}

class PlatformErrorInfo {          // 可序列化错误表示(运行时错误对象另见 contracts §18)
  final String code; final String message; final String? category;
  final bool retryable; final bool recoverable; final Map<String, Object?> metadata;
}

enum PlatformErrorCategory { extension, source, repository, provider, identity, resolver, network, permission, auth, task, media, storage, configuration, timeout, cancellation, unknown }
```

标准错误码:`extension.not_found/incompatible/load_failed/disabled/state_invalid/already_registered`
(后三个由 W2 网关补充:`disabled` = 用户关掉后不得再 load;`state_invalid` = 生命周期转移不合法,例如
未 ready 就 start;`already_registered` = 同一 id 未 unload 前重复注册)、
`source.invalid/unreachable/parse_failed/refresh_failed`、`repository.unavailable/parse_failed`、`provider.unsupported/not_found`、`identity.not_found/ambiguous`、`resolver.unsupported/failed/timeout`、`network.timeout/unreachable/forbidden/rate_limited/response_too_large`、`permission.denied/restricted`、`auth.required/expired/invalid`、`task.cancelled/timeout/failed`、`media.unsupported/expired/unavailable`。插件自定义码必须带命名空间(`tvbox.parse_failed`、`lxmusic.script_failed`)。

## 15. 聚合 / 账号 / EPG / 音乐 / 导入模型

```dart
class RepositorySource { final RepositoryId repositoryId; final int priority; final bool enabled; }

class AggregatedContent {            // 同一内容多源 → 一个 UI 条目,不破坏原 ContentRef
  final ContentIdentity? identity;
  final ContentSummary primary;
  final List<ContentSummary> alternatives;
  final List<ContentRef> references;
}

class SourcePriority { final SourceId sourceId; final int priority; final bool preferred; }

class ContentReferencePreference {   // 首选/回退/地区/画质特定源,不改 ContentIdentity
  final SourceId sourceId; final int priority; final bool preferred; final Map<String, Object?> constraints;
}

class AccountReference { final AccountId id; final ExtensionId extensionId; final String? username; final AccountState state; }  // AccountState: unknown/loggedOut/loggedIn/expired/disabled
// 认证秘密 MUST NOT 用普通模型表示——Token 属安全凭据存储

class EpgProgram { final ContentRef ref; final ContentRef channel; final String title; final String? description; final DateTime startAt; final DateTime endAt; final String? category; }
class LiveChannel  { final ContentRef ref; final String name; final String? logo; final String? group; final List<ContentRef> streams; final Map<String, Object?> metadata; }
class MusicTrack   { final ContentRef ref; final String title; final String? artist; final String? album; final String? cover; final Duration? duration; }
class LyricsData   { final String? plain; final String? synced; final String? translation; final String? romanization; }  // 解析归 music runtime/provider
class Playlist     { final ContentRef ref; final String name; final List<ContentRef> items; final String? cover; }

class SourceImportRequest { final String input; final String? name; final SourceImportType? expectedType; final Map<String, Object?> options; }
enum SourceImportType { auto, tvbox, lxMusic, m3u, xmltv, plugin }   // 用户导入流程优先 auto
class SourceDetection { final SourceImportType type; final double confidence; final RuntimeId? runtimeId; final List<String> reasons; }
class SourceValidation { final bool valid; final List<ValidationIssue> issues; }
class SourceImportResult { final bool success; final SourceDescriptor? source; final SourceDetection detection; final SourceValidation validation; final PlatformErrorInfo? error; }
```

## 16. 序列化 / 兼容 / 卫生规则

- **需序列化**:ExtensionDescriptor、SourceDescriptor、SourceConfig、RepositoryDescriptor、ContentRef、ContentIdentity、MediaTicket、PermissionGrant、TaskDescriptor、TaskStatus、DiagnosticEvent、PlatformErrorInfo。瞬态运行时模型不强制。
- JSON:字段名稳定;枚举用字符串(禁止 `{"kind":3}`);容忍未知字段(向前兼容 §77);可选字段可缺失。
- 可空字段表示"协议确实没给",**不得**表示状态(用 `SourceState` 不用 `DateTime? loading`)。
- metadata 不是核心字段的垃圾场:稳定且被广泛消费的字段应升为类型化字段;扩展自定义 metadata 必须带命名空间(`metadata["tvbox.quality"]`),核心用 `platform.*`。
- 相等性按稳定身份:ContentRef→sourceId+contentId+kind+parentId;ContentIdentity/MediaTicket→id。禁止比较大 metadata map。
- 核心模型不可变(final/const,构造边界用 unmodifiable 集合)。
- 持久化时间一律 UTC;时长用 Duration(序列化毫秒或 ISO-8601,禁止裸浮点秒)。
- 敏感 Header(Authorization/Cookie/Set-Cookie/Proxy-Authorization/X-Api-Key/X-Auth-Token):运行时可持有,诊断与持久化必须脱敏。

## 17. 模型分层与归属

```text
Core(内容身份与播放凭据):ContentRef / ContentIdentity / MediaTicket
Transport:SourceDescriptor / RepositoryDescriptor / ProviderDescriptor
Runtime:TaskStatus / RuntimeStatus / ExtensionStatus / DiagnosticTrace
UI:不在本文定义
```

归属:ExtensionDescriptor→Extension;SourceDescriptor→Source;RepositoryDescriptor→Repository;ProviderDescriptor→Provider;ContentRef→source/provider;ContentIdentity→Identity 子系统;MediaTicket→Resolver/Media 边界;TaskDescriptor→TaskScheduler;DiagnosticEvent→Diagnostics。任何模型不得拥有其他子系统的运行时资源。

## 18. 推荐包布局(pure_live_platform)

契约与模型落在**单一伞包** `pure_live_platform`(纯 Dart,无 Flutter 依赖):

```text
packages/pure_live_platform/lib/
├── pure_live_platform.dart        # 唯一公共导出(ContentRef/ContentIdentity/ContentSummary/Source·Repository·ProviderDescriptor
│                                  #  /ResolveRequest/ResolveResult/MediaTicket/MediaTrack/Permission/Task*/DiagnosticEvent/PlatformErrorInfo)
├── models/{extension,runtime,source,repository,provider,content,resolver,media,permission,task,diagnostics,error,network,epg,music}/
└── contracts/                     # 接口定义(Extension/Gateway/Runtime/Source/Repository/Provider/Resolver/Refresher/PermissionManager/TaskScheduler/…)
```

> **实现落点以 [../adr/0018-contract-package-split.md](../adr/0018-contract-package-split.md) 为准**:本节示例写的是
> 单一伞包,实际形态是**模型集中在 `pure_live_platform`,行为契约按子系统分包**
> (`capability` / `extension` / `permission` / `task` / …)。`pure_live_platform` 不建 `contracts/` 目录。

## 19. 首实现优先级(不要一次实现全部)

最小首切片(TVBox 播放通)需要:

```text
ExtensionDescriptor / RuntimeDescriptor / SourceDescriptor / RepositoryDescriptor / ProviderDescriptor
ContentRef / ContentSummary
ResolveRequest / ResolveContext / ResolveResult
MediaTicket / MediaTicketPolicy
PlatformErrorInfo
DiagnosticEvent / DiagnosticTrace
```

TVBox 播放通之后再加:ContentIdentity / Task / Permission / Aggregation / EPG / Music。

## 20. 设计不变量(Invariants 1-10)

1. ContentRef 不含播放器信息。
2. MediaTicket 不含 UI 状态。
3. Resolver 不创建 Player 实例。
4. Repository 不依赖 UI。
5. External Runtime 不需要变成 Plugin。
6. Source 失败不代表 Runtime 失败。
7. Identity 失败不阻止播放。
8. 未知 metadata 不破坏模型解析。
9. 取消不视为普通失败。
10. Media Core 拥有播放状态。

## 21. 最终模型流

```text
User Input → SourceImportRequest → SourceDetection → SourceDescriptor
→ RepositoryDescriptor → ProviderDescriptor → ContentSummary → ContentRef
→(ContentIdentity)→ ResolveRequest → ResolveResult → MediaTicket → Media Core
```

最重要的稳定边界:

```text
ContentRef → ResolveRequest → ResolveResult → MediaTicket → Media Core
```

边界之上描述"用户想要什么内容",边界之下描述"内容如何播放"——该边界 MUST 保持独立于 Flutter UI、外部源协议、repository 实现与播放引擎。
