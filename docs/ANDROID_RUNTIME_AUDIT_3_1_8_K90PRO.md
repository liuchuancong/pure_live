# v3.1.8 K90 Pro Android 运行审计

日期：2026-09-01  
应用：Pure Live `3.1.8`，arm64 分包 `versionCode=6121`  
设备：K90 Pro / `25102RKBEC`（`myron`），Android 17 / API 37，arm64-v8a

本文只记录已经在新设备取得的事实。尚未执行的直播、录制和长时组合继续留在总验收矩阵中，不由安装成功、接口探针或短时首页样本代替。

## 1. 设备与连接基线

- 物理显示为 `1200×2608`、480 dpi，系统公开 60/90/120 Hz 三种模式；测试时活动模式及 SurfaceFlinger 应用请求均为 120 Hz。
- 网络 ADB 同时暴露 IP serial 与 mDNS alias，所有命令固定指定同一个 IP serial，避免同一物理设备被当成两台设备。配对端口、配对码和连接地址不写入仓库。
- UI 回归不依赖 root；设备中安装了管理工具不等同于 ADB shell 已获得 root。本轮没有修改应用数据、账号、Cookie、系统包或其他应用。
- 用户切到其他应用时，`android_ui.ps1` 的前台校验会在触控前终止。本轮准备进入直播间时检测到 Bilibili 在前台，操作按设计停止，没有把缓存坐标发送给其他应用。

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

## 4. 首页与热门页

| 项目 | 结果 | 已观察事实 |
|---|---|---|
| 关注首页 | PASS（当前样本） | 三个状态标签、11 个平台标签、4 个底部入口都落在物理屏幕内；当前“已开播”桶为空时显示明确空状态和“查看未开播”，6 个关注数据仍在 |
| 首页下拉 | PASS（手势链） | 从列表顶部真实下拉，流程在约 5.2 秒内完成；应用保持可操作且无 Pure Live FATAL/ANR。直播事实准确性仍要与各平台当前房间状态交叉验证 |
| Bilibili 热门 | PASS（当前样本） | 约 7 秒内得到完整双列缩略图；可见热度按 43.6万、41.5万、39.8万、38.9万、35.7万、28.5万递减，卡片没有逐个换位或残留加载占位 |
| 热门纵向手势 | RUN | 连续上下滑动后应用仍响应；Android `gfxinfo` 对 Flutter Surface 本轮返回 0 个 View 帧，故不把该计数写成帧率通过，后续改用 SurfaceFlinger/Perfetto 或屏幕录像时间线 |
| 刷新率请求 | PASS（首页） | K90 Pro 活动显示模式为 120 Hz；SurfaceFlinger 存在 Pure Live 的 `RequestedRefreshRateVote=120.00001` |

截图和语义证据位于 `local-artifacts/diagnostics/android-k90pro/`，其中包括干净首页、Bilibili 热门双列网格和对应 UI XML。该目录是本地证据，不提交包含设备状态的图片。

## 5. 后续实机顺序

手机空闲且 Pure Live 处于前台后，按以下顺序继续，并在每次触控前保留前台保护：

1. Bilibili 普通 16:9 房间：首帧、弹幕、画质、线路、系统返回；
2. 抖音原生竖屏房间：普通页、竖屏沉浸、横屏居中背景、PiP 与应用小窗；
3. 虎牙、斗鱼代表房间：短签名续接、画质线路、弹幕和 2～3 分钟录制；
4. 纯音频往返、后台总开关、锁屏、系统 PiP 与停止计时；
5. 录制中心的实时大小、稳定会话开始时间、重试分片、停止/删除和滚动边界；
6. 30～60 分钟资源趋势、CPU/温度、播放器结束后的进程/媒体会话/Wake Lock 回落。

