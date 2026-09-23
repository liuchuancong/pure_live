# Pure Live v3.1.0 Android / Windows 验收矩阵

本矩阵是 `docs/FULL_CLIENT_TEST_PLAN_2026_08_28.md` 的 v3.1.0 执行账本。前者保留完整测试方法；本文件补齐近期竖屏全屏、短时签名续接、后台策略和录制状态机，并用统一状态记录每一项是否真的执行。

状态：`NR` 未执行、`RUN` 执行中、`PASS` 通过、`FAIL` 失败、`BLOCKED` 缺少当前外部条件。`PASS` 必须附日志、截图、命令记录或确定性测试路径；构建成功不等于功能通过。

> 阶段性增量说明已移至 [`ACCEPTANCE_MATRIX_HISTORY_3_1_0.md`](ACCEPTANCE_MATRIX_HISTORY_3_1_0.md)。本页只维护 62 个编号行、快速顺序与发布门禁；每行只保留当前结论、关键证据入口和剩余闭环，不追加批次时间线。

## 1. 快速回归顺序

连接 Android 时先跑 A0～A8；随后关闭 Android 重型任务，再串行跑 W0～W8。一次快速回归目标 25～40 分钟：

1. 安装/升级、冷启动、首页首屏和手势；
2. 每个平台选一个开播房间，核对详情、播放、画质/线路、弹幕和观看指标；
3. 当前主问题的相邻模式：竖屏、横屏全屏、系统 PiP、应用小窗、音频、后台、返回；
4. 创建一条短录制，观察实时大小/速率，停止并实读文件；
5. 注入断网/恢复、切后台/恢复、锁屏/恢复；
6. 收集启动、帧、CPU、内存、温度和资源回落；
7. 失败项修复后只先跑目标案例和相邻模式，全部稳定后再执行完整门禁。

## 2. Android 执行账本

### A0 安装、升级与启动

| ID | 状态 | 验收内容 | 证据 |
|---|---|---|---|
| A0-01 | PASS | v3.0.24 正式 APK 覆盖安装，包名、版本、签名、arm64 与原数据保留 | `local-artifacts/3.0.24-4112/release-verify/`；PJZ110 `versionName=3.0.24`, `versionCode=6112` |
| A0-02 | PASS | 冷启动一次进入，无 FATAL/ANR；首屏可交互 | 当前实机 `am start -W`: Total 312 ms / Wait 316 ms；13.17 秒录像显示启动页后进入完整关注网格 |
| A0-03 | PASS | 连续 10 次冷启动、更新后首次启动、清理进程后启动 | v3.1.2 arm64 Release 覆盖升级保留关注数据；10 次强制结束后冷启动全部存活并获得焦点，293～332 ms、平均 306.2 ms，0 FATAL/ANR。见 `docs/ANDROID_RUNTIME_AUDIT_3_1_2.md` |
| A0-04 | RUN | 后台 15 秒、2 分钟、锁屏后恢复；直播状态按阈值刷新且卡片位置稳定 | 首页后台 20 秒热恢复已通过；v3.1.2 虎牙实际播放在其他应用前台时连续 10 分钟保持 `PLAYING`，21 个样本无 FATAL/ANR，结束后进程、媒体会话和 Wake Lock 释放。锁屏后的首页刷新与播放器恢复仍待当前版本补充。见 `docs/ANDROID_RUNTIME_AUDIT_3_1_2.md` |
| A0-05 | RUN | v3.1.4 Android 专项包覆盖升级与关注刷新 | PJZ110 网络 ADB 保持用户其他应用前台完成覆盖安装，核对 `versionName=3.1.4`、`versionCode=6117`；没有强制启动或清理用户任务。手机关注下拉与平板横屏仍按 A1-01 继续 |
| A0-06 | PASS | v3.1.5 双平台一致版静默覆盖升级 | PJZ110 / Android 16 通过网络 ADB 执行 `adb install -r`，安装前后用户前台均保持小红书；核对 `versionName=3.1.5`、`versionCode=6118`，没有启动 Pure Live 或打断用户任务 |
| A0-07 | PASS | v3.1.6 Android arm64-v8a 安装包静默覆盖升级 | PJZ110 / Android 16 从 v3.1.5 执行 `adb install -r` 成功，核对 `versionName=3.1.6`、`versionCode=6119`；安装前后 `com.xingin.xhs/.index.v2.IndexActivityV2` 保持同一前台 Activity，没有启动 Pure Live 或抢占用户界面。安装后空闲基线为活动进程/服务/通知/Wake Lock 均 0，DropBox 中以 Pure Live 为主进程的崩溃/ANR 为 0；见 `docs/ANDROID_POST_INSTALL_BASELINE_3_1_6.md` |
| A0-08 | PASS | v3.1.7 Android arm64-v8a 事件身份补丁静默覆盖升级 | PJZ110 / Android 16 从 v3.1.6 执行 `adb install -r` 成功，核对 `versionName=3.1.7`、`versionCode=6120`；安装前后同一 `com.xingin.xhs/.index.v2.IndexActivityV2` 保持前台，Pure Live 没有被启动且安装后无运行进程 |
| A0-09 | PASS | v3.1.8 Android arm64-v8a 在新主力设备覆盖升级、启动与数据保留 | K90 Pro / `25102RKBEC` / Android 17 通过网络 ADB 覆盖安装，核对 `versionName=3.1.8`、arm64 分包 `versionCode=6121`；一次启动成功、原 6 个关注记录保留、无 AndroidRuntime/FATAL。短时内存只记录为启动基线，完整运行矩阵继续执行 |
| A0-10 | PASS | 斗鱼过滤修订后的 v3.1.8 Android arm64 Debug 覆盖安装与基础运行 | 从干净提交 `971c2753` 构建，APK 为 299,150,717 B，SHA-256 `B0EEAF3434E961EFD10419BEF59AC46164D44CDD61DC5746CCE63C3AFFF259DF`；K90 Pro / cycle 200 覆盖安装并完成 14/14 直播冒烟，无 FATAL/ANR。构建：`local-artifacts/build-records/20260904T193151421Z-build-androidarm64-debug.json`；实机：`local-artifacts/diagnostics/android-runtime-smoke-20260905T033502392/summary.json` |

### A1 首页、关注、热门、分区与搜索

