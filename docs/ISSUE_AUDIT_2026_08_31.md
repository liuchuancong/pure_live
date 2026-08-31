# 近期 Issue 审计（2026-08-31）

审计基线：维护分支 `v3.1.0+4113` / `b1182034`，目标补丁版本 `v3.1.1+4114`。本轮只读取上游 Issue 和当前维护分支代码进行归因，不合并上游提交。状态只描述已经取得的证据；静态覆盖不会替代 Android / Windows 实机结果。

快照时间为 2026-08-31（Asia/Shanghai）：维护仓库当前没有未关闭 Issue；上游未关闭列表共 10 项，最新项为 #821。下表覆盖全部当前未关闭上游 Issue，并保留与 v3.1.0 直接相关、刚完成处置的 #818/#801 作为闭环记录。

## 结论表

| Issue | 类型与归因 | 当前证据 | 处理状态 |
|---|---|---|---|
| [#821 iOS 最低系统版本](https://github.com/liuchuancong/pure_live/issues/821) | `community-platform`；iOS 14.3 闪退报告，缺少崩溃日志且不属于本分支主要维护设备 | Issue 仅给出 TrollStore 安装与系统版本，没有 IPA 架构、Deployment Target、崩溃堆栈或签名信息；Android/Windows 结果不能外推 | 保留为社区证据；需要 iOS 构建元数据和崩溃堆栈后再定位，不修改 Android/Windows 公共启动链掩盖未知 iOS 问题 |
| [#820 多画面声音、音量与弹幕](https://github.com/liuchuancong/pure_live/issues/820) | `fork-regression`；多画面最初由维护分支提交 `6ec8713d` 引入，控制入口与会话目标被硬编码到 1+3 focus 布局 | 根因已静态复现：`_buildLargeControlBar` 是唯一音量入口且只在 focus 大格渲染；`_syncDanmakuSession` 又要求 `layout == focus`，所以 1×1/1×2/2×2 顶部弹幕开关没有连接/渲染目标。音量只保存在播放器句柄，重建格子后回到 100% | v3.1.1 在所有布局顶部增加当前声音来源格的音量入口；声音来源改成 Rx 单一状态，非 focus 弹幕连接并只渲染到该格；音量复用普通播放器的按房间持久化存储。聚焦 `test/multiview_test.dart` 45/45 通过（含 quad 弹幕焦点切换和房间音量重建恢复）；Windows Debug 已确认 2×2 顶部音量入口实际渲染。完整门禁 Analyze 0、Flutter 669/669、公开接口 42/42、全仓审计 0 error；联网房间交互仍由最终包继续观察 |
| [#818 后台播放关闭后仍播放](https://github.com/liuchuancong/pure_live/issues/818) | Android 策略缺陷；最初由维护分支 `2ca7ff6a` 的纯音频稳定化策略引入，后来进入上游 | PJZ110 / Android 16 / `6458d541` arm64 Release：关闭开关后手动纯音频退桌面由 `PLAYING` 转 `PAUSED` 且当前 Wake Lock 为 0；回前台恢复。开启开关时普通视频后台继续；关闭开关后主动系统 PiP 继续；关闭开关时 1 分钟自动助眠在后台按时停止，媒体状态为 `NONE`，Pure Live 保活锁释放，CPU 样本为 0% | 原复现链及视频、纯音频、自动助眠、系统 PiP 四组合均已实机通过，记入 v3.1.0 发布闭环 |
| [#817 iOS 定时结束后屏幕不立即熄灭](https://github.com/liuchuancong/pure_live/issues/817) | 平台能力与预期边界，不是播放器停止失败 | Issue 没有日志；当前计时结束会停止播放并释放媒体资源。iOS 未向普通第三方应用开放立即锁屏入口，屏幕熄灭由系统自动锁定策略决定 | 验证停止播放、释放屏幕常亮和音频会话；文案明确“停止播放并恢复系统自动锁屏”，不伪造锁屏动作 |
| [#819 小红书直播](https://github.com/liuchuancong/pure_live/issues/819) | 新平台请求，被错误标为 Bug | 当前平台目录、接口探针、画质、弹幕、录制、登录与故障语义均没有小红书合同 | 进入平台研究清单；先形成公开入口、登录依赖、直播源寿命与协议证据，再决定是否进入稳定版，避免只加一个不完整首页入口 |
| [#810 新窗口使用现有配置](https://github.com/liuchuancong/pure_live/issues/810) | Windows 体验缺口，现有隔离是有意设计 | `WindowsMultiInstanceLauncher` 为每个窗口生成独立 instance 目录，避免多个进程并发写同一 Hive；因此新窗口从默认配置启动 | 设计“只读配置快照 + 独立运行时状态”：创建窗口时复制主题、播放器、弹幕、代理和平台设置，不共享可变数据库；收藏、历史和窗口位置按字段决定是否导入。先加迁移/并发测试，再做实机 |
| [#807 局域网数据同步](https://github.com/liuchuancong/pure_live/issues/807) | 功能缺口 | 当前仍有 WebDAV、Firebase 配置同步和 TV 数据同步文案，但没有完整的局域网发现、配对、冲突合并与传输状态入口 | 作为独立同步工程；先统一配置 schema、设备身份、一次性配对和冲突策略，不在播放器稳定批次中恢复半套服务 |
| [#801 Windows 弹幕刷新率 / MSIX 日志目录](https://github.com/liuchuancong/pure_live/issues/801) | 维护分支已有代码修复，待当前 Windows 包复验 | Windows 已显示省电/均衡/最高档位；`DisplayModeService` 提供当前与最高刷新率，主画面和小窗弹幕使用同一自适应 FPS；日志 UI 使用统一日志目录解析 | Windows 阶段在主屏/副屏分别验证刷新率切换、165 Hz 上限、窗口跨屏与日志目录打开；通过后在 Issue 审计中标记实证完成 |
| [#792 虎牙未开播房间显示历史弹幕](https://github.com/liuchuancong/pure_live/issues/792) | 功能请求，不是当前弹幕连接故障 | 虎牙实时弹幕连接只覆盖当前直播会话；项目没有可信的历史弹幕归档来源、时间线合同或本地录制索引 | 不把缓存的其他房间/旧会话弹幕伪装成历史弹幕。后续若引入本地随录存档，必须按平台、房间、场次和时间戳隔离，并显式标注来源 |
| [#779 可选择另一套应用图标](https://github.com/liuchuancong/pure_live/issues/779) | 外观功能请求 | Android 动态图标需要预置 `activity-alias` 并处理启动器缓存；Windows 快捷方式/安装器图标是另一套更新路径，不是替换一张资源即可跨平台生效 | 留作独立外观批次；先准备各尺寸资源、升级兼容和启动器回退测试，不把图标切换混入播放器稳定版 |
| [#767 Windows 4K / 高 DPI GPU 过高](https://github.com/liuchuancong/pure_live/issues/767) | 性能问题，代码层已有多轮缓解，仍需硬件实测 | 当前按可见 viewport / DPR 约束纹理，关闭房间有延迟释放与硬销毁，Windows 虎牙使用双播放器候选但限制为固定两个实例 | 用 Windows Performance Counter 记录 4K/150%、1440p/100%、单窗/双窗、弹幕开关和小窗；同时记录 GPU 3D、Video Decode、CPU、PSS/Working Set 和关闭后回落。未达门限则继续定位合成面或候选播放器生命周期 |
| [#708 侧边任务栏下全屏黑边](https://github.com/liuchuancong/pure_live/issues/708) | 旧 Windows 全屏边界问题 | 当前通过系统 `setFullScreen` 管理全屏，代码不再用主工作区尺寸模拟全屏 | 在侧边任务栏与底部任务栏各执行一次真实全屏/退出；以窗口 bounds、显示器 bounds 和截图为证据 |

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
