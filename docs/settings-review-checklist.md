# 设置逐项审查清单（对照 `pure_live-master`）

> 用途：按“一个设置一行”审查，你审一项，我实现一项；不再按页面打包，也不再凭印象漏项。
> 参考：`C:\Users\m1779\Downloads\pure_live-master\pure_live-master`
> 状态：✅ 已实现且有消费；◐ 部分；○ 缺失；➖ 参考自身未消费/平台不适用；❓ 待逐项核对。
> 每项格式：`[状态] 编号 名称 — 选项/默认值 — 参考位置 — 参考消费点 — 我们的情况/实现要点`

## A. 通用、窗口、启动、退出、更新

- [x] GEN-01 `refresh_rate_mode` — 节能 / 均衡 / 性能，默认节能 — `core/config/app_settings_controller.dart:54`、`general_settings_page.dart:32` — live_device `DisplayRefreshRateService`：Android 按参考分支为释放请求 / 交互升频 / 前台保持最高（见 GEN-12）；其他平台节能 `matchContent(60)`、均衡 `preferDefault`、性能 `preferMaximum`；实现 `app/providers/display_refresh_rate_provider.dart`，UI `features/settings/refresh_rate_section.dart`。Windows 请求接口不可用时只读，不显示假下拉 — ✅（Windows 实机只读；Android/iOS 模式选择待真机）。
- [x] GEN-02 Windows 动态刷新率信息 — 只读：当前/最高 Hz — `general_settings_page.dart:48` — live_device `read()` 的 currentHz/maxHz/monitorCount；UI 当前 240 Hz · 最高 240 Hz，多显示器提示，刷新按钮 — ✅（Windows 实机）。
- [x] GEN-03 `enableNewWindowPlay` — 开关，默认 true — `app_settings_controller.dart:62`、`general_settings_page.dart:58` — `roomWindowsProvider` + `shell.roomWindows`；通用页“直播间在独立窗口打开” — ✅（已有）。
- [x] GEN-04 `showSplashPage` — 开关，默认 true — `app_settings_controller.dart:53`、`general_settings_page.dart:64` — `splashSettingsProvider`（`ui.splash`）+ 根层 `StartupSplash`：启动时盖一层应用标记，900ms 后 280ms 淡出再移除；关闭后下次启动直接进主界面 — ✅ 代码完成，未运行期测试（按要求跳过）。
- [x] GEN-05 `enableAutoCheckUpdate` — 开关，默认 true — `app_settings_controller.dart:50`、`general_settings_page.dart:70` — `updateSettingsProvider`（`updates.autoCheck`）在 `PureLiveApp` 首帧后静默调用 `versionCheckProvider.check()`；结果由关于页渲染，失败不打扰 — ✅（Windows 实机请求 version.json 200，设置行已显示）。
- [x] GEN-06 `useGitHubOriginForUpdates` — 开关，默认 false — `app_settings_controller.dart:51`、`general_settings_page.dart:76` — 更新源选择 — ➖ 已核实不适用：我们只有 GitHub raw 一个发布源，没有第二个镜像可切换；不造无效开关（若以后加镜像再补）。
- [x] GEN-07 `enable_countdown_close` — 开关，默认 false — `exit_settings_controller.dart:26`、`general_settings_page.dart:83` — `autoShutdownProvider`（`exit.autoShutdown.enabled`）启动/取消倒计时；到时桌面 `WindowHost.destroy`+`exit(0)`、移动 `SystemNavigator.pop`；通用页“定时关机”开关 — ✅ 代码完成，未运行期测试（按要求跳过）。
- [x] GEN-08 `autoShutDownTime` — 1–525600 分钟，默认 120 — `exit_settings_controller.dart:25`、`general_settings_page.dart:110` — `autoShutdownProvider`（`exit.autoShutdown.minutes`）保存时长并在启用时重启倒计时；UI 预设 15/30/45/60/90/120/180/240/480/720/1440 + 自定义 — ✅ 代码完成，未运行期测试（按要求跳过）。
- [x] GEN-09 `enableStartUp` — 开关（读系统真实状态，不预置存储值） — `startup_controller.dart:24`、`general_settings_page.dart:132` — live_device 新增 `PlatformStartupService`（Windows Run 键 + Startup 文件夹回退）、`startupProvider`；通用页 `开机启动` 行 — ◐ 实现完成，服务 CLI 直测通过；本机由代理启动的 GUI 进程写 Run 被 Access Denied，回退路径也未能落盘，运行期待正常启动方式复测。
- [x] GEN-10 `window_width` / `window_height` — 预设 1080×720 / 1280×720 / 1600×900 / 1920×1080 / 2560×1440 + 自定义，范围 400–16384 × 300–16384 — `window_size_controller.dart:184-185`、`general_settings_page.dart:149` — `windowSizeProvider`（`window.width`/`window.height`）通过 `WindowHost.geometry/setGeometry/center` 应用并居中；启动时应用，窗口边缘拖拽后 450ms 回写 — ✅（Windows 实机 1600×900 应用 + 重启恢复 + 行值更新）。
- [x] GEN-11 `dontAskExit` — 开关，默认 false — `exit_settings_controller.dart:23`、`general_settings_page.dart:157` — 跳过退出确认 — `shell.dontAskExit`（默认 false）+ live_shell `DesktopShell.confirmClose`：关闭主窗口且未勾选时弹出「隐藏到托盘/最小化 · 退出应用 · 不再询问」对话框，回答后回写 `shell.closeAction` 与 `shell.dontAskExit`；勾选后直接执行所选关闭行为。UI 为通用页「退出不再询问」开关；已加入备份与设置搜索；macOS 不弹确认（关窗不结束应用）。 — ✅（代码完成，未运行期点击测试）
- [x] GEN-12 Android 刷新率模式（与 GEN-01 同键，平台分支） — 节能/均衡/性能，默认节能 — `app_settings_controller.dart:116-119`、`core/widgets/adaptive_refresh_rate_scope.dart:15-160` — `AdaptiveRefreshRateController` + `AdaptiveRefreshRateScope` — 应用层新增 `RefreshRateInteractionScope`（`lib/app/refresh_rate_interaction_scope.dart`）包住根内容，把指针按下/移动/抬起、滚动开始/更新/结束与 `resumed`/`inactive`/`paused` 生命周期送进 `DisplayRefreshRateController`；Android 分支节能与均衡先 `preferDefault`，均衡仅在交互时 `preferMaximum`、停手 1.5s 回落，性能前台 `preferMaximum`、切后台释放；`_setHigh` 串行合并请求，选择新档会清掉旧 burst。Android 的节能不再固定 60 Hz，而是按参考把选择交还系统；其他平台保持 GEN-01 映射。模式选项在 Android 上不再依赖内容匹配能力。文案同步改为交互自适应 — ✅ 代码完成，未在 Android 真机点击/切换验证。
- [x] GEN-13 `exitChoose` — 退出行为，默认 `exitAction` — `exit_settings_controller.dart:24` — `shellWindowSettingsProvider` + `shell.closeAction`；通用页“关闭窗口时” — ✅（已有）。
- [x] GEN-14 `autoRefreshTime` — 数值，默认 3（旧版自动刷新兼容键） — `app_settings_controller.dart:43`、`:196/:222/:249/:272` — ➖ 参考自身只做持久化、备份/恢复和旧配置迁移，设置页无控件、运行期无消费；关注页真正的定时刷新读取 `refresh_config_controller.dart:21/27` 的 `autoRefreshFavorite`/`autoRefreshInterval`（REF-01/03）。不新增无效兼容键。—— ✅ 已核实为不适用。
- [x] GEN-15 `enableDenseFavorites` — 开关，默认 true — `app_settings_controller.dart:44` — 关注页密度 — ✅ 独立键 `browse.denseFavorites`（默认 true）与通用页「浏览偏好 → 紧凑模式」开关；`FavoritesPage` 读取并计算网格列宽：紧凑模式使用小卡片（最多 280px、多列），关闭后按参考 300px 最小卡宽重算（手机一列、大卡片）；已加入备份、设置搜索与恢复后的 provider 刷新。代码完成，未运行期点击测试。