| ID | 状态 | 验收内容 |
|---|---|---|
| A1-01 | RUN | 关注：已开播/录播/未开播与全部平台；下拉动画、失败保留快照、刷新后状态准确。当前冷启动先保留全部卡片原桶位并统一显示“正在核验”，约 3 秒后一次提交完整结果；20 秒热恢复保留旧快照到请求完成。v3.1.4 已修复 Android 平板横屏误判桌面后同时失去内外刷新器，宽屏移动/桌面/窄窗及真实拖动回归通过。K90 Pro / cycle 210 的最终 APK 冷启动后进入“未开播 → 虎牙”，两个真实未开播收藏完整显示且没有数量/列表矛盾，见 `local-artifacts/diagnostics/android-favorite-offline-20260905T043215093/summary.json`。09-20 `abbc4ea8` 修复关注标签筛选条固定 44 px、低于 48 px 命中下限且不足以容纳 3.0 倍文字的问题；现按主题、系统缩放及可见标签动态增高，320×480 / 3.0 倍英文与交互专项 3/3、Analyze 无诊断。平板横屏物理设备、报告者原收藏集合及当前候选触控仍待交叉验证。 |
| A1-02 | RUN | 热门：平台页签边界、快速左右滑、网格纵向惯性、切回保持位置、卡片不跳动。v3.0.24 已完成页签条左右各 20 次快速滑动并稳定停在首尾边界，无 FATAL/ANR；截图、语义树与日志位于 `local-artifacts/runtime/android-v3.0.24/home-platform-boundary/`。K90 Pro / v3.1.8 的 Bilibili 热门约 7 秒得到完整双列缩略图，可见热度严格递减且无逐卡跳位；下拉刷新和连续上下滑后仍可操作。Flutter Surface 没有进入本轮 `gfxinfo` View 帧计数，纵向帧时序仍需 SurfaceFlinger/Perfetto 证据。见 `docs/ANDROID_RUNTIME_AUDIT_3_1_8_K90PRO.md` |
| A1-03 | PASS | 分区：平台标签左右各重复 10/20 次后稳定停在首尾硬边界；网易 CC 旧 JSON 跳转官方 HTML 时返回稳定的“全部 / 端游 / 手游 / 其他”，未串数据、未崩溃。09-12 关注分区另修订显示平台变化后的页签长度/选择身份错位、3.0 倍文字关注按钮溢出和空名称/类型断言，新增 4/4、相关五文件 27/27，见 `docs/FAVORITE_AREAS_STATE_AND_LAYOUT_AUDIT_2026_09_12.md`。09-20 `ac5c97e0` 修复普通分区三列固定网格在 320×480 / 3.0 倍文字下底部溢出 40 px：图片继续保持正方形，标签区按实际应用字号与系统缩放扩展；1.0/2.0/3.0 倍及相邻分区生命周期回归 28/28、Analyze 无诊断。既有原生结论见 `docs/ANDROID_RUNTIME_AUDIT_3_1_2.md` |
| A1-04 | RUN | 搜索：全部/单平台标签左右端点稳定，`LOL` 聚合结果、开播优先排序和平台能力说明均可用；直连 Twitch 明确显示部分平台失败，经可达 Clash 应用代理后 Twitch 原生结果和在线人数正常。源码分页现按平台隔离：允许一个完整重叠页继续取得后续新结果，连续第二个停滞页有界终止，空页/失败平台不随其他平台重试，换词重置预算。文本编辑本身不触发请求；同一平台/关键词的未完成首屏重复提交共用事务，聚合部分呈现后仍不重启，异词/切平台保持 latest-wins，事务结束后同词可刷新。09-20 `5ea194db` 以 40 px 红灯将搜索平台标签恢复为至少 48 px，标签行增至 56 px，边界回归 3/3。真实长列表和双端输入/滚动继续。详见 `docs/SEARCH_PAGINATION_STAGNATION_AUDIT_2026_09_11.md`、`docs/SEARCH_SUBMIT_TRANSACTION_AUDIT_2026_09_11.md`；WebView2 缺失提示见 `docs/WEBVIEW2_MISSING_DIALOG_LAYOUT_AND_TRANSACTION_AUDIT_2026_09_14.md`。 |
| A1-05 | RUN | 历史、标签、工具箱、IPTV、WebDAV、备份/恢复、关于与更新检查的源码/Widget 合同已覆盖加载/空/错误态、窄屏大字号、滚动、路由退出、重复操作、迟到结果和对象身份；早期原生五场景见 [辅助页面审查](AUXILIARY_PAGES_AUDIT_2026_09_07.md)。09-11～09-15 的分项修订各有独立审计，其中版本下载、账号退出、缓存/历史清理、标签管理及二维码同步均已加入单次事务和响应式动作。`9f115f6a` 修复房间卡片标签分配在 1.9 倍文字下固定 68 px 行溢出 21 px；09-20 `2ee98324` 又修复 WebDAV 面包屑固定 50 px 头部在 3.0 倍文字下没有垂直余量。`3b09d74b` 继续以 30.1 px 红灯修复默认字号面包屑命中区，短目录段现至少 48×48 px；WebDAV 与录制设置联合 37/37、Analyze 无诊断。真实 WebDAV 深层目录与传输、系统下载/安装、双端候选触摸/键盘/系统返回及重启数据保留继续；代表证据见 [WebDAV 审计](WEBDAV_STATE_LAYOUT_AND_DIRECTORY_PATH_AUDIT_2026_09_11.md)、[工具箱审计](TOOLBOX_ROUTE_AND_SELECTOR_LAYOUT_AUDIT_2026_09_12.md)、[IPTV 管理审计](IPTV_MANAGE_LAYOUT_AND_LIFECYCLE_AUDIT_2026_09_12.md)和[标签管理审计](TAG_MANAGEMENT_DETAIL_ACCESSIBILITY_AND_ROUTE_AUDIT_2026_09_15.md)。 |
| A1-06 | RUN | 首页上/下各 20 次、平台左/右各 20 次；记录 SurfaceFlinger/Perfetto 帧和主线程阻塞。09-12 新增可复用 SurfaceFlinger timestats/主线程 schedstat 工具及纯解析回归；精确 `09dce413` 的五文件相邻测试 45/45、全库 analyze 通过。K90 / Android 17 / 120 Hz 上绑定 SHA-256 `0F28A5F0…D4CD7F` 的 Debug 候选完成热门网格 20 上+20 下和平台页 20 左+20 右。竖向 2924 帧、P50/P90/P95/P99=8/8/16/24 ms、`>=16 ms` 5.472%、最大 102 ms；横向 2842 帧、8/8/8/16 ms、`>=16 ms` 2.322%、最大 42 ms；两组 dropped/lateAcquire/badDesiredPresent 均 0，页面存活且无 FATAL/ANR。Release 对照、102 ms 离群点 timeline、关注/分区长列表及温升轮次继续，见 `docs/ANDROID_HOME_SCROLL_FRAME_PACING_AUDIT_2026_09_12.md` |

### A2 设置全量

主题/夜间、自定义字体、布局间距、刷新、视频/音量、竖屏直播、观看指标、后台/助眠、小窗弹幕、播放器内核/硬解/代理、本地互动、导航、平台 Cookie、缓存、备份、录制目录、日志。每个控件核对：初始值、修改后即时效果、返回后保存、重启后恢复、跨页面文案一致、Android 不出现 Windows 专属项。

