# Windows 实机回归报告（2026-08-28）

## 范围

- 基线提交：`1e609cb05714347e124b5d6806579ab426e29394`
- 测试系统：Win11 x64 实机，24 逻辑处理器
- 候选配置：Windows x64 Debug（定向复现）和 Windows x64 Release（录制、稳定性、退出释放）
- 独立数据实例：`fullreg1`、`postfix1`、`lifecycle1`、`lifecycle2`、`releasegate2`、`escfix`
- 本报告不把单个哔哩哔哩直播样本外推成全部平台结论；全平台接口由独立探针和解析器测试覆盖。

## 已发现并修复的根因

### 1. 普通启动提前分配 FFmpeg

桌面端在首帧后固定延迟 2 秒预热 FFmpeg。该路径与“浏览首页保持原生媒体栈冷启动”的策略冲突，增加启动后的内存、线程和磁盘活动。桌面预热已移除，录制开始时再初始化；Android 原有首用兼容预热保持不变。

### 2. IPTV 在普通启动时下载并导入内置资源

基线新实例在没有进入 IPTV 的情况下生成 `IPTV_CACHE/88888.m3u` 和约 4.7 MiB 数据库。根因是 IPTV 设置控制器启动 3 秒后无条件执行热门 M3U 和默认 EPG 导入。现改为：

- 普通启动只在用户已开启自动同步时执行同步检查；
- 热门 M3U 在进入网络/IPTV 功能时按需加载；
- 默认 EPG 只在打开 IPTV 设置且没有来源时加载；
- 同一资源的并发入口由 single-flight 门合并；
- `loadHotResources` 等待真实导入完成，不再提前返回。

### 3. IPTV 同步间隔覆盖睡眠倒计时设置

`autoSyncHoursInterval` 错用了 `autoShutDownTime` 持久化键。两项互相覆盖，既会改变同步频率，也会破坏用户的停止播放时间。现使用独立键 `autoSyncHoursInterval`。

### 4. 设置控制器重复生命周期与冷启动卡死

旧注册顺序先创建 IPTV 的 lazy/fenix 工厂，再尝试 `Get.put(..., permanent: true)`；GetX 会直接返回已有 lazy 注册，永久实例实际没有接管生命周期。初次修复若在 `SettingsService.onInit` 内直接创建 IPTV，又会在冷 Hive 迁移阶段重入依赖容器，实机表现为启动页长时间无响应。

最终顺序为：先完成 `SettingsService` 注册，再由 `InitialServices` 创建唯一的永久 IPTV 控制器。`lifecycle1` 复现了错误顺序的无响应，`lifecycle2` 在相同全新实例条件下正常进入首页。

### 5. 直播页退出未明确关闭全局播放器

普通路由退出只释放页面/弹幕对象，没有明确调用全局 `PlayerManager.close()`。基线退出直播后 10 分钟仍保留约 1.14 GiB Private Bytes、1741 句柄和 237 线程。现将普通退出与小窗交接分开：普通退出先关闭源，再按顺序释放弹幕、视频控制器、子控制器和 Rx 状态；小窗交接继续保留当前会话。

### 6. 软停止长期保留原生解码资源

软停止有利于立即重开直播，但旧实现永久保留播放器。新增 45 秒空闲宽限期：期间重新开播会复用当前播放器；超过宽限且没有播放、小窗或 PiP 会话时执行完整原生释放。立即释放设置仍保持原行为。

### 7. 普通直播间 Escape 路由动作错误

桌面全局键盘处理器最初对所有 Escape 都调用 `toggleFullScreen()`，普通房间会误入全屏，宽屏也会错误进入系统全屏。第一次修复虽然把普通状态返回为未处理，但 Windows Flutter 不会自动把该键转换成 Navigator pop，页面仍然停留。最终按状态解析动作：全屏/宽屏只退出对应展示层，普通房间显式执行当前 Navigator 的 `maybePop`，PiP 保留自己的关闭路径。修复后的 Debug 实例已确认真实直播页按 Escape 返回首页。

## 实机证据

### 基线与旧候选

- 冷启动主窗口：约 2.6 秒。
- Release 空闲 10 分钟：全部样本响应；工作集 `291.90 → 197.75 MiB`，Private `600.50 → 499.37 MiB`。
- 修复启动策略后的 Debug 空闲 10 分钟：工作集 `588.99 → 589.31 MiB`，Private `736.02 → 735.98 MiB`，没有自动生成 IPTV 文件。
- 哔哩哔哩直播：首帧、实时弹幕、线路 1→2、画质请求与服务器实际回执均通过。
- 录制 78.16 秒并正常封装：13,561,682 字节，H.264 1280×720 30fps + AAC。
- 旧候选退出直播后的 10 分钟恢复场景：Private `1160.64 → 1138.11 MiB`，句柄 `1757 → 1741`，线程 `240 → 237`，证明原生资源长期滞留。

