# 依赖与接口审计

最近核验日期：2026-09-24

## 2026-09-24 全量版本复核与升级进度

- 对照 Flutter 官方 GitHub 稳定标签，将独立工具链从 3.47.0 升至 **3.47.5 / Dart 3.13.4**；旧 SDK 保留以便回滚。
- `flutter pub outdated --json` 显示的 **20 个落后直接/开发依赖全部升级**，锁文件重新解析后共有 49 个包变更。托盘库 0.7.0 不再沿用已弃用的旧接口，改为 `TrayIcon`、`Menu` 与原生事件；菜单对象在应用生命周期内复用。
- 升至 Android Gradle Plugin **9.3.3**（9.3 稳定补丁）和 Gradle **9.7.1**；wrapper 固定官方发布的 ZIP SHA-256。Google Services 4.5.0 保持当前版本；两个尚用 setup-python v6.1.0 的工作流统一到仓库已有的 v7.0.0 固定提交。
- 再次运行 `flutter pub outdated --json`：直接/开发依赖 **0 项落后**。随后继续迁移原先被 SDK/上游约束锁定的 10 项传递依赖；当前整个 pub 图显示 **0 项落后**，见下文原生 FFmpeg 单独版本边界。
- `Predidit/media-kit` 已从 `994465d9` 升至 HEAD `d13fc22b`。新版将 libmpv 改为 SHA-256 校验的 Native Assets，旧 `media_kit_libs_*` 插件及依赖覆盖已移除；`media_kit_video` 以三方合并移植本地 Android Surface/音轨和 Windows 帧进度补丁。`code_assets 2.1.0` 是新版媒体钩子的要求；先核验 FFmpeg 钩子 API，再升级 `objective_c` 至 9.6.0，定向测试已通过。网页内核指定功能分支与 `screen_retriever` 的远端 HEAD 均未变化。
- 同一源码 `31a3c964` 已通过完整质量门禁（仓库审计 0 error、Flutter Analyze 无问题、**5333/5333** 测试），产出 Android arm64 与 Windows x64 Debug 候选；记录分别为 `20260924T011045818Z-build-androidarm64-debug.json` 和 `20260924T013607460Z-build-windowsx64-debug.json`。这些构建结果不代替两端设备/GUI 与 Release 验收。

