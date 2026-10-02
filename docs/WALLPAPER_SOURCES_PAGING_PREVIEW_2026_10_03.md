# 背景设置：随机图源迁移与分页/预览重构（2026-10-03）

参照 TV 分支 `pure_live_TV/lib/features/wallpaper`，把「很多源」的背景设置能力
迁移进本仓库，并按本仓库的分层与 GetX 约定重写。代码提交：

- `5d29713b` 随机图源数据层（源表、随机取图、字节入库）
- `813123a6` 背景设置分入口 + 自动续页网格 + 全屏预览

## 迁移内容

| TV 侧 | 本仓库落点 |
| --- | --- |
| `wallpaper_api_source.dart`（7 组、约 100 个随机图源） | `lib/domains/wallpaper/domain/wallpaper_api_catalog.dart` |
| `fetchRandomImage` / JSON 信封解析 / 魔术字节校验 | `lib/domains/wallpaper/data/wallpaper_api_client.dart` |
| `wallpaper_video.dart` 的视频工具 | 已在 `lib/domains/wallpaper/data/wallpaper_media_store.dart`（此前迁移） |
| `wallpaper_paging.dart`（客户端 24/页 + serverAll/serverFixedSize） | `lib/domains/wallpaper/presentation/wallpaper_grid_controller.dart` |
| `wallpaper_preview_page*.dart` | `lib/domains/wallpaper/presentation/wallpaper_preview_page.dart` |
| `wallpaper_page.dart` 四入口结构 | `lib/domains/wallpaper/presentation/wallpaper_page.dart` |
| `wallpaper_tile.dart` / `wallpaper_image.dart` / `wallpaper_display_options.dart` | 同名文件位于 `presentation/` |

纯色（151 项：12 个平色 + 139 个渐变）与动态壁纸（iTab `/wallpaper/video/list`）
此前已在仓库中，本次给它们独立入口与统一预览：来源分类树、网格、预览三层
共用同一份数据与控制器。

## 分页规则（本次改动的核心）

- 客户端步长固定 `kWallpaperClientPageSize = 24`；服务端页大小仍按来源
  （官方/Wallhaven 24，必应 16）请求，取回的页进入只增不减的缓冲区，
  网格每次从缓冲区切 24 条。
- 滚动到底部前 600px 自动续页；首屏不满一屏时继续补齐，避免「看起来没有更多」。
- 编译进来的来源（纯色、deepin）不走网络，直接本地切片。
- 控制器按 `(来源, 分类)` 缓存，网格与预览共用；网格出栈时释放，缓存有界。
- 原「加载更多」按钮与内嵌 `WallpaperLibraryView` 已删除。

## 预览页

上一张/下一张（走到缓冲区末尾会自动续页）、换一张（随机图源）、填充模式/
模糊/遮罩循环、视频播放暂停、设为背景。**应用动作只发生在预览页**，浏览网格
不再一点就换背景。随机图源只有字节、没有 URL，落盘后再按本地图片应用。

## 验证与边界

- `flutter analyze --no-pub`：无问题。
- `tool/validate_architecture.py --strict`：0 未批准违规、21 已批准、0 过期条目。
- 仓库 `test/` 为空，本次没有可跑的 Dart/Widget 测试；静态检查覆盖编译与分层。
- 仍需真机自测：随机图源的取图成功率（各 API 可用性会随时间变化）、
  视频壁纸下载与播放、续页节奏、以及取消/退出时的解码器释放。
