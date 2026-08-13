# 依赖与接口审计

最近核验日期：2026-08-13

## 固定工具链

- Flutter 3.44.9 / Dart 3.12.2（`.fvmrc`）。
- Android compileSdk/targetSdk 36，JDK 17，AGP 8.11.1，Gradle 8.14，Kotlin 2.2.20。
- Google Services Gradle Plugin 4.5.0。
- FFmpeg Kit Extended Flutter 0.5.13，桌面/Android 产物固定到 builders v0.10.5。

AGP、Gradle 和 Kotlin 不按“最新数字”单独升级，而与 Flutter 3.44.9 的模板兼容矩阵一起升级。`permission_handler` 暂留 12.x，因为 13.x 要求 compileSdk 37。

`flutter pub outdated --json` 已核对所有直接依赖，当前结果没有被 pub 标记为已撤回或受已知安全公告影响的版本。未跟随最高版本的直接依赖均有约束原因：`meta` 由当前 Flutter SDK 固定，`build_runner` 的新版本需要更高 Dart SDK，`permission_handler` 13.x 需要 compileSdk 37，`xml` 7.x 被当前 WebDAV 依赖约束在 6.x。它们应随下一次 Flutter/Android 工具链升级一起复测，而不是单包强制覆盖。

## 可复现依赖

- 应用提交 `pubspec.lock`，所有 hosted 包锁定具体版本。
- `media_kit`、`flv_lzc`、`screen_retriever`、`dart_quickjs` 均固定完整 Git 提交，不再跟随可变的 `main`。
- 删除已停止作用的 `sqlite3_flutter_libs`；项目使用 `sqlite3` 3.x 的 Native Assets。
- 升级 `app_links`、`connectivity_plus`、`pro_mpack` 与 Syncfusion sliders，并通过静态分析和完整测试。
- GitHub Actions 固定到已核验的完整提交 SHA，Dependabot 每月汇总检查 pub、Gradle 和 Actions 更新；工作流仍仅手动运行，不因依赖检查消耗构建分钟。

## 直播接口探测

运行：

```powershell
python .\tool\interface_probe.py
```

探测 Bilibili、Douyu、Huya、Kuaishou、Douyin、网易 CC 的公开分类/推荐入口及关键 JSON/HTML 字段。Bilibili WBI 签名接口、登录态清晰度、弹幕 WebSocket 和实际 CDN 播放仍需在应用内用真实直播间验证。

接口属于外部服务，任何时刻都可能变化；发布前应重新运行探测并执行真机播放回归。

返回 [文档索引](README.md)。
