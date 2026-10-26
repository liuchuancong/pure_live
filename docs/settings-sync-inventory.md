# 设置全量同步清单（参考 `pure_live-master`）

> **逐项审查请用 [`settings-review-checklist.md`](settings-review-checklist.md)**：一行一个设置，含参考位置、默认值、消费点、现状，共 263 项；本文件只保留页面级结构和分批计划。
>
> 参考：`C:\Users\m1779\Downloads\pure_live-master\pure_live-master`
> 对象：`apps/pure_live` 的设置面
> 原则：一个控件 = 一条设置；每条必须落到持久化键、真实消费点和可验证行为。
> 状态：✅ 已对齐；◐ 已有但字段/逻辑不全；○ 缺失；➖ 平台不适用/暂缓（写明原因）。

## 0. 参考的设置入口

参考 `features/settings/settings_page.dart` 的入口分组（10 组 + 配置预览）：

| 组 | 入口 | 参考页面 |
| --- | --- | --- |
| 主题 | 主题自定义 / 背景 | `theme_settings_page.dart` / `wallpaper_page.dart` |
| IPTV | IPTV 设置 | `iptv_page.dart` |
| 刷新 | 刷新设置 | `refresh_settings_page.dart` |
| 视频 | 视频 | `video_settings_page.dart` |
| 播放器内核 | 播放器内核 | `player_kernel_settings_page.dart` |
| 网络代理 | 自定义网络代理 | `network_proxy_settings_page.dart` |
| 本机互动 | 本机互动 | `local_interaction_settings_page.dart` |
| 通用 | 通用 / 导航显示 / 平台 | `general_settings_page.dart` / `navigation_settings_page.dart` / `platform_settings_page.dart` |
| 数据 | 缓存与数据 | `cache_data_settings_page.dart` |
| 备份 | 备份与恢复 | `backup_page.dart` |
| 页头 | 配置预览 | `local_config_preview_page.dart` |

另有从其它页面进入的设置：视频 → 竖屏直播 / 观众指标 / 弹幕字体 / 弹幕过滤；主题 → 页面 / 房间卡片 / 字体 / 加载样式 / 文本大小；播放器内核 → 预设 / 超分 / mpv 选项 / 指南。

### 与我们现有 IA 的关系

现有分类保留（个性化 / 直播 / 播放 / 系统 / 关于 + 模块专属），把参考页面挂到对应分类：

- 个性化：主题、外观、背景（含随机图源）、页面、导航、房间卡片、字体、加载样式。
- 直播：直播资源、刷新、弹幕、屏蔽、竖屏直播、录制。
- 播放：播放偏好、视频、播放器内核、网络代理（播放器部分）。
- 系统：通用、窗口、平台、本机互动、网络代理、数据与缓存、备份、配置预览、关于。
- IPTV / Bilibili：保留既有专属分区。

### 覆盖量化（按参考页的独立控件键粗略计数）

| 参考页 | 控件键 | 当前概略 | 主要缺口 |
| --- | ---: | --- | --- |
| 主题 | 34 | ◐ 约 14 | 加载样式、字体管理、页面/房间卡片入口、文本大小 |
| 通用/窗口 | 47 | ◐ 约 15 | 开机启动、更新源 |
| 页面 | 17 | ◐ 约 2 | 分页条三项开关、页大小选项管理 |
| 导航 | 8 | ◐ 约 2 | 首页菜单显示/排序、至少保留一项 |
| 平台 | 11 | ◐ 约 4 | 第三方授权、标签管理 |
| 刷新 | 17 | ◐ 约 3 | 并发刷新、缩略图刷新与频率 |
| 视频 | 61 | ◐ 约 6 | 音量分档、蜂窝清晰度、后台播放、ASMR、PiP 6 项、全屏默认、常亮、退出浮窗 |
| 播放器内核 | 51 | ◐ 约 40 | 一键预设入口、平台选项表逐项核对、重置语义、指南深度 |
| 弹幕 | 约 30 | ◐ 约 10 | 模板/保存、边距、字重/字距、最大同屏、海量、小窗缩放、FPS、折叠、相似度过滤 |
| 房间卡片 | 35 | ○ | 双目标、预设、可见性、平台角标、圆角、布局、预览 |
| 竖屏直播 | 39 | ○ | 检测/高度/布局/全屏策略/画面模式/弹幕模式/房间覆盖/诊断/重置 |
| 观众指标 | 6 | ✅ | 4 档显示、真实在线优先、每平台开关、热度/累计说明 |
| 字体 | 17 + 23 | ◐ 约 1 | 五档字族、字体下载/应用/删除、字重锁定 |
| 加载样式 | 4 | ○ | 样式、颜色、恢复默认 |
| 本机互动 | 23 | ○ | 本机服务、浮层、资料、礼物动效、经验经济 |
| 网络代理 | 10 | ◐ 约 3 | App/播放器两组归一化、端口校验、连接重建 |
| 缓存与数据 | 22 | ◐ 约 8 | 缩略图刷新、下载目录、清理确认细节 |
| 配置预览 | — | ○ | 完整 JSON + 复制 |
| 背景 | — | ✅ | 图库/视频/纯色/渐变/设备/随机图源、预览 |
| IPTV/录制/备份/账号/WebDAV/远程 | — | ✅/◐ | 逐字段复核 |