## B. 主题与外观

- [x] THEME-01 主题模式 — 跟随系统/浅色/深色，默认 System — `theme_settings_controller.dart:17`、`theme_settings_page.dart:?` — ThemeMode — ✅ 现有外观页：`AppThemeSettings` 默认 `DsThemeMode.system`，外观页三档选择写 `theme.mode`，`DsApp.themeMode` 消费；已进备份与设置搜索。
- [x] THEME-02 任意主题色 — 色盘/预设，默认蓝 — `theme_settings_controller.dart:19`、`theme_settings_page.dart:205-223` — ThemeData primary — ✅ 外观页「主题色」改为打开取色对话框：系统取色、6 个命名色、参考 `AppConsts.themeColors` 14 个预设色、HSV 色板 + 色相条 + `#RRGGBB` 输入；持久化沿用 `theme.seed`（命名名或 `#RRGGBB`），启动由 `stored_theme.dart` 解析为 `DsSeed.color`，根层 `_customSeedColor` 区分自定义色与系统/命名色，只有 seed 真正变化才写盘；`DsThemeData(seed)` 是消费点；已进备份（`theme.seed`）与设置搜索。未运行期点击测试。
- [x] THEME-03 动态取色 — 开关，默认 false（Android 12+） — `theme_settings_controller.dart:18` — dynamic_color — ✅ 新增 `theme.dynamicColor`（默认 false）与 `dynamicColorProvider`；`dynamicColorSeedProvider` 用已有 `dynamic_color` 读取平台调色板（Android 12+ 壁纸 CorePalette，Windows/macOS/Linux 系统强调色，iOS/web 返回 null）。消费点：`PureLiveApp` 在开关开启且调色板可用时以调色板主色作为 `DsThemeData` 的 seed，覆盖存储主题色；外观页新增「动态取色」开关（不支持的平台不显示），开启时主题色行只读并显示「跟随系统动态取色」，个性化预览同步使用动态色。已进备份（`theme.dynamicColor`）、设置搜索、跨窗口/恢复后 provider 刷新与中英文文案（slang 已生成）。`dart analyze lib` 0、`flutter build bundle` exit 0；未运行期点击测试。Windows 默认 seed 本就取系统强调色，因此默认外观下开关前后颜色相同，选过自定义/命名主题色后差异可见。
- [x] THEME-04 网格交叉间距 `crossAxisSpacing` — 0–64，默认 6 — `theme_settings_controller.dart:21` — 网格布局 — ✅ 外观页已有滑杆，消费 `browse.crossSpacing` → 共享 `CardGrid` 横间距；原先范围 0–32、默认 16 与参考不符，已改为参考的 0–64、默认 6，滑杆最大/刻度随常量。已进备份与搜索。
- [x] THEME-05 网格主轴间距 `mainAxisSpacing` — 0–64，默认 6 — `theme_settings_controller.dart:22` — 网格布局 — ✅ 同上，`browse.mainSpacing` → 行间距；范围与默认同步改为 0–64 / 6；已进备份与搜索。
- [x] THEME-06 加载样式 `loadingStyle` — 样式键集合，默认 `AppConsts.defaultLoadingStyleKey` — `theme_settings_controller.dart:23` — 加载组件 — ◐ 新增 `theme.loadingStyle`（默认 `default`）与 `loadingStyleProvider`；因不新增依赖，按参考键实现 10 种 Flutter 原语动画（default/pulse/doubleBounce/threeBounce/wave/fadingCircle/cubeGrid/ripple/orbit/lineScale），由 `AppLoadingIndicator` 统一渲染（default 仍用 `DsSpinner`，保留 reduced-motion）。消费点：`CardGrid` 加载页脚与下拉刷新、房间聊天/播放器、IPTV 频道与来源/播放页、多画面、VOD、WebDAV、背景图库、版本记录、工具箱等页面加载状态；外观页新增「加载样式」行（静态预览）与画廊对话框（实时预览、选中即应用）。已进备份（`theme.loadingStyle`）、设置搜索、跨窗口/恢复后 provider 刷新与中英文文案（slang 已生成）。参考其余 75 种动画依赖 `flutter_spinkit`/`loading_animation_widget`/`loading_indicator`，未获准新增依赖，故不展示、不伪造。`dart analyze lib` 0、`flutter build bundle` exit 0；未运行期点击测试。
- [x] THEME-07 加载颜色 `loadingStyleColorSwitch` — 空/颜色，默认空 — `theme_settings_controller.dart:24` — 加载组件 — ✅ 新增 `theme.loadingColor`（默认空=跟随主题强调色，读写接受 `#RRGGBB`/`#AARRGGBB`）与 `loadingColorProvider`；消费点：`AppLoadingIndicator` 的默认着色改为“显式 color > 加载颜色设置 > 图标色 > 强调色”，因此 `CardGrid`、房间聊天/播放器、IPTV、多画面、VOD、WebDAV、背景图库、版本、工具箱等全部加载状态同步换色；显式传入的颜色（如视频暗底白圈）仍优先以保证可读。加载样式对话框中新增「加载颜色」行与取色对话框：跟随主题、参考 14 个预设色、任意 6/8 位十六进制（8 位含透明度），确认后写入。已进备份（`theme.loadingColor`）、设置搜索、跨窗口/恢复后 provider 刷新与中英文文案（slang 已生成）。未运行期点击/目视透明度效果。
- [x] THEME-08 语言 `language` — 语言表；参考 v5 未选择时跟随系统、基准简体中文（3.x 默认简体中文） — `theme_settings_controller.dart:20`、`appearance_pages.dart:143-179` — locale — ✅ 持久化 `app.locale`（null=跟随系统，回退 zh-CN）；启动读取并 `LocaleSettings.setLocaleRawSync`，根层 `AppLocaleScope` 提供即时切换，跨窗口/备份恢复经 `settingsRevisionProvider` 重读并重设 locale；外观页「语言」行提供跟随系统/简体中文/English，`PureLiveApp._updateLocale` 写盘并立即应用；已进备份（`app.locale`）、设置搜索与 slang 中英文文案。仅提供已翻译的两种语言，不伪造语言列表。未运行期点击切换。并发收口补强：`ThemePersistence.normalizeLocaleCode` 把 `zh`/`zh-*`/`简体中文`/`English` 等旧值归一化为 `zh-CN`/`en`，未知值回退跟随系统；`readLocale` 与 `_updateLocale` 只读写规范代码；语言选项文案改走 slang（`languageSimplifiedChinese`/`languageEnglish`）。未运行期切换/重启验证。
- [x] THEME-09 文本缩放 `textScaleFactor` — 0.5–2.0，默认 1.0 — `font_settings_controller.dart:18-20/41`、`theme_settings_page.dart:160-185` — TextScaler — ✅ 新增 `theme.textScale`（默认 1.0，读写夹取 0.5–2.0）与 `textScaleFactorProvider`；消费点：根层 `PureLiveApp` builder 用 `MediaQuery.copyWith(textScaler: TextScaler.linear(factor))` 包住全部路由与启动遮罩（主窗口与克隆窗口同一根）；外观页「字体和语言」新增文本缩放滑杆（0.5×–2.0×、15 档、100% 为原始大小）与实时预览行；已进备份（`theme.textScale`）、设置搜索、跨窗口/恢复后 provider 刷新与中英文文案（slang 已生成）。`dart analyze lib` 0、`flutter build bundle` exit 0；未运行期点击/目视缩放。
- [ ] THEME-10 正文字号 small/medium/large — 5 档字号键 — `font_settings_controller.dart:42-44`、`font_settings_page.dart` — ThemeData textTheme — ○。
- [ ] THEME-11 标题字号 medium/large — 2 档 — `font_settings_controller.dart:45-46` — textTheme — ○。
- [ ] THEME-12 字体族 `fontFamilyName` — 默认 Default — `font_settings_controller.dart:47` — ThemeData — ◐ 有字体选项，无管理器。
- [ ] THEME-13 字体文件 `fontFamilyFileName` — 默认空 — `font_settings_controller.dart:48` — 字体注册 — ○。
- [ ] THEME-14 弹幕字体文件 `danmakuFontFamilyFileName` — 默认空 — `font_settings_controller.dart:49` — 弹幕渲染 — ○。
- [ ] THEME-15 主题 → 房间卡片入口 — 动作 — `theme_settings_page.dart` — `room_card_settings` — ○。
- [ ] THEME-16 主题 → 页面设置入口 — 动作 — `theme_settings_page.dart` — `page_settings` — ○。
- [ ] THEME-17 主题 → 加载样式入口 — 动作 — `theme_settings_page.dart` — `change_loading_style` — ○。
- [ ] THEME-18 主题 → 字体管理器入口 — 动作 — `theme_settings_page.dart` — `change_font_family` — ○。
- [ ] THEME-19 主题 → 文本大小入口 — 动作 — `theme_settings_page.dart` — `text_size_settings` — ○。

