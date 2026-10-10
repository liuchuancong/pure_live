# 依赖规则与架构不变量

> 护栏脚本 `tool/check_architecture.dart` 按本文机械校验;违反 = CI 失败。

## 1. 分层与方向

```text
L0 Foundation → L0.5 Integrations → L1 Ecosystem → L2 Services
→ L3 UI → L4 Features → App(组合根,每个 App 一个)
L5 Providers/Plugins(与 L2-L4 平级,只向下依赖)
```

严格单向,禁止任何反向依赖;`sources/plugins` 之间禁止互相依赖;**App 之间禁止任何依赖**(含 dev/test)。

## 1bis. App 清单(一个 App 一个功能)

| App | 功能 | 装配的生态面 |
|---|---|---|
| `apps/pure_live` | 直播(native Dart 源) | 不装插件宿主 / 不装 JS+Python 运行时 |
| `apps/pure_bili` | B 站视频 | 同上 |
| `apps/pure_music` | 音乐(lx + bmsc 式音源) | 同上 |
| `apps/pure_tvbox` | TVBox 兼容(导入即运行) | 装 permission / extension / plugin_api / plugin_host / js_runtime / external_tvbox / python_runtime |

依据与边界见 [application-portfolio.md](application-portfolio.md) 与
[../adr/0022-multi-app-one-feature-each.md](../adr/0022-multi-app-one-feature-each.md)。
"哪个包被哪个 App 消费"的矩阵在 portfolio 文 §3,它是包重写范围的唯一依据。

护栏对这一节机械执行四条:`app-to-app`(App 的 pubspec 依赖另一个 App)、`app-import-app`
(App 源码 import 另一个 App 的 package)、`depend-on-app` / `import-app`(共享包反向触达任一 App),
以及把 `apps/*` 纳入 `unregistered-package` 扫描(只查直接子目录,不递归进原生工程的
`ephemeral/` 生成物)。App 仍不受包布局模板约束(barrel / `lib/src`),但它的依赖方向照常检查。

## 2. 包清单(81+)

| 层 | 包 |
|---|---|
| L0 Foundation | utils, logging, network, auth, storage, files, platform_info, **cache**, **events**, **diagnostics**, backup, sync, release, l10n |
| L0.5 Integrations | firebase(**保留**), media(media_core 接线), **python_runtime**(serious_python 嵌入式 CPython 宿主) |
| L1 Ecosystem | plugin_api, plugin_host, plugin_registry, extension(gateway), resolver, identity, permission, task, capability, content, external_tvbox / lx_music / m3u / xmltv, theme, background, danmaku |
| L2 Services | search, history, favorites, playlist, links, feed, download, remote, cast, fonts, emote |
| L3 UI | design, ui_kit(唯一 import fluttersdk_wind), adaptive, lyric, player_ui |
| L4 Features | repository:live/vod/music/iptv/recorder/search/home/account/backup;UI:live_ui/vod_ui/music_ui/iptv_ui/recorder_ui/settings_ui/account_ui/backup_ui/home_ui。**偏好机制不在这一层**:它(`PreferenceKey` / `PreferencesStore`)住在 L0 `storage`,因为 §3 既禁同层互依也禁 L0 互依,而机制必须用 `KeyValueStore`;各 App 的偏好**词汇表**仍归自己声明(portfolio §5) |
| L5 Providers | bilibili(live+vod 参考实现)、douyu、huya、douyin、twitch、youtube 等 33+ 站、music sources、tvbox adapters、iptv sources、第三方插件 |

目录形态:`packages/<层>/<短名>`,层 = `foundation/ integrations/ ecosystem/ services/ ui/ features/ providers/`;应用壳在 `apps/<name>`(四个,见 §1bis),仓库根 `pubspec.yaml` 是 pub workspace hub,四个 App 都是成员。包名 `pure_live_<短名>`,目录用短名。形态决策见 [../adr/0015-monorepo-layout.md](../adr/0015-monorepo-layout.md),多 App 拆分见 [../adr/0022-multi-app-one-feature-each.md](../adr/0022-multi-app-one-feature-each.md)。

## 3. 逐层依赖细则

