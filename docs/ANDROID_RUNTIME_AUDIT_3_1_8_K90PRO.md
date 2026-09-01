# v3.1.8 K90 Pro Android 运行审计

日期：2026-09-01  
应用：Pure Live `3.1.8`，arm64 分包 `versionCode=6121`  
设备：K90 Pro / `25102RKBEC`（`myron`），Android 17 / API 37，arm64-v8a

本文只记录已经在新设备取得的事实。尚未执行的直播、录制和长时组合继续留在总验收矩阵中，不由安装成功、接口探针或短时首页样本代替。

## 1. 设备与连接基线

- 物理显示为 `1200×2608`、480 dpi，系统公开 60/90/120 Hz 三种模式；测试时活动模式及 SurfaceFlinger 应用请求均为 120 Hz。
- 网络 ADB 同时暴露 IP serial 与 mDNS alias，所有命令固定指定同一个 IP serial，避免同一物理设备被当成两台设备。配对端口、配对码和连接地址不写入仓库。
- UI 回归不依赖 root；设备中安装了管理工具不等同于 ADB shell 已获得 root。本轮没有修改应用数据、账号、Cookie、系统包或其他应用。
- 用户切到其他应用时，测试包装层和 `android_ui.ps1 -NoBringToFront` 的前台校验会在触控前终止。本轮准备进入直播间时检测到 Bilibili 在前台，操作按设计停止，没有把缓存坐标发送给其他应用；需要主动开始一段测试时才显式把 Pure Live 拉到前台。

## 2. 覆盖安装与启动

- 从旧版执行 `adb install -r -t` 覆盖安装成功；`firstInstallTime` 保持 `2026-07-21 18:07:53`，`lastUpdateTime` 更新为 `2026-09-01 10:51:26`。
- 包信息为 `versionName=3.1.8`、`versionCode=6121`、`targetSdk=37`。
- 第一次启动即进入主页，原关注数据保留，界面明确显示共有 6 个关注；没有 AndroidRuntime/FATAL。
- 启动约 12 秒的首个样本为 TOTAL PSS 179,370 KB、TOTAL RSS 377,012 KB。页面稳定并完成首页/热门操作后的另一短样本为 TOTAL PSS 135,053 KB、TOTAL RSS 249,032 KB、瞬时 CPU 约 1%、电池温度 35.9°C。两个离散点只作为起始基线，不用于宣称不存在泄漏。

## 3. 新设备 UI 地图

- `tool/device_ui_map.json` 新增 `k90pro_portrait_1200x2608` 和 `k90pro_landscape_2608x1200`，并把前者设为默认配置；PJZ110 两个配置继续保留。
- 初始坐标由 PJZ110 按物理尺寸换算，不直接冒充测量值。主页实际语义快照完成后，菜单、状态标签、平台标签、空状态入口和底部导航已用 K90 Pro 实测边界校正。
- 新增首页顶部下拉刷新手势和 `refresh_home` 流程；实际执行后应用保持前台、操作完成且无 Pure Live FATAL/ANR。
- 实机暴露了两个测试工具问题并已修复：Windows PowerShell 5.1 解析脚本中损坏的非 ASCII 正则会中止快照；其 JSON 序列化还会制造大面积无意义缩进差异。过滤表达式现为 ASCII，UI XML 以二进制拉取后显式按 UTF-8 读取，JSON 使用跨 PowerShell 版本一致的两空格格式写回。
- `validate_device_ui_map.py` 现在检查点位/节点边界、中心、语义类型和 Unicode replacement character，避免乱码快照进入仓库。
- 当前 Issue 相邻回归分两组执行：WebSocket 重连、弹幕生命周期、虎牙醒目留言和多画面退出 17/17；导航边界、关注刷新、搜索、画质文案、直播页布局、竖屏面板、录制中心、弹幕列表和设置面板 64/64。记录分别为 `local-artifacts/build-records/20260901T031920369Z-quality-focused.json` 与 `local-artifacts/build-records/20260901T032610237Z-quality-focused.json`。

## 4. 首页与热门页