## C. 页面、导航、平台

- [ ] PAGE-01 `showPageSizeSelector` — 开关，默认 true — `page_settings_controller.dart:14`、`page_settings_page.dart` — 分页条 — ◐ 分页层已有，未暴露开关。
- [ ] PAGE-02 `showGotoButton` — 开关，默认 true — `page_settings_controller.dart:15` — 分页条 — ◐。
- [ ] PAGE-03 `showScrollToTopBtn` — 开关，默认 true — `page_settings_controller.dart:16` — 列表回顶 — ◐。
- [ ] PAGE-04 `defaultPageSize` — 桌面 20 / 手机 12 — `page_settings_controller.dart:17` — 页大小 — ◐ 通用页有每页数量。
- [ ] PAGE-05 `page_size_options_raw` — 选项集合 [20,40,60,80]/[12,24,36,48]，可增删 1–100 — `page_settings_controller.dart:19` — 分页条 — ○。
- [ ] PAGE-06 自适应推荐 — 按宽度推荐选项 — `page_settings_page.dart` — 计算值 — ○。
- [ ] NAV-01 菜单：多画面 — 开关；至少保留一个 — `app_settings_controller.dart:61` / `savedMenuIds`、`navigation_settings_page.dart` — 侧栏/首页 — ◐ 有多画面开关。
- [ ] NAV-02 菜单：关注 — 开关 — 同上 — 首页/侧栏 — ◐ 现有固定。
- [ ] NAV-03 菜单：热门 — 开关 — 同上 — 首页/侧栏 — ◐。
- [ ] NAV-04 菜单：分区 — 开关 — 同上 — 首页/侧栏 — ◐。
- [ ] NAV-05 菜单：录制中心 — 开关 — 同上 — 首页/侧栏 — ○/◐。
- [ ] NAV-06 菜单拖动排序 — `savedMenuIds` 顺序 — `navigation_settings_page.dart` — 侧栏/首页 — ○。
- [ ] PLAT-01 平台显示/隐藏 — 各平台 — 平台设置页 / 现有 `sites.display` — 平台列表 — ✅/◐。
- [ ] PLAT-02 首选平台 `preferPlatform` — 默认 Bilibili — `favorite_room_controller?` / 平台页 — 房间/搜索 — ✅。
- [ ] PLAT-03 第三方授权 — 各平台开关 — 平台页 — 登录/授权 — ○。
- [ ] PLAT-04 热门标签管理 — 标签列表 — 平台页 — 分区标签 — ◐ 有标签页，设置编辑待核。
- [ ] PLAT-05 平台筛选空态 — 显示提示 — 平台页 — 筛选 — ◐。

## D. 刷新

