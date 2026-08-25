# v3.0.0 全平台稳定版

- 版本：`3.0.0+4087`
- 维护仓库：`wzgrx/pure_live`
- 上游基线：`liuchuancong/pure_live@c22ae2f4`
- 发布日期：2026-08-25

## 本轮范围

- 通过连续真实 merge 把上游从 `974f4c32` 同步到发布冻结点 `c22ae2f4`，保留共同祖先和维护分支历史。
- 合并上游关注页/热门页状态绑定、无效关注房间清理与 Android ABI 版本管理；额外按平台 ID 保留关注平台选择，防止配置重排后显示与筛选错位。
- 启动、备份恢复和显式清理统一拒绝空平台、空/占位房间号并按平台内房间身份去重，补充备份提取回归，避免损坏历史记录进入刷新链路。
- 合并上游播放器生命周期串行化、移动端视频画面适配和录制初始化调整；采用 `resolvePlayUrlsRaw` 分离底层能力与统一扩展，修复 Bilibili 线路解析递归堆栈。
- 修复 #791 Android 录制链路：统一请求头、补齐斗鱼反盗链信息、重新解析过期 CDN、引用 FFmpeg 参数、允许短时单轨输入、清理目录组件并降低高频持久化开销。
- 修复正式发布工作流的 Windows artifact Action 无效 SHA，固定第三方 Action 完整提交，并阻止任一请求平台失败后创建不完整 Release。
- 修复 Windows 长路径本机构建的 Kotlin 增量缓存跨盘回退：优先使用与 Pub 缓存同盘的稳定短路径目录联接，保留 `SUBST` 兼容后备。
- 修复 Windows Firebase C++ SDK 大文件下载中断及旧 `extracted` 目录串版：增加续传、长度/ZIP/SHA256/版本头校验，并显式绑定 13.11.0 SDK。
- 保持 `wzgrx/pure_live` 为应用内更新、版本历史和下载源；上游仓库地址只用于源码基线与贡献链接。
- 修复上游 #793、#794、#797：Windows 重复启动在 native engine 前拦截、PiP 前后恢复全屏/宽屏表达状态、跨房间清理旧视频宽高避免横竖屏比例串联。
- 修复上游 #798：YY 对齐当前 StreamManager 合同，并为被 HTTP 路由拒绝但官方匿名 HLS 可播的频道增加自动回退和实际流去重。
- 复核所有直接依赖、Git 固定提交、Gradle/AGP/Flutter 组合和 41 项公开平台接口合同。

## 依赖结论

- Flutter `3.47.0` / Dart `3.13.0`，AGP `9.3.1`，Gradle `9.5.0`，compileSdk/targetSdk 37，Java 25 构建运行时与 Java/Kotlin 17 字节码目标保持不变。
- 上游把 hosted 来源切换到 `https://pub.dev` 后遗留的镜像归档哈希已由官方解析器重建，`flutter pub get --enforce-lockfile` 可复现。
- `flutter pub outdated` 中唯一可见的直接大版本为 `dynamic_color 2.1.0`；该版本把 Flutter Material `ColorScheme` 更换为独立 `material_ui.ColorScheme`，属于全应用主题迁移而非补丁升级，v3.0.0 保持 1.9.0。
- 其他更新是 Flutter SDK或当前插件约束锁定的传递包，没有通过 override 强制破坏播放器、Native Assets 或代码生成组合。

## Issue 处理

- #791：本轮完整修复。
- #793、#794、#797、#798：本轮完成代码修复与确定性/接口回归。
- #795、#796：录制目录选择、写入探测、应用子目录隔离及斗鱼录制请求头/重试链路已覆盖。
- #786、#783：此前修复继续由接口/渲染测试覆盖。
- #767：viewport 纹理限制与测试已在当前分支；原生视频平面列为架构优化。
- #789：确认是独立功能请求，详见 `ISSUE_AUDIT_2026_08_25.md`。

## 质量与构建证据

- 定向录制回归：请求头、FFmpeg命令、重试策略和目录策略通过。
- 上游状态回归：关注平台身份保持、Release ABI和热门排序测试通过。
- Flutter Analyze 在发布冻结源码上完成，结果为 `No issues found`；完整 Flutter 测试共 `385/385` 通过，覆盖页面刷新、播放器/音频模式、PiP、弹幕生命周期、画质事务、录制、搜索、热度/在线人数和 Windows 窗口状态。
- 完整门禁记录 `local-artifacts/build-records/20260825T090433062Z-quality-full.json` 用时 533.293 秒，Analyze 与完整测试均通过；随后抖音搜索公开端点短暂返回 HTTP 503，使该次在线探针以 `40/41` 结束。
- 为在线合同增加同 Cookie 会话下的有界瞬态重试后，`local-artifacts/build-records/20260825T090730487Z-interface-probe-final.json` 在 51.491 秒内 `41/41` 通过；重试不掩盖持续失败，耗尽三次后仍保留原始错误。
- 各平台产物、字节数与 SHA-256 由串行构建工作流写入 Release 校验清单，避免发布后再改动冻结源码提交。
- 本轮遵循 `BUILD_POLICY.md`：完整门禁一次；Android、Windows 和托管平台按阶段串行；没有执行 ADB 或手机操作。

## 目标产物

| 平台 | 目标产物 | 架构/说明 |
|---|---|---|
| Android | `PureLive-3.0.0-4087-android-arm64-v8a-release.apk` | arm64-v8a，正式签名 |
| Windows | `PureLive-3.0.0-4087-windows-x64-setup.exe` / `.msix` | Windows 10/11 x64 |
| Linux | `PureLive-3.0.0-4087-linux-x64.tar.gz` | Ubuntu 24.04 构建基线 |
| macOS | `PureLive-3.0.0-4087-macos-universal.zip` / `.dmg` | Apple Silicon + Intel |
| iOS | `PureLive-3.0.0-4087-ios-arm64-unsigned-app.zip` / `trollstore.ipa` | arm64 |

## 验证边界

- 自动化测试验证可重复的状态/解析合同，公开探测验证发布时接口可达性；平台风控、登录态、具体直播间和 CDN仍可能随时变化。
- Android 实机安装与特定 OEM 后台策略不属于本轮自动化操作；Release APK供用户独立覆盖安装验收。

返回 [文档索引](README.md)。
