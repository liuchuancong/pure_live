# Pure Live v3.1.5 Android / Windows 双平台发布

## 1. 发布范围

- 版本：`3.1.5+4118`
- 目标：Android `arm64-v8a` APK、Windows x64 可选目录安装程序和便携 ZIP。
- 源码：两个平台从同一干净冻结提交串行构建；不会把旧版本安装包改名复用。
- 上游：本轮不拉取、不合并上游提交，只统一维护分支现有修复的版本和发布资产。

## 2. 包含的修复

### Android

- 保留 v3.1.4 对上游 Issue #826 的根因修复：Android/iOS 宽屏、横屏和平板形态仍使用触控下拉刷新，桌面宽屏继续使用桌面分页交互。
- 平台标签左右切换和列表纵向刷新保持独立手势轴；空列表、短列表继续允许拖动显示刷新指示器。

### Windows

- 包含 v3.1.3 多画面真全屏显式退出入口，以及 v3.1.2 Windows 原生真全屏边界和窗口状态恢复修复。
- 安装程序继续允许选择目标目录；便携 ZIP 适合免安装或整目录迁移。
- 打包阶段依据当前 CMake install manifest 建立独立目录，并拒绝开发符号、退役插件 DLL 和运行时用户数据进入产物。

## 3. 质量证据

- 业务源码最近一次完整门禁：Analyze 0 issue、Flutter 测试 675/675、公开平台接口 42/42、全仓审计 3895 个文件且 0 error。
- 完整记录：`local-artifacts/build-records/20260831T171731254Z-quality-full.json`。
- 本轮只改版本、平台更新源、工作流默认标签与发布文档，因此双平台打包复用上述业务源码门禁；每个平台仍分别执行自己的内容完整性、文件清单、版本和哈希核验。

## 4. 构建与资产

冻结提交与标签提交均为 `dacd2daf07e1817923a02d04c7d3519c97df829a`。发布严格按 Android、Windows 两个阶段串行进行：

| 平台 | 命令 | 耗时 | 峰值 CPU | 峰值工作集 | 收尾 |
| --- | --- | ---: | ---: | ---: | --- |
| Android arm64-v8a | `build_local_release.ps1 -Target AndroidArm64 -Configuration Release -SkipQuality` | 656.738 s | 55.25% | 18,827,100,160 bytes | 重型进程 0 |
| Windows x64 | `build_local_release.ps1 -Target WindowsX64 -Configuration Release -SkipQuality` | 791.532 s | 51.71% | 20,274,487,296 bytes | 重型进程 0 |

构建产物：

| 资产 | 大小 | SHA-256 | 签名状态 |
| --- | ---: | --- | --- |
| `PureLive-3.1.5-4118-debug-signed-android-arm64-v8a-release.apk` | 118,449,355 bytes | `c4380eefa002b525e1fabeadd7ecb5c616b3b5972af232dccc2fc86ba2e8ff39` | Release 编译模式，本地调试证书 |
| `PureLive-3.1.5-4118-windows-x64-portable.zip` | 72,310,038 bytes | `b07741c5acab25b56e252aaf9286c8f3e2f79b7114d0e56813ce1e8a5dc3bd0b` | 便携 ZIP，不适用 Authenticode |
| `PureLive-3.1.5-4118-windows-x64-setup.exe` | 56,041,592 bytes | `6d00beb58d66dd7e0b1f8ee201ffa98923b7efd7563bf1ce2752911ecf4a38ae` | 未配置 Authenticode |

- Android 内容门禁：包名 `com.mystyle.purelive`、版本名 `3.1.5`、基础 build `4118`、arm64 ABI 偏移 `2000`、Manifest `versionCode=6118`、唯一 ABI `arm64-v8a`、Flutter 资源 1258 项。
- Windows ZIP 内容门禁：1301 项，`pure_live.exe`、`WebView2Loader.dll`、Flutter manifest 与 v3.1.5 更新源齐全；开发符号、退役 QuickJS DLL、`AppData` 和 `IPTV_CACHE` 均为 0。
- Android 构建记录：`local-artifacts/build-records/20260831T181145177Z-build-androidarm64-release.json`。
- Windows 构建记录：`local-artifacts/build-records/20260831T182546971Z-build-windowsx64-release.json`。
- GitHub Release 同时提供 `BUILD_METADATA.json`、`WINDOWS_BUILD_METADATA.json`、Android/Windows 各自的 SHA-256 清单和三个安装资产，共 7 个文件。

## 5. 安装与升级

- Android：包名保持 `com.mystyle.purelive`，同签名安装可直接覆盖并保留配置；签名不同的历史包需按 Android 的签名一致性规则处理。
- Windows 安装程序：安装时可选择目录，升级前仍会按现有迁移逻辑识别旧数据；便携版应完整解压到目标目录后运行。
- Windows 安装程序和便携版使用同一 Release 构建目录；便携 ZIP 不包含测试期间生成的 `AppData` 或 `IPTV_CACHE`。

## 6. 证据边界

- 自动化与打包成功证明源码可分析、测试和生成结构正确的安装包，不替代所有设备、所有直播平台和长时间观看的人工运行验证。
- Android 平板横屏的物理设备交互仍以实际平板或可调宽窗口复验为准；已有宽屏移动判定与真实 pointer drag 回归不会被写成虚假的实机结论。
- Windows 未配置 Authenticode 或 Android 使用本地调试证书时，资产名、元数据和说明会明确披露签名状态。

## 7. 回滚边界

本轮没有新增业务行为。回滚只涉及版本、更新源、工作流默认标签、发布文档和平台打包配置；Android 平板刷新与 Windows 多画面/全屏修复本身分别保留在 v3.1.4 与 v3.1.3 的可审计提交中。
