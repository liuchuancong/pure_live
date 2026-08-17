# 依赖与接口审计

最近核验日期：2026-08-17

## 固定工具链

- Flutter 3.47.0 / Dart 3.13.0（`.fvmrc`）。
- Android compileSdk/targetSdk 37，Java 25 构建运行时，Java/Kotlin 17 字节码目标，AGP 9.3.1，Gradle 9.5.0。
- Google Services Gradle Plugin 4.5.0。
- FFmpeg Kit Extended Flutter 0.5.13，按插件配置解析 builders v0.10.5，并复用 Native Assets 共享缓存。

Android 已启用 AGP 9 Built-in Kotlin。主应用、`flv_lzc` 以及六个仍使用独立 KGP 的插件已完成本地迁移，根设置不再声明或应用 `org.jetbrains.kotlin.android`。当前 Flutter 3.47 的通用依赖检查会把 AGP 自带编译器套用到独立 KGP 最低版本规则，因此 Gradle 属性跳过该项误判，同时由 `tool/audit_built_in_kotlin.py` 固定检查 AGP/Gradle 下限、开关和全部本地模块；实际 release 编译继续作为最终门禁。

`flutter pub outdated` 已于 2026-08-17 再次复核。所有直接运行时依赖处于当前上游最新版、项目固定 Git 提交或本地兼容补丁；报告中的 8 项更新均属于 Flutter SDK 或当前上游约束锁定的传递依赖，当前锁定版本未受已知 pub 安全公告影响。完整 Android release 日志中已无第三方插件应用 KGP 的迁移警告。

播放器依赖在 v2.0.33 再次单独核验：`video_player` 锁定到 2.14.0，`better_player_plus` 为 1.3.5；项目使用的 `Predidit/media-kit` 修订分支 HEAD 仍为 `994465d9bfca3f39d0b41199d16e7fd93fe97881`。`pub outdated` 中其余较新版本均为当前 Flutter SDK 或上游依赖约束锁定的传递包，未用强制 override 破坏播放器组合兼容性。

## 可复现依赖

- 应用提交 `pubspec.lock`，所有 hosted 包锁定具体版本。
- `flame_barrage 0.0.4` 暂存于 `plugins/flame_barrage`，仅修补引擎移动时忽略逐条速度的问题并保留原许可证；上游发布等效修复后再恢复 hosted 依赖。
- `plugins/built_in_kotlin/` 保存 `better_player_plus 1.3.5`、`floating 6.0.0`、`flutter_exit_app 2.1.2`、`flutter_js 0.8.7`、`mobile_scanner 7.4.0` 和 `share_handler_android 0.0.11` 的源快照，仅迁移 Android 构建脚本并保留上游许可证；上游发布 Built-in Kotlin 版本后逐项恢复 hosted 依赖。
- `media_kit`、`flutter_inappwebview`、`screen_retriever`、`dart_quickjs` 均固定到 2026-08-16 复核的完整 Git 提交，不跟随可变分支。
- `flv_lzc` 固定自上游 `030d611` 并存放在 `plugins/flv_lzc`；仅移除 Android 注册阶段的临时 `SurfaceTexture` 探测，规避 Flutter 3.47 平台纹理注册断言，保留上游许可证和来源说明。
- Android 本地构建会预取并校验 MediaKit arm64 库与 FFmpeg Kit AAR；后者预先写入 Native Assets 共享缓存，避开 Windows Dart 下载器在 GitHub Release 重定向处长时间等待。
- 删除已停止作用的 `sqlite3_flutter_libs`；项目使用 `sqlite3` 3.x 的 Native Assets。
- 升级 `app_links`、`connectivity_plus`、`pro_mpack` 与 Syncfusion sliders，并通过静态分析和完整测试。
- GitHub Actions 固定到已核验的完整提交 SHA，Dependabot 每月汇总检查 pub、Gradle 和 Actions 更新；工作流仍仅手动运行，不因依赖检查消耗构建分钟。

## 直播接口探测

运行：

```powershell
python .\tool\interface_probe.py
```

当前脚本共检查 15 项：Bilibili、Douyu、Huya、Kuaishou、Douyin、网易 CC 的公开分类/推荐入口、Douyu/Huya/CC 搜索、Bilibili WBI 签名与弹幕节点，以及 Huya 当前弹幕注册所需的直播间数字 `uid`。弹幕认证回应、登录态清晰度和实际 CDN 播放仍需在应用内用真实直播间验证。

虎牙另提供 `python .\tool\huya_danmaku_probe.py` 实时 WebSocket 回归；2026-08-16 已验证注册、新版心跳和真实推送接收。该项依赖当前直播间与平台网关状态，保留为发布前手动检查。

接口属于外部服务，任何时刻都可能变化；发布前应重新运行探测并执行真机播放回归。

返回 [文档索引](README.md)。