| 项目 | 结果 | 已观察事实 |
|---|---|---|
| 关注首页 | PASS（当前样本） | 三个状态标签、11 个平台标签、4 个底部入口都落在物理屏幕内；当前“已开播”桶为空时显示明确空状态和“查看未开播”，6 个关注数据仍在 |
| 首页下拉 | PASS（手势链） | 从列表顶部真实下拉，流程在约 5.2 秒内完成；应用保持可操作且无 Pure Live FATAL/ANR。直播事实准确性仍要与各平台当前房间状态交叉验证 |
| Bilibili 热门 | PASS（当前样本） | 约 7 秒内得到完整双列缩略图；可见热度按 43.6万、41.5万、39.8万、38.9万、35.7万、28.5万递减，卡片没有逐个换位或残留加载占位 |
| 热门纵向手势 | RUN | 连续上下滑动后应用仍响应；Android `gfxinfo` 对 Flutter Surface 本轮返回 0 个 View 帧，故不把该计数写成帧率通过，后续改用 SurfaceFlinger/Perfetto 或屏幕录像时间线 |
| 刷新率请求 | PASS（首页） | K90 Pro 活动显示模式为 120 Hz；SurfaceFlinger 存在 Pure Live 的 `RequestedRefreshRateVote=120.00001` |

## 5. 权限与后台前置条件

- 通知权限已授予，系统允许 `START_FOREGROUND`、Wake Lock 和后台运行，Pure Live 也在 device-idle 用户白名单中。
- 新设备当前没有授予悬浮窗 app-op，`SYSTEM_ALERT_WINDOW` 为 `ignore`；系统 PiP 不依赖该权限，但应用外悬浮窗测试必须先走一次真实授权流程。
- `READ_MEDIA_VIDEO` 当前未授予，`MANAGE_EXTERNAL_STORAGE` 仍为系统默认。默认应用私有录制目录会先执行真实写入探针并可直接使用；外部自定义录制目录必须在实机选择目录后验证读写、重启持久化、打开目录和拒绝权限提示。先保留新安装的真实状态，避免预授权掩盖权限流程缺陷。

截图和语义证据位于 `local-artifacts/diagnostics/android-k90pro/`，其中包括干净首页、Bilibili 热门双列网格和对应 UI XML。该目录是本地证据，不提交包含设备状态的图片。

## 6. 共享轮转直播冒烟

