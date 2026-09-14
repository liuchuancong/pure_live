# Windows 副屏亮度所有权审计（2026-09-14）

## 结论

上游 Issue #863 描述的“Windows 播放约两分钟后 AOC 副屏亮度降到最低”存在稳定的原生写入链。Pure Live 的 Dart 层早已把亮度手势限制在 Android/iOS，但通用 `screen_brightness` 依赖仍会让 Flutter 在 Windows 注册 `screen_brightness_windows`。该插件注册后无需任何 Dart 亮度调用，就会监听窗口大小、激活和关闭消息，并通过 DDC/CI 写物理显示器亮度。

提交 `a0bbe074` 将亮度依赖拆成平台接口与 Android/iOS 两个直接实现，Windows/macOS 构建不再解析、编译或注册对应亮度插件；移动端继续沿用相同 MethodChannel 合同。本轮已完成确定性红灯、245 项受影响回归、本批唯一一次全库 analyze 和 Windows x64 Debug 构建。Windows 双屏 GUI 与报告者 AOC 显示器仍留在原生验收账本中，因此不提升宏观 PASS。

## 问题与首次错误状态

- Issue：上游 `liuchuancong/pure_live#863`。
- 报告环境：Windows 11、Intel 处理器、AMD 显卡、AOC 副屏。
- 报告路径：打开 Pure Live、播放直播，约两分钟后副屏亮度被改写；显示器断电重开可暂时恢复，随后再次出现。
- Issue 没有附日志、截图、具体 AOC 型号或 DDC/CI 读数；问题表单的平台选择与正文环境也不一致。

首次错误状态不在播放器手势逻辑，而在 **Windows 原生插件注册边界**：应用没有对桌面亮度功能作调用，但依赖图仍让一个具有物理显示器写权限的插件在进程启动时注册。

## 根因链

### 1. Dart 层已有移动端边界

`lib/modules/live_play/widgets/video_player/video_controller.dart` 的 `PlatformHelper.supportsBrightness` 只允许 Android/iOS，亮度控制器也只在该条件为真时延迟创建。Windows 左侧亮度手势同样被界面层阻断。因此，继续增加 Dart 条件判断不会消除原生插件自身的窗口消息副作用。

### 2. 通用依赖仍把桌面插件带入构建

修复前 `pubspec.yaml` 直接依赖 `screen_brightness ^2.1.2`，锁文件解析为 2.1.11，并传递引入：

- `screen_brightness_android 2.1.6`
- `screen_brightness_ios 2.1.4`
- `screen_brightness_macos 2.1.4`
- `screen_brightness_ohos 2.1.4`
- `screen_brightness_platform_interface 2.1.2`
- `screen_brightness_windows 2.1.2`

生成的 `windows/flutter/generated_plugin_registrant.cc` 会调用 `ScreenBrightnessWindowsPluginCApiRegisterWithRegistrar`，生成的 CMake 也会编译和链接该插件。

### 3. Windows 插件注册即产生物理亮度写入

本机 Pub 缓存中的 `screen_brightness_windows-2.1.2/windows/src/screen_brightness_windows_plugin.cpp` 显示：

1. 构造函数取得 Flutter 原生窗口，通过 `MonitorFromWindow(..., MONITOR_DEFAULTTOPRIMARY)` 读取当时显示器的亮度，并注册顶层 WindowProc。
2. `WM_SIZE`、`WM_ACTIVATEAPP`、`WM_CLOSE` 和 `WM_DESTROY` 会进入 `OnApplicationPause` 或 `OnApplicationResume`。
3. `OnApplicationPause` 调用 `SetScreenBrightness(system_screen_brightness_)`。
4. 写入前再次按窗口当前位置调用 `MonitorFromWindow`，最后执行 Windows DDC/CI `SetMonitorBrightness`。

因此，窗口跨主副屏移动或在副屏上发生激活、最小化、恢复等生命周期事件时，插件能够把先前保存的亮度值写到当前物理显示器。这条无需 Dart 调用的原生写入链与 Issue #863 的现象直接吻合。

### 4. 旧修复为什么没有封住边界

历史提交 `6cf42712`（“修复window亮度问题”）做了两件事：

- 把 Dart 亮度控制器改为 Android/iOS 延迟创建；
- 在 `windows/CMakeLists.txt` 设置 `screen_brightness_NOT_IMPLEMENTED TRUE`。