- [x] REF-01 `autoRefreshFavorite` — 开关，默认 false — `refresh_config_controller.dart:21` — 关注页刷新 — ✅ 已有 `refresh.follows.auto`（默认 false）、设置 → 资源 → 刷新开关、`FavoritesPage` 的 `Timer.periodic`；修改后 `ref.listenManual` 立即重挂时钟，切后台/前台也重挂；已进备份与设置搜索。
- [x] REF-02 `refreshFavoriteOnResume` — 开关，默认 true — `refresh_config_controller.dart:26` — 回前台刷新 — ✅ `refresh.follows.onResume`（默认 true）加入 `FollowsAutoRefresh`；设置 → 资源 → 刷新新增“返回应用时刷新关注”开关；`FavoritesPage.didChangeAppLifecycleState` 在 `resumed` 后 450ms 触发一次全量静默刷新，若 15s 内刚刷新过则跳过，离开前台取消待执行；关闭开关立即取消；已进备份（搜索与中英文文案原已存在）。未运行期测试。
- [x] REF-03 `autoRefreshInterval` — 5–360 分钟，默认 30 — `refresh_config_controller.dart:27` — 定时刷新 — ✅ 原默认 15 与参考不符，已改为 30；读取和写入都夹取 5–360，防止备份/手改值把时钟设到范围外；12 档（5/10/15/20/30/45/60/90/120/180/240/360）与设置行沿用，已有备份与搜索。
- [x] REF-04 `maxConcurrentRefresh` — 1–20，默认 4 — `refresh_config_controller.dart:28` — 刷新队列 — ✅ `refresh.maxConcurrent`（默认 4，读写夹取 1–20）+ 设置 → 资源 → 刷新「最大并发刷新」20 档选择（4 标推荐）；消费点：关注页 `FollowsController.refreshRooms` 的批大小（原硬编码 4）与观看历史 `HistoryController.refreshRooms`（原逐条串行，现同样分批并发）；已进备份、设置搜索与恢复后的 provider 刷新。未运行期验证。
- [x] REF-05 `autoRefreshThumbnails` — 开关，默认 false — `refresh_config_controller.dart:29`、`cache_controller.dart:234-250` — 设置 → 资源 → 刷新「自动刷新封面」；持久化 `refresh.thumbnails.auto`（默认 false）。每个窗口的根层在首帧/跨窗口设置变更/备份恢复后启动 `ThumbnailRefreshController`，按间隔清空 `cached_network_image` 磁盘缓存与 Flutter 内存图片缓存（房间窗口清自己的 cache 实例），让封面、头像、台标下次重新下载；不会动观看历史/关注。已进备份与搜索。 — ✅ 代码完成，未运行期等待一个周期验证。
- [x] REF-06 `thumbnailRefreshInterval` — 5–360，默认 30 — `refresh_config_controller.dart:30`、`refresh_settings_page.dart:145-167` — 持久化 `refresh.thumbnails.minutes`（默认 30，读写夹取 5–360），八档 5/10/15/30/60/120/240/360，仅在自动刷新开启时显示；修改立即重排计时器。已进备份与搜索。 — ✅ 代码完成，未运行期测试。

## E. 视频、音频、播放行为

- [x] VID-01 `globalVolumeMute` — 开关，默认 false — `volume_settings_controller.dart:10`、`live_room_volume_manager.dart:16`、`volume_control.dart:67/109` — 全局音量 0 — ✅ `playback.globalMute`（默认 false）+ 设置 → 播放偏好「全局静音」开关；消费点：直播间 `RoomController` 的 `_muted || _globalMute` 生效静音与实时监听（播放器栏图标/按钮同步），IPTV 播放页、VOD 播放页同样在句柄到达和设置变化时应用，多画面墙的 `_audible` 把全局静音算进去且工栏按钮可一键清除；各页在全局静音时点“取消静音”会关闭该设置，避免假按钮；预置静音 `playback.muted` 仍保留为用户自己的选择。已进备份、设置搜索与中英文文案（slang 已生成）。 — ✅ 代码完成；`dart analyze lib` 0 issues，`flutter build bundle` exit 0（20:45 初次 / 21:00 复跑）。未运行期播放验证。
- [x] VID-02 `defaultMobileVolume` — 0–1，默认 0.5 — `volume_settings_controller.dart:8`、`video_settings_page.dart:91-101` — 移动默认音量 — ✅ `playback.mobileVolume`（默认 0.5，夹取 0–1）；设置 → 播放偏好「默认音量」在手机/平板（Android/iOS，含 TV）读取/写入该键，滑杆只改当前平台；手机/平板新打开的直播间、IPTV、VOD、多画面用它作为初始音量。旧版单键 `playback.volume` 仅作为当前平台的迁移回退，改过滑杆后移除。已进备份、搜索与中英文文案。未运行期验证。
- [x] VID-03 `defaultDesktopVolume` — 0–1，默认 1.0 — `volume_settings_controller.dart:9`、`video_settings_page.dart:102-114` — 桌面默认音量 — ✅ `playback.desktopVolume`（默认 1.0，夹取 0–1）；桌面（Windows/macOS/Linux）滑杆读写该键，新播放器用它作为初始音量；与 VID-02 共用平台选择与迁移逻辑。已进备份、搜索与中英文文案。未运行期验证。
- [x] VID-04 `preferResolution` — 原画/蓝光8M/蓝光4M/超清/流畅，默认原画 — `player_settings_controller.dart:48`、`:287`、`player_controller.dart:640-665` — 画质选择 — ✅ `playback.quality` 改为参考的五档优先清晰度（`kPreferredResolutionChoices`，默认原画）；设置 → 播放偏好改为五档选择，去掉“自动”；房间与多画面共用 `preferredQualityIndex`：先找同名画质，找不到按档位位置比例映射到站点实际画质（原画→第一档、流畅→最后一档）；旧版站点标签（蓝光/高清/标清）读入时映射到最近档位；已进备份与搜索，新增蓝光 8M/4M 中英文文案（slang 已生成）。 — 代码完成，未运行期切站点验证映射。VID-05 蜂窝画质另列（需网络类型能力，未加依赖）。
- [ ] VID-05 `preferResolutionCellular` — 同上，移动网络 — `player_settings_controller.dart:49` — 蜂窝画质 — ○。
- [ ] VID-06 `enableBackgroundPlay` — Android 开关，默认 false — `app_settings_controller.dart:45` — 后台音频 — ○。
- [ ] VID-07 `enableAsmrSleepMode` — Android 开关，默认 false — `app_settings_controller.dart:46` — ASMR/睡眠 — ○。
- [ ] VID-08 `asmrSleepMinutes` — 15…1440，默认 60 — `app_settings_controller.dart:47` — 睡眠定时 — ○。
- [ ] VID-09 `floatPlay` — 开关，默认 false — `player_settings_controller.dart:215` — 返回时浮窗 — ○。
- [ ] VID-10 `windowsPipAlwaysOnTop` — Windows 开关，默认 false — `player_settings_controller.dart:218` — PiP 置顶 — ○。
- [ ] VID-11 `rememberPipPosition` — 开关，默认 true — `window_size_controller.dart:188` — PiP 位置记忆 — ○。
- [ ] VID-12 `windowsPipBaseSize` — 200–720，默认 360 — `player_settings_controller.dart:230` — PiP 基准尺寸 — ○。
- [ ] VID-13 `windowsPipMinWidth` — 100–320，默认 140 — `player_settings_controller.dart:231` — PiP 最小宽 — ○。
- [ ] VID-14 `windowsPipMinHeight` — 60–240，默认 90 — `player_settings_controller.dart:232` — PiP 最小高 — ○。
- [ ] VID-15 `windowsPipFreeAspect` — 开关，默认 false — `player_settings_controller.dart:220` — 锁定宽高比 — ○。
- [ ] VID-16 PiP 位置重置 — 动作/确认 — `window_size_controller.dart`、video 页 — 清几何 — ○。
- [ ] VID-17 `enableFullScreenDefault` — 开关，默认 false — `app_settings_controller.dart:52` — 初始全屏 — ○。
- [x] VID-18 `enableScreenKeepOn` — 开关，默认 true — `app_settings_controller.dart:49` — live_device `ScreenAwakeService`；`keepScreenOnProvider` + 播放偏好页开关，房间/IPTV 播放时读取并保持/释放 wakelock（暂停、失败、关闭设置即释放） — ✅（房间/IPTV 已接线；桌面开关已验证）。
- [ ] VID-19 `enableRotateScreen` — 开关，默认 false — `app_settings_controller.dart:48` — 屏幕旋转 — ○（参考 video 页未列，但属于播放行为）。
- [ ] VID-20 弹幕显示/隐藏 `hideDanmaku` — 默认 false（显示） — `danmaku_settings_controller.dart:61` — 房间/小窗/多画面 — ✅/◐。
- [ ] VID-21 弹幕字体族入口 `danmakuFontFamilyName` — 默认 Default — `danmaku_settings_controller.dart:91` — 弹幕渲染 — ○。
- [ ] VID-22 弹幕过滤入口 — 关键字/相似度 — 见 F 组 — ○/◐。
- [ ] VID-23 竖屏直播入口 — 动作 — 见 G 组 — ○。
- [ ] VID-24 观众指标入口 — 动作 — 见 J 组 — ◐。