### 修复后候选

- `lifecycle2` 新实例：主窗口约 4.0 秒出现，8 秒检查时 `Responding=true`，工作集 582.06 MiB、Private 726.52 MiB、1129 句柄、157 线程。
- 启动实例只有 Hive/迁移文件，没有 IPTV 缓存目录。
- 热门页卡片正常加载；哔哩哔哩样本首帧与实时弹幕正常。
- 直播中资源快照：工作集 772.46 MiB、Private 1018.05 MiB、1659 句柄、245 线程。
- 路由退出后的 120 秒释放趋势：工作集 `766.25 → 696.61 MiB`，Private `979.79 → 888.07 MiB`，句柄 `1589 → 1225`，线程 `235 → 150`；第 40–45 秒发生预期的完整释放，之后 I/O 读保持不变、CPU 平均 0.024%。

### Windows Release 复核

- Release 直播/录制混合场景运行 600.48 秒，共 61 个样本，全部 `Responding=true`，没有进程退出。
- CPU 平均 `2.17%`、P95 `2.69%`；线程 `245 → 242`，句柄趋势近乎持平（`+0.12/分钟`）。Private Bytes 曾因打开录制中心达到 1004.69 MiB，最终 839.63 MiB，整体斜率为 `-1.98 MiB/分钟`；未出现持续单调泄漏。
- 录制中心实时显示时长、大小、倍速和码率；单任务列表在底部滚轮输入后保持夹持，没有空白越界。
- 本轮录制 171.15 秒、17,011,646 字节；`ffprobe` 验证为 H.264 1280×720 30fps + AAC，停止后正常封装为 MP4。
- 退出直播后的 Release 120.47 秒恢复场景：工作集 `407.69 → 306.36 MiB`，Private `791.82 → 666.76 MiB`，句柄 `1638 → 1290`，线程 `232 → 151`；I/O 读完全停止，证明退出路径和 45 秒空闲释放在 Release 生效。
- 证据：
  - `local-artifacts/diagnostics/windows-regression/20260828T042354418Z-release-live-soak-pid41204-summary.json`
  - `local-artifacts/diagnostics/windows-regression/20260828T043454885Z-release-route-exit-recovery-pid41204-summary.json`
  - `.local-build/windows-package-release/AppData/releasegate2/RECORDS/bilibili/水无月菌/2026-08-28/12-24-23/20260828_122423_201.mp4`

## 自动化结果

- `flutter analyze`：0 issue。
- 完整 Flutter 测试：593 项通过。
- 启动、IPTV 策略、single-flight、设置生命周期、播放器音频切换/路由重开/空闲释放及 Escape 状态解析：修复后 39 项定向测试通过。
- 公共接口探针：42/42 通过。
- 仓库静态审计：0 error；空 catch 仅作为既有清单警告。
- `git diff --check`：通过。
- Windows Release 构建通过，耗时 384.63 秒；峰值构建工作集约 1.93 GiB，结束后重型进程数为 0。产物：
  - `local-artifacts/3.0.18-4106/PureLive-3.0.18-4106-windows-x64-portable.zip`
  - `local-artifacts/3.0.18-4106/PureLive-3.0.18-4106-windows-x64-setup.exe`
- 最新 Escape 修复完成 Windows Debug 增量构建和实机确认；本轮没有重新生成 Release 交付包。

## 尚未宣称通过的独立阶段

1. 普通窗口↔全屏、宽屏、小窗和音频模式各 20 次循环，以及高密度弹幕列表手势矩阵。
2. 断网、恢复、失效线路、限速/高延迟和重复进出房间故障注入。
3. Windows 60–120 分钟正式长稳；本轮完成的是 10 分钟 Release 混合负载，加上既有 10 分钟基线和退出恢复证据。
4. Android 安装、启动/后台恢复、竖屏/横屏/PiP、功耗和厂商后台策略；该部分进入单独设备阶段后执行。
5. 本轮实机直播只选取哔哩哔哩公开样本；42 项接口探针和解析器测试用于覆盖其他平台，但不等同于每个平台的长时间真实播放。

## 续测：录制统计异常复现与修复