第一项只保护应用调用路径。第二项没有被 `screen_brightness_windows` 的 CMake 或 Flutter 生成注册逻辑读取；当前生成注册器和生成插件 CMake 仍包含 Windows 亮度插件。因此旧修复没有到达真正的原生注册边界。

## 修订

提交 `a0bbe074`：

1. 移除通用 `screen_brightness` 依赖。
2. 直接依赖 `screen_brightness_platform_interface 2.1.2`、`screen_brightness_android 2.1.6` 和 `screen_brightness_ios 2.1.4`。
3. `VideoController` 直接使用 `ScreenBrightnessPlatform.instance`，保留 Android/iOS 原有 `application` 与 `setApplicationScreenBrightness` MethodChannel 行为。
4. 从锁文件删除 Windows/macOS/OHOS 实现和通用包装包。
5. 重新生成 Windows/macOS 插件注册文件；桌面亮度插件均被移除，Android/iOS 注册仍保留。
6. 删除没有消费者的 `screen_brightness_NOT_IMPLEMENTED` CMake 变量。
7. 新增 `test/brightness_platform_boundary_test.dart`，固定平台能力、依赖清单、生成插件图和桌面注册器四层边界。

这不是在插件内部猜测特定显示器的 DDC/CI 行为，而是让 Windows 构建从源头不再包含该物理亮度所有者。

## 验证证据

### 确定性红灯

修订前运行：

```powershell
.\tool\local_ci.ps1 -Scope Focused `
  -TestPath test/brightness_platform_boundary_test.dart -SkipPubGet
```

结果为 1/4 通过、3/4 失败：失败项分别锁定桌面插件图、生成注册器/CMake 和通用依赖清单。记录：

`local-artifacts/build-records/20260913T200405980Z-quality-focused.json`

### 修订后质量门禁

13 个直接导入或覆盖 `VideoController` 的测试文件合并执行：

- Flutter tests：**245/245 PASS**；
- `flutter analyze`：**No issues found**；
- 本批 analyze 调用：**1 次**；
- 锁文件以 `pub get --enforce-lockfile` 重新验证；
- 仓库审计：0 error。

记录：

`local-artifacts/build-records/20260913T201409874Z-quality-focused.json`

### Windows 构建边界

命令：

```powershell
.\tool\build_local_release.ps1 `
  -Target WindowsX64 -Configuration Debug -SkipQuality
```

结果：

- Windows x64 Debug 构建成功，记录耗时 302.117 秒；
- ZIP：`local-artifacts/3.1.8-4121/PureLive-3.1.8-4121-windows-x64-debug.zip`；
- 大小：142,781,856 bytes；共 1,301 项；
- SHA-256：`842FC2A8E959EC5B48E9C8892EA9E486B97845B4ADF6401DD958A17973025E49`；
- 构建日志中的 `screen_brightness` 命中：0；
- `build/windows/x64/install_manifest.txt` 命中：0；
- 最终 ZIP 条目命中：0；
- `dumpbin /dependents pure_live.exe` 未列出 `screen_brightness_windows_plugin.dll`。

构建记录：

`local-artifacts/build-records/20260913T201936245Z-build-windowsx64-debug.json`

增量 `build/windows/x64/runner/Debug` 仍保留上一轮构建遗留的同名 DLL；它没有出现在 EXE 依赖表、当前构建日志、安装清单或新 ZIP 中。仓库打包流程正是按当前安装清单建立干净目录，避免把已移除插件的旧文件带入产物。

## 证据边界与后续

- 本轮没有启动 Windows GUI，没有执行任何亮度写入，也没有操作 Android 设备。
- 当前证据证明代码、生成注册、链接依赖和打包产物已移除 Windows 亮度插件；报告者具体 AOC 显示器的两分钟双屏复验尚未执行。
- W1-01 保持 `RUN`；宏观账本保持 **20 PASS / 42 RUN / 0 NR，共 42 组未闭环**。
- 本轮 Astra Light 使用 **0 次**。进入 Windows GUI 验收批次时只创建一个 Astra Light 任务并复用，覆盖主副屏移动、最小化/恢复、焦点切换、全屏往返和至少两分钟持续播放；其余工作继续使用常规模型。
