# PureLive 参考同步 · 续跑台账

> 这是定时自动任务的唯一进度台账。每次运行**只推进一个未完成子项**，完成后勾选并在「进度记录」追加一行；没有验证结果不算完成。

## 固定上下文

- 应用（工作区）：`F:\projects\pure_live\apps\pure_live`，Flutter + Riverpod 3 + desen_ui 0.3.2（不要引入 Material/Cupertino 页面组件，现有 `AppBar`/`Scaffold` 例外）。
- 参考（**只读**）：`C:\Users\m1779\Downloads\pure_live-master\pure_live-master`，v5 monorepo（`apps/pure_live` + `packages/live_*`）。只参考布局、结构与交互逻辑，不照搬 `live_ui` 实现。
- 播放栈：`F:\media_core\packages`，已依赖 `media_core`、`media_core_live`、`media_core_media_kit`、`media_core_danmaku`、`media_core_recording_ffmpeg`、`media_core_presentation`、`media_core_audio`、`media_core_fullscreen`、`media_core_pip`、`media_core_cast_dlna`、`media_core_mediasession`、`media_core_notify`。播放器只能走这些包，不得换替代实现。
- 语言：slang，分组 JSON 在 `lib/l10n/messages/<group>/`。改 JSON 后运行 `dart run slang`；**不要**运行 `build_runner`（会删 `translations.g.dart`；若跑过必须补 `dart run slang`）。
- 验证：`cd apps/pure_live && dart analyze lib` 必须 0 issues，`flutter build bundle` 必须 exit 0。不写测试。
- 不新增依赖或第三方组件；确需新增时写入「阻塞与待决策」并跳过该项。
- 不改参考仓库；不执行 `git reset/checkout/clean`；不提交，除非用户在当次对话中明确要求。保留当前未提交批次。
- 若同时有其他会话在改文件：先看 `git status` 与文件修改时间，只动本项自己的文件，不覆盖别人的进行中改动。

## 当前已落地（无需重做）

> **2026-10-25 全量复核修正**：本节的「已落地」是页面/基础链路层面，不等于参考功能全部对齐。一次逐面核对确认仍有大量 PARTIAL/MISSING（直播间详情与聊天 tabs、IPTV 指南/回看、设备同步、标签/提醒、版本更新、WebDAV 多服务器、搜索筛选/链接、录制设置等）。完整矩阵、证据和优先级见 [parity-audit-2026-10-25.md](parity-audit-2026-10-25.md)。后续待办以该报告的 P0/P1 和第 A11 节为准。

- 外壳：模块注册表、分组菜单（搜索直播/观看记录｜链接解析/多画面｜关注/热门/分区｜录制中心）、多画面入口开关、移动抽屉同构。
- 关注页：已开播/录播/未开播/全部计数、平台计数、观众徽标与主播·状态·人数、刷新/分页/每页/跳转、混合列表平台角标。
- 设置：按模块注册表各自成组——直播（平台与授权/刷新、播放与弹幕、直播数据）、IPTV（节目单更新）、Bilibili 视频（Bilibili 账号、默认清晰度）、音乐（暂无专属项）；主题外观/背景/导航/通用/网络/备份/缓存/关于为共享分区。侧栏、手机菜单、搜索与面板眉题都只读当前模块的组，不再把所有分区强塞给每个模块。桌面侧栏在设置页显示组标题（界面/直播来源/播放/通用/数据/关于），项目名精简，设置页隐藏全局搜索，只保留设置自己的搜索。
- 房间/播放器：media_core 呈现驱动链（系统全屏/窗口全屏/PiP）、房间页 AppBar 头（头像/主播/平台·分区/关注/菜单）、聊天列上方信息条（状态/标题/观众/开播时间/定时关闭）、宽窗 16:9 画面居中 + 右侧 300–400px 聊天列、窄窗画面+信息条+聊天堆叠；播放器控制条（画质/线路/弹幕/投屏/全屏/PiP）、自动隐藏、离开页面释放播放与弹幕、睡眠定时、聊天倒序、键盘快捷键、状态浮层 l10n、恢复后保持静音/音量。
- 多画面：真实播放（每格一个 `LivePlaybackController` + `MediaPlayerView`），1×1/1×2/2×2/1+3，选中格发声、1+3 的大格跟随选中格，其余静音，关注+历史选台，离开页面释放；旧的 6/9 格已去掉。
- IPTV：频道与来源改为资源面板 + 表格；频道可搜索/按分组与收藏筛选、全部同步、直接打开播放页；来源表合并播放列表与节目单，带格式/频道数/更新时间/自动更新开关/同步/删除；节目单自动更新按 6h/12h/24h/3天/7天在后台执行。回看与换源菜单仍缺。
- 录制：房间控制条有录制/停止，FFmpeg 后台录制当前线路并写 `RecordingTask`；录制中心读同一任务库并每 10 秒更新字节；设置扩项仍缺。
- 分区：二级品类页签、分区关注爱心；历史：点击重进房间、刷新在线状态；搜索：隐藏已关闭平台；工具箱：获取直链；收藏：平台角标。

## 任务队列（自上而下，一项一轮）

### A1 多画面真实播放（大项，拆成子项逐轮做）

参考：`apps/pure_live/lib/features/multiview/*`；我方：`lib/features/multiview/*`。

- [x] A1a 会话骨架：每格一个 `LivePlaybackController` + `MediaPlayerView`；选中格发声、其余静音，离开页面释放全部。已完成（2026-10-25）。
- [x] A1b 布局：1×1 / 1×2 / 2×2 已实现；旧的 6/9 格去掉，最多 4 路。
- [x] A1b2 1+3 主格+侧列布局（参考 `multiview/widgets/toolbar.dart` 的 focus 布局）。已完成（2026-10-25）：第四段「1+3」；大格跟随选中格（点小格即放大并取得声音），小格在右侧列或下方行（按哪种让大格更大自动选），小格用紧凑标题浮层，大格保留完整标题栏；布局存档改为枚举名并兼容旧整数。运行期未做真机目视。
- [x] A1c 音频：同一时刻只有选中格有声；`select` 切换。
- [ ] A1c2 每格画质/线路/音量/暂停全部，以及工具栏的静音全部/暂停全部入口。
- [x] A1d 选台：关注 + 最近观看合并选台，已在墙上的房间拒绝重复。
- [ ] A1d2 搜索选台与拖拽换位；布局保存已有（`multiviewProvider`）。

### A2 录制引擎接入（大项）

参考：`features/live_play/buttons/record_button.dart`、`record/*`、`features/recorder/*`；我方：`lib/features/recorder/*`、`lib/features/room/player_surface.dart`。

- [x] A2a 引擎：`recorder_engine.dart` 的 `FfmpegRecordingBackend` + `RecordingManager`，从当前 `LivePlayLine`（含 headers/刷新）开始，按 10 秒写进度、按 MB 上限停止，写 `RecordingTask`。已完成并通过 analyze/build（运行期需真机/真流验证）。
- [x] A2b 房间入口：控制条录制/停止按钮，录制中显示 stop 图标；失败 toast。
- [x] A2c 录制中心联动：任务库是同一存储，录制页随 watch 流刷新；开始/停止/失败状态由引擎写回。
- [ ] A2d 录制设置扩充：分段时长、重连、直播检测、最大任务数；当前只消费目录/命名/MB 上限。
- [ ] A2e 停止确认与失败原因展示、取消/删除先停引擎的边界检查。

### A3 IPTV 频道播放

参考：`features/iptv/*`、`packages/live_iptv`；我方：`lib/features/iptv/*`。

- [x] A3a IPTV 播放页：root 路由，`IptvChannel.entry` 的 url/headers/alternatives 建 `LivePlaybackController`，`MediaPlayerView` + 全屏/PiP；返回释放。已完成（2026-10-25）。
- [x] A3b 频道卡：点击打开播放；播放页显示台号/频道名/当前节目。
- [ ] A3b2 备选线路菜单（当前已把 alternatives 作为扫描源，但没有手动切换入口）。
- [x] A3d 资源面板：页头（标题/统计/导入/视图切换）、频道表（分组/正在播出+进度/收藏/播放，范围筛选、频道搜索、全部同步）、来源表（合并播放列表与节目单、类型/频道数/更新时间/自动更新/同步/删除，筛选、搜索、全部同步）。已完成（2026-10-25）；按参考图的卡片+表格形态，运行期未目视。
- [x] A3e 节目单自动更新：间隔 6h/12h/24h/3天/7天持久化；应用级定时器每分钟检查，到期同步开启 autoUpdate 的网络节目单，失败按间隔重试、与手动同步互斥；来源页提供逐项开关和全部开关。已完成（2026-10-25）。
- [x] A3f 来源排序：参考「编辑顺序」卡片；编辑态支持拖动 + 上移/置顶/下移/置底、未保存草稿提示、取消/保存；保存写入 `iptv.sources.order`，只影响来源表的显示顺序，取消不落盘。已完成（2026-10-25）。
- [ ] A3c EPG/回看：回看 URL 按 `catchupSource` 模板生成；无模板时隐藏。

### A4 搜索页缺口

参考：`features/search/*`；我方：`lib/features/search/*`、`features/popular/popular_page.dart` 的内联搜索。

- [ ] A4a 结果排序（综合/人气/时间）、显示离线、结果去重；用现有 `LiveRoom.audience`/`broadcast`。
- [ ] A4b 链接识别：输入以 http(s) 开头时显示「打开链接」并按 `LiveLinkResolver` 解析；失败时仍保留普通搜索。
- [ ] A4c 网页搜索：`webview_flutter` + `LiveWebSearchProvider`（已有能力）打开网页搜索页；无能力平台隐藏入口。
- [ ] A4d 失败与覆盖：失败横幅（重试/范围/代理/网页搜索）、覆盖行、内联搜索 Esc 关闭。

### A5 播放器剩余（小项逐轮）

参考：`features/live_play/player/*`、`buttons/*`。

- [ ] A5a 画质/线路切换忙状态与失败回退（切换中 spinner；失败保留原画质并提示）。
- [ ] A5b 离开应用自动 PiP（设置开关，`AppLifecycleState.inactive` + `PipDriver`），回到前台退出。
- [ ] A5c 音频模式（`LivePlaybackController.setAudioOnly`）+ 控制条按钮。
- [ ] A5d 竖屏三档聊天面板（窄屏全屏竖屏）；可先做三档高度 + 拖拽手柄。
- [ ] A5e 聊天未读按钮：上滑后新消息计数，点击回底。
- [ ] A5f 手势：左半屏亮度（无 media_core API，需现有依赖；没有就跳过并记录）、右半屏音量、双击全屏、滚轮音量。