- **L0**:互不依赖,**唯一例外**是人人可用的叶子 `utils` 与 `logging`(任何包都可依赖它们,含 L0 内部);只依赖 pub.dev 三方。护栏 `tool/check_architecture.dart` 的 `kLeafPackages` 就是这条例外的白名单。
- **L0.5**:→ L0。
- **L1**:→ L0,外加共享模型伞包 `pure_live_platform`(见 [../contracts/platform-models.md](../contracts/platform-models.md) §18);L2-L5 同理可依赖该伞包。
- **L2 services**:→ L0 + L1 的**契约面** —— `pure_live_platform` 伞包与 `pure_live_capability`
  (能力接口与 `CapabilityRegistry`;provider-contract.md §3 规定搜索/Feed 的发现入口就是它,所以这条边是
  文档要求,不是新开的口子)。L2 **不**依赖 L1 的运行时服务包(plugin_api / extension / permission / task / resolver),
  那些由组合根注入进来;护栏只查方向,这条界线靠 review 守(见 [../roadmap/w4-progress.md](../roadmap/w4-progress.md) §3)。
- **L3 ui**:→ **design 是 ui 层的叶子**(任何 ui 包都可依赖它,像 L0 的 utils/logging)+ L0 + theme。
  层内次序是 `design → ui_kit → adaptive`:ui_kit 是组件底座,adaptive 是风格注册表,后者可用前者。
  design 不含行为也不 import Flutter,所以"人人可用"不会把耦合带回来。
  (此前这行只写了 `ui_kit→design`,而 `ui/lyric` 早已依赖 design —— 文档落后于代码,见 §4。)
- **L4 features**:repository → L0 + plugin_api + services;UI 包 → **本域 repository** + services + ui + ecosystem;同层禁互依。
- **L5 sources**:→ L0 + plugin_api(经 host 注入的沙箱桥);同层禁互依;**不得触碰 PlayerAdapter**。
- **app**:每个 App 都是自己进程里的唯一全知层;其他任何包禁止依赖 app,**App 之间也禁止互相依赖**
  (共享只能下沉到 `packages/`,或各自实现)。

## 4. 显式例外清单(护栏白名单)

| 例外 | 理由 |
|---|---|
| danmaku → media | 弹幕时间轴跟播放器时钟 |
| background → media | 视频背景复用播放内核 |
| sync → firebase | 云同步数据面 |
| backup → auth | 同步凭据 |
| player_ui → media | 控制层需要播放状态 |
| ui_kit → design | 组件底座就是设计令牌(护栏同表已有,此前漏记于文档) |
| adaptive → design、adaptive → ui_kit | design 是 ui 层的叶子,注册表要把 `DesignTokens` 映射成 ThemeData 并安装 ui_kit 的 `DesignTokensTheme`。护栏不需要新白名单:`kAllowedLayers['ui']` 已含同层;**不把 design 加进 `kLeafPackages`** —— 那会让 L0 也能 import ui 包 |
| external_tvbox → python_runtime | 外部生态运行时必须宿主在嵌入式 CPython 上(见 [../adr/0017-tvbox-python-runtime.md](../adr/0017-tvbox-python-runtime.md)) |
| python_runtime → external_tvbox | Python 宿主实现的是 external_tvbox 定义的 SpiderHandle 契约,镜像上述依赖(见 [../adr/0017-tvbox-python-runtime.md](../adr/0017-tvbox-python-runtime.md)) |
| external_tvbox → js_runtime | js spider 的执行走同一个沙箱体系,适配器需要能驱动它(见 [../plugin/js-plugin.md](../plugin/js-plugin.md)) |
| extension → permission / task | 网关是 `ExtensionContext` 的装配点,只能定向依赖这两个服务包(见 [../adr/0019-gateway-service-edges.md](../adr/0019-gateway-service-edges.md)) |
| resolver → capability | `Resolver` 是 `ResolveCapability` 的平台形状,适配器必须能看到被适配的契约(见 [../adr/0021-resolver-capability-edge.md](../adr/0021-resolver-capability-edge.md)) |
| js_runtime → plugin_api / capability | JS 宿主实现的正是 plugin_api 的沙箱与运行时契约,并把适配器以能力对象交付(见 [../plugin/js-plugin.md](../plugin/js-plugin.md)) |
| plugin_host → plugin_api | 安装器直接调用 plugin_api 的 Manifest 校验器,权限天花板只有一处裁决(见 [../plugin/plugin-manifest.md](../plugin/plugin-manifest.md)) |
| external_tvbox → plugin_api | spider 沙箱要命名 `SandboxPolicy`/`SandboxUnit`,那是 plugin_api 的沙箱契约而不是 js_runtime 宿主;与上面 js_runtime → plugin_api 同一条「插件系统与其执行引擎是一个域」的边(见 [../plugin/js-plugin.md](../plugin/js-plugin.md)) |

