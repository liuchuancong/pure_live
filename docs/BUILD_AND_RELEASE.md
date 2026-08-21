# 本地构建、测试与发布

本仓库采用“本机优先、Actions 手动兜底”的流程，固定使用 Flutter `3.47.0`。`pubspec.lock`、Git 依赖提交和 FFmpeg 产物地址均已固定，便于复现结果。

最近完整核验：2026-08-20，Windows 11 + Java 25 + Flutter 3.47.0；设备 UI 映射、Built-in Kotlin 审计、Flutter Analyze、154 项单元/Widget 测试及 26/26 平台公开接口探测全部通过。v2.3.0 继续以本机优先方式构建 Android arm64 与 Windows x64，再由显式阶段任务补齐 Linux x64、macOS universal 和 iOS arm64 设备归档；PiP 返回弹幕恢复、启动逐批刷新、横屏本地输入、播放器控制器释放和有界弹幕缓存均进入回归范围。干净便携目录继续把数据、缓存和临时文件写入 release 同级 `AppData`。

## 前置环境

- Windows 11 x64，已启用 Flutter Windows 桌面开发所需的 Visual Studio C++ 工具；
- Android SDK 及可用的 Android 设备或模拟器；
- Java 25 构建运行时（Android 应用和插件字节码目标仍为 17）；
- Python 3，用于直播接口探测和发布历史更新；
- 可选：Inno Setup 6，用于生成 Windows EXE 安装包；
- 可选：GitHub CLI，用于从本机创建并上传 Release。

## Windows 11 一键质量门禁

仓库脚本依次执行锁定依赖解析、变更 Dart 文件格式检查、静态分析、完整测试和直播接口探测：

```powershell
PowerShell -ExecutionPolicy Bypass -File .\tool\local_ci.ps1
```

`tool/flutterw.ps1` 按以下顺序寻找 Flutter：

1. 环境变量 `PURE_LIVE_FLUTTER` 指向的 `flutter.bat`；
2. `.fvm/flutter_sdk/bin/flutter.bat`；
3. `%LOCALAPPDATA%\Codex\flutter\sdk-3.47.0\flutter\bin\flutter.bat`；
4. `PATH` 中的 Flutter。

路径较长时脚本会从 `P:` 到 `W:` 为当前工作区选择并保留一个稳定的短盘符映射，规避 FFmpeg Native Assets 在 Windows 上超过传统路径长度后的构建失败，也支持本地主工作区与临时自托管 Runner 并行构建。映射记录位于未跟踪的 `.dart_tool/pure_live_subst_drive.txt`；连续的 `pub get`、分析、测试和构建会复用同一盘符，避免 Native Assets 增量缓存引用已经释放的盘符。

Android 构建使用 Java 25 运行 Gradle 与 lint，应用和插件的 Java/Kotlin 字节码目标保持 17。脚本优先读取 `PURE_LIVE_JAVA_HOME`，随后检测 Android Studio JBR，最后回退到本机 Temurin；当前工具链为 compileSdk/targetSdk 37、Gradle 9.5.0、AGP 9.3.1 和 AGP Built-in Kotlin。`tool/audit_built_in_kotlin.py` 会在本地 CI 中阻止独立 KGP、模块私有 AGP classpath 和旧 Kotlin DSL 回归。

Android 打包前会由 `tool/prefetch_android_native.ps1` 下载并逐一校验 media_kit 的四个 libmpv JAR，避免 Gradle 直接访问 GitHub Release 时因连接中断生成损坏缓存。

Windows 的 `flutter_inappwebview_windows` 需要 `nuget.exe`。脚本会自动发现 `%LOCALAPPDATA%\Codex\nuget\nuget.exe` 或 `PATH` 中的 NuGet；建议从 `https://dist.nuget.org/` 下载并核验 Microsoft Authenticode 签名。

## 一键生成安装包

```powershell
PowerShell -ExecutionPolicy Bypass -File .\tool\build_local_release.ps1
```

默认生成：

- Android `arm64-v8a` APK（默认优先且仅构建这一架构）；
- Windows x64 便携 ZIP；
- 安装了 Inno Setup 6 时，额外生成 Windows EXE 安装包；
- 所有文件的 `SHA256SUMS.txt`。

产物位于 `local-artifacts/<version-build>/`，该目录不会提交到 Git。

Windows 打包前会先清理 `build/windows/x64/runner/Release`，并检查 `AppData`、缓存数据库等运行时状态未进入便携包或安装器；打包暂存区还会剔除 `.lib`、`.exp`、`.pdb`、`.ilk` 等仅供原生开发/链接使用的文件。请勿直接把运行过的 Release 目录手工压缩发布。

可选参数：`-SkipQuality`、`-SkipAndroid`、`-SkipWindows`、`-SkipInstaller`、`-UseOfficialRepositories`。

本地打包默认通过临时 Gradle init script 优先使用阿里云 Maven 镜像，并保留 Google/Maven Central 回退，解决国内网络的 TLS 中断；`-UseOfficialRepositories` 会只使用项目声明的官方仓库。该设置仅对当前脚本进程生效，不改全局 Gradle 配置。

### Android 正式签名

在 `android/key.properties` 中配置以下字段，密钥文件放在仓库外部：

```properties
storeFile=C:/secure/path/pure-live-release.jks
storePassword=...
keyPassword=...
keyAlias=...
```

Android 始终使用 `com.mystyle.purelive` 和“纯粹直播”名称。未配置发布密钥时，本地 release 构建使用 Android 调试签名，文件名包含 `debug-signed`；本地发布脚本默认阻止调试签名 APK 进入正式 Release。

将本地 APK 安装到已连接的 Android 设备并完成启动探测：

```powershell
PowerShell -ExecutionPolicy Bypass -File .\tool\install_android_local.ps1
```

