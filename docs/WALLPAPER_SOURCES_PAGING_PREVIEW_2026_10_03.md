# 背景设置：随机图源迁移与分页/预览重构（2026-10-03）

参照 TV 分支 `pure_live_TV/lib/features/wallpaper`，把「很多源」的背景设置能力
迁移进本仓库，并按本仓库的分层与 GetX 约定重写。代码提交：

- `5d29713b` 随机图源数据层（源表、随机取图、字节入库）
- `813123a6` 背景设置分入口 + 自动续页网格 + 全屏预览
- 后续修订：分页改用应用统一分页组件（页码/每页选择），预览页的填充/模糊/
  遮罩改为弹窗选择并去掉底部黑色渐变，背景设置各子页改为透明以露出壁纸。

## 迁移内容

| TV 侧 | 本仓库落点 |
| --- | --- |
| `wallpaper_api_source.dart`（7 组、约 100 个随机图源） | `lib/domains/wallpaper/domain/wallpaper_api_catalog.dart` |
| `fetchRandomImage` / JSON 信封解析 / 魔术字节校验 | `lib/domains/wallpaper/data/wallpaper_api_client.dart` |
| `wallpaper_video.dart` 的视频工具 | 已在 `lib/domains/wallpaper/data/wallpaper_media_store.dart`（此前迁移） |
| `wallpaper_paging.dart` 的分页语义 | `lib/domains/wallpaper/presentation/wallpaper_grid_controller.dart`（改挂 `core/pagination`） |
| `wallpaper_preview_page*.dart` | `lib/domains/wallpaper/presentation/wallpaper_preview_page.dart` |
| `wallpaper_page.dart` 四入口结构 | `lib/domains/wallpaper/presentation/wallpaper_page.dart` |
| `wallpaper_tile.dart` / `wallpaper_image.dart` / `wallpaper_display_options.dart` | 同名文件位于 `presentation/` |

纯色（151 项：12 个平色 + 139 个渐变）与动态壁纸（iTab `/wallpaper/video/list`）
此前已在仓库中，本次给它们独立入口与统一预览：来源分类树、网格、预览三层
共用同一份数据与控制器。

## 分页规则（本次改动的核心）

- 网格不再自写分页，改用应用统一的 `BasePageView`：
  - 编译来源（纯色、deepin）走 `ServerAllPageController`，一次性取回本地表后
    由分页核心切片；
  - iTab 来源走 `ServerFixedPageController`，服务端固定页大小（官方/Wallhaven
    24、必应 16），桌面端正是「刷新 / 上一页 / 页码 / 下一页 / 每页数量 / 跳转」
    的分页条，移动端是下拉刷新 + 触底续页。
  - 每页数量跟随 设置 → 页面 的全局分页设置，不再自带魔法数字。
- 控制器按 `(来源, 分类)` 缓存（`Get.put(tag: ...)`），网格与预览共用；网格
  出栈时 `Get.delete`，缓存有界。
- 原「加载更多」按钮与内嵌 `WallpaperLibraryView` 已删除。

## 预览页

上一张/下一张（桌面端翻到页边界会自动开下一页/上一页，移动端续页）、
换一张（随机图源）、填充模式/模糊/遮罩改为**弹窗选择**（当前值打勾，不再靠
连点循环）、视频播放暂停、设为背景。底部控制栏不再画黑色渐变，壁纸本身保持
完整可见。**应用动作只发生在预览页**，浏览网格不再一点就换背景；随机图源只有
字节、没有 URL，落盘后再按本地图片应用。

## 背景如何贯穿全 App

`AppBackgroundLayer` 画在 Navigator 之后（`main.dart` 的 `MaterialApp.builder`），
但页面默认会用自己的 `scaffoldBackgroundColor` 盖住它，因此在两层之间插了
`WallpaperCanvasTransparency`：有壁纸时它把 `Theme.scaffoldBackgroundColor`
改成透明，所有路由、弹窗、菜单都继承，没壁纸时原样返回同一个 `Theme`（形制
不变，切换壁纸不会重挂 Navigator）。

不能靠改 `GetMaterialApp(theme:)`：GetX 只在启动时读一次该参数
（`GetRootState.didUpdateWidget` 被注释掉了），运行期改主题到不了页面——此前
壁纸只在那几个硬编码透明 `Scaffold` 的背景设置子页里可见就是这个原因。

桌面端壁纸层包住标题栏，图片铺到窗口顶边；标题栏与左侧导航栏保留一层
`kWallpaperSurfaceOpacity`（0.55）的半透明洗色，控件在任何图片上都可读。

页面 chrome（AppBar、左右导航栏、chips、桌面分页条）按
`kWallpaperSurfaceOpacity`（0.55）洗淡；**卡片按 `kWallpaperCardOpacity`
（0.82）**洗得更实——卡片承载正文，既要在图片的亮部/暗部上看起来一致，也要保证
文字对比度。设置页与背景设置页的行卡片（`buildModernCard`）读的就是主题卡片色，
所以两页观感一致。**弹窗、下拉菜单、弹出面板不洗**：它们从 `colorScheme` 取默认
底色，而这条路径特意保持不变——菜单/对话框透出图片只会更难读。改透明度只动上面
两个常量。

页面切换用的是「先淡出、后淡入」的过渡（`WallpaperFadeThroughTransitionsBuilder`）：
旧页面在新页面出现前就完全淡出，中途只剩壁纸。M3 的 fade-forwards 是交叉淡化，
底衬不透明会闪主题色、透明又会让两个半透明页面叠在一起（浅色主题闪白、深色主题
闪黑）。

背景设置的所有子页（壁纸库、分类、网格、随机图源、随机图源分组）也各自用透明
`Scaffold`，与上面的统一机制互为兜底。

## 验证与边界

- `flutter analyze --no-pub`：无问题。
- `tool/validate_architecture.py --strict`：0 未批准违规、21 已批准、0 过期条目。
- `test/domains/`：`area_display_config_test.dart`（5 例）与
  `wallpaper_canvas_transparency_test.dart`（3 例）全部通过。
- 仍需真机自测：随机图源的取图成功率（各 API 可用性会随时间变化）、
  视频壁纸下载与播放、续页节奏、以及取消/退出时的解码器释放。