## F. 播放器内核

- [ ] KER-01 `videoPlayerKey` — 手机 mpv/ijk/exo；桌面 mpv；默认 mpv — `player_settings_controller.dart:46` — switchEngine — ✅。
- [ ] KER-02 `videoFitIndex` — 画面比例索引，默认 0 — `player_settings_controller.dart:45` — 播放器 fit — ✅。
- [ ] KER-03 播放器代理 — 开关/主机/端口，默认关闭/空/7897 — `proxy_settings_controller.dart:11-13` — `http-proxy` — ✅/◐。
- [ ] KER-04 硬解开关 `enableCodec` — 默认 true — player outputs — `enableHardwareAcceleration`/`hwdec=no` — ✅。
- [ ] KER-05 一键均衡预设 — 动作/确认 — player 预设 — `applyPreset(balanced)` — ◐ 有预设选择，无一键动作。
- [ ] KER-06 Android 兼容修复 — 动作/确认 — player 预设 — `applyPreset(compat)` — ○/◐。
- [ ] KER-07 Super Resolution `superResolutionMode` — off/efficiency/quality，默认 off — `player_settings_controller.dart:239` — `glsl-shaders` — ✅（Windows）。
- [ ] KER-08 强制销毁 `useHardStopOnExit` — 默认 false — `player_settings_controller.dart:236` — 参考无消费；我们用于 teardown — ✅（真实语义待定义）。
- [ ] KER-09 自定义输出 `customPlayerOutput` — 默认 false — player outputs — vo/hwdec/ao 下发 — ✅/◐。
- [ ] KER-10 视频输出 vo — 平台列表，默认 auto — player outputs — mpv vo — ✅/◐。
- [ ] KER-11 音频输出 ao — 平台列表，默认 auto — player outputs — mpv ao — ✅。
- [ ] KER-12 硬件解码器 hwdec — 平台列表，默认 auto-safe — player outputs — mpv hwdec — ✅。
- [ ] KER-13 video-sync — 8 个模式，默认 audio — player outputs — mpv video-sync — ✅。
- [ ] KER-14 interpolation — 开关，默认 false — player outputs — mpv interpolation — ✅。
- [ ] KER-15 scale — 12 内核，默认 lanczos — player outputs — mpv scale — ✅。
- [ ] KER-16 deinterlace — auto/no/yes，默认 auto — player outputs — mpv deinterlace — ✅。
- [ ] KER-17 hwdec-codecs — all/h264,hevc/…，默认 all — player outputs — mpv hwdec-codecs — ✅。
- [ ] KER-18 audio-exclusive — Windows 开关，默认 false — player outputs — mpv audio-exclusive — ✅。
- [ ] KER-19 恢复 mpv 默认 — 动作/确认 — player controller — reset 子集 — ✅/◐（范围需与参考对齐）。
- [ ] KER-20 mpv 官方文档 / 播放器指南 — 链接/文档 — player guide — 无状态 — ◐（指南内容需补全）。
- [ ] KER-21 预设 6 个 — 均衡/兼容/RTX VSR/低配/弱网/低延迟 — presets — 各写一组 mpv 属性 — ✅/◐（平台/属性逐项核对）。

## G. 竖屏直播

- [ ] POR-01 `enablePortraitStreamAdaptation` — 开关，默认 true — `player_settings_controller.dart:243` — 竖屏策略 — ○。
- [ ] POR-02 `portraitAdaptiveHeight` — 开关，默认 true — `:244` — 房间高度 — ○。
- [ ] POR-03 `portraitLayoutMode` — balanced/immersive/compatibility，默认 balanced — `:245` — 密度模式 — ○。
- [ ] POR-04 `portraitFullscreenPolicy` — followSource/followSystem/landscape，默认 followSource — `:246` — 全屏方向 — ○。
- [ ] POR-05 `portraitFullscreenDisplayMode` — complete/ambient/balanced/cover，默认 ambient — `:250` — 全屏画面 — ○。
- [ ] POR-06 `portraitPipFollowSource` — 开关，默认 true — `:254` — 参考无消费 — ➖（参考也未接线）。
- [ ] POR-07 `portraitDanmakuMode` — followGlobal/upperQuarter/reduced/hidden，默认 followGlobal — `:255` — 弹幕区域 — ○。
- [ ] POR-08 `rememberPortraitRoomOverride` — 开关，默认 true — `:256` — 房间覆盖记忆 — ○。
- [ ] POR-09 `showPortraitDiagnostics` — 开关，默认 false — `:257` — 诊断浮层 — ○。
- [ ] POR-10 重置竖屏设置 — 动作 — `:258`、portrait 页 — 重置并清覆盖 — ○。

## H. 弹幕