- 当前源码 Debug 实例 `matrix1` 复现到录制中心时长显示为 `596523:14:08`，而同一任务实际只录制约十余秒、文件约 4.75 MiB。该值对应 FFmpeg/MPEG-TS 源时间戳或 `INT32_MAX` 哨兵被当作会话耗时，并非真实录制时长。
- 修复在 FFmpeg 事件边界完成：直播录制统计若显著超前于会话墙钟，则按墙钟回退；普通可解释的 FFmpeg 进度仍保留。事件继续使用毫秒合同，控制器不再收到源 PTS。
- 旧版本已经持久化的超大计数在任务恢复时清理，任务元数据、文件大小和录制产物保持不变。
- 修复后重新构建 Windows x64 Debug，以新实例 `matrix2` 对同一哔哩哔哩公开直播执行短时录制：录制中心实时显示 `00:00:28`、5.25 MiB、1.4x、2.1 Mbps；停止时为 `00:00:37`、6.75 MiB，状态正常进入“已停止”。
- 停止后的 MP4 为 6,673,875 字节、36.078 秒；`ffprobe` 验证 H.264 1280×720 30fps + AAC，说明 UI 计数、实际媒体时长和封装结果重新处于同一数量级。
- 本次实机同时复核了热门页加载、直播首帧、实时弹幕、录制开始/停止、录制中心固定状态栏和任务删除确认流程。
- 新增 4 项时间归一化/旧数据迁移测试；相关两个测试文件合计 13 项通过，`flutter analyze` 仍为 0 issue。
- Windows Debug 增量构建耗时 173.83 秒，构建记录：`local-artifacts/build-records/20260828T062009674Z-build-windowsx64-debug.json`。
- `matrix2` 退出直播后的 55 秒资源趋势：工作集 `860.0 → 765.7 MiB`，Private `1091.9 → 980.2 MiB`，句柄 `1691 → 1345`，线程 `237 → 156`；原生媒体空闲释放再次生效。Debug CPU 不作为 Release 功耗结论，正式性能仍引用上方 Release 混合负载结果。

## 续测：v3.0.19 Windows 稳定版收口

- 对当前维护分支执行 30 分钟虎牙真实播放与高密度弹幕 Debug 长稳，期间完成 3 轮普通窗口→全屏→Escape 返回循环。181 个采样全部 `Responding=true`，进程没有退出；CPU 平均 `3.58%`、P95 `4.12%`、最大 `5.06%`，线程 `243 → 243`，句柄 `1698 → 1607`。
- 30 分钟样本的 Working Set 为 `949.7 → 1054.9 MiB`，Private Bytes 为 `1204.3 → 1296.4 MiB`。Debug 图片/弹幕缓存预热期间存在约 `2.95 / 1.46 MiB/分钟` 的正斜率，但没有线程或句柄同步增长；退出直播后的 120 秒进一步验证是否可释放，而不是把单一斜率直接判为泄漏。
- 退出直播后 120 秒：CPU `2.54% → 0.65%`，Working Set `992.8 → 820.8 MiB`，Private Bytes `1222.6 → 1020.4 MiB`，句柄 `1538 → 1184`，线程 `233 → 150`。45 秒空闲释放后资源持续回落，证明播放器、纹理与解码线程没有随页面永久保留。
- 实机续测发现普通直播间按 Escape 虽不再误入全屏，但仍停留在直播页。第一个错误状态是 `HardwareKeyboard` 返回 `false` 后，Windows Flutter 没有把未处理 Escape 自动转换为 Navigator pop。
- 修复新增 `EscapePresentationAction.popRoute`：全屏/宽屏仍只退出展示层，PiP 保留自己的关闭路径，普通房间显式执行当前 Navigator 的 `maybePop`。4 项状态解析测试通过；重新构建 `3.0.19+4107` Windows Debug 后，真实直播页按 Escape 已返回首页。
- 最终完整质量门禁首次运行时，哔哩哔哩推荐首项短暂返回空播放描述，41/42 通过；直接复核显示同批其他实时房间正常。接口门禁已改为有界检查最多 5 个推荐房间，同时继续强制验证画质、流和 CDN 三类描述。修复后接口探针恢复为 42/42，避免把推荐/播放服务的短暂最终一致性误判成平台整体失效。
- 证据：
  - `local-artifacts/diagnostics/full-regression-20260828/windows/runtime/20260828T115750181Z-win3019-debug-live-danmaku-30m-pid56240-summary.json`
  - `local-artifacts/diagnostics/full-regression-20260828/windows/runtime/20260828T122853986Z-win3019-debug-post-live-recovery-pid56240-summary.json`
  - `local-artifacts/build-records/20260828T123259810Z-quality-focused.json`
  - `local-artifacts/build-records/20260828T123546159Z-build-windowsx64-debug.json`

## 续测：虎牙长播/最小化恢复黑屏（2026-08-30）

- 当前源码候选而非仅旧安装包稳定复现：虎牙直播最小化约 90 秒后恢复，纹理永久停止出帧，界面提示
  “播放源异常”；原生日志记录 TLS I/O 中断和 EOF。
- 根因是播放器恢复状态机而不是登录限制：同 URL 刷新没有重开死亡传输、同引擎预算不会在健康播放后恢复、
  候选播放器的同步 playing 事件早于管理器订阅导致旧 loading 状态残留，以及立即重试全部落在同一故障窗口。