### A6 热门页缺口

- [ ] A6a 卡片：直播/回放/受限标记；受限/轮播房间隐藏并显示「已隐藏 N 个」。
- [ ] A6b 平台选择器：logo 网格（有图标才显示，不伪造）、固定高度、当前勾选；「平台显示」跳设置。
- [ ] A6c 分页：桌面每页数量/跳转/方向键；手机「加载更多」页脚。

### A7 关注与历史补齐

- [ ] A7a 关注标签体系：新增 tag store（`RoomLocal.tagIds` 已有）；标签 chip 行 + 设置标签弹窗 + 按标签过滤；无 store 前不伪造。
- [ ] A7b 未开播紧凑行（录播/未开播 tab）；平台徽标与状态行样式对齐参考。
- [ ] A7c 历史卡片：平台徽标、观看时间、右键删除；手机不显示桌面分页。

### A8 设置与弹幕补齐

- [ ] A8a 设置搜索上升到「行」级：为每个分区建可搜索行清单（label/description/keywords），桌面高亮结果；不搬 2042 行 catalog，只登记已存在的行。
- [ ] A8b 弹幕过滤：表情/长度/平台过滤/相似度阈值（`MessageFilter` 已支持，先确认字段后接 UI）；房间弹幕面板。
- [ ] A8c 日志页：`live_log` 包已存在，做一个设置内日志查看页（如果能力足够）。

### A9 账号 / 备份 / TV（需先定范围）

- [ ] A9a 账号：按平台 Cookie 编辑器、登录验证/退出状态；B 站网页登录无 API 则记录阻塞。
- [ ] A9b 备份：恢复预览 diff、多 WebDAV 服务器与目录浏览；TV/设备同步无 API 则记录阻塞。
- [x] A9c TV：不再维护独立 TV 外壳；TV 复用桌面外壳，侧栏当前项取得初始焦点、卡片网格按索引 D-pad 导航并滚动目标入视、当前焦点自动滚入最近滚动区、房间页 TV 使用常驻控制条并以播放键起步。已完成（2026-10-25），独立 TV 文件已删除。
- 这三项规模大，每轮只做一个页面/一条链路；遇到产品决策写入「阻塞与待决策」。

### A10 VOD / 音乐（参考 v5 没有对应页面）

- [x] A10a1 VOD 浏览：Bilibili 热门（`no_more` 收尾）、分区排行（单页）、分区列表（`newlist` 分页）、搜索（排序/时长，访客指纹 cookie 规避 412）；模型与客户端见 `packages/live_vod`。已完成（2026-10-25）。
- [x] A10a2 VOD 详情/播放：`view` 详情、分P、`playurl` 渐进 mp4（画面+声音）、DASH 回退明确提示无声、media_core 播放器（画质/分P/倍速/音量/全屏/PiP）、按 bvid+cid 记录续播进度。已完成（2026-10-25）；真流播放未做运行期目视。
- [ ] A10a3 VOD 历史/收藏：站点页、收藏与观看历史仍是直播模型；播放进度已按 `vod.progress.<bvid>` 存本地，但没有列表 UI。
- [ ] A10b 音乐：先确认曲库来源；没有来源时只做播放器/队列/歌词的空页面并记录决策，不伪造数据。

### A11 全量复核缺口（2026-10-25，按功能/UI 核对，不以文件为准）

详见 [parity-audit-2026-10-25.md](parity-audit-2026-10-25.md)。本轮已修：Android release 网络/PiP/媒体通知权限、房间详情失败永转圈与重试死按钮、离线/轮播无动作、线路循环、设置工具顺序未消费、搜索主播/分区死卡片。

- [~] B1 直播间核心面：B1a 详情/聊天 tabs/菜单/消息动作 + B1b 手势/常亮 + B1c 自动比例/自动 PiP + B1d 手动画面方向与记忆已完成（2026-10-25）；余竖屏全屏/三档面板、亮度/换台手势、后台音频、应用内悬浮小窗、切换房间、本地互动。
- [~] B2 IPTV：B2a 节目单/回看/回直播 + B2b 线路菜单/上下换台/投屏/快捷键已完成（2026-10-25）；余 IPTV 平台化（关注/历史/搜索/多画面）与录制。
- [ ] B3 设备同步 + TV 同步：LAN 发现/配对/部分勾选/预览；现在完全没有。
- [x] B4a 搜索：本地排序（智能/平台/观众/关注数）、显示离线、URL 链接识别与打开、网页搜索"检测到直播间"条、全部搜索排除隐藏平台、主播/分区卡真实跳转。已完成（2026-10-25）。
- [ ] B4b 搜索余项：平台搜索失败时的继续/网页搜索兜底入口、范围排除、桌面 UA。
- [~] B5 备份：B5a 设置覆盖/缺项安全 + B5b WebDAV 目录浏览/选择恢复/上传命名/删除已完成（2026-10-25）；余多服务器配置、Digest、恢复前 diff/范围、上传进度。
- [~] B6 版本与更新/通知：B6a 版本/更新检查/版本记录 + B6b1 录制结果系统通知/首次录制权限已完成（2026-10-25）；余应用内下载与校验、跳过版本、启动自动检查与启动页、下载结果通知。
- [~] B7 关注：B7a 本地标签体系（筛选/卡片展示/设置面板/删除清理）已完成（2026-10-25）；余开播提醒、首页菜单顺序与重选刷新。
- [~] B8 录制/多画面：B8a 15 项录制设置/任务停止/错误 + B8b1 多画面选台搜索已完成（2026-10-25）；余默认画质、弹幕/礼物、拼音目录、开播自动录制/轮询；多画面弹幕/沉浸全屏/遥控/低画质/离屏优化/恢复提示。
- [~] B9 设置：B9a 行级搜索索引与多词 AND 已完成（2026-10-25）；余跳转/高亮到具体行、视频/弹幕全量设置、字号/加载样式/刷新率/播放器代理等参考行。
- [~] B10 浏览补齐：B10a 平台显示 + B10b 工具箱 + B10c 热门排序 + B10d 历史菜单 + B10e 分区滑动/预取/返回刷新 + B10f IPTV 导入/地址 + B10g 热门每页数量已完成（2026-10-25）；余热门观众指标、历史卡片网格/回顶、分区桌面页码、IPTV 文件/默认/热门 EPG 与播放列表自动更新/UA。


## 进度记录