## 1. 逐页控件清单

### 1.1 主题 `theme_settings_page.dart`（34 键）

| 控件键 | 类型/默认 | 参考存储/消费 | 现状 |
| --- | --- | --- | --- |
| `change_theme_mode` | 跟随系统 / 浅色 / 深色；默认 System | `themeMode`；Get.changeThemeMode | ◐ 有模式切换，无动态取色 |
| `change_theme_color` | 任意颜色 / 预设色 | `themeColorSwitch`；重建 Theme | ◐ 只有固定 seed，无任意取色 |
| `enable_dynamic_color` | 开关；默认 false（Android 12+） | `enableDynamicTheme`；dynamic_color | ✅ 动态调色板 seed（`theme.dynamicColor`） |
| `change_loading_style` | 打开加载样式页 | `loadingStyle` + `loadingStyleColorSwitch` | ◐ 外观页内画廊：10 种内置动画（85 种需动画包） |
| `room_card_settings` | 打开房间卡片页 | `roomCard.*` | ○ |
| `grid_spacing_settings` | 交叉/主轴间距，0–64，默认 6 | `crossAxisSpacing` / `mainAxisSpacing`；网格 | ◐ 有间距项，位置在通用；无独立主题分组 |
| `page_settings` | 打开分页设置页 | `page.*` | ○ |
| `change_language` | 语言选择 | `language`；slang/Get locale | ✅ 有语言选择 |
| `change_font_family` | 打开字体管理器 | `fontFamily.*` | ◐ 只有系统默认/平台字体 |
| `text_size_settings` | 5 档字体大小 | `font_*`；标题/正文 | ○ |
| 圆角/对比度/选中样式/撞色 | 现有外观项 | 现有 | ✅（参考在主题页的不同组织方式） |

### 1.2 通用 `general_settings_page.dart`（47 键）

| 控件键 | 类型/默认 | 参考存储/消费 | 现状 |
| --- | --- | --- | --- |
| `refresh_rate_mode` | 节能 / 均衡 / 性能；默认节能 | `refreshRateMode`；Android `AdaptiveRefreshRateController`，Windows 显示器信息 | ○ |
| `windows_dynamic_refresh_rate` | 信息行（当前/最高 Hz） | 原生 runner / `DisplayModeService` | ○ |
| `open_new_window` | 开关；默认 true | `enableNewWindowPlay`；房间在新窗口打开 | ○ |
| `splash_animation` | 开关；默认 true | `showSplashPage`；启动页 | ○ |
| `enable_auto_check_update` | 开关；默认 true | `enableAutoCheckUpdate`；版本检查调度 | ◐ 有版本检查，无自动检查开关 |
| `use_github_origin_for_updates` | 开关；默认 false | `useGitHubOriginForUpdates`；版本源 | ○ |
| `enable_countdown_close` | 开关；默认 false | `exit.*`；关闭倒计时 | ○ |
| `countdown_duration` | 5–120 分钟/自定义 | `exit.countdownSeconds`；退出拦截 | ○ |
| `startup` | 开机启动/托盘等 | `startup.*`；原生启动注册 | ○（平台相关） |
| `window_size` | 预设 1080×720 / 自定义；范围校验 | `windowSize.*`；WindowManager | ○ |
| `no_exit_confirm` | 开关；默认 false | `exit.skipConfirmation` | ◐ 有退出行为选择，无“跳过确认” |
| `general` 中的网格/卡片/分页 | 现有卡片宽度、每页数量、间距 | 现有 | ✅ |