- 修复包含同 URL 强制重开、候选权威状态同步、健康播放预算恢复，以及 750 ms/2 s 两轮有界延迟重新取源；
  显式暂停、生命周期切换、切房、退房和释放均会取消延迟任务。
- 新增 3 项针对性回归；播放相关组合测试 82/82、完整 Flutter 测试 639/639、`flutter analyze` 0 issue、
  `git diff --check` 通过。
- 修复版 Windows x64 Release 构建成功（Flutter 阶段 496 秒）：
  - `local-artifacts/3.0.19-4107/PureLive-3.0.19-4107-windows-x64-setup.exe`
  - `local-artifacts/3.0.19-4107/PureLive-3.0.19-4107-windows-x64-portable.zip`
  - 构建记录：`local-artifacts/build-records/20260829T222121692Z-build-windowsx64-release.json`
- 修复版真实虎牙房间最小化 90 秒：帧 `142 → 295`；曾停在 249 约 15 秒，恢复状态机随后创建新纹理并继续出帧。
  恢复窗口后画面立即可见，30 秒帧 `387 → 447`，弹幕持续更新。
- 后续前台 10 分钟共 21 个样本，帧 `526 → 1700`，全部 `Responding=true`；线程 `244 → 243`，
  句柄 `1705 → 1719`。换源时 Private Bytes 瞬时升高到约 1.13 GiB，随后回落到约 0.96 GiB，没有永久黑屏。
- 虎牙画质 `蓝光30M → 蓝光20M` 实际重新出帧并更新 UI；当前样本仅返回线路 1，未伪造第二线路。
- 运行证据：
  `local-artifacts/runtime/windows-huya-recovery-fixed-20260829T222802676Z/`。

## 续测：直播状态与多画面下播房间（2026-08-30）

- 根因不是单一平台字段，而是模型长期同时保存 `status` 布尔值和 `liveStatus` 枚举；卡片排序、角标、
  进入房间和多画面曾分别读取不同字段，平台明确返回下播后仍可能被旧布尔值画成开播。
- `LiveRoom.effectiveLiveStatus` 现为展示和播放决策的单一状态来源；旧备份只有布尔值时在反序列化阶段迁移，
  显式 `offline/banned/unknown` 不再被陈旧的 `status=true` 覆盖，持久化时也写回一致状态。
- 启动关注页会同步把上次进程保存的状态标为“核验中”，保留卡片元数据和原分组位置，平台响应全部完成后
  一次性发布新快照；请求失败保持 unknown，不再继续显示昨天的“开播”。恢复前台超过 15 秒同样重新核验。
- 多画面严格区分平台明确下播与请求/解析失败：前者进入 `MultiviewCellStatus.offline` 业务空态，后者进入带
  失败类型的 error；下播格不会请求画质/播放地址，也不会创建原生播放器，并且可以直接点击重新选台。
- Windows Release 实机使用已确认下播的虎牙 `10188`：关注页归入“未开播”；多画面选台显示“未直播”，
  加入格子后显示“该直播间未开播 / 点击此格可重新选台”。日志为 `Create Texture=0`、`frames=0`、
  `errorLikeLines=0`，证明没有把正常下播误报为播放器异常。
- 点击该下播格重新选台并替换为正在直播的虎牙房间后正常出帧；退出多画面时纹理计数为
  `Create Texture=1 / Free Texture=1`，播放器资源成对释放。
- 实机日志：
  - `local-artifacts/runtime/windows-huya-recovery-fixed-20260829T222802676Z/multiview-offline-seed.stdout.log`
  - `local-artifacts/runtime/windows-huya-recovery-fixed-20260829T222802676Z/multiview-offline-seed.stderr.log`

## 续测：虎牙覆盖页面返回后 0×0 黑屏（2026-08-30）

- 复现路径为虎牙直播进入录制中心后返回；日志中旧纹理此前持续出帧，恢复候选请求遇到 HTTP 403/404，
  新 `VideoOutput.Resize` 始终为 `0×0`，但恢复状态机仍释放了旧的非零纹理。
- 根因是把 `Player.open`/`playing` 误当成视频可见，而不是等待 Windows 原生渲染器的首个已呈现帧；覆盖页面
  返回时还存在同尺寸缓存阻止 viewport 重新提交的问题。
- 同引擎无帧恢复现复用首帧门控的暖切换：候选实际出帧后才提交，0×0/无帧候选在截止时间后释放，活动
  纹理保持不动。Windows `Texture` 重挂载的第一次布局会强制重提交尺寸。
- 18 秒录制中心覆盖实测还证实呈现帧看门狗会把主动卸载的 Texture 当成停帧，后台创建第二个虎牙播放器。
  路由现在显式暂停呈现监控，保持传输/音频存活；Texture 重建并提交 viewport 后才恢复监控。
