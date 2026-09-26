# 3.2.0 剩余工作与当前候选（2026-09-24）

本页只保留当前快照和主要阻塞。逐批历史已移至[状态时间线归档](ACCEPTANCE_STATUS_HISTORY_3_2_0.md)，编号证据以[验收矩阵](ACCEPTANCE_MATRIX_3_1_0.md)为准，执行顺序见[完整验收入口](ACCEPTANCE_3_2_0.md)。**v3.2.0 已于 2026-09-25 从 `claude` 分支发布（Android arm64、Windows x64、Linux x64，未推送应用内更新）；下表的真机验收缺口在发布后继续补齐。**

## 当前可证明的状态

| 项目 | 当前证据 |
| --- | --- |
| 功能源码基线 | 依赖配置至 `060420f7`：Flutter 3.47.5、AGP 9.3.3、Gradle 9.7.1、pub 直接与传递图均已复核升级，FFmpeg 9.0.2 覆盖 Android/Windows/Linux/macOS/iOS。最新本地 Full 记录 `20260924T033341958Z-quality-full.json`（`b6033234`，Analyze 与 **5334/5334** 测试通过），随后 Android/Windows 原生候选及 Linux/macOS/iOS 单平台构建分别通过；公开接口探测 **42/42**。这仍不代替双端客户端完整验收 |
| Android 最新本机构建/原生输入 | `e4532d77` arm64 Debug 已通过 `20260924T033620351Z-build-androidarm64-debug.json`；FFmpeg 9.0.2 AAR、18 个原生库及 16 KB ELF 门禁由本机构建验证。手机上已安装的是较早 `31a3c964` 候选，当前原生升级包尚待按设备轮转窗口覆盖安装并执行 A0～A8 |
| 五平台原生升级 | [Linux 构建](https://github.com/liuchuancong/pure_live/actions/runs/35956033043)、[macOS 应用构建](https://github.com/liuchuancong/pure_live/actions/runs/35974500374)与 [iOS 应用构建](https://github.com/liuchuancong/pure_live/actions/runs/35977431211)通过，Apple 两端均核对实际打包的 FFmpeg 9.0.2 架构和版本；这是构建证据，不等于设备/GUI 功能验收 |
| Android 当前编号账本 | 46 行：16 PASS / 30 RUN / 0 NR；每行仍含多个动作和平台组合，旧包证据不自动覆盖当前源码 |
| Windows 最新归档 | `e4532d77` x64 Debug 构建已通过 `20260924T033917897Z-build-windowsx64-debug.json`，含 FFmpeg 9.0.2；当前 Native Assets 候选仍需 1+3、2×2、音频、帧进度和严格退出 GUI 复验 |
| 手机快照 | `192.168.1.2:5555` 已核对 25102RKBEC / myron，`su -c id` 为 root。覆盖安装前 Pure Live 无运行进程或录制服务；安装后前台是另一应用，本批未启动 Pure Live、唤醒屏幕或发送界面输入。实际运行时动作前需重读手机状态 |
| 当前安装 APK | 3.1.8 / 6121，2026-09-24 09:40 本地时间覆盖安装成功；安装包与 `31a3c964` Debug 候选同 SHA-256 `3B572462…D543AF`，`firstInstallTime` 仍为 2026-07-21 18:07:53，数据未执行清除；正式签名候选仍待生成 |
| 平台范围 | 当前 **34 个直播站点 + IPTV，0 组未注册**，即源码共 35 个适配器（3.2.8 前为 45 站）。3.2.8 下线花椒、OPENREC、TTingLive、PopkonTV、GoodGame、VK Video Live、Dailymotion、Rumble、NimoTV、Shopee Live、淘宝直播，并删除未注册的战旗、浪 Live 代码，依据见[平台兼容性](PLATFORM_COMPATIBILITY.md)开头说明；DLive、一直播与企鹅电竞已归档生命周期证据；已注册平台仍有能力与双端原生覆盖缺口 |
| 编号总账 | 历史大组 20 PASS / 42 RUN / 0 NR；RUN 是待补证或部分完成，不等于 42 个当前 Bug |

## 编号统计

| 范围 | 总大项 | PASS | RUN：部分完成 | NR：未执行 |
| --- | ---: | ---: | ---: | ---: |
| Android | 46 | 16 | 30 | 0 |
| Windows | 16 | 4 | 12 | 0 |
| 合计 | 62 | 20 | 42 | 0 |

当前账本已有 20 项 PASS、42 项 RUN、0 项 NR，共 **42 个历史大项尚未闭环**。一行通常包含多个动作或平台组合；旧版本、旧设备、单次探针或源码测试不会自动覆盖当前候选的整行。

## 主要阻塞

1. **当前原生闭环缺失**：升级版 Android Debug 已本机构建，但手机仍装较早候选；A0～A8 与当前 Windows Native Assets 的 GUI/录制复验待按轮转窗口执行。两端均无 3.2.0 Release 候选。
2. **Windows GUI/性能批次未完成**：`e4532d77` Debug 已构建；旧版 1+3 [原生复验](ISSUE_875_WINDOWS_MULTIVIEW_FRAME_STALL_AUDIT_2026_09_23.md)不能代替升级版。多 DPI、主副屏、PiP/全屏/多窗口、WebView2、Issue #767 的 4K GPU 对照、Issue #875 的大格停帧判别、音频与帧进度及严格退出计时仍需集中执行。
3. **Android 组合矩阵未闭合**：当前候选仍需覆盖锁屏/后台、横屏/系统返回、PiP、实体音量键、自动录制和累计数据迁移；设备在线时优先合并执行。
4. **平台与录制范围较大**：每个平台的目录、播放、弹幕、录制、断流恢复和资源释放尚未全部在当前双端候选上完成；OPENREC 当前本机官网/公共接口 CloudFront 403，需在可访问窗口复核；长录和严格解码仍是发布门禁。
5. **平台扩展继续推进**：战旗与浪 Live 等待当前生产媒体证据后注册；DLive、一直播与企鹅电竞已完成生命周期归档；PandaTV、PopkonTV、Shopee Live、VK Video Live、NimoTV、Dailymotion、Rumble、GoodGame、FC2 Live、Steam Broadcasts、京东直播、淘宝直播、酷狗直播、百度直播、六间房直播与 LOOK 直播已进入源码能力表，双端原生与录制证据并入集中验收。
6. **发布链未开始**：版本冻结、正式签名、全平台串行产物、README/更新日志、资产复验和 GitHub 发布均等待前述门禁。

## 下一批顺序

1. 继续按战旗、浪 Live 的生产证据门槛与 C2/C3 活跃平台顺序扩展源码；同时完成当前仍可确定复现的 Issue/所有权缺口，已经修复或证据不足的条目停止重复调查。
2. Android 与 Windows 以 `e4532d77` 原生升级 Debug 作为下一批候选；Windows 批量复验多格画面、音频与退出。Android 当前安装的是较早候选，手机进入可用测试窗口后按轮转规则保留数据覆盖安装升级版，再集中收口 A0～A8。
3. 同一候选集中完成平台播放/弹幕/录制、资源与性能证据，失败项回源码修订后只重跑受影响组。
4. 42 个编号组和发布范围实际闭合后，固定 3.2.0 提交并执行完整发布门禁。