- 三任务共享手机通过 `A 哔哩哔哩模块 → B 小红书模块 → C Pure Live` 文件租约轮转；Pure Live 的完整实机动作全部放在一个 C quantum 内，结束后只停止 `com.mystyle.purelive` 并交棒。协调器记录 lane、循环编号、退出码与 `graceSkip`，不记录配对信息或账号数据。
- 仓库新增 `tool/android_runtime_smoke.ps1`：冷启动、首页刷新、热门/Bilibili 进房、弹幕连接、画质/线路、纯音频往返、系统 PiP、恢复直播页、返回、PSS/RSS/CPU/线程/帧时间和日志都由同一脚本采证。USB 与网络 ADB 同时存在时选择唯一网络 transport；多个网络目标时要求显式 `-Serial`。
- cycle 14 在 v3.1.8+4121 上真实退出 0，14/14 命名断言通过。当前样本进入 Bilibili 竖屏源，画面首帧、`原画`、`线路1`、弹幕服务器连接、普通弹幕均可见；纯音频状态与视频恢复分别被 UI 轮询观察到，系统 PiP 成功进入，重新拉起主 Activity 后弹幕页及新消息继续工作。
- UIAutomator 首次观察到纯音频/视频恢复状态分别为 4,514 ms / 5,506 ms；该数字包含每轮 XML dump/pull 的探针开销，只作为有界状态到达证据，不当作用户可见切换延迟。后续如需精确延迟，使用屏幕录像或 SurfaceFlinger 时间线。
- 恢复直播并稳定后的离散点为 TOTAL PSS 277,778 KB、TOTAL RSS 462,584 KB、Swap PSS 166 KB、75 线程、`dumpsys cpuinfo` 瞬时 1.6%；日志没有 Pure Live FATAL/ANR。`gfxinfo` 只观察到 9 个 Android View 帧、P50/P90/P95/P99 均 5 ms，覆盖范围不足以代表 Flutter 播放/滚动流畅度。
- cycle 12 的应用功能同样为 14/14，但测试器末尾把逗号分隔的比较表达式解析成一次“值与数组比较”，产生了假失败。断言现改为命名有序表，失败时输出具体名称；旧证据离线回放 14/14，新脚本在 cycle 14 实机退出 0，问题归属于测试工具而不是客户端。
- cycle 15 再次真实退出 0，14/14 断言通过；直播、弹幕、纯音频往返、系统 PiP 恢复和返回链保持正常，日志过滤结果为 0 个 FATAL/ANR/Flutter/解码/Surface 异常。离散资源点为 TOTAL PSS 276,561 KB、TOTAL RSS 460,320 KB、Swap PSS 163 KB、75 线程、瞬时 CPU 1.5%。本轮脚本在租约内先执行唤醒和无凭据 keyguard 清理，系统证据为 `SCREEN_STATE_ON`、`INTERACTIVE_STATE_AWAKE`。
- cycle 27 使用最终时间戳修复源码重新构建的 arm64 Debug APK 覆盖安装并真实退出 0。APK 为 `301,635,003 bytes`，SHA-256 `BB517F79BB25CB9C1700128F295DD0A99E9C9FF5B9E3F509D70F0B48FEBC42C2`；构建门禁核对 16 个 arm64 原生库的最小 ELF LOAD 对齐均不低于 `0x4000`，APK 同时通过 `zipalign -P 16`。设备当前页大小为 4096 bytes，但冷启动没有出现 Android 16 KB 兼容性警告。
- cycle 27 的 15/15 命名断言全部通过：覆盖安装后的版本为 `3.1.8 / 6121`，房间 UI、9 条可见真实弹幕、画质、线路、纯音频往返、系统 PiP、恢复后的弹幕页和返回链均成立，日志没有 FATAL/ANR。此前测试器只接受短暂的“弹幕服务器连接正常”和“原画”两个固定文案，忙碌房间中系统消息滚出可访问树、选中“超清”时会产生客户端正常但脚本失败；断言现同时接受真实 `用户: 内容` 行及平台归一化画质标签。最终证据为 `local-artifacts/diagnostics/android-runtime-smoke-20260901T202512542/summary.json`，构建记录为 `local-artifacts/build-records/20260901T122355411Z-build-androidarm64-debug.json`。
- 本轮 Debug 离散资源点为 TOTAL PSS 799,687 KB、TOTAL RSS 996,192 KB、Swap PSS 114 KB、80 线程。Debug 包含完整调试资产，且采样发生在视频/音频/PiP 连续切换后；该单点只触发后续 Release 长时趋势验证，不据此推导正式包泄漏。`gfxinfo` 仍只覆盖 9 个 Android View 帧，也不作为 Flutter 动画流畅度结论。
- 上游 #829 相邻场景已用 `tool/android_local_interaction_visibility_smoke.ps1` 单独验收：覆盖安装、读取并暂时关闭“本地互动体验”、进入 Bilibili 房间、切换横屏全屏、检查禁用入口不占位、恢复用户原设置并停止应用。cycle 19 的一次运行在安装后遇到进程级 ADB daemon 被重启，命令没有送达；测试器补充有界 server 恢复。cycle 20 随后真实退出 0，观察到 `2608×1200` 横屏视口、`enablePromptHidden=true`、`originalStateRestored=true`，且没有触发 server 恢复。
- 截图顶部的坐标、压力与边界线来自手机开发者选项“指针位置/布局边界”，不是 Pure Live 绘制层。PiP 截图中的底层页面属于进入 PiP 前的其他任务，Pure Live 只占右上系统 PiP 窗口，恢复后前台包重新为 Pure Live。

本轮证据目录：`local-artifacts/diagnostics/android-runtime-smoke-20260901T142833509/`、`local-artifacts/diagnostics/android-runtime-smoke-20260901T145018348/`、`local-artifacts/diagnostics/android-local-interaction-20260901T154001015/`、`local-artifacts/diagnostics/android-runtime-smoke-20260901T202512542/`。

## 7. 后续实机顺序

手机空闲且 Pure Live 处于前台后，按以下顺序继续，并在每次触控前保留前台保护：

1. Bilibili 普通 16:9 房间：继续补充非竖屏样本的画面比例、横屏全屏、应用小窗与系统返回；
2. 抖音原生竖屏房间：普通页、竖屏沉浸、横屏居中背景、PiP 与应用小窗；
3. 虎牙、斗鱼代表房间：短签名续接、画质线路、弹幕和 2～3 分钟录制；
4. 纯音频往返已完成单轮；继续执行后台总开关、锁屏、重复 10 次系统 PiP 与停止计时；
5. 录制中心的实时大小、稳定会话开始时间、重试分片、停止/删除和滚动边界；
6. 30～60 分钟资源趋势、CPU/温度、播放器结束后的进程/媒体会话/Wake Lock 回落。