- 新增 0×0 候选保帧与“长时间覆盖不得重开传输”测试并修正首帧提交测试的异步断言；播放、稳定纹理、
  尺寸策略和虎牙取流专项 52/52 通过，`flutter analyze` 0 问题。质量记录：
  `local-artifacts/build-records/20260830T011808450Z-quality-focused.json`。

## 续测：虎牙约两分钟传输结束与无黑场续接（2026-08-30）

- 继续在同一公开房间对协议层做隔离复现：FLV 首次连接约 `129.6 s` 后进入
  `complete=true`；改用 HLS 后约 `131 s` 同样结束，播放列表续取同时出现 HTTP 403。
  两次结束时 URL 的 `wsTime` 仍在有效期内，因此这不是单纯的签名时间到期，也不是只切换
  FLV/HLS 就会消失的播放器选择问题。
- 上游 `v3.0.8` 的虎牙重构改进了房间页解析、WUP `getCdnTokenInfoEx` 获取和两分钟 Token 缓存，
  但当前播放管理器只转发 `onComplete`，没有在健康播放期间预取新源、首帧门控提交或保留旧纹理；
  固定缓存时间也没有根据 `wsTime` 驱动。它改善首次进入和重新请求，但没有覆盖本次 Windows
  长播复现链路。
- 当前维护分支在 Windows 将虎牙活动源视为短传输租约：约 100 秒预取全新房间身份、Token 与
  播放地址，后台候选真实产生第一帧后才替换活动播放器。候选失败只释放候选并在 10 秒后重排，
  旧画面、音频和 Texture 保持不动，避免恢复路径再次退化为破坏式重开。
- 同时去掉 `MediaKitAdapter` 每个视频帧重复发布相同 playing/loading 状态的行为，避免一秒数十次
  重启播放器看门狗、通知 UI 和输出状态日志。
- 修复版 Windows x64 Release 在虎牙 `660000` 连续运行约 8 分钟，完成 4 次首帧门控换源：
  `handoffCommits=4`、`terminalEvents=0`、`frameCallbacks=930`。每次换源后帧继续增长，未出现
  `complete`、`live_source_completed` 或原生播放器错误。
- 换源期间 Private Bytes 短暂升至约 `1.10 GiB`，十秒后回落到约 `0.80 GiB`；线程约
  `242–247`、句柄约 `1687–1717`，没有随换源次数单调增长。
- 证据：
  - `local-artifacts/runtime/windows-huya-recovery-trace-20260830T103348429Z/`
  - `local-artifacts/runtime/windows-huya-hls-continuity-20260830T110622121Z/`
  - `local-artifacts/runtime/windows-huya-proactive-handoff-20260830T035042734Z/summary.json`
  - `local-artifacts/build-records/20260830T034959413Z-build-windowsx64-release.json`

## 续测：状态一致性与多画面业务空态确定性门禁（2026-08-30）

- 状态模型、冷启动核验、下拉刷新合并、下播业务空态、严格解析失败分流、下播格重新选台、
  多画面换流/释放/弹幕会话等 61 项定向测试通过。
- 本轮定向质量记录：
  `local-artifacts/build-records/20260830T040445316Z-quality-focused.json`。
- 这些自动化和前述下播房间实测证明了三个报告问题的直接修复路径；它们仍不代表 Windows
  全功能矩阵已经全部结束。完整 Flutter 回归、全部公开接口、安装器/便携包、设置迁移、搜索、
  录制、历史记录、IPTV、窗口/托盘/多实例及长时资源矩阵继续按独立证据层执行。

## 续测：虎牙官方服务器续租机制与请求身份（2026-08-30）

- 重新抓取虎牙官方房间页、`roomPlayer_7bcba17f.js` 和 `2608271115/vplayer.js`，确认网页登录态和
  匿名态共用相同的播放租约状态机。登录只改变 viewer UID/Cookie，仍需 AntiCode 更新、CDN 重连和
  HLS/FLV 故障恢复，所以登录本身不会消除约两分钟传输结束或 403。
- 官方页面外层 `hyPlayerConfig.vappid=10057` 不是 CDN token 请求的应用号。播放内核普通直播配置为
  `vAppid=66`，最终 `GetCdnTokenExReq` 使用 `iAppId=66 / iLoopTime=0`；本仓库已用确定性测试锁定，
  避免以后把页面参数机械写入 WUP 请求。
- 官方当前 TARS 身份已更新为 `webh5&0.1.0&websocket`，本仓库原 `0.0.0` 已同步修正；主播 UID、
  Windows `pc_exe` HYSDK 和浏览器 HTTP User-Agent 都不再混入该字段。
- 官方 AntiCode 按 `wsTime * 1000 + 300000` 计算失效点，并提前 30 秒调用
  `liveui.getCdnTokenInfoEx`；FLV 重连前替换最新 `wsSecret/wsTime` 并轮换域名，HLS 分片失败/超时则
  `destroy/reset/start`。这进一步证明现网把“签名租约”和“活动传输”分开维护。