- [ ] DAN-01 `hideDanmaku` — 开关（显示=反选），默认显示 — `danmaku_settings_controller.dart:61` — 房间/小窗/多画面 — ✅/◐。
- [ ] DAN-02 `noEmojiMode` — 开关，默认 `defaultNoEmojiMode` — `:62` — 发送/渲染 — ○。
- [ ] DAN-03 `danmakuTopArea` — 0–300，默认 `defaultDanmakuTopArea` — `:63` — 上边距 — ○。
- [ ] DAN-04 `danmakuArea` — 0–1，默认 `defaultDanmakuArea` — `:64` — 显示区域 — ✅/◐（现有区域档位）。
- [ ] DAN-05 `danmakuBottomArea` — 0–300，默认 `defaultDanmakuBottomArea` — `:65` — 下边距 — ○。
- [ ] DAN-06 `danmakuSpeed` — 20–400 px/s，默认 120 — `:66` — 速度 — ✅。
- [ ] DAN-07 `danmakuFontSize` — 10–30，默认 16 — `:67` — 字号 — ✅。
- [ ] DAN-08 `danmakuFontWeight` — 100–900 步进 100，默认 500 — `:68` — 字重 — ○。
- [ ] DAN-09 `danmakuFontBorder` — 0–4，默认 1.5 — `:69` — 描边 — ✅/◐（现有描边开关，无宽度）。
- [ ] DAN-10 `danmakuOpacity` — 0–1，默认 1 — `:70` — 透明度 — ✅。
- [ ] DAN-11 `danmakuMaxVisibleCount` — 10–120，默认 48 — `:73` — 同屏上限 — ○。
- [ ] DAN-12 `enableDanmakuStroke` — 开关，默认 true — `:74` — 描边开关 — ✅。
- [ ] DAN-13 `danmakuMassMode` — 开关，默认 false — `:76` — 海量模式 — ○。
- [ ] DAN-14 `danmakuLetterSpacing` — −2–8，默认 0 — `:82` — 字距 — ○。
- [ ] DAN-15 `danmakuFps` — 30–240，默认 `defaultDanmakuFps` — `:83` — 手动 FPS — ○。
- [ ] DAN-16 `danmakuAutoFps` — 开关，默认 `defaultDanmakuAutoFps` — `:84` — 自动 FPS — ○。
- [ ] DAN-17 `enableDanmakuTapInteraction` — 开关，默认 true — `:85` — 点按动作 — ○。
- [ ] DAN-18 `enableDanmakuLongPressInteraction` — 开关，默认 true — `:86` — 长按动作 — ○。
- [ ] DAN-19 `collapseRepeatedDanmaku` — 开关，默认 false — `:87` — 重复折叠 — ○。
- [ ] DAN-20 `repeatedDanmakuWindowSeconds` — 1–30，默认 5 — `:88` — 折叠窗口 — ○。
- [ ] DAN-21 `savedDanmakuTemplate` — JSON v2，默认空 — `:90` — 保存/恢复模板 — ○。
- [ ] DAN-22 `pipDanmakuScaleAuto` — 开关，默认 true — `:99` — 小窗缩放 — ○。
- [ ] DAN-23 `pipDanmakuScaleValue` — 0.4–1.0，默认 0.4 — `:100` — 小窗缩放 — ○。
- [ ] DAN-24 `filterDouyuSuspectedAutomatedMessages` — 开关，默认 `default…` — `:105` — 斗鱼过滤 — ○。
- [ ] DAN-25 `enableDanmakuSimilarityFilter` — 开关，默认 `default…` — `:111` — 相似度过滤 — ○。
- [ ] DAN-26 `danmakuSimilarityThreshold` — 50–100，默认 85 — `:115` — 相似度阈值 — ○。
- [ ] DAN-27 `danmakuSimilarityCacheDuration` — 1–60s，默认 3 — `:116` — 过滤缓存 — ○。
- [ ] DAN-28 `danmakuSimilarityMaxCacheSize` — 20–1000，默认 100 — `:117` — 过滤缓存 — ○。
- [ ] DAN-29 模板四项 — 最佳/舒适/密集/默认 — danmaku surface — 写 9 个属性 — ○。
- [ ] DAN-30 屏蔽关键字 — 列表 + 空输入拒绝 — `shieldList`、favorite controller — 发送/渲染过滤 — ✅。
- [ ] DAN-31 屏蔽用户 — 列表 — `blockedDanmakuUsers` — 用户过滤 — ✅。

## I. 房间卡片

- [ ] CARD-01 配置目标 — 手机 / 桌面 — `room_card_settings_controller.dart:251-260`、room card 页 — 两套配置 — ○。
- [ ] CARD-02 预设 — 紧凑/标准/详细/自定义 — `RoomCardPreset` — 组配置 — ○。
- [ ] CARD-03 `layout` — cover/compact，默认 cover — `RoomCardAppearance` — 卡片布局 — ○。
- [ ] CARD-04 `showAvatar` — 开关，默认 true — 同上 — 头像 — ○。
- [ ] CARD-05 `showAnchorName` — 开关，默认 true — 同上 — 主播名 — ○。
- [ ] CARD-06 `showAudience` — 开关，默认 true — 同上 — 观众数 — ◐ 仅有观众指标，无显示开关。
- [ ] CARD-07 `showReplayBadge` — 开关，默认 true — 同上 — 回放角标 — ○。
- [ ] CARD-08 `showPlatformBadge` — 自动/总是/隐藏 — 同上 — 平台角标 — ○。
- [ ] CARD-09 `automaticPlatformBadge` — 开关，默认 true（标准预设） — 同上 — 自动角标 — ○。
- [ ] CARD-10 `cornerRadius` — 0–32，默认 20（紧凑 12） — 同上 — 圆角 — ○。
- [ ] CARD-11 预览 — 动作/实时卡片 — room card 页 — 预览 — ○。
- [ ] CARD-12 重置当前目标 — 动作 — room card 页 — 恢复标准 — ○。

## J. 字体、加载样式、观众指标

- [ ] FONT-01 字体管理入口 — 动作 — `font_family_manager_page.dart` — 字体页 — ○。
- [ ] FONT-02 默认字体组 / 云字体组 — 选择/下载/应用/删除 — 同上 — 字体注册 — ○。
- [ ] FONT-03 自动字重 / 锁定字重 — 开关 — 同上 — 字重 — ○。
- [ ] FONT-04 字号 five 档 — 见 THEME-10/11 — font settings — textTheme — ○。
- [ ] LOAD-01 加载样式 — 样式集合，默认 `AppConsts.defaultLoadingStyleKey` — `loading_style_settings_page.dart` — 加载组件 — ○。
- [ ] LOAD-02 加载颜色 — 空/颜色 — 同上 — 加载组件 — ○。
- [ ] LOAD-03 恢复默认加载样式 — 动作 — 同上 — 样式/颜色 — ○。
- [ ] AUD-01 观众指标模式 — 跟随平台/在线/热度/累计 — `audience_metric_settings_page.dart` — 卡片数字 — ✅/◐。
- [ ] AUD-02 每平台真实在线 — 8 个平台开关，默认抖音/快手/CC/Twitch/SOOP/AcFun/Picarto/TwitCasting — `app_settings_controller.dart:56` — 数据选择 — ○。
- [ ] AUD-03 迁移 `audienceMetricMigration` — 版本修复 — `:57` — 自动 — ✅（内部）。
- [ ] AUD-04 `preferRealOnlineCounts` — 开关，默认 false — `app_settings_controller.dart:55` — 真实在线优先 — ○。

## K. 网络代理、缓存、数据、配置预览

