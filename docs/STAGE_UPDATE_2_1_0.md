# Pure Live v2.1.0 阶段更新

本阶段将维护分支的弹幕、性能、播放、助眠、本地互动与发布工程整合为一个可向上游审阅的大版本，同时同步 `liuchuancong/pure_live` 在 2026-08-17 的最新提交。

## 上游同步

- 合并上游 Twitch 平台、账号 Cookie 页面、原生搜索、直播详情、播放清晰度和 IRC 弹幕。
- 合并 `file_picker 12.0.0` 稳定 API、`windows_single_instance 1.2.0` 与 `flutter_inappwebview_ultra 1.0.0`。
- 合并默认音量百分比修正、网页关闭清理、字体初始化顺序和弹幕纯文字模式。
- 保留维护分支已验证的统一 px/s 弹幕速度、动态刷新率、积压淘汰、会话隔离、小窗实时预览和 AGP 9 Built-in Kotlin 迁移。

## Twitch 完整接入

- Twitch 已进入平台目录、链接识别、分类、推荐、频道搜索、直播详情、清晰度、外部打开、录制配色和账号设置。
- 目录、搜索与房间返回的 `viewersCount` 明确存为并发观看人数，可加入“真实在线人数优先”排行。
- IRC 解析保留完整显示名、用户 ID、消息 ID、平台时间和无颜色用户；断线继续复用统一的单连接、有界重连实现。
- 本地互动新增 Twitch 徽章、Bits、订阅等级、Cheer、订阅星标和 Hype Train 体验包。
- 20 项接口探测加入 Twitch 分类、目录、搜索、房间和播放令牌校验。

## 弹幕与设置

- 主画面和小窗分别提供“纯文字模式”，过滤图集表情；开关实时作用于画面。
- 小窗设置预览同步展示纯文字模式，手机继续保持上方固定预览、下方独立滚动参数。
- 兼容上游早期 `pipDanmaNoEmojiMode` 存储键，备份统一导出为 `pipDanmakuNoEmojiMode`。

## 构建矩阵

| 平台 | 架构 | 产物 | 验证方式 |
| --- | --- | --- | --- |
| Android | arm64-v8a | 正式包名 APK | Windows 本机签名构建、ADB 覆盖安装与启动探测 |
| Windows | x64 | 便携 ZIP / 可选 EXE | Windows 本机构建与进程/窗口启动探测 |
| Linux | x64 | `tar.gz` 便携包 | Ubuntu 22.04 手动工作流编译 |
| macOS | arm64 | `.app` ZIP | macOS 15 手动工作流编译 |
| iOS | arm64 device | 无签名 `.app` ZIP | macOS 15 `flutter build ios --no-codesign` |

Android 与 Windows 优先使用本机 5090 环境，Apple 平台仅使用一次 macOS 作业同时构建，以控制 Actions 用量。五平台开关均为手动触发，日常提交不会自动消耗构建分钟。

当网页手动调度入口受 GitHub API 状态影响时，可显式推送 `stage-build-*` 标签；该标签只补建 Linux、macOS 与 iOS，Android/Windows 仍保留本机构建，不会让普通分支提交自动运行。

## 回归门禁

1. `tool/local_ci.ps1`：锁定依赖、Built-in Kotlin 审计、格式、Analyze、完整测试、20 项接口探测。
2. `tool/build_local_release.ps1 -RequireReleaseSigning`：Android arm64 与 Windows x64 正式产物。
3. `tool/install_android_local.ps1`：连接设备覆盖安装、冷启动与前台窗口检查。
4. `manual-build`：Linux、macOS、iOS 编译与短期构建归档。

本阶段本机门禁结果：Built-in Kotlin 审计与 Flutter Analyze 零问题、63 项单元/Widget 测试通过、20/20 平台接口探测通过。

返回 [文档索引](README.md)。
