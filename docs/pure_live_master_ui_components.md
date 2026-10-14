# pure_live-master（v3.1.19）UI 组件使用审查

- **审查对象：** `C:\Users\XA-158\Downloads\pure_live-master\pure_live-master`（master 单体 app，v3.1.19+4108）
- **审查日期：** 2026-10-14
- **审查方法：** pubspec 依赖声明 + `lib/` 全量 grep 统计（组件构造次数 / `package:` 导入文件数）
- **用途：** 为 v2 重构的 `live_uikit` 组件体系提供旧版 UI 用量的参照基线；数字为该快照的时点值，不代表旧仓后续演进

---

## 1. 总体格局

旧版 UI 的基本盘是 **Material（`ThemeData` 手工构建 light/dark 双主题）+ 内嵌 GetX（`lib/get/` 定制 fork，非 pub 依赖）+ 自建 `lib/core/widgets` 组件库 + 一批聚焦的第三方 UI 包**。

几个定调的事实：

- **纯 Material 单风格。** Cupertino 几乎不用（全库仅 1 处 `CupertinoSwitch`），Fluent/macOS/Glass 等多设计语言在旧版没有任何前身。
- **无常驻导航壳。** `NavigationBar`、`BottomNavigationBar`、`Drawer`、`TabBar`、`BottomSheet` 持久容器均为 0 使用；导航完全依赖 `GetMaterialApp` + `GetPage` 路由全页 push（`lib/app/router/app_pages.dart`），底部切换页是自绘实现。
- **Tabs 自绘。** Material `TabBar` 未使用（仅 `TabBarView` 8 处），标签页由 `core/widgets/scrollable_tab_bar.dart` 自建。
- **入口：** `lib/main.dart:217` 构造 `GetMaterialApp`；主题由 `lib/core/theme/`（`theme.dart`、`app_text_styles.dart`、`app_canvas_scope.dart`、`dynamic_color_adapter.dart`）手工装配，`dynamic_color`+`material_ui` 提供系统动态取色。

## 2. Flutter 内置组件用量（构造次数）

| 层 | 组件（次数） |
|---|---|
| 布局 | SizedBox 817 · Column 287 · Padding 269 · Row 233 · Expanded 199 · Container 193 · Center 79 · Wrap 56 · Stack 53 · Positioned 45 · Align 44 · Flexible 26 |
| 滚动 | SingleChildScrollView 48 · ListView 45 · CustomScrollView 13 · SliverToBoxAdapter 26 · SliverList 6 · ScrollConfiguration 3 · FittedBox 5 |
| 页面骨架 | Scaffold 88 · AppBar 70 |
| 交互 | IconButton 116 · TextButton 103 · InkWell 46 · TextField 42 · ListTile 40 · Tooltip 32 · ElevatedButton 17 · OutlinedButton 8 · Switch 7 · Chip 5 · ExpansionTile 4 · FloatingActionButton 3 |
| 弹窗 | AlertDialog 70 · Dialog 16 · SimpleDialog 3 · showModalBottomSheet 3 |
| 反馈/动画 | CircularProgressIndicator 47 · LinearProgressIndicator 20 · SnackBar 11 · AnimatedOpacity 17 · AnimatedContainer 14 · AnimatedSwitcher 4 · AnimatedBuilder 6 |
| 其他 | ClipRRect 21 · GestureDetector 18 · DecoratedBox 17 · MouseRegion 10 · TabBarView 8 · SelectableText 6 · Slider 6 · ImageFiltered 3 |

零使用（值得注意的"没有"）：`NavigationBar`、`BottomNavigationBar`、`Drawer`、`TabBar`、`PopupMenuButton`、`DropdownButton`、`Hero`、`NestedScrollView`、`ReorderableListView`、`Dismissible`、`Stepper`、`DataTable`、`Autocomplete`。

## 3. 第三方 UI 包（声明 → 实际用量）

表中"文件数"为 `import 'package:<pkg>/...'` 的文件数，"次数"为组件名出现次数。