| 日期 | 项目 | 结果 | 验证 | 备注 |
|---|---|---|---|---|
| 2026-10-25 | 台账建立 | ✅ | - | 记录当前已落地批次与剩余队列；定时任务按本表续跑 |
| 2026-10-25 02:02 | A1a/A1b/A1c/A1d | ✅ 部分 | analyze 0 / build bundle ok | 多画面真实播放落地；1+3、每格控制、搜索选台待做 |
| 2026-10-25 02:02 | A2a/A2b/A2c | ✅ | analyze 0 / build bundle ok | 房间录制按钮 + FFmpeg 引擎 + 录制中心联动；真流运行期待验证 |
| 2026-10-25 02:02 | A3a/A3b | ✅ | analyze 0 / build bundle ok | IPTV 频道播放页与卡片打开；换源/回看待做 |
| 2026-10-25 02:44 | A1b2 | ✅ | analyze 0 / build bundle exit 0 | 改动 `multiview_controller.dart`、`multiview_page.dart`：布局枚举（含 focus/1+3）、大格=选中格、侧列/下行自适应、小格紧凑标题；存档写枚举名并兼容旧整数。运行期未做真机目视 |
| 2026-10-25 03:26 | UI 外壳打磨 | ✅ | analyze 0 / build bundle exit 0 | 标题栏一键深浅色 + 搜索按钮（Ctrl/⌘+K、设置 Ctrl/⌘+,）；手机顶栏改为当前页标题并带搜索/主题，底部导航按模块给 4 个目的地；信息流滚动后出现回到顶部浮钮；原生标题栏平台在内容头补主题开关；appearance 的对比度/选中样式/撞色规则改为启动读取并持久化 |
| 2026-10-25 03:54 | 分页统一 | ✅ | analyze 0 / build bundle exit 0 | 按参考区分固定窗口/服务端页码/游标/单页：每站固定请求窗口 + 游标回传 + 身份去重 + 两页无新增结束；热门/分区桌面改本地切片（每页数量不再影响服务端页边界），分区补桌面分页条；搜索固定窗口、逐站续页、最多 8 并发；内联搜索桌面分页也改本地切片；短列表自动补页。核对表见 `docs/pagination-audit.md` |
| 2026-10-25 04:27 | 焦点与 TV | ✅ | analyze 0 / build bundle exit 0 | 删除独立 TV 外壳，TV 复用桌面外壳。侧栏当前项初始焦点与失焦救援；CardGrid 卡片按索引 D-pad 导航（左右跨列、上下跨行、末行加载更多），未构建行先滚动再聚焦，嵌套控件保留自身方向键；全局焦点变化自动滚入最近滚动区；房间页 TV 不再用方向键调音量、控制条常驻并以播放键起步；平台选择面板当前项 autofocus；TV 下隐藏工具栏与设置搜索框，避免方向键被文本框吃掉。焦点规则见 `docs/focus-navigation.md` |
| 2026-10-25 05:03 | 背景设置 | ✅ | analyze 0 / build bundle exit 0 | 新增「背景」设置分区与 app 根层 `PureBackground`：图片/视频本地上传或 http(s) 地址、填充/遮罩/模糊、清除；文件落到 `data/background`，视频背景独立 media_core 内核并在房间播放时暂停；外壳/侧栏/顶栏/分区房间页背景半透明 |
| 2026-10-25 05:43 | Bilibili 视频站 | ✅ | analyze 0（app + live_vod）/ live_vod 测试通过 / build bundle exit 0 / 真接口 probe 通过 | VOD 模块改为真站点：热门/排行/分区/搜索四个表面与视频详情播放页；`/vod/:bvid` 手动路由；播放走 media_core 共享内核，按 bvid+cid 续播；客户端补齐分区 feed（channel id 1005 等）、排行、访客指纹 cookie（搜索 412）；封面统一 https。详情见下节 |
| 2026-10-25 06:04 | IPTV 资源面板 | ✅ | analyze 0 / build bundle exit 0 | 按参考图重做 IPTV：页头（标题/统计/导入/视图切换）；频道改为表格（分组/正在播出+进度/收藏/播放，范围筛选、频道搜索、全部同步、短页自动补页）；来源改为「当前节目单 + 自动更新」卡片和合并资源表（格式/频道数/更新时间/自动更新/同步/删除，筛选、搜索、全部同步）；自动更新真实调度（6h/12h/24h/3天/7天，应用级定时器、逐项/全部开关、失败按间隔重试）。运行期未目视 |
| 2026-10-25 06:12 | IPTV 来源排序 | ✅ | analyze 0 / build bundle exit 0 | 来源表新增「编辑顺序」：编辑态覆盖设置卡片，拖动 + 上移/置顶/下移/置底，草稿提示、取消/保存；保存写 `iptv.sources.order` 并即时回显，取消不写。顺序仅影响来源表显示，不改频道/节目单业务。运行期未目视 |
| 2026-10-25 06:29 | 模块化设置架构 | ✅ | analyze 0 / build bundle exit 0 | 设置脱离「一份全量分区强塞所有模块」：模块注册表各自声明组，搜索/侧栏/手机菜单/面板眉题都按当前模块读取。共享区只保留主题外观、背景、导航、通用、网络、备份、缓存、关于；直播保留平台/刷新/播放弹幕/录制/直播数据；IPTV 新增节目单更新（间隔、批量开关、手动同步）；VOD 新增 Bilibili 账号（仅 B 站）与默认清晰度（播放页实际使用）；默认平台移到直播「平台显示」，备份从直播数据拆成共享分区；音乐暂无专属项。未做运行期目视 |
| 2026-10-25 06:50 | 房间崩溃与结构 | ✅ | live_sites 187 tests / analyze 0 / build bundle exit 0 / 序列化探针往返通过 | 修复打开直播间写历史崩溃：`LiveRoomActivity` 等枚举无序列化器、`LiveRoom` 还序列化了瞬态 `RoomRuntime`；补 8 个枚举的 name 序列化器、runtime `serialize:false` 并重生成。房间页按参考结构重排：AppBar 房间头（头像/主播/平台·分区/关注/菜单）、聊天列顶部信息条、宽窗 16:9 居中画面 + 右聊天列、窄窗堆叠；播放器暗底统一白字、错误标题本地化并截断原因。TwitCasting 那条流未重放，实际流是否可用仍取决于源 |
| 2026-10-25 07:03 | 设置导航整理 | ✅ | analyze 0 / build bundle exit 0 | 设置侧栏从「一堆行+分隔线」改为按组显示标题（界面/直播来源/播放/通用/数据/关于）；直播组顺序回到界面→直播来源→播放→通用→数据→关于；长项名精简（导航栏/平台与账号/自动刷新/播放内核/浏览与窗口/观看数据/版本与许可）；设置页隐藏全局工具栏搜索，只留设置搜索；搜索支持按组名命中。未做运行期目视 |
| 2026-10-25 07:09 | 折叠导航图标 | ✅ | analyze 0 / build bundle exit 0 | 折叠侧栏改为 64px 宽：项目用 40px 方形项 + 24px 图标（与顶部 24px 模块标记同一视觉重量），分组标题折叠成短分隔线；展开态仍是 16px 图标与文字行。未做运行期目视 |
| 2026-10-25 07:34 | 全量 UI/功能复核 | ❌ 未完成 | analyze 0 / build bundle exit 0（Android 包未构建） | 逐面核对参考后确认**没有全部同步**：60+ 面中多数 PARTIAL/MISSING；旧台账远程接收/WebDAV 多服务器/录制 17 项/播放设置/搜索网页/备份恢复等 ✅ 需降级。本轮修了 Android release 网络/PiP/媒体通知权限、房间详情失败永转圈/重试死按钮、离线无动作、线路循环、工具排序未消费、搜索死卡片。完整证据/优先级见 docs/parity-audit-2026-10-25.md 与 A11 |
| 2026-10-25 08:15 | A11 B4a 搜索 | ✅ | analyze 0 / build bundle exit 0 | 搜索页新增排序（智能/平台/观众/关注数，仅对已收页本地排序不重发）与"显示离线"；输入/粘贴 http(s) 链接时出现识别条，经 `linkToolProvider` 解析并进房间；网页搜索跟踪 URL，识别到直播间时显示"检测到直播间"条（进入/关闭）；"全部"范围排除隐藏平台；主播卡打开平台主页、分区卡打开分区房间页。文案 zh/en + slang。运行期未目视 |

| 2026-10-25 08:28 | A11 B1a 直播间详情/菜单/聊天 | ✅ 基础面 | analyze 0 / build bundle exit 0 | 详情面板：主播与关注、状态/开播时间/限制（本地化）、完整标题、在线/热度/累计、公告/简介、房间号/链接复制、分享（系统面板或剪贴板）、平台外部打开；信息条点击打开。房间菜单：详情、`LiveRoomRefresh` 稀疏刷新、分享、外部打开、复制链接、重试、关闭。聊天四 tab：弹幕（长按/右键复制、屏蔽用户、屏蔽关键词可编辑）/ 超级聊天（仅平台有 `LiveSuperChatFeed` 时）/ 弹幕设置（显示+样式全量）/ 屏蔽列表。屏蔽页文案改为已生效。运行期未目视 |

| 2026-10-25 08:31 | A11 B1b 播放手势与常亮 | ✅ | analyze 0 / build bundle exit 0 | 播放器手势层：单击显示/隐藏控制条、双击播放/暂停、竖向拖动调音量（右/任意位置，带音量浮层）、鼠标滚轮 ±5%；房间与 IPTV 播放期间通过 `live_device` 的 `ScreenAwakeService` 保持屏幕常亮，暂停/离开即释放。亮度手势、上下滑换台、长按倍速与媒体键仍缺。运行期未目视 |
| 2026-10-25 08:33 | A11 B2a IPTV 节目单与回看 | ✅ | analyze 0 / build bundle exit 0 | 新增 `iptv_guide_panel.dart`：按天翻页、节目时间/标题/副标题、正在播出进度、每分钟刷新；按频道的 `catchup-mode/source/days` 判断可回看并调用 `buildIptvCatchupUrl` 生成地址，回看中显示「正在回看」与「回到直播」，失败给出说明；播放页节目单按钮。频道当前节目每分钟走时。来源/回看真流未验证 |

| 2026-10-25 08:38 | A11 B6a 版本与更新 | ✅ 基础面 | analyze 0 / build bundle exit 0 | 新增 `features/version`：安装版本、手动检查 fork `assets/version.json`（`networkFactoryProvider` 代理、平台覆盖、版本号+构建号比较）、可更新面板（更新说明 + 打开下载页）、版本记录面板（`assets/releases.json`、Markdown 纯文本化、逐条打开）；关于页去掉占位，项目地址改为 `liuchuancong/pure_live`。**注意**：fork feed 当前为 3.1.19/build 4108，而应用 pubspec 为 0.1.0，因此会显示可更新；发布 v2 前需更新 version.json/releases.json，否则提示会误导。未做应用内下载与校验。运行期未目视 |

| 2026-10-25 08:41 | A11 B10a 平台显示收口 | ✅ | analyze 0 / build bundle exit 0 | `sitesDisplay.toggle` 改为返回是否变更：最后一个可见平台拒绝关闭并提示；隐藏首选平台时自动把首选移到下一个可见平台；设置「首选平台」下拉只列可见项；热门与分区在无可见平台时空态给出「平台显示」按钮（跳到设置 sites 分区）。运行期未目视 |

| 2026-10-25 08:43 | A11 B10b 工具箱剪贴板 | ✅ | analyze 0 / build bundle exit 0 | 链接工具打开后读取剪贴板，仅当文本能被 `LinkToolController.linkUriOf` 识别为链接/主机且字段为空时填入；读取失败静默。解析中显示「取消」，`reset()` 递增 generation 使旧解析不再写状态。运行期未目视 |

| 2026-10-25 10:05 | A11 B1c 竖屏比例与自动小窗 | ✅ | analyze 0 / build bundle exit 0 | 房间画面按 `PlayerHandle.combinedSnapshot.geometry.aspectRatio` 自适应：窄窗竖屏流 58% 高舞台、宽窗按真实比例，横屏不再强塞 16:9。新增「离开应用时自动小窗」播放设置（`playback.autoPip`，默认关）：Android/iOS 播放中进入 inactive 时按设置进入系统 PiP，每次离开只触发一次，回前台复位；桌面不触发。**PiP 入口仍依赖系统授权**，失败静默。运行期未目视 |

| 2026-10-25 10:09 | A11 B2b IPTV 播放能力 | ✅ | analyze 0 / build bundle exit 0 | 播放页新增：线路菜单（当前线路标记，`switchLine` 不重建会话）、上/下频道按钮与方向键（`IptvZapSequence.step` 环绕，`pushReplacement` 换页）、DLNA 投屏（把当前地址构造为 `LivePlayLine`，复用房间投屏对话框；投屏对话框去掉未用的 room 参数）、F 全屏/Esc 退出、返回直播改为图标。投屏/回看真流未验证 |

| 2026-10-25 10:15 | A11 B8a 录制设置与任务停止 | ✅ | analyze 0 / build bundle exit 0 | `RecordingSettings` 扩为 15 项并逐项接 `FfmpegRecordConfig`（分段、rwTimeout、队列、首路音视频、keepAlive、结束校验、重试次数/间隔、卡流、磁盘余量、TS/分段 MP4）+ 引擎并发上限。设置面板分「文件与位置/分段与恢复/后台与上限」三组，滑块/下拉/分段控件；任务菜单新增「停止录制」，卡片显示失败原因两行；空态/命名文案更新为已接入。真实录制仍未运行期验证 |

| 2026-10-25 10:20 | A11 B7a 关注标签 | ✅ | analyze 0 / build bundle exit 0 | 新增 `follow_tags.dart`（`follow.tags` JSON，名称去重）+ `follow_tag_picker.dart`：关注页标签筛选 chips、卡片标签行、长按/右键菜单「设置标签/取消关注」；面板勾选即时写 `RoomLocal.tagIds`，新增标签即加入当前房间，删除标签确认后从所有关注清理；标签被删后筛选自动回全部。未做标签色/重命名/开播提醒。运行期未目视 |

| 2026-10-25 10:22 | A11 B10c 热门排序 | ✅ | analyze 0 / build bundle exit 0 | 热门页平台行右侧加排序选择：平台推荐 / 按观众。排序只作用于已收目录，稳定（同观众保留平台序）；桌面先排序再本地切片，翻页内容正确；切换排序回到列表顶部。观众取 online/popularity/total 首个可用值。运行期未目视 |