### 1.3 页面 `page_settings_page.dart`（17 键）

| 控件键 | 类型/默认 | 参考存储/消费 | 现状 |
| --- | --- | --- | --- |
| `show_page_size_selector` | 开关；默认 true | `page_show_size_selector`；分页条 | ◐ 分页层已有，开关未暴露 |
| `show_goto_button` | 开关；默认 true | `page_show_goto_button`；分页条 | ◐ 同上 |
| `show_scroll_to_top` | 开关；默认 true | `page_show_scroll_top`；列表回顶 | ◐ 同上 |
| `default_page_size` | 桌面 20 / 手机 12 | `page_default_size` | ◐ 默认值在通用页 |
| `page_size_options_manage` | 选项 [20,40,60,80] / [12,24,36,48]；可增删 1–100 | `page_size_options_raw` | ○ |
| `adaptive_recommend` | 由宽度推荐选项 | 计算值 | ○ |

### 1.4 导航显示 `navigation_settings_page.dart`（8 键）

| 控件键 | 类型/默认 | 参考存储/消费 | 现状 |
| --- | --- | --- | --- |
| `multiview_title` / `favorites_title` / `popular_title` / `areas_title` / `record_center` | 5 个入口开关；至少保留一个 | `savedMenuIds`；首页菜单/侧栏 | ◐ 只有多画面开关和工具栏排序 |
| `drag_menu_to_sort_tip` | 拖动排序 | `savedMenuIds` 顺序 | ○ |
| `tools_order` | 工具栏顺序 | 参考在通用/导航 | ✅（现有工具排序） |

### 1.5 平台 `platform_settings_page.dart`（11 键）

| 控件键 | 类型/默认 | 参考存储/消费 | 现状 |
| --- | --- | --- | --- |
| `platform_display` | 平台显示/隐藏/排序 | 平台注册表 + prefs | ✅/◐ 有显示、排序 |
| `prefer_platform` | 首选平台下拉，支持筛选 | `preferPlatform`；房间/搜索 | ✅ |
| `third_party_auth` | 第三方授权开关 | `thirdPartyAuth.*`；登录 | ○ |
| `tag_management` | 热门标签管理 | `tags.*`；分区页 | ◐ 有标签页，设置入口/编辑待核 |
| `platform_filter` | 平台筛选空态 | 显示层 | ◐ |

### 1.6 刷新 `refresh_settings_page.dart`（17 键）

| 控件键 | 类型/默认 | 参考存储/消费 | 现状 |
| --- | --- | --- | --- |
| `auto_refresh_follow` | 开关；默认 false | `autoRefreshFavorite`；关注页 | ✅ |
| `refresh_follow_on_resume` | 开关；默认 true | `refreshFavoriteOnResume` | ✅ |
| `auto_refresh_interval` | 5–360 分钟；默认 30 | `autoRefreshInterval` | ✅（现有单位/范围待核） |
| `max_concurrent_refresh` | 1–20，默认 4 | `maxConcurrentRefresh`；刷新队列 | ○ |
| `auto_refresh_thumbnails` | 开关；默认 false | `autoRefreshThumbnails` | ○ |
| `thumbnail_refresh_interval` | 5–360；默认 30 | `thumbnailRefreshInterval` | ○ |

### 1.7 视频 `video_settings_page.dart`（61 键）——当前最大缺口