| 包 | 用途 | 文件数 | 关键组件次数 |
|---|---|---|---|
| remixicon | 主图标库 | **74** | 全库主力图标来源 |
| cached_network_image | 网络图片 | 9 | — |
| flex_color_picker | 颜色选择器 | 5 | ColorPicker 1 |
| waterfall_flow | 瀑布流布局 | 3 | WaterfallFlow 3（直播间列表） |
| syncfusion_flutter_sliders | 滑块 | 3 | SfSlider 3 |
| markdown_widget | Markdown 渲染 | 3 | 3（公告/说明页） |
| dynamic_color + material_ui | 系统动态取色 | 2 + 3 | 喂 `ColorScheme` |
| qr | 二维码矩阵 | 2 | 2（B 站扫码登录，绘制自绘） |
| loading_indicator | 加载动画 | 2 | LoadingIndicator **68** |
| loading_animation_widget | 加载动画 | 2 | 40 |
| flutter_spinkit | 加载动画 | 2 | 2 |
| flutter_smart_dialog | 全局自定义弹窗 | 2 | SmartDialog 6 |
| easy_refresh | 下拉刷新/上拉加载 | 1 | EasyRefresh 9 |
| scroll_animator | 滚动动画 | 1 | — |
| flutter_reorderable_grid_view | 拖拽排序 | 1 | 1（频道排序） |
| photo_view | 图片查看 | 1 | PhotoView 1 |
| flutter_svg | SVG 渲染 | 1 | SvgPicture 2 |
| flutter_color | 颜色工具 | 1 | — |
| media_core_ui | 播放器 UI | 1 | 随 media_core 17 子包链路 |

图标体系实际是三层：remixicon（主力）+ `core/widgets/custom_icons.dart` 自打包字体（FlutterIcon.com 生成，含 Font Awesome 子集）+ `font_awesome_flutter`（声明但未直接使用）。

加载动画三家并存（68 / 40 / 2），没有统一收口。弹窗体系三轨并行：Material `AlertDialog`（70）为主、`SmartDialog`（6）做全局弹窗、`GetSnackBar`（9）做轻提示。

## 4. 自建组件库 `lib/core/widgets`（25 个）

`common_avatar`、`empty_view`、`refresh_indicators`、`section_list_tile`、`scrollable_tab_bar`、`menu_button`、`count_button`、`search_button`、`qr_code_widget`、`app_prompt_dialogs`、`app_status_view`、`common_appbar_actions`、`keep_alive_wrapper`、`snackbar_util`、`toast_util`、`fitting_sheet_body`、`download_apk_dialog`、`download_directory_dialog`、`share_command_import_dialog`、`adaptive_refresh_rate_scope`、`pure_live_scroll_physics`、`pure_live_scroll_controller`、`widget_extensions`、`custom_icons`。

这一层就是 v2 `live_uikit` 通用组件的单体前身：职责相同（空态、刷新、头像、提示、滚动定制），但全部硬编码 Material，无 token/adapter 分层。

## 5. 领域 UI

- **播放器**：`media_core` 17 子包（含 `media_core_ui`、`media_core_danmaku` + `flame_barrage` 弹幕引擎）+ `lib/core/player/presentation`（`pip_window_widget`、`fullscreen_window`、`windows_pip_driver`、`player_danmaku_surface`）+ `lib/domains/live/presentation/playback/widgets/video_player/`（`video_controller_panel`、`volume_control`、`playback_failure_overlay`、`video_loading`、`iptv_schedule_dialog`、`portrait_playback_picker_dialog` 等 12 个组件）。
- **房间卡片**：`domains/live/presentation/widgets/`（`room_card`、`room_card_layout`、`platform_tab`）。
- **桌面窗口**：`window_manager`（窗口控制/PiP）、`flutter_acrylic`（亚克力毛玻璃）、`tray_manager`（系统托盘）、`windows_single_instance`，收口在 `lib/core/platform/desktop_manager.dart` 与 `desktop_tray_service.dart`。

## 6. 空声明依赖（pubspec 声明但 lib 零引用）

`lottie`、`font_awesome_flutter`、`scrollview_observer`、`animated_splash_plus` —— 四个包在 `lib/` 内连组件名都搜不到。启动页实际是自绘路由页（`RoutePath.kSplash`），并非 animated_splash_plus。

## 7. 对 v2 `live_uikit` 的对照观察

**可借鉴的正面信号：**

- 组件需求面清晰：卡片、空态、刷新、提示、颜色选择、瀑布流、滑块、二维码、拖拽排序、加载动画——这些就是旧版真实消耗过的组件清单，v2 组件集的优先级可直接参考第 2–4 节的用量分布。
- `AlertDialog` 占弹窗绝对大头（70/90+），说明"对话框 + 确认/表单"是核心交互，v2 适配器层的 button/dialog builder 优先级应最高。
- 自建 `core/widgets` 的 25 个组件语义可平移成 v2 token 驱动组件的需求来源。

**反面清单（v2 已决策规避，此处留档）：**

- 单一 Material 硬编码，无设计语言抽象 → v2 以 seed token + style adapter 解耦。
- 弹窗三轨并行、loading 三家并存 → v2 收口到适配器单一入口。
- 常驻导航壳缺失、Tabs 自绘 → v2 由各风格 adapter 提供导航/标签组件。
- 空声明依赖四个 → v2 依赖入包即用，不留死依赖。