- 继续追踪 `launch.wsTimeSync` 后排除了一条错误方向：请求中的客户端时间来自 `performance.now()`，
  返回值只供 SEI 采集/发送时间和端到端延迟统计使用，AntiCode、`wsTime`、`seqid` 与续租调度均未读取。
  因此 `lServerTime` 不是可用于签名的 Unix 墙钟，本仓库没有把它接入播放 URL，也没有增加无关的周期 WUP。
- 本仓库额外保留 WUP `iExpireTime` 给出的更早服务端上界：用最终 URL 的 SHA-256 指纹在内存中关联，
  最多 32 条、注册新源时清理过期项，不持久化 URL、Cookie、UID 或 token。即使本地计时稍晚于服务器
  到期，也继续把该源判为已到续租点，不会删除较短上界后又退回较长 `wsTime`。
- 真实 URL 与官方签名函数进一步证明 `seqid = viewerUid + Date.now()`；非 WAP 的 `u` 可逆回 viewer UID，
  所以 `seqid - viewerUid` 是稳定的开流签发时刻。三轮 FLV/HLS 都在该时刻后约 129～132 秒结束，现将
  100 秒续租点和 125 秒失效边界锚定到这个签发时刻，而不是锚定到元数据查询时刻。重复读取同一个 URL
  不再延长其短会话寿命，缓存旧源也会被明确判为过期。
- 最终聚焦门禁：虎牙 URL/身份/短会话与播放器故障恢复 53/53 通过，`flutter analyze` 0 issue；质量记录：
  `local-artifacts/build-records/20260830T055447060Z-quality-focused.json`。冻结证据摘要：
  `local-artifacts/diagnostics/huya-official-web-20260830/mechanism-summary.json`。

## 续测：当前源码录制租约续接（2026-08-30）

- 录制链路原有两个独立问题：`FFmpegService.start()` 会等原生会话退出，把租约定时器放在
  `await start()` 之后等同于运行期不调度；而重试终端先同步 remux 再重连，会把 10～20 秒封装耗时
  直接变成录制缺口。
- 当前控制器改在原生 `startAck` 安装租约；刷新点前 5 秒预取同画质、同线路新地址，到点把旧输入标记为
  静默 `leaseRefresh` 并立即续接。旧输入 TS 只登记为持久化待处理组，用户停止后统一封装，避免封装阻塞
  直播输入。
- 定向门禁包含租约元数据、同线路/画质续租、过期边界、进程恢复、待处理产物持久化和 FFmpeg 终止分类，
  合计 100/100 通过；最终 `flutter analyze` 0 issue。质量记录：
  `local-artifacts/build-records/20260830T073018790Z-quality-focused.json`。
- 最新源码 Windows x64 Release 编译和便携包成功；构建记录：
  `local-artifacts/build-records/20260830T074217142Z-build-windowsx64-release.json`，便携包：
  `local-artifacts/3.0.19-4107/PureLive-3.0.19-4107-windows-x64-portable.zip`。本轮成功构建使用
  `-SkipInstaller`，所以没有把既有安装器描述为本次新产物。
- 当前源码候选对虎牙公开房间录制 `342 s`，经历三次主动输入切换，录制中心时长/大小持续增长，
  停止后生成 4 个 MP4。`ffprobe` 合计 `342.093 s / 98,877,027 bytes`，全部为
  H.264 1920×1080 + AAC，4/4 非空，残留 TS 为 0。
- 同期 300.38 秒资源采样 61/61 全部响应：CPU 平均 `1.12%`、P95 `1.82%`；线程
  `248 → 247`；Private Bytes `775.3 → 806.8 MiB`，换流瞬态最大 `1047.1 MiB`，没有按输入尝试
  单调爬升；工作集 `369.5 → 426.1 MiB`，最大 `474.5 MiB`。
- 完成交互后的另一段 600.53 秒稳定采样 121/121 全部响应：CPU 平均 `0.58%`、P95 `1.66%`；
  Working Set `325.1 → 333.8 MiB`，Private Bytes `1098.2 → 1022.6 MiB`，线程 `213 → 213`，
  说明活动资源会震荡/回落，不是随时间单向上涨。
- 证据：
  - `local-artifacts/runtime/windows-full-matrix-20260830/20260830T074635793Z-huya-current-source-recorder-lease-rotation-pid46468-summary.json`；
  - `local-artifacts/runtime/windows-full-matrix-20260830/20260830T075147000Z-huya-current-source-recorder-lease-media-summary.json`；
  - `local-artifacts/runtime/windows-full-matrix-20260830/20260830T071209968Z-windows-current-source-steady-live-after-interactions-pid9012-summary.json`。

