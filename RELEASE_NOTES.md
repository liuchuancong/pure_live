# Pure Live v2.0.29

本版本完成 Flutter、Dart、Android 构建链和项目直接依赖的集中升级，并保留 v2.0.28 的动态高刷新率、小窗弹幕和本地互动优化。

## 工具链与依赖

- Flutter 由 3.44.9 升级至 3.47.0，Dart 升级至 3.13.0。
- Android 升级至 compileSdk/targetSdk 37、AGP 9.1.1、Gradle 9.3.1 与 Kotlin 2.4.10。
- 升级 `flutter_json` 0.2.0、`permission_handler` 13.0.1、`xml` 7.0.1、`hooks` 2.1.0、`image` 4.9.1、`build_runner` 2.16.0 等依赖。
- `flutter_inappwebview` 切换至官方仓库当前 6.2.0-beta.3 提交，修复 AGP 9 已移除旧 ProGuard 默认配置造成的构建中断。
- Git 依赖逐项核对默认分支并固定完整提交；GitHub Actions 同步 Flutter 3.47.0，并升级 `download-artifact` 8.0.1。

## 兼容性与构建

- 适配 Dart 3.13 的参数修饰符诊断。
- Android 各插件统一使用 API 37 编译，兼容仍声明较低 compileSdk 的旧插件。
- 兼容第三方插件混合 Java/Kotlin 字节码目标，继续保留迁移警告便于后续切换 AGP 内置 Kotlin。
- 长路径短盘符支持 `P:` 到 `W:` 自动分配，本地主工作区与临时自托管 Runner 可并行使用各自稳定映射。
- 仅优先构建 Android `arm64-v8a`，Windows 仅构建 x64，减少本机与 Actions 重复耗时。

## 验证

- Flutter Analyze 零问题通过。
- 27 项单元测试与 Widget 测试全部通过。
- Android `arm64-v8a` release 原生编译与 Windows x64 release 原生编译通过。
- 外部平台接口由本机发布门禁重新探测；设备刷新率、温控和长时间后台播放数据继续按具体机型记录。

## 下载说明

- Android：`arm64-v8a` APK，正式包名为 `com.mystyle.purelive`。
- Windows：x64 安装包和便携 ZIP。
- 使用 `SHA256SUMS.txt` 校验文件完整性。