正式发布时使用 `-RequireReleaseSigning`，缺少或不完整的外部签名配置会在构建前终止：

```powershell
PowerShell -ExecutionPolicy Bypass -File .\tool\build_local_release.ps1 -RequireReleaseSigning
```

签名材料只保存在 GitHub Secrets、Actions 托管额度紧张时，可在本机注册
Windows x64 临时自托管 Runner，再手动运行
`local-signed-android` 工作流。编译仍在本机完成，工作流仅把签名 Secrets
注入临时进程；工作流依次检测 Runner 工具缓存、Android Studio JBR 与 `JAVA_HOME`，且只接受真实 Java 25，任务结束后会清理 JKS 和 `android/key.properties`。

临时 Runner 注册服务异常时，可显式推送 `signed-build-*` 标签，使用同一工作流的一次性 GitHub 托管回退作业生成正式签名 arm64 APK；普通提交不触发该作业，本机门禁与 Windows 构建仍保持优先。

Linux、macOS 和 iOS 通常通过 `manual-build` 手动开关补建；阶段标签也支持精确补建：`stage-linux-*` 运行 Linux，`stage-ios-*` 运行 iOS，`stage-apple-*` 在一个 macOS Runner 内连续构建 macOS 与 iOS。普通分支推送、Android 和 Windows 均保持本机优先。

全平台阶段包就绪后，`publish-staged-release` 工作流可输入阶段构建 Run ID 与本机正式签名 Android Run ID：Windows x64 会在临时自托管 Runner 上重新构建，托管发布作业只负责汇总 Linux/macOS/iOS 阶段包、校验来源提交与正式签名元数据、生成统一 SHA-256，并创建 Release。这样不会为已经通过的 Linux/Apple 平台重复消耗完整构建额度。

本机生成的 Windows EXE 安装向导始终显示安装目录页，可选择其他磁盘并记住上次目录。关注、历史、IPTV、录制、图片/表情/插件缓存和应用临时文件统一位于 `{app}\AppData`；更换目录时安装器保留上一个位置索引，新版首启再备份和合并。详见 [Windows 数据目录与升级](WINDOWS_DATA_AND_UPGRADE.md)。Windows 播放小窗默认使用普通窗口层级；“设置 → 播放设置 → Windows 小窗始终置顶”可按需切换，当前小窗会立即应用。

Linux 版使用系统浏览器承接“继续网页搜索”，避免引入额外 WPE WebKit 运行时；平台原生搜索、直播详情、弹幕与播放链路仍在应用内完成。Windows/macOS/Android/iOS 使用锁定修订版 `flutter_inappwebview`。

Ubuntu 24.04 构建会同时安装 `libva`、VDPAU、PulseAudio、Wayland、EGL 与 X11 开发包，以满足当前锁定 `libmpv.so` 的 glibc 2.38 / GLIBCXX 3.4.32 基线和链接依赖；Android 使用仓库内的同版本网页内核兼容副本通过 AGP 9.3.1 / R8 构建。Linux 归档携带应用与媒体库，目标系统仍需提供 GTK、托盘、显卡驱动和音频运行库。

## 单独命令

```powershell
.\tool\flutterw.ps1 pub get --enforce-lockfile
.\tool\flutterw.ps1 analyze --no-fatal-infos --no-fatal-warnings
.\tool\flutterw.ps1 test
python .\tool\interface_probe.py
.\tool\flutterw.ps1 build apk --release --split-per-abi --target-platform android-arm64
.\tool\flutterw.ps1 build windows --release
```

## 从本地产物发布 GitHub Release

提交并推送代码后，可由本机直接上传产物，不占用 Actions 构建分钟：

```powershell
PowerShell -ExecutionPolicy Bypass -File .\tool\publish_local_release.ps1 `
  -Tag v2.3.0 -CreateTag
```

脚本要求工作树已提交，并通过 GitHub CLI 当前登录身份创建或更新 Release。

## GitHub Actions

`.github/workflows/feature-build.yml` 支持手动触发，可分别选择 Android arm64、Windows x64、Linux x64、macOS universal 和 iOS arm64 设备编译；默认先运行完整静态分析、测试与接口探测。`stage-linux-*`、`stage-ios-*` 与 `stage-apple-*` 标签仅用于精确阶段补建，产物保留 3 天。

代码未变化且当前提交已经在本机通过完整门禁时，可关闭手动工作流的
`run_quality`，仅调用托管 Runner 完成 Secrets 正式签名；默认仍会执行完整门禁。

Android 手动云构建要求以下 Secrets：

- `PURELIVE_KEYSTORE_BASE64`
- `PURELIVE_STORE_PASSWORD`
- `PURELIVE_KEY_PASSWORD`
- `PURELIVE_KEY_ALIAS`

`.github/workflows/update_releases.yml` 只支持手动触发，不再每日消耗 Actions 配额。正式 Release 不由标签自动发布；仅上述显式阶段标签会启动对应平台编译。

需要在本机刷新 `assets/releases.json` 时，从仓库根目录运行：

```powershell
python .\tool\update_releases.py
```

## 发布检查清单

1. 更新 `pubspec.yaml`、`assets/version.json` 与 `RELEASE_NOTES.md`。
2. 运行 `tool/local_ci.ps1`。
3. 运行 `tool/build_local_release.ps1`，核对 APK、EXE/ZIP 和 SHA-256。
4. 运行 `tool/install_android_local.ps1` 在真机覆盖安装并启动；正式 Release 使用仓库持久签名验证升级链。
5. 提交并推送 `master`，再运行 `tool/publish_local_release.ps1`。
6. 在 [维护分支 Releases](https://github.com/liuchuancong/pure_live/releases) 核对附件和校验文件。

返回 [文档索引](README.md)。