| 分组/控件键 | 类型/默认 | 参考存储/消费 | 现状 |
| --- | --- | --- | --- |
| `global_mute` | 开关；默认 false | `globalVolumeMute`；音量管理 | ○ |
| `mobile_default_volume` / `desktop_default_volume` | 0–100%；0.5 / 1.0 | `defaultMobileVolume` / `defaultDesktopVolume` | ◐ 单音量，无平台分档 |
| `prefer_resolution` | 原画/蓝光8M/蓝光4M/超清/流畅；默认原画 | `preferResolution`；`_setDefaultResolution` | ◐ 有清晰度枚举，缺蜂窝分档 |
| `mobile_quality` | 同上；移动网络 | `preferResolutionCellular` | ○ |
| `portrait_live_settings` | 跳转竖屏直播 | — | ○ |
| `audience_metric_settings` | 跳转观众指标 | — | ✅ 播放 → 画面入口，独立观众指标页 |
| `enable_background_play` | Android 开关；默认 false | `app.enableBackgroundPlay`；`LiveAudioService` | ○（需后台音频服务） |
| `asmr_sleep_mode` + `asmr_sleep_timer` | 开关 + 15…1440 分钟；默认 60 | `app.enableAsmrSleepMode` / `asmrSleepMinutes`；睡眠定时 | ○ |
| `exit_float_window` | 开关；默认 false | `floatPlay`；返回时浮窗 | ○ |
| `windows_pip_always_on_top` | Windows 开关；默认 false | `windowsPipAlwaysOnTop`；PiP 驱动 | ○ |
| `windows_pip_remember_position` | 开关；默认 true | `window.rememberPipPosition` | ○ |
| `windows_pip_base_size` | 200–720，默认 360 | `windowsPipBaseSize` | ○ |
| `windows_pip_min_width` / `min_height` | 100–320 / 60–240；140 / 90 | `windowsPipMinWidth/Height` | ○ |
| `windows_pip_free_aspect` | 开关；默认 false | `windowsPipFreeAspect` | ○ |
| `windows_pip_reset_position` | 确认动作 | 清除 PiP 几何 | ○ |
| `enable_fullscreen_default` | 开关；默认 false | `app.enableFullScreenDefault` | ○ |
| `enable_screen_keep_on` | 开关；默认 true | `app.enableScreenKeepOn`；wakelock | ○ |
| `show_danmaku` | 反选开关；默认显示 | `danmaku.hideDanmaku` | ✅/◐ 有弹幕开关 |
| `change_danmaku_font_family` | 打开字体管理器 | `danmakuFontFamily*` | ○ |
| `danmaku_filter` | 打开屏蔽页 | 屏蔽关键字/相似度 | ◐ 有关键字页 |

### 1.8 播放器内核 `player_kernel_settings_page.dart`（51 键）

现有 `player_kernel_pane.dart` 已覆盖大部分：内核切换、播放器代理、硬解/解码器、强制销毁、6 预设、Anime4K 三档、vo/ao/video-sync/interpolation/scale/deinterlace/hwdec-codecs/audio-exclusive、恢复默认、mpv 文档、指南。

待逐项核对：

| 控件/行为 | 参考细节 | 现状 |
| --- | --- | --- |
| `kernel_switch` | 手机 mpv/ijk/exo；桌面 mpv；默认 mpv；归一化 | ✅ |
| `network_proxy` | 播放器独立 proxy，host 归一化/端口校验 | ✅（样式/校验待核） |
| `enable_codec` | 默认 true；关闭后强制 hwdec=no | ✅ |
| 预设 one-click / compat | 均衡一键 + Android 兼容修复，确认框 | ◐ 均衡一键（KER-05）已接入；Android 兼容一键待 KER-06 |
| `force_destroy_player` | 参考只存不消费（装饰） | ✅ 我们用于 teardown，按真实逻辑保留 |
| `custom_output_hwdec` | 控制 vo/hwdec/ao 是否下发；变更重建引擎 | ✅ 自定义输出开启才下发所选 vo/hwdec/ao（hwdec 接管硬解开关），关闭时 hwdec 由硬解开关决定 auto-safe/no；直播间/IPTV/VOD/多画面均接 tuning 监听并在输出变化时重建（KER-09） |
| 所有 mpv 选项平台表 | Windows/Android/iOS/macOS/Linux 选项不同；默认 auto/lanczos/audio 等 | ✅/◐ 需逐平台核对 |
| `reset` | 只重置部分字段（参考语义） | ◐ 我们的恢复默认范围可能不同，需逐项定义 |
| `player_guide` | 6 章完整指南 | ◐ 现有提示简短 |

### 1.9 弹幕（视频页入口 + `danmaku_settings_page`）

参考约 30 项，核心：

- 模板：最佳/舒适/密集/默认；保存/恢复模板（JSON v2，范围校验）。
- 显示：无表情、显示区域、上/下边距、透明度、最大同屏数、速度、字号、字重、字间距、实时/海量模式、描边开关、描边宽度、自动 FPS 开关 + 手动 30–240、重复折叠 + 窗口 1–30s。
- 交互：点按/长按动作开关、同屏样式迁移。
- 小窗：自动缩放开关 + 0.4–1.0 手动值。
- 过滤：斗鱼疑似机器人过滤、相似度过滤开关、阈值 50–100/默认 85、缓存 1–60s/默认 3、最大缓存 20–1000/默认 100、关键字列表。
- 现有：屏蔽关键字/用户、字号/速度/区域/透明度/描边/恢复默认、小窗开关。