| 2026-10-25 10:25 | A11 B1d 画面方向选择 | ✅ | analyze 0 / build bundle exit 0 | 新增 `room_orientation.dart`：房间菜单「画面方向」对话框（自动/竖屏/横屏），按房间 identity 存 `room.orientation` JSON；自动移除记忆。画面比例先取播放器几何，再按选择映射 9:16 / 16:9，窄/宽布局共用。未做竖屏全屏与三档面板。运行期未目视 |

| 2026-10-25 10:27 | A11 B10d 历史长按菜单 | ✅ | analyze 0 / build bundle exit 0 | 历史记录卡外包 `DsContextMenuRegion`：右键/长按可进入直播间、复制房间链接（复用 `copyRoomLink`）、删除记录（destructive）；原有点击进入与 x 删除保留。历史仍按 Today/Yesterday/Earlier 分组列表，未改卡片网格。运行期未目视 |

| 2026-10-25 10:32 | A11 B9a 设置行级搜索 | ✅ | analyze 0 / build bundle exit 0 | 新增 90 条左右的设置行索引（现有翻译键 + 中英关键词），桌面结果分「分区/具体设置」两组，行结果标注所属分区并跳转；手机列表把命中行写进分区描述；分区和行均支持空格分隔的多词 AND。未做具体行滚动/高亮。运行期未目视 |

| 2026-10-25 10:35 | A11 B10e 分区滑动与预取 | ✅ | analyze 0 / build bundle exit 0 | 分区网格加横向滑动：速度 ≥240 切换分类、两端环绕、切后回顶；`AreasCatalogController.warm` + 800ms 定时预热下一平台；页面监听生命周期，离开 ≥15s 返回刷新当前平台。未加桌面页码分页。运行期未目视 |

| 2026-10-25 10:36 | A11 B5a 备份覆盖与缺项安全 | ✅ | analyze 0 / build bundle exit 0 | `BackupDocument` 记录实际携带的 section（`presentSections` / hasFollows 等），`apply` 只清空并恢复文档真正带来的部分，旧备份缺 history/areas/settings 时保留本机数据；`kBackedUpPrefs` 从 19 项扩到约 85 项（浏览网格/外壳/主题/播放/弹幕样式/屏蔽/代理/缓存/IPTV 三个/录制 15 项/关注标签/房间方向等），移除不存在的 `iptv.epg.url`。仍未做 diff/范围选择与 WebDAV 多服务器。运行期未目视 |

| 2026-10-25 10:40 | A11 B5b WebDAV 目录浏览 | ✅ | analyze 0 / build bundle exit 0 | `WebDavBackupClient` 新增 `list/downloadFile/uploadFile/deleteFile/directory`，PROPFIND depth 1 用正则解析 response/href/resourcetype/size/date（不新增 XML 依赖），href 相对/绝对解析与 XML 反转义。新增 `webdav_browser.dart` 面板：上一级（不越过配置目录）、进入文件夹、点文件恢复（解析 + 摘要确认）、上传当前备份到指定文件名、删除服务器文件；备份页 WebDAV 增加「浏览服务器」入口。未对真实服务器验证 |

| 2026-10-25 10:44 | A11 B10f IPTV 导入与源地址 | ✅ | analyze 0 / build bundle exit 0 | 播放列表导入名称可空：URL 用 host，文本用「导入的播放列表」；名称提示改为留空自动命名。来源表名称单元格在地址旁增加复制按钮（本地/远程都可）与远程地址的外部打开按钮，复制成功/打开失败都有提示。运行期未目视 |

| 2026-10-25 10:47 | A11 B6b1 录制通知 | ✅ | analyze 0 / build bundle exit 0 | 新增 `user_notification_providers.dart`：启动时 best-effort `MediaCoreNotify.enable()`（安装 JobNotifications），`RecorderEngine.start` 首次触发权限请求；录制完成/失败走 media_core 的 job reporting。未在 Android/iOS/Windows 真机验证通知与权限 |

| 2026-10-25 10:50 | A11 B10g 热门每页数量 | ✅ | analyze 0 / build bundle exit 0 | 热门桌面分页旁新增每页选择（20/30/40/60/80），写入共享 `browse.pageSize`，`_PlatformFeed` 原有监听随即 `resize` 并保持当前首房间；pager 与排序共存。未做观众指标设置。运行期未目视 |

| 2026-10-25 10:53 | A11 B8b1 多画面选台搜索 | ✅ | analyze 0 / build bundle exit 0 | 选台弹窗改为有状态：顶部搜索框，按标题/主播/房间号/平台 id/平台显示名过滤关注+历史房间；无匹配给出空态；选中仍拒绝已在墙上的房间并提示所在格。未做弹幕/沉浸全屏/遥控 |

| 2026-10-25 10:52 | A11 B10h 观众指标设置 | ✅ | analyze 0 / build bundle exit 0 | 新增 `audience_metric_provider.dart`（`browse.audienceMetric`：跟随平台/在线/热度/累计），设置「浏览与窗口」加选择；热门 `RoomCard` 与关注 `FollowedRoomCard` 改为 ConsumerWidget 读取选择，缺该指标时按其余可用值回退；加入设置搜索索引与备份 prefs。运行期未目视 |

| 2026-10-25 10:56 | A11 B10i 历史卡片网格 | ✅ | analyze 0 / build bundle exit 0 | 历史页读取共享 `browse.layout`：网格模式按天用 `GridView`（max extent/间距随浏览设置）渲染新 `_HistoryGridCard`（16:9 封面、观看时刻角标、标题/主播、同一右键/长按菜单），列表模式保留原行卡；菜单项抽成 `_historyMenuItems` 两处共用。未加回顶/刷新进度。运行期未目视 |

| 2026-10-25 10:59 | A11 B10j 历史刷新进度 | ✅ | analyze 0 / build bundle exit 0 | `HistoryController.refreshRooms` 增加 `onProgress(done,total)`；历史页刷新时头部显示 `DsProgressBar`，逐条回报、结束清除，失败条数仍 toast。未加回顶/分页。运行期未目视 |

### 背景设置（2026-10-25）

- 使用工作区 `packages/pure_uikit_background`（`PureBackground`）作为唯一渲染层。
- 设置 → 外观组下新增「背景」分区：无 / 纯色 / 渐变 / 图片 / 视频。
  - 纯色/渐变为内置预设（参考 pure_live_TV 的 solid/gradient 表，取 12 个纯色 + 14 个渐变），
    通过 `SolidBackground` / `GradientBackground` 渲染。
  - 图片支持本地上传、http(s) 地址和「图库」：快捷图库取 deepin 公共图库 6 张缩略图；
    「浏览全部壁纸」打开内置图库面板，来源与 pure_live_TV 的图库一致：官方（7 分类）、Wallhaven（19 分类）、
    必应、deepin（26 张，随应用编译）与动态壁纸（iTab `/wallpaper/video/list`）。
    官方/Wallhaven/必应/动态壁纸走 iTab API（与 TV 相同的 host/headers/分页），缩略图按需加载，
    AVIF 统一请求为 JPEG；选中图片/视频即应用。
  - 视频支持本地上传、http(s) 地址和内置动态壁纸；上传文件复制到 `data/background/`，替换时删除旧文件。
  - 未同步：TV 的 19 组随机图片 API（随机必应/栗次元/无铭/UAPI 等）；它们不是图库分类，需要单独页面与
    随机取图/预览流程。
  - 图库模型为 built_value：`background_library_models.dart`（`WallpaperSource` / `WallpaperCategory` /
    `WallpaperItem`，builder 生成），目录只存 id 与 API 过滤值；来源名与全部分类名走 slang
    （`wallpaperSource*` / `wallpaperCategory*`），Dart 里不再有中英文字符串。deepin 的壁纸标题保留
    作品原名（源数据/专有名词），不作为界面标签。
- 显示项：填充方式/高斯模糊仅对图片/视频显示；遮罩强度对全部类型生效；可清除背景（保留已保存媒体）。
- 应用根层渲染背景；外壳、侧栏、顶栏、分区房间页在外壳范围内改为半透明，卡片保持不透明。
- 视频背景使用独立的 media_core 内核（无音频、无池、无投屏驱动），应用不可见或房间有播放句柄时暂停。

| 2026-10-25 11:13 | 背景样式扩展（参考 pure_live_TV） | ✅ | analyze 0 / build bundle exit 0 | 背景来源由无/图片/视频扩为无/纯色/渐变/图片/视频：新增 `background_presets.dart`（12 纯色 + 14 渐变 + deepin 图库 6 张），设置面板用色块/渐变块/缩略图直接应用；`AppBackground` 用包内 `SolidBackground`/`GradientBackground` 渲染，图片仍走 cachedImage；纯色/渐变隐藏无意义的填充/模糊行；新增 prefs 纳入备份与设置搜索。运行期未目视 |

| 2026-10-25 11:21 | 内置壁纸源与视频源同步 | ✅ | analyze 0 / build bundle exit 0 / iTab 三源 curl 200 | 新增 `background_library.dart`：官方 7 分类、Wallhaven 19 分类、必应、deepin 26 张、动态壁纸（iTab `/wallpaper/video/list`）五个内置来源，分类 chips、分页加载更多、缩略图网格、选中即应用图片/视频；深链接到背景设置「浏览全部壁纸」。iTab host/headers/分页与 TV 一致，官方/Bing/视频接口已 curl 验证 200；AVIF 改请求 JPEG 以适配桌面解码。随机图片 API 组仍未同步。运行期未目视 |

| 2026-10-25 11:34 | 图库模型 built_value + 来源国际化 | ✅ | analyze 0 / build bundle exit 0 | `WallpaperSource`/`WallpaperCategory`/`WallpaperItem` 由 record 改为 built_value（生成 `.g.dart`，builder/不可变），目录只保留 id/query/pageSize；5 个来源名与 26 个分类名全部移入 slang（`wallpaperSource*`/`wallpaperCategory*`），删除 Dart 内硬编码中英文；图库请求增加 generation 守卫，切源/切分类时旧请求不会写回；移除旧的 `backgroundOfficial/backgroundBing/backgroundLiveWallpapers`。deepin 作品标题保留原名。运行期未目视 |

