# 设置与配置归属地图（§13 审计）

> 依据《PureLive v4 产品级设计与工程开发标准》§13.1–§13.6。本轮只做静态审计与归类，
> 未改任何配置类；结论以源码为准，真实交互仍需运行验证。

## 1. 现状：配置类与规模

| 类 | 文件 | 字段 | 归属 | 存储前缀 | 恢复默认 |
|---|---|---:|---|---|---|
| `PlaybackSettings` | `features/settings/playback/playback_settings_providers.dart` | ~25（record） | 全局播放 | `playback.*` | 部分键逐项重置，无整组重置 |
| `MusicSettings` | `modules/music/controller/music_settings.dart` | 46 | 音乐模块 | `music.*` | 无整组重置 |
| `RecordingSettings` | `modules/live/recorder/data/recording_settings.dart` | 30 | 录制模块 | `recording.*` | 有（页头） |
| `BackgroundSettings` | `app/background/settings/background_settings.dart` | 19 | 全局外观 | `background.*` | 有 |
| `HongguoSettings` | `modules/hongguo/controller/hongguo_settings.dart` | 1（其余在 `hongguo_danmaku.dart`） | 红果模块 | `hongguo.*` | 弹幕页有 |
| `IptvBrowseSettings` | `modules/iptv/controllers/iptv_browse_settings.dart` | 4 | IPTV 模块 | `iptv.*` | 无 |
| `VodPlaybackSettings` | `modules/vod/controller/vod_playback_settings.dart` | 3 | 点播模块 | `vod.*` | 无 |

另有 26 个 `*Settings`/`*Controller` 型 Notifier（弹幕样式、房间卡片、站点显示、代理、WebDAV、
日志、同步服务等），按模块划分，未混入上述大类。

## 2. 逐条核对（§13）

- **§13.1 配置范围**：全局（播放、外观）、模块（音乐、录制、红果、IPTV、点播）、页面偏好
  （`playback.chatCollapsed` 房间聊天列折叠）、任务配置（下载队列行）、临时 UI 状态（搜索词、
  面板展开）各自有归属；唯一的页偏好混在模块类里的是 `chatCollapsed`，影响仅限直播间。
- **§13.3 设置项定义**：每个键都有默认值与有效范围（`kPreferredResolutionChoices`、
  `DanmakuStyleRange`、`HistoryLimitController.choices` 等提供回退）；`settings-key-disposition.md`
  记录键的读写点，备份与刷新由两道门禁（`check_prefs_manifest.ps1`）强制。
- **§13.4 控件选择**：连续值（字号、透明度、音量）走 Slider + 数值 detail；离散少量选项走
  `SettingsChoiceRow`/下拉；路径走目录选择；颜色走取色器 + 预设；样式类走实时预览（歌词、桌面歌词、
  房间卡片、背景）。未发现「互斥选项用开关」或「固定档位用滑杆」的实例。
- **§13.6 变更副作用**：扫描全部 `build()` 方法，**零处**持久化写入（`StoragePrefs.` /
  `ThemePersistence.store`）；多窗口写入由 prefs 桥接 + 修订号刷新；无效值有回退；
  导入/恢复见备份模块。
- **§13.5 配置模型拆分（欠账）**：`MusicSettings`（46 字段）与 `RecordingSettings`（30 字段）
  在规模上触及「万能配置类」红线，见下节。

## 3. 拆分计划（未实施，按批次）

P1 · 音乐：`MusicSettings` 按职责拆成
`MusicPlaybackSettings`（模式、自动下一首、结束行为、速度、淡入淡出、音量记忆）、
`MusicLyricsSettings`（字号、对齐、放大、翻译/音译、简繁、偏移、进度、自动滚动）、
`MusicDesktopLyricsSettings`（字号、颜色、描边、透明度、行距、对齐、竖排、粗体）、
`MusicUiSettings`（视图记忆、面板状态）。键名与备份键**保持不变**，只改代码分组，
迁移成本为零；设置页与播放器按组分读。

P1 · 录制：把 `RecordingSettings` 的调度字段（`scheduleEnabled` 等）与网络字段
（代理、CA、超时）拆成子组，保持 flat key。

P2 · 页面偏好：`playback.chatCollapsed` 迁到直播间自己的偏好 provider（新键 + 旧键一次性迁移）。

原则：拆分不是目的——只有在字段继续增长、或跨职责修改频繁时才做；本次只记录，不改代码。

## 4. 与门禁的关系

- `tool/check_prefs_manifest.ps1`：键 ↔ 备份 ↔ 刷新清单；本轮未增删键，通过（363/348/124）。
- `tool/check_settings_ia.ps1`：设置页/分区/命中的归属；本轮未改设置页，通过（75/61/305）。
- 拆分执行时两道门禁必须继续通过，且旧键的备份不能断（用户恢复备份后设置仍要生效）。