状态：◐（约三分之二字段缺失）。

### 1.10 竖屏直播 `portrait_live_settings_page.dart`（39 键）

| 控件 | 默认 | 参考消费 | 现状 |
| --- | --- | --- | --- |
| `portrait_smart_detection` | true | 竖屏策略刷新 | ○ |
| `portrait_adaptive_height` | true | 房间布局高度 | ○ |
| `portrait_layout_mode` | balanced / immersive / compatibility | PresentationDensityMode | ○ |
| `portrait_fullscreen_policy` | followSource / followSystem / landscape | 全屏方向 | ○ |
| `portrait_fullscreen_display_mode` | complete / ambient / balanced / cover | 全屏画面模式 | ○ |
| `portrait_pip_follow_source` | true | 参考无消费（仅存） | ➖ 参考自身未接线，暂不同步 |
| `portrait_danmaku_mode` | followGlobal / upperQuarter / reduced / hidden | 弹幕区域裁剪 | ○ |
| `portrait_remember_room_override` | true | 房间级覆盖记忆（上限 300） | ○ |
| `portrait_show_diagnostics` | false | 调试浮层 | ○ |
| `portrait_reset_settings` | — | 重置以上并清房间覆盖 | ○ |

### 1.11 房间卡片 `room_card_settings_page.dart`（35 键）

- 目标：手机 / 桌面分别配置；预设：紧凑 / 标准 / 详细 / 自定义；重置当前目标。
- 可见内容：头像、主播名、观众数、回放角标。
- 平台角标：自动 / 总是 / 隐藏；与 `automaticPlatformBadge` 互斥。
- 外观：圆角 0–32；布局 cover / compact。
- 预览：实时预览卡片，锚点信息。
- 存储：`room_card_{mobile,desktop}_preset` + `room_card_{mobile,desktop}_config`；消费：热门/关注/历史/录制卡片。
现状：○（可能只有观众指标）。

### 1.12 观众指标 `audience_metric_settings_page.dart`（6 键）

- 展示模式：跟随平台 / 在线 / 热度 / 累计（`browse.audienceMetric`，原先在浏览页，现移入独立观众指标页）。
- 每平台「真实在线」开关 + 真实在线人数优先（`browse.preferRealOnline` / `browse.realOnlinePlatforms`，默认 8 平台；能力表见 `live_sites` 的 `LiveAudienceCapability`），只列出公开提供并发人数的平台；其余平台在「仅热度或累计观看」组说明。
- 标题下方的排序规则说明、未开放来源说明。
- 迁移：参考的 `audienceMetricMigration` 无需落地——默认集合已包含历次补入的平台，读取时按能力表归一化。
现状：✅（显示/排序消费点：热门与关注卡片、热门页「按观众」排序；备份、搜索、刷新齐全）。

### 1.13 字体 `font_settings_page.dart`（17 键）+ 字体管理（23 键）

- 正文 small/medium/large、标题 medium/large 的字族选择；恢复默认确认。
- 字体管理器：默认字体 / 云字体分组；下载、应用、删除；当前激活；失败提示；弹幕字体专用入口；字重自动/锁定。
- 存储：`fontFamily.*`、`danmakuFontFamily*`；消费：ThemeData textTheme、弹幕渲染。
现状：◐（仅一个字体族选项）/ ○（管理器）。

### 1.14 加载样式 `loading_style_settings_page.dart`（4 键）

- 样式选择（AppConsts.loadingStyleKeys）、加载颜色、恢复默认。
- 消费：启动/页面加载组件。
现状：○。

### 1.15 本机互动 `local_interaction_settings_page.dart`（23 键）

- 开关、本机平台包、用户资料（昵称/头衔）、浮层消息、平台角标、等级角标、礼物动效、互动状态、弹幕样式、经验经济、清空历史。
- 这是一个本机互动子系统（本地 HTTP/WebSocket + 浮层），不是单纯偏好。
现状：○（需先确认产品范围）。

### 1.16 网络代理 `network_proxy_settings_page.dart`（10 键）

