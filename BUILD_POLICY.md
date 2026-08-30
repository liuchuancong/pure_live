# Pure Live 构建资源策略

<!-- build-policy-markers: bugfix-android-release-default; local-build-first; github-secret-signing; serial-platform-stages -->

本文件是本仓库开发、验证、构建、打包和发布的默认资源规则。当前任务中的用户明确要求优先级最高；已完成的 Bug 修复批次默认进入 Android 新版本交付闭环，其他平台不会因为上一轮构建过而自动进入下一轮范围。

## 1. 范围与阶段

- 每次命令只处理一个平台与一个变体。完成一个 Bug 修复批次后，`AndroidArm64 Release`、版本递增、源码同步和 GitHub Release 视为本仓库的常设交付范围；当前任务明确要求暂缓交付时才停止在代码与测试阶段。
- Android、Windows、Linux、macOS、iOS 按独立阶段串行执行；同一次并发全平台打包列为禁止项。
- 日常开发使用受影响模块、目标测试文件和目标平台 `Debug`。
- 对外正式交付才执行该目标平台的 `Release`、一次完整静态分析、完整测试及所需接口核验。
- 构建、打包、签名、上传和发布仍是独立证据层；Bug 修复闭环预先包含这些 Android 阶段，但各阶段必须串行且上一层验证通过后才进入下一层。非 Bug 工作与 Android 之外的平台继续以当前任务的明确范围为准。
- Android 正式私钥只由仓库 Secrets 注入。日常与候选 APK 在本机完成编译；正式签名可通过
  `sign-staged-android` 对本机暂存包执行短时签名与校验，避免为了访问私钥重复运行远端 Flutter/Gradle 构建。

### 1.1 Bug 修复默认交付闭环

一次用户任务中同一根因或相邻功能的多个修复合并为一个交付批次，避免每个小提交重复增加版本。完成修复并通过定向验证后按固定顺序执行：

1. 将语义版本补丁位和数字 build 各递增一次，并同步 `pubspec.yaml`、`assets/version.json`、工作流默认标签、MSIX 版本、README、Release Notes 与阶段文档。
2. 在干净提交上执行一次完整质量门禁；同一业务源码已通过完整门禁而后续只修改发布脚本或文档时，可引用该证据并使用 `-SkipQuality` 重建最终提交。
3. 仅在本机串行构建 Android `arm64-v8a` Release，执行 APK 内容、包名、版本、ABI、关键原生库、文件大小和 SHA-256 核验。
4. 推送最终 `master`，创建与源码提交一致的版本 tag 和草稿 Release，上传本机暂存 APK、构建元数据与校验文件。
5. 仅调用 `sign-staged-android` 使用 GitHub Secrets 完成短时正式签名；核对固定证书指纹和最终 APK 哈希后发布 Release。
6. 刷新 `assets/releases.json`，以独立的 `[skip ci]` 索引提交同步 GitHub；确认 Release 页面、附件、下载地址和源码提交一致后结束。

纯文档、策略或注释变更本身不单独触发 APK 版本；它们若属于同一 Bug 修复交付批次，则随该版本一并提交。签名或发布阶段出现错误时保留已通过的本机构建证据，修正发布层后从失败阶段继续，不重复远端编译。

## 2. 本机资源档位

目标机器：Core Ultra 9 275HX（24 核）、192 GB RAM、RTX 5090 Laptop（24 GB）。任何档位都为 Codex 桌面、编辑器和系统交互保留资源。

| 场景 | Gradle workers | Flutter test concurrency | 用途 |
|---|---:|---:|---|
| 交互开发（默认） | 16 | 12 起步 | 用户仍在使用桌面时的定向检查与 Debug |
| 专门构建 | 20 | 12 起步 | 用户明确安排的独占构建窗口 |

