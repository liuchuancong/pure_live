# 依赖与接口审计

最近核验日期：2026-08-23

## 固定工具链

- Flutter 3.47.0 / Dart 3.13.0（`.fvmrc`）。
- Android compileSdk/targetSdk 37，Java 25 构建运行时，Java/Kotlin 17 字节码目标，AGP 9.3.1，Gradle 9.5.0。
- Google Services Gradle Plugin 4.5.0。
- FFmpeg Kit Extended Flutter 0.6.0，按插件配置解析 builders v0.11.0，并复用经过 SHA-256 校验的 Android/Windows Native Assets 共享缓存。

Android 已启用 AGP 9 Built-in Kotlin。主应用、`flv_lzc` 以及六个仍使用独立 KGP 的插件已完成本地迁移，根设置不再声明或应用 `org.jetbrains.kotlin.android`。当前 Flutter 3.47 的通用依赖检查会把 AGP 自带编译器套用到独立 KGP 最低版本规则，因此 Gradle 属性跳过该项误判，同时由 `tool/audit_built_in_kotlin.py` 固定检查 AGP/Gradle 下限、开关和全部本地模块；实际 release 编译继续作为最终门禁。

AGP 9.3.1 是当前 9.3 稳定补丁，官方兼容表给出的默认 Gradle 为 9.5.0；仓库保持该验证组合。Google Services 4.5.0 与 Firebase 当前官方设置文档一致。Gradle 独立发行线虽已有更新版本，但不越过 AGP/Flutter 已验证默认组合做孤立升级。

`flutter pub outdated` 已于 2026-08-23 再次复核。`scrollview_observer` 从 1.27.0 更新至 1.27.1；更新后没有已撤回、已停止维护或命中公开 advisory 的直接依赖。`dynamic_color` 1.9.0 是当前 Flutter Material `ColorScheme` 可直接使用的最新系列；2.x 已把公开类型迁移到独立 `material_ui.ColorScheme`，全应用主题迁移前保持 1.9.0。其余可见更新均由 Flutter SDK或上游约束锁定，保持依赖解析器给出的兼容组合，不使用破坏播放器组合的强制覆盖。

播放器依赖在 v2.6.0 再次单独核验：`better_player_plus` 为 1.3.5 的 Built-in Kotlin 本地快照；项目使用的 `Predidit/media-kit` 修订分支仍固定到 `994465d9bfca3f39d0b41199d16e7fd93fe97881`，`media_kit_video` 使用包含 Surface/音频模式生命周期修复的仓库副本。`pub outdated` 中其余较新版本均为当前 Flutter SDK 或上游依赖约束锁定的传递包，未用强制 override 破坏播放器组合兼容性。

## 可复现依赖

- 应用提交 `pubspec.lock`，所有 hosted 包锁定具体版本。
- hosted 包来源已统一为官方 `https://pub.dev`，本地与 GitHub Actions 均使用 `flutter pub get --enforce-lockfile`，避免仅因镜像 URL 不同重写整份锁文件。
- `flame_barrage 0.0.4` 暂存于 `plugins/flame_barrage`，仅修补引擎移动时忽略逐条速度的问题并保留原许可证；上游发布等效修复后再恢复 hosted 依赖。
- `plugins/built_in_kotlin/` 保存 `better_player_plus 1.3.5`、`floating 6.0.0`、`flutter_exit_app 2.1.2`、`flutter_js 0.8.7`、`mobile_scanner 7.4.0` 和 `share_handler_android 0.0.11` 的源快照，仅迁移 Android 构建脚本并保留上游许可证；上游发布 Built-in Kotlin 版本后逐项恢复 hosted 依赖。
- `media_kit`、`screen_retriever`、`dart_quickjs` 固定到已复核的完整 Git 提交；网页内核同步上游锁定到 `guide-inc-org/guide-flutter_inappwebview` 的 `sbi_fx_pc/v6.2.0-beta.3`（解析提交 `3e6c4c4a`），覆盖 Android、iOS、macOS 与 Windows。Android 子包保留同一提交的 Dart/Java 实现，并在 `plugins/built_in_kotlin/flutter_inappwebview_android` 修正 AGP 9 默认 ProGuard 文件、模块私有 AGP classpath 和 Java 17 目标。Linux 的网页搜索使用系统浏览器，避免额外 WPE WebKit 原生依赖。
- 2026-08-23 重新执行远端引用核对：`Predidit/media-kit@994465d9`、`liuchuancong/screen_retriever@b246b396`、`liuchuancong/dart_quickjs@0596dfce` 均仍是各自远端 HEAD；网页内核目标分支仍解析到 `3e6c4c4a`。
- Windows 单实例插件同步上游恢复为 hosted `windows_single_instance 1.2.0`，删除仓库内旧副本；`file_picker` 使用稳定版 12.0.0 API。
- `flv_lzc` 固定自上游 `030d611` 并存放在 `plugins/flv_lzc`；仅移除 Android 注册阶段的临时 `SurfaceTexture` 探测，规避 Flutter 3.47 平台纹理注册断言，保留上游许可证和来源说明。
- Android 本地构建会预取并校验 MediaKit arm64 库与 FFmpeg Kit v0.11.0 AAR；质量门禁和 Windows 构建会单独预取同版本 Windows ZIP。两者预先写入 Native Assets 共享缓存，避免 Windows Dart 下载器在 GitHub Release 重定向处长时间等待。
- 删除已停止作用的 `sqlite3_flutter_libs`；项目使用 `sqlite3` 3.x 的 Native Assets。
- 升级 `app_links`、`connectivity_plus`、`pro_mpack` 与 Syncfusion sliders，并通过静态分析和完整测试。
- GitHub Actions 固定到已核验的完整提交 SHA，Dependabot 每月汇总检查 pub、Gradle 和 Actions 更新；日常分支推送不构建，仅手动入口或显式阶段标签按平台运行。
- 当前锁定的 Predidit Linux `libmpv` 需要 glibc 2.38 与 GLIBCXX 3.4.32，因此 Linux 作业固定使用 Ubuntu 24.04；Ubuntu 22.04 链接失败属于二进制基线不匹配，而非缺少单个开发包。

## 直播接口探测

运行：

```powershell
python .\tool\interface_probe.py
```

当前脚本共检查 26 项：Bilibili、Douyu、Huya、Kuaishou、Douyin、网易 CC、Twitch、SOOP Live 的公开分类/推荐入口、搜索、Bilibili 弹幕节点、Huya 弹幕注册身份、Twitch 房间元数据与播放令牌，以及 SOOP 房间元数据和播放令牌。v2.6.0 发布时的结果写入阶段文档；另外保留 Windows release 的 Douyu 2K60 直播和实时弹幕持续接收样本。Android 弹幕恢复默认由协议、生命周期和通知顺序自动化回归覆盖；设备复核只在当前任务明确安排时追加。

虎牙另提供 `python .\tool\huya_danmaku_probe.py` 实时 WebSocket 回归；2026-08-16 已验证注册、新版心跳和真实推送接收。该项依赖当前直播间与平台网关状态，保留为发布前手动检查。

接口属于外部服务，任何时刻都可能变化；发布前应重新运行探测，并按发布计划选择本地桌面运行或独立设备播放验收。

返回 [文档索引](README.md)。