| ID | 状态 | 验收内容 |
|---|---|---|
| A2-01 | RUN | 设置顶/中/底三级页面全部可达，长页滚动到边界，开关与数值无重叠 | 设置首页、页面尺寸、通用/视频/录制、观看数据、导航、加载、字体、代理、主题、缓存、刷新、播放器内核、平台账号、备份、WebDAV、更新与本地互动均已补齐窄屏大字号、滚动边界、输入归一化、路由所有权和迟到结果的确定性覆盖；设置值与备份迁移按平台能力过滤。09-14～09-15 又统一账号退出、缓存/历史清理、字号重置、网络清晰度、ASMR/后台播放、Windows PiP 置顶及标签动作的单次事务、48 px 命中与失败保留。09-20 `3b09d74b` 将录制设置“打开文件夹”从 21 px 修至至少 48 px；`069209d0` 将主题间距增减从 40 px 修至至少 48 px，联合回归 9/9。当前剩余为未覆盖的二/三级页面清单核对，以及 Android/Windows 候选上的触摸/键盘/系统返回、权限/服务失败重试和重启持久化。入口证据见 [设置标题栏审计](SETTINGS_APP_BAR_LAYOUT_AUDIT_2026_09_11.md)、[平台与账号审计](PLATFORM_SETTINGS_AND_AUTH_LAYOUT_AUDIT_2026_09_11.md)、[备份设置审计](BACKUP_SETTINGS_AND_LOCAL_PREVIEW_LAYOUT_AUDIT_2026_09_11.md)、[标签动作审计](TAG_MANAGEMENT_CARD_ACTION_ACCESSIBILITY_AUDIT_2026_09_15.md)。 |
| A2-02 | PASS | PJZ110 正确识别 `120 / 120 Hz`；省电/均衡/最高三档即时更新，恢复最高档后强制结束并冷启动仍保持。K90 Pro / Android 17 也识别 60/90/120 Hz，首页活动模式为 120 Hz 且 SurfaceFlinger 记录 Pure Live 的 120 Hz 请求。主界面与自动弹幕的联动说明一致；证据见 `docs/ANDROID_RUNTIME_AUDIT_3_1_2.md`、`docs/ANDROID_RUNTIME_AUDIT_3_1_8_K90PRO.md` |
| A2-03 | PASS | 后台播放与手动纯音频策略一致；自动助眠按计时继续 | `6458d541` arm64 Release 四组合实机通过：关闭开关后手动纯音频退桌面由 `PLAYING` 转 `PAUSED` 且当前 Wake Lock 为 0，回前台恢复；开启开关时普通视频退桌面保持 `PLAYING` 并持有必要锁；关闭开关后主动进入系统 PiP 仍保持 `PLAYING`；关闭开关并启用 1 分钟自动助眠时，后台在期限内保持 `PLAYING`，到点变为 `NONE`，Pure Live 保活锁消失且 CPU 样本为 0%。证据：`local-artifacts/runtime/android-6458d541/background-off-audio-only.txt`、`background-on-video.txt`、`pip-background-off.txt`、`auto-sleep-one-minute.txt` |
| A2-04 | RUN | 小窗弹幕固定预览/双栏预览实时更新，保存/恢复默认与模板状态一致 | 共享指标已统一预览与实际 Overlay；`cc3ab5b2` 进一步让主模板在嵌入页可恢复，先完整验证再一次提交并覆盖纯文字/全部视觉字段；整行开关、七类滑块、计数器及小窗颜色均具名。精确 `9cc76caa` 七文件 52/52、全库 analyze 通过。绑定产品提交的 K90 候选完成小窗开关/默认恢复回归；真实 Bilibili 直播间中纯文字关→开、顶部留白 0→1 后共同恢复到关/0，进程重启仍保持。覆盖安装保留 firstInstallTime，设备 APK 哈希一致，规范 Hive 精确恢复、应用停止。Windows GUI、其余样式逐项原生输入、实际系统 PiP/小窗完整视觉对照和长时性能继续，详见 `docs/PIP_DANMAKU_PREVIEW_FIDELITY_AUDIT_2026_09_11.md`、`docs/ANDROID_PIP_DANMAKU_ACCESSIBILITY_RESET_AUDIT_2026_09_12.md`、`docs/ANDROID_DANMAKU_TEMPLATE_ACCESSIBILITY_NATIVE_AUDIT_2026_09_12.md` |
| A2-05 | RUN | 应用代理覆盖平台 API、封面/头像和弹幕 WebSocket；全角地址归一化，播放器代理保持独立 | 路由与 WebSocket 回归通过，虎牙协议探针收到 command 22；v3.1.2 Android Release 已用可达 Clash 端点验证 Twitch 原生搜索由直连失败恢复为真实结果，播放代理保持关闭。播放器内核快捷代理入口已复用同一主机归一化与端口边界；最终 APK 的弹幕 WebSocket 与视频播放代理仍待逐平台复验；详见 `docs/NETWORK_PROXY_AUDIT_3_1_0.md`、`docs/ANDROID_RUNTIME_AUDIT_3_1_2.md`、`docs/PLAYER_KERNEL_SETTINGS_LAYOUT_AUDIT_2026_09_11.md` |
| A2-06 | PASS | 颜色选择器真实区分 RGB 与 ARGB；加载颜色可调透明度，主题/小窗颜色不伪装成透明度；输入、预览、确认与取消一致 | Widget 回归覆盖 RGB/ARGB 解析、非法值、即时预览和取消恢复。K90 Pro / cycle 198 使用最终 APK 验证主题入口显示 RGB 与“选择色阶”，加载入口显示真实 alpha 滑块与 ARGB，输入 `0x800080DD` 后取消并重开恢复 `0xFFA0CAFD`。证据：`local-artifacts/diagnostics/android-color-picker-20260905T024906912/summary.json` |
| A2-07 | PASS | “System Default”不再被应用层强制替换；下载字体仍按 ID 使用，失效 ID 安全回落，Windows 保留 Microsoft YaHei | `test/theme_font_resolution_test.dart` 覆盖四条解析路径；根因和 Issue 边界见 `docs/ISSUE_AUDIT_2026_09_05.md` |
| A2-08 | PASS | 平台弹幕过滤与相似过滤分别呈现、即时生效且互不改写；实机操作后恢复用户原值 | K90 Pro / cycle 203 打开真实直播间“屏蔽管理”，四项文案完整；斗鱼平台过滤由开→关→开即时变化，相似过滤保持原关闭状态。脚本：`tool/android_danmaku_filter_settings_smoke.ps1`；证据：`local-artifacts/diagnostics/android-danmaku-filter-settings-20260905T035024190/summary.json` |

### A3 播放与呈现核心矩阵

每个代表房间执行：普通页 → 横屏全屏 → 返回 → 系统 PiP → 恢复 → 应用小窗 → 恢复 → 纯音频 → 视频 → 画质 → 线路 → 返回。检查同一 room/session、首帧、声音、控制 UI、弹幕列表、画面弹幕和返回手势。