## 续测：虎牙 AntiCode 完整模板与离线页返回（2026-08-30）

- 再次以 `Cache-Control: no-cache` 获取官方房间页和播放器脚本。房间仍声明
  `h5playerVersion=2608271115`；`roomPlayer_7bcba17f.js` 的 SHA-256 仍为
  `088B79C83A9C7A5172397A5ACC67CA34352DA2AB2497F57813CA9E601D539312`，
  `vplayer.js` 仍为
  `F80D395A453DE6FE5233BF46C18F5AD67CAF4858FF014BF2B9F14D057B35D213`。
  本轮排除“官方脚本在测试过程中又切换版本”这一变量。
- 进一步核对官方 AntiCode 算法发现维护分支仍有一处兼容性偏差：官方把服务端下发的完整 `fm`
  当作模板，在原位置依次替换 `$0/$1/$2/$3`；旧实现却先按下划线切割并重建固定布局。旧方式只对
  当前恰好使用该布局的 token 有效，服务端增加字段、更换分隔符或调整占位符位置后会生成结构正确但
  签名错误的 URL。现已改为完整模板替换，并在最终 CDN 查询中移除只供本地签名使用的 `fm`。
- `fm` 缺少任意占位符或 `wsTime` 非法时现在立即判为模板错误，交给既有 WUP 新 token/线路/协议
  恢复链路，不再把错误签名送入原生播放器后等待 403/黑屏超时。新增非下划线、占位符重排和畸形模板
  测试，锁定后续服务端变更的兼容边界。
- FLV/HLS 现分别从自己的 AntiCode 字段起步；一条 CDN 的模板或 WUP 刷新失败只淘汰这一条，不再让
  `Future.wait` 的单个异常清空同一快照中的全部健康线路，也不再用 HLS token 拼接 FLV 地址。
- 匿名登录短暂失败时使用的进程内临时 UID 不再永久缓存；下一次独立取源会重新请求官方匿名身份，避免
  一次网络抖动把服务器未确认的 UID 固化为“本次启动持续 403”，而已成功取得的官方身份仍复用。
- 故障测试同时发现回退 UID 曾调用 `Random.nextInt(100000000000)`，超过 Dart 的 `2^32` 上限；这会在
  匿名接口恰好失败时再抛 `RangeError`。生成器现由两个合法随机区间组合，网络故障路径本身不再崩溃。
- 无账号 Cookie 的在线合同探针取得匿名 UID 后，用完整模板生成不含 `fm` 的 AL FLV 地址；官方 CDN
  返回 HTTP 200 / `video/x-flv`，前 4096 字节以 `FLV` 开头。脱敏证据：
  `local-artifacts/diagnostics/huya-official-web-20260830-refresh/official-media-probe-summary.json`。
- 离线房间在 `VideoController` 创建前只渲染业务空态，过去键盘快捷键包装器也因此没有挂载，导致
  Windows 的 Escape 在离线页失效。页面级 Escape 现始终存在；控制器为空时忽略可能残留的全屏状态并
  直接返回上一页，音量/录制快捷键仍只在播放器就绪后注册。
- 最终聚焦门禁：9 个相关测试文件、136/136 通过，`flutter analyze` 0 issue；质量记录：
  `local-artifacts/build-records/20260830T094023270Z-quality-focused.json`。此前当前源码完整门禁仍为
  652/652，接口探针 42/42，记录：
  `local-artifacts/build-records/20260830T080845612Z-quality-full.json`。
- 线路隔离、匿名身份重试及大范围随机数故障测试使虎牙取流文件达到 28/28 通过；首次故障
  注入准确触发旧生成器的 `RangeError`，修复后同一用例通过，并确认第二次请求取得官方身份、第三次复用。
- 录制完成后的后台空闲继续采样 900.642 秒，91/91 全部响应，线程 `246 → 246`、句柄
  `1816 → 1761`、Private Bytes `862.2 → 845.3 MiB`；Working Set 在缓存回收抖动中
  `448.9 → 460.3 MiB`，没有伴随线程、句柄或 Private Bytes 同向增长。证据：
  `local-artifacts/runtime/windows-full-matrix-20260830/20260830T081049250Z-windows-current-source-post-recording-background-idle-pid46468-summary.json`。

## 续测：虎牙当前线路矩阵与旧式短会话兜底（2026-08-30）

- 当前 `profileRoom` 返回 5 条可选 CDN、FLV/HLS 共 10 个入口；使用官方匿名会话逐条重新签名并读取
  媒体头，10/10 有效。FLV 均为 HTTP 200 + `FLV`，HLS 同时存在健康的 HTTP 200 与 Range HTTP 206，
  均以 `#EXTM3U` 开头。脱敏证据：
  `local-artifacts/diagnostics/huya-official-web-20260830-refresh/current-profile-all-lines-probe.json`。