| 2026-10-25 15:48 | 背景路由拆分 + 来源预览 | ✅ | analyze 0 / build bundle exit 0 / 1280×800 运行期目视 | 「背景」改为总览 + 4 个来源路由（在线图片 / 在线视频 / 纯色与渐变 / 从设备），桌面内容区切换、手机平板推 `SettingsSectionRoute`；图片与视频各自列出来源 chips（图片 4 源、视频 iTab 动态壁纸）、分类 chips、分页网格；点缩略图打开预览对话框，视频预览用独立 `PureBackground` 播放，确认「应用」才替换背景，取消不变；总览保留当前背景预览、填充/遮罩/模糊/清除；删除旧混排 `_BackgroundPane` 与 `showBackgroundLibrary` 面板，搜索索引改指向 4 个子页。未同步随机图片 API 组。运行期已看总览/图片/视频/纯色/设备与预览对话框；本机网络未取到 CDN 缩略图，失败占位可见 |

| 2026-10-25 16:42 | 随机图源（背景） | ✅ | dart analyze lib 0 / flutter build bundle exit 0 / Windows 运行期取图+应用+换一张 | 新增「随机图源」背景子页：参考的 7 组 82 个随机图源（必应/栗次元/无铭/UAPI/360/其他/性感），支持 direct、JSON 取址、alcy 随机分类三种请求；桌面 UA、代理复用、JSON 键递归取址、`&amp;` 反转义、25s 超时、字节魔数校验（JPEG/PNG/GIF/BMP/WebP，拒绝 AVIF/HEIC 与 HTML/JSON 信封）；取到的字节按 FNV 内容哈希写入 `data/background/random-*.ext`，旧图删除；预览对话框可“换一张”、重试，确认后才替换背景。分组/来源名全部进新 slang 命名空间 `wallpaper`。运行期验证 UAPI 组：11.4s 取到并显示，应用后背景与 toast 生效；发现共享 HTTP 缓存会让“换一张”返回同一张，随机请求改为 `cache: false`，复测第二张不同。

### 背景设置：路由与预览（2026-10-25）

- 结构对齐参考的分来源页面，不再把所有来源塞进一张长页：设置 → 个性化 → 背景是总览（当前背景、来源入口、显示项），四个子页分别是「在线图片」「在线视频」「纯色与渐变」「从设备」。桌面在内容区切换并保留侧栏，手机/平板走路由；面包屑递归显示 `设置 › 个性化 › 背景 › 子页`。
- 在线图片页：官方 / Wallhaven / Bing / deepin 四个来源 chips，各自分类 chips、缩略图网格、加载更多；点缩略图弹大图预览，「应用」才写入背景。
- 在线视频页：iTab 动态壁纸来源，缩略图带播放标记；预览对话框内用 `PureBackground` + `AppBackgroundVideoSource` 实际播放，关闭即释放播放器。
- 纯色与渐变页保留调色板与渐变块；从设备页保留图片/视频的本地上传与 http(s) 地址输入。总览页显示当前背景预览（视频不重复创建解码器，只提示应用后播放）、填充、遮罩、模糊与清除。
- 图库客户端（`background_library.dart`）只保留取数与分页；旧的图库面板、6 张快捷图与 `showBackgroundLibrary` 一并移除，避免两套来源入口并存。设置搜索覆盖新的四个子页及其行。
- 总览的当前背景预览限制在 480px 宽（16:9），不会再把来源入口挤出首屏；图片加载失败时显示「图片无法加载」占位，而不是一块空白。预览对话框标题用固定的「壁纸预览」，不拿 iTab 官方源的哈希文件名当标题；网格的选中环只在对应类型确实生效时出现。
- 验证：`dart analyze lib` 0、`flutter build bundle` exit 0；Windows debug 1280×800 实际点击走查：总览 / 在线图片 / 在线视频（预览对话框）/ 纯色与渐变（应用后背景实时变化）/ 从设备 / 面包屑返回。本机网络未加载到 CDN 缩略图与视频帧，所以只验证了占位与对话框结构，未验证真实图像/视频像素。

### Bilibili 视频站（2026-10-25）

- 入口：VOD 模块 `VodPage` 四个表面 —— 热门（`/x/web-interface/popular`，`no_more` 收尾、请求窗口 ≤50）、排行（`ranking/v2`，经典 rid、单页）、分区（`region/feed/rcmd`，channel id 1005/1008/… 分页，空页收尾）、搜索（`search/type`，综合/播放/最新/弹幕/收藏 + 时长档，窗口 ≤50）。
- 分区 feed 与排行用的是两套 id：feed 要 1xxx channel id（经典 id 会 `-400`），排行要经典 rid；「资讯」channel 没有排行榜，所以只在分区页出现。
- 访客搜索会被风控（HTTP 412）：客户端首次搜索时取 `/x/frontend/finger/spi` 的 `buvid3/buvid4`，并把 referer 换成 `search.bilibili.com`；已登录时直接用账号 cookie。
- 详情页 `/vod/:bvid`：`view` 元数据、分P、相关推荐（前 20）；播放 `playurl fnval=1` 的渐进 mp4（画面+声音），高画质只回 DASH 时播放首条视频流并明确提示无声；画质/分P/倍速/音量/全屏/PiP 均在控制条。
- 播放进度键 `vod.progress.<bvid>`（JSON：cid + 秒），换 P/换画质/离开页面先落盘；播放到结尾清除；被详情/菜单路由覆盖时暂停。
- 已知边界：无弹幕、评论、收藏/追番、PGC；VOD 模块的「收藏/历史」入口仍是直播模型；DASH 音视频合流未接入（需 `media_core_ingest`，未获准新增依赖）。

### IPTV 资源面板（2026-10-25）

- 布局按参考图：页头显示 `IPTV` + 当前表面名 + 统计（频道/分组或播放列表/节目单/频道），右侧两个导入按钮和「频道 / 来源」切换；窄窗把操作换到标题下。
- 频道表：名称（台标/台号）、分组、正在播出（程序名 + 进度条）、收藏、播放；工具条含全部/收藏、本组数量、频道搜索、全部同步；分组仍用 tabs；表格在固定高度内滚动，短列表自动补页，窄宽度走 `DsTable` 的卡片模式。
- 来源表：当前节目单（选择来源）与自动更新（全部开关、间隔、状态行）两张卡片；下方合并播放列表与节目单，列为名称/类型/频道/更新于/自动更新/操作，工具条含全部/播放列表/节目单、数量、搜索、全部同步；删除仍二次确认，使用中的节目单有角标。
- 自动更新：`iptv.update.hours` 持久化 6/12/24/72/168 小时；应用启动时挂一个进程级定时器，每分钟检查开启 `autoUpdate` 的网络节目单，`lastRefresh` 超过间隔才同步；一次运行一个、失败记住尝试时间按一个间隔重试，手动导入/同步时不抢网络。
- 当前节目单的「正在播出」仍靠页面每分钟重读；回看/换源菜单仍未做。
- 来源顺序是显示顺序（`iptv.sources.order`，`p:`/`g:` 键）：编辑态有拖动与四个方向动作、草稿提示和取消/保存，取消不落盘。频道的点播顺序仍由库的置顶/号码/分组规则决定，不在这次排序范围内。
- 验证：`dart analyze lib` 0、`flutter build bundle` exit 0；未做运行期目视。

### 模块化设置（2026-10-25）

- 每个模块的设置由 `module_navigation.dart` 的 `settingsGroups` 唯一决定：直播、IPTV、Bilibili 视频、音乐各一份；`settings_sections.dart` 不再把全量分区并进每个模块。
- 共享分区：外观（主题/对比度/字体）、背景、导航栏、通用（页大小/窗口行为）、网络代理、备份与恢复、缓存、关于。它们在各模块显示同一份内容。
- 直播专属：平台显示与授权（默认平台也从「通用」移到这里）、刷新（关注自动刷新）、播放（画质/音量/画面比例）、弹幕、小窗弹幕、播放器内核、录制、直播数据（历史与关注导入导出）。备份不再埋在直播数据里，改为共享分区。
- IPTV 专属（节目单与更新）：更新间隔（6h/12h/24h/3天/7天）、网络节目单的批量自动更新开关、全部同步；与 IPTV 页面和后台定时器共用同一组 provider。
- Bilibili 视频专属（账号与清晰度）：只列 Bilibili 的账号（`AccountPane` 增加站点过滤），默认清晰度（720P/1080P/1080P+/4K，`vod.quality.qn`）；播放页打开分P时按该值请求，服务端实际给的清晰度仍以播放器菜单为准。
- 音乐模块暂无曲库来源，因此只显示共享分区，不伪造音乐专属项。
- 搜索、桌面侧栏分组、手机设置菜单和面板眉题都读当前模块的组；搜索不会搜到其他模块的设置。
- 桌面设置侧栏在每个组上方显示组名（折叠成图标栏时退回分隔线），直播分组按「界面 → 直播来源 → 播放 → 通用 → 数据 → 关于」排列；项名精简后同一屏更容易扫读。设置页不再同时显示工具栏的全局搜索，只保留面板内的设置搜索。
- 折叠侧栏保持 64px 轨宽，项目使用 40px 方形项 + 24px 图标，与顶部 24px 模块标记同一视觉重量；展开态仍保持 16px 图标和文字行。
- 验证：`dart analyze lib` 0、`flutter build bundle` exit 0；未做运行期目视。

### 直播间序列化崩溃与结构（2026-10-25）

- 崩溃原因：`HistoryRepository.record` 调 `LiveRoom.toJson()`；`live_sites` 的 built_value 序列化表只登记了模型类，没有 `LiveRoomActivity` 等枚举序列化器，且 `LiveRoom` 的生成序列化器把本应瞬态的 `RoomRuntime` 也写进去。两处都会抛 `Bad state: No serializer ...`。
- 修复：在 `serializers.dart` 增加 8 个枚举的 name 序列化器（未知值回退到 none/unknown 等安全值）；`LiveRoom.runtime` 标 `@BuiltValueField(serialize: false)` 并重生成；探针验证 `toJson`/`fromJson` 往返，`live_sites` 187 个测试通过。
- 房间页结构向参考 v5 `live_play` 靠拢：普通态顶部是 AppBar 房间头（返回、头像、主播、平台·分区、关注、更多菜单）；宽窗画面按 16:9 居中在深色舞台里，右侧 300–400px 聊天列，聊天列顶部是信息条（状态/标题/观众/开播时间/定时关闭）；窄窗按「画面 + 信息条 + 聊天」堆叠。原来的底部标题/关注条已移除。
- 播放器的暗底文字/控制条/进度线改用固定白色等级（浅色主题下不再深字压深底）；错误遮罩标题本地化（房间信息失败/播放失败），原始错误只作为两行截断说明，两个操作仍走 desen_ui 按钮。
- 未完成：聊天列的详情面板、超级聊天/弹幕设置 tabs、聊天折叠手柄、本地发送器，以及参考的完整播放器手势；TwitCasting 示例流没有重放，实际播放失败是否仍发生取决于源。