| ID | 状态 | 验收内容 |
|---|---|---|
| A3-01 | PASS | K90 Pro / cycle 209 使用提交 `6e1deea1` 的最终 Debug APK，在当前 Bilibili 普通横向房间完成普通页 → 横屏全屏 → 系统返回 → PiP → 恢复；普通页没有竖屏手势入口，横屏全屏为 `2608×1200` 且完整铺满，PiP 保持横向比例，返回前后仍为同一直播间。7 项模式断言及致命日志检查全部通过，证明竖屏控制栏手势补丁在普通流上保持禁用；脚本 `tool/android_presentation_smoke.ps1 -Mode Standard`，证据 `local-artifacts/diagnostics/android-standard-presentation-20260905T042627364/summary.json` |
| A3-02 | PASS | K90 Pro / cycle 208 使用提交 `6e1deea1` 的最终 Debug APK，在当前抖音原生竖屏房间完成普通页 → 下滑竖屏全屏 → 可见控制栏上滑恢复 → 横屏全屏 → 系统返回 → PiP → 恢复全链路；普通页和竖屏沉浸均为 `1200×2608`，横屏为 `2608×1200` 且主体居中、两侧使用环境背景，PiP 保持竖向比例，恢复后仍为同一直播间并继续显示弹幕。9 项运行断言及致命日志检查全部通过；脚本 `tool/android_presentation_smoke.ps1 -Mode Portrait`，证据 `local-artifacts/diagnostics/android-portrait-presentation-20260905T042024096/summary.json`。几何与手势确定性覆盖另见 `test/portrait_stream_support_test.dart`、`test/live_stream_geometry_hint_test.dart`、`test/mobile_video_frame_test.dart`、`test/live_play_normal_layout_test.dart` 与 `test/portrait_fullscreen_interaction_test.dart` |
| A3-03 | RUN | 内嵌黑边/延迟几何/异常元数据：稳定仲裁后再切换，不污染下一房间或重启后的普通流。09-12 有效红灯证明极端截图比例可提前稳定、最大面积异常候选可否决多数正确候选；`01f7bfc6` 改为有限画布比例与严格多数紧凑簇。K90 上旧候选另复现显式横屏后系统返回仍停在 `2608×1200`，`039f8ff3` 以一次性方向所有权按退出沉浸→竖屏→释放顺序修复。精确提交 197/197、全库 analyze 通过；同提交 arm64 Debug 覆盖安装且设备 APK 哈希一致，竖屏完整呈现后紧接普通流，两轮返回/PiP/房间存活及方向恢复全部通过。真实内嵌黑边、长延迟元数据和多次房间/重启继续，见 `docs/VIDEO_GEOMETRY_ARBITRATION_AND_ORIENTATION_RESTORE_AUDIT_2026_09_12.md` |
| A3-04 | RUN | cycle 208 在抖音竖屏源的横屏全屏中发送 Android 系统返回，先恢复 `1200×2608` 普通直播页且竖屏手势与弹幕栏仍存活；竖屏沉浸的控制栏现直接接管上滑恢复，不再依赖控制栏先隐藏。09-12 当前直播间定时器和房间音量均改为本地草稿、等待式单次提交并补齐大字号布局。09-20 `2fac1480` / `45e0bb4f` 修复全屏清晰度、线路和换房大字号面板；`48f79eb7` 将普通播放页收藏/录制入口统一为至少 48×48 px；`5644b45e` 以 35/36/38 px 红灯修复全屏面板及本地弹幕输入动作。`6752fa6d` 再将弹幕样式恢复/关闭从 40 px 修至 48 px，`069209d0` 同步修复 40 px 的音频、投屏及竖屏模式动作；三组最新回归 7/7、9/9，收敛 Analyze 无诊断。当前源码尚待候选原生复验，其他对话框/底部面板的返回优先级及连续第二次返回仍按本行继续 |
| A3-05 | RUN | `tool/android_recording_smoke.ps1 -ExerciseStreamSelection` 现把“仅打开菜单”提升为真实选择、提交后稳定及错误态门禁。K90 Pro / cycle 212～216 已在最终 Debug APK 分别完成虎牙 `蓝光30M→流畅`/`线路1→线路2`、斗鱼 `原画1080P60→超清`、快手 `蓝光 质臻→超清`、Bilibili `线路1→线路2`、抖音 `高清→标清`/`线路1→线路2`，每次切换后继续稳定播放并完成 H.264 + AAC 短录；单一档位/线路按平台实际能力记为不适用。确定性回归另覆盖稳定平台 ID、服务端实际档位回写、相同 URL 拒绝假切换、快速点击 latest-wins、失败原子回滚和新线路数钳制；Android 原生播放器尚不具备 Windows 离屏首帧接管能力，网易 CC、Twitch、SOOP、YY 的实际切换继续逐项采样。09-20 `3ee6b172` 修复真实普通播放页观看人数/清晰度/线路行：320×480 / 3.0 倍英文下旧行横向溢出 641 px，现按可用宽度弹性分配并删除 313 行死代码及其 173 行专用测试；`ef764591` 再以真实文字高度证明固定 55 px 行把 48 px 文字裁到 31 px，现按主题和系统缩放动态增高。相关七文件 31/31、Analyze 无诊断。首个证据 `local-artifacts/diagnostics/android-recording-smoke-20260905T044047480/summary.json`，其余逐轮证据见 Android 审计 |
| A3-06 | RUN | 播放意外暂停、buffering、EOF、签名过期均有界恢复；用户暂停不被自动恢复 | 当前源码把卡住的原生 `play()` 和签名源 resolver 纳入明确超时，超时后继续既有有限线路/内核回退；新增边界 2/2、播放器恢复文件 116/116、最终十文件 245/245 与全库 analyze 通过。精确 `8a4a417c` arm64 Debug 已保留数据覆盖 K90，设备 APK 哈希一致，正常播放/音频/PiP/退出 16/16 通过。09-20 `71fa2064` 修复真实离线播放占位页：320×480 / 3.0 倍英文下旧标题栏把 63 px 文字裁到 31 px且正文向下溢出 353 px，现按真实文字高度增高并在空间不足时滚动；相关四文件 34/34、Analyze 无诊断。真实断流/签名到期注入、长时组合和 Windows 继续，见 `docs/PLAYBACK_CONTINUITY_RECOVERY_AUDIT_2026_09_12.md` |
| A3-07 | RUN | 虎牙普通视频在其他应用前台时连续后台播放 10 分钟，21/21 媒体状态均为 `PLAYING`；PSS/RSS 呈波动平台，CPU 平均 2.24%、最高 5%，结束后媒体会话与 Wake Lock 释放。横竖屏、PiP、纯音频和锁屏组合仍按矩阵继续 |
| A3-08 | RUN | 多画面真全屏显式退出表面已完成聚焦 Widget 回归：安全区 44×44 按钮、系统留白剥离、退出回调和按钮外格子点击隔离均通过。v3.1.3 Windows Release 便携包已验证按钮与 `Escape` 均从 `1536×960` 真全屏恢复到 `1276×718` 普通窗口。源码现让 Windows 每格按真实 viewport/DPR/源尺寸防抖协商输出，布局切换、窗口缩放及带 GlobalKey 的聚焦晋升会交换大/小纹理目标而不重建播放器；见 `docs/MULTIVIEW_RENDER_TARGET_AUDIT_2026_09_11.md`。Issue #875 呈现帧停滞有界单格恢复已通过 80/80 源码回归，真实 Windows 1+3 连续播放待验；见[专项审计](ISSUE_875_WINDOWS_MULTIVIEW_FRAME_STALL_AUDIT_2026_09_23.md)。Android 16 正式 APK 已覆盖安装、冷启动正常，系统返回/方向恢复与双端真实多路清晰度、资源和连续性继续复验 |

### A4 弹幕与本地互动