- App 代理：enable/host/port；播放器代理：enable/host/port；端口归一化（全角字符、数字校验）；代理变更重建连接。
- 参考在同一页分两组；我们现有 App 代理在「网络」，播放器代理在「播放器内核」。
现状：◐（代理逻辑已有，分组/校验/重建待统一）。

### 1.17 缓存与数据 `cache_data_settings_page.dart`（22 键）

- 当前缓存大小、刷新缩略图、清理本地缓存（确认）、下载目录选择/重置/权限提示。
- 目前有：历史限制/清空、关注导入导出、封面缓存大小/上限/清除。
缺失：缩略图刷新、下载目录、清理范围确认细节。

### 1.18 配置预览 `local_config_preview_page.dart`（297 行）

- 展示当前完整配置 JSON，支持复制；参考页头有入口。
现状：○。

### 1.19 背景 `wallpaper_page.dart` + 域

- 参考入口：显示项（填充/遮罩/模糊/清除）、来源（纯色、动态视频、图库、随机 API）、设备（图片/视频上传、URL）。
- 随机 API：7 组 82 源，JSON/direct/alcy 三种请求形态，取字节、魔数校验、落盘、全屏预览 +“换一张” + 应用。
- 图库：4 图片源、分类、分页、预览；动态视频源。
现状：✅ 图库/视频/纯色/渐变/设备 + **随机图源（本轮新增）**；分布选项已有。

### 1.20 其它域

| 域 | 参考控件/键 | 现状 |
| --- | --- | --- |
| IPTV 自动同步 | `auto_sync_title/desc`、`sync_interval_title`（小时）、`epg_source_switched`、`active_epg_source`、`select_epg_source` | ◐ 有间隔/自动更新/批量同步；EPG 源切换与状态待核 |
| IPTV 导入/管理 | `import_playlist`、`import_epg_source`、`local_import`、`network_import`、`download_guide_sub`、`custom_ua_title`、`iptv_list_manage`、`edit_ua_title` | ◐ 来源管理/导入已有；自定义 UA、网络导入细节待核 |
| 录制基础 | `default_record_quality`、`use_pinyin_folder`、`record_danmaku`、`storage_directory`、`auto_start_boot` | ◐ 目录/命名/质量已有，拼音目录/开机启动/录弹幕待核 |
| 录制存储 | `enable_cache_limit`、`cache_limit`、`current_cache_size`、`clear_all_cache` | ✅ 开关默认 false、上限默认 1024 MB（1 MB 起）、受管 PureLiveRecords 目录、当前大小只读、确认清理；录制前/结束/每分钟/设置变更按最旧文件裁剪，活跃录制永不删除 |
| 录制流参数 | `prefer_best_stream`、`rw_timeout`、`queue_size`、`segment_duration`、`max_record_tasks` | ◐ 大部分已有，逐项核消费 |
| 录制重连 | `auto_reconnect`、`max_retry_count`、`retry_delay`、`enable_polling`、`check_interval`、`enable_backoff`、`max_check_interval` | ◐ 有重试/轮询，字段名/默认值需对齐 |
| 备份 | Firebase 云备份（账号/连接）、WebDAV、远程同步 TV、本地备份/恢复、备份目录、日志目录与开关 | ◐ 本地/WebDAV/远程已有；Firebase 是新依赖，需用户决策（默认不做） |
| 账号 | Cookie 编辑、登录状态、斗鱼续期 | ✅/◐ |

## 2. 差距排序（按影响）

1. **视频/播放行为**：20+ 控件（PiP 几何、全屏、后台播放、ASMR、屏幕常亮、蜂窝清晰度）——直接影响播放体验。
2. **弹幕**：约 20 项渲染/交互/过滤字段——参考的完整弹幕能力。
3. **房间卡片**：8 个可见性 + 外观 + 手机/桌面两套配置——首页和关注页的观感。
4. **主题/字体/加载样式**：静态外观与启动体验。
5. **通用/窗口/启动/退出**：窗口大小、启动页、关闭倒计时、刷新率、更新源。
6. **页面/导航**：分页条控制、首页菜单显示/排序。
7. **竖屏直播**：竖屏房间的完整呈现策略。
8. **本机互动**：独立子系统，先确认边界。
9. **缓存/数据/配置预览**：补齐动作与可视化。
10. **平台/刷新/代理**：补齐高级字段与校验。