### 4.1 声明与 import 必须一致(护栏 `undeclared-dependency`)

pub workspace 会把 `package:<成员>/...` 解析到任何 workspace 成员,即使 import 方从没在自己的 pubspec 里声明它。
而 §3 的方向表只读 pubspec,所以这类边对方向校验完全不可见 —— 目录里统计出来的依赖也因此偏少。护栏于是把每个包
`lib/` 里的 `package:` import 与它声明的 `dependencies` 逐条比对,缺失的记为 **warning**:构建今天能过,但这是一条
没被记录的真实依赖。CI 用 `--strict` 跑(见 [.github/workflows/architecture.yml](../../.github/workflows/architecture.yml)),
warning 同样让流水线变红。

- 只针对 workspace 成员;pub.dev 三方包的声明由 lockfile 与 analyzer 负责,护栏不重复报。
- **dev_dependencies 不是 `lib/` 的声明**:只在测试里可用的包被生产代码 import,消费者侧必然解析不到。
  `foundation/release` 曾经这样引用 `pure_live_network`(L0 依赖另一个 L0,README 明令禁止),
  现在改成包内定义 `UpdateFeedTransport` 端口、由 App 组合根绑定 —— 与 `features/music` 的
  `MusicSourceBridge`、`foundation/sync` 的 `RemoteStore` 同一个做法:端口不是依赖。

## 5. 架构不变量(I1-I10)

| # | 不变量 |
|---|---|
| I1 | Provider 不知道播放器实现 |
| I2 | Player 不知道内容来源 |
| I3 | Feature 不解析第三方网站 |
| I4 | UI 不调用 Provider 内部实现 |
| I5 | Plugin 不允许绕过 Capability Contract |
| I6 | 所有可播放资源最终进入 MediaTicket |
| I7 | 跨业务数据统一使用 ContentRef |
| I8 | 插件权限最小化 |
| I9 | 每个 App 是自己进程的唯一 Composition Root;App 之间不共享组合根、不互相依赖 |
| I10 | Core 不依赖具体业务 |

## 6. 禁止清单

- 平台扩展链反向依赖:`TVBox Runtime → TV UI`、`LX Music Runtime → Music UI`、`Source → Player`、`Repository → GoRouter`、`Resolver → Widget`(平台基础设施禁令,见 [platform-infrastructure.md](platform-infrastructure.md);该链本身单向:External Runtime → Extension → Capability → Content)。
- Feature UI 直接调用第三方 API(I3)。
- Plugin 直接调用 PlayerAdapter(I1/I5)。
- `BilibiliHistory/DouyuHistory/MusicHistory` 这类平台前缀业务类型——历史/收藏/播放列表一律建在 ContentRef 上(见 [../services/history.md](../services/history.md))。
- 业务代码 `import fluttersdk_wind`(仅 ui_kit)/ 直接 import 厂商 SDK(仅 integrations)。
- JS 插件直接获得完整 HTTP 能力(只能走 PluginNetwork,见 [../security/network-security.md](../security/network-security.md))。
- 用 EventBus 替代正常接口依赖。
- App import 另一个 App(含 dev/test 依赖、路径依赖、fixture 共享)。要共享就下沉到 `packages/`。
- 保留没有 App 消费者的包。包的存在性由 [application-portfolio.md](application-portfolio.md) §3 的
  消费矩阵决定;空壳包让包数变成误导数字。