- [ ] NET-01 App 代理 `enableAppProxy` / `appProxyHost` / `appProxyPort` — 默认关/空/7897 — `proxy_settings_controller.dart:16-18` — Dio 重建 — ✅/◐。
- [ ] NET-02 播放器代理 `enableProxy` / `proxyHost` / `proxyPort` — 默认关/空/7897 — `:11-13` — mpv http-proxy — ✅/◐。
- [ ] NET-03 端口归一化 — 全角字符/数字校验 — proxy controller — 保存前 — ◐。
- [ ] CACHE-01 当前缓存大小 — 只读 — `cache_data_settings_page.dart` — 缓存 — ✅。
- [ ] CACHE-02 刷新缩略图 — 动作 — 同上 — 封面缓存 — ○。
- [ ] CACHE-03 清理本地缓存 — 动作/确认 — 同上 — 缓存 — ✅/◐。
- [ ] CACHE-04 下载目录 — 选择/重置/权限提示 — 同上 — 下载 — ○。
- [ ] CACHE-05 历史限制/清空 — 现有 — 我们的数据页 — ✅。
- [ ] CACHE-06 关注导入/导出 — 现有 — 我们的数据页 — ✅。
- [ ] CACHE-07 封面缓存上限 — 现有 — 我们的数据页 — ✅。
- [x] PREVIEW-01 配置预览 — 完整 JSON + 复制 — `local_config_preview_page.dart` — 只读 — ✅ `config_preview_dialog.dart`：用 `captureSettingsSnapshot()` 生成缩进 JSON，可选文本滚动区 + 复制到剪贴板；关于页入口；加入设置搜索。未运行期测试。

## L. 背景、图库、随机图源

- [ ] BG-01 纯色/渐变 — 色块/渐变块 — `wallpaper_page.dart`、`wallpaper_items_page.dart` — 背景 — ✅。
- [ ] BG-02 在线图片图库 — 4 源、分类、分页、预览 — `wallpaper_library_page.dart` 等 — 背景 — ✅。
- [ ] BG-03 在线视频 — iTab 动态壁纸 — 图库域 — 背景 — ✅。
- [ ] BG-04 随机图源 — 7 组 82 源，direct/json/alcy，预览/换一张/应用 — `wallpaper_api_*` — 背景 — ✅（本轮）。
- [ ] BG-05 设备上传/URL — 图片/视频 — `wallpaper_page.dart` — 背景 — ✅。
- [ ] BG-06 显示选项（填充/遮罩/模糊/清除） — 现有 — 背景 — ✅。

## M. IPTV

- [ ] IPTV-01 `isAutoSyncEnabled` — 开关，默认 false — `iptv_settings_controller.dart:27` — 自动同步调度 — ◐。
- [ ] IPTV-02 同步间隔（小时） — 整数，默认见 iptv 页 — iptv 页 `sync_interval_title` — 定时任务 — ◐。
- [ ] IPTV-03 `selectedSourceId` / `selectedSourceName` — 默认空 — `iptv_settings_controller.dart:25-26` — 当前节目单源 — ◐。
- [x] IPTV-04 `customIptvUserAgent` — 文本，默认空 — `:29`、`iptv_page.dart:183/234`、`playback_header_resolver.dart:143` — 导入/请求头 — ✅ `iptv.userAgent`（默认空，空白即清除）+ 设置 → IPTV 自定义 User-Agent 输入框；消费点：`iptvImporterProvider` 把值传给播放列表/节目单下载的 `iptvFetcherFor`/`iptvBytesFetcherFor`，IPTV 播放的 `SourceHeaders` 与投屏线路在条目没有自带 UA 时补上，条目自带的 User-Agent 优先；已进备份、设置搜索、跨窗口刷新与中英文文案（slang 已生成）。 — 代码完成，未运行期抓包/播放验证。
- [ ] IPTV-05 `m3uDirectory` — 文本，默认 `m3uDirectory` — `:30` — M3U 存储 — ◐。
- [ ] IPTV-06 导入播放列表 — 本地/网络文件动作 — iptv 页 `import_playlist` — 解析并保存 — ✅/◐。
- [ ] IPTV-07 导入 EPG — 本地/网络文件动作 — `import_epg_source` — 解析并保存 — ✅/◐。
- [ ] IPTV-08 选择 EPG 源 — 列表选择 — `select_epg_source`、`active_epg_source` — 当前 EPG — ◐。
- [ ] IPTV-09 播放列表管理 — 列表编辑/删除 — `iptv_list_manage` — 来源列表 — ✅/◐。
- [ ] IPTV-10 节目单下载子入口 — 动作 — `download_guide_sub` — 下载 — ◐。

## N. 录制（参考页 21+ 项）

- [ ] REC-01 默认画质 — 选项/默认见 controller — `record_settings_page.dart` `default_record_quality` — 录制引擎 — ◐/✅。
- [ ] REC-02 拼音目录 `use_pinyin_folder` — 开关 — `record_settings_controller.dart` — 目录命名 — ○/◐。
- [ ] REC-03 录制弹幕 `record_danmaku` — 开关 — 同上 — 录制 — ○/◐。
- [ ] REC-04 存储目录 `storage_directory` — 路径 — 同上 — 录制 — ✅。
- [ ] REC-05 缓存上限开关 `enable_cache_limit` — 开关 — 同上 — 缓存 — ◐。
- [ ] REC-06 缓存上限 `cache_limit` — 数值 — 同上 — 缓存 — ◐。
- [ ] REC-07 当前缓存大小 — 只读 — 录制页 — 缓存 — ◐。
- [ ] REC-08 清理全部缓存 — 动作/确认 — 录制页 — 缓存 — ◐/✅。
- [ ] REC-09 性能/画质预设 — 省电/高清/超清/极致 — 录制页 `record_performance_quality` — 录制参数 — ◐。
- [ ] REC-10 首路最佳 `prefer_best_stream` — 开关 — 同上 — 流选择 — ✅。
- [ ] REC-11 rw_timeout — 数值/预设 — 同上 — 拉流 — ✅/◐。
- [ ] REC-12 queue_size — 数值 — 同上 — 队列 — ✅/◐。
- [ ] REC-13 segment_duration — 数值 — 同上 — 分段 — ✅/◐。
- [ ] REC-14 max_record_tasks — 数值 — 同上 — 并发 — ✅/◐。
- [ ] REC-15 auto_reconnect — 开关 — 同上 — 重连 — ✅/◐。
- [ ] REC-16 max_retry_count — 数值 — 同上 — 重试 — ✅/◐。
- [ ] REC-17 retry_delay — 数值 — 同上 — 重试间隔 — ✅/◐。
- [ ] REC-18 enable_polling — 开关 — 同上 — 轮询 — ✅/◐。
- [ ] REC-19 check_interval — 数值 — 同上 — 轮询间隔 — ✅/◐。
- [ ] REC-20 enable_backoff — 开关 — 同上 — 退避 — ✅/◐。
- [ ] REC-21 max_check_interval — 数值 — 同上 — 最大间隔 — ✅/◐。
- [ ] REC-22 auto_start_boot — 开关 — 同上 — 开机启动 — ○/◐。
- [ ] REC-23 打开录制目录 — 动作 — recorder_open_folder — 目录 — ✅。

## O. 备份、WebDAV、远程、账号

