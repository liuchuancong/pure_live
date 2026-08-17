# Pure Live v2.1.0 阶段更新

本阶段将维护分支的弹幕、性能、播放、助眠、本地互动与发布工程整合为一个可向上游审阅的大版本，同时同步 `liuchuancong/pure_live@24ff92b6`（2026-08-18）。

## 上游同步

- 合并上游 Twitch 与 SOOP Live 平台、账号 Cookie 页面、原生搜索、直播详情、播放清晰度和弹幕协议。
- 合并 `file_picker 12.0.0` 稳定 API、`windows_single_instance 1.2.0`，并迁移到上游锁定的 `flutter_inappwebview 6.2.0-beta.3` 修订分支。
- 合并默认音量百分比修正、网页关闭清理、字体初始化顺序和弹幕纯文字模式。
- 保留维护分支已验证的统一 px/s 弹幕速度、动态刷新率、积压淘汰、会话隔离、小窗实时预览和 AGP 9 Built-in Kotlin 迁移。

## Twitch 与 SOOP Live 完整接入

- Twitch 已进入平台目录、链接识别、分类、推荐、频道搜索、直播详情、清晰度、外部打开、录制配色和账号设置。
- 目录、搜索与房间返回的 `viewersCount` 明确存为并发观看人数，可加入“真实在线人数优先”排行。
- IRC 解析保留完整显示名、用户 ID、消息 ID、平台时间和无颜色用户；断线继续复用统一的单连接、有界重连实现。
- 本地互动新增 Twitch 徽章、Bits、订阅等级、Cheer、订阅星标和 Hype Train 体验包。
- SOOP Live 已接入分类、推荐、搜索、房间信息、播放线路、Cookie、弹幕、链接识别、录制配色、并发在线人数与本地互动资源包。
- SOOP 播放令牌按真实房间广播编号生成，播放线路并发读取且过滤空地址；多平台详情回退路径同步移除空房间强制解引用。
- 25 项接口探测覆盖 Twitch 分类、目录、搜索、房间、播放令牌，以及 SOOP 分类、推荐、搜索、房间和播放令牌。

## 弹幕与设置

- 主画面和小窗分别提供“纯文字模式”，过滤图集表情；开关实时作用于画面。
- 小窗设置预览同步展示纯文字模式，手机继续保持上方固定预览、下方独立滚动参数。
- 兼容上游早期 `pipDanmaNoEmojiMode` 存储键，备份统一导出为 `pipDanmakuNoEmojiMode`。

## 构建矩阵

| 平台 | 架构 | 产物 | 验证方式 |
| --- | --- | --- | --- |
| Android | arm64-v8a | 正式包名 APK | Windows 本机签名构建、ADB 覆盖安装与启动探测 |
| Windows | x64 | 便携 ZIP / 可选 EXE | Windows 本机构建与进程/窗口启动探测 |
| Linux | x64 | `tar.gz` 便携包 | Ubuntu 24.04 阶段工作流编译与 ELF x86-64 核验 |
| macOS | universal | `.app` ZIP | macOS 15 编译，主程序含 x86_64 与 arm64 |
| iOS | arm64 device | 无签名 `.app` ZIP | macOS 15 `flutter build ios --no-codesign` |

Android 与 Windows 优先使用本机 5090 环境，Apple 平台仅使用一次 macOS 作业同时构建，以控制 Actions 用量。五平台支持手动选择；显式阶段标签只补建指定平台，日常分支提交不会自动消耗构建分钟。

阶段标签可按平台精确补建：`stage-linux-*` 只构建 Linux，`stage-ios-*` 只构建 iOS，`stage-apple-*` 在同一 macOS Runner 构建 macOS 与 iOS；`signed-build-*` 只补建正式签名 Android arm64。普通分支提交不自动运行这些作业。

## 回归门禁

1. `tool/local_ci.ps1`：锁定依赖、Built-in Kotlin 审计、格式、Analyze、完整测试、25 项接口探测。
2. `tool/build_local_release.ps1 -RequireReleaseSigning`：Android arm64 与 Windows x64 正式产物。
3. `tool/install_android_local.ps1`：连接设备覆盖安装、冷启动与前台窗口检查。
4. `manual-build`：Linux、macOS、iOS 编译与短期构建归档。

正式签名 APK 默认通过本机临时 Runner 注入 GitHub Secrets；`signed-build-*` 标签仅用于临时 Runner 服务异常时的一次托管构建回退。

本阶段本机门禁结果：Built-in Kotlin 审计与 Flutter Analyze 零问题、64 项单元/Widget 测试通过、25/25 平台接口探测通过。

## 最终构建验收

- Android arm64 正式签名：[run 32051382539](https://github.com/wzgrx/pure_live/actions/runs/32051382539) 通过；包名 `com.mystyle.purelive`、版本 `2.1.0 (2048)`、单一 `arm64-v8a`，v2 签名证书与 v2.0.36 正式包一致。
- Windows x64 在本机完成便携 ZIP 与 EXE 安装器；程序持续启动 20 秒后进程存活、窗口句柄有效且 UI 线程响应。
- Linux x64：[run 32053307686](https://github.com/wzgrx/pure_live/actions/runs/32053307686) 通过；归档含 1320 项，主程序为 x86-64 PIE ELF。
- macOS universal 与 iOS arm64：[run 32051400058](https://github.com/wzgrx/pure_live/actions/runs/32051400058) 通过；macOS 主程序含 x86_64/arm64，iOS 主程序为 arm64，iOS 归档保持无签名状态。
- 所有正式附件均在本机重新计算 SHA-256；Android、Linux 与 Apple Actions 外层归档摘要和 GitHub Artifact 摘要一致。

返回 [文档索引](README.md)。
