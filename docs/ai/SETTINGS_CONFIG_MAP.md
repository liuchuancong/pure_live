# 设置与配置归属地图（§13 审计）

> 依据《PureLive v4 产品级设计与工程开发标准》§13.1–§13.6。本轮只做静态审计与归类，
> 未改任何配置类；结论以源码为准，真实交互仍需运行验证。

## 1. 现状：配置类与规模

| 类 | 文件 | 字段 | 归属 | 存储前缀 | 恢复默认 |
|---|---|---:|---|---|---|
| `PlaybackSettings` | `features/settings/playback/playback_settings_providers.dart` | 28 → 27（record，`chatCollapsed` 已迁出，见轮次 35） | 全局播放 | `playback.*` | 部分键逐项重置，无整组重置 |
| `MusicSettings` | 轮次 33 已拆分为 4 组类（`music_playback_settings.dart` 等） | 46 → 13+11+12+10 | 音乐模块 | `music.*`（键未变） | 各组 `reset()` 保留原语义 |
| `RecordingSettings` | `modules/live/recorder/data/recording_settings.dart` | 30 → 22 + schedule/network 子组 | 录制模块 | `recording.*`（键未变） | 有（页头） |
| `BackgroundSettings` | `app/background/settings/background_settings.dart` | 19 | 全局外观 | `background.*` | 有 |
| `HongguoSettings` | `modules/hongguo/controller/hongguo_settings.dart` | 1（其余在 `hongguo_danmaku.dart`） | 红果模块 | `hongguo.*` | 弹幕页有 |
| `IptvBrowseSettings` | `modules/iptv/controllers/iptv_browse_settings.dart` | 4 | IPTV 模块 | `iptv.*` | 无 |
| `VodPlaybackSettings` | `modules/vod/controller/vod_playback_settings.dart` | 3 | 点播模块 | `vod.*` | 无 |

另有 26 个 `*Settings`/`*Controller` 型 Notifier（弹幕样式、房间卡片、站点显示、代理、WebDAV、
日志、同步服务等），按模块划分，未混入上述大类。

## 2. 逐条核对（§13）

- **§13.1 配置范围**：全局（播放、外观）、模块（音乐、录制、红果、IPTV、点播）、页面偏好
  （`danmaku.chatCollapsed` 房间聊天列折叠，直播间自有）、任务配置（下载队列行）、临时 UI 状态（搜索词、
  面板展开）各自有归属；曾混在全局 `PlaybackSettings` 里的页偏好 `chatCollapsed` 已迁出（轮次 35，
  旧键一次性采纳并退役）。
- **§13.3 设置项定义**：每个键都有默认值与有效范围（`kPreferredResolutionChoices`、
  `DanmakuStyleRange`、`HistoryLimitController.choices` 等提供回退）；`settings-key-disposition.md`
  记录键的读写点，备份与刷新由两道门禁（`check_prefs_manifest.ps1`）强制。
- **§13.4 控件选择**：连续值（字号、透明度、音量）走 Slider + 数值 detail；离散少量选项走
  `SettingsChoiceRow`/下拉；路径走目录选择；颜色走取色器 + 预设；样式类走实时预览（歌词、桌面歌词、
  房间卡片、背景）。未发现「互斥选项用开关」或「固定档位用滑杆」的实例。
- **§13.6 变更副作用**：扫描全部 `build()` 方法，**零处**持久化写入（`StoragePrefs.` /
  `ThemePersistence.store`）；多窗口写入由 prefs 桥接 + 修订号刷新；无效值有回退；
  导入/恢复见备份模块。
- **§13.5 配置模型拆分（已还清，轮次 33）**：`MusicSettings`（46 字段）拆成 4 个组 provider，
  `RecordingSettings`（30 字段）拆出 schedule/network 子组；键名与备份键保持不变，见第 3 节。

## 3. 拆分计划（P1 已实施，见轮次 33；P2 已实施，见轮次 35）

P1 · 音乐（✅ 轮次 33 已实施）：`MusicSettings`（46 字段）按职责拆成 4 个组 provider，
设置页与播放器按组分读（`build()` 只 watch 自己组的 provider，重建范围随之收窄）：

- `MusicPlaybackSettings`（13 字段：默认源、音质、自动播放、错误跳过、进度记忆、音量、倍速、
  音调保持、已播清理、置顶、显示来源、热搜）→ `music_playback_settings.dart`
- `MusicLyricsSettings`（11 字段：翻译/音译、对调、简繁、逐词、字号、对齐、放大、进度、拖拽、偏移）
  → `music_lyric_settings.dart`
- `MusicDesktopLyricsSettings`（12 字段：桌面歌词开关/锁定、字号、颜色、描边、透明度、行距、
  竖排、粗体、对齐）→ `music_desktop_lyric_settings.dart`
- `MusicDownloadSettings`（10 字段：容器、命名模板、并发、跳过已存在、封面/歌词写入）→
  `music_download_settings.dart`（计划修正：原计划清单漏列了下载组，实施时补上）
- `MusicUiSettings` 原本已独立存在于 `music_ui_settings.dart`，本轮未动

键名与备份键**保持不变**（旧 flat key 原样读写），零迁移；备份恢复后设置照常生效。
`musicSettingsProvider` 从刷新清单 `kSettingsProviders` 换成 4 个组 provider（+3）。

P1 · 录制（✅ 轮次 33 已实施）：`RecordingSettings`（30 字段）拆出两个子组 record——
`RecordingScheduleSettings`（轮询开关/间隔/退避/上限/开机自启）与 `RecordingNetworkSettings`
（读超时、TLS 校验、CA 路径），`RecordingSettings` 本体保留其余 22 字段并以
`schedule`/`network` 字段挂子组。控制器 getter/setter 保持原名、内部路由到子组，引擎、
监视器与设置页的调用点基本不动；`reset()` 语义逐字段保留（网络可调项重置、CA 路径保留）。

P2 · 页面偏好（✅ 轮次 35 已实施）：`playback.chatCollapsed` 迁到直播间自己的
`chatCollapsedProvider`，新键 `danmaku.chatCollapsed` 与 `chatPanelWidthProvider` 同族同文件
（`chat_display_settings.dart`）。一次性迁移沿用 `storage_folder_provider.dart` 的「采纳并退役」先例：
首次读取缺新键时按字面读旧键 `playback.chatCollapsed` 作为初值，`unawaited` 写入新键后
`StoragePrefs.remove` 旧键，此后只从一个键读；旧键保留在备份清单，老备份恢复出的旧键由下次启动的
采纳逻辑接力。`PlaybackSettings` 28→27 字段（记录/默认值/读取/copyWith/setter 六处移除），
新 provider 进失效清单 `kSettingsProviders`（127→128 的 +1）。

原则：拆分不是目的——只有在字段继续增长、或跨职责修改频繁时才做。

## 4. 与门禁的关系

- `tool/check_prefs_manifest.ps1`：键 ↔ 备份 ↔ 刷新清单。拆分后通过：
  **363 prefs keys / 348 backup entries / 127 invalidations**（键与备份集合与拆分前完全一致，
  失效提供者 -1+4=+3）。
- `tool/check_settings_ia.ps1`：设置页/分区/命中的归属。拆分后通过（75 sections / 61 pages /
  305 search hits，行结构未动）。
- 拆分执行时两道门禁必须继续通过，且旧键的备份不能断（用户恢复备份后设置仍要生效）——已满足。
