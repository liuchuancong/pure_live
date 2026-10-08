# 依赖规则与架构不变量

> 护栏脚本 `tool/check_architecture.dart` 按本文机械校验;违反 = CI 失败。

## 1. 分层与方向

```text
L0 Foundation → L0.5 Integrations → L1 Ecosystem → L2 Services
→ L3 UI → L4 Features → App(组合根)
L5 Providers/Plugins(与 L2-L4 平级,只向下依赖)
```

严格单向,禁止任何反向依赖;`sources/plugins` 之间禁止互相依赖。

## 2. 包清单(81+)

| 层 | 包 |
|---|---|
| L0 Foundation | utils, logging, network, auth, storage, files, platform_info, **cache**, **events**, **diagnostics**, backup, sync, release, l10n |
| L0.5 Integrations | firebase(**保留**), media(media_core 接线) |
| L1 Ecosystem | plugin_api, plugin_host, plugin_registry, extension(gateway), resolver, identity, permission, task, capability, content, external_tvbox / lx_music / m3u / xmltv, theme, background, danmaku |
| L2 Services | search, history, favorites, playlist, links, feed, download, remote, cast, fonts, emote |
| L3 UI | design, ui_kit(唯一 import fluttersdk_wind), adaptive, lyric, player_ui |
| L4 Features | repository:live/vod/music/iptv/recorder/settings/search/home/account/backup;UI:live_ui/vod_ui/music_ui/iptv_ui/recorder_ui/settings_ui/account_ui/backup_ui/home_ui |
| L5 Providers | bilibili(live+vod 参考实现)、douyu、huya、douyin、twitch、youtube 等 33+ 站、music sources、tvbox adapters、iptv sources、第三方插件 |

目录形态:`packages/<层>/<短名>`,层 = `foundation/ integrations/ ecosystem/ services/ ui/ features/ providers/`;应用壳在 `apps/pure_live`,仓库根 `pubspec.yaml` 是 pub workspace hub。包名 `pure_live_<短名>`,目录用短名。形态决策见 [../adr/0015-monorepo-layout.md](../adr/0015-monorepo-layout.md)。

## 3. 逐层依赖细则

- **L0**:互不依赖,**唯一例外**是人人可用的叶子 `utils` 与 `logging`(任何包都可依赖它们,含 L0 内部);只依赖 pub.dev 三方。护栏 `tool/check_architecture.dart` 的 `kLeafPackages` 就是这条例外的白名单。
- **L0.5**:→ L0。
- **L1**:→ L0。
- **L2 services**:→ L0 + L1(plugin_api)。
- **L3 ui**:→ design 单向(ui_kit→design)+ L0 + theme。
- **L4 features**:repository → L0 + plugin_api + services;UI 包 → **本域 repository** + services + ui + ecosystem;同层禁互依。
- **L5 sources**:→ L0 + plugin_api(经 host 注入的沙箱桥);同层禁互依;**不得触碰 PlayerAdapter**。
- **app**:唯一全知层;其他任何包禁止依赖 app。

## 4. 显式例外清单(护栏白名单)

| 例外 | 理由 |
|---|---|
| danmaku → media | 弹幕时间轴跟播放器时钟 |
| background → media | 视频背景复用播放内核 |
| sync → firebase | 云同步数据面 |
| backup → auth | 同步凭据 |
| player_ui → media | 控制层需要播放状态 |

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
| I9 | App 是唯一 Composition Root |
| I10 | Core 不依赖具体业务 |

## 6. 禁止清单

- 平台扩展链反向依赖:`TVBox Runtime → TV UI`、`LX Music Runtime → Music UI`、`Source → Player`、`Repository → GoRouter`、`Resolver → Widget`(平台基础设施禁令,见 [platform-infrastructure.md](platform-infrastructure.md);该链本身单向:External Runtime → Extension → Capability → Content)。
- Feature UI 直接调用第三方 API(I3)。
- Plugin 直接调用 PlayerAdapter(I1/I5)。
- `BilibiliHistory/DouyuHistory/MusicHistory` 这类平台前缀业务类型——历史/收藏/播放列表一律建在 ContentRef 上(见 [../services/history.md](../services/history.md))。
- 业务代码 `import fluttersdk_wind`(仅 ui_kit)/ 直接 import 厂商 SDK(仅 integrations)。
- JS 插件直接获得完整 HTTP 能力(只能走 PluginNetwork,见 [../security/network-security.md](../security/network-security.md))。
- 用 EventBus 替代正常接口依赖。
