# 依赖与接口审计

最近核验日期：2026-08-16

## 固定工具链

- Flutter 3.44.9 / Dart 3.12.2（`.fvmrc`）。
- Android compileSdk/targetSdk 36，JDK 17，AGP 8.11.1，Gradle 8.14，Kotlin 2.2.20。
- Google Services Gradle Plugin 4.5.0。
- FFmpeg Kit Extended Flutter 0.5.13，按插件配置解析 builders v0.10.5，并复用 Native Assets 共享缓存。

AGP、Gradle 和 Kotlin 不按“最新数字”单独升级，而与 Flutter 3.44.9 的模板兼容矩阵一起升级。`permission_handler` 暂留 12.x，因为 13.x 要求 compileSdk 37。

`dart pub outdated --no-dev-dependencies` 已于 2026-08-16 复核。本次升级 `better_player_plus` 1.3.5、`flame_barrage` 0.0.4 和稳定版 `file_picker` 12.0.0，并迁移其单文件选择 API。直接依赖中 `meta` 由当前 Flutter SDK 固定，`permission_handler` 13.x 需要 compileSdk 37，`xml` 7.x 被当前 WebDAV 依赖约束在 6.x；`flutter_json` 0.2.0 留待配置预览页面专项回归。其余直接运行时依赖均处于当前约束的可解析版本。

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

当前脚本共检查 15 项：Bilibili、Douyu、Huya、Kuaishou、Douyin、网易 CC 的公开分类/推荐入口、Douyu/Huya/CC 搜索、Bilibili WBI 签名与弹幕节点，以及 Huya 当前弹幕注册所需的直播间数字 `uid`。弹幕认证回应、登录态清晰度和实际 CDN 播放仍需在应用内用真实直播间验证。

虎牙另提供 `python .\tool\huya_danmaku_probe.py` 实时 WebSocket 回归；2026-08-16 已验证注册、新版心跳和真实推送接收。该项依赖当前直播间与平台网关状态，保留为发布前手动检查。

接口属于外部服务，任何时刻都可能变化；发布前应重新运行探测并执行真机播放回归。

返回 [文档索引](README.md)。