| ID | 状态 | 验收内容 |
|---|---|---|
| A4-01 | RUN | 房间隔离、时间戳、去重、重连、横竖屏/PiP 返回后继续；关闭房间后旧消息不进入新房。K90 Pro 旧候选完成远端连接、10 条可见消息、PiP/恢复及 14/14 门禁。09-19 `80c87c0e` 对八个平台统一类型化重连/最终关闭事件；#872 已对齐 Bilibili 当前队列认证、operation 24 ACK 与 Cookie uid，七文件 57/57、协议 11/11、DIRECT 实际聊天 1 条；#871/#845 将斗鱼非空聊天默认交付，相关 53/53，Analyze 均无诊断。报告者登录态 Windows、当前候选实时网页/App 数量对照、长时断网重连、Android 报告网络与连续换房继续。见 [Bilibili 审计](ISSUE_872_BILIBILI_LOGGED_IN_DANMAKU_AUDIT_2026_09_19.md)、[斗鱼审计](ISSUE_871_DOUYU_CHAT_COMPLETENESS_AUDIT_2026_09_19.md)和 [#860 审计](ISSUE_860_REFRESH_DANMAKU_AUDIT_2026_09_11.md)。 |
| A4-02 | RUN | 列表上滑一次即冻结，累计新消息，回到底部一次追平；快速滚动、长按屏蔽、关键词管理。既有 K90 高消息量实测已确认第一次上滑冻结、新消息 3→10、一次恢复追尾，以及冻结行长按用户屏蔽、目标移除且其他冻结行保留、设置恢复。当前 `d57e9b87` 统一关键词/用户 trim 与大小写去重，补齐 40 字符边界、完整条目、精确移除语义、整行开关和具名滑块；相邻 88/88、全库 analyze、同提交 arm64 Debug 和 K90 过滤页开关往返通过，设备包哈希一致。当前候选高频快速滚动、完整长按/关键词闭环和 Windows 交互继续，见 `docs/DANMAKU_LIST_AND_FILTER_MANAGEMENT_AUDIT_2026_09_12.md` |
| A4-03 | RUN | 主画面、小窗弹幕速度/FPS/密度/字体/描边/区域一致，120 Hz 下无明显跳步 | `90d5d73b` 修复实际小窗固定 1.0 描边和预览固定阴影偏差，预览/Overlay 共用字体、字重、全局描边开关与 0～4 宽度策略；速度、FPS、密度、区域与轨道路径完成源码核对。五文件 37/37、全库 analyze、同提交 arm64 Debug 内容/16 KB 对齐及 K90 小窗设置双向重启回归通过，设备包哈希一致、Hive 精确恢复。真实系统 PiP 逐帧视觉、120 Hz Perfetto、长时高密度与 Windows 小窗继续，见 `docs/DANMAKU_RENDERING_CONSISTENCY_AUDIT_2026_09_12.md` |
| A4-04 | RUN | K90 Pro / cycle 193 已验证本地互动开关启用、重启持久化、竖屏与横屏全屏输入、2 秒排队、同一共享列表回显和原设置恢复；横屏输入期间控制栏保持挂载，测试器通过被键盘遮挡时仍可达的 IME `send` 动作提交。源码已为全部 22 个支持平台补齐独立本地化身份、通用礼包回落和 ID 归一化，并修复窄屏大字号的样式标题/数值溢出；4 文件 16/16 通过。09-20 `0183368a` 将全屏/底部样式面板的固定 38/46 px 标题行改为按实际主题字号与系统缩放扩展，标题单行省略，2.5～3.0 倍文字布局 **7/7**、Analyze 无诊断。真实平台礼包、等级、特效及跨入口组合矩阵继续执行。证据：`local-artifacts/diagnostics/android-local-interaction-enabled-20260905T015317914/summary.json`、`docs/LOCAL_INTERACTION_PLATFORM_AND_LAYOUT_AUDIT_2026_09_11.md` |
| A4-05 | RUN | 虎牙醒目留言通知不阻塞普通弹幕；WUP 留言板短暂滞后时自动补偿，空板不抛异常，同一快照不重复显示，旧房间未完成请求不会抑制新房间通知。v3.1.7 进一步使用平台 `lMessageId` 区分“可见内容相同但实际是两次付费”的合法事件，并将会话去重缓存限制为 512 项；协议定向回归与到期策略合计 11/11 通过：`local-artifacts/build-records/20260831T214641341Z-quality-focused.json`。09-12 页面层补齐可滚动双语空状态、平台颜色/头像畸形输入回落、窄屏大字号响应式卡片，并与消息模型共用事件身份，十文件 60/60 回归通过，见 [醒目留言呈现审计](SUPER_CHAT_PRESENTATION_AUDIT_2026_09_12.md)；真实付费消息触发依赖外部房间事件，保留为运行观察项 |

### A5 平台适配器

| 平台 | 目录/搜索 | 详情/状态 | 热度/在线语义 | 画质/线路 | 弹幕 | 播放 | 录制 |
|---|---|---|---|---|---|---|---|
| Bilibili | PASS（热门双列） | PASS（当前房间） | PASS（热门热度降序） | RUN（当前匿名样本仅原画；真实 `线路1→线路2` 后稳定，6 线路可选） | PASS（连接；本轮安静样本） | PASS（视频/音频/PiP 恢复） | PASS（切换后短录） |
| 斗鱼 | PASS（热门进房） | PASS（当前房间） | PASS（热度标签） | PASS（4 档；真实 `原画1080P60→超清` 后稳定；当前仅线路1） | PASS（真实消息） | PASS（1080p60/4K 样本） | PASS（切换后短录） |
| 虎牙 | PASS（热门进房） | PASS（当前房间） | RUN（当前卡片） | PASS（6 档清晰度、4 线路；真实 `蓝光30M→流畅`、`线路1→线路2` 后稳定） | PASS（真实消息） | PASS（当前样本） | PASS（切换后短录） |
| 抖音 | PASS（热门进房） | PASS（横/竖样本） | PASS（累计观看标签） | PASS（纯音频项已隔离；当前 3 档/2 线路真实 `高清→标清`、`线路1→线路2` 后稳定） | PASS（连接；活跃样本另有真实消息） | PASS（当前样本） | PASS（切换后短录） |
| 快手 | PASS（热门进房） | PASS（当前房间） | PASS（真实在线人数） | PASS（4 档；真实 `蓝光 质臻→超清` 后稳定；当前仅线路1） | PASS（连接；活跃样本另有真实消息） | PASS（当前样本） | PASS（切换后短录） |
| 网易 CC | PASS（分类迁移回退/热门进房） | PASS（当前房间） | RUN（当前卡片） | PASS（高清/原画、2 线路入口） | N/A（当前适配器无弹幕） | PASS（当前样本） | PASS（当前短录） |
| Twitch（Clash） | PASS（原生搜索/热门） | PASS（当前房间） | PASS（搜索在线人数） | PASS（5 档/线路1入口） | PASS（当前 9 条实时聊天） | PASS（当前样本） | PASS（当前短录） |
| SOOP Live（Clash） | PASS（热门进房） | PASS（当前房间） | RUN（当前卡片） | PASS（3 档/线路1入口） | RUN（连接通过，安静样本无聊天） | PASS（当前样本） | PASS（当前短录） |
| YY | PASS（热门进房） | PASS（当前房间） | RUN（当前卡片） | PASS（2 档/线路1入口） | RUN（当前样本） | PASS（HTTPS HLS） | PASS（当前短录） |
| IPTV | NR | NR | N/A | NR | N/A | NR | NR |

### A6 录制中心

| ID | 状态 | 验收内容 |
|---|---|---|
| A6-01 | RUN | Bilibili 显示 35 秒/2.75 MB/1.1x；虎牙显示 40 秒/19.00 MB/1.2x/4.2 Mbps；斗鱼显示 39 秒/88.25 MB/1.2x/29.4 Mbps；抖音显示 31 秒/26.50 MB/1.0x/6.3 Mbps；快手私有 TS 在 3.551 秒内增长 7,077,888 B，五个平台样本均证明持续写入。开始前目录探测和准备态继续补证 |
| A6-02 | RUN | Bilibili、虎牙、斗鱼、抖音、快手的停止、封装、已停止状态和取消监控通过；K90 Pro / cycle 195 验证 9 状态固定 3×3、状态/任务区反复横滑不换页、任务列表上下硬边界在额外 8 次同向手势后语义签名稳定，页面与底部导航没有漂移。09-11 源码增量将并发任务限制为 1..10、缓存限制为正整数，并统一分片/重试/检测/超时/队列/画质的读取与持久化边界；151/151 定向回归通过。09-14 取消监控确认已补齐完整任务名、文件保留说明、滚动布局、平台标签换行和单次事务，最终两文件 43/43，见 `docs/RECORDER_MONITOR_REMOVAL_LAYOUT_AND_TRANSACTION_AUDIT_2026_09_14.md`。失败重连、待开播、离线恢复、真实并发/缓存回收、原生取消监控及重启保持继续执行。证据：`local-artifacts/diagnostics/android-recording-center-boundary-20260905T020844875/summary.json`、`docs/RECORD_SETTINGS_LAYOUT_AND_BOUNDS_AUDIT_2026_09_11.md` |
| A6-03 | RUN | Bilibili 7,763,631 B / 60.086333 秒；虎牙 27,681,159 B / 56.813667 秒、1440p120；斗鱼修复后 140,249,937 B / 61.416867 秒、2160p；抖音 42,616,963 B / 49.933122 秒；快手 151,779,525 B / 60.225667 秒；五者均含 H.264 与 AAC。其他平台继续执行 |
| A6-04 | RUN | Bilibili、虎牙、斗鱼、抖音、快手样本停止后监控均移除，强制停止后进程消失且活动 Wake Lock 无 Pure Live；签名/线路过期续接、跨分片累计与正常退出资源释放继续执行；09-07源码TLS握手取消合同转绿，56/56本机回归及四状态原生HTTP对照通过；Android该修订未部署，本行保持RUN，见 `docs/RECORDING_TLS_OWNERSHIP_AUDIT_2026_09_07.md` |
| A6-05 | RUN | K90 Pro 强制锁屏/Dozing 60 秒期间 Bilibili 同一 TS 增长 6,291,456 B，唤醒后直播页恢复，最终 11,224,519 B / 112.749333 秒 H.264 + AAC 文件可读；10 分钟厂商省电、断网恢复、低电量和待开播监控继续执行 |