### 设置：个性化总览（2026-10-25）

- 参考 Windows「个性化」：设置侧栏不再单列「外观」「背景」，改成一个「个性化」入口。入口页顶部是当前主题预览 + 跟随系统/浅色/深色三张主题缩略图（点选立即应用），下面是个性化设置行：背景（显示当前类型）与外观（显示当前模式）。
- 子页是可返回的独立页面：手机/平板走 `SettingsSectionRoute` 路由；桌面在设置内容区切换并保留侧栏，页头显示「个性化 › 背景/外观」面包屑，返回键回总览。侧栏在子页时仍高亮「个性化」。
- 设置搜索改为内容区顶部居中的搜索框（最大 560px），没有在标题栏新增搜索图标；搜索结果包含嵌套在个性化里的外观/背景页及其行。
- 窗口标题条不再跟随 mobile/desktop 内容布局：自绘窗口在窄窗仍显示标题条，推入的设置/分区/网页/房间/IPTV/Bilibili 路由也补上标题条（播放全屏与窗口全屏时隐藏）；系统标题栏和手机平台仍由平台负责。
- 验证：`dart analyze lib` 0、`flutter build bundle` exit 0；未做运行期目视。

### 设置信息架构与播放器（2026-10-25）

- 侧栏改成 Windows 式分类：直播模块为「直播 / 个性化 / 播放 / 系统」，IPTV、Bilibili 视频各自把模块分类放在最前，最后是「关于」。每个分类进入总览页，再打开子页；桌面保留侧栏并在内容区切换，手机/平板走 `SettingsSectionRoute`。
- 子页路径只保留顶部一条面包屑：桌面内容头的「设置 › 分类 › 子页」可点分类返回，设置面板内不再重复大号面包屑，只显示子页标题与说明；手机仍用路由 AppBar 的返回。
- 合并重复页面：直播资源 = 平台显示/排序/账号 + 关注自动刷新；弹幕 = 屏蔽关键字/用户 + 样式 + 小窗弹幕；数据与缓存 = 观看历史/关注导入导出 + 封面缓存。播放分类下保留「播放偏好」与「播放器内核」两个子页；系统分类含浏览与窗口、网络代理、平台节点、日志、数据与缓存、备份与恢复。
- 首页导航也按平台定义：Windows/macOS/Linux 在任何窗口宽度都保留桌面侧栏（窄窗自动收成图标轨），手机/平板才用底部栏/抽屉；桌面窄窗隐藏内容区 320px 工具栏搜索，避免挤掉面包屑。
- 播放器内核：桌面只注册 mpv（与旧参考一致，页面如实说明）；Android/iOS 额外注册 IJK 与 BetterPlayer，设置中可切换并以 `preferredBackend` 传给直播/VOD 播放，选择持久化到 `player.backend`。
- 播放器内核页按旧参考补全：播放器代理（独立 host/port，应用到 mpv `http-proxy`）、硬件解码开关与 hwdec 解码器、强制销毁播放器、6 个播放预设（均衡/安卓兼容/RTX VSR/低配/弱网/低延迟，含额外 mpv 属性）、Anime4K 三档、mpv 高级设置（自定义 vo/ao、video-sync、插帧、缩放、反交错、hwdec-codecs、WASAPI 独占）、恢复默认、mpv 官方文档和播放器指南。调参持久化到 `player.tuning` / `player.proxy`，对当前与之后的 handle 生效；输出驱动变化会重建引擎。
- 首页「链接解析」现在只做链接解析；原先塞在同一入口的「平台节点」「日志」移到设置 → 系统，「缓存清理」由设置 → 系统 → 数据与缓存承担。
- Anime4K 超分辨率：复制旧参考的 9 个 shader；关闭/效率/质量三档持久化到 `player.superResolution`，通过 mpv `glsl-shaders` 应用到当前 handle 与之后打开的播放器，仅 Windows 显示与生效。硬件解码仍通过 `hwdec` 写入。
- 验证：`dart analyze lib` 0、`flutter build bundle` exit 0，shader 已进入 bundle；未做运行期目视。

## 运行注意事项（2026-10-25）

- 两个自动化（「合并」与「PureLive 页面同步续跑」）在 01:40–01:56 同时改过 multiview/recorder，导致页面与控制器短暂不匹配；已停止两个运行并暂停任务，人工核对后已恢复一致。
- 后续恢复自动化时只启用一个，避免两个会话同时写同一批文件。

## 阻塞与待决策

- 账号/备份的具体范围与优先级需用户确认（TV 已改为复用桌面外壳，不再单独排期）。
- 音乐的数据来源需产品决策；VOD 已定为 Bilibili（2026-10-25）。
- 参考里没有后端支撑的偏好（封面自动刷新、液体玻璃、字号微调、底部导航栏开关）不伪造。
- 加载样式全量画廊：参考的 85 种动画来自 `flutter_spinkit`、`loading_animation_widget`、`loading_indicator` 三个包；用户未批准新增依赖，THEME-06 现提供 10 种 Flutter 原语实现，其余 75 种隐藏而不伪造。若同意加包再补齐。
- 更新检查指向 fork `liuchuancong/pure_live` 的 master `assets/version.json`；当前 feed 仍是 3.1.19（build 4108），应用版本 0.1.0。发布 v2 时需同步该文件（版本/构建号/平台下载地址），否则会一直提示可更新。应用内下载需要发布产物的命名约定，暂只打开下载页。

### 设置全量同步清单（2026-10-25）

- 新增 `docs/settings-sync-inventory.md`：按参考 `pure_live-master` 的 10 个入口 + 全部子页逐项列出控件键、类型/默认值、存储键、消费点和我们的现状，给出 8 个批次（房间卡片/页面/导航 → 通用/窗口/配置预览 → 视频/PiP/播放行为 → 弹幕 → 竖屏 → 刷新/缓存/字体/加载 → 本机互动 → 域设置复核）。
- 明确验收规则：每个控件必须有真实消费点；平台不支持的项隐藏而不是做假开关；新设置进入备份、搜索与重置路径。
- 当前最大缺口：视频页 61 键（仅对齐约 8 项）、弹幕约 30 项（约 1/3）、房间卡片 35 键（仅观众指标）、竖屏 39 键、主题/字体/加载样式、通用/窗口/启动、分页/导航。
- 本轮先补了背景的随机图源；下一批从房间卡片 + 页面 + 导航开始。

### 设置逐项审查清单（2026-10-25）

- 新增 `docs/settings-review-checklist.md`：从参考的 185 个持久化 `hive*` 键 + 设置页动作/链接逐条展开，共 263 项，一行一项，标注参考文件:行号、默认值、消费点、当前状态，供逐项审查后再实现。
- 顶部保留 17 个分区（通用/主题/页面导航/刷新/视频/内核/竖屏/弹幕/房间卡片/字体/加载/观众/代理/缓存/背景/IPTV/录制/备份/本机互动/内部键）。
- 工作流改为：审查一项 → 只实现该项的 prefs + 消费点 + UI + l10n + 备份 + 验证 → 勾选并记录，不再按页面一次性大改。

| 2026-10-25 17:00 | 设置 GEN-01/02 刷新率 | ✅ | dart analyze lib 0 / flutter build bundle exit 0 / Windows 实机只读 | 用 `live_device` 的 `DisplayRefreshRateService` 接刷新率：`display_refresh_rate_provider.dart` 读 current/max/supported/monitorCount、观察 watch、持久化 `display.refreshRateMode`，按平台能力映射节能 `matchContent(60)` / 均衡 `preferDefault` / 性能 `preferMaximum`；Windows 请求接口不可用时只读，不显示假下拉。新增通用页“显示 → 刷新率”行（当前/最高 Hz、多显示器提示、重新读取），加入备份与设置搜索。Windows 实机显示 240 Hz 只读；Android/iOS 模式选择待真机。 |

| 2026-10-25 17:20 | 设置 VID-18 播放保持屏幕常亮 | ✅ | dart analyze lib 0 / Windows debug build / 设置行实机 | 新增 `keepScreenOnProvider`（`playback.keepScreenOn`，默认 true）与播放偏好页开关；房间页与 IPTV 播放页的 `_syncScreenWake` 改为读取偏好后再取/放 live_device `ScreenAwakeService` 的 wakelock，暂停/失败/关闭设置时释放。加入备份与设置搜索。 |

| 2026-10-25 17:35 | 设置 GEN-05 启动自动检查更新 | ✅ | dart analyze lib 0 / flutter build bundle exit 0 / Windows 实机 version.json 200 | 新增 `updateSettingsProvider`（`updates.autoCheck`，默认 true）与通用页“更新”分组开关；`PureLiveApp` 首帧后若开关开启且尚未检查，静默调用 `versionCheckProvider.check()`，结果由关于页渲染，失败不打断。加入备份与设置搜索。GEN-06 因只有一个 GitHub 发布源，标注为不适用，不造镜像开关。 |

| 2026-10-25 17:50 | 设置 GEN-10 窗口尺寸 | ✅ | dart analyze lib 0 / flutter build bundle exit 0 / Windows 实机应用+重启恢复 | 新增 `windowSizeProvider`（`window.width`/`window.height`）与通用页“窗口尺寸”行/对话框：五个参考预设 + 自定义宽高（400–16384 × 300–16384），应用后通过 `WindowHost.setGeometry` 居中；启动时应用存储尺寸，窗口边缘拖拽 450ms 后回写，加入备份与设置搜索。实机从 1280×800 改为 1600×900，行值更新，重启仍为 1600×900。 |

| 2026-10-25 18:10 | 设置 GEN-09 开机启动（live_device） | ◐ | dart analyze lib/packages 0 / Windows build / CLI 服务直测通过；GUI 运行期被本机策略拒绝 | `live_device` 新增 `StartupService`/`StartupCapabilities`/`StartupException`/`PlatformStartupService`：Windows 写 HKCU Run 键（reg.exe），失败回退到 Startup 文件夹 `.cmd`；读状态按可执行文件目标比对。App 新增 `startupProvider`（系统状态为准，读写超时 6/8s）与通用页开关，失败不再是无限 spinner。CLI 直测 enable/disable 成功；代理启动的 GUI 进程写 Run 返回 Access Denied，回退文件未落盘，需用普通启动方式复测；不伪报成功。 |