版本来源：[Flutter tags](https://github.com/flutter/flutter/tags)、[pub.dev outdated](https://dart.dev/tools/pub/cmd/pub-outdated)、[AGP 9.3 发布说明](https://developer.android.com/build/releases/agp-9-3-0-release-notes)、[Gradle 9.7.1 发布说明](https://docs.gradle.org/9.7.1/release-notes.html)、[tray_manager 变更记录](https://pub.dev/packages/tray_manager/changelog)、[media-kit fork 对比](https://github.com/Predidit/media-kit/compare/994465d9bfca3f39d0b41199d16e7fd93fe97881...d13fc22ba1b19b45de3090c2d1b0f8a541b585a0)、[FFmpeg 官方发行版](https://ffmpeg.org/download.html)。

## 2026-09-24 传递依赖与生成链继续迁移

- 原先受约束的 10 项现固定到发布稳定版：`_fe_analyzer_shared 108.0.0`、`analyzer 14.4.0`、`cli_util 0.6.0`、`dbus 0.8.0`、`file_picker_linux 2.0.1`、`material_color_utilities 0.13.1`、`nm 0.6.0`、`qr 4.0.0`、`source_gen 4.3.0`、`test_api 0.7.14`。`flutter pub outdated --json` 对当前全部直接/传递依赖返回 **0 项落后**。
- `qr_flutter 4.1.0` 仍调用 `qr 3.x` 的旧构造与静态常量，强行解析到 `qr 4.0.0` 时编译失败。项目的唯一二维码入口现直接用 `qr 4.0.0` 矩阵绘制，保留低纠错等级、黑白对比和 12 px 留白；旧 Flutter 包已退出依赖图。新增渲染测试与 Bilibili 登录测试同批通过。
- 移除项目没有使用的 `json_serializable`，把 Drift 构建器更新为当前 `drift_dev:drift_dev` 并限定 `tables.dart`/`database.dart`，关闭忽略项目 CLI 参数的 enven 自动构建器；旧 protobuf 构建配置已移除。`build_runner` 由 1351 个 JSON 输入和 5404 个 Drift 输入缩至 6 个 Drift 输入，生成后格式化的 `database.g.dart` 与仓库基线一致。
- 当前源码的完整质量门禁已通过：仓库审计 0 error、格式检查 0 处变更、Flutter Analyze 无问题、**5334/5334** 测试；记录为 `20260924T023009765Z-quality-full.json`。同一源码的 Android arm64、Windows x64 Debug 构建也已通过，记录分别为 `20260924T023453893Z-build-androidarm64-debug.json` 与 `20260924T023903144Z-build-windowsx64-debug.json`；Android 打包的 18 个 ELF 通过 16 KB 对齐检查。**原生 FFmpeg 另计**：以上候选仍采用插件最新公开版 `0.6.2` / builders `0.11.1` 附带的 FFmpeg `9.0.1`，而[官方最新稳定版](https://ffmpeg.org/download.html)为 `9.0.2`；需重新构建并验证各目标 ABI 的原生 bundle，不能用 pub 包版本 0 项落后代替这一步。

## 固定工具链

- Flutter 3.47.5 / Dart 3.13.4（`.fvmrc`）。
- Android compileSdk/targetSdk 37，Java 25 构建运行时，Java/Kotlin 17 字节码目标，AGP 9.3.3，Gradle 9.7.1。
- Google Services Gradle Plugin 4.5.0。
- FFmpeg Kit Extended Flutter 0.6.2；应用通过平台资产覆盖采用已验证的 FFmpeg 9.0.2 Android/Windows/Linux/macOS/iOS 原生包，并复用经过 SHA-256 校验的 Android/Windows Native Assets 共享缓存。macOS Release 与 iOS 无签名应用构建及 FFmpeg 打包内校验已通过；真机与 GUI 验收仍按正式发布门禁执行。

Android 已启用 AGP 9 Built-in Kotlin。主应用、`flv_lzc` 以及六个仍使用独立 KGP 的插件已完成本地迁移，根设置不再声明或应用 `org.jetbrains.kotlin.android`。当前 Flutter 3.47 的通用依赖检查会把 AGP 自带编译器套用到独立 KGP 最低版本规则，因此 Gradle 属性跳过该项误判，同时由 `tool/audit_built_in_kotlin.py` 固定检查 AGP/Gradle 下限、开关和全部本地模块；实际 release 编译继续作为最终门禁。

AGP 9.3.3 是 9.3 稳定补丁；Gradle 9.7.1 是本轮检查时的稳定版。两者均通过版本和解析检查后再进入应用构建门禁。Google Services 4.5.0 与 Firebase 当前官方设置文档一致。

`flutter pub outdated` 已于 2026-09-24 在 Flutter 3.47.5 上重新复核，当前直接和传递依赖均为公开稳定最新版。直接依赖当前包括 `cached_network_image 4.0.2`、`dynamic_color 2.1.0`、`ffmpeg_kit_extended_flutter 0.6.2`、`flex_color_picker 4.0.0`、`loading_indicator 4.0.2`、`permission_handler 13.0.2`、`file_picker 13.1.0` 与 Syncfusion sliders `34.2.9`。`dynamic_color` 2.x 和图像/颜色组件采用独立 `material_ui`；应用在单一边界把其完整 Material 3 `ColorScheme` 转换为 Flutter 框架主题，并以字段完整性及组件渲染测试防止主题角色丢失。部分覆盖项用于跨越 Flutter SDK 或上游包的旧约束，必须以代码生成、分析、测试和原生构建证据验证；`code_assets` 的覆盖让 FFmpeg 钩子与新版媒体钩子共享 2.1.0 API。

播放器依赖在本轮再次单独核验：`better_player_plus` 为 1.3.5 的 Built-in Kotlin 本地快照；项目使用的 `Predidit/media-kit` 固定到 `d13fc22ba1b19b45de3090c2d1b0f8a541b585a0`，`media_kit_video` 使用包含 Surface/音频模式和 Windows 画面进度修复的仓库副本。移除旧平台库插件后，由 `media_kit` 本身的 Native Assets 钩子选择并验证各平台 libmpv。

2026-09-24 再查 `Predidit/media-kit` 的远端 HEAD 仍为 `d13fc22b`；其 Native Assets 清单引用的四组播放器原生资产，也分别对应各构建仓库当日最新公开发行标签：[Android v1.2.7](https://github.com/Predidit/libmpv-android-video-build/releases/tag/v1.2.7)、[Windows 202609151348](https://github.com/Predidit/libmpv-win32-video-cmake/releases/tag/202609151348)、[Linux 20260810](https://github.com/Predidit/libmpv-linux-build/releases/tag/20260810)、[Apple 0.6.8](https://github.com/Predidit/libmpv-darwin-build/releases/tag/0.6.8)。这里核对的是所选构建仓库的发布资产，并不将其标签号等同于底层 mpv 的源码版本。

## 可复现依赖

- 应用提交 `pubspec.lock`，所有 hosted 包锁定具体版本。
- hosted 包来源已统一为官方 `https://pub.dev`，本地与 GitHub Actions 均使用 `flutter pub get --enforce-lockfile`，避免仅因镜像 URL 不同重写整份锁文件。
- 上游 `03c88c9b` 切换 hosted URL时保留了镜像归档哈希，v3.0.0 使用官方解析器重建 12 个受影响条目的当前 SHA-256；最新上游 `db5ac31b` 已包含同一锁结果，合并后 `--enforce-lockfile` 复核一致。
- `flame_barrage 0.0.4` 暂存于 `plugins/flame_barrage`，仅修补引擎移动时忽略逐条速度的问题并保留原许可证；上游发布等效修复后再恢复 hosted 依赖。
- `plugins/built_in_kotlin/` 保存 `better_player_plus 1.3.5`、`floating 6.0.0`、`flutter_exit_app 2.1.2`、`mobile_scanner 7.4.0` 和 `share_handler_android 0.0.11` 的活动源快照；旧 `flutter_js` 快照仅保留许可证归档，不再出现在 `pubspec`、插件注册或运行时依赖图中。
- `media_kit`、`screen_retriever` 固定到已复核的完整 Git 提交；网页内核同步上游锁定到 `guide-inc-org/guide-flutter_inappwebview` 的 `sbi_fx_pc/v6.2.0-beta.3`（解析提交 `3e6c4c4a`），覆盖 Android、iOS、macOS 与 Windows。Android 子包保留同一提交的 Dart/Java 实现，并在 `plugins/built_in_kotlin/flutter_inappwebview_android` 修正 AGP 9 默认 ProGuard 文件、模块私有 AGP classpath 和 Java 17 目标。Linux 的网页搜索使用系统浏览器，避免额外 WPE WebKit 原生依赖。
- 2026-08-24 重新执行远端引用核对：`Predidit/media-kit@994465d9`、`liuchuancong/screen_retriever@b246b396` 与 `liuchuancong/flv_lzc@030d611` 均仍是各自远端 HEAD；网页内核目标分支仍解析到 `3e6c4c4a`。
- 上游 `7410eb9f` 已把斗鱼与抖音签名迁移为纯 Dart，并从锁文件和桌面插件注册中移除 JS 运行时。维护分支进一步修复斗鱼过期时间单位/并发缓存和抖音参数副作用，平台签名单元回归与斗鱼公开描述符探测共同验证。
- `volume_controller 3.6.1` 在发布日的官方归档哈希发生变化；锁文件已通过官方 `pub.dev` API 与 `flutter pub get` 重建为当前归档 SHA-256 `9e776874…b446f`，随后 `--enforce-lockfile` 复核通过。
- Windows 单实例插件同步上游恢复为 hosted `windows_single_instance 1.2.0`，删除仓库内旧副本；`file_picker` 使用稳定版 13.1.0 API。
- `flv_lzc` 固定自上游 `030d611` 并存放在 `plugins/flv_lzc`；仅移除 Android 注册阶段的临时 `SurfaceTexture` 探测，规避 Flutter 3.47 平台纹理注册断言，保留上游许可证和来源说明。
- Android 本地构建按当前 `media_kit/hook/native_bundles.json` 预取并校验四个 ABI 的 Native Assets；质量门禁和 Windows 构建预取 media_kit 与 FFmpeg 的 Windows 档案。Android、Windows、Linux、macOS、iOS 的 FFmpeg 底层已从上游 builders v0.11.1 自带的 9.0.1 重编译至官方 `n9.0.2`，继续使用最新 Flutter 钩子包 `ffmpeg_kit_extended_flutter 0.6.2`。项目的[原生依赖资产预发布](https://github.com/liuchuancong/pure_live/releases/tag/native-ffmpeg-9.0.2-b1)固定 Android 三 ABI AAR SHA-256 `c6c9b1ff7be756b0fb587f98e05972ca4dae97e8275c22961b443b4fd5f49bf7`、Windows x86_64 ZIP SHA-256 `e61684a91f7471ba00f1d5b36a24e93ab602ef72bd57000d94990e7e0c5dfe3a`、Linux x86_64 ZIP SHA-256 `d6003c3feb2bdcdccd0d4ad5e7b76fa8e8951430c6a22c1db7be5e13da19403d`、macOS universal XCFramework ZIP SHA-256 `9977fc0d3de38af4830c54f536146b2595843d7a45850c50c6205ffb56ca899a`、iOS universal XCFramework ZIP SHA-256 `f1758956e81d938bedf39e796dc99a3b34951cffcc681ab52e241d47b0c93aa4`。macOS 档案来自[单平台构建 Run 35960427126](https://github.com/liuchuancong/pure_live/actions/runs/35960427126)，已核对 XCFramework 描述、x86_64/arm64 Mach-O 切片与 `n9.0.2` 标记。[iOS 单平台构建 Run 35970481097](https://github.com/liuchuancong/pure_live/actions/runs/35970481097)也已核对设备与模拟器 arm64 切片及版本标记。Linux 在 Ubuntu 24.04 容器中构建，最高要求 GLIBC 2.38；在同一基线动态加载并实读返回版本 `n9.0.2`。本机构建先核对 SHA-256，再写入按原生版本隔离的 Native Assets 共享缓存；AAR 合并脚本 `tool/assemble_ffmpeg_android_aar.py` 同时核对 ELF 架构、版本标记和页面对齐。GitHub 构建通过 `pubspec.yaml` 的平台资产 URL 使用同一版本，并由 `tool/verify_ffmpeg_native.py` 对实际钩子下载与打包库再校验。Linux Flutter 构建虽执行了钩子却未将 `libffmpegkit.so` 复制入 release bundle；打包阶段现从已校验 ZIP 中补齐 `bundle/lib/libffmpegkit.so`，随后验证打包文件。五个平台的原生包均已迁移；[macOS 应用构建 Run 35974500374](https://github.com/liuchuancong/pure_live/actions/runs/35974500374)与 [iOS 应用构建 Run 35977431211](https://github.com/liuchuancong/pure_live/actions/runs/35977431211)分别通过 Release 编译、产物生成和打包内 FFmpeg 9.0.2 校验。
- 2026-09-24 的 [Linux 单平台构建 Run 35956033043](https://github.com/liuchuancong/pure_live/actions/runs/35956033043) 已在提交 `ddc92015` 上通过 Flutter Release 编译、FFmpeg 原生 ZIP SHA-256 / 运行库版本 / GLIBC 基线检查，并上传临时便携构建产物。Flutter 3.47.5 Linux 官方归档的哈希同步至[官方发布索引](https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json)当前值 `2132e990f236f8d22e7c6314b29a191a95b10d7cbcfec9b4e2e303d996652cbb`。
- FFmpeg 9 默认校验 TLS 对端证书，而 Android/Linux OpenSSL 构建时写入的 `OPENSSLDIR` 不存在于用户设备。应用因此保留证书校验，显式使用 curl 于 2026-08-13 从 Mozilla NSS 导出的 `assets/certificates/mozilla-ca-bundle.pem`，固定 SHA-256 `f66dff1b…80bc9`。启动时复制到应用数据目录并再次校验，仅对 HTTPS 输入注入 `-ca_file`；不以关闭 TLS 校验掩盖信任库缺失。
- 删除已停止作用的 `sqlite3_flutter_libs`；项目使用 `sqlite3` 3.x 的 Native Assets。
- 升级 `app_links`、`connectivity_plus`、`pro_mpack` 与 Syncfusion sliders，并通过静态分析和完整测试。
- GitHub Actions 固定到已核验的完整提交 SHA，Dependabot 每月汇总检查 pub、Gradle 和 Actions 更新；日常分支推送不构建，仅手动入口或显式阶段标签按平台运行。
- 当前锁定的 Predidit Linux `libmpv` 需要 glibc 2.38 与 GLIBCXX 3.4.32，因此 Linux 作业固定使用 Ubuntu 24.04；Ubuntu 22.04 链接失败属于二进制基线不匹配，而非缺少单个开发包。

## Android 16 KB 页面兼容性

Android 官方要求同时检查 APK 内原生库的 ZIP 对齐与 ELF `LOAD` 段对齐；仅有 `zipalign -P 16` 通过不足以证明每个 `.so` 支持 16 KB 页面。官方说明见 [Support 16 KB page sizes](https://developer.android.com/guide/practices/page-sizes)。

2026-09-01 对 v3.1.8+4121 arm64 Debug 和当前 Release APK 做了独立核验：

- Android Build Tools 36 的 `zipalign -c -P 16 -v 4` 均通过；
- 用 NDK r29 `llvm-objdump -p` 检查 16 个 arm64 ELF，13 个的最小 `LOAD` 对齐达到 `2**14` 或更高；
- `libijkffmpeg.so`、`libijkplayer.so`、`libijksdl.so` 的最小 `LOAD` 对齐仍为 `2**12`；它们来自 `plugins/flv_lzc/android/build.gradle` 锁定的 `io.github.flutterplayer:fplayer-core:1.0.4`；
- K90 Pro 当前运行页大小为 4096 字节，因此现有包在该设备可启动；Android 17 安装 Debug 包仍给出原生库兼容提示，这三项在 16 KB 页设备/严格模式下属于发布阻断项；
- Maven Central 的 [fplayer-core 1.0.4](https://central.sonatype.com/artifact/io.github.flutterplayer/fplayer-core) 仍是该坐标最新版本，直接升小版本不会得到已验证的 16 KB 二进制。后续采用源码可复现重编译或经过 API/许可证/ABI 回归的播放器替换，不引入来源不明的预编译库。

本地逐 ELF 结果保存于 `local-artifacts/diagnostics/elf-alignment-20260901T152627221/`。正式稳定版门禁将以所有打包 ABI 的 ZIP + ELF 双重对齐为准。

2026-09-24 升级版 arm64 Debug APK（`31a3c964`）已重新检查：18 个打包原生库的最小 ELF `LOAD` 对齐均为 `0x4000`，APK 内容门禁通过；这是当前 arm64 Debug 候选的结果，不覆盖其他 ABI、Release 或真机回归。

## 直播接口探测

运行：

```powershell
python .\tool\interface_probe.py
```

当前脚本总计检查 42 项，覆盖 Bilibili、Douyu、Huya、Kuaishou、Douyin、网易 CC、Twitch、SOOP Live 与 YY Live 的公开分类/推荐入口、搜索、房间元数据、弹幕节点和播放链路。v2.9.7 在不增加重复请求的前提下，把既有推荐检查升级为字段语义检查：斗鱼 `ol`、虎牙 `totalCount`、抖音 `user_count`、快手 `watchingCount`、CC 热度/并发双字段、Twitch `viewersCount`、SOOP `total_view_cnt = pc_view_cnt + mobile_view_cnt` 与 YY `users` 都必须存在并可解析。播放器链路继续覆盖斗鱼签名 + H5 + CDN FLV 实读、快手直播/录播结构、Bilibili/Huya/CC 画质线路以及 Twitch/SOOP/YY 播放令牌；v3.0.0 额外实读上游 #798 指定 YY 房间的匿名移动 HLS 清单，并在上游 #799 截图对应斗鱼房间在线时验证其 H5 清晰度/CDN和实际 FLV 文件头，防止“常规房间探针通过、特定房间仍不能播”的盲区。发布结果写入对应阶段文档；Android 设备验收仍作为独立证据层。

虎牙另提供 `python .\tool\huya_danmaku_probe.py` 实时 WebSocket 回归；2026-08-16 已验证注册、新版心跳和真实推送接收。该项依赖当前直播间与平台网关状态，保留为发布前手动检查。

接口属于外部服务，任何时刻都可能变化；发布前应重新运行探测，并按发布计划选择本地桌面运行或独立设备播放验收。

返回 [文档索引](README.md)。