### A7 故障与资源

| ID | 状态 | 验收内容 |
|---|---|---|
| A7-01 | RUN | Wi-Fi 断开/恢复、Clash 开关、DNS/超时、直播端断流、切移动网络；`44b63210` 补齐 Android/curl/POSIX/Windows DNS 诊断与 HTTP 5xx 分类，并让具体传输原因优先于通用输入打开文本；八文件 186/186、全库 analyze 通过。当前候选真实网络切换、应用代理开关、系统恢复、跨网络与上游实际断流继续，见 `docs/NETWORK_FAILURE_RECOVERY_AUDIT_2026_09_13.md` |
| A7-02 | RUN | `723b4452` 已完成权限请求分流、事务式录制目录选择、并发安全写探针、存储耗尽独立诊断及非重试续接的源码/确定性子集；七文件 79/79、全库 analyze 通过。系统权限拒绝/恢复、真实存储耗尽、低电量、温控、长时间锁屏、来电/音频焦点和耳机拔出仍待当前候选原生验证，见 `docs/RECORDER_STORAGE_FAILURE_AUDIT_2026_09_13.md` |
| A7-03 | RUN | 虎牙普通视频后台 10 分钟：PSS 438,712～497,718 KB、拟合约 `+283.9 KB/min`；RSS 643,384～702,020 KB、拟合约 `+299.3 KB/min`；CPU 平均 2.24%、最高 5%。结束后进程与锁释放。首页、PiP、录制和温度对照仍待执行 |
| A7-04 | RUN | K90 Android 17 上同一 Bilibili Debug 房间完成 50/50 次视频→纯音频→返回并关闭应用内悬浮会话；50 次均一次输入生效、进程未重启。每 5 轮采样中原生播放器/Codec 线程、FD、Socket、DMA-BUF、GPU FD 与 BLAST layer 均稳定；52 秒空闲硬释放后 FD 300→262、DMA-BUF 53→25，最终 PSS/RSS 相对预热首页为 +16,684/+17,012 KB，无 FATAL/ANR。Release、多平台、视频恢复、全屏/PiP/后台与长轮次继续，见 `docs/ANDROID_ROOM_RESOURCE_RECOVERY_AUDIT_2026_09_13.md` |

### A8 当前实机事实

- 当前主设备：K90 Pro / `25102RKBEC`（`myron`），Android 17 / API 37，1200×2608，arm64-v8a，支持 60/90/120 Hz。旧 OnePlus PJZ110 / Android 16 记录保留为历史基线，不与新设备结果混写。
- v3.1.8+4121 已在共享轮转 cycle 14 完成可重复直播冒烟并退出 0：冷启动、首页刷新、热门/Bilibili 进房、首帧、弹幕连接、画质/线路、纯音频→视频、系统 PiP→直播页恢复、返回和日志共 14/14 命名断言通过。恢复后离散点为 PSS 277,778 KB、RSS 462,584 KB、75 线程、瞬时 CPU 1.6%，无 FATAL/ANR；当前 `gfxinfo` 只覆盖 9 个 Android View 帧，因此不据此宣称 Flutter 滚动性能通过。完整边界和证据见 `docs/ANDROID_RUNTIME_AUDIT_3_1_8_K90PRO.md`。
- v3.1.8+4121 快手适配已从占位 `EmptyDanmaku` 改为 cursor 串行增量 feed，并在共享轮转 cycle 52 完成当前房间播放、11 条真实评论、在线人数、4 档画质入口、线路1、短录封装与资源清理。成品为 151,779,525 B / 60.225667 秒 H.264 + AAC；证据见 `local-artifacts/diagnostics/android-recording-smoke-20260902T002303173/summary.json`。
- v3.1.2 arm64 Release 已覆盖升级并保留关注数据；10 次冷启动 293～332 ms、平均 306.2 ms，0 FATAL/ANR。分类/搜索标签硬边界、CC 官方 HTML 迁移回退、120 Hz 三档即时切换与冷启动持久化均通过；Twitch 直连失败可由 Pure Live 应用层 Clash 代理恢复，测试后代理设置已原样还原。完整记录见 `docs/ANDROID_RUNTIME_AUDIT_3_1_2.md`。
- v3.0.24 首页已加载并可操作；冷启动后 8 秒样本 `TOTAL PSS 226040 KB`、`TOTAL RSS 399688 KB`，仅作基线，不代表长时通过。
- #818 已在 `6458d541` arm64 Release 实机闭环：普通视频和手动纯音频均遵循后台播放总开关；关闭时退桌面暂停并释放当前 Wake Lock，回前台恢复；开启时普通视频继续；系统 PiP 作为用户主动紧凑播放继续；1 分钟自动助眠在总开关关闭时仍按计时播放，到点停止并释放 Pure Live 保活锁。纯音频/视频自动化也改为先等待 2 秒控件自动隐藏，再确定性唤出并点击，避免测试脚本把已显示的控制层反向隐藏。
- 09-13 当前 `039f8ff3` 产品候选完成正常退出路径 50 次循环：视频→纯音频、返回、关闭应用内悬浮会话均闭环；循环态 FD/Socket/DMA-BUF/Codec/BLAST 保持平台，52 秒空闲释放后 FD 300→262、DMA-BUF 53→25，最终 PSS/RSS 相对预热首页为 +16,684/+17,012 KB。A7-04 已由 NR→RUN，完整数据见 `docs/ANDROID_ROOM_RESOURCE_RECOVERY_AUDIT_2026_09_13.md`。
- 09-13 当前设备已进一步覆盖为 `fec7eae9` 音频输出候选，APK SHA-256 为 `DE7DE185B3E44700CB0D7BE4D2907B17CEB6EFC48BF7BAD53FA5FF95ADFFAE0E`。规范 Hive 覆盖前后逐字节一致；5/5 次真实 Bilibili 视频→纯音频→退出通过，AudioTrack 路径活跃，OpenSL ES/unknown-key/`setVolume -19` 尾窗记录为 0。完整数据见 `docs/ANDROID_AUDIO_OUTPUT_BACKEND_AUDIT_2026_09_13.md`。

## 3. Windows x64 执行账本

### W0 安装、数据与启动

安装器目录选择、D:\Soft\PureLive、便携 ZIP、覆盖升级、旧关注/历史/设置迁移、只读目录回退、卸载残留、单实例、显式新窗口、冷启动与关闭资源回落。

### W1 UI 与输入

主页/二三级页面滚轮、触控板、拖动滚动条、平台与分类页签边界；100%/125%/150%/200% DPI；窗口缩放、最大化、主副屏移动；键盘 Space/Esc/方向/R；鼠标悬停、右键、长按等价操作。

### W2 播放、弹幕与窗口

普通窗口、宽屏、真全屏、侧边任务栏、PiP 置顶开关与位置记忆、应用切换遮挡关系、多窗口配置快照；画质/线路、音频模式、投屏提示、弹幕 FPS 随显示器刷新率；虎牙短签名双实例首帧接管与无黑场恢复。

### W3 录制、性能与长时