## 3. 同步批次（一次一批，做完验证再下一批）

### 批 1：房间卡片 + 页面 + 导航（纯 Flutter，先做）
- 新增房间卡片设置（mobile/desktop 双目标、预设、可见性、平台角标、圆角、布局、预览）。
- 把现有分页层的“每页数量/跳页/回顶”暴露为页面设置；页大小选项管理（1–100，去重排序）。
- 首页菜单显示/排序 + 至少保留一个；与现有工具排序统一。
- 消费点：`RoomCard`/`FollowedRoomCard`/历史卡、分页条、桌面侧栏/手机菜单。
- 验收：切换任一开关，卡片/分页条/菜单立即变化；重启保持；备份包含。

### 批 2：通用 + 窗口 + 配置预览（纯 Flutter，平台能力分层）
- 窗口大小（预设/自定义/校验）、启动页开关、打开新窗口、关闭倒计时、更新源、自动检查更新、无退出确认。
- Windows 刷新率模式（有原生信息才显示信息行）；Android 刷新率模式（平台能力不可用则隐藏，不做假开关）。
- 配置预览页（JSON、复制）。
- 验收：窗口尺寸可应用并持久化；退出倒计时真实生效；预览内容与各 prefs 一致。

### 批 3：视频 / PiP / 播放行为
- 音量分平台档 + 全局静音；蜂窝清晰度。
- 全屏默认、屏幕常亮、后台播放（Android）、ASMR 睡眠（平台能力检测）、退出浮窗。
- Windows PiP 6 项 + 重置位置（依赖现有 `PresentationDriver`/窗口宿主；缺一项就不显示）。
- 弹幕显示开关/字体/过滤入口接到对应页。
- 验收：每项找到真实消费调用；无平台能力时不渲染伪开关。

### 批 4：弹幕全量
- 模板/保存恢复、无表情、区域、上下边距、最大同屏、字重/字间距、海量模式、小窗缩放、自动/手动 FPS、重复折叠、点按/长按、相似度过滤。
- 先核对现有渲染器支持哪些字段，缺的补到渲染器，不只在设置页做 UI。

### 批 5：竖屏直播
- 检测/自适应高度/布局模式/全屏策略/全屏画面模式/弹幕模式/房间覆盖记忆/诊断浮层/重置。
- 消费点：房间布局/播放呈现/弹幕 surface。

### 批 6：刷新 / 缓存 / 字体 / 加载样式
- 刷新并发与缩略图频率；缓存缩略图刷新、下载目录；字族管理与字体下载/删除；加载样式与颜色。
- 字体/加载样式是独立子系统，先补数据与消费，再加 UI。

### 批 7：本机互动（范围确认后）
- 若产品确认要：本地服务/浮层/用户资料/礼物动效/经验经济；否则在文档标记“参考有、我们暂不支持”并说明原因。

### 批 8：域设置复核 + 收尾
- IPTV/录制/备份/账号/WebDAV/远程接收逐字段复核。
- 所有新设置加入搜索索引、备份 prefs、重置路径、l10n（中/英）。
- 最终：`dart analyze lib` 0、`flutter build bundle` exit 0、按平台截图走查。

## 4. 本轮已完成 / 待验证

- ✅ 背景：图库/视频/纯色/渐变/设备拆分路由 + 预览。
- ✅ 背景：随机图源 7 组 82 源（JSON/direct/alcy 三种请求、魔数校验、哈希落盘、预览“换一张”、应用）。
- 随机图源已运行期验证：UAPI 组取图、预览、「换一张」、应用均通过；`dart analyze lib` 0、`flutter build bundle` exit 0。共享 HTTP 缓存会命中同一张，随机请求已显式 `cache: false`。
- 下一批从「房间卡片 + 页面 + 导航」开始。

## 5. 验收规则（防止再做皮毛）

1. 每个控件必须在参考中找到对应字段；不得新增参考没有的伪功能。
2. 每个开关/选择必须有一个真实消费点（文件+符号）；只写 prefs 不算完成。
3. 平台专属项用能力检测隐藏，不显示无效开关；隐藏原因写入代码注释。
4. 每个设置加入备份/恢复与搜索；重置路径要定义清楚。
5. UI 文案全部 slang；代码注释英文。
6. 每批结束跑 analyze/build，并至少对一个真实页面做运行期操作验证。
