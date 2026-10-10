# packages/ 公共模块目录

> 本目录是 monorepo 的**共享模块层**:四个 App(`apps/pure_live` 直播、`apps/pure_bili` B 站视频、
> `apps/pure_music` 音乐、`apps/pure_tvbox` TVBox 兼容)直接调用这些包,不复制代码。
> **App 之间互不依赖;一切共享逻辑下沉到这里。**
>
> 本文件的表是"包提供什么";**"哪个包被哪个 App 消费"以及包重写范围的唯一依据**是
> [docs/architecture/application-portfolio.md](../docs/architecture/application-portfolio.md) §3,
> 重写的完成判据(工业级 DoD)在同文 §6。决策记录:
> [docs/adr/0022-multi-app-one-feature-each.md](../docs/adr/0022-multi-app-one-feature-each.md)。
> **规则:没有 App 消费者的包不重写也不保留**——空壳包让包数变成误导数字。
>
> 添加新 App:在 `apps/<name>` 建包 → 根 `pubspec.yaml` 的 `workspace:` 登记 → 按下表选依赖。
> 层级方向严格单向(见 docs/architecture/dependency-rules.md);护栏 `tool/check_architecture.dart --strict` 强制。

## 依赖方向(App 视角)

```
App 可依赖:全部层(L0 → L5)
规则:features → L0+ecosystem+services;services → L0+ecosystem;
     providers → L0+ecosystem;ui → L0+ecosystem+ui;同层禁互依(例外表见护栏)
```

## L0 foundation(基础能力,全部可用)

| 包 | 公共 API | 用途 |
|---|---|---|
| pure_live_utils | 异步/集合/字符串/时间工具、Clock 时钟缝 | 所有包的公共叶子 |
| pure_live_logging | 日志门面 | 统一日志 |
| pure_live_network | NetworkClient(dio 封装:超时/重试退避/体积上限/状态码自管)、NetworkFailure 分类 | 全部 HTTP |
| pure_live_storage | FileKeyValueStore(JSON KV 文档,原子写)、KeyValueStore 接口、迁移 | 偏好/缓存/域数据落盘 |
| pure_live_cache | CacheHub 命名空间缓存(内存 LRU/FIFO+TTL)+ DiskCacheTier 磁盘层 + TwoLevelCache | 图片/API/媒体缓存 |
| pure_live_files | writeAtomic/readStringOrEmpty/directorySize/deleteQuietly | 文件操作 |
| pure_live_auth | CredentialStore(凭据+会话,SecretVault/SessionBox 注入)、AuthSession/CredentialHandle | 站点登录凭据 |
| pure_live_backup | BackupEngine/RestoreEngine(域快照,凭据键两端拒收)、WebDavBackupStore | 用户数据备份/恢复 |
| pure_live_sync | SyncEngine(游标记录同步,RemoteStore/LocalStore 注入) | 数据同步 |
| pure_live_events | EventBus(类型化进程内事件) | 无主事实广播 |
| pure_live_diagnostics | RingBuffer(有界环) | 诊断缓冲 |
| pure_live_l10n | LocaleTag(BCP-47)、TranslationBundle/TranslationResolver(回退链+插值) | 多语言 |
| pure_live_platform_info | 平台/设备探测 | 平台判定 |
| pure_live_release | AppVersion(四段版本比较)、UpdateChecker/ReleaseEntry(releases.json 源) | 应用内更新 |

## L0.5 integrations(厂商 SDK 适配,仅此层可见厂商)

| 包 | 公共 API | 用途 |
|---|---|---|
| pure_live_media | MediaKernelHost(内核)、MediaSurface、MediaCorePlayerView(六风格控制面)、MediaSessionBootstrap、PlayerConfig、VodPlaybackCore(见 roadmap) | 播放 |
| pure_live_python_runtime | PythonSpiderHost + LocalSpiderGateway(嵌入 CPython,worker 轮询本地网关) | TVBox py spider |
| pure_live_firebase | FirebaseBootstrap(受保护初始化,未配置=安全降级) | 可选分析/崩溃 |

## L1 ecosystem(契约与运行时)