- Gradle workers 上限为 20，不使用全部 24 核。
- Flutter 测试从 `--concurrency=12` 开始；只有记录表明资源仍充足且任务确有收益时才单独调整。
- 构建中的 GPU 主要留给桌面和播放器验证，不以占满 GPU 为优化目标。

## 3. Gradle 与增量缓存

`android/gradle.properties` 固化以下基线：

- daemon、parallel、build cache、configuration cache、VFS watch 均启用；
- Configuration Cache 保持严格失败模式；已确认不兼容的 Flutter 聚合任务必须用
  `notCompatibleWithConfigurationCache` 精确标注，使 Gradle 丢弃该条目，禁止用全局
  warning 模式保存不完整状态；
- 交互构建默认 `org.gradle.workers.max=16`，专门构建由脚本覆盖为 20；
- Gradle JVM Heap 为 6 GiB、Metaspace 为 1 GiB、使用 Parallel GC；
- Kotlin daemon Heap 为 4 GiB；
- Kotlin 与 Android 增量状态保持启用。

构建脚本不传 `--no-daemon`，也不在每轮开始停止 Gradle daemon。保留 `.gradle`、`.dart_tool`、`build` 和原生依赖缓存；仅在缓存损坏、生成物与源码明显不一致或工具链迁移确有需要时执行针对性清理。`flutter clean` 与递归删除整个构建目录不属于常规步骤。

Windows 长路径工作区由 `tool/flutterw.ps1` 优先映射到 `%LOCALAPPDATA%\Codex\workspaces` 下的稳定同盘目录联接，使工程与默认 Pub 缓存保持同一盘符，避免 Kotlin 插件增量缓存因跨盘相对路径失败而回退到完整编译；目录联接受限时才使用稳定 `SUBST` 盘符作为兼容后备。

Windows 增量构建目录可能保留已移除插件的旧 DLL 或资源。正式 ZIP/安装程序按当前
`build/windows/x64/install_manifest.txt` 与经审查的 runner 运行时小型白名单建立独立打包
目录，并排除开发文件；禁止直接复制整个 `runner/Release` 目录。

Windows Firebase C++ SDK 由 `tool/prefetch_windows_native.ps1` 在构建前按插件声明版本预取：断点续传并重试大型归档，核对服务端长度与 ZIP 结构，写入 SHA256 记录，校验解压后的版本头文件，并通过 `FIREBASE_CPP_SDK_DIR` 避免 CMake 误复用旧版本的通用 `extracted` 目录。

## 4. 验证策略

- 上游同步先执行 [`UPSTREAM_REVIEW_POLICY.md`](UPSTREAM_REVIEW_POLICY.md)：冻结完整提交，运行
  `tool/review_upstream_update.ps1`，以 merge base 盘点全部入站提交和全部文件，记录逐文件差异与冲突处置，再允许 merge。合并后必须运行 `tool/audit_repository.py` 复核整个已跟踪仓库。上游工作流、版本、更新源和默认设置不得机械覆盖维护分支；播放器普通页布局与系统返回必须通过确定性 Widget 回归。
- 修改过程中优先运行直接相关的单元/Widget 测试或模块检查。
- `flutter analyze` 在本轮代码修改完成后执行一次，避免每个小改动后重复启动分析服务器。
- 定向测试使用一个 Flutter 命令承载全部目标文件，并从 `--concurrency=12` 开始。
- 完整回归由 `tool/local_ci.ps1 -Scope Full` 显式触发；日常定向检查使用 `-Scope Focused -TestPath ...`。
- 聚焦回归在根/本地插件 `pubspec.yaml` 与 `pubspec.lock` 均未变化且
  `.dart_tool/package_config.json` 已存在时，可显式传入 `-SkipPubGet`，避免对同一锁文件重复执行
  分钟级依赖求解。脚本会自行核对前置条件；完整回归始终重新解析并校验锁定依赖。