十个平台短录与代表平台 10 分钟录制；4K/150% 与 1440p/100%，单窗/双窗、弹幕开/关；记录 GPU 3D、Video Decode、CPU、Working Set/PSS、句柄、线程和退出后回落。至少一条虎牙跨两次签名续接的连续播放/录制证据。

| ID | 状态 | 验收内容 |
|---|---|---|
| W0-01 | RUN | v3.1.0 Windows x64 便携 ZIP 已独立解压到 `.local-build/windows-v3.1.0-runtime-20260831T060618Z/`，`pure_live.exe` 报告 `3.1.0+4113`，数据目录位于便携目录旁的 `AppData`；程序启动、运行和窗口关闭正常。安装器自选目录、旧版本覆盖迁移和卸载残留仍待执行 |
| W0-02 | PASS | v3.1.7 Windows x64 便携 ZIP 在全新隔离目录以独立 instance 启动，FileVersion/ProductVersion 均为 `3.1.7+4120`；数据只写入便携目录内独立 `AppData`，180 秒 37/37 样本均响应，退出后同路径残留进程为 0。见 `docs/WINDOWS_RUNTIME_AUDIT_3_1_7.md` |
| W0-03 | PASS | v3.1.8 正式便携 ZIP 在独立目录与独立 instance 启动，FileVersion/ProductVersion 均为 `3.1.8+4121`；完成真实播放、弹幕和短录后正常退出，匹配的应用与 FFmpeg 进程均为 0。见 `docs/WINDOWS_RUNTIME_AUDIT_3_1_8.md` |
| W0-04 | RUN | #849 的 Release 部署缺口已修复：便携 ZIP 与安装器携带 Flutter 官方要求的三项 app-local VC++ runtime；最终 ZIP 共 1305 项，隔离实例 24.534 秒内 12/12 样本响应，并实证三项 DLL 都从解压目录加载。当前主机通过不替代报告者具体 Win10 build 复验；证据：`local-artifacts/diagnostics/windows-startup-20260904T190044783Z/summary.json`；09-07 2d8e4e0c Release独立候选1306条ZIP再次验证三项VC++运行库从解压目录实际加载，版本14.52.36615.0；非报告者Win10环境复验，见 `docs/WINDOWS_RELEASE_CPU_AUDIT_2026_09_07.md` |
| W1-01 | RUN | 旧 Windows 候选已覆盖热门平台切换、卡片/缩略图加载、纵向滚动、弹幕设置长页及 Esc 返回；辅助页面、分区/搜索另有原生补证。09-14～09-15 源码批次集中修复副屏亮度所有权、WebView2 提示、版本下载、账号退出、缓存/历史清理、字号与 PiP 几何重置、网络清晰度、窗口尺寸捕获、标题栏/项目链接、托盘菜单和标签动作；均有定向回归，但尚未进入同一当前候选。下一次 Windows GUI 批次统一覆盖全部页面、鼠标/键盘/触控板、Esc/快速重复输入、100%/150%/200% DPI、主副屏、浏览器/下载/账号/缓存真实依赖和进程重开。入口证据见 [Windows 辅助页](WINDOWS_AUXILIARY_NATIVE_AUDIT_2026_09_07.md)、[副屏亮度审计](WINDOWS_SECONDARY_MONITOR_BRIGHTNESS_OWNERSHIP_AUDIT_2026_09_14.md)、[窗口几何审计](WINDOWS_WINDOW_GEOMETRY_CAPTURE_OWNERSHIP_AUDIT_2026_09_14.md)与[标题栏审计](WINDOWS_TITLE_BAR_CONTROL_ACCESSIBILITY_AUDIT_2026_09_15.md)。 |
| W1-02 | PASS | v3.1.2 Windows x64 便携 Release 在 `3840×2400 / 200 Hz` 显示器正确显示当前与最高刷新率。省电、均衡、最高三档均即时刷新文案与策略；均衡模式在强制结束隔离实例并用相同 instance id 冷启动后仍恢复，随后成功回到省电默认。应用全过程响应，证据见 `docs/WINDOWS_RUNTIME_AUDIT_3_1_2.md` 与 `local-artifacts/runtime/windows-v3.1.2/refresh-rate-and-fullscreen-20260831.json` |
| W2-01 | RUN | 旧 Windows 候选已在 Bilibili `EdmundDZhang` 房间持续播放画面/声音/双弹幕，并在平台拒绝“原画”时保持实际“超清”，未伪报成功。09-14 的 PiP 系列修订已统一显示器身份、置顶、进出 single-flight、宿主队列、失败回滚、全屏/宽屏呈现快照和窗口几何捕获；最终相关联合回归最高 121/121。当前仍需在同一候选完成普通/宽屏/真全屏/PiP 往返、快速重复操作、关闭竞争、置顶遮挡、100%/150%/200% DPI、主副屏与进程重开。见 [PiP 呈现事务](WINDOWS_PIP_PRESENTATION_TRANSACTION_AUDIT_2026_09_14.md)和[窗口几何所有权](WINDOWS_WINDOW_GEOMETRY_CAPTURE_OWNERSHIP_AUDIT_2026_09_14.md)。 |
| W2-02 | PASS | v3.1.2 便携 Release 实际进入 Bilibili 开播房间，视频与两层弹幕持续更新。普通窗口 `1276×718 @ (325,240)` 进入真全屏后覆盖 `1536×960 @ (0,0)`，Esc 精确恢复；最大化 `1536×912` 进入后同样覆盖 `1536×960`，Esc 恢复最大化工作区。两条往返过程中播放与弹幕不中断，证据见 `docs/WINDOWS_RUNTIME_AUDIT_3_1_2.md` |
| W2-03 | RUN | v3.1.7 GitHub Release 便携实例加载 Bilibili 热门卡片并进入真实开播房间；约 10 秒取得首帧并连接弹幕，列表与画面持续更新。本地测试弹幕约 3.5 秒后同时进入列表和画面；浅色主题设置页、长页滚动、双击真全屏与 Esc 返回均正常，返回后弹幕继续。该房间只返回 `原画 / 线路1`，纯音频、PiP、多画质/多线路和录制继续执行。见 `docs/WINDOWS_RUNTIME_AUDIT_3_1_7.md` |
| W2-04 | RUN | v3.1.7 Windows 实际打开虎牙房间，画质 `蓝光20M→蓝光8M`、线路 `线路1→线路2` 均提交真实结果，切换后视频和弹幕继续。短录累计 198 秒并跨一次短签名续接，两个 MP4 均有 H.264 1080p60 与 AAC 音轨。实测同时暴露录制中心时间被续接尝试覆盖；工作树已用独立 `recordingStartedAt` 修复并通过 13/13 聚焦回归，待下一 Windows 包复验。见 `docs/WINDOWS_RUNTIME_AUDIT_3_1_7.md`；09-07 fadd5bdb Debug 实际完成虎牙20M→8M、线路1→2，取直链4M/六线路选择后取消仍保留播放器8M/线路2，录制持续；本轮未覆盖签名续接，见 `docs/WINDOWS_PLAY_RECORD_AUDIT_2026_09_07.md` |
| W2-05 | RUN | v3.1.8 Windows Bilibili 热门完成 20 张缩略图加载并进入真实在播房间，约 9 秒取得首帧，远端弹幕持续更新；本地弹幕约 3.5 秒后同时进入列表与画面层。当前样本只覆盖单一画质/线路，多画质、多线路、纯音频和 PiP 继续执行。见 `docs/WINDOWS_RUNTIME_AUDIT_3_1_8.md` |
| W3-01 | RUN | Bilibili 短录 89.831 秒，输出 MP4 18,301,583 bytes；`ffprobe` 读到 H.264 1280×720 约 30 fps 与 AAC 音轨，统计从 0.5 MB 单调增长至 19.4 MB。随后播放/弹幕/设置/录制混合场景采样 600.643 秒、61 点、全程 Responding、CPU 平均 3.6807%/P95 4.2325%；Working Set 401.41→463.46 MiB，Private Bytes 762.41→834.80 MiB，仍需更长平台矩阵判断缓存平台期。证据：`local-artifacts/diagnostics/windows-regression/20260831T062626030Z-v3.1.0-bilibili-play-danmaku-pid70096-summary.json` |
| W3-02 | RUN | v3.1.7 干净便携实例空闲采样 180.930 秒、37 点、全程响应；Working Set 196.0078→196.0234 MiB（+0.0024 MiB/min），Private Bytes 530.9766→528.8086 MiB，句柄 1072→1043、线程 153→147，退出后残留进程 0。空闲基线通过；播放、弹幕、录制和多窗口长时对照继续执行。见 `docs/WINDOWS_RUNTIME_AUDIT_3_1_7.md`；09-07 2d8e4e0c Release空关注页可见/最小化/恢复CPU约1.208%/0.0166%/1.330%，每段60秒13/13响应，正常退出；WPR启动0xc5585011未得热栈，原生归因和长时场景继续，见 `docs/WINDOWS_RELEASE_CPU_AUDIT_2026_09_07.md` |
| W3-03 | RUN | v3.1.7 Bilibili 播放、弹幕、设置与全屏交互采样 300.648 秒、61 点，全部响应；CPU 平均 2.2202%/P95 3.5525%，Working Set 399.72→421.52 MiB，句柄 1666→1656、线程 242→238。Private Bytes 816.29→889.95 MiB，存在会回落的短时峰值，仍需退出回落、第二段等长与录制对照后判断缓存平台期。见 `docs/WINDOWS_RUNTIME_AUDIT_3_1_7.md`；09-14 `7715e0fa` 修复 `cover` / `fill` / `fitHeight` 等模式仍分配 `contain` 小纹理、再由 Flutter 放大的源码缺口，26/26 与 Debug 构建通过；4K/150% 和 1440p/100% 的 GPU 3D / Video Decode 同源原生对照继续，见 [fit 尺寸审计](WINDOWS_VIDEO_OUTPUT_FIT_SIZING_AUDIT_2026_09_14.md) |
| W3-04 | RUN | v3.1.7 虎牙录制中心实时大小/时长/速度/码率可见，停止后 FFmpeg 进程为 0；短签名续接产生的两段 MP4 共 83,138,772 bytes、媒体时长 195.550334 秒，均通过 `ffprobe`。工作树修复会话开始时间在续接后漂移的问题；退出后完整资源回落与新包 UI 复验继续执行。见 `docs/WINDOWS_RUNTIME_AUDIT_3_1_7.md`；09-07源码TLS网络侧取消与本机56/56定向回归通过，原生四状态输出SHA保持；当前Windows包未含该修订，真实HTTPS长期性能继续，见 `docs/RECORDING_TLS_OWNERSHIP_AUDIT_2026_09_07.md` |
| W3-05 | RUN | Windows 旧候选已完成 207.610 秒短录与 706 秒墙钟长录；最终 711.806 秒 H.264 720p60+AAC、177121160 B，卡片大小一致，三段 TS 合并后严格全解码、逐包时钟与退出资源检查通过。后续猫耳真实 UI HLS 115.008 秒短录通过；克拉克拉 FLV 尾部缺帧曾保留，底层停止边界修订后真实 HLS/FLV 短录全解码。09-10 实际 HLS 入口和控制器连续两轮启动/停止/自动合并通过，但尚未进入当前 GUI 候选。多平台、续签/断流、当前 Windows GUI 长录与 CPU/内存/句柄回落继续。见 [Windows 长录](WINDOWS_LONG_RECORD_AUDIT_2026_09_07.md)、[FLV 边界](FLV_AVC_STOP_BOUNDARY_AUDIT_2026_09_08.md)和 [HLS 控制器](HLS_CONTROLLER_PREFETCH_AUDIT_2026_09_10.md)。 |