- [ ] BAK-01 本地备份/恢复 — 动作 — `backup_page.dart` — 备份 — ✅。
- [ ] BAK-02 备份目录 — `backupDirectory` — `backup_controller.dart:36` — 文件 — ✅。
- [ ] BAK-03 WebDAV 配置/上传/下载 — `currentWebDavConfig` — `web_dav_settings_controller.dart:16` — 备份 — ✅。
- [ ] BAK-04 远程同步 TV/接收 — 动作 — remote 页 — 设备同步 — ✅。
- [ ] BAK-05 日志开关/目录/浏览器查看 — 动作 — backup 页 — 日志 — ◐。
- [ ] BAK-06 Firebase 云备份 — 登录/同步 — backup 页 — 云 — ➖/○（新依赖，需决策）。
- [ ] ACC-01 Cookie 编辑 — 13 平台 cookie 键 — `cookie_settings_controller.dart` — 请求 — ✅。
- [ ] ACC-02 斗鱼 Cookie 续期/保存时间/设备参数 — `douyuCookieSavedAt` / `douyuLtp0` / `douyuDid` — 同上 — 斗鱼 — ✅/◐。

## P. 本机互动（独立子系统，27 个持久化键）

- [ ] LOCAL-01 `localInteraction.enabled` — 开关，默认 true — local interaction controller — 本机互动 — ○。
- [ ] LOCAL-02 `localInteraction.userName` — 文本，默认 Pure Live — 同上 — 浮层 — ○。
- [ ] LOCAL-03 `localInteraction.title` — 头衔，默认 listener — 同上 — 浮层 — ○。
- [ ] LOCAL-04 `localInteraction.showAsDanmaku` — 开关，默认 true — 同上 — 浮层 — ○。
- [ ] LOCAL-05 `localInteraction.showPlatformBadge` — 开关，默认 true — 同上 — 浮层 — ○。
- [ ] LOCAL-06 `localInteraction.showLevelBadge` — 开关，默认 true — 同上 — 浮层 — ○。
- [ ] LOCAL-07 `localInteraction.enableGiftEffects` — 开关，默认 true — 同上 — 浮层 — ○。
- [ ] LOCAL-08 `localInteraction.previewPlatform` — 默认 Bilibili — 同上 — 预览 — ○。
- [ ] LOCAL-09 `localInteraction.coins` — 默认 1000 — 同上 — 经济 — ○。
- [ ] LOCAL-10 `localInteraction.experience` — 默认 0 — 同上 — 经济 — ○。
- [ ] LOCAL-11 `localInteraction.history` — 默认空列表 — 同上 — 历史 — ○。
- [ ] LOCAL-12 `localInteraction.danmakuPreset` — 默认 clean — 同上 — 浮层弹幕 — ○。
- [ ] LOCAL-13 `localInteraction.danmakuColor` — 默认 0xFFFFFFFF — 同上 — 浮层弹幕 — ○。
- [ ] LOCAL-14 `localInteraction.danmakuFontSize` — 默认 19.0 — 同上 — 浮层弹幕 — ○。
- [ ] LOCAL-15 `localInteraction.danmakuSpeed` — 默认 130.0 — 同上 — 浮层弹幕 — ○。
- [ ] LOCAL-16 `localInteraction.danmakuFontWeight` — 默认 600 — 同上 — 浮层弹幕 — ○。
- [ ] LOCAL-17 `localInteraction.danmakuShowStroke` — 默认 true — 同上 — 浮层弹幕 — ○。
- [ ] LOCAL-18 `localInteraction.danmakuStrokeWidth` — 默认 1.5 — 同上 — 浮层弹幕 — ○。
- [ ] LOCAL-19 `localInteraction.danmakuPlacement` — 默认 scroll — 同上 — 浮层弹幕 — ○。
- [ ] LOCAL-20 `localInteraction.danmakuFontFamily` — 默认 system — 同上 — 浮层弹幕 — ○。
- [ ] LOCAL-21 `localInteraction.danmakuItalic` — 默认 false — 同上 — 浮层弹幕 — ○。
- [ ] LOCAL-22 `localInteraction.danmakuOpacity` — 默认 1.0 — 同上 — 浮层弹幕 — ○。
- [ ] LOCAL-23 `localInteraction.danmakuLetterSpacing` — 默认 0.0 — 同上 — 浮层弹幕 — ○。
- [ ] LOCAL-24 `localInteraction.danmakuStrokeColor` — 默认 0xFF000000 — 同上 — 浮层弹幕 — ○。
- [ ] LOCAL-25 `localInteraction.danmakuShowShadow` — 默认 false — 同上 — 浮层弹幕 — ○。
- [ ] LOCAL-26 `localInteraction.danmakuShadowColor` — 默认 0xFF000000 — 同上 — 浮层弹幕 — ○。
- [ ] LOCAL-27 `localInteraction.danmakuShadowBlur` — 默认 2.0 — 同上 — 浮层弹幕 — ○。
- [ ] LOCAL-28 `localInteraction.danmakuShadowOffset` — 默认 1.0 — 同上 — 浮层弹幕 — ○。
- [ ] LOCAL-29 `localInteraction.danmakuFixedDurationMs` — 默认 4000 — 同上 — 浮层弹幕 — ○。
- [ ] LOCAL-30 清空历史/经验经济 — 动作 — local page — 清空 — ○。

## Q. 内部/房间级存储（不作为设置页控件，仅备份/内部）

- [ ] INT-01 房间音量表 `roomVolumes` — JSON — volume controller — 房间音量 — ✅（内部）。
- [ ] INT-02 房间卡片两套配置 — 见 CARD — 房间卡片 — ○。
- [ ] INT-03 窗口/PiP 几何 — `windows_pip_*`、`window_width/height`、`rememberPipPosition` — window controller — 窗口 — ◐（GEN-10/VID-10…）。
- [ ] INT-04 竖屏房间覆盖 — `portraitRoomOverrides` — player controller — 房间 — ○。
- [ ] INT-05 直播数据/热门分区/标签 — `hotAreasList`、`siteCatalogMigration`、`follow.tags` — live — ✅/◐。
- [ ] INT-06 播放器引擎输出段 — `engineOutputs`（预设/vo/hwdec/ao/…） — player controller — mpv — ✅/◐。
- [ ] INT-07 屏蔽关键字/用户 — `shieldList` / `blockedDanmakuUsers` — 房间 — ✅。
- [ ] INT-08 Cookie 13 键 — 见 ACC-01。
- [ ] INT-09 本机互动 27 键 — 见 LOCAL。

## 审查顺序（建议）

1. GEN-01 起，逐项审 A-E（通用/外观/页面/刷新/视频），这些直接影响主界面和播放。
2. F-H（内核/竖屏/弹幕），弹幕与播放逻辑互相依赖。
3. I-K（卡片/字体/加载/观众/代理/缓存/预览）。
4. L-Q（背景已完成；IPTV/录制/备份/账号/本机互动/内部）。

> 下一步：从 GEN-01 开始，一次只实现一项，先给该项补 prefs、消费点、设置行、l10n、备份与验证，再进入下一项。每项完成后在本清单打勾并记录文件/消费符号。