- 打包脚本要求显式传入 `-Target` 与 `-Configuration`，每次调用只生成该目标产物。
- Android APK 在复制、签名和发布前必须通过内容完整性门禁：核对唯一目标 ABI、Flutter AssetManifest/版本清单/翻译与表情资源，以及 FFmpegKit、SQLite、MediaKit、Flutter 和应用原生库。仅验证包名、版本、ABI 与签名不构成完整交付证据。
- Android 正式打包复用同一源码提交质量门已经锁定的 `.dart_tool/package_config.json`，目标构建使用 `--no-pub`，避免为 Android 打包重建 Windows/iOS/macOS 插件链接，也避免 Windows 长路径目录联接与 SUBST 盘符在同一增量图中混用。
- 同一应用源码提交已通过完整回归后，如果失败阶段只涉及构建脚本、Gradle 兼容配置或
  发布流程，打包重试可使用 `-SkipQuality`；构建记录与交付报告必须引用此前通过的完整
  回归运行。业务源码、依赖或生成逻辑有变化时仍执行完整回归。

## 5. 重型任务互斥

启动 Gradle、Java、Dart、Flutter 或大范围搜索之前，先通过 `tool/build_resource_guard.ps1`：

1. 获取当前 Windows 会话共享的重型任务互斥锁；
2. 检查其他 Codex 工作区中仍活跃的 Gradle、Java、Dart、Flutter、`rg` 进程；
3. 检测到活跃任务时排队，连续安静后再开始；
4. 同一时间只保留一个重型验证或构建任务。

已结束构建留下的 Gradle/Kotlin/分析服务器常驻 daemon 保留增量缓存，不作为活跃任务；
资源守卫以显式构建客户端或持续高负载区分实际构建与 daemon 健康检查，避免空闲
daemon 让后续阶段长期误排队。

同理，仅存活但采样期间没有实际 CPU 工作、正在等待标准输入的 `rg` 不算活跃搜索；
真正扫描文件的 `rg` 仍由持续 CPU 采样识别并进入排队，避免一个闲置管道永久阻塞后续构建。

禁止绕过互斥脚本并行启动另一套全量测试或构建。

## 6. 记录与收尾

每次重型任务在 `local-artifacts/build-records/` 写入 JSON 记录，至少包含：

- 实际命令、源码提交、目标平台与变体；
- 开始时间、耗时和结果；
- Gradle/配置缓存启用状态、日志中可观察到的命中与 `UP-TO-DATE` 数量；
- 重型进程峰值 CPU、峰值内存与进程数；
- 产物绝对路径或验证范围；
- 任务结束后的活跃重型进程数。

监控任务、临时脚本与互斥锁在 `finally` 中释放。构建结束后确认后台 CPU 回落。Bug 修复批次只继续既定的 Android 签名、GitHub 发布和索引同步，不追加下一轮完整回归或其他平台打包；普通构建任务在目标产物完成后结束。

## 7. 推荐调用

```powershell
# 日常定向验证：同一命令运行受影响测试，修改完成后附加一次 Analyze
PowerShell -ExecutionPolicy Bypass -File .\tool\local_ci.ps1 `
  -Scope Focused -TestPath test/example_test.dart -Analyze -SkipPubGet

# Android 交互 Debug（一次只构建这一目标）
PowerShell -ExecutionPolicy Bypass -File .\tool\build_local_release.ps1 `
  -Target AndroidArm64 -Configuration Debug -SkipQuality

# Android 正式交付：一次完整回归后构建正式目标
PowerShell -ExecutionPolicy Bypass -File .\tool\build_local_release.ps1 `
  -Target AndroidArm64 -Configuration Release -FullRegression -RequireReleaseSigning

# 同一提交已由上一阶段完成完整回归时，Windows 正式阶段复用该证据
PowerShell -ExecutionPolicy Bypass -File .\tool\build_local_release.ps1 `
  -Target WindowsX64 -Configuration Release -SkipQuality
```
