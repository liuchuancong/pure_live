# Android 实机回归记录（2026-08-28）

## 设备与候选

- 设备：OPPO `PJZ110`，Android 16，`arm64-v8a`。
- 屏幕：1440×3168，密度 640；设备声明并实际运行 120 Hz。
- 初始电量 47%，电池温度 37.2 °C。
- 覆盖前已安装版本：3.0.19（versionCode 6107）。
- 当前源码 Debug APK：`local-artifacts/3.0.19-4107/PureLive-3.0.19-4107-android-arm64-v8a-debug.apk`，224,988,602 字节。
- 构建记录：`local-artifacts/build-records/20260828T055634020Z-build-androidarm64-debug.json`。

## 已完成实机步骤

1. Android arm64 Debug 串行增量构建成功；APK 的目标 ABI、Flutter 资源与关键原生库完整性门禁通过。
2. 通过 ADB 流式覆盖安装成功，包名保持 `com.mystyle.purelive`，安装后进程正常启动。
3. 覆盖安装后关注数据和直播卡片仍存在，证明本次 Debug 覆盖没有重置用户数据。
4. 首页进入前台并完成卡片加载；保存截图：`local-artifacts/diagnostics/android-regression/post-install-home.png`。
5. 设备原先开启的“指针位置”“显示点按”和布局边界调试层已关闭，后续性能观察不再混入系统开发者叠加层开销。
6. 首页完成 10 组上/下滚动输入。Flutter 使用独立 Surface，Android `dumpsys gfxinfo` 在该场景返回 0 帧，因此该计数不作为流畅度结论；后续改用 SurfaceFlinger/Perfetto 和肉眼交互证据。

## 本轮发现并修复的工具问题

无线 ADB 的设备序列号可能包含空格。旧安装脚本使用“连续非空字符”解析序列号，会误报设备离线。本轮改为从 `adb devices` 行尾的 `device` 状态向前提取完整序列号并去除首尾空白；随后同一无线设备的覆盖安装与启动均成功。

## 连接中断后的边界

完成安装、启动、数据保留和首页滚动后，无线 ADB 会话从设备列表退出；mDNS 仍显示旧端点，但 TCP 端口拒绝连接。以下项目因此保留到设备重新上线后的同一回归批次：

- 冷启动与后台恢复计时；
- 首页关注/热门/分区/搜索及下拉刷新；
- 哔哩哔哩直播首帧、弹幕、画质/线路；
- 竖屏、横屏、音频、Android PiP 进入与恢复；
- 本地弹幕、录制中心短录与文件核验；
- CPU、PSS、温度、电量、SurfaceFlinger 帧时序及重复切换趋势。

本记录只把实际执行过的步骤列为通过，未把 Windows 结果或静态测试外推成 Android 模式结论。