### W4 当前 Windows 运行事实

- v3.1.8+4121 的 GitHub Release 便携包已在隔离数据目录完成真实运行回归：热门/Bilibili 首屏 20 张卡片及缩略图加载正常，热度保持降序；进入直播约 9 秒后画面、弹幕、画质和线路可用；本地弹幕约 3.5 秒后同时进入列表与覆盖层。停止 103 秒录制后得到 101.283 秒、8,584,393 B 的 H.264 540×960 + AAC MP4，退出后 Pure Live/FFmpeg 剩余进程均为 0。证据见 `docs/WINDOWS_RUNTIME_AUDIT_3_1_8.md`。
- 上述运行回归发现“录制中 TS 累计字节”被停止后的 MP4 卡片继续沿用，导致 UI 显示 9.00 MB、磁盘最终文件为 8,584,393 B。当前代码已在每个录制 attempt 完成提交后按最终文件重新核算，同时保留其他已提交 attempt 的累计字节；38/38 定向测试通过。09-07已在fadd5bdb Windows Debug实证最终卡片32.26 MB与33,832,167 B一致，完成此子项原生复验；见 `docs/WINDOWS_PLAY_RECORD_AUDIT_2026_09_07.md`，其余录制矩阵继续。
- 测试对象是 GitHub Release 的 `PureLive-3.1.0-4113-windows-x64-portable.zip` 独立解压副本，不是开发态 `flutter run`。
- v3.1.2 补充测试对象同样来自冻结提交 `4d79e5fa` 的便携 Release，而不是开发态运行；验证了当前 200 Hz 显示器检测、刷新率模式即时生效/持久化，以及普通窗口和最大化两种真全屏往返。
- 实际录制文件：`D:\Soft\pure_live\AppData\RECORDS\PureLiveRecords\bilibili\EdmundDZhang\2026-08-31\14-27-35\20260831_142734_898.mp4`；短录期间时长、大小和速度持续更新，停止后 MP4 音视频轨均可读取。
- “立即启动录制”当前会创建一个录制任务；停止录制后任务保留为“已监控”，而“添加监控”又是独立入口。该行为已记录为待澄清的产品语义，暂不把“立即录制”解释成一次性任务，也不据此扩大改动录制生命周期。
- 10 分钟样本没有无响应、线程持续增长或进程退出；Working Set 增长约 62 MiB，Private Bytes 净增长约 72 MiB，中间峰值 989.32 MiB。单段样本尚不足以区分图片/媒体缓存平台期与泄漏，后续需要空闲基线、退出房间回落和第二段等长样本作对照。

## 4. v3.1.0 发布门禁

当前源码质量证据：`3e4cdbeb` 完整门禁耗时 924.527 秒；Analyze 0 issue、完整 Flutter 回归 667/667、公开接口 42/42、全仓 3884 个文件审计 0 error。记录：`local-artifacts/build-records/20260831T032317652Z-quality-full.json`。

1. 所有 P0/P1 `FAIL` 清零；外部房间暂时不开播时标为 `BLOCKED` 并提供同平台替代房间证据。
2. `flutter analyze` 在修改冻结后只跑一次并为 0；完整测试、接口探针和仓库审计全部通过。
3. Android 正式 APK 在当前提交覆盖安装，签名、版本、ABI、资源和关键原生库核验通过；Android 实机矩阵完成。
4. Windows x64 Release、便携 ZIP 和安装器从同一提交串行生成；启动、安装、播放器、录制与资源回落通过。
5. 其他平台按最终明确发布范围串行构建；构建产物不得借用旧提交冒充当前版本。
6. Release 包含源码标签、完整更新说明、SHA-256、构建元数据、已知限制与回滚信息；发布后再下载资产做一次独立核验。
