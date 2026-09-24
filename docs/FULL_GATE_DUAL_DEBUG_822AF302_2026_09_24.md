# `822af302` 完整门禁与双端 Debug 候选（2026-09-24）

本批输入为干净提交 `822af3024746e1772415904582d9a5502c2eee92`。它纳入[Windows 标题栏 Overlay 修订](WINDOWS_TITLE_BAR_OVERLAY_RUNTIME_AUDIT_2026_09_24.md)和房间/多画面平台徽标的无适配器资源查询；未合并上游、安装手机应用或发布版本。

## 完整质量门

`tool/local_ci.ps1 -Scope Full` 成功：全仓 Analyze **No issues found**、Flutter **5326/5326**、公共接口 **42/42**。仓库审计 5123 个跟踪文件、0 error、2 项既有清单 warning，设备静态夹具检查未发出真实 ADB 操作。记录 `local-artifacts/build-records/20260923T185608270Z-quality-full.json`：输入工作树干净、运行中源码未变化、结束后活跃重型进程 0。

## 串行本机构建

| 平台 | Debug 产物 | 核验 |
| --- | --- | --- |
| Android arm64-v8a | `PureLive-3.1.8-4121-android-arm64-v8a-debug.apk`，290061996 B；SHA-256 `5E9B29B5962CE4F4A83D37ACD1B035DE35B4D30E50EE80086B1A5C29ECC1DEDC` | `20260923T185754279Z-build-androidarm64-debug.json` 成功；包名 `com.mystyle.purelive`、Manifest code 6121、minSdk 26、16 个原生库、ELF LOAD 至少 `0x4000`、APK 内容完整性通过 |
| Windows x64 | `PureLive-3.1.8-4121-windows-x64-debug.zip`，143795654 B；SHA-256 `AA59CF3A9BF33E18D27FDCFBB1FE11EED683336AE354B552DFD8C013D5FA0D6B` | `20260923T190132254Z-build-windowsx64-debug.json` 成功，未签名 |

两个构建使用同一通过完整门禁的源码提交，依次完成，没有并行。手机只读核对 `25102RKBEC` / `myron`；本批观察到前台先为小红书、后为哔哩哔哩，未安装、唤醒或输入。先前 Windows GUI 的标题栏异常消失证据属于 `d1437fe5` 候选，不自动覆盖本批新 ZIP；本批 Android/Windows 候选均待当前输入的原生功能验收。

当前产物仍是 **3.1.8+4121 Debug 候选**。Android A0～A8、Windows 实际播放/录制及 Issue #875/#767 长时性能、逐平台源稳定性、正式签名和 3.2.0 Release 均未闭环。