- 这些入口实际由多种边缘服务器实现，首包延迟存在差异；官方 `multiLine` 才是本次房间快照的可选集合。
  基础列表中优先级为 `-1`、未进入 `multiLine` 的描述不会被本仓库机械加入播放列表。
- 修复 `multiLine.cdnType` 被误读成不存在的 `sCdnType`，线路诊断恢复真实 AL/TX/HS 等身份；同时
  `HuyaLineModel.toString()` 不再输出完整 URL、AntiCode 或流名。
- 为没有 `seqid` 的旧式静态 token 增加进程内 URL 指纹签发时刻：与当前模板一致在 100 秒续接、
  125 秒失效，不再因为只看到较长 `wsTime` 而等服务器 EOF 后再黑屏恢复。该内存索引最多 64 条，
  过期值仍保持权威直到淘汰，避免死 URL 被重新判成健康。
- 本轮虎牙取流测试 30/30 通过，`flutter analyze` 0 issue；质量记录：
  `local-artifacts/build-records/20260830T101435076Z-quality-focused.json`。

## 虎牙 CDN 会话窗口二次取证与提前续接修正（2026-08-30）

- 当前 Debug 长播前四次候选续接均在旧源出帧期间完成；第 5 次却从
  `18:43:49.001` 开始，到 `18:44:35.977` 候选播放、`18:44:39.735` 提交。旧源已在
  `18:44:20.012` 完成，说明约 51 秒的房间解析、原生实例、D3D 与首帧事务超过了原先预留的约 30 秒，
  这是仍可见黑场的客户端竞态，不是“已经登录即可消失”的账号问题。
- 同一个匿名签名 FLV URL 的隔离实验进一步证明边缘连接不是固定时长：立即单连接持续
  `100.780 s`；同 URL 在签发后 90 秒才连接时仍返回 HTTP 200，却只持续 `20.476 s`。另一轮 0/30 秒
  并发复用分别持续 `80.596 s` 与 `40.469 s`。响应均为 Tengine、`Connection: close`，未出现新的
  HTTP 鉴权错误。
- 因此当前实现把 `wsTime`、WUP `iExpireTime`、由 `seqid` 推导的签发时间和活动 socket 生命周期视为
  四个不同边界。Windows 虎牙实际安装一个新传输后，按“服务端声明点与本地 40 秒点取更早者”启动
  后台候选；候选首帧前不暂停、不销毁旧播放器。旧 session 在交接期间排队的 complete/buffering 事件
  由 session id 栅栏丢弃，不再误伤已提交的新播放器。
- 当前构建的手动质量切换（蓝光10M→蓝光4M）、线路切换（AL→TX）和 Escape 返回均在持续播放中完成。
- 重建 Debug 后公开房间 `660000` 完成 8/8 次 40 秒提前续接，0 次候选失败、0 次原生/终止错误。
  第一个冷候选耗时 `8841 ms`；固定两个 MediaKit/D3D 实例进入交替后，后续耗时为
  `1082/1775/1020/604/602/514/1008 ms`。活动期只出现两个 VideoOutput（各自首次从 0×0 切到
  1920×1080 时重建一次 Texture），后续续接没有再创建或销毁 VideoOutput，第 8 次提交后仍持续出帧。
- 241.674 秒资源采样 49/49 全响应，CPU 平均 `2.139%`、P95 `2.996%`，线程 `322 → 325`、句柄
  `2001 → 2019`；Working Set `850.5 → 926.4 MiB`、Private Bytes `1173.0 → 1212.6 MiB`，峰值
  `1520.5 MiB`。短窗口缓存仍有正斜率，因此这里只证明原生实例/Texture 不再按续接次数增长，不把它
  外推为无限时内存结论。
- 官方当前 AntiCode 代码明确以 `wsTime+300 s` 为失效点、提前 30 秒调用
  `liveui.getCdnTokenInfoEx`；`VideoLoader` 又独立处理 onclose、连接/首包超时、403/404、域名轮换和
  `wsSecret/wsTime` 替换。账号登录只改变 viewer UID/Cookie，不会取消这两套续租/重连状态机。
- 脱敏服务器证据：
  `local-artifacts/diagnostics/huya-official-web-20260830-refresh/same-signed-url-concurrent-lifetime-probe.json`、
  `local-artifacts/diagnostics/huya-official-web-20260830-refresh/same-signed-url-sequential-lifetime-probe.json`；
  当前运行日志：`local-artifacts/runtime/windows-huya-ping-pong-20260830/stdout.log`；资源摘要：
  `local-artifacts/runtime/windows-huya-ping-pong-20260830/20260830T134305205Z-huya-ping-pong-warm-standby-pid64796-summary.json`；
  Debug 构建记录：`local-artifacts/build-records/20260830T134003653Z-build-windowsx64-debug.json`。
