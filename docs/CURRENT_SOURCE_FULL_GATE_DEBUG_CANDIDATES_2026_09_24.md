# 当前源码完整门禁与双端 Debug 候选（2026-09-24）

本批输入为干净提交 `52be1624f03f21c093b61a914f1f2eb0575dc148`，包含首选平台可见性/筛选优化与小红书官方直播深链导入。没有合并上游、安装手机应用或发布版本。

## 完整质量门

`tool/local_ci.ps1 -Scope Full` 成功：全仓 Analyze 无问题、Flutter **5324/5324**、公共接口 **42/42**。记录 `local-artifacts/build-records/20260923T182144239Z-quality-full.json`；输入时工作树干净，运行中源码未变化，结束后无活跃重型进程。仓库审计和设备静态夹具检查通过；这些证据不替代原生客户端操作。

## 串行构建

| 平台 | 本地 Debug 产物 | 核验 |
| --- | --- | --- |
| Android arm64-v8a | `PureLive-3.1.8-4121-android-arm64-v8a-debug.apk`，290060910 B；SHA-256 `04C597E8E217A2DCC8C83A925D49B6EF7CC968F78BD5992E02A9503765E5A981` | `20260923T182320498Z-build-androidarm64-debug.json` 成功；包名 `com.mystyle.purelive`、Manifest code 6121、minSdk 26、16 个原生库、ELF LOAD 至少 `0x4000`、APK 内容完整性通过 |
| Windows x64 | `PureLive-3.1.8-4121-windows-x64-debug.zip`，143794825 B；SHA-256 `D0C1751AA9D53C5B1E46491B4FEC8170D617BBDD31E4E4B44712FCD7AE526440` | `20260923T182517845Z-build-windowsx64-debug.json` 成功，未签名 |

两端构建使用同一通过完整门禁的源码提交，并串行完成。手机只读确认 `25102RKBEC` / `myron`、root 已授权，前台仍为哔哩哔哩；没有安装、唤醒或输入。当前安装包与本批 Android 候选不是同一输入。Windows GUI、双端播放/录制、长时与平台矩阵仍待当前候选原生验收。

当前产物仍是 **3.1.8+4121 Debug 候选**，不是 3.2.0 Release。后续按设备轮转规则集中验收，缺陷修订后重建受影响候选；验收闭环后冻结版本、签名与发布。