| 包 | 公共 API | 用途 |
|---|---|---|
| pure_live_platform | 全部数据模型(ContentRef/MediaTicket/Page*/MediaTrack/PluginManifest/...) | 统一词汇 |
| pure_live_capability | CapabilityKind、Browse/Search/Resolve/Feed 接口、CapabilitySet/Registry | 源能力契约 |
| pure_live_permission | PolicyPermissionManager、ExtensionNetwork/CookieStore(权限天花板) | 插件权限 |
| pure_live_task | TaskScheduler/Task/TaskContext(优先级+去重) | 后台任务 |
| pure_live_extension | ExtensionGateway/RuntimeRegistry/ExtensionContext(插件装配点) | 插件生命周期 |
| pure_live_plugin_api | Manifest 校验/HostBridge/ScriptSandbox/PluginRuntime 契约 | 插件 ABI |
| pure_live_plugin_host | PluginBundle 解析(Manifest 头)、PluginStore(原子落盘/启停/卸载) | 插件安装 |
| pure_live_js_runtime | FjsJsSandbox(fjs 引擎,资源上限强制)、JsPluginRuntime、PureLive.registerPlugin 环境 | JS 插件 |
| pure_live_resolver | ResolverRegistry/ResolverChain/CapabilityResolver | 解析链 |
| pure_live_identity | IdentityMatcher/Index(跨源内容身份) | 同内容跨源对齐 |
| pure_live_external_tvbox | SpiderHandle 契约、SpiderVodProvider(通用适配)、TVBox 单仓多仓/M3U 解析、PlaylistLiveSource | TVBox/IPTV 兼容 |
| pure_live_python_runtime | PythonSpiderHost(serious_python)+ LocalSpiderGateway(loopback 任务网关) | py spider |

## L2 services(业务数据服务)

| 包 | 公共 API | 用途 |
|---|---|---|
| pure_live_favorites | FavoritesService(收藏分组/条目,文件域持久化) | 收藏 |
| pure_live_history | HistoryService(观看进度,节流写+flush) | 历史/续播 |
| pure_live_playlist | PlaylistsService(歌单/播放列表) | 队列 |
| pure_live_search | CapabilitySearchAggregator(跨源搜索扇出,逐源隔离) | 搜索聚合 |
| pure_live_feed | CapabilityFeedAggregator(跨源首页扇出,源序稳定) | 首页聚合 |

## L3 ui(界面基础)

| 包 | 公共 API | 用途 |
|---|---|---|
| pure_live_design | 令牌(spacing/radius)、BackgroundConfig | 设计词汇 |
| pure_live_adaptive | AdaptiveUiStyle 六风格注册表(light/dark 双主题)、AppBackground(背景层) | 风格切换 |
| pure_live_ui_kit | PosterCard/CoverImage、EmptyState、ErrorRetry、SectionHeader | 共享组件 |
| pure_live_lyric | LyricsSurface(flutter_lyric 适配:LRC/YRC/QRC) | 歌词 |
| pure_live_player_ui | showPlayerOptionSheet、showPlayerEpisodePanel(泛型面板) | 播放面板 |

## L4 features(业务域,domain+data 实装;presentation=UI 最后)

| 包 | domain | data |
|---|---|---|
| features/live | LiveSession(换源状态机:pending→commit/rollback) | — |
| features/vod | EpisodeNavigator(连播导航) | WatchProgressRepository(续播位置) |
| features/music | — | MusicQueue+LxMusicRepository(队列+lx 解析) |
| features/search | — | SearchHistory(搜索历史) |
| features/settings | — | PreferencesStore(类型化偏好) |
| features/account | — | SiteAccountRegistry(站点凭据注册) |
| features/backup | — | WebDavBackupService(构建→推→拉→恢复) |
| features/iptv | ChannelZapper+EpgWindow | — |
| features/home | HomeTabOrganizer(标签序) | — |
| features/recorder | RecordingTask 状态机 | — |

## L5 providers(域适配层;站点业务以导入插件为主)

| 包 | 公共 API | 用途 |
|---|---|---|
| pure_live_demo | DemoLiveSource(种子样例) | 开发演示 |
| pure_live_huya | HuyaSource(虎牙:feed/browse/search/resolve+antiCode 签名) | 直播 |
| pure_live_bilibili | BilibiliVodSource(WBI 搜索/详情/playurl)+ BilibiliLiveSource(直播) | B站 |
| pure_live_music | MusicSourceScriptHost(lx 兼容宿主)+ crypto/zlib 桥 | 音乐 |
| pure_live_iptv | IptvSource(M3U+EPG)、XmltvParser | IPTV |
| pure_live_tvbox / douyu / douyin / twitch / youtube / community | 骨架(按需填充或由导入插件替代) | 预留 |

## App 接入清单(新 App 五步)

1. `apps/<name>/` 建 Flutter 包,pubspec 写 `resolution: workspace` + 所需包依赖;
2. 根 `pubspec.yaml` 的 `workspace:` 登记路径;
3. 组合根(lib/app/runtime.dart)装配:存储/网络/缓存 + 注册域源;
4. `tool/flutterw.ps1 pub get` → `dart analyze` → 护栏 `--strict`;
5. UI:ui/adaptive 选风格,ui_kit 取组件。