| 2026-10-25 18:25 | 设置 GEN-07/08 定时关机 | ✅ 代码完成，未运行期测试 | dart analyze lib 0 / flutter build bundle exit 0 | 参考是“自动关机倒计时”而非关闭按钮倒计时：新增 `autoShutdownProvider`（`exit.autoShutdown.enabled` / `.minutes`，默认关 / 120 分钟，范围 1–525600），启用即从完整时长开始、改时长重启、关闭立即取消；到时桌面 `WindowHost.destroy`+`exit(0)`、移动 `SystemNavigator.pop`。通用页新增“定时关机”分组：开关 + 剩余时间/时长行 + 预设与自定义时长对话框；加入备份与设置搜索。按要求跳过运行期测试。 |

| 2026-10-25 18:40 | 设置 GEN-04 启动动画 | ✅ 代码完成，未运行期测试 | dart analyze lib 0 / flutter build bundle exit 0 | 新增 `splashSettingsProvider`（`ui.splash`，默认 true）与根层 `StartupSplash`：启动时以应用标记覆盖内容区，900ms 保持 + 280ms 淡出后移除；关闭后下次启动直接进主界面。通用页加“启动动画”开关（主窗口），加入备份与设置搜索。按要求跳过运行期测试。 |

| 2026-10-25 18:55 | 设置 PREVIEW-01 配置预览 | ✅ 代码完成，未运行期测试 | dart analyze lib 0 / flutter build bundle exit 0 | 新增 `config_preview_dialog.dart`：以 `captureSettingsSnapshot()` 生成缩进 JSON，只读可选文本 + 复制；关于页加入“配置预览”入口，加入设置搜索。仅展示备份携带的键，不提供编辑。未运行期测试。 |

| 2026-10-25 19:27 | 设置 GEN-11 退出确认 | ✅ 代码完成，未运行期点击测试 | dart analyze lib 0 / live_shell analyze 0 / live_shell 147 tests passed / flutter build bundle exit 0 | 改动：`packages/live_shell` 的 `close_disposition.dart`（`CloseChoice`）、`shell_settings.dart`（`dontAskExit`）、`desktop_shell.dart`（`confirmClose` + 单飞关闭流程）；应用新增 `app/window_close_dialog.dart`、`app/routing/root_navigator.dart`，改 `app_router.dart`、`app_bootstrap.dart`（`storedDontAskExit`、Windows/Linux 确认、macOS 不接）、`shell_settings_provider.dart`（`rememberCloseChoice/setDontAskExit`）、`settings_page.dart`、`settings_search.dart`、`backup_settings.dart`、settings 中英文 JSON 与 slang 生成文件。消费点：`DesktopShell._handleClose` 读取 `ShellSettings.dontAskExit` 并询问，回答回写 `shell.closeAction`/`shell.dontAskExit`；勾选后直接执行关闭动作。未做运行期点击验证，也未实现参考在关闭动作失败时回滚 `dontAskExit` 的分支。 |

| 2026-10-25 19:46 | 设置 GEN-12 Android 交互自适应刷新率 | ✅ 代码完成，未在 Android 真机验证 | dart analyze lib 0 / flutter build bundle exit 0 | 对照参考 `AdaptiveRefreshRateController`/`AdaptiveRefreshRateScope`：新增 `app/refresh_rate_interaction_scope.dart` 包住根内容，收集指针按下/移动/抬起、滚动开始/更新/结束与 resumed/inactive/paused 生命周期；`display_refresh_rate_provider.dart` 增加 Android 策略：节能与均衡先 `preferDefault`，均衡仅交互时 `preferMaximum`、停手 1.5s 回落，性能前台保持最高、切后台释放；请求串行合并，选择新档清除旧 burst；Android 上节能/均衡不再依赖内容匹配、节能不固定 60 Hz，其他平台保持原映射。更新 settings 中英文刷新率说明与档位名称（slang 已生成）。 | 

| 2026-10-25 19:47 | 设置 GEN-14 `autoRefreshTime` 审查 | ➖ 参考自身不适用 | 全文检索确认 | 参考只有声明、备份/恢复和旧配置迁移（`app_settings_controller.dart:43/196/222/249/272`），没有任何设置控件或运行期读取；关注页定时刷新实际由 `refreshConfigController.autoRefreshFavorite/autoRefreshInterval` 驱动。我们不为遗留键造无效开关，清单标为已核实不适用。 |

| 2026-10-25 19:58 | 设置 GEN-15 关注页紧凑模式 | ✅ 代码完成，未运行期点击测试 | dart analyze lib 0 / flutter build bundle exit 0 | 改动：`browse_settings_providers.dart`（`FavoritesDensityController`，键 `browse.denseFavorites`，默认 true）、`settings_refresh.dart`（恢复/跨窗口刷新）、`favorites_page.dart`（消费网格列宽）、`settings_page.dart`（通用页浏览偏好开关）、`settings_search.dart`、`backup_settings.dart`、settings 中英文 JSON 与 slang 生成文件。消费点：`FavoritesPage` 按开关选择 cardExtent；紧凑模式小卡片（上限 280px、多列），关闭后按参考 300px 下限计算列宽（手机单列、大卡片）。未验证部分：未做运行期点击/目视，未在真机确认列宽切换。 |

| 2026-10-25 20:02 | 设置 REF-01/02/03 关注刷新 | ✅ 代码完成，未运行期测试 | dart analyze lib 0 / flutter build bundle exit 0 | REF-01 复核已有周期刷新开关、时钟重挂、备份/搜索；REF-02 新增 `refresh.follows.onResume`（默认 true）与设置开关，`FavoritesPage` 在 `resumed` 后 450ms 静默刷新全部关注，15s 内刚刷新则跳过，离开前台取消待执行；REF-03 把默认间隔从 15 改为参考的 30，并在读写处夹取 5–360。改动：`refresh_settings_providers.dart`、`favorites_page.dart`、`settings_page.dart`、`backup_settings.dart`。文案与搜索项原已存在，未改 slang。 | 

| 2026-10-25 20:03 | 设置 REF-04 最大并发刷新 | ✅ 代码完成，未运行期测试 | dart analyze lib 0 / flutter build bundle exit 0 | 新增 `refresh.maxConcurrent`（默认 4，范围 1–20）与 `maxConcurrentRefreshProvider`；设置 → 资源 → 刷新加入 20 档选择（4 标推荐）；关注页刷新批大小由硬编码 4 改为读设置，观看历史刷新由逐条串行改为同一边界分批并发，并让单个房间异常不再中断整轮；加入备份、搜索、恢复后 provider 刷新与中英文文案（slang 已生成）。 | 

| 2026-10-25 20:06 | 设置 REF-05/06 封面自动刷新 | ✅ 代码完成，未运行期等待周期 | dart analyze lib 0 / flutter build bundle exit 0 | 新增 `thumbnail_refresh_provider.dart`：`refresh.thumbnails.auto`（默认 false）与 `refresh.thumbnails.minutes`（默认 30，5–360），每个窗口首帧启动计时器，跨窗口 revision/备份恢复后重排；到点同时清空图片磁盘缓存与内存图片缓存，房间窗口清自己的 manager；设置 → 资源 → 刷新新增开关与八档间隔（仅开关开启时显示）；加入备份、搜索与中英文文案（slang 已生成）。未验证部分：未实际等待 5 分钟观察缓存清空/重新下载。 | 

| 2026-10-25 20:15 | 设置 THEME-01/04/05 主题与网格间距 | ✅ | dart analyze lib 0 / flutter build bundle exit 0 | 复核主题模式（默认跟随系统、三档、备份/搜索）；把网格横/纵间距的范围与默认值从 0–32 / 16 改为参考的 0–64 / 6，`browse_settings_providers.dart` 的常量同时驱动设置滑杆与所有共享 `CardGrid`，已进备份与搜索。未运行期目视间距变化。 | 

| 2026-10-25 20:27 | 设置 IPTV-04 自定义 User-Agent | ✅ 代码完成，未运行期验证 | dart analyze lib 0 / flutter build bundle exit 0 | 新增 `iptv_user_agent.dart`（`iptv.userAgent`，默认空；空白清除）与设置 → IPTV 文本框；`iptvImporterProvider` 把 UA 传给播放列表/节目单下载 fetcher，IPTV 播放与投屏在条目未自带 UA 时补上（条目自带优先）；加入备份、搜索、`settings_refresh` 与 iptv 中英文文案（slang 已生成）。未验证部分：未实际抓包确认 UA 到达服务端、未播放验证。 | 

| 2026-10-25 20:42 | 设置 VID-01 全局静音 | ✅ 代码完成，未运行期播放验证 | 定向 dart analyze 0；全量 `dart analyze lib` 无 error（仅并行会话 `window_media_session.dart` 的 1 条 info）；`flutter build bundle` exit 0（20:45，产物已更新） | 新增 `playback.globalMute`（默认 false）与播放偏好「全局静音」开关；直播间按 `_muted || _globalMute` 生效并实时监听，IPTV/VOD 在句柄到达与设置变化时应用，多画面墙把全局静音计入可听判断且按钮可清除；各播放器的取消静音会关闭全局静音，避免假按钮；预置静音 `playback.muted` 保留为用户自己的选择；加入备份、搜索、中英文文案（slang 已生成）。未验证部分：未实际播放并切换全局静音。 | 

| 2026-10-25 20:45 | 设置 THEME-02 任意主题色 | ✅ 代码完成，未运行期点击测试 | dart analyze lib 0 / flutter build bundle exit 0（最终复跑；并发会话的 `window_media_session.dart` 收尾前曾阻塞全量分析，未修改该外部文件） | 改动 `theme_persistence.dart`（`theme.seed` 现可存命名名或 `#RRGGBB`，新增 `parseSeedColor`/`encodeSeedColor`/`storeSeed`）、`stored_theme.dart`（启动解析自定义色）、`theme_settings.dart`（`AppThemeScope.seedColor` 区分自定义与系统/命名色）、`pure_live_app.dart`（`_customSeedColor`，仅 seed 真正变化时写盘，避免冻结系统取色）、新增 `theme_color_dialog.dart`（系统取色 + 6 命名色 + 参考 14 预设色 + HSV 色板/色相条/hex 输入，确认后应用）、`settings_page.dart`（主题色行改为取色对话框）、`settings_search.dart`（自定义/色盘/十六进制关键词）、settings 中英文 JSON + slang 生成文件。消费点：`DsThemeData(seed: settings.seed)` 即时重建按钮/选中态/强调色；重启由 `readStoredAppThemeSettings` 从 `theme.seed` 恢复；备份沿用 `theme.seed`。未验证：未运行期点击取色、未重启验证自定义色恢复。 | 

