# 近期 Issue 审计（2026-08-31）

审计基线：维护分支 `v3.1.0+4113` / `b1182034`，当前目标补丁版本 `v3.1.6+4119`。本轮只读取上游 Issue 和当前维护分支代码进行归因，不合并上游提交。状态只描述已经取得的证据；静态覆盖不会替代 Android / Windows 实机结果。

快照时间为 2026-09-01（Asia/Shanghai）：维护仓库当前没有未关闭 Issue；上游未关闭列表共 13 项，最新项为 #828。#801、#807、#810、#818 已由上游在 2026-08-31 关闭；关闭状态只表示 Issue 生命周期变化，不替代本维护分支的代码与运行验证。下表覆盖全部当前未关闭上游 Issue，并保留这四项与维护分支直接相关的闭环或后续设计记录。

## 结论表

| Issue | 类型与归因 | 当前证据 | 处理状态 |
|---|---|---|---|
| [#828 虎牙醒目留言需手动刷新才显示](https://github.com/liuchuancong/pure_live/issues/828) | `shared-current-bug`；界面已用响应式 `RxList/Obx`，根因在虎牙协议时序而不是列表刷新控件 | URI `2001314` 只是“醒目留言板变化”通知，旧实现立即且只调用一次 WUP `getHeadLineMessageBoard`；通知可能先于服务端列表可见，空列表还会执行 `.last`，并且 `await` WUP 会阻塞后续 WebSocket 解码 | v3.1.6 改为通知后非阻塞调度 `0/600/1800/4000 ms` 有界补偿，每次请求 3 秒超时，按房间代际取消过期任务并对快照去重；空板安全返回。延迟可见、重复快照、跨房间隔离与到期策略聚焦回归 9/9 通过；真实付费消息仍需在外部事件发生时观察，不把协议测试写成实播结论 |
| [#827 直播间画面显示自定义](https://github.com/liuchuancong/pure_live/issues/827) | 外观功能请求；正文提出平台标识显示、图标大小和热度背景透明度，没有最短复现、截图或异常行为 | 当前 RoomCard 与多画面分别有独立的标识/指标组件，需求没有说明目标是首页卡片还是多画面格子；直接加入一组全局参数会错误联动两个不同场景 | 先保留为产品设计项；需要明确作用页面和预期范围后，再抽出场景化视觉配置并补浅色/深色、密集卡片、平板和多画面回归，不作为 v3.1.4 Bug 修复 |
| [#826 平板横屏不能下拉刷新](https://github.com/liuchuancong/pure_live/issues/826) | `shared-current-bug`；上游 v3.0.9 与维护分支均存在宽度误判 | 关注页外层为避免嵌套 `TabBarView` 手势丢失而关闭刷新包装；内层又用 `width > 680` 关闭 `EasyRefresh`。Android 平板横屏超过阈值但仍是移动平台，两层入口因此同时消失 | v3.1.4 改为“移动平台始终保留下拉、桌面宽屏才使用桌面分支”，网格列数仍按宽度响应；宽屏移动/桌面/窄窗判定与真实 pointer drag 回归 2/2 通过，最终 APK 手机实测和平板横屏设备证据按阶段文档继续 |
| [#825 同步入口与设备同步](https://github.com/liuchuancong/pure_live/issues/825) | 主要是入口便利性功能请求，附带“设备同步不成功”但没有服务类型、错误信息、日志、冲突方向或复现步骤 | 当前 WebDAV、Firebase、TV 二维码和本地备份是四条不同合同；恢复会覆盖大量设置，直接把恢复动作放到主页会放大误触和旧快照覆盖风险 | 不把高风险恢复按钮直接放进主页。先在同步工程中统一设备身份、备份时间/来源、上传下载方向、差异预览和冲突确认；具体失败需按 WebDAV/Firebase/TV 路径及日志单独归因 |
| [#824 多画面模式全屏后无法退出](https://github.com/liuchuancong/pure_live/issues/824) | `fork-regression`；多画面由维护分支引入，真全屏分支又明确设计成只渲染网格、没有任何可见 chrome | 当前代码与最短复现完全对应：真全屏仅依赖 Android 系统返回和 Windows `Escape`；格子点击只切换声音来源。根因不是直播源、播放器内核或上游合并冲突 | v3.1.3 增加安全区内 44×44 显式退出按钮，复用原状态机并保留系统返回/Escape；按钮外区域继续命中格子。聚焦 Widget 回归 1/1、完整 Flutter 674/674 和公开接口 42/42 通过；Windows Release 已验证按钮与 Escape 从真全屏恢复普通窗口，Android 已覆盖安装/冷启，方向、系统返回和真实多路会话仍按运行矩阵复验 |
| [#821 iOS 最低系统版本](https://github.com/liuchuancong/pure_live/issues/821) | `community-platform`；iOS 14.3 闪退报告，缺少崩溃日志且不属于本分支主要维护设备 | Issue 仅给出 TrollStore 安装与系统版本，没有 IPA 架构、Deployment Target、崩溃堆栈或签名信息；Android/Windows 结果不能外推 | 保留为社区证据；需要 iOS 构建元数据和崩溃堆栈后再定位，不修改 Android/Windows 公共启动链掩盖未知 iOS 问题 |
| [#820 多画面声音、音量与弹幕](https://github.com/liuchuancong/pure_live/issues/820) | `fork-regression`；多画面最初由维护分支提交 `6ec8713d` 引入，控制入口与会话目标被硬编码到 1+3 focus 布局 | 根因已静态复现：`_buildLargeControlBar` 是唯一音量入口且只在 focus 大格渲染；`_syncDanmakuSession` 又要求 `layout == focus`，所以 1×1/1×2/2×2 顶部弹幕开关没有连接/渲染目标。音量只保存在播放器句柄，重建格子后回到 100% | v3.1.1 在所有布局顶部增加当前声音来源格的音量入口；声音来源改成 Rx 单一状态，非 focus 弹幕连接并只渲染到该格；音量复用普通播放器的按房间持久化存储。聚焦 `test/multiview_test.dart` 45/45 通过（含 quad 弹幕焦点切换和房间音量重建恢复）；完整门禁 Analyze 0、Flutter 669/669、公开接口 42/42、全仓审计 0 error。GitHub Release 的 Windows x64 便携正式包已实际同时播放两路直播，切换声音来源和四种布局；Letme 房间音量 100%→54%，正常退出并重启进程、重新选房后仍恢复 54%。两路流采样全程响应，退出多画面后 Working Set 约 461.84→238.70 MiB、线程 325→154、句柄 2032→1266，关闭窗口后进程消失。在线观察窗内未截获可见聊天消息，平台弹幕实时接收仍保留为运行时观察项 |
| [#818 后台播放关闭后仍播放](https://github.com/liuchuancong/pure_live/issues/818) | Android 策略缺陷；最初由维护分支 `2ca7ff6a` 的纯音频稳定化策略引入，后来进入上游 | PJZ110 / Android 16 / `6458d541` arm64 Release：关闭开关后手动纯音频退桌面由 `PLAYING` 转 `PAUSED` 且当前 Wake Lock 为 0；回前台恢复。开启开关时普通视频后台继续；关闭开关后主动系统 PiP 继续；关闭开关时 1 分钟自动助眠在后台按时停止，媒体状态为 `NONE`，Pure Live 保活锁释放，CPU 样本为 0% | 原复现链及视频、纯音频、自动助眠、系统 PiP 四组合均已实机通过，记入 v3.1.0 发布闭环 |
| [#817 iOS 定时结束后屏幕不立即熄灭](https://github.com/liuchuancong/pure_live/issues/817) | 平台能力与预期边界，不是播放器停止失败 | Issue 没有日志；当前计时结束会停止播放并释放媒体资源。iOS 未向普通第三方应用开放立即锁屏入口，屏幕熄灭由系统自动锁定策略决定 | 验证停止播放、释放屏幕常亮和音频会话；文案明确“停止播放并恢复系统自动锁屏”，不伪造锁屏动作 |
| [#819 小红书直播](https://github.com/liuchuancong/pure_live/issues/819) | 新平台请求，被错误标为 Bug | 当前平台目录、接口探针、画质、弹幕、录制、登录与故障语义均没有小红书合同 | 进入平台研究清单；先形成公开入口、登录依赖、直播源寿命与协议证据，再决定是否进入稳定版，避免只加一个不完整首页入口 |
| [#810 新窗口使用现有配置](https://github.com/liuchuancong/pure_live/issues/810) | 上游已关闭；Windows 体验缺口，现有隔离是有意设计 | `WindowsMultiInstanceLauncher` 为每个窗口生成独立 instance 目录，避免多个进程并发写同一 Hive；因此新窗口从默认配置启动 | 关闭状态不改变技术结论。后续设计“只读配置快照 + 独立运行时状态”：创建窗口时复制主题、播放器、弹幕、代理和平台设置，不共享可变数据库；收藏、历史和窗口位置按字段决定是否导入。先加迁移/并发测试，再做实机 |
| [#807 局域网数据同步](https://github.com/liuchuancong/pure_live/issues/807) | 上游已关闭；功能缺口 | 当前仍有 WebDAV、Firebase 配置同步和 TV 数据同步文案，但没有完整的局域网发现、配对、冲突合并与传输状态入口 | 关闭状态不等于功能已实现。仍作为独立同步工程；先统一配置 schema、设备身份、一次性配对和冲突策略，不在播放器稳定批次中恢复半套服务 |
| [#801 Windows 弹幕刷新率 / MSIX 日志目录](https://github.com/liuchuancong/pure_live/issues/801) | 上游已关闭；维护分支代码与当前 Release 运行验证均完成 | `DisplayModeService` 在 v3.1.2 便携 Release 实测识别 `3840×2400 · 200 Hz（最高 200 Hz）`；省电、均衡、最高三档切换均即时更新说明，均衡模式在同一隔离实例冷重启后仍保留，最后恢复省电默认。主画面和小窗弹幕继续使用同一自适应 FPS 解析 | 当前显示器检测、三档即时生效、持久化和默认回退闭环；证据见 `docs/WINDOWS_RUNTIME_AUDIT_3_1_2.md`。副屏跨屏与 MSIX 日志目录仍属于后续设备/封装矩阵，不外推为已验证 |
| [#792 虎牙未开播房间显示历史弹幕](https://github.com/liuchuancong/pure_live/issues/792) | 功能请求，不是当前弹幕连接故障 | 虎牙实时弹幕连接只覆盖当前直播会话；项目没有可信的历史弹幕归档来源、时间线合同或本地录制索引 | 不把缓存的其他房间/旧会话弹幕伪装成历史弹幕。后续若引入本地随录存档，必须按平台、房间、场次和时间戳隔离，并显式标注来源 |
| [#779 可选择另一套应用图标](https://github.com/liuchuancong/pure_live/issues/779) | 外观功能请求 | Android 动态图标需要预置 `activity-alias` 并处理启动器缓存；Windows 快捷方式/安装器图标是另一套更新路径，不是替换一张资源即可跨平台生效 | 留作独立外观批次；先准备各尺寸资源、升级兼容和启动器回退测试，不把图标切换混入播放器稳定版 |
| [#767 Windows 4K / 高 DPI GPU 过高](https://github.com/liuchuancong/pure_live/issues/767) | 性能问题，代码层已有多轮缓解，仍需硬件实测 | 当前按可见 viewport / DPR 约束纹理，关闭房间有延迟释放与硬销毁，Windows 虎牙使用双播放器候选但限制为固定两个实例 | 用 Windows Performance Counter 记录 4K/150%、1440p/100%、单窗/双窗、弹幕开关和小窗；同时记录 GPU 3D、Video Decode、CPU、PSS/Working Set 和关闭后回落。未达门限则继续定位合成面或候选播放器生命周期 |
| [#708 侧边任务栏下全屏黑边](https://github.com/liuchuancong/pure_live/issues/708) | 已在 v3.1.1 正式包复现并定位，v3.1.2 修复版实测通过 | `window_manager 0.5.2` 在隐藏标题栏初始化后遗留 `is_frameless_=true`；`setFullScreen(true)` 只更新内部布尔值，原生窗口样式和边界被跳过。Windows 进入前重放隐藏标题栏样式以清除该阻断，再执行真实全屏 | 3840×2400、250% 缩放环境下，普通窗口与最大化均覆盖完整逻辑显示器 `1536×960`；Escape 后分别精确恢复原矩形和最大化状态。正式 Windows 包继续重复该矩阵并保留截图与 HWND 证据 |

## #818 根因链

1. 设置页关闭后台播放后会调用 `releaseKeepAlive()`，开关本身已正确持久化。
2. `BackgroundPlaybackPolicy.shouldContinue()` 原先返回“后台开关 **或** 助眠会话 **或** 手动纯音频”。
3. 生命周期协调器在收到 Android `hidden/paused` 时读取该策略；手动纯音频使结果恒为真，因此不会执行生命周期暂停。
4. `LiveAudioHandler` 又使用同一策略重新申请 native keep-alive，于是媒体会话、AudioService、CPU lock 与 Wi-Fi lock 一致保持。
5. 普通视频不含该旁路，所以当前正式包普通模式已经正确暂停；这解释了 Issue 表面上的“有时仍播放”。

修复后只有两个明确意图继续：用户打开后台播放，或用户已经启动带停止计时的自动助眠会话。耳机按钮只改变当前房间的画面/功耗模式，不再隐式取得后台播放权限。

## 发布前复验

- Android：后台开关开/关 × 视频/手动纯音频/自动助眠/系统 PiP；检查媒体状态、AudioService、CPU/Wi-Fi lock、返回前台恢复和计时结束资源释放。
- Windows：#801、#767、#708 均保留真实显示器证据，单元测试结果只作为前置门禁。
- Issue 结论写入 v3.1.0 更新说明，并注明“已复现”“当前代码已覆盖”“等待设备场景”三种不同证据等级。