| 2026-10-25 21:01 | 设置 VID-02/03 移动/桌面默认音量 | ✅ 代码完成，未运行期验证 | dart analyze lib 0 / flutter build bundle exit 0 | 把单一 `playback.volume` 拆成 `playback.mobileVolume`（默认 0.5）与 `playback.desktopVolume`（默认 1.0），读写夹取 0–1；设置 → 播放偏好「默认音量」按当前平台（Android/iOS 含 TV 为移动，其余桌面）读取/写入，旧 `playback.volume` 只在对应平台作为迁移回退并在改动后移除；直播间、IPTV、VOD、多画面新播放器都用当前平台默认音量（IPTV/VOD 原先未消费默认音量，本次补上）；加入备份两键、搜索关键词与默认值说明（slang 已生成）。未验证部分：未在手机/桌面分别打开播放器确认初始音量。 | 

| 2026-10-25 21:05 | 设置 THEME-03 动态取色 | ✅ 代码完成，未运行期点击测试 | dart analyze lib 0 / flutter build bundle exit 0 | 新增 `lib/app/providers/dynamic_color_provider.dart`：`theme.dynamicColor`（默认 false）与 `dynamicColorProvider`；`dynamicColorSeedProvider` 用已有的 `dynamic_color` 读平台调色板（Android 12+ 壁纸 CorePalette 主色，Windows/macOS/Linux 系统强调色，iOS/web 返回 null）。消费点：`PureLiveApp` 在开关开启且调色板可用时把主色作为 `DsThemeData` 的 seed 覆盖存储主题色，`DsThemeData(seed)` 驱动全应用强调色；`AppThemeScope.dynamicSeedColor` 供外观页与个性化预览读取。外观页新增「动态取色」开关（无调色板的平台不渲染），开启时主题色行只读并显示「跟随系统动态取色」；个性化三张主题预览同步使用动态 seed。改动：`theme_persistence.dart`（读写）、`theme_settings.dart`（scope 字段）、`pure_live_app.dart`、`settings_refresh.dart`（跨窗口/恢复失效）、`settings_page.dart`、`settings_search.dart`、`backup_settings.dart`（`theme.dynamicColor`）、settings 中英文 JSON + slang 生成文件。未验证部分：未运行期点击；Android 壁纸调色板未在真机验证；Windows 默认 seed 本就取系统强调色，默认外观下开关前后颜色相同，选过自定义/命名主题色后差异可见。 | 

| 2026-10-25 21:13 | 设置 VID-04 首选清晰度 | ✅ 代码完成，未运行期验证 | 本项定向 `dart analyze` 0；`flutter build bundle` exit 0（21:12，产物已更新，包含本项）；21:14 起另一会话在改 loading style / live_storage，当前全量 analyze 被其半成品打断，与本项无关 | `playback.quality` 从“站点原始标签或自动”改为参考的五档优先清晰度（原画/蓝光8M/蓝光4M/超清/流畅，默认原画）；设置 → 播放偏好五档选择；新增 `preferredQualityIndex`，先精确匹配标签、否则按档位比例选最近的站点画质；房间 `RoomController._pickQuality` 与多画面 `_pickQuality` 共用；旧存值蓝光/高清/标清映射到最近档位；加入蓝光 8M/4M 中英文文案、搜索关键词与备份沿用。未验证部分：未在各平台/各站点实际对比画质映射。 | 

| 2026-10-25 21:19 | 设置 THEME-06 加载样式 | ◐ 代码完成，参考 85 种中实现 10 种，未运行期点击测试 | dart analyze lib 0 / flutter build bundle exit 0（21:19，产物已更新） | 新增 `lib/app/providers/loading_style_provider.dart`（`theme.loadingStyle`，默认 `default`，未知键归一）与 `lib/shared/widgets/app_loading_indicator.dart`（10 种 Flutter 原语动画：default/pulse/doubleBounce/threeBounce/wave/fadingCircle/cubeGrid/ripple/orbit/lineScale；default 仍用 `DsSpinner`；遵守 reduced-motion；无新增依赖）。新增 `lib/features/settings/loading_style_dialog.dart`：外观页「加载样式」行带静态预览，打开画廊对话框，10 种动画实时预览、选中即写。消费点：`CardGrid` 加载页脚/下拉刷新、房间聊天与播放器、IPTV 频道/来源/播放页、多画面、VOD、WebDAV、背景图库、版本记录、工具箱等页面加载状态。改动另含 `theme_persistence.dart`、`settings_page.dart`、`settings_search.dart`、`backup_settings.dart`（`theme.loadingStyle`）、`settings_refresh.dart`、settings 中英文 JSON + slang 生成文件。参考其余 75 种动画依赖 `flutter_spinkit`/`loading_animation_widget`/`loading_indicator`，未获准新增依赖，故不展示。未验证：未运行期点击/目视各动画尺寸与画廊排版；75 种外部动画未同步。 |

| 2026-10-25 21:25 | 设置 THEME-07 加载颜色 | ✅ 代码完成，未运行期点击测试 | dart analyze lib 0 / flutter build bundle exit 0（21:24，产物已更新） | 新增 `theme.loadingColor`（默认空=跟随主题强调色；读取接受 `#RRGGBB`/`#AARRGGBB`，空白即清除）与 `loadingColorProvider`；`AppLoadingIndicator` 的着色顺序改为“显式 color > 加载颜色设置 > 图标色 > 强调色”，因此 `CardGrid`、房间聊天/播放器、IPTV、多画面、VOD、WebDAV、背景图库、版本、工具箱等加载状态统一换色，视频暗底等显式白色仍优先。加载样式对话框中新增「加载颜色」行与取色对话框：跟随主题、14 个参考预设色、任意 6/8 位十六进制（8 位含透明度），确认后写入。改动：`theme_persistence.dart`（读写/ARGB 编码）、`loading_style_provider.dart`（provider）、`app_loading_indicator.dart`（消费）、`loading_style_dialog.dart`（行+取色）、`settings_search.dart`、`backup_settings.dart`（`theme.loadingColor`）、`settings_refresh.dart`、settings 中英文 JSON + slang 生成文件。未验证：未运行期点击取色/目视半透明加载圈；THEME-06 已由并发会话于 21:19 完成并记录，本轮按下一未勾选项推进。 |

| 2026-10-25 21:29 | 设置 THEME-08 语言 | ✅ 复核完成（无代码改动） | dart analyze lib 0 / flutter build bundle exit 0（21:27） | 复核参考 `appearance_pages.dart:143-179`（未选择时跟随系统，行内显示当前语言）与 3.x `theme_settings_controller.dart:20`（键 `language`，默认简体中文）后确认现有实现完整：`app.locale`（null=跟随系统，slang `base_locale` 为 zh-CN）；`PureLiveApp` 启动与跨窗口/恢复时 `LocaleSettings.setLocaleRawSync`，`AppLocaleScope` 供外观页读写，`_updateLocale` 写盘并立即应用；设置行（跟随系统/简体中文/English）、备份 `app.locale`、搜索与中英文文案均已有。只提供已翻译的两种语言。未验证部分：未运行期点击切换/重启确认持久化。 |

| 2026-10-25 21:33 | 设置 THEME-08 语言（并发收口补强） | ✅ 代码完成，未运行期切换 | dart analyze lib 0 / flutter build bundle exit 0（21:33，产物已更新） | 本轮开始时按旧清单选中 THEME-08；执行中另一会话于 21:29 已复核并勾选该项，保留其记录、未覆盖。本轮补的代码：`ThemePersistence.normalizeLocaleCode` 归一化 `zh`/`zh-*`/`简体中文`/`中文`/`English` 等旧值或参考显示名，`readLocale` 与 `PureLiveApp._updateLocale` 只读写规范代码 `zh-CN`/`en`，未知值回退跟随系统；外观页语言选项改用 slang 新键 `settings.languageSimplifiedChinese`/`languageEnglish`（中英文 JSON 已生成）。消费点：根 `TranslationProvider` + `DsApp.locale` + `AppLocaleScope`；备份键 `app.locale` 与设置搜索原已存在。未验证部分：未运行期切换语言/重启恢复；保留现有“跟随系统”选项与默认（参考仅英语/简体中文且默认简体中文）。 |

| 2026-10-25 21:53 | 设置 THEME-09 文本缩放 | ✅ 代码完成，未运行期点击测试 | dart analyze lib 0 / flutter build bundle exit 0（21:52，kernel_blob 已更新） | 对照参考 `font_settings_controller.dart:18-20/41`（默认 `defaultTextScaleFactor` 1.0，范围 0.5–2.0）与 `theme_settings_page.dart:160-185`（主题页滑杆 + 预览），新增 `app/providers/text_scale_provider.dart`：键 `theme.textScale`（floating，默认 1.0，读写/归一化夹取 0.5–2.0，非有限值回退默认）与 `textScaleFactorProvider`；消费点 `PureLiveApp` 的 builder 用 `MediaQuery.copyWith(textScaler: TextScaler.linear(textScale))` 包住全部路由与启动遮罩，主窗口和克隆窗口都走同一根；外观页“字体和语言”新增文本缩放行（0.5×–2.0×、15 档、显示百分比）和实时预览行；加入备份 `theme.textScale`、设置搜索（文本/字号/缩放/倍率）、`settings_refresh` 的 provider 失效列表和中英文文案（slang 已生成）。未验证部分：未运行期拖动滑杆/目视 0.5×–2.0× 下各页面排版，未重启确认恢复。 |

## 自动化（2026-10-25）

- 已启用本地自动任务「PureLive 设置清单逐项同步」：每 30 分钟独立运行，读取 `docs/settings-review-checklist.md`，每轮只完成第一项未勾选项，补持久化/消费点/UI/l10n/备份/搜索并更新清单与台账；验证 `dart analyze lib` 与 `flutter build bundle`，不当场做 GUI 点击测试。
- 另外两个旧自动化（「合并」「PureLive 页面同步续跑」）保持 disabled；只保留这一个启用，避免并发写。
