# 直播间 UI 重设计：信息条置顶（方案 A，已确认）

2026-11-12 定稿。用户要求放弃逐形态打补丁的旧做法，先设计后编码。
视觉方向经样张选型确认为 **A**；同日用户反馈「不好看我还是喜欢放顶部好一点」⇒ **信息条从视频下方移至顶栏**（宽/常规/紧凑三档与系统 chrome 合并为一条顶栏），视频舞台拿到完整高度。
样张：room-ui-spec.html（交互原型+设计文档）。**2026-11-12 第十四轮起以 ZCode 会话 visualizations 目录副本为唯一工作副本**，qoder 会话目录原件停止改动、仅作历史来源。
本文件是该任务的台账：每轮开工先读，做完回填状态列。

## 诊断（为什么重做）

- 9+ 形态各自在 room_page.dart（2083 行）build 里手写分支，无统一布局模型 → 近期提交链来回振荡。
- 主播身份出现在 4 处（AppBar 标题 / 聊天列头 / 顶条关注胶囊 / 详情面板），无唯一归属。
- 动词散落顶条簇 / 底条 / ⋮ / 聊天 tab / 详情板五处。
- 缺口：宽屏视频下无常驻信息栏；竖屏全屏聊天不可达（room_chat_stream.dart 285 行零引用成孤儿）。
- 巨石：player_surface 3143 / room_controller 2848 / room_page 2082 / room_chat 1472；room 目录 36 文件 14554 行（2026-11-12 wc 核实）。

## 定稿设计

### 五区单一归属

| 区 | 内容 | 归属 |
|---|---|---|
| 舞台 | 视频+滚动弹幕层（唯一弹幕形态）+手势+瞬态 HUD+锁定 | player_surface |
| 控制 | 底部播放行：播放/画质/线路/比例/倍速(回放)/弹幕开关+设置/音量/全屏/回放 seek；右上工具簇：截屏/录制/PiP/投屏/更多入口；锁定钮 | 控制条+右上簇（视频内浮层，自动隐藏，沿用 shared/player/player_overlay.dart 标准）；锁定钮独立右缘垂直居中（观看守卫，第十二轮） |
| 身份与信息 | 头像/名字/标题/分区/人数/时长/关注/分享（认证 ✓ 徽章删除） | **顶栏=头像＋两行（行1 主播名、行2 平台·类型）**；**标题+观看·已播=大屏视频左上玻璃条**（跟随自动隐藏、锁定消隐）；紧凑=顶栏头像+主播/平台类型＋面板房间信息条（标题+观看·已播）；全屏/横持=胶囊（行2 平台·类型，展开含标题与数据）；PiP=标题条（第二十一轮定稿） |
| 互动 | 聊天/醒目/录制/屏蔽 4 tab+输入 | 宽=右列；常规=堆叠；窄=三停靠点面板；横持=仅消息列；竖屏全屏=上滑临时面板；剧场=覆盖抽屉 |
| 系统 | 返回/窗口键/主题 | 页头或顶条；「更多」唯一入口=视频右上簇（panel/sheet 随尺寸，第十轮）；窗口级动作只走窗口 chrome（□ 键/全屏▾），不进更多（第十一轮） |

### 布局状态机

窗口档（宽≥840 / 常规 600–839 / 紧凑 <600，沿用现值；已核实 `kRoomWideBreakpoint=840`、compact `<600`）× 呈现模式（内联/剧场/系统全屏/窗口全屏/竖屏全屏/PiP/TV）× **平台（Windows/macOS/Android/iOS，第八轮新增）**。
chrome 策略由一张 policy 表驱动，删 build 手写分支。手机横持（高<480 且宽≥600，与代码 `_phoneLandscapeMaxHeight` 一致）：舞台满高 + 右侧仅消息列 280（双列，非单列）。**TV 留位（第十三轮明确）**：呈现模式保留 tv 枚举、策略表留行，但 TV 遥控焦点遍历/10ft 字号不在本轮范围，另立任务补全；现状 `Env.isTv` 仅在 app 壳层使用，room 内无 TV 分支。平台臂只换系统区组件：窗口键（Win −□× / mac 红黄绿 / 移动无）、窗口全屏（仅 Win）、手势与快捷键（桌面/移动）。**更多容器随舞台宽分流（第九轮）**：≥720=玻璃 panel（右下锚定、点外关闭、内部滚动），<720=B站底部 sheet；与 AppShell pageNarrow 同 720 口径。

### 响应式策略表

| 元素 | 宽≥840 | 常规 600–839 | 紧凑<600 | 手机横持 | 竖屏全屏 | 剧场/系统全屏 | PiP |
|---|---|---|---|---|---|---|---|
| 舞台 | 左 Expanded 地板 420 | 全宽≤60%高 | 全宽 16:9 | 满高 | 全屏 | 全屏 | 全屏 |
| 身份 | 顶栏 64px 常驻 | 顶栏 56px | 顶栏 48px | 顶条胶囊 | 胶囊(自动隐藏) | 胶囊 | 隐藏(仅 PiP 标题条) |
| 聊天 | 右列 320(拖 280–520，T 折叠) | 堆叠在下 | 三停靠点 250/44%/68% | 右列 280 仅消息 | 上滑临时面板 | 覆盖抽屉 | 无 |
| 控制条 | 底部通栏·两端锚定·自动隐藏(视频宽<460 收拢+⋮兜底) | 同 | 同 | 同 | 同+底部手势带 | 同 | PiP 条 |
| 右上工具簇 | 5 图标·跟随隐藏 | 5 图标 | 文字 3 芯片 | 文字 3 芯片(视频宽≈580→T3) | 文字 3 芯片 | 5 图标 | —（全量在条） |
| 锁定钮 | 右缘垂直居中·跟随隐藏·锁定态唯一残留（PiP 在条上）·锁定同时挂起亮度/音量/双击手势（B站 app 同款） |||||||
| 次级动词 | 右上簇「更多」→panel/sheet | 同 | 同 | 同 | 同 | 同 | —（全量在 PiP 条） |
| 更多容器 | 右列全高 panel | ≥720 panel 否则 sheet | sheet | ≥720 panel 否则 sheet | sheet | ≥720 panel | —（全量在条） |
| 滚动弹幕 | 视频区仅滚动弹幕 · 无底部浮聊/置底 · 醒目留言不进视频区 · 全平台一致 |||||||

### 控件位置与自动隐藏组（2026-11-12 第二轮反馈定稿）

- **控制条位置**：视频**底部通栏、两端锚定**（左=播放/音量，右=画质/线路/弹幕/截屏/PiP/投屏/全屏），底渐变 scrim 承托；窄视频 <460 自动收拢（左=播放+音量图标，右=弹幕+画质+全屏，其余进 ⋮ 兜底）。悬浮胶囊降为可选对比项，不做默认。
- **自动隐藏组**（跟随 `controlsAutoHideSeconds` 一起隐/现）：控制条、右上工具簇、锁定钮（锁定态常驻）、身份胶囊、顶/底渐变 scrim、竖屏全屏手势提示带、PiP 条+标题。**不跟随**：页顶栏（身份常驻）、聊天列/面板（内容）、滚动弹幕层（内容）。
- **锁定作用域（第十三轮补充）**：锁定同时挂起亮度/音量/双击/长按手势与全部视频内 chrome，仅保留右缘解锁钮；解锁后恢复原状态（B站 app 同款防误触语义）。
- **音量分档（第十三轮明确）**：T1=图标+滑杆；T2=图标点击=静音切换、滚轮/键盘微调（不出滑杆，保单行）；T3/T4=文字钮开滑杆弹层。亮度/进度手势仅移动端。
- **删除「直播中」徽标**：用户原话"我都在看直播了我还不知道在直播中吗"——观看即直播，状态冗余；人数与已播时长保留在顶栏/胶囊。录制中状态保留（非冗余）。

### 控件全清单与归属（2026-11-12 第六轮反馈定稿：参考哔哩哔哩）

用户否掉右侧控制条（"我不要右侧栏这种"），贴 B站播放器面板截图要求照它做；并点名**清晰度/线路/画面比例/关注不要图标、小屏不要用图标**。定稿：

1. **底部播放行＝两端锚定双簇**（第十七轮用户定稿）：**左簇**=播放/暂停(错误→重试)·刷新(常驻·重连)·音量(T1 滑杆，图标=静音切换)·弹幕开/关；**右簇**=清晰度·线路·画面比例·倍速(回放)·窗口全屏(仅 Windows)·全屏；弹幕设置齿轮撤条（更多设置行唯一入口）。**单行不换行**（第七轮反馈）：T4 压缩字号 10.5/去前缀/去箭头保证 373px 一行放下（含回放倍速 chip），溢出时横向细滚动条兜底；回放 seek 独立在栏上方一行，不占控制行。T1 加音量滑杆与全标签。
2. **右上工具簇**（第十轮定骨架，第十七轮改成员）：截屏/录制/画中画/⋯更多（投屏移入更多面板 tile）；桌面单行图标、小屏文字芯片(截屏/录制/更多)，全档位常驻视频右上、跟随自动隐藏；**更多唯一入口=右上簇**（底部行与顶栏不再放更多）。画中画/投屏小屏仍进更多面板。**锁定/解锁钮独立右缘垂直居中**（第十二轮纠正，B站 app/腾讯视频/MX Player 防误触位）：观看态守卫、拇指弧内，锁定后唯一残留、同位置解锁；不进右上簇也不进更多。
3. **「更多」容器随尺寸（第九轮定稿，第十五轮照参考图重排）**：舞台宽 ≥720=**右列全高面板**（照 B站 web：覆盖聊天列、点外关闭、内部滚动、圆 tile 均匀网格 5 列），<720=**B站样式底部 sheet**（照 B站 app：「分享/工具/设置」分区分组、圆 tile 行）；内容同一套：分享圆 tile(分享/复制链接/外部打开/房间详情)＋带字工具 tile(截屏/录制/小窗播放/投屏/播放统计/切换房间/后台听，开关式 tile、不另设重复开关行)＋设置行：倍速行内分段、控件自动隐藏行内分段、清晰度/线路/画面比例/弹幕设置/定时关闭箭头行。锁定不在 tile（第十二轮：右缘独立，第十三轮已修正此处漏改）。**窗口级动作（窗口全屏）不进更多**。入口=右上簇⋯/更多（唯一）；打开期间暂停自动隐藏。
4. **页顶栏/视频左上条/胶囊**（第二十一轮用户定稿）：**顶栏=头像＋两行**——行1=主播名（14px 粗体）、行2=平台·类型（哔哩哔哩 · 电台·虚拟主播）；右侧=**关注纯文字**＋分享/详情/主题/折叠/窗口键；**标题+观看·已播=大屏（宽/常规/窗口全屏）视频左上玻璃条**——省略号兜底、悬浮显全文、点击开详情、跟随控件自动隐藏、锁定态消隐；紧凑=顶栏头像+主播/平台类型＋底面板房间信息条（标题+观看·已播）；全屏/横持=胶囊（行2 平台·类型，展开=标题+观看·已播+分享/详情）；PiP=标题条。
5. 无右侧栏、无折叠 deck、无图标堆砌；PiP 条单行容纳全量。
锁定态：视频内 chrome 全隐只留解锁钮；错误态：播放行出重试+画面错误卡。
画面比例选项：自适应(铺满舞台)/16:9/4:3/21:9（后三者 contain 真 letterbox），JS 按视频盒计算场景几何。
逐控件落位依据（频率×状态×层级三问、参考对照与用户拍板列）见样张 #map「控件落位分析」表；本文件只记结论，不重复论证。

### 竖屏补强

- **视频区只显示滚动弹幕**（第八轮反馈）：删除底部浮动聊天与置底展示，醒目留言仅在醒目 tab、不进视频区；聊天一律走右列/面板/抽屉。room_chat_stream 零引用直接删（P5），不再复活浮条。
- 竖屏全屏上滑唤出聊天面板（复用 RoomBottomPanel 内容），补"聊天不可达"缺口。

### 平台差异（2026-11-12 第八轮反馈定稿）

用户："不同平台还有不同的组件功能，比如 windows 上还有窗口全屏功能"。平台是策略表第三维：

| 组件 | Windows | macOS | Android | iOS |
|---|---|---|---|---|
| 窗口键 | − □ ×（自绘标题栏） | 红黄绿 | 无 | 无 |
| 窗口全屏 | **有**·铺满屏幕保留标题栏 | 无 | 无 | 无 |
| 系统全屏/剧场 | 有 | 有 | 系统全屏 | 系统全屏 |
| 画中画 | 应用小窗 | 应用小窗 | 系统 PiP | 系统 PiP |
| 投屏 | DLNA/Miracast | AirPlay/DLNA | DLNA/Miracast | AirPlay/DLNA |
| 手势/键盘快捷键 | 无手势·有快捷键 | 同左 | 有手势·无快捷键 | 同左 |

Windows 窗口全屏入口（第十五轮改）：播放行「全屏｜窗口全屏」**同行双芯片**＋标题栏 □ 键；全屏▾ 二选弹层删除（第十一轮的两入口方案废止其一）。窗口级动作不进更多面板。

## 现状审查（2026-11-12 第十六轮，双探索代理核实，仅事实与行号）

### 现状地图（关键锚点）

- **布局分支**：room_page.dart build 手写分支 L890-1374——悬浮窗 L890／竖屏全屏 L756-772（入口 L1134）／横持 L786-797（判定 L941）／竖屏流底部面板 L1167-1201／窄堆叠 L1149-1232／宽窗 L1234-1271／TV L1273-1338／ownsWindow 整页 L1364-1365。
- **身份散 5 处**：AppBar `_RoomTitleBar`（仅标题，L1511）／`_ChatRoomHeader`（L1539，宽列头 L1264+窄窗 L1229）／`_RoomHero`（L1840，竖屏面板头）／`_AnchorFollowChip`（player_surface L2083，immersive 顶条+折列两场景）／详情面板 `_Streamer`。关注按钮 3 个实现（`_FollowPill` L1652／chip 内嵌 L2159／`_DetailsFollow`）。AppBar 现无头像/人数/关注。
- **控制条**：`_ControlBar`（player_surface L2793-3052）画面底 Positioned（bottomInset/controlBarEndInset），非通栏；控件=播放/重试/弹幕组（开关+齿轮）/画质线路比例（`_StreamPickerRow` L1643，<600 fitOnly 移 ⋮）/窗口全屏（**仅条宽≥720，L2929/L2999**）/全屏（L3012）；回放另有 seek 行（L2939）。**缺**：音量条上入口（现仅滚轮/拖拽/↑↓）、倍速（media_core adapter 已暴露 `setRate` player_adapter.dart L91，不动内核即可接）。
- **右上工具**：`_PlayerTopBar`（L1782-2077）**仅 immersive/tv/横持显示**（identity L1276）→ **宽窗普通态无截屏/录制/PiP/投屏入口**（截屏仅 S 键、PiP 无入口）。簇内件：截屏 pill L1964／音频 pill L1953／`_PresentationCluster`（录制/PiP/投屏 L2465-2634，narrow<460 投屏录制退出）／More pill L1923。
- **更多**：⋮=DsMenuAnchor 固定下拉（AppBar `_RoomMenu` L1808-1829 / 画面条 More pill 两挂载）；`roomMenuItems`（L1716-1801）=切房/画质线路(compact)/投屏/睡眠定时/独立房间窗口/快捷键帮助。
- **锁定**：已有，右缘垂直居中（player_surface L1440-1454）✓位置同设计，但**仅 immersive** 显示。
- **弹幕**：flame 滚动层✓；弹幕设置面板已有（四滑杆+高级页，`_DanmakuSettingsControls` L2276-2395）与设计一致，直接保留。
- **聊天列**：折叠已接（chatCollapsedProvider+AppBar toggle+T 键）；**拖拽零接线**——ChatSplitter（186 行，拖/双击复位/键盘）与 chatPanelWidthProvider（280-520 持久化）已就绪但无消费方，宽度硬编码 360（L1239）；折叠态非 TV 无画面重开钮。
- **竖屏**：RoomBottomPanel 三停靠点（250/44%/68%+拉穿进全屏）已存在且 6 例护栏测试锁定，与设计同数值✓；横持 feedOnly 280 列✓已存在；**竖屏全屏无聊天入口**（`_buildPortraitFullscreen` L756-772 仅 swipe hint）。
- **断点**：840/600/480/280 与设计一致；720 已用于控制条（L2929）与设计同口径；缺 T1-T4 控件档位体系（现仅 narrow<460/crowded<320 两级）。
- **护栏**：仅 room_bottom_panel_test（6 例）；无 840 断点/布局分支护栏测试 → P1 验证门需先补最小护栏。
- **其他**：「直播中」徽标代码本无（P3 该项作废）；死代码确认：room_chat_stream（285 行，L1084 注释"已移除"）、chat_display_settings 的 chatMode/chatStreamCorner provider（仅 settings_refresh 引用）。

### 差距表（定稿 → 现状 → 落点）

| 设计定稿 | 现状 | 差距 | 步骤 |
|---|---|---|---|
| 身份唯一归属顶栏 | AppBar 仅标题，身份散 5 处、关注 3 实现 | AppBar 吸收头像/人数/关注；收编 4 widget；胶囊扩标题/人数/已播 | P2 |
| 控制条底部通栏两端锚定+scrim | 已在画面底但非通栏 | 通栏化+音量入口新增+倍速（回放，走 setRate） | P3 |
| 全屏｜窗口全屏同行文字芯片 | 已相邻两个图标钮 | 图标→文字芯片、撤 ≥720 门槛、<460 压缩「窗口」 | P3 |
| 右上簇全档位常驻（跟随隐藏） | 仅 immersive 顶条；宽窗普通态无会话工具 | 提为 surface 级常驻浮层，不依赖顶条形态 | P3 |
| 更多=右列全高 panel／分区 sheet | ⋮ 固定下拉菜单 | 新造两容器；roomMenuItems 迁移（见下）；撤两挂载点 | P5 |
| 聊天列可拖 280-520+折叠+重开条 | 折叠✓；拖拽零接线；无重开钮 | 接线 ChatSplitter+chatPanelWidthProvider；右缘重开条 | P3 |
| 锁定全档位 | 仅 immersive | 撤 immersive 门槛 | P5 |
| 竖屏全屏聊天可达 | 无聊天入口 | 上滑临时面板（复用 RoomBottomPanel 内容） | P4 |
| TV 留位 | TV 专属分支已存在（玻璃列 overlay） | P1 枚举映射现状分支，行为不变 | P1 |

### 两种显示方法 → 现状映射（第十六轮结论）

- **大屏（B站 web，图2/图4）**：`Row[stage+聊天列]` 骨架已同构；差「顶栏常驻身份」（=P2/P3）、「右列全高更多面板」（=P5 新造）、「底行动词全文字芯片」（=P3 升级）。
- **小屏（B站 app，图1/图3）**：三停靠点面板/横持单消息列已存在且数值与设计一致；差「sheet 分区分组」（=P5 新造）、「竖屏全屏聊天可达」（=P4）、「右上簇小屏文字芯片」（=P3 常驻化时一并落）。
- **内容迁移（roomMenuItems 六项去留）**：切换房间→工具 tile；画质/线路（compact 兜底）→撤（`_StreamPickerRow` 底条已承担）；投屏→撤（右上簇已有）；睡眠定时→更多设置行；**独立房间窗口→工具 tile（第十六轮新增内容项）**；快捷键帮助→设置行尾部（仅桌面臂）。

### 风险

- 护栏薄：P1 动手前先补「断点→形态枚举」最小护栏测试，否则「行为不变」无法自证。
- AppBar 高度 40/toolbarHeightOf → 设计 64/56/48：ownChrome 时 `WindowDragArea`（L1428）必须包住新身份块，拖拽区不得缩水。

## 实施步骤（按依赖排序，每步可独立验证）

| # | 步骤 | 主要路径 | 验证门 | 状态 |
|---|---|---|---|---|
| P0 | **补最小护栏**：断点→形态枚举测试（840/600/480 分界 × 竖屏流/横持），锁定现状行为基线 | 新 test/live/room_layout_guard_test.dart | analyze + 新护栏绿 | **已做**（7 例全绿） |
| P1 | 布局状态机 + chrome policy 表（纯重构，行为不变；tv 枚举映射现状玻璃列分支 L1273-1338） | room/layout/room_layout.dart（常量+枚举+resolve），room_page 构建分支改读机器旗标（assert 桥已撤，手算公式与 `_phoneLandscapeMaxHeight` 已删，见第二十七轮） | analyze ✓ + P0 护栏绿 ✓ + room_bottom_panel_test 绿 ✓ + 行为等值改写 ✓ | **已做**（内容盒级 wide 复查保留，属内容度量） |
| P2 | 身份唯一归属 RoomIdentityBar（顶栏/胶囊多态一件） | room/identity/room_identity_bar.dart 已建并接入 AppBar（两行=主播/平台·类型，头像带 live 环，`WindowDragArea` 包整块，高度≥56）；actions 增关注 pill+详情门；`_RoomTitleBar` 删除；标题移交 PlayerSurface（见 P3a）；`_ChatRoomHeader`/`_RoomHero`/`_AnchorFollowChip` 收编随 P3/P4 | analyze ✓ | **已做**（列头收编随 P3） |
| P3 | 宽窗骨架落 A：P3a 视频左上标题+数据条已挂（`_RoomTitleCaption`，宽/常规内联显示，跟随自动隐藏，点击开详情）；P3b 控制条已按双簇重排（左=播放/刷新/静音/音量滑杆(≥720)/弹幕，右=清晰度/线路/比例｜窗口全屏(撤 720 门槛)/全屏）；P3c ChatSplitter 已接线宽窗聊天列（拖拽 preview/松手 set 持久化/双击复位 340，宽度走 `chatPanelWidthProvider`，semanics 键 `chatColumnWidth` 新增于 room l10n）；P3d 右上簇已收口——更多 pill 内联常驻（`menuItems: widget.roomMenu` 不再按 immersive 门控）、投屏撤出条（split 簇只留录制/PiP，投屏在 ⋮ 菜单与（P5 后）更多面板）；P3e replay 倍速文字芯片已挂（循环 1.0/1.25/1.5/2.0，`handle.setRate`，引擎拒绝时芯片仍显示所请）；scrim/两端锚定经复核为现状已有（`_ControlBar` 底渐变 + `Positioned(left:0,right:inset)`），无需改动；右上簇成型（现挂顶条动词行内）随 P6 拆分顺带 | room_page.dart、player_surface.dart | analyze ✓ 全绿 + 测试 105/105 ✓ | **已做**（簇成型随 P6） |
| P4 | 竖屏：竖屏全屏聊天可达——`_buildPortraitFullscreen` 加聊天面板（`_portraitChatOpen` 状态，下方 62% `RoomGlassCard`+`RoomChatPanel(translucent)`，把手点击/下滑关闭，离开竖屏全屏自动复位）+ 开门 pill（`DsIcons.messageCircle`，位于还原区上方，Tap 开启不用手势避免与设置冲突） | room_page.dart | analyze ✓ + 底部面板 6 例绿 ✓ | **已做**（横持/紧凑复检随 P5） |
| P5 | 更多容器：新造 `room/more/room_more_menu.dart`——`showRoomMore` 双形态（≥720 右停靠全高 panel 宽 372、顶让位 56；<720 分区 sheet ≤76% 高；`showGeneralDialog` 滑入、点障碍关），内容=分享圆钮行（shareRoom/copyRoomLink/openRoomExternally/详情）+工具 tile（截屏/录制/画中画/投屏/纯音频/切换房间/新窗口，各按能力门控）+设置行（自动隐藏 1–10 滑杆、清晰度/线路/比例（关容器后走 `roomStreamPickerAskProvider`）、弹幕设置、睡眠定时、快捷键说明（桌面））；入口=右上簇⋯唯一：`roomMenuItems`+`_RoomMenu` 删除，PlayerSurface/顶条参数 `roomMenu/menuItems` 改 `onMore`；撤条上 cast pill（split 簇只留录制/PiP，投屏移容器 tile）；锁定撤 immersive 门槛（`!mini && (_locked‖showBar)`）并删 didUpdateWidget 自动解锁；`RoomStreamPicker` 增 `fit`；死代码清除：room_chat_stream 删（grep 零引用）、chatMode/chatStreamCorner provider+键+refresh 列表清；l10n 增 chatColumnWidth/moreTools/moreSettings | room_page.dart、player_surface.dart、more/room_more_menu.dart（新）、chat_display_settings、settings_refresh、room l10n | analyze ✓（room+test/live 0 issues）、format ✓、grep 零引用 ✓；测试结果见第二十四轮 | **已做**（Esc 关闭于第二十六轮补齐） |
| P6 | 巨石按区拆分（纯移动，Dart `part` 方案——私有名零改名、入口 import 路径不变）：room_chat 1472→入口 222+feed 405+line 460+composer 185+tabs 194；room_page 2031→入口 1468+bar 134+hero 435；player_surface 3297→入口 1501+stage 158+top_bar 452+pickers 196+danmaku 267+pip 295+control_bar 440 | room/** | analyze ✓（room+backup+test/live 0 issues）；测试构建归用户 | **已做**（两入口的巨型 State 类无法跨文件，如实超 500，见第二十五轮） |

每步开工前 `git status` 复查共享文件归属；format 只点本轮改过的单文件；提交按 pathspec、英文信息。

## 禁区与约束

- 不动：录像 lane 文件（recorder_page/recorder_library_pane/recorder_card_parts）、直播设置导航顺序、live_sites 站点包、播放内核/media_core、AppShell。
- 保留：剧场模式（参考没有≠该删）、player_overlay 玻璃浮层标准（全播放页共用）、现有全部功能（零回退）、三停靠点数值、断点现值。
- 主题走现有 token + 玻璃两滑杆策略；舞台恒深色；文案走 slang。
- 运行时验收归用户（analyze 绿即交付，不跑 build/截屏）。

## 进度回填

- 2026-11-12：方案 A 选型确认；交互原型+设计文档 room-ui-spec.html 交付并浏览器实测（七形态/折列/弹层/发送/录制/屏蔽/明暗零报错）。
- 2026-11-12：用户反馈信息条改置顶 ⇒ 宽/常规/紧凑三档身份并入顶栏（与返回/主题/⋮/窗口键同条），视频不再被信息条切高度；原型与本文档同步更新，待复验后进入 P1。
- 2026-11-12：第二轮反馈 ⇒ 控制条定稿底部通栏两端锚定（窄收拢+⋮兜底）；自动隐藏组扩到胶囊/scrim/手势带/PiP条；删「直播中」徽标。原型已更新并复验。
- 2026-11-12：第三轮反馈 ⇒ 补全 19 项控件（含画面比例/倍速/seek/锁定/重试/统计/切房等），按视频宽四档排版 T1–T4，T4 用控件 deck 保证全控件可达；⋮ 收窄为房间级操作。原型已更新并复验。
- 2026-11-12：第四/五轮反馈 ⇒ 否掉单行堆砌与折叠 deck；定稿四个归属家（底部播放行/右上玻璃簇/右侧控制条/页顶栏），右侧控制条宽窗竖条常驻、窄屏单行芯片常驻、沉浸右缘竖玻璃条；零折叠面板。原型已更新并复验。
- 2026-11-12：第六轮反馈 ⇒ 否掉右侧栏；照 B站播放器面板定稿：底部播放行全文字芯片（小屏零图标、关注纯文字），次级进 B站样式「更多」底部 sheet（圆 tile+带字动作 tile+设置行/分段/开关），右上簇仅桌面。原型已更新并复验。
- 2026-11-12：第七轮反馈 ⇒ 控制栏单行不换行：T4 压缩字号/去前缀/去箭头，373px 含回放倍速仍一行；seek 独立栏上方；七形态单行+无横向溢出复验过。
- 2026-11-12：第八轮反馈 ⇒ ① 视频区只留滚动弹幕：删底部浮动聊天（fstrip/开关/pref 计划全撤）、置底展示与醒目入弹幕层；② 平台维度：Windows 窗口全屏（第八形态 winFull，□ 键/全屏▾/更多行三入口）+−□×，macOS 红黄绿，移动端无窗口键；策略表加 Platform 第三维+平台差异表。复验：八形态单行无溢出、顶栏无溢出、winFull 进出/平台切换/全屏▾/mac 绿点/移动全屏流程全过、滚动弹幕仅上区飞行、零控制台报错。
- 2026-11-12：第九轮反馈 ⇒ 更多容器随尺寸分流：舞台≥720=玻璃 panel（右下锚定/点外关闭/内部滚动）、<720=B站 sheet，内容同一套；顺带修 row* 行开弹层后容器 DOM 残留（改 render 再 openOvl）、后台听去重为开关式 tile（删重复开关行、标签不再折行）。复验：wide/theater/phoneLand/regular=panel、compact/portraitFull=sheet，panel 在框内且不压顶栏、tile 高度齐平、audio tile 开关保持容器、Esc/点外/× 关闭、rowq/rowd 正确交接弹层、零控制台报错。
- 2026-11-12：第十轮反馈 ⇒ 常用会话工具放出右上：右上簇=截屏/录制/画中画/投屏/锁定/⋯更多（桌面图标、小屏文字 截屏/录制/更多，全档位），更多唯一入口移右上簇；底部播放行与顶栏撤更多。复验：七形态簇单行且在视频内、与胶囊/聊天退出钮零重叠、T1 六图标/锁定只留解锁、簇开 panel/sheet 正常、录制簇钮红点状态同步、底行仍单行、顶栏无溢出、零控制台报错。
- 2026-11-12：第十一轮反馈 ⇒ 窗口全屏撤出更多（"窗口全屏咋能跑更多去"）：窗口级动作只留标题栏 □ 键与全屏▾ 二选两入口；更多只装会话工具与播放设置。复验：panel/sheet 均无窗口全屏、全屏▾ 二选与 □ 键进出 winFull 正常、窄桌面窗顶栏 □ 键仍在、零控制台报错。
- 2026-11-12：第十二轮反馈 ⇒ 锁定钮移右缘垂直居中（"锁定图标应该在右侧中间位置"，B站 app/腾讯/MX 防误触惯例），撤出右上簇与更多；锁定态唯一残留同位解锁；顺带修 PiP 锁定态解锁钮被 CSS 隐藏、regular 形态漏挂锁定钮。用户批评"没有分析乱设计"⇒ 文档新增「控件落位分析」表：频率×状态×层级三问，逐控件给参考依据（B站 app/web·YouTube·腾讯视频·MX Player）与用户拍板列。复验：七形态锁定钮垂直居中且与簇/胶囊/聊天退出钮/底行零重叠、锁定/解锁/PiP 锁定流程全过、更多无锁定、零控制台报错。
- 2026-11-12：第十三轮（文档一致性梳理，无代码改动）⇒ ① 事实核实：room_page 行数 2083→2082、巨石总计 9,548→9,545；`room_chat_stream` 零引用成立、`chat_splitter` 仅 huya 在用（P5 结论维持）、断点 840/600 与代码 `kRoomWideBreakpoint`/compact 一致、横持 480/280 与 `_phoneLandscapeMaxHeight`/`_phoneLandscapeChatWidth` 一致。② 五区表修正：截屏/录制/PiP/投屏归右上簇（第十轮口径补齐）、锁定归右缘（第十二轮口径补齐）、「更多」唯一入口改右上簇（撤页头 ⋮ 旧口径），互动区补常规/横持/剧场归属。③ 策略表修正：控制条「视频底浮层」→底部通栏口径；次级动词 ⋮→右上簇「更多」；PiP 次级动词→全量在条；PiP 身份→隐藏(仅标题条)；横持右上簇→文字 3 芯片。④ 缺口补齐：TV 枚举留位说明（`Env.isTv` 仅壳层、room 无 TV 分支，TV 焦点/10ft 另立任务）、锁定挂起手势作用域、音量 T1–T4 分档、横持"单列"矛盾更正为双列。⑤ 样张同步修正（见样张同日记录）。
- 2026-11-12：第十四轮（样张排版/UI 优化，无规格变更）⇒ 控制台参数分五组（形态·平台/控件布局/弹幕/外观·主题/状态模拟）；「控件位置」卡片长文改八项要点网格（顺带修正残留的"锁定小屏进更多面板"旧口径）；策略表加斑马纹+悬停高亮；视频内设计标注 .an 半透明模糊化（与真实 UI 区分）；竖屏全屏身份胶囊 max-width 70%→60%（消除与右上文字簇碰撞）；三停靠点提示字号 9→10；补 `data-zcode-design` 标记（浏览器设计工具可拾取元素）。div 配平与 JS 绑定 ID 经脚本核验，浏览器渲染复验归用户。
- 2026-11-12：第十五轮（用户提供 4 张 B站参考图：app 竖屏 sheet/web 宽屏更多面板/手机横屏全屏/web 直播页；要求先做显示排版分析再定方案）⇒ ① **全屏+窗口全屏同行**（用户点名）：底行最右改「全屏｜窗口全屏」同行双芯片（仅 Windows 显示后者，T4 压缩为「窗口」），删除全屏▾ 二选弹层，标题栏 □ 键保留；② **大屏更多容器改右列全高面板**（AskUserQuestion 用户拍板，照图2 B站 web）：覆盖聊天列、顶随顶栏高度避让、点外关闭/Esc、内部滚动，圆 tile 统一网格 5 列（分享 4+工具 7）；③ **小屏 sheet 照图1 分区分组**：「分享/工具/设置」小节标签+圆 tile 行+工具圆 tile 网格（tile 由方圆角统一为圆形 46px）；④ 小屏右上簇保持「截屏/录制/更多」（AskUserQuestion 用户拍板，不改 B站 分享+⋮）；⑤ 顺带修正 md 第十二轮漏改：「更多」tile 清单里的「锁定」移除。已确认不变项：底行只放播放动词、锁定右缘、更多入口右上簇唯一、内容同一套容器随尺寸。样张与台账同步更新；渲染复验归用户。
- 2026-11-12：第十六轮（真实代码现状审查，双探索代理 + 人工复核，无代码改动）⇒ 审查 room_page/player_surface/room_controller/room_chat 及 shared/player 现状并回填「现状审查」节：①差距定位——身份散 5 处（AppBar 仅标题）、控制条非通栏、⋮ 固定下拉、**宽窗普通态无截屏/录制/PiP/投屏入口**（_PlayerTopBar 仅 immersive 显示）、聊天拖拽零接线（ChatSplitter+chatPanelWidthProvider 已就绪无消费方）、竖屏全屏无聊天入口、锁定仅 immersive；②好消息——断点 840/600/480/280 与设计全一致、三停靠点面板已存在且数值相同（6 例测试锁定）、锁定位置已是右缘垂直居中、弹幕设置面板四滑杆已与设计一致、全屏/窗口全屏已相邻（仅差图标→文字与撤 720 门槛）、TV 分支已存在可映射枚举；③事实修正——「直播中」徽标代码本无（P3 该项作废）、回放倍速可行（media_core adapter 已暴露 setRate，不动内核）、护栏仅 room_bottom_panel_test 6 例（新增 P0 补断点护栏）；④roomMenuItems 六项去留定案（切房/独立窗口→工具 tile，睡眠/快捷键→设置行，画质线路/投屏撤重复）；⑤P1-P6 全部挂上行号锚点并新增 P0。方案已达可开工状态，等用户确认后进入 P0/P1。
- 2026-11-12：第十七轮（用户反馈"越改越差"，点名组件排版重定）⇒ ① **底行双簇**（用户逐项点名）：左簇=播放暂停·刷新(常驻重连)·声音·弹幕（弹幕从右簇移左、设置齿轮撤条归更多设置行）；右簇=清晰度(原"画质"更名贴B站)·线路·画面比例·倍速(回放)·窗口全屏·全屏，两端锚定；② **右上簇改成员**：截屏/录制/画中画/更多（投屏撤出簇归更多 tile，此前为第十轮五件套）；③ **顶栏瘦身**（用户："标题加分区等太长了"）：删「标题—分区」，改两行=名字+认证／观看数·已播时长，标题分区只在详情面板+全屏胶囊展开出现；④ 音量统一为图标=静音切换（T1 加滑杆），撤小屏音量弹层（手势/滚轮/键盘已覆盖）；⑤ 样张内 8 处规格表格/要点网格同步，md 五区表/控件清单 1/2/4 同步。同步项：错误态重试与刷新共用（错误时刷新钮隐藏避免重复）。待浏览器复验后同步到实现方案 P3 锚点描述（_ControlBar 控件清单同步该双簇顺序）。
- 2026-11-12：第十八轮（用户纠正："是优化不是把标题分类删掉"，要求重新设计归属而非删除）⇒ 标题/分区回归并重新定家：① 宽/常规顶栏改两行——第一行「名字+认证+分区小徽章（chip，短文本正好）」、第二行「标题独占（省略号兜底+悬浮显全文+点击打开房间详情）」，观看数·已播移回右侧独立数据区（不再挤占身份行）；② 紧凑竖屏=底面板顶部新增信息条（标题省略+分区徽章），对齐 B站 app「标题在视频下方」惯例；③ 全屏/横持胶囊展开与 PiP 标题条维持原样；④ 实现 P2 映射更新：_ChatRoomHeader(L1539) 的 标题/分区 信息并入 RoomIdentityBar 两行结构，分区渲染为 chip。教训记录：信息删除前必须先找到新家，「显示过长」的解法是分层与省略，不是移除。
- 2026-11-12：第十八轮补充（用户拍板）⇒ 删掉名字旁的认证 ✓ 徽章（无信息量）：顶栏/全屏胶囊/详情面板三处同步移除；实现映射：RoomIdentityBar 不含认证徽章。
- 2026-11-12：第十九轮（用户纠正："大屏标题应放直播左上角""别我说啥改啥，认真设计"）⇒ 标题的归属按观看语境系统化定家：① **内联大屏（宽/常规/窗口全屏）=视频左上玻璃条**——省略号兜底、悬浮显全文、点击开详情、跟随控件自动隐藏组、锁定态消隐；② 顶栏回归**单行**（名字+分区 chip｜观看·已播数据区｜关注+系统键），第二行删除；③ 紧凑=面板信息条维持、全屏/横持=胶囊展开维持、PiP=标题条维持。**设计原则沉淀：标题的"家"随观看语境变化——内联贴画面、全屏进胶囊、小屏贴视频下方；页面 chrome 只管身份与动作，不承载内容说明。** 实现映射更新：P2 RoomIdentityBar=单行（名字+分区），标题条归 P3 舞台层（PlayerSurface 内新增、跟随 controlsAutoHideSeconds），宽窗普通态因此获得标题可见性（此前无）。
- 2026-11-12：第二十轮（用户明确"标题栏第二行放名字+分区"）⇒ 视频左上标题栏定稿为**两行堆叠**：第一行=标题（省略·点击开详情），第二行=名字+分区徽章（无头像）；顶栏=纯系统条（返回+观看·已播+关注+分享/详情/主题/折叠/窗口键），不含身份。紧凑形态维持原样（顶栏名字+面板信息条标题分区）。实现映射：PlayerSurface 新增 vhead 双行玻璃条（宽/常规/窗口全屏），跟随 controlsAutoHideSeconds 与锁定消隐。
- 2026-11-12：第二十轮修正（用户严正纠正："是在标题栏，不是视频左上方"）⇒ 撤销视频左上叠层（vhead 全部移除，残留 grep=0），**最终定稿：页面标题栏两行**——行1=标题（省略·悬浮全文·点击开详情）、行2=小头像+名字+分区徽章；右侧观看·已播数据区与动作簇（关注/分享/详情/主题/折叠/窗口键）垂直居中；视频画面左上保持无叠层。紧凑维持单行。实现映射更新：RoomIdentityBar 两行结构置于 AppBar 内，AppBar 高度维持 64/56，`WindowDragArea` 包整条。教训补记：位置类反馈中的歧义词（"标题栏"=页面顶栏，而非标题条）必须在动手前用一句话复述确认，不再靠猜。
- 2026-11-12：第二十一轮（用户给出明确终稿）⇒ 顶栏重设计定稿：**顶栏=头像＋两行（行1 主播名、行2 平台·类型）**，右侧关注+系统键；**大屏视频左上=标题+观看·已播 双行玻璃条**（vhead，跟随自动隐藏/锁定消隐）；**小屏=标题+观看·已播 放入面板房间信息条**（pinfo，B站 app 标题在视频下方惯例）；胶囊行2 改平台·类型、展开补观看·已播；A/B/C 顶栏切换器按约删除（选择器/绑定/状态位全清，残留 grep=0）。实现映射：RoomIdentityBar=头像+主播名/平台·类型两行；PlayerSurface vhead=标题/数据两行；紧凑 RoomBottomPanel pinfo=标题/数据。校验：JS 语法 ✓、div 296/296 ✓、残留 0 ✓、浏览器截图确认 ✓。
- 2026-11-12：第二十三轮（代码实施第二阶段：P4 + P3e）⇒ ① **P4 竖屏全屏聊天可达**：`_buildPortraitFullscreen` 增聊天面板——`_portraitChatOpen` 状态（离开竖屏全屏自动复位）、下方 62% 玻璃面板（`RoomGlassCard`+`RoomChatPanel(translucent)`，把手 tap/下滑关闭）、开门 pill（`DsIcons.messageCircle`+`t.room.expandChat`，置于还原区上方，用 tap 而非手势以免与聊天设置互斥）；② **P3e replay 倍速**：控制条右簇增倍速文字芯片（循环 1.0/1.25/1.5/2.0，`PlayerHandle.setRate`，引擎拒绝时按 hongguo 先例吞错并保持所请显示；rate 读取 `handle.rate`，芯片只在 replay 房间出现）；MediaBarButton 是纯图标按钮（label 只作 tooltip），故芯片用 `_StreamPickerRow` 的文字+描边写法。验证：room+test analyze **0 issues**、护栏+底部面板 **13/13** 全绿。**未做**：P5 更多容器、P6 拆分；运行时验收归用户。
- 2026-11-12：第二十四轮（代码实施第三阶段：P5 更多容器 + 死代码收尾）⇒ ① **新造 `room/more/room_more_menu.dart`**：`showRoomMore` 双形态容器（≥720 右停靠全高 panel 宽 372 顶让位 56；<720 分区 sheet ≤76% 高；showGeneralDialog 滑入、点障碍关、barrierLabel=更多），内容=分享圆钮行（分享/复制链接/外部打开/详情）＋工具 tile（截屏 canCaptureScreenshot 门控/录制/画中画 pipAvailable 门控/投屏 lines 门控/纯音频/切换房间/新窗口 offersRoomWindow 门控）＋设置行（自动隐藏 DsSlider 1–10、清晰度/线路/比例行先 pop 再走 roomStreamPickerAskProvider（`RoomStreamPicker` 增 `fit`）、弹幕设置走 SettingsSectionRoute、睡眠定时、快捷键说明仅非手机）；② **入口收口唯一**：PlayerSurface/顶条 `roomMenu/menuItems` 参数改 `onMore`，`roomMenuItems`+`_RoomMenu`（~120 行）删除、DsMenuAnchor 两挂载撤除；③ 条上 cast pill 撤除（split 簇只留录制/PiP，投屏在容器 tile 可达）；④ 锁定撤 immersive 门槛（`!mini && (_locked||showBar)`）并删 didUpdateWidget 自动解锁；⑤ **死代码清除**：room_chat_stream.dart 删（grep 零引用）、chatMode/chatStreamCorner provider+键清、补漏：backup_settings 两条死备份项（danmaku.chatMode/chatStreamCorner）与 settings l10n 10 对死键（chatPresentation*4+chatStreamCorner*6，均 grep 零 dart 引用）删除、slang 重生成；room l10n 增 moreTools/moreSettings。验证：analyze（room+features/backup+test/live 作用域）**0 issues**（最终状态）、format ✓、grep 残留 0、lan_sync_scopes_test 6/6（backup 删除影响面）；**test/live 全量未在最终状态执行（按用户指示测试构建归用户自行执行；此前房间代码终态快照为 105/105）**。**未做**：P6 拆分；Esc 关容器未接（遗留 P6 顺带）；运行时验收归用户。
- 2026-11-12：第二十五轮（代码实施第四阶段：P6 巨石拆分收尾）⇒ ① **方案**：Dart `part` 纯移动——三巨石转库+part 文件，私有名零改名、入口 import 路径与公开 API 不变（`RoomChatPanel`/`chatSeenEmotesProvider`/`RoomPage`/`followsRoomProvider`/`PlayerSurface`/`PictureActionButton`/`kPlayerStageColor`/`RoomStreamPicker`/`roomStreamPickerAskProvider`/`roomRecordingTaskOf`/`toggleRoomRecording`/`toggleRoomPip` 均保持入口可见）；不用 import+公开化改名，避免把 30+ 私有类泄进模块 API；② **room_chat 1472→5 文件**：入口 222（枚举+emotes provider+面板）、room_chat_feed 405（_chatStateArea+_ChatFeed）、room_chat_line 460（_ChatLine/_ChatName/_ChatHover/墨色三 helper/_giftOf/_superChatPrice/_SenderTag）、room_chat_composer 185、room_chat_tabs 194（noticeBar+superChat+shield）；③ **room_page 2031→3 文件**：入口 1468（RoomPage+State）、room_page_bar 134（followsRoomProvider+_roomAppBar+_FollowPill+_ChatColumnToggle）、room_page_hero 435（hint+列头+hero+_Elapsed+_SleepChip）；④ **player_surface 3297→7 文件**：入口 1501（_openReplays+墨色常量+PictureActionButton+PlayerSurface+State+_veilOf）、stage 158（backdrop/ambient 三件+_PictureDrag）、top_bar 452（caption+_uptimeText+顶条+State+_AnchorFollowChip）、pickers 196（_StreamPickerRow+枚举+ask provider+_lineShortLabel/_lineDetail）、danmaku 267（弹幕簇+设置面板+录制/PiP 公开动词+_NarrowRecordingUnderMenu）、pip 295（_PresentationCluster+_PipBar/_PipButton）、control_bar 440（控制条+State+_BarDivider+_IdleWakeStrip+_RestoreSwipe）；⑤ **偏差如实**：两入口文件超 500（1468/1501）——`_RoomPageState`（~1380 行）与 `_PlayerSurfaceState`（~1220 行）在 Dart 里类体不可跨文件，再拆需把方法组提炼为新类（超出纯移动口径，未做，另立任务）。验证：`dart format` ✓、analyze（room+features/backup+test/live）**0 issues**；**测试与构建按用户指示归用户执行**（此前三轮快照：护栏 7 例+底部面板 6 例+test/live 105/105 均在拆分前的代码态）。**至此 P0–P6 全部完成**；运行时验收归用户。
- 2026-11-12：第二十六轮（P5 遗留补齐：Esc 关闭更多容器）⇒ `room_more_menu.dart` 增 `_RoomMoreEscape`——`CallbackShortcuts`+`SingleActivator(LogicalKeyboardKey.escape)`→`Navigator.pop`，`Focus(autofocus: true)` 保底持焦；焦点落入 tile 后快捷键仍在其子树生效（键事件冒泡至最近含绑定的祖先）；showRoomMore 文档口径同步为"barrier tap or Escape to close"，panel/sheet 两形态同享。验证：format ✓、room analyze **0 issues**；运行时验收归用户。**余项**：两入口巨型 State 类的方法组提炼（>500 偏差修正，行为级重构，另立任务待确认）。
- 2026-11-12：第二十七轮（P1 收尾：policy 表全量收编）⇒ room_page 构建分支改读布局状态机——撤手算 `landscapePhone` 公式与 assert 桥，`landscapePhone`/`wideWindow` 直接取 `RoomLayout.resolve` 的 `landscapePhone`/`windowClass`（等值改写：`!landscape && width≥840` ≡ `class==wide && !landscape`）；`_phoneLandscapeMaxHeight` 常量随公式删除（机械值由 `kRoomLandscapeMaxHeight` 与护栏测试钉住）；内容盒级 `wide` 复查（`constraints.maxWidth`，聊天列吃宽后的再判定）保留，属内容度量非窗口度量，机器不越权。验证：format ✓、analyze（room+test/live）**0 issues**。**State 提炼评估结论（第二十六轮余项）**：入口行数地板=imports+widget(~280)+字段+生命周期(~200)+build 体(room_page 510/player_surface 577)；仅搬 helper 组（可编译验证）→入口仍 ~900-1050 超 500，不付；达标须分解 build 闭包为带参 mixin 方法——转写风险真实存在而 test/live/运行时验收尚未在用户手里执行，**决定冻结代码待用户验收**；分解方案保留（分段带参提炼，编译器可查类型、运行时需回归），验收通过后按需另启。
- 2026-11-12：第二十八轮（用户运行时反馈"实现与设计稿 UI/行为/布局不符"⇒ 全量重审计 + 差异修复第一、二批）⇒ ① **重读设计原型全文（1263 行 CSS+HTML+JS），逐区审计得差异表 A–G**：A=内联视频右上应为单一悬浮玻璃簇（截屏/录制/画中画/⋯，窄屏文字芯片 截屏/录制/更多），实现却是分散 pill 行（音频+截屏+录制/PiP+⋯+折列主播芯片）；B=全屏/剧场身份应为玻璃胶囊（头像+名+平台·分区+关注+展开→标题/观看/已播/分享/详情）+右上文字钮（聊天/退出），实现是全宽渐变身份条；C=控制条应全文字芯片（弹幕文字开关、齿轮撤条、窗口全屏/全屏文字、T1=≥960 全标签+音量滑杆），实现是图标混合+齿轮；D=紧凑应为 拖手柄+pinfo 信息条（标题+观看·已播）+tabs+三停靠，实现是旧 _ChatRoomHeader 卡；E=更多面板应为玻璃+「更多」标题栏+X，工具 tile=截屏/录制/小窗/投屏/**统计**/切房/后台听，自动隐藏=分段；F=PiP 条应全量图标（17 键）+左上标题条；G=页顶栏缺分享钮、紧凑顶栏多按钮。根因：实施时只对齐了"簇成员归属"，外壳沿用了旧组件形态，analyze 绿不验形状；② **修复 A（落地）**：新增 `_TopToolCluster`（top_bar part）——玻璃 pill 一枚、DsIcons.ellipsis（水平 ⋯ 合原型 i-more）、录制态 danger 红、窄图(<460)文字芯片且撤画中画；内联挂载替换 `_PlayerTopBar`（后者仅余 immersive/tv/onTitle 形态，identity 参数与 false 分支、`_PresentationCluster.split` 分支随死代码清除；音频 pill 撤出视频顶（更多 tile 仍可达）、折列主播芯片撤（身份在页顶栏常驻）；`_NarrowRecordingUnderMenu` 迁 top_bar part）；③ **修复 C（落地）**：新增 `_BarChip`（控制条文字芯片：icon/svg+可选文字+selected+dimmed+TV 焦点环）；弹幕=文字芯片（弹幕/弹幕 关，关态变暗，**齿轮撤条**——`onDanmakuSettings/danmakuSettingsAnchor` 参数、State 的 `_danmakuSettingsOpen/_danmakuSettingsAnchor/_toggleDanmakuSettings/_closeDanmakuSettings`、PopScope 分支、条上弹幕设置浮层全部移除，设置走更多面板的弹幕设置行→弹幕样式页；danmaku part 两组件删除、录制/PiP 公开动词迁 pip part）；窗口全屏=文字芯片（选中态 tint）、全屏=文字芯片（原型无 on 态）；播放/重试 T1(≥960) 图标+文字；音量滑杆 720→**960**（T2 不出滑杆，第十三轮口径）；l10n 增 danmakuChip/danmakuChipOff/fullscreenChip（中英）；④ **刻意差异（记账）**：更多面板的弹幕设置行维持"跳弹幕样式页"（原型为画内快捷滑杆面板+高级按钮跳页，快捷面板暂不建页级宿主，后续可补）；验证：format ✓、analyze（room）**0 issues**；测试/构建归用户。**余项**：B 胶囊、D 紧凑 pinfo、E 更多面板材质/标题栏/tile/分段、F PiP 全量条、G 顶栏分享+紧凑顶栏精简（按此顺序续作）。
- 2026-11-12：第二十九轮（差异修复第三批：B 全屏/剧场/横持/竖屏全屏身份胶囊）⇒ ① **`_PlayerTopBar` 收敛为 TV 专属**（top_bar part）：构造裁至 `{room,onLeave,onWake,onMore,endInset}`，fullscreen/portraitExit/onTitle 参数与对应分支删除，返回 pill 恒显（t.common.close）；文档注明其余沉浸形态改画胶囊+工具簇（gcap/tcluster）；② **新 `_ImmersiveCapsule`**（top_bar part）：玻璃 pill=头像(DsAvatar sm)+主播名/平台·分区两行+关注钮（未关注=accent 底、已关注=onVideo 悬浮底，heartCrack/heart 图标，同 TV 条 _AnchorFollowChip 口径）+chevronDown/Up 展开钮；展开行（.xtra）=标题 · 观看数 · 已播 · 分享(下划线链接→shareRoom) · 详情(下划线链接→showRoomDetails)，Text.rich+WidgetSpan，maxLines 2 省略；身份半区按压=onTitle（横持房间卡移交）否则 showRoomDetails；ConstrainedBox(maxWidth 420) 对应原型 .gcap max-width 60% 封顶；③ **新 `_ModeExitChip`**（top_bar part）：玻璃文字钮（gbtn 退出），标签按形态=退出全屏/退出窗口全屏/退出竖屏全屏/退出剧场，onPressed=widget.onLeave（room_page `leave()` 先退模式后退房间，与原型 exitfull 同义）；④ **入口挂载重构**（player_surface.dart）：`capsuleIdentity = !tv && (immersive || portraitFullscreen || onTitle != null)` 局部；内联形态（vhead 标题条+悬浮簇）与胶囊形态互斥；胶囊形态挂左上胶囊(top:12/start:12)+右上列（退出芯片+悬浮簇，spacing s4，对应原型 tcluster 落 top:54）；TV 保留全宽顶条；`room_details.dart show shareRoom` import 补入；⑤ **刻意差异（记账）**：原型沉浸形态右上文字钮含「聊天」（剧场开覆盖抽屉/竖屏全屏开底部面板），实现暂无聊天抽屉回调且剧场聊天抽屉为既有缺口，本批不挂聊天钮，待抽屉功能另立任务一并补。验证：format ✓、analyze（room）**0 issues**；测试/构建归用户。**余项**：D 紧凑 pinfo、E 更多面板材质/标题栏/tile/分段、F PiP 全量条、G 顶栏分享+紧凑顶栏精简。
- 2026-11-12：第三十轮（差异修复第四批：D 紧凑拖手柄+pinfo 信息条+三停靠）⇒ ① **停靠几何升为共享 API**（room_bottom_panel.dart）：`_Stops`→公开 `RoomPanelStops`，`_stops/_stopOf/_target/_entersFullscreen` 提为 `RoomBottomPanel.stopsOf/stopOf/nearestStop/entersFullscreen` 公有静态（sheet 私有方法改委托，行为零变化，guard 测试面不变）；② **新 part `room_page_compact.dart`**：`_CompactRoomBody`（fCompact 堆叠形态）=Expanded 画面（吃面板余高，AspectRatio 保形）+grip 拖手柄行（48px 触达行+38×4 圆条，垂直拖 120–greatest）+面板（动画 spring 与 sheet 同源）=pinfo+Expanded(chat)+stops 行；松手=最近停靠（甩动优先），拉穿最低档（距离≥clamp(30%·least,72,144) 或 900fling+28px）→竖屏全屏（与 sheet 同一 `entersFullscreen` 语言）；旋转/缩窗时钳回最近档；`_RoomPanelInfo`（pinfo）=标题（省略+悬浮全文 tooltip+点击详情+hover accent）+tstat（**观看数** 观看 · 已播 **_WatchedClock**，数字 w700，逐秒走字），单行 6/12 padding+底描边；`_PanelStops`=停靠：250px/44%/68% 三芯片（当前档 accent 描边+加粗，点击落档）+「· 拉穿最低档进竖屏全屏」提示，Wrap 防窄溢出；③ **接线**：紧凑堆叠分支（非竖屏流/compatibility）旧 `picture+SizedBox+maxPicture/desired 手算` 全撤换 `_CompactRoomBody`；**竖屏 sheet 面板头 `_RoomHero` 大卡→pinfo**（第二十一轮"小屏=pinfo"定稿落地，身份在页顶栏、标题数据在面板头、聊天多得一卡高度）；④ **死代码清除**：`_RoomHero`+`_Elapsed`+`_SleepChip` 删（sheet 头换 pinfo 后零引用），`_ChatRoomHeader` 撤 `hoverStats` 参数与 false 分支（紧凑用途已不存在，宽列 hover figures 恒开），`showRoomSleepTimer` 撤出 room_page import show 列表，room_page_hero 435→176 行；⑤ **l10n**：room 增 panelStops（停靠：/Stops:）+panelStopsHint（拉穿最低档进竖屏全屏/Pull past the lowest stop for portrait full screen），statWatched zh 已观看→**已播**（对齐原型 gcap xtra 与 pinfo 同词），slang 重生成。验证：format ✓、analyze（room+test/live）**0 issues**；测试/构建归用户。**余项**：E 更多面板材质/标题栏/统计tile/隐藏分段、F PiP 全量条、G 顶栏分享+紧凑顶栏精简。
- 2026-11-12：第三十一轮（差异修复第五批：E 更多面板玻璃+「更多」头部+统计 tile+自动隐藏分段）⇒ ① **容器材质**：panel/sheet 的不透明 surface→`RoomGlassCard` 磨砂玻璃（`RoomGlassCard` 增可选 `borderRadius` 覆写：panel 停靠右缘、仅 start 侧圆角，对齐原型 `morepanel` 14px 单侧圆）；**panel 头部 `.ph2`**=「更多」(w800)+关闭 ✕（新 `_CloseButton`，30×30 hover 亮，pop），头部下描边分隔，面板体内滚（旧版无滚动、短窗溢出风险顺带修复）；sheet 保持把手无头部（原型 sheet 口径），分组标签按原型口径 panel 隐、sheet 显（`_RoomMoreContent(labeled:)`）；② **工具 tile 对齐原型 fCompact 七件**：截屏/录制(录制中变体)/小窗播放/投屏/**播放统计**/切换房间/后台听——**统计 tile 新增**（DsIcons.gauge，handle 门控，pop 后翻 `playerStatsVisibleProvider`；**房间画面新挂 `PlayerStatsOverlay`**（其余四个播放页早已挂、房间漏挂——右上图层，非 mini），provider 文档纠正「I 键」说法为 tile 入口）；**新窗口 tile 删除**（offersRoomWindow 判定、roomPlaylistProvider import、openRoom 调用随之清）——记账：新窗口本为第十三轮房间菜单迁移项，原型 morepanel 七件无它；独立窗口仍可从详情面板/其他入口到达则路径不变，若原型口径为唯一口径需用户验收确认；③ **自动隐藏=分段**：更多面板滑杆行→`_Seg` 分段芯片（`.sg`：常显/2s/4s/6s/10s，当前值 accent 底 w800；滑杆遗留的中间值不高亮直至点选）——**配置域扩容**：`kControlsAutoHideSecondsMin` 1→**0**（0=常显，set 控件 doc 同步），player_surface `_scheduleHide` 0 时不启定时器，设置页滑杆 detail 0 显「常显」（新增 settings.controlsAutoHideAlways 中英），双入口共用同一 provider 永不一致；④ 面板宽 372/顶部让位 56 维持（原型 360/顶栏高差为像素级差异未改）。验证：format ✓、analyze（room+features/settings）**0 issues**；测试/构建归用户。**余项**：F PiP 全量条+标题条、G 顶栏分享+紧凑顶栏精简。
- 2026-11-12：第三十二轮（差异修复第六批：F PiP 全量图标条+顶部标题条）⇒ ① **`.piptitle` 标题条**（新 `_PipTitle`）：左上 dark scrim 圆 pill（scrimDeep+pill 圆角），「主播名 · 标题(12字截断…)」，strip 可拖窗（`startDragging`，吃掉原本落在画面上的拖拽）+双击还原，对齐原型 top:8/left:10；② **`.pipbar` 全量图标条**（`_PipBar` 改 stateful）：28px 渐变条→**36px 玻璃条**（shade 渐变+顶描边，对齐原型 height:36/glass/border-top），**移到画面底部**（旧实现竟挂 top:0）；按钮列表（解锁态 13 键，顺序照原型）：播放/暂停、静音切换、倍速(仅回放，`_PipSpeedChip` 循环 1.0/1.25/1.5/2.0，与控制条芯片同语言)、弹幕开关（切 `miniDanmakuVisible`，关态变暗）、截屏（canCapture 门控）、录制（录制中 danger 红）、定时（showRoomSleepTimer）、后台听（on 态 accent）、切房（showRoomSwitcher）、**统计**（翻 `playerStatsVisibleProvider`，**统计浮层撤 mini 排除**——PiP 窗内也可显示，其余四个播放页同款）、锁定、返回应用、关闭；**锁定态只余解锁键**（原型 fPip locked 口径）；窄窗横向滚动（原型 overflow-x: auto）；`_PipButton` 增 lit/danger/dim 三态墨色；`_toggleLock`/`_locked` 接入（PiP 窗内锁定与主窗各自独立 State，窗内自洽）；拖手柄图标与空档拖拽撤除（画面本身就是拖拽面，见 onPanStart mini 分支，条上不再重复）。**记账偏差**：画质/线路/比例三拾取与弹幕设置（齿轮）不进 PiP 条——ask 通道指向主窗拾取器（画中画窗按了会开在主窗），设置页整页也不宜渲染进小窗，需窗内拾取器宿主另立任务；PiP 内 seek 条（原型 pipseek，仅回放）同属该任务。验证：format ✓、analyze（room）**0 issues**；测试/构建归用户。**余项**：G 顶栏分享+紧凑顶栏精简。
- 2026-11-12：第三十三轮（差异修复第七批：G 顶栏分享+紧凑顶栏精简，**A–G 审计修复收官**）⇒ ① **分享钮补入页顶栏**（新 `_ShareButton`，room_page_bar part）：`_roomAppBar` actions 在详情键前插入 share（`DsIcons.share`→`shareRoom`，detail 门控，tooltip 底出）——原型 sys 组头即分享；② **紧凑顶栏精简**：`width < kRoomCompactBreakpoint(600)` 时 actions 只留 关注 pill + 窗口键（ownChrome 桌面才有），分享/详情/主题/聊天列折叠全部撤出——原型 compact topbar 口径（`compact?'':sys`），这些动词的既有家：分享/详情在更多容器（分享圆钮行/详情行）、pinfo 标题点击亦开详情、主题在设置；`_ChatColumnToggle` 维持自折（<840 已不显示）。验证：format ✓、analyze（room+test/live）**0 issues**；测试/构建归用户。**至此第二十八轮差异表 A–G 全部落地**：A 悬浮工具簇、B 身份胶囊+退出芯片、C 控制条文字芯片、D 紧凑 grip+pinfo+三停靠、E 更多面板玻璃+头部+统计+分段、F PiP 全量条+标题条、G 顶栏分享+紧凑精简；遗留记账：剧场聊天抽屉（B/E 均涉及）、窗内拾取器（F）、横持语义（原型 tcluster 落位）、主题色 tile/倍速分段细节、PiP seek。运行时视觉验收与测试构建归用户。
- 2026-11-12：第三十四轮（A–G 后续优化第一批：剧场聊天抽屉 + PiP 窗内拾取器 + 统计快捷键 + 回放倍速分段）⇒ ① **剧场聊天抽屉**（第二十九/三十一轮记账项落地，原型 fTheater `.chat.glassy`）：新 part `room_page_theater.dart`——`_TheaterChatDrawer` 玻璃列沿窗口右缘满高（`RoomGlassCard` 仅 start 侧圆角，宽=聊天列宽设置 clamp(280, 窗宽 44%)），内容=`RoomChatPanel(translucent)`，tab 行尾挂 ✕（`trailing` 参数，该参数本为剧场列而设）；页面 `_theaterChatOpen` 状态（`PresentationMode.fullscreen` 即剧场 ownsWindow 分支 Stack：画面+scrim(0x59 黑，点外关)+抽屉；离开剧场自动复位；Esc 先关抽屉再退模式）；**PlayerSurface 增 `onChatDrawer/chatDrawerOpen` 参数**，沉浸右上列（gbtns）增「聊天/收起聊天」文字钮（复用 `_ModeExitChip`，文档泛化为 gbtn 文字钮），仅在页面有抽屉可开时出现——B/E 批的「聊天钮依赖抽屉缺口」就此闭合；窗口全屏（winFull）无抽屉（原型口径）；② **PiP 窗内拾取器**（第三十二轮记账项落地）：`_PipBar` 增 画质/线路/比例三枚 `DsMenuAnchor` 菜单钮（`_PipMenuButton`，当前项打勾）——`selectQuality/selectLine/setFit` 直连控制器，不走指向主窗的 ask 通道；统计钮图标 gauge→**activity**（与其他播放页一致，gauge 让位画质）；③ **统计 I 键**：`RoomShortcutAction.stats`+KeyI 绑定（非 TV），帮助表同步出行，兑现 provider 文档口径；④ **更多面板回放倍速分段**：`_Seg` 泛型化（`T extends num`），设置区首行增倍速 seg（0.75/1.0/1.25/1.5/2.0/3.0×，仅回放且 handle 在，原型 moreInner 同款，与控制条倍速芯片同一 setRate）。验证：format ✓、analyze（room）**0 issues**（每步均绿）；测试/构建归用户。**余下记账**：PiP seek 条（窗内拾取器宿主已有，seek 属回放域另议）、横持 tcluster 落位核对、主题色 tile。
- 2026-11-12：第三十五轮（A–G 后续优化第二批：PiP 回放时间线 + 横持退出钮纠偏，**后续优化项全部清零**）⇒ ① **PiP 回放时间线**（第三十二轮记账项落地，原型 `.pipseek`）：新 `_PipSeek`（pip part）——位置/DsSlider/时长三段行（44px 数字标签，vod 页同款 idiom：拖动即显指尖秒位、松手 `handle.seek`），挂画面 bottom:42（图标条上方 6px），`_PipBar` 增 `transport` 参数（表面 State 的 `_transport` 快照透传）；显示条件=回放（isRecord 或 非直播且有时长）且未锁定，与控制条 seekLine 同判据；② **横持退出钮纠偏**（"横持 tcluster 落位核对"的发现）：普通态胶囊形态=手机横持，退出芯片此前误标「退出剧场」（theaterOff 的 `_` 兜底），改 `t.common.close`（横持不是演示模式，动词就是关房间——`onLeave` 在普通态=路由退出，标签与行为自此一致；竖屏全屏分支保留 portraitFullscreenExit）；③ "主题色 tile" 记账注销：核对原型 moreInner/sys 组，主题钮家在页顶栏 sys 组（第三十三轮 G 已交付 `ThemeModeToggle`），更多面板本无主题 tile，系笔记误差。验证：format ✓、analyze（room）**0 issues**；测试/构建归用户。**至此台账所有已知差异与记账项全部闭环**；运行时视觉验收与测试构建归用户。
- 2026-11-12：第二十二轮·续（P3 余项）⇒ ① **P3c 聊天列可拖**：`ChatSplitter` 接入宽窗分支（`columnWidth` 改读 `chatPanelWidthProvider`，拖拽 preview/松手 set/双击复位 340；上限仍 `columnMaxWidth`）；l10n 增 `chatColumnWidth`（中英）并 `dart run slang` 重新生成；② **P3d 右上簇收口**：更多 pill 不再按 immersive 门控（`menuItems: widget.roomMenu` 恒传，内联右上有了唯一更多入口）；投屏撤出内联条（split 簇仅录制/PiP，投屏在 ⋮ 菜单可达，零回退）；③ scrim/两端锚定复核为现状已有，记账不改。验证：room+test analyze 0 issues、测试 105/105 全绿；全仓 analyze 仅 1 条 iptv 存量 info（该文件非本轮触碰；工作区另有用户并行的 iptv/live_iptv/live_storage 改动，与本轮无关、未触碰）。
- 2026-11-12：第二十二轮（代码实施第一阶段：P0+P1+P2+P3a/P3b）⇒ ① **P0**：`test/live/room_layout_guard_test.dart` 7 例（840/600 分界、横持旗标、桌面短窗），全绿；② **P1**：新建 `room/layout/room_layout.dart`（kRoomWideBreakpoint=840/kRoomCompactBreakpoint=600/kRoomLandscapeMaxHeight=480 + RoomWindowClass 枚举 + `RoomLayout.resolve` 工厂），room_page 常量改为委托（`_wideBreakpoint`/`_phoneLandscapeMaxHeight`）、构建入口接 `RoomLayout.resolve`（assert 桥接校验一致），原公开常量名由导入供给；③ **P2**：新建 `room/identity/room_identity_bar.dart`（头像 live 环 + 两行主播名/平台·类型，骨架占位防跳动），`_roomAppBar` 重写：高度 ≥56、title=RoomIdentityBar（ownChrome 时 WindowDragArea 包裹）、actions 增 `_FollowPill` 与详情门（ChromeIconButton+badgeInfo），`_RoomTitleBar` 删除（标题移交播放器）；④ **P3a**：player_surface 新增 `_RoomTitleCaption`（标题/观看·已播两行玻璃条，PlayerGlassPill 承载，点击 showRoomDetails，宽/常规内联跟随自动隐藏，immersive/tv/竖屏全屏不挂）；⑤ **P3b**：`_ControlBar` 双簇——左簇新增 静音切换（`t.room.mute/unmute`，状态回读 setState 刷新）与音量滑杆（DsSlider 0-100，≥720 显示），窗口全屏按钮撤 ≥720 门槛全档位可见；验证：`flutter analyze`（room+shared/player+test）**0 issues**、全仓 analyze **0 issues**、护栏 7 例+底部面板 6 例全绿。**未做（后续轮次）**：P3 通栏 scrim/右上簇常驻浮层/ChatSplitter 接线/倍速、P4 竖屏聊天、P5 更多容器（含投屏迁更多——现仍可从 ⋮ 菜单到达，无功能回退）、P6 拆分；运行时视觉验收归用户。

- 2026-11-12：第三十六轮（用户拍板：直播间不需要 seek——seek 属红果短剧/bilibili 视频/虎牙回放视频域；撤直播间改动并把设计语言带去其它播放模块）⇒ ① **撤 PiP 回放时间线**（第三十五轮①整项回退）：`_PipSeek` 删、`_PipBar` transport 参数与挂载层撤、mount 的 bottom:42 时间线层删；**控制条既有的回放 seek 行保留**——房间内播放的虎牙回放/bilibili 回放正是用户点名的 seek 目标，行仅在回放房出现，直播房不受影响；② **0=常显 跨页回归修复**（第三十一轮 E 引入的适配面缺口）：hongguo `_scheduleHide`、vod `_scheduleHide`、wallpaper_video_player `_scheduleHideBar`（media_preview 的 barHideAfter 宿主）此前读 0 会 `Duration(0)` 立即隐藏——三处均增 `<=0 跳过`（常显=播放中条不隐）；IPTV 未动（其 info 条 6s 固定、不读该设置，且为用户并行开发区，是否接入留给用户）；③ **统计 I 键补齐**：hongguo/vod 的 CallbackShortcuts 表在 keyF 后增 `KeyI → playerStatsVisibleProvider.toggle()`（非 TV，与房间同键同面板）；media_preview 无既有快捷键表，维持菜单入口。验证：format ✓、analyze（room/hongguo/vod/settings 四作用域）**0 issues**；测试/构建归用户。**其余播放页与房间设计语言的差异面（统计浮层四页均已挂、菜单入口三页均有）核对完毕，本轮不再有已知缺口。**

- 2026-11-12：第三十七轮（用户「继续」拍板 IPTV 接入）⇒ `iptv_play_page` `_showInfo` 撤固定 6 秒，改读 `controlsAutoHideSeconds`（0=常显：换台提示条不再自动隐，直到下次换台；>0 按设定秒数隐）——settings.dart 本已导入，零新增依赖。验证：format ✓、analyze（iptv）**0 issues**；测试/构建归用户。**候选待用户确认**：vod/hongguo 两页的画中画窗 chrome 是否对齐直播间 F 条（13 键玻璃条+标题条）——两页无设计原型背书，不经审计不动手，等用户立项。

- 2026-11-12：第三十八轮（vod/hongguo 画中画窗差异审计，探索代理全量清点，无代码改动）⇒ ① **架构事实**：两页 pip 走 `modeOwnsWindow` immersive 分支（vod :1470-1472 / hongguo :1209-1212），渲染的是与全屏同一套沉浸面（非裸画面）；pip 窗=独立窗口+独立 Navigator（window_root :86-141），窗内菜单/面板/弹层均落窗内，与直播间同机制；**两页 immersive 分支均不包 CallbackShortcuts**（键盘在 pip 窗内全盲）。② **共同缺失**（对照直播间 F 条）：窗口拖动零接线（两页对 windowsPipWindowProvider 零引用，仅窗顶 resize band）、双击恢复零接线（vod 双击=±10s/播放暂停、hongguo=播放暂停——视频语义该保留，恢复应挂标题条）、关闭窗口动词缺、控件锁缺、**Esc 未绑**；**pip 态动词错位**：两页顶部「退出全屏」pill 与 hongguo 底栏全屏钮（:2240-2244 无 pip 门控）在 pip 态按下会**切系统全屏而非回页面**（与第三十五轮横持退出钮同类错位）；vod 顶部 pip-exit 钮才是恢复动词。③ **两页既有优势（保留，不换直播间条）**：vod=缓冲/章节/预览进度行+两端时间、上下分段 chip、画质/分段/倍速/字幕四选、弹幕开关+设置直达、收藏、投屏、横向滚动兜底；hongguo=选集网格、右侧动作栏（下一集/赞/收藏/评论/分享）、睡眠定时（菜单）、长按倍速。④ **候选方案待确认**：P1 pip 态动词纠偏（退出 pill→恢复回页面+label 改 pipOff，含 hongguo 底栏全屏钮门控）；P2 标题条承载窗口拖动+双击恢复；P3 关闭窗口动词（需先核实两页窗口宿主 API）；P4 immersive 态 Esc=退出 pip 回页面。

- 2026-11-12：第三十九轮（用户确认立项：vod/hongguo 画中画窗对齐直播间窗口层，P1–P4 全量落地）⇒ ① **P1 动词纠偏**：vod 顶 strip 前导 pill 在 pip 态改绘 恢复动词（pip-exit.svg + `t.room.pipOff` → `_togglePip` 即 `_exitTo(_returnMode)` 回页面），非 pip 态维持退出全屏；action pill 的 pip 钮在 pip 态隐藏（前导已是同一动词，不再重复）；hongguo 同改前导 pill，底栏全屏钮加 pip 门控（pip 中收起——小窗没有自己的全屏可切）；② **P2 窗口拖动+恢复**：两页顶 strip 标题区（Expanded 文本）包 GestureDetector——pip 态 `onPanStart` → `windowsPipWindowProvider.startDragging`、`onDoubleTap` → `_togglePip` 恢复（房间 `_PipTitle` 同对动词；全屏态 strip 保持惰性不抢手势）；③ **P4 owned-window 键盘**：两页 immersive 分支包 `CallbackShortcuts`+`Focus(autofocus)`——Esc=`_leave`（退出所在模式：pip 回页面/全屏回布局）、I=`playerStatsVisibleProvider.toggle()`（非 TV；tv 局部上提至分支前），pip 窗内键盘自此不再全盲（chromium 自动隐藏时焦点随 chrome 消失属既有限，常显下恒可用）；④ **P3 关闭窗口**：核实 `roomLeaveProvider` 在 window_root :148-153 对非主窗 override 为 `host.close`（通用窗口关闭动词，经 app.dart 导出，两页零新增 import）——两页顶 strip 末尾（vod 在 morePill 后 / hongguo 在角簇后）pip 态增 ✕ 玻璃 pill：先 `_handle?.pause()` 再 close（窗体 dispose 的 silence+release 兜底音频不外泄），主窗（provider=null）不显示。**两页内容条（进度/选集/字幕/弹幕/动作栏等）按第三十八轮结论原样保留**。验证：format ✓、analyze（vod+hongguo）**0 issues**；测试/构建归用户。

- 2026-11-12：第三十九轮·补（同类错位清尾+全仓校验）⇒ hongguo 错误浮层「回选集」在 pip 态原会 `_toggleFullscreen`（落入全屏而非回选集页）——改读 pip 态走 `_togglePip` 回页面（全屏态维持原语义）。**全仓校验**：`flutter analyze`（纯 live 全应用）+ `test` 作用域 → **0 issues**（含用户自有并行的 iptv/live_iptv 等改动区）。

- 2026-11-12：第三十九轮·补二（死键清尾+入口去重）⇒ ① room `openInNewWindow` 死键删除（第三十一轮新窗口 tile 撤除后零 dart 引用；中英 json 同删，slang 重生成，json 校验过）；② hongguo ⋮ 菜单的 pip 项在 pip 态隐藏（`pipIn && !pipInMode`，图标简化为进入态）——顶 strip 前导 pill 已是恢复动词，菜单不再重复同一动词（与 vod 第三十九轮①同口径）。其余候选键逐一核查存活（theaterOff/theaterOn=media_preview、fullscreenOn/Off、windowFullscreenOn/Off、portraitFullscreenExit、danmakuChipOff、moreTools/moreSettings、panelStops/Hint、controlsAutoHideValue 均有引用）。校验：format ✓、analyze（hongguo/vod/live 三作用域+**纯 live 全应用+test**）→ **全部 0 issues**；测试/构建归用户。

- 2026-11-12：第四十轮（「继续」触发 State 提炼的"安全部分"尝试 → **尝试失败，全额回滚，冻结结论加强**）⇒ ① 尝试：把两入口的**方法组**（room_page 生命周期/浮窗/面板簿记 239+28 行、竖屏全屏/横持/切房 176 行；player_surface 拾取机制 98 行、画面手势/弹幕持有/HUD 235 行、tv scope/veil 22 行）以 P6 纯移动口径搬入新 part 文件——**前提误判**：P6 移动的是顶层类/函数，而本次搬的是 `_RoomPageState`/`_PlayerSurfaceState` 的**类成员**，Dart 类体不可跨文件，成员出类即失去 `mounted`/`_panels`/`_openPanelKind` 等接收者（304 errors）；② 回滚：以块长反拼原文件（part 文件为块源、@override 上锚定拼接点）、撤 part 指令、删三个新文件、恢复 pickers/stage 追加块——analyze **0 issues**、行数回到 1500/1523（与提取前一致），无一残留；③ **结论入账**：两入口剩余的 >500 偏差是 Dart「类体不可跨文件」的**结构性结果**——build 体（room 540/surface 612 行）与其依赖的字段/生命周期同生共死；唯一达标路径就是第二十七轮冻结的带参 mixin 分解（编译器可查类型、运行时需回归），**该路径维持冻结，且本次失败即其风险的实锤演示**。不建议再以"纯移动"口径重试。验证：format ✓、analyze（room）**0 issues**；测试/构建归用户。

- 2026-11-12：第四十一轮（「继续」授权的 State 提炼以**扩展（extension）机制**落地，第四十轮失败口径的可行解）⇒ ① **机制**：Dart 类体不可跨文件（第四十轮实锤），但同库 part 文件里的 `extension _RoomPageLifecycle on _RoomPageState` / `extension _PlayerSurfacePictureGestures on _PlayerSurfaceState` 可跨文件承载 State 成员且完整保有 `this`（私有字段/mounted/ref 全解析）；顶层函数（`_veilOf`/`_panelWidth`）本就可自由移动；**纯机械搬移，零逻辑改动**；② **迁移清单**：room_page 1666→**1081**——lifecycle part 258（写后帧/朝向/屏幕常亮/app 生命周期暂停/画中画簿记/浮窗武装/面板栈 `_onRoomPanelChanged`+`_showRoomPanel`）、layouts part 183（竖屏全屏/手机横持/画面比例/切房滑动）；player_surface 1501→**1173**——gestures part 242 新建（画面 tap/长按/弹幕持有与消息/HUD/拖亮/滚轮音量/手势边缘/飞行弹幕配置）、pickers part 追加拾取机制 98、stage part 追加 `_tvScope`+顶层 `_veilOf`；③ **机制的三条硬约束（全部落地并记账）**：(a) extension 成员**不可覆写父类**——`didChangeAppLifecycleState` 搬入 extension 后 `WidgetsBindingObserver` 的回调分发会静默失效（lint=override_on_non_overriding_member，本质是行为破坏而非风格问题），已搬回类体（dispose 之后）；今后凡 `@override` 的 State 成员必须留在类体；(b) extension 内不可裸引宿主类 static——`_phoneLandscapeChatWidth` 限定为 `_RoomPageState.` 前缀、`_panelWidth` 从 extension static 改为库级函数；(c) extension 调 `setState` 触发 invalid_use_of_protected_member（receiver 本就是 State 实例，语义安全）——四个承载 part 文件头加 `ignore_for_file` 与两句缘由注释；④ **过程偏差如实**：中途解析曾报 428–501 issues，三处根因均已修复——三个新 part 文件漏写 `part of` 头（被当独立库解析，几百个 undefined 即源于此）、wrap 脚本对已包裹文件二次包裹（双 extension 头+残留旧 doc 碎片，两文件按块重建）、build 的 `@override` 被切进 gestures 块尾；⑤ **验证**：format ✓、analyze（room）→（lib+test 全量）**两轮 0 issues**；入口仍超 500 的偏差=build 体（同第二十七轮口径），进一步达标需分解 build 为分段方法，仍属冻结事项；测试与构建按用户指示归用户执行；运行时行为等价性由「纯机械搬移+编译器全检」背书，视觉/运行时验收归用户。

- 2026-11-13：第四十二轮（用户点名「虎牙视频UI和播放页面也有优化，只要涉及播放都要优化，比如录制播放等」+ 拍板补下载 ⇒ 全部播放面对齐直播间设计语言，P0–P3 四批落地）⇒ 双探索代理全量盘点（各播放页动词矩阵 × 9 项共享基建）后实施：① **P0a 虎牙视频页表现层整套接入**（`huya_video_player_page.dart` 742→1413，此前无全屏/无统计/无快捷键的裸播放器）：全屏/窗口全屏/画中画三形态（roomPresentationProvider）+沉浸分支 Esc/I、覆盖条（strip=返回|退出 pill+标题+截屏+小窗+✕，pip 标题拖动+双击恢复）、底栏=seek 行(VodSeekBar)+文字芯片（播放/静音+音量/时钟/清晰度/倍速/窗口全屏/全屏）随 controlsAutoHideSeconds 自动隐藏（0=常显）、统计浮层+I 键、截屏（capturePlayerFrame，canCaptureScreenshot 门控）、键盘全量（space/F/I/Esc/↑↓音量/←→递增 seek/,/. 倍速步进/M 静音/TV 唤醒）、VodPictureGestures 手势面（tap 开关 chrome/双击 ±10/横扫 scrub/竖拖音量/滚轮/长按 3x）、geometry 双驱动喂养、后台门 BackgroundPlaybackGate、常亮、朝向策略；PageHeader 撤除（strip 即页头，vod 同口径）；② **P0b 虎牙下载**（用户拍板「补下载」）：新 `huya/controller/huya_downloads.dart`（502 行）——持久化队列（StoragePrefs 'huya.downloads'，跨会话续传 .part+range/200/416 语义照 vod）、单车道、任务时经 `HuyaVideoApi.detail` 重解析新鲜地址（签约 URL 不入库）、按观看清晰度取源（缺失回落最优）、文件落站内视频文件夹、复用 vod 的文件名助手；页内接入=strip 下载钮+画面进度 pill（运行中转圈+百分比+暂停；暂停/失败态=恢复/重试 pill，弥补暂无管理页）+入队三态 toast+完成 toast（ref.listen 相变）；l10n 增 vod.downloadResume（恢复下载/Resume download）slang 重生成；③ **P1 回放页对齐**（`archive_player_page.dart` 448→1181，虎牙/斗鱼/SOOP 回放共用）：同 P0a 全套口径（覆盖条+芯片栏+统计+I/Esc/截屏/键盘/手势/后台门/双驱动/常亮/朝向），分P行保留常态页布局（沉浸态暂无分P入口，记账遗留）；弹幕层与开关原样保留；④ **P2 IPTV 补角**（iptv_play_page，用户并行开发区，仅增量）：I 键（统计）、pip 窗内 CallbackShortcuts（Esc=还原/I=统计）+窗内统计浮层挂载、✕ 改走 roomLeaveProvider（host.close，先 pause）、控制条/光标隐藏改读 controlsAutoHideSeconds（撤固定 3s，0=常显；信息条原本已读）、画面挂 RecordingIndicator 录制红点（呼吸点+计时+点击停止，对齐直播间录制反馈）；⑤ **P3 零散补缺**：hongguo——pip 驱动喂养补齐（此前只喂 fullscreen，小窗锁 16:9）、,/.\u3000倍速步进+M 静音+←→ 递增 seek（5/10/20 逐级，与 vod 同语言）、条上窗口全屏芯片（_desktop 门控）；media_preview——pipOwned 裸舞台→窗口层三件套（恢复 pill+标题拖动/双击还原+✕ 走 roomLeaveProvider）+窗内 Esc/I 键；⑥ **决策点回执**：录制不进点播型页面（vod/hongguo/虎牙视频/回放——录制引擎面向直播流，点播的动词是下载，vod/hongguo 已有、虎牙本轮补齐）；各页 ⋮ 下拉→玻璃更多面板维持另立任务；⑦ **过程如实**：`dart format` 目录级运行时顺带规整了 hongguo 模块 10 个本轮未触碰文件的纯格式差异（逐文件核对 vs HEAD 均为 format-only、无语义混入，无用户未提交工作受影响）；验证：format ✓、analyze 逐批（huya/archive/iptv/hongguo/media_preview）全 0 issues、最终 lib+test 全量 **0 issues**；测试与构建按用户指示归用户执行。**遗留记账**：虎牙/回放沉浸态无分P入口（需玻璃面板另立）、虎牙下载无管理页/设置 pane（当前以页内 pill+文件落盘覆盖基本环，管理面待用户立项）、IPTV 窗口全屏动词缺、iptv 嵌入态光标隐藏语义复核归用户、运行时视觉验收归用户。

- 2026-11-13：第四十三轮（用户「开始」触发第四十二轮遗留批次清尾：A 回放页沉浸态分P入口 / B 虎牙下载管理面 / C IPTV 窗口全屏动词）⇒ ① **A 回放页沉浸态分P**（`archive_player_page.dart` 1181→1250）：启用全 App 播放器统一弹层语言（shared 的 `PlayerPanelHost`+`PlayerOverlayPanel`+`PlayerPanelOption`，即 vod 拾取面板同一套）——沉浸态条上增「分P」芯片（仅 `segments.length > 1` 且 immersive 时出现，`KeyedSubtree` 锚点+`_barAnchor` 供宿主居中测量），面板列 P1..Pn（SOOP 按 order、斗鱼按序号，当前项打勾），选分P先收面板再 `controller.open`；`_scheduleHide` 增 `_partsOpen` 守卫（面板开着 chrome 不隐，随 bar 隐藏而收起）；常态页的分P行原样保留；② **B 虎牙下载管理面**：新 `SettingsSection.huyaDownload`（虎牙模块此前无任何设置页——`module_navigation` 的 huya 模块注释原话"Huya has no settings page of its own yet"）+ 新 pane `huya/pages/huya_downloads_pane.dart`（199 行）：全队列行式管理（任务名+相位字幕+进度条/速度、行尾相位动词钮=暂停/恢复/重试/打开、⋯ 菜单=打开文件/打开文件夹/删除文件（destructive）/移除任务）+ 下载文件夹行（openDownloadedPath，与 vod 同一 appPaths.videos 存放点）；ripple 全套：settings_sections 枚举+label/desc 双 switch+groupHuya 三表（label/desc/icon）、module_navigation huya 模块 settingsGroups 增自有组（单节组按 settingsSolePageOf 折叠，不重复占行）、settings_page dispatch+barrel import（huya.dart 增导出 pane）、settings_search 两条命中、settings l10n 增 huyaDownloadTitle/huyaDownloadDescription（中英，slang 重生成）；pane 文案复用 vod/common 既有下载键（零新增冗余键）；③ **C IPTV 窗口全屏动词**：条上全屏钮前增窗口全屏芯片（`_desktop` 门控+pip 态隐退，`toggleWindowFullscreen` 直连，选中态 tint），与直播间/vod/hongguo 条上双动词同一口径——iptv 此前是唯一没有窗口全屏的播放页；④ **过程如实**：一处 python 脚本转义事故——`'P\${part.order}'` 被 bash/python 双层转义写成字面 `\${`（插值失效，Dart 字符串显示原文），use_raw_strings lint 兜住，已修为真插值；hongguo 目录级 format 的教训生效，本轮各目录 format 均 0 changed（未再波及未触碰文件）；⑤ **验证**：format ✓、analyze（archive/iptv/huya/settings/app 五作用域逐批）全 0 issues、最终 lib+test 全量 **0 issues**；测试与构建按用户指示归用户执行；运行时视觉验收归用户（分P面板居中弹出/选集切换、pane 行操作与删除文件、窗口全屏进出）。

- 2026-11-13：第四十四轮（用户「继续 该走的功能不能少」⇒ 差距表剩余缺口清尾：睡眠定时四页接入 + media_preview 沉浸态键盘）⇒ ① **睡眠定时接入 vod / 虎牙视频 / 回放 / IPTV 四页**（此前仅房间与红果有，对照差距表该列为四页全空）：房间既有模式照搬——入页捕获 `sleepTimerProvider.notifier` 并设 `onFire_ = _onSleepFire`（fire=handle.pause+`t.room.sleepDone` toast，房间同款），离页 `onFire_ = null` + `Timer.run(start(null))` 解除武装（Timer.run 即房间的写后帧口径，dispose 期 ref 不可用）；面板入口 `showRoomSleepTimer`（room_panel 直引，page-agnostic，room.dart barrel 未导出 panels 维持原 API 面）；**入口落位**：vod ⋮ 菜单尾部增「定时关闭」行；虎牙视频/回放两页 strip 增 ⋯ 玻璃 pill（此前无更多菜单，睡眠作为"选择"进 ⋯ 与 vod 同口径，pill 行=动作、⋯=选择）；IPTV 页头 demoVerbs 增「定时关闭」verb（宽头按钮/窄头 ⋯ 折叠双形态自动覆盖，直播/ASMR 语义）；四页 fire 语义统一为**暂停**（直播频道与视频都是"看到这里睡着"）；② **media_preview 沉浸态 Esc/I**：非 pip 沉浸分支包 CallbackShortcuts+Focus(autofocus)——Esc 走 `_leave`（抽屉先让、再退全屏，与 PopScope 同序）、I 翻统计浮层（此前该页无任何键盘绑定）；③ **过程如实**：iptv import 插入一度把多行 import 语句拦腰截断（`iptv_user_agent.dart'` 无分号续行），解析报 16 错，已按字母序重排至 `live/recorder` 之后（recorder < room）修复；archive/huya 同类 directives_ordering 一并按序归位；④ **验证**：format ✓、analyze（vod/huya/archive/iptv/media_preview 五作用域）**0 issues**、lib+test 全量 **0 issues**；测试与构建按用户指示归用户执行；运行时验收归用户（定时面板弹出/到点暂停+toast、离页解除、各页 ⋯ 与页头 verb 落位）。
- 2026-11-13：第四十五轮（用户「红果短剧我一直觉得详情版面不好看帮我优化一下」→ 提案9点 → 用户「继续」授权实施）⇒ 红果剧集详情页对齐剧集家族标准（`hongguo_series_page.dart` 547→618）：① 页面骨架加阅读宽度上限——`_body` 的滚动内容套 `Center`+`ConstrainedBox(maxWidth: 1100)`（与 vod season 同读宽），宽窗口不再把字拉过一版头能承受的宽度，货架/相关/评论同受益；② 海报位重做——88×118 小图改 **3:4 大海报**（宽窗 200 / 窄窗 116，`LiveWindow.isCompact` 判定），底部 `kRoomCoverScrim` 渐变压脚，右上角**评分强调章**（accent 底 + onAccent 字 + 圆角章 + numeric w700，照抄 vod `_scoreBadge` 制式，rating>0 才出现）；③ 标题升格 heading w600 两行；④ 徽章行=排行榜奖杯（warning 保留）+ 分类徽章 + 评分章（角与行各说一次分，vod 同款双置）；⑤ 弱信息行降格——状态/热度/播放/粉丝/点赞/集数收进一行灰 caption（两行封顶），评分从该行摘出（升级为章）；⑥ 进度条脱离信息列——有进度时在按钮上方独立成条（第N集·时长 + HongguoProgressStripe）；⑦ 按钮全面降为 sm 且只留一个主声——▶ 继续观看/立即播放（唯一 primary）→ 从头看（secondary，仅有进度时）→ ♡ 收藏（ghost，收藏态只换 heart/heartOff 图标+文字，不再变 primary）→ 云收藏（ghost，登录态）→ 分享（ghost 纯图标 `DsButton.icon`，vod 惯例）；⑧ 简介保留 3 行 TextPainter 折叠原机制；⑨ DsCard 外壳拆除，头直接落页面（`_SeasonHead` 同款无卡）。验证：hongguo 定向 analyze **0 issues**、全量 lib+test analyze **0 issues**、dart format 已过（仅触碰本文件）。**未做/归用户**：视觉验收与运行验证归用户；架子（剧集货架/相关/评论区）本轮未动（收益于宽度上限），玻璃 more 面板共享组件化仍是挂账项。
- 2026-11-13：第四十六轮（用户「继续」接四十五轮未动项 → 提案5点 → 用户「开始」授权）⇒ 红果详情页剩余段落优化（页级节奏 + 评论区语言统一）：① 页级分隔线对齐 vod season 家族节奏——`hongguo_series_page.dart` 列 children 在 head 之后补唯一一条 `DsDivider`（DsDivider 取自身 1px 无边距，s16 间距不变），货架/相关/评论之间仍纯间距；② 剧集货架段头补总数（`hongguo_episode_shelf.dart`）：`剧集` → `剧集 · N`（vod 同款 `episodes · length`），≤20 集不翻页的剧此前从不显示总数；③ 评论区语言统一（`hongguo_comment_panel.dart`，详情页+播放页两宿主同受益）——剧集评论行距 s4→s12 且行间加细线 `DsDivider`（行块独立子 Column spacing 0 自管节奏，避免外层 s8 与分隔线叠加）；站点短评**去 DsCard 外壳**改与评论同款细线分行（头像 sm/名字 w600/评分/点赞/内容保留），两段一个语言；面板 title 行补 `Semantics(header: true)`（两货架段已有）；④ 硬编码 `红果用户` 兜底名×2 → `t.hongguo.anonymousUser`（zh 红果用户 / en Hongguo user，插在 commentsEmpty 后，zh/en 同位；`dart run slang` 重生成，键分布与四十三轮 huyaDownloadTitle 同模式）；⑤ 相关作品段与剧集卡片不动（骨架/空态/错误态已完整）。踩坑：`DsSpace` 刻度 8→12 无 s10，行距改 s12。验证：hongguo 定向 analyze **0 issues**、全量 lib+test analyze **0 issues**、dart format 已过（3 文件触碰仅 1 变更）。**未做/归用户**：视觉验收与运行验证归用户；玻璃 more 面板共享组件化仍挂账。
- 2026-11-13：第四十七轮（用户「继续」对四十六轮挂账项拍板 → 提案两阶段 → 用户「继续」授权）⇒ **玻璃 more 容器共享化**（阶段一容器落地 + 阶段二第一站虎牙接入）：① **PlayerGlassCard 提升共享**——`lib/shared/player/player_glass_card.dart` 新建（RoomGlassCard 原逻辑平移：LiveGlassLevel.standard 磨砂 + surface 86% 底 + border 边），`room_glass_card.dart` 64→9 行改 **typedef 别名**（原案"薄子类"因 final class 禁库外 extends 落空，typedef 保住"房间引用零改动"承诺，Dart 3 类别名构造/静态全通），房间 5 文件引用零改动；② **player_more_container 新建**（`lib/shared/player/player_more_container.dart` 382 行）——`showPlayerMoreContainer(context, content:)`：≥720 右停靠玻璃面板（372 宽、仅 start 侧圆角、header 更多+✕）/ <720 底部玻璃 sheet（grip+分组标签 labeled 标志传给内容），showGeneralDialog 滑入 easeOutCubic、barrier、Esc+autofocus 关闭全数平移；原语泛化 `playerMoreSectionLabel`/`PlayerMoreTile`（圆钮+lit accent 环）/`PlayerMoreRow`（label+value+chevron|trailing）/`PlayerMoreSeg<T>`（段选 chips）；player.dart barrel 字母序插两行；③ **showRoomMore 改薄壳**（room_more_menu.dart 622→295）——容器接管 chrome，`_RoomMoreContent` 内容原样平移（自绘 grip 块移交容器、`_Tile/_Row/_Seg/_sectionLabel` 换共享原语、`_Circle` 彩色分享圆留在房间），文案/动词/交互零变化，删除 `kRoomMorePanelBreakpoint/_RoomMoreEscape/_RoomMorePanel/_RoomMoreSheet/_CloseButton`（断点常量无外部引用已核）；④ **虎牙视频页 ⋯ 接入**（huya_video_player_page.dart 1447→1504）——`DsMenuAnchor`(仅睡眠) → `showPlayerMoreContainer` + 新 `_HuyaMoreContent`（ConsumerWidget）：定时关闭 row + **自动隐藏 seg row**（0/2/4/6/10s 读同一 `playbackSettingsProvider.controlsAutoHideSeconds`——虎牙 :453 已生效该设置但此前无处可调，真实补缺）；bar 常驻动词（下载/截图/PiP/画质/倍速/适配）不重复收纳（房间"面板是索引"规则）；labeled 时补 `t.room.moreSettings` 组标签。验证：定向（shared+live+huya）analyze **0 issues**、全量 lib+test analyze **0 issues**、dart format 已过（6 触碰 3 变更，9 个用户未格式化 live 文件未触碰）。**未做/归用户**：视觉与运行验收归用户（房间 more 零变化属静态平移保证）；回放/IPTV/vod 视频/红果播放器四页接入待后续轮按同规则各自成图。
- 2026-11-13：第四十八轮（用户严厉纠偏「设计的UI只是原型，需要根据实际情况分析优化而不是机械照抄」点名四条 + 「回放也不需要 不管是直播还是录播都不需要」）⇒ 直播间照抄清除（对照用户提交 9eb7308a8 旧版逐条复原）：
- 2026-11-13：第四十八轮（用户严厉纠偏「设计的UI只是原型，需要根据实际情况分析优化而不是机械照抄」点名四条 + 「回放也不需要 不管是直播还是录播都不需要」）⇒ 直播间照抄清除（对照用户提交 9eb7308a8 旧版逐条复原）：① **房间控制条时间轴+倍速整体删除**（用户拍板：直播/录播都不要——房间页是"看直播"的地方，值得拖动进度的回放属于 vod 页）：`seekLine`/`speedChip`/`replay` 判定/`_dragSeconds`/`_rate`/`didUpdateWidget`/`vodDurationText` import 全清——原"直播误判 replay"bug（`isLiveNow` 在平台不填状态时默认 false → 虎牙等直播被套上回放形态）随删除一并消灭；② **按钮化**（"窗口全屏和全屏是按钮"）：播放/重试 `_BarChip` 文字档（原型 T1 tier 照搬）→ `PlayerBarButton` 图标（pause/play.svg、refreshCw）；窗口全屏文字芯片 → 图标按钮（square/copy、selected 态、wide≥720 门恢复）；全屏文字芯片 → 图标按钮（maximize/minimize、selected、fullscreenOn/Off 键回归）；`_BarChip` 类整体删除；③ **弹幕设置整套复原**（"我之前的弹幕和弹幕设置不是挺好的吗"）：`_DanmakuBarCluster`（danmaku-on/off.svg 开关 + danmaku-settings.svg 齿轮）+ `_DanmakuSettingsControls` 四滑条（显示区域/字号/不透明度/速度 + 高级设置入口），`_danmakuSettingsOpen/_danmakuSettingsAnchor/_toggleDanmakuSettings/_closeDanmakuSettings`，`_scheduleHide` 加守卫，PopScope `canPop` 收紧+返回先关面板，面板宿主块（`PlayerPanelHost` 280 宽挂齿轮上方 + Esc 焦点 + barrier 点关）——此前我把它删成文字芯片+更多面板跳设置页，是本轮最大错误；④ **更多面板去重**（"更多里面有画中画 外面也有 重复了"）：删 截图/录制/PiP 三 tiles（顶栏呈现簇已有）→ 工具格剩 投屏/统计/切房间/纯音频；删 回放倍速 seg 行（②的另一半，房间倍速全面退场）；删 弹幕设置行（齿轮是家）；imports 清理（recorder/room_screenshot/app.dart 移除 → environment_providers 直接 show platformRuntimeProvider）。原则确立并写入面板头注释：**原型只是参照，bar 常驻动词不进面板，面板只收 bar 上没有的动词与设置**。验证：定向 live+shared analyze **0 issues**（控制条全文件重写一次过）、全量 lib+test **0 issues**、format 过（仅触碰本轮 3 文件，9 个用户未格式化 live 文件未动）。**未做/归用户**：运行验收（齿轮弹面板/开关即时生效/窄窗 sheet 形态）；IPTV 头部折叠菜单另议；三页容器接入（回放/vod/红果）暂缓，待用户重新定夺——此前提案的内容清单需按"bar 收不下的才进面板"重新核对。

- 2026-11-13：第四十九轮（product-design Audit 走查 + 全量机会点排期，用户拍板六包按序）⇒ 用户点名「针对当前直播间 UI 优化设计」：三路探索代理对 48 轮后现状做 Nielsen 12 维全页走查，**25 findings（major 10 / minor 15 / blocker 0）聚 6 机会点**，报告落 spark-output/audit/pure-live-room.md + context/audit.json（对话内已呈现 Major 10 条）。用户拍板：**六包按序全排**、竖屏全屏**接线**且**按画幅路由**——统一全屏动词按 `pictureRatio` 分流：竖屏视频（<1）→竖屏全屏形态（聊天面板/退出手势启用），横屏视频（≥1）→系统全屏（横屏显示）；适用于拉穿/F 键/控制条全屏钮/自动全屏全部入口。批次表（验证门=逐包 room 作用域 analyze + format 只点本轮文件，l10n 触碰即 slang 重生成）：
  - **O1 连接生命周期可见性**：audit-1 聊天断连状态迁移（socket 掉线回写 chat status 让故障横条接管）/ audit-2 reconnecting 死枚举处理（media_core 属禁区，引擎无重连信号则删死枚举并在 buffering 卡文案兜底）/ audit-6 睡眠定时面板显激活档+剩余 / audit-4 键盘 ↑↓ 音量接 PlayerVolumeHud / audit-5 静音回显改监听控制器。
  - **O2 竖屏形态接线**：audit-9+10 按画幅路由接线（竖屏流 sheet 拉穿、紧凑体拉穿、F 键、全屏钮、自动全屏 latch 全走同一分流；PlayerSurface 竖屏参数 canEnterPortraitFullscreen/onPortraitFullscreen/onPortraitRestore/onPortraitSwipe 全接）。
  - **O3 身份与动词语义统一**：audit-13 宽窗列头收编（_ChatRoomHeader 身份+关注撤除，身份唯一归顶栏；TV 双份记账保留）/ audit-7 refresh 独立文案（不再冒名 retry）/ audit-8 错误卡返回统一 back / audit-14 门控统一（PiP 条截屏不可用改隐藏，与常驻簇同口径）/ audit-15 ⋯ 方向统一水平。
  - **O4 设置与帮助诚实性**：audit-21 更多面板快捷键帮助传真表 / audit-17 不可发言 composer 位留 muted 提示（按未登录/平台不支持分文案）/ audit-18 礼物过滤接线管线+设置入口 / audit-19 聊天字号残留清尾。
  - **O5 健壮性与反馈细节**：audit-24 统计浮层 handle! 摘除 / audit-16 发送字数上限 / audit-23 发送失败 toast 带原因 / audit-20 聊天 tab 持久化。
  - **O6 窄口径与 PiP 兜底**：audit-11 更多面板补弹幕开关行（窄条兜底）/ audit-25 表情收集 O(n) 评估后闭环（受 200+60 上限约束，若无感知收益则记录"评估不修"依据）/ audit-12 PiP 不可达动词**维持记账**（窗内拾取器宿主另立任务，历轮已定）。
- 2026-11-13：第四十九轮·实施（O1–O6 全部落地，全量 lib+test analyze **0 issues**；测试构建与运行时验收归用户）⇒ 逐包回填：
  - **O1 完成**：① **RoomState 收编 muted/volume**（audit-5 真因）——原"state echo 回显"注释是错的：Riverpod 3 Notifier 默认 `updateShouldNotify = previous != next`（structural），`_with()` 复制同值 record 相等**根本不通知**，回显全靠手动 setState、PiP 条本地 `_muted` 镜像永不刷新。修法=muted/volume 进 record（_initial 带参、open 先设字段后写 state、setVolume 按**整百分点节流**推 state 防拖拽逐帧刷页），控制条删 `.then(setState)` 改读 `room.muted/room.volume`，PiP 条删本地 `_muted` 镜像改读 record；② **聊天断连状态迁移**（audit-1）——站点包早有现成信号：`DanmakuSessionBase.states`（Connecting/Joined/Reconnecting/Exhausted，18 家会话继承，barrel 已导出），控制器从没订阅。新增 `_chatStates` 订阅（`LiveDanmakuStatusEvents` 能力接口仍零实现属包内挂账，本轮零包改动）：Joined→connected、Reconnecting→connecting（横条 spinner）、Exhausted→failed 带原因；events 流 onDone（自身断绝，非基类会话如 bigo 的终端路径）→failed；后台 resume 失败也写 failed。回调带 `identical(_danmaku, from)` 守卫防换房竞态；③ **reconnecting 死枚举删除**（audit-2，media_core 属禁区无引擎信号，播放侧重连期维持 buffering 卡）；④ **睡眠定时剩余**（audit-6）——room_panel sheet 头新增 `_SleepRemaining`（endsAt 逐秒走字 mm:ss，控制器清零即消失），键 sleepRemaining；⑤ **键盘音量 HUD**（audit-4）——新 `PlayerSurfaceHud` 回执对象（页面持有、surface initState 挂 `_showAdjust`/dispose 摘），nudgeVolume 先 show 再 setVolume，避开共享 provider 的跨窗泄漏（PiP 窗独立页面实例各自持有）。
  - **O2 完成（按画幅路由，用户口径）**：统一全屏动词 `pictureRatio<1 → 竖屏全屏形态 / ≥1 → 系统全屏`——`_enterFullscreen` 改路由版（sheet 圆钮/紧凑拉穿/竖屏流拉穿全走它，**sheet 实例补传 onPortraitFullscreen** 修复 audit-10 拉穿弹回）；新 `_toggleFullscreenVerb`（先退竖屏面、再退系统全屏、再按形状进入）接管 F 键/遥控 fullscreen/控制条全屏钮（surface 新增 `onFullscreen` 可选回调，双击同动词）；`_maybeAutoFullscreen` 按形状分流；playerWith 补传 `onPortraitRestore`（还原带手势）+`onPortraitSwipe`（中段滑切房，swipeSwitch&&mobile 门控）——竖屏全屏形态自此全链路可达（audit-9）；补 PopScope（仅竖屏全屏态拦截返回，`canPop: !_portraitFullscreen`，先退形态再退房）。
  - **O3 完成**：① **宽窗列头收编**（audit-13）——`_ChatRoomHeader` 整类删除（含第二身份/第二关注钮/悬停数字），宽列=纯 `RoomChatPanel`（tab 行自起），身份唯一归顶栏；`_roomClock` 留给 compact pinfo；live_cache import 随删；**死键 statOnAir 删除**（detailsHint 仍有多消费者保留）；TV 的 AppBar+画面条双份维持记账；② **refresh 独立文案**（audit-7）：新键 reloadRoom（重新打开房间/Reopen the room），离线卡不再冒名 retry；③ **错误卡返回统一 back**（audit-8）；④ **PiP 条截屏不可用改隐藏**（audit-14，与常驻簇同口径：面板=置灰、常驻条=隐藏）；⑤ **TV ⋯ 改水平 ellipsis**（audit-15，与右上簇同向）。
  - **O4 完成**：① **快捷键帮助传真表**（audit-21）——showRoomMore 增 `shortcuts` 参数（页内 build 局部 bindings 闭包直传），帮助弹窗与 `?` 键同一张表；② **不可发言提示**（audit-17）——composer 位留 muted 提示行（chatViewOnly："这个平台只能看，不能发言"）；按 LiveDanmakuSending 契约"要登录的平台不藏接口"，composer 隐藏=平台根本无发送能力，单一文案成立；③ **礼物过滤接线**（audit-18）——管线硬编码 true/false 改读 `chatShowGiftsProvider/chatGiftsAboveTierProvider`（闭包按事件现读，切换免重开）；弹幕设置 look 段新增「聊天列表」分组两行开关 + settings_search 目录两条登记；④ **字号残留清尾**（audit-19 降级为纯删除）——复核发现渲染早已用固定常量（`kChatListFontSizeFixed`），audit 的"旧值仍生效"不成立；chatNames/fontSize/lineSpacing 三 provider+键零消费者全删（含 settings_refresh 三条登记、backup_settings 三行备份项）。
  - **O5 完成**：① **统计浮层摘 `handle!`**（audit-24）——挂载加 `handle != null` 守卫（开关留着等引擎回来）；② 发送字数上限 100+计数器（audit-16，DsTextField maxLength）；③ 发送失败 toast 带平台原因（audit-23，description 参数）；④ 聊天 tab 持久化（audit-20，`danmaku.chatTab` 存名读名，未知名回弹幕 tab）。
  - **O6 完成**：① **更多面板补弹幕开关行**（audit-11，DsSwitch 读同一 danmakuVisible，条宽 <320 弹幕簇消失时仍有路径）；② **audit-25 评估不修**：表情收集 O(n) 受 200+60 行上限与每帧批处理双重钳制（room_controller 811-828 帧合并），最坏 ~15.6k 轻量字符串操作/秒，无感知收益，增量缓存属无收益抽象——记录依据后关闭；③ **audit-12 维持记账**（窗内拾取器宿主另立任务，历轮已定）。
  - 验证：每包 room 作用域 analyze → 全量 lib+test analyze **0 issues**（六包终态复跑亦绿）；dart format 仅触碰本轮 18 个文件（3 changed）；slang 重生成两轮（room+settings 键增删）。**未做/归用户**：运行时验收（竖屏全屏进出/拉穿/返回键、断连横条、PiP 条截屏隐藏、帮助表、礼物开关、定时剩余、静音/音量跨面回显）；测试构建归用户。**本轮未提交。**

- 2026-11-25：第五十轮（用户确认在当前工作区实施「直播 UI 优化 + 全屏修复」统一方案，三批落地）⇒
  - **房间信息层级**：新增 `room/page/room_facts.dart`，标题玻璃条、沉浸胶囊展开态与紧凑信息条共用「观看·已播」；已播计时收进单一秒级 `Timer`，compact 旧 `_WatchedClock` 与 hero 旧 `_roomClock` 删除，避免同屏重复计时。标题保持单行省略，胶囊按「标题 / 事实 / 分享·详情」分层。
  - **手机竖屏与横持**：竖屏沉浸删除视频区浮聊，恢复滚动弹幕，完整聊天改临时抽屉并补可见聊天入口；横持沉浸补 280px 可收起聊天列，打开时顶条/控制条同步预留末端空间；常规窄窗横屏增加 420px 舞台地板，放不下聊天列时改用底部面板，不再把视频挤成窄条。
  - **控制条与更多面板**：正常态刷新=「重新打开房间」，错误态播放位=「重试」且隐藏重复刷新；全屏图标/文案/selected 同时识别页面竖屏全屏与系统全屏。更多面板补「播放统计」tile，handle 未就绪时禁用，不复制底条已有截图/录制/PiP 动词。
  - **聊天与小窗身份**：已连接但无发送能力的房间保留只读说明，不再整条消失；桌面应用小窗标题合并主播名与房间标题，同名不重复。
  - **全屏与键盘/TV**：F、屏幕全屏钮、双击、自动全屏按画幅路由（竖屏流→页面竖屏全屏，横屏流→系统全屏）；F11 固定系统全屏。新增 `toggleFullscreenResult` 保留旧 `Future<void>` API，房间请求失败时 toast 反馈；系统全屏传顶部/底部安全区。Escape 顺序=面板/聊天 → 退出呈现 → 离开房间；TV Up/Down 增加 primary-focus 守卫，按钮/滑块聚焦时不再误触换房；面板开启期间自动隐藏守卫保留。
  - **列表与回放状态**：关注分区仓库/监听异常进入可重试错误态；多窗选房只监听当前历史/关注来源；关闭离线过滤后，主播结果可恢复显示离线主播；回放分P/普通面板开启或暂停时控制条不自动隐藏，Escape 先关面板。
  - **清理与文案**：零引用 `room_chat_overlay.dart` 与对应测试删除，barrel 同步移除；Slang 增 `chatViewOnly`、`fullscreenFailed`、`shortcutSystemFullscreen`（中英）并重生成三份 translations。无新增持久化配置；聊天/全屏/错误均为页面或运行时状态，播放统计与既有设置 provider 共用。
  - **多平台/主题**：布局覆盖桌面宽窗、窄桌面窗、手机竖屏、手机横持、竖屏全屏、系统全屏、窗口全屏、桌面小窗与 TV 焦点路径；颜色/间距/字体继续走 desen_ui 与现有主题 token，舞台保持深色。均为静态实现核对，未声称真机视觉通过。
  - **验证**：`dart run slang` 成功；仅格式化本轮单文件；`dart analyze lib` **No issues found**；受影响既有测试 **72/72 通过**（布局/底部面板/聊天/关注分区/多窗/搜索/回放）；目标路径 `git diff --check` 无空白错误。**未构建 APK/桌面产物、未截图、未运行 UI，运行时视觉与交互验收归用户。**
  - **限制与归属**：Windows `multiview_desktop` 的全屏状态及进入前窗口状态属进程全局，多窗互相影响需上游包修复，本轮未改 Pub cache。共享工作树既有并行改动全部保留；本轮未提交、未推送。

- 2026-11-25：第五十一轮（下载/播放器关联缺口 + IPTV 录制分离 + IPTV 全屏）⇒
  - **录制作用域**：共享 `RecorderEngine`、任务仓库和 `recordings` 根目录不变；`RecorderPage` 新增 `RecordingPageScope.live/iptv`，任务、统计、状态筛选、当前 tab、停止全部、预览列表和文件库均按作用域读取。IPTV 页不再显示开播检测、排程编辑、立即开录、直播间搜索或进入直播间；来源动作改为查找频道并打开 `/iptvPlay`，缺失频道有提示。直播列表排除 IPTV，IPTV 文件库只读 `iptv` 分树。
  - **模型与监控**：`RecordingTask.isIptv` 统一识别 `iptv:<channelId>`；IPTV 的停止态显示「已保存」而不是直播订阅的「已暂停」。监控器的排程、武装、窗口结束与 tick 快照排除 IPTV；中断恢复仍结算/重试合并 IPTV 文件，但不会把它重新武装成直播等待任务。
  - **录像库**：`RecorderLibraryPane` 支持 `platforms/excludedPlatforms/filterByPlatform` 与独立空状态说明；IPTV 不显示直播平台筛选，文件卡的来源动词改为「打开频道」。IPTV 设置组补共享录制设置，录制页设置入口不再落到不存在的 section。
  - **IPTV 全屏**：系统全屏与窗口全屏时，`AppLayout` 直接用不透明黑色 `PageSurface` 承载播放器，移除 AppShell、侧栏、标题栏、手机 AppBar/底栏；`IptvPage` 同时绕过三栏浏览器，只返回嵌入舞台。`_withBoard` 在非 normal 呈现只保留舞台。IPTV 模块内容使用稳定 `GlobalKey` 跨根重挂载，离开 IPTV 时更换 key；退出全屏可恢复原频道选择、三栏页面和同一播放器实例，而不是重建流。TV 根返回仍保留退出确认。
  - **下载/播放器**：共享 PIP chrome 隐藏时增加 `ExcludeFocus`，与既有 `IgnorePointer`、`ExcludeSemantics` 一起移出焦点/指针/语义树；虎牙下载的移除记录和删除文件统一走现有破坏性确认弹窗，复用 Slang 文案。
  - **配置/状态**：无新增持久化配置；录制页 scope、tab family、过滤/分页和页面 key 属运行时状态。Slang 新增 IPTV 录制空状态与外部播放器中英文案并重生成；磁盘布局、录制 ID 和共享引擎均未改。
  - **多平台/主题**：全屏改造覆盖桌面、窄桌面、手机、TV 的 AppShell 祖先链；录制页沿用现有宽工具栏/窄屏页头动作、分页和 desen_ui 主题组件。颜色/字体/间距仍走现有主题 token，全屏舞台为黑色。仅做静态实现核对，未声称真机视觉通过。
  - **验证**：`dart run slang` 成功；仅格式化本轮单文件；`dart analyze lib` **No issues found**；录制/监控相关模型、路径、预览、排程、仓库、虎牙下载、浮动播放器与房间布局/控制条既有测试 **78/78 通过**；`git diff --check` 无空白错误（仅 CRLF 提示）。**未构建 APK/桌面产物、未截图、未运行 UI；GlobalKey 重挂载后的实际连续播放、退出全屏布局恢复及多平台交互仍须用户运行时验收。**
  - **归属**：共享工作树既有并行改动全部保留；本轮未提交、未推送，未改 Pub cache。

- 2026-11-25：第五十二轮（虎牙关闭仍有声音 + Bilibili DASH 无声）⇒
  - **虎牙退出根因**：页面与浮动窗口虽然调用 `silencePlayer`，但 `PlayerHandle.dispose` 同步清掉 source/backend guard 后，排队的 `setVolume` 会被跳过；旧 open/play 仍占命令队列时，真实后端可能继续出声。共享 `PlayerAdapter` 新增 `silenceNow` 契约，`PlayerHandle.dispose` 在进入 runtime dispose 队列前直接调用，500ms 超时后继续释放；media_kit/mpv 用 native `set-property volume 0` 与 `pause true` 绕过 Dart command lock。其他继承 `PlayerAdapterBase` 的后端获得 volume=0 + pause 默认实现。
  - **Bilibili 根因**：应用层已正确生成 video/audio `CompositeMediaSource`；media_kit/mpv 原实现只向 `audio-files` 列表选项追加 URL，并未把音轨挂入已经打开的当前文件。改为运行时 `audio-add`，首条外部音轨 `select`、后续音轨 `auto`，避免后续 Dolby/高码率音轨抢走首选；请求头、音视频对齐和外部音轨存在性诊断保留，单条失败仍记录且不杀主视频。
  - **配置/状态**：无新增持久化配置；`silenceNow` 是播放器适配器生命周期契约，不是用户设置。未改应用层音量、全局静音、模块仲裁、Media3 原生 composite 或录制配置。
  - **文件**：本地 media_core 的 adapter contract/base、PlayerHandle、fake adapter 与两项测试；media_core_media_kit 的 adapter 与命令测试，共 8 文件。PureLive 侧只回填本台账，应用代码无需新增页面级释放补丁。
  - **验证**：media_core 与 media_core_media_kit `flutter analyze` 均 **No issues found**；PureLive `dart analyze lib` **No issues found**；media_core 全量 **2668/2668**、media_kit 全量 **30/30**、PureLive 播放器/浮动窗/虎牙/VOD 聚焦回归 **28/28** 通过；两仓 `git diff --check` 通过（PureLive 仅既有 CRLF 提示）。
  - **平台/主题与限制**：修复覆盖共享释放链及 media_kit/mpv 的 Windows、macOS、Linux、Android、iOS 路径；不涉及 UI 或主题。未构建、未截图、未运行 UI，未亲耳验证虎牙关闭瞬间静音、Bilibili 外部音轨选择/同步及移动端 Media3 行为；这些运行时验收仍归用户。共享工作树既有并行改动全部保留；未改 Pub cache，未提交、未推送。

- 2026-11-25：第五十三轮（整体产品 UI/功能/性能审计，待确认）⇒
  - **范围**：共享 AppShell/设置/播放器、直播/房间/回放、IPTV、Bilibili、虎牙、红果、音乐、下载与录制；实际对照 `E:/study/newBV-main/newBV-main`、`E:/study/webtv-main/webtv-main`、`E:/study/lx-music-desktop-master/lx-music-desktop-master`。
  - **结果**：44 项可定位发现（2 blocker / 21 major / 21 minor），聚类为 8 个机会点。最高优先级为 PGC 切集失败沿用旧 handle、录像库批量删除无确认、IPTV 当前频道状态分叉、嵌套路由/音乐音频仲裁、红果回环地址投屏、音乐中等宽度双栏溢出。
  - **方案**：阶段 0 正确性与数据安全；阶段 1 共享 UI 基础与主路径；阶段 2 下载/录制任务中心；阶段 3 性能与可访问性。保留单一 AppShell、模块沙盒、PiP/悬浮窗/多画面、回放弹幕与 live/iptv 录制分域，不重排直播设置。
  - **产物**：`spark-output/context/audit.json`、`spark-output/audit/pure-live-product-audit.md`、`spark-output/dashboard.html` 与本台账。未修改业务代码；JSON 计数与 dashboard 注入已程序化校验。
  - **限制**：仅静态源码与参考代码审查，未构建、测试、截图或运行 UI；性能结论为重建范围风险，真实帧率、TV 焦点、音频、投屏与横竖屏行为仍待运行时验收。等待用户确认实施范围。

- 2026-11-26：第五十四轮（全产品优化阶段 0–3 实施）⇒
  - **正确性与数据安全**：修复 PGC 切集时旧播放器继续播放、请求等待与失败清理竞态；VOD/虎牙/红果的休眠停止意图跨后台和路由返回保留，显式播放才恢复。虎牙关闭的排队静音改由 media_core 的 `silenceNow` 在释放前立即停声；Bilibili DASH 外部音轨改走 mpv 运行时 `audio-add`。下载在解析前同步预留任务身份，先删文件再移除记录，文件删除失败保留任务并提示；批量暂停覆盖 queued/running。红果回环投屏安全禁用，未引入局域网代理。
  - **共享 UI 与主路径**：沿用单一 AppShell、既有模块导航和 desen_ui；优化直播间信息层级、聊天遮挡/窄横屏舞台、刷新/重试、统计、只读聊天、全屏与返回/Escape/TV 焦点；IPTV 系统全屏改为纯播放器根，不再携带侧栏或三列祖先；音乐播放页按高度和剩余宽度切换歌词/封面。隐藏播放器控件同时退出 pointer、semantics 和 focus 树；共享控制条、选择条、seek 层、悬浮窗和回放页统一动作与可访问名称。
  - **任务与资产管理**：回放下载从页面生命周期移到窗口/container 级，离开回放页不自动取消；仅支持当前会话持续，拒绝 AES、fMP4 map 和 byte-range playlist。录像库补批量删除确认、文件/房间/站点搜索、当前任务文件保护；录制父页只订阅结构投影，任务卡独立订阅完整进度。`RecordingLibraryController` 仅在任务结算信号变化时扫描磁盘。IPTV/live 录制仍共享引擎和仓库，任务、筛选、统计、预览、动作与磁盘分树严格分域。
  - **性能**：多窗父层只看选中/静音/房间结构投影，单格、选中控制条和工具栏按需订阅；单格 transport 更新不重建兄弟格或整墙。音乐下载队列、多窗选房、当前房间录制文件、录像库按日行改为 lazy builder；录像库一次分组和汇总；音乐下载在筛选/计数/构建间复用文件缺失缓存，避免每个进度 tick 重复 stat。音乐在线歌单父层只订阅当前曲目，IPTV 最近页移除逐行 EPG 订阅。
  - **无障碍**：`MediaBarButton` 将 selected 传入共享 pressable 语义；移动端抽屉关注角标使用关注数量文案；壳内页面搜索补表单语义名称。新增共享播放器语义回归。静态检查确认共享 PIP/overlay 隐藏状态已退出焦点与语义树。
  - **配置/状态**：未新增持久化播放器配置；录制 scope、窗口级回放任务、结构投影与列表缓存属运行时状态。播放器内核/实例仍按模块隔离，主题/语言/外观/共享播放偏好仍全局。用户可见文案继续走 Slang；生成文件已同步。磁盘录制目录和任务 ID 规则不变。
  - **文件范围**：应用层涉及共享 layouts/player/settings、直播/房间/多窗/录制/回放、IPTV、VOD、虎牙、红果、音乐及其测试；`packages/live_vod` 补 Bilibili 外部音轨选择信息。本地 media_core、media_core_media_kit、media_core_audio 在仓外修复释放静音、外部音轨、音乐 mute 保持和下载删除安全。共享工作树其他未提交改动保留，未读取凭据或 Pub cache，未提交、未推送。
  - **多平台与主题**：逻辑与响应式覆盖桌面、平板、手机和 TV 分支；IPTV 全屏替换 AppShell 祖先；窄屏页级动作交壳层头部，宽屏保留工具栏。UI 使用现有主题 token 和浅/深/自定义主题链。多窗、全屏 reparent、音频后端、TV D-pad、触控和读屏实际效果仍需对应设备验收，不能由静态分析代替。
  - **验证**：`dart analyze lib` 与 `dart analyze test` 均 **No issues found**；回放 4/4、录制 provider 2/2、设置搜索 9/9、下载聚焦 28/28、音乐 provider/playback 13/13、VOD/虎牙/红果播放 30/30、IPTV/录制 40/40、多窗与录制 11/11、共享播放器语义 1/1 均通过；media_core 2668/2668、media_core_media_kit 30/30、media_core_audio 下载/后台 23/23 已通过，相关两包 `flutter analyze` 通过；`live_vod` `dart analyze` 与全量 **69/69** 通过；App `flutter test --no-pub` 全量 **1241/1241** 通过（03:57，退出码 0；运行期有既有 drift 多数据库调试警告，无失败）。`git diff --check` 仅既有 CRLF 提示。
  - **未完成与限制**：回放进程重启恢复和断点续传未实现；跨模块统一任务中心、全部 secondary surface/细粒度订阅、TV/触控/读屏全矩阵未完成；红果局域网代理有意延后。未构建 APK/桌面产物、未截图、未运行 UI、未做真实音频与设备视觉验收。页面 builder 化的主要行为由静态分析和既有聚焦测试覆盖，不宣称完整运行时回归。

- 2026-11-26：第五十五轮（继续审查与竞态收口）⇒
  - **IPTV 首态**：首次加载且无缓存时显示既有骨架；只有无可用数据的错误才显示失败与重试，刷新失败但仍有旧库时继续展示可用内容，与指南/最近页一致。
  - **播放器离页静音**：共享 `silencePlayer` 先走适配器即时 `silenceNow`，再排队暂停，避免慢 open 堵住命令队列时音频跨页面继续播放；`PlayerHandle` 暴露即时静音 API，并在 dispose 清空 guard 后复用同一私有实现。清理了共享 helper 的重复暂停。
  - **小窗替换**：关闭回调归具体 State 所有，旧视图 dispose 只在仍是当前所有者时清空静态槽位，防止 supersede 后误删新窗口回调。
  - **录制时钟**：页面与详情按运行状态启停局部秒级 builder，时长和码率随墙钟刷新；不再依赖相同 child 实例触发重建，也不持续刷新父结构投影。
  - **回放完成竞态**：所有字节已写入后，以 `sink.close()` 成功作为提交点；最终关闭期间取消不再删除完整成品，传输阶段取消仍删除半文件。
  - **直播候选绑定**：media_core_live 在 open 前按 sweep 身份发布 staged handle，房间去掉按 URI 轮询同窗口全部句柄的旧逻辑，改用代次校验的直接回调；正式接管仍只发生在验证提交。
  - **配置/状态与文件**：无新增持久化配置、Slang key 或主题 token；改动集中在 PureLive 的 IPTV 页、共享播放器、录制页、回放下载、房间控制器及对应测试，以及仓外 media_core/media_core_live 的句柄、sweep、fake 与回归测试。保留其他并行未提交改动。
  - **验证**：PureLive `dart analyze lib`/`dart analyze test`、media_core 与 media_core_live `dart analyze lib test` 均 **No issues found**；聚焦回归 App **31/31**、media_core **6/6**、media_core_live **19/19** 通过；全量 media_core **2669/2669**、media_core_live **58/58**、App **1242/1242** 通过（最终 App 03:33，退出码 0）。两仓 `git diff --check` 无空白错误，PureLive 仅四条既有 CRLF 提示。
  - **平台/主题与限制**：首态骨架沿用现有 desen_ui 与主题链；生命周期修复覆盖共享播放器调用面，不区分桌面、平板、手机或 TV。未构建 APK/桌面产物、未截图、未运行 UI、未做真实音频、TV/触控/读屏及多窗口视觉验收；回放断点续传与进程重启恢复仍未实现。本轮未提交、未推送。

- 2026-11-26：第五十六轮（请求代次、下载一致性与音乐窗口状态收口）⇒
  - **播放请求代次**：直播间连续切换清晰度时，旧解析、ingest、open 与 staged 回调不能覆盖新选择；过期 ingest 只关闭自己的 relay。IPTV 的 `engine_release_pending` 重试在延迟前后均校验请求代次。VOD/红果的路由暂停记录绑定具体 handle，返回时不会恢复已替换的播放器；三个播放页 F11 统一走窗口全屏。
  - **下载与录制**：红果续传仅接受起点正确的 206，服务器忽略 Range 返回 200 时截断重下；最终 `sink.close()` 成功才是提交点。VOD/红果成品文件名占用同时检查 `.part`。录制进度和磁盘空间检查在异步等待后复核 session 身份与 `startedAt`，旧场次迟到结果不能停止或覆盖新场次。
  - **播放器音频**：Bilibili 首选外部音轨的加载、选中或超时失败进入统一错误流，可选语言音轨仍 best-effort。红果切集/离页、IPTV 频道页、多窗格、房间/IPTV 预览和壁纸预览统一使用即时 `silencePlayer`，消除慢 open 队列期间的漏声窗口。
  - **下载列表性能**：VOD 下载页按任务 id、阶段、路径和目录缓存文件存在性，进度 tick 不再反复 stat；缺失成品的播放按钮禁用。音乐「仅可播放」筛选和播放队列同样排除已删除文件。
  - **音乐状态**：歌词面板改用 `sourceId + trackId` 身份，跨平台同 ID 不再复用旧 State。音频缓存盒从进程单例改为窗口级 Riverpod provider，设置页与当前播放来源共享同一实例；模块重建替换来源、离开时解除引用，目录或容量变化时重建缓存，加载期间环境变化不会安装过期实例。红果排队中的打开请求完整保留续播、恢复、降级和自动播放参数。
  - **配置/状态与文件**：无新增持久化配置、Slang key 或主题 token；请求代次、窗口缓存盒和文件状态缓存均属运行时状态。改动涉及直播房间/多窗/录制、IPTV、VOD、虎牙、红果、音乐、共享预览和对应测试；仓外 media_core_media_kit 补充外部音轨统一错误路径。保留其他并行未提交改动。
  - **验证**：PureLive `dart analyze lib`/`dart analyze test` 均 **No issues found**；音乐缓存 **15/15**、下载/录制聚焦 **47/47**、直播/多窗/红果/IPTV 聚焦 **80/80** 通过；App `flutter test --no-pub` 全量 **1248/1248** 通过（最终 03:44，退出码 0）。media_core_media_kit `dart analyze lib` 无问题，适配器测试 **20/20** 通过。`git diff --check` 仅既有 CRLF 提示。
  - **平台/主题与限制**：修复沿用现有 desen_ui、主题与响应式分支，未改导航或设置结构。未构建 APK/桌面产物、未截图、未运行 UI、未做真实音频、TV/触控/读屏及多窗口视觉验收；桌面歌词恢复、宽屏设置 section 同步和极窄屏歌单动作仍待后续有证据时处理。本轮未提交、未推送。

- 2026-11-26：第五十七轮（只读复查）⇒
  - **上轮闭环**：即时静音、请求代次、红果续传、文件名占用、录制进度/空间身份、VOD 文件状态缓存和窗口级缓存盒均有实现与调用；本轮未修改业务代码。
  - **确认遗漏**：录制 `_endAs` 先释放 claim 再无身份校验写 `setEnded`，同 ID 新场次可被旧结束写入覆盖；VOD/红果/虎牙 `_drop` 删除期间允许同 ID 重入，旧删除可按 ID 删掉新任务；运行中「删除并删文件」的意图未传给最终 drop，且停止后的本地 `stopped` 标记存在时间差，可能留下孤儿成品。
  - **音乐与播放器**：多个 `CachedTrackSource` 各自持有同目录缓存索引，但设置盒只保存最后一个，usage/clear 漏算漏删；歌词面板监听、加载参数与完成保护仍用裸 track.id；桌面歌词恢复与首轨恢复并发，存在冷启动时序缺口。VOD/虎牙/红果 autoplay 在音量/静音恢复前启动，存在短暂默认音量窗口。
  - **性能与界面**：三个 VOD/红果播放页直接 watch 完整下载队列，其他任务进度 tick 仍会重建播放页；transport tick 直接触发根 State 重建。IPTV 最近/指南的窄屏页级动作仍在页内固定行；空库进入指南无导入出口。音乐下载宽屏设置同时开 pane 并 push 子页。
  - **排除与边界**：五个播放页 dispose 中 `ref.read` 在框架 unmount 流程仍可读取，不构成已确认清理中断；IPTV 自动回退后的实际 sourceIndex 同步缺少仓外证据，不列已确认缺陷；本轮未运行 analyze/test/build，未截图或做设备验收，也未提交、未推送。上述发现只作为下一轮修复候选，不代表已经修复。

- 2026-11-26：第五十八轮（录制场次身份、下载删除与播放订阅收口）⇒
  - **录制旧场次隔离**：`setEnded`/`setStopped`/`setFailed` 强制校验 `expectedStartedAt`，监控、引擎、录制页、录像库和房间录制页全部传入当前场次身份；旧结束、失败和迟到进度不能覆盖同 ID 新场次。`_endAs` 在 recording claim 仍持有时提交结束状态，finalize 锁覆盖 take 改名、最终路径、后处理状态提交和 backend 关闭。
  - **下载删除一致性**：VOD/红果/虎牙队列引入任务代次、删除锁和运行中删文件意图；删除、暂停、恢复、排队调度和清理完成项均拒绝删除中任务。旧 run 只关闭自己的 client/sink，不再消费新 run 的停止标记或写入失败状态；最终关闭与改名前后检查停止意图，运行中「删除并删文件」会传到最终 drop。红果 stranded 合并在移动前后复核代次，失效结果不能回写新任务路径。
  - **音乐状态收口**：同目录、同容量的多个 `CachedTrackSource` 共享一个缓存与实时索引，usage/clear 去重；窗口级缓存盒 disarm 会清空来源并使在途加载失效，不影响另一窗口。歌词监听、请求和完成保护统一使用 `sourceId:trackId` 复合身份与请求代次；桌面歌词等待首轨状态真正发布后仅尝试恢复一次。
  - **播放性能与窄屏流程**：VOD 视频页、季页和红果播放页只 `.select` 当前分P/集数的下载投影，其他任务进度不再重建整页；完成/失败提示改用 `ref.listen`。IPTV 最近与指南在页宽 `<720` 时把页级动作发布到 AppShell 头部，宽屏保持原工具栏；指南空库补回播放列表导入和节目单导入入口。
  - **配置/状态与文件**：无新增持久化配置、Slang key、主题 token 或新文件；代次、删除意图、缓存盒和歌词代际均为运行时状态。修改 `recording_repository.dart`、`recorder_engine.dart`、`recording_monitor.dart`、录制页/录像库/房间录制页、三个下载控制器、`music_audio_cache.dart`、`music_playback.dart`、`music_lyric_panel.dart`、VOD 视频/季页、红果播放页、IPTV 最近/指南页，以及录制、三个下载和音乐缓存回归测试；保留其他并行未提交改动。
  - **验证**：本轮 Read/Edit 的 22 个 Dart 文件完成单文件格式化；`dart analyze lib test` **No issues found**；录制、VOD/红果/虎牙下载和音乐缓存聚焦回归 **60/60** 通过；App `flutter test --no-pub` 全量 **1255/1255** 通过（04:01，退出码 0）。`git diff --check` 无空白错误，仅四条既有 CRLF 替换提示。
  - **平台/主题与限制**：沿用现有 desen_ui、主题和响应式分支，未改导航或设置结构；IPTV 仅调整窄屏动作归属，宽屏布局不变。未构建 APK/桌面产物、未截图、未运行 UI、未做真实音频、多窗口、TV、触控或读屏验收；自动验证完成时尚未提交、推送，后续提交状态以 Git 历史为准。
  - **剩余候选**：后台播放 gate 快速切换恢复竞态、红果/VOD/虎牙 autoplay 早于音量/静音恢复，以及红果 stranded 合并 copy 中途异常时的目标文件清理仍待后续取证；桌面歌词冷启动恢复与窄屏动作仅有静态/自动测试验证，仍需真机确认。

- 2026-11-26：第五十九轮（播放恢复代次、autoplay 音频与红果合并收口）⇒
  - **后台播放**：`BackgroundPlaybackGate` 串行化 pause/resume，前台返回等待在途暂停完成；再次进入后台或 dispose 会使旧恢复代次失效，短暂 inactive 只取消尚未执行的延迟暂停。
  - **路由恢复**：VOD、红果、虎牙播放页的 push/pop 暂停绑定 handle 与请求代次；返回时等待暂停结束，期间换集、睡眠、离页或再次覆盖路由都不会让旧 play 覆盖新状态，迟到 play 会自行暂停。
  - **autoplay 音频**：VOD、红果创建 handle 时带模块音量和全局/页面静音状态，并在 open 前恢复；虎牙初次打开、切档和 seek 恢复重开前恢复模块音量，避免默认音量窗口。
  - **红果合并与删除**：stranded 文件先写隐藏临时副本、逐字节校验，再提交到重新选择的空闲正式名；新路径持久化成功后才删源文件，复制异常/取消清理临时文件。删除在等待合并前同步占位，清理、暂停、恢复和调度跳过待删除任务，合并提交后按新路径删除。
  - **配置/状态与文件**：无新增持久化配置、Slang key 或主题 token；代次、暂停串行队列、待删除占位和合并队列均为运行时状态。修改共享后台 gate、VOD/红果/虎牙播放页、虎牙播放控制器、红果下载控制器及对应回归测试；保留其他并行未提交改动。
  - **验证**：本轮 Read/Edit 的 8 个 Dart 文件完成单文件格式化；`dart analyze lib test` **No issues found**；后台 gate 与红果下载聚焦回归 **23/23** 通过；App `flutter test --no-pub` 全量 **1263/1263** 通过（03:50，退出码 0）。`git diff --check` 无空白错误，仅三条既有 CRLF 替换提示。
  - **平台/主题与限制**：修复沿用现有播放器、desen_ui、主题与响应式分支，未改导航或设置结构。未构建 APK/桌面产物、未截图、未运行 UI、未做真实音频、后台切换、多窗口、TV、触控或读屏验收；自动验证完成时尚未提交、推送，后续提交状态以 Git 历史为准。

- 2026-11-26：第六十轮（录制场次准备、跨窗口收尾锁与音乐恢复收口）⇒
  - **录制场次身份**：引擎取得 claim 后按当前存储行准备新场次，不再整行回写启动前快照；准备、running、失败和结束共用同一个 `startedAt`。自动监测在准备完成后仍要求订阅启用，用户暂停或替换场次时停止启动。
  - **订阅设置保留**：新场次显式清空上一场的路径、结束时间、文件统计、媒体信息、错误和后处理状态，同时保留最新房间信息、质量、检查节奏、启用开关和日程。running 构造也保留检查节奏，避免准备后的设置被默认值覆盖。
  - **跨窗口后处理**：finalize marker 解锁后保留在磁盘，探测锁也不再删除；所有窗口持续锁同一 inode，消除解锁与删标记之间换 inode 导致的双 finalizer 窗口。
  - **旧预览删除**：录像库删除回调先验证当前任务仍拥有预览所指路径，旧场次预览不能把新场次标成文件已删除。
  - **音乐恢复**：初始 `PlayerConfig` 携带模块音量与合成静音；适配器重建后补放音量/倍率。模块切换续播先登记待恢复 seek，首轨时长可用后再定位；播放、切歌、seek 等新意图使旧恢复失效。离页保存期望音量，避免尚无引擎句柄时被默认状态覆盖。
  - **下载重查**：音乐下载列表指纹恢复真实目录与重查代次插值，「重新检查」会使文件缺失缓存失效。
  - **配置/状态与文件**：无新增持久化配置、Slang key、主题 token 或新文件；期望音量、待恢复 seek 与重查代次均为运行时状态。修改录制仓库/引擎/监测/页面、音乐播放控制器/下载页及两项录制回归测试；保留其他并行未提交改动。
  - **验证**：本轮 Read/Edit 的 Dart 文件完成单文件格式化；`dart analyze lib test` **No issues found**；录制、finalize 锁和音乐设置聚焦回归 **23/23** 通过；App `flutter test --no-pub` 全量 **1267/1267** 通过（03:45，退出码 0）。`git diff --check` 本轮路径无空白错误。
  - **平台/主题与限制**：修复沿用现有 desen_ui、主题与响应式分支，未改导航或设置结构。未构建 APK/桌面产物、未截图、未运行 UI、未做真实音频、多窗口 finalize、TV、触控或读屏验收；自动验证完成时尚未提交、推送，后续提交状态以 Git 历史为准。
  - **剩余候选**：录像库对活动/后处理临时目录的删除门控、音乐冷恢复下载的 URL 解析续期、跨窗口音乐缓存 `.part` 清理，以及 IPTV 浮窗音频所有权/句柄释放仍需后续取证。

- 2026-11-26：第六十一轮（共享下载 UI 与背景失败态收口）⇒
  - **下载卡片契约**：`DownloadTaskCard` 开始渲染已有的 `leading`、`meta`、`badgeLabel`，并用共享 `downloadRowBadge` 替换仅依赖颜色的 8px 状态点；标题、清晰度、状态、进度与行尾动作保持同一卡片层级，四个下载管理器无需重复实现。
  - **窄屏队列头**：compact 只保留带文字的「更多」动作面板，宽屏才显示图标溢出菜单，消除同一组队列动词的两个入口；设置按钮同时要求回调与可访问标签，避免空标签断言。
  - **背景失败态**：letterbox 模糊副本与主图共用 frame/error builder，并遵循调用方 alignment；图片加载失败时模糊层也显示配置的 placeholder/fallback，不再绕过失败处理。
  - **配置/状态与文件**：无新增持久化配置、Slang key、主题 token 或新文件；仅修改 `download_task_card.dart`、`download_workspace.dart` 与 `image_background_view.dart`，保留其他并行未提交改动。
  - **验证**：三个 Dart 文件完成单文件格式化；App 与 `live_uikit_background` 的 `dart analyze lib test` 均 **No issues found**；背景包 **38/38**、App `flutter test --no-pub` 全量 **1267/1267** 通过（03:46，退出码 0）；`git diff --check` 本轮路径无空白错误。
  - **平台/主题与限制**：沿用现有 desen_ui、主题与响应式分支，未改导航或设置结构。未构建 APK/桌面产物、未截图、未运行 UI，未做窄屏/大字体、TV、触控或读屏视觉验收；自动验证完成时尚未提交、推送，后续提交状态以 Git 历史为准。
  - **剩余候选**：壳层窄屏动作溢出、平板设置导航双模式、设置缩窄丢 section、字体目录错误态、横屏聊天遮挡顶栏、竖屏全屏安全区、PiP 裁剪规划不一致，以及红果移除确认/IPTV 长源名仍需后续核实；相关页面已有并行改动，本轮未覆盖。

- 2026-11-26：第六十二轮（长标题、抽屉可达性与设置异常态收口）⇒
  - **直播详情**：房间标题取消三行省略，`AppPanel` 的滚动区现在可以完整阅读长标题，不再把关键房间信息截断。
  - **VOD 抽屉**：边缘抽屉门改用 `DsPressable`，保留 28px 视觉 tab 的同时提供 44px 命中区、按钮语义、键盘 Enter/Space 激活和焦点环。
  - **指南章节**：折叠行合并语义并发布当前 `expanded` 状态，读屏可以区分展开与收起，原有点击和箭头视觉不变。
  - **平板设置导航**：设置路由镜像 AppShell 的 `isTabletSized` 判定；手机/平板启用侧栏壳时不再叠加 stacked 分类页，TV 与窄桌面保持原分支。
  - **字体目录异常态**：中文/Google 目录失败时使用 `DsTable.errorView` 显示刷新失败和重试，不再伪装成无结果或继续展示旧行；重试只失效当前目录 provider。
  - **配置/状态与文件**：无新增持久化配置、Slang key、主题 token 或依赖；仅修改 `room_details.dart`、`vod_widgets.dart`、`guide_chapter.dart`、`settings_navigation.dart` 和 `font_manager_page.dart`，保留其他并行未提交改动。
  - **验证**：五个 Dart 文件完成局部格式化并撤回无关格式差异；App `dart analyze lib test` **No issues found**；`flutter test --no-pub` 全量 **1267/1267** 通过（03:17，退出码 0）；`git diff --check` 本轮路径无空白错误，仅既有 CRLF 替换提示。
  - **平台/主题与限制**：改动沿用现有 desen_ui、主题 token 和响应式分支，覆盖桌面、平板、手机与 TV 的导航判定，不区分浅色/深色/自定义主题。未构建 APK/桌面产物、未截图、未运行 UI，未做真实键盘、TV、触控、大字体或读屏验收；这些行为目前只有源码核对、静态分析和全量自动测试证据。
  - **剩余候选**：横屏聊天对非 TV 顶栏的 `endInset`、竖屏全屏 SafeArea、PiP 控件宽度与顺序规划、IPTV 窄屏长源名、红果移除确认、虎牙同构抽屉门及设置缩窄丢 section 仍需后续取证；相关文件已有并行改动，本轮未覆盖。

- 2026-11-26：第七十二轮（参考播放器对照、首帧计时与候选画面收口）⇒
  - **参考对照**：逐项核对 `E:\study\PureLive` 的会话、计时与直播 sweep，确认当前也是详情→清晰度→线路的串行链路；参考主要的 1 MiB/1 秒探测、6 秒缓存和低延迟写入参数已经在当前默认值中。没有证据支持盲降缓存档位或把站点请求强行并发，本轮不重复实现已有能力。
  - **首开计时纠偏**：旧实现把 `ready && hasSource` 当作原生输入已打开、把 `playing` 当作首开完成，且首帧监听在候选提交后才挂上。现改为监听真实的 `PlayerAdapterOpened`，从 staged 候选开始观察 `PlayerAdapterVideoFrameProgress`；其他平台以首个有效视频尺寸作为引擎能提供的最接近首帧信号。播放与首帧两个标记都到齐才结束计时，`total` 取两者较晚时间。
  - **候选画面状态**：`RoomState` 新增运行时 `pictureReady`，候选句柄切换时清零；监听器同时校验当前 open/source 与 `state.player` 的句柄身份，旧候选排队到达的事件不能把新线路标成有画面。候选已出画而 sweep 仍在验证位置时，不再覆盖“连接中/慢”卡片；慢连接计时同步停用，失败、缓冲、暂停和离线状态仍按原优先级显示。
  - **窄窗 UI**：沉浸胶囊的身份文本外层增加 `Flexible`，让长房间标题先收缩省略，避免挤掉返回、关注和详情按钮并触发 RenderFlex 溢出；不改标题数据来源或既有信息层级。
  - **配置与主要文件**：无新增持久化配置、Slang key、依赖或主题 token；`pictureReady` 与候选监听均为房间运行态。修改 `room_controller.dart`、`room_open_timing.dart`、`room_status.dart`、`room_page_lifecycle.dart`、`player_surface_top_bar.dart` 和 `room_open_timing_test.dart`；仓外 media_core 与本轮其他并行工作树内容未修改。
  - **验证**：六个 Dart 文件完成单文件格式化；候选身份补强后再次 `dart analyze lib test` **No issues found**；`flutter test --no-pub test/live/room_open_timing_test.dart` **9/9** 通过；`git diff --check` 本轮路径无空白错误，`pubspec.yaml`/`pubspec.lock` 无本轮依赖变化。
  - **平台/主题与限制**：改动沿用现有播放器、desen_ui 和浅色/深色/自定义主题；胶囊收缩只影响沉浸顶栏。未构建 APK/桌面产物、未截图、未运行 UI、未做真实线路切换、手机/TV、触控、大字体、读屏或视觉验收；静态分析与计时单测不能证明真实秒开或流畅度提升。
  - **剩余性能边界**：当前 `RoomOpenTiming` 仍从 `RoomController.open()` 起算，路由/窗口创建与首帧绘制不在区间内；仓外 live sweep 的原生 initialize/open 尚未套 18 秒 open 超时，失败线路仍串行尝试，Windows 首帧心跳来自约 1 秒一次的 estimated-vf-fps。后续应以当前构建的真实点击到首帧、切线和持续卡顿日志取证，再决定是否调整媒体核或并发策略。提交范围仅限上述文件，其他并行改动保留在工作树。

- 2026-11-26：第七十三轮（直播候选原生打开有界化与失败线路续试）⇒
  - **打开截止时间**：仓外 `media_core_live` 的同引擎换线与 staged 引擎候选统一经过 `_openCandidate`，使用 `LiveWatchdogs.sourceReadyTimeout`（默认 18 秒）限制原生 `open()`；`Duration.zero` 保持完全关闭。打开与位置验证是两个先后不重叠的独立窗口，不把 18 秒误称为两阶段共享总预算。
  - **卡住句柄退役**：超时后先取消当前句柄的控制器订阅、清理 source/watchdog/capability，再调用 `PlayerKernel.release`。release 会同步摘除内核注册并立即标记句柄 disposed；原生 dispose 仍可能排在被卡住的 open 后，因此后台完成，不再让下一条线路额外等待释放超时。
  - **回归覆盖**：新增 staged open 挂起后下一引擎成功、同引擎第二条线 open 挂起后正确耗尽并清空句柄、零截止时间不干预慢 open 三项测试；同时断言旧原生调用迟到完成不会夺回当前播放或重新注册句柄。
  - **配置与主要文件**：无新增持久化配置、Slang key、依赖、主题 token 或 App 业务状态。仓外修改 `live_playback_sweep.dart`、`live_playback_controller.dart`、`live_watchdogs.dart`、`live_playback_controller_test.dart`；PureLive 仅回填本台账。外部仓库已有其他并行修改，本轮未整文件覆盖、未提交或推送。
  - **验证**：控制器定向测试 **23/23**、`media_core_live` 全包 **62/62** 通过；`flutter analyze --no-pub` 与 App `dart analyze lib test` 均 **No issues found**；本轮四个外部文件完成单文件格式化，两个仓库 `git diff --check` 无空白错误（PureLive 仅既有 CRLF 替换提示）。
  - **平台/主题与限制**：修复位于共享直播播放核，不区分桌面、平板、手机、TV 或浅色/深色/自定义主题。未构建 APK/桌面产物、未截图、未运行 UI，未做真实慢线路、原生 open 挂起、切线、音频、多窗口、TV、触控、大字体或读屏验收；自动测试不能证明真实秒开或流畅度已经提升。
  - **剩余边界**：原生 initialize/create 仍不受该 open 截止时间保护；候选线路依旧串行，连续多个卡住候选会分别消耗打开窗口，并受内核在途释放数量上限约束。Windows 首帧信号仍约为 1 秒分辨率，真实点击到首帧仍应结合当前构建日志取证。

- 2026-11-26：第七十四轮（播放器内核初始化截止时间与未注册句柄退役）⇒
  - **初始化有界化**：`PlayerKernel.create()` 现在将既有 `PlayerConstants.initializationTimeout`（15 秒）应用到 `handle.initialize()`。直播 sweep 使用无 source 的 `kernel.create(preferredBackend: engine)`，此前不会进入 create 自带的 18 秒 open 超时，因此这是独立于第七十三轮的另一条启动卡死边界。
  - **超时退役**：初始化超时时句柄尚未注册，不能走 `kernel.release`；改为立即调用 `handle.dispose()` 同步标记退役，但不等待原生销毁。原生 initialize 无法取消，dispose 会排在其后，迟到初始化完成后先经过既有 500ms 静音保护，再执行 adapter/runtime 释放。后台释放失败记录 lifecycle warning，调用方只收到原始 `TimeoutException`。
  - **错误路径保持**：非超时初始化异常仍等待 `handle.dispose()` 完成后才抛出，保持原有清理契约；超时句柄不进入内核 registry，也不占用 pending-release 槽位。
  - **回归覆盖**：新增真实时钟测试验证 15 秒截止、超时返回时无注册句柄且原生 dispose 尚未执行、首个 initialize 仍挂起时第二个 create 已成功、旧 initialize 迟到完成后旧 adapter 被销毁且 healthy 句柄继续独占 registry、release 后 registry 清空。
  - **配置与主要文件**：无新增持久化配置、Slang key、依赖、主题 token 或 App 业务状态。仓外修改 `player_kernel.dart`，新增 `test/kernel/player_kernel_initialization_timeout_test.dart`；`player_handle.dart` 仅复核既有同步退役与静音契约，最终无本轮差异。PureLive 仅回填本台账，外部仓库未提交或推送。
  - **验证**：初始化超时及既有 kernel dispose race 定向测试 **2/2** 通过；`media_core` 全包 **2671/2671** 通过；`media_core_live` 全包 **62/62** 通过且分析无问题；media_core `lib` 分析与 App `dart analyze lib test` 均 **No issues found**；本轮两个外部目标 `dart analyze` 无问题，`git diff --check` 无空白错误。media_core 全包分析仍报告并行未入库测试 `kernel_dispose_race_test.dart` 的两条 info，本轮未改动该文件。
  - **平台/主题与限制**：修复位于共享播放器内核，不区分桌面、平板、手机、TV 或浅色/深色/自定义主题。未构建 APK/桌面产物、未截图、未运行 UI，未做真实原生 initialize 挂起、慢引擎、切线、音频、多窗口、TV、触控、大字体或读屏验收；自动测试不能证明真实秒开或流畅度已经提升。
  - **剩余边界**：同步 adapter factory `create()` 与 create 之前的 source 解析不在该截止时间内；候选线路仍串行，多个永久挂起的原生 open 仍可能陆续触及内核在途释放上限。Windows 首帧信号仍约为 1 秒分辨率，真实点击到首帧仍应结合当前构建日志取证。

- 2026-11-27：第七十五轮（Bilibili 音频恢复、音乐沉浸页、哔哩哔哩音乐源与 IPTV 频道交互）⇒
  - **Bilibili 音频恢复**：UGC/PGC 外挂音轨报错时先逐个尝试 `VodDashAudio.backupUrls`，始终保留原 DASH 视频 essence、codec、bitrate、quality 与请求头；备用地址耗尽或不支持合成后才请求合流兼容流，UGC/PGC 合流参数统一修正为 `fnval=0`。恢复使用请求代次与播放器 handle 身份防止旧错误落到新会话，并保留播放位置、音量、静音、倍率及 UGC audio-only 状态。本轮没有新增 FFmpeg 拼接器或依赖。
  - **音乐沉浸页**：音乐播放页自行承载窗口拖动区和窗口按钮，路由不再叠加独立 `WindowCaptionBar`；无歌曲时仍保留关闭、拖动与窗口控制，macOS inset 控件场景不重复绘制。
  - **哔哩哔哩音乐源**：在既有音乐架构注册 `bilibili` source，复用搜索、播放器、队列、音频缓存、歌词补全、下载解析、Bilibili client 与 LRCLIB；接入音乐区榜单、第一 P 时长、DASH/FLAC 音频与 64K/132K/192K/杜比/Hi-Res 音质映射。共享音质胶囊按 source 档位映射并显示实际服务音质，没有另建播放内核或 lx script 适配。
  - **IPTV 播放与频道交互**：播放/暂停按钮按 `canPause`/`canPlay` 分流，不再在播放中继续调用 resume；频道列表选中态改读真正达到播放的 `iptvNowPlayingProvider`，起播失败不再被标成当前播出频道。其他频道点击请求播放，当前频道再次点击打开随频道节目单；节目单回放通过既有 `IptvPlayLaunch` 记录进入播放页。频道行增加 `DsContextMenuRegion`，支持长按、右键、键盘菜单与读屏菜单，提供节目单和收藏动作。
  - **配置、状态与主要文件**：无新增持久化配置、Slang key、主题 token 或依赖；音频恢复代次、备用地址下标和频道交互均属运行时状态。修改 `modules/vod/widgets/vod_media_source.dart`、`modules/vod/pages/vod_video_page.dart`、`modules/vod/pages/vod_season_page.dart`、`packages/live_vod/lib/src/bilibili_vod_client.dart`、`modules/music/pages/music_player_page.dart`、`modules/music/controller/sources/music_source_bilibili.dart`、`modules/music/controller/music_source.dart`、`modules/music/widgets/music_quality_pill.dart`、`app/routing/router/app_router.dart`、`modules/iptv/pages/iptv_play_page.dart`、`modules/iptv/pages/iptv_page.dart`、`modules/iptv/views/iptv_panels.dart` 与对应测试。共享工作树其他未提交改动保留，未整文件覆盖或回退。
  - **验证**：App `dart analyze lib` 与 `dart analyze test` 均 **No issues found**；IPTV 全量 **76/76**、Bilibili 音乐源 **6/6**、音乐模块 **238/238**、VOD media source **3/3**、`live_vod` Bilibili client **29/29** 通过；最新 IPTV/Bilibili 音乐定向 **9/9** 通过。仅格式化本轮明确点名的两个测试文件，共享源码采用窄编辑；`git diff --check` 本轮 IPTV 路径无空白错误。本轮未重跑 App 全量测试。
  - **平台/主题与限制**：沿用现有 desen_ui、主题和响应式分支，IPTV 频道行覆盖 320px 窄屏，音乐页覆盖桌面自绘/inset caption 分支；逻辑不区分浅色、深色或自定义主题。未构建 APK/桌面产物、未截图或运行 UI，真实 Bilibili 外挂音轨/合流清晰度、音乐播放/缓存/下载/歌词/榜单、IPTV 暂停/节目单回放/长按菜单及 TV、触控、读屏效果仍待运行时验收。自动测试不能替代这些验收；本轮未提交或推送，仓外 media_core 没有本轮修改。

- 2026-11-27：第七十六轮（跨模块路由覆盖恢复、下载提交点与录制后处理保护）⇒
  - **路由覆盖生命周期**：IPTV、VOD 单片/剧集、虎牙视频和红果播放页统一按 RouteAware 处理覆盖暂停与返回恢复；只订阅一次当前 route，以覆盖深度保证嵌套路由仅在最外层返回时恢复。保存原始播放意图，opening 期间被覆盖时抑制自动播放，transport 在缓冲后开始播放也补暂停；恢复前等待 pause 完成并校验 handle、频道和请求代次，睡眠与销毁时清理全部恢复状态。虎牙 controller 的 `open()` 增加 `autoPlay` 参数，红果继续尊重显式不自动播放意图。
  - **Bilibili DASH 重开**：单片与剧集页在每次 DASH、合流和备用音频 open 前撤销旧 adapter 事件订阅并递增 attempt 代次，同时清除旧 pending 标记；没有 source/open token 的迟到 `PlayerAdapterErrorEvent` 不再把新会话误判为音频恢复失败。恢复播放仍考虑路由覆盖状态。
  - **下载提交点**：VOD、虎牙和红果在 `.part` rename 成功后立即发布 done，再检查停止请求，避免停止恰好落在提交点时留下完成文件却显示暂停；pause 也不再把已完成任务改回 paused。VOD/虎牙失败重试在扩展名不变时复用旧目标路径，不再遗失既有 `.part`。
  - **弹幕 sidecar 与删除**：VOD 按任务串行写入最新弹幕 sidecar，每个写任务都复核 generation、删除和停止状态；删除等待在途 sidecar 写完并继续拒绝迟到写入。下载仍沿用 generation token、删除重入保护和 retry timer 清理。
  - **录制后处理**：RecorderEngine 新增 `isPostProcessing(taskId)`，正常停止和 finalize 重试均跟踪在途任务。页面删除前若仍在合并、改名或归档，保留任务行并提示处理中，不再让 `RecordingLibrary.deleteTake()` 因任务记录提前消失而失去活动目录保护。
  - **音乐音质复核**：共享音质胶囊把 `flac24bit` 视为可满足 lossless，实际服务档位高于请求档位时不再误标降级。匿名实测 Bilibili `fnval=16` 与 `4048` 的音频 id 集合一致，抽样未见 Dolby/FLAC 解锁证据，本轮保留 `audioStreams()` 的 `fnval=16`，不把登录态高音质推测当作修复。
  - **配置与主要文件**：无新增持久化配置、Slang key、依赖或主题 token；路由深度、播放意图、pause generation、adapter attempt、sidecar 写锁和 finalize 任务集合均为运行时状态。修改 `modules/iptv/pages/iptv_play_page.dart`、`modules/vod/pages/vod_video_page.dart`、`vod_season_page.dart`、`modules/huya/pages/huya_video_player_page.dart`、`controller/huya_video_playback.dart`、`modules/hongguo/pages/hongguo_player_page.dart`、`modules/vod/controller/vod_downloads.dart`、`modules/huya/controller/huya_downloads.dart`、`modules/hongguo/controller/hongguo_downloads.dart`、`modules/music/widgets/music_quality_pill.dart`、`modules/live/recorder/engine/recorder_engine.dart`、`recorder/pages/recorder_page.dart` 与本台账；`music_source_bilibili.dart`、`bilibili_vod_client.dart` 仅只读复核。
  - **验证**：下载聚焦回归 **38/38**、播放器/录制聚焦回归 **60/60** 通过；App `dart analyze lib`、`dart analyze test` 均 **No issues found**；`flutter test --no-pub` 全量 **1310/1310** 通过（03:26，退出码 0）。仅格式化本轮明确修改的 Dart 文件，仓外 media_core 无本轮修改。
  - **多平台与限制**：播放、下载和录制修复沿用 desen_ui 与浅色/深色/自定义主题，不按设备复制配置；路由恢复覆盖页面级弹窗和嵌套路由源码路径。未构建 APK/桌面产物、未截图或运行 UI，未做真实外挂音轨、慢缓冲期间覆盖/返回、停止与 rename 并发、sidecar 删除并发、录制 finalize、多窗口、TV、触控、大字体或读屏验收。自动测试不能替代这些验收；共享工作树其他并行改动保留。本轮已隔离提交为 `ec544124e`，推送因本地代理不可用及 GitHub 直连被重置而失败，本地提交完整保留。

- 2026-11-27：第七十七轮（路由恢复过期暂停与录制后处理重入防护）⇒
  - **路由恢复纠正暂停**：IPTV、VOD 单片/剧集、虎牙视频和红果播放页在 `resume/play` 返回后执行纠正性 `pause` 前，除既有 generation 外还要求覆盖深度确实增加。返回页面后用户立即切台/切集时，旧恢复 continuation 不再暂停新媒体；只有 resume 期间又推入覆盖路由且仍处于覆盖状态时才补暂停。
  - **录制后处理重入**：`RecorderEngine.start()` 在任务仍处于本进程 finalize 集合时直接返回 `busy`，避免停止后的旧归档尚未完成就重新开录，进而让缓存清理按新任务行误判旧成果的活动状态。
  - **未采纳候选**：同名并发下载争路径缺少稳定复现条件；Dart 单线程中从同步选取目标到写入 `_items` 没有让出点，现有磁盘检查与队列写入之间不会插入另一任务，因此本轮不引入额外路径锁。
  - **配置与主要文件**：无新增持久化配置、Slang key、依赖或主题 token；仅复用既有路由深度、generation 与 finalize 任务集合。修改 `modules/iptv/pages/iptv_play_page.dart`、`modules/vod/pages/vod_video_page.dart`、`vod_season_page.dart`、`modules/huya/pages/huya_video_player_page.dart`、`modules/hongguo/pages/hongguo_player_page.dart`、`modules/live/recorder/engine/recorder_engine.dart` 与本台账。
  - **验证**：App `dart analyze lib`、`dart analyze test` 均 **No issues found**；播放/录制聚焦回归 **17/17**、录制仓库 **11/11** 通过；`flutter test --no-pub` 全量 **1310/1310** 通过（04:51，退出码 0）。仅格式化本轮明确修改的六个 Dart 文件，仓外 media_core 无本轮修改。
  - **多平台与限制**：修复位于共享播放与录制运行时，不区分桌面、平板、手机、TV 或浅色/深色/自定义主题。未构建 APK/桌面产物、未截图或运行 UI，未做真实覆盖返回与切台并发、录制 finalize 期间重开、多窗口、TV、触控、大字体或读屏验收；自动测试不能替代这些运行时验收。

- 2026-11-27：第七十八轮（开放 API 歌词身份、在途请求与缓存清理竞态）⇒
  - **歌词身份与过期响应**：`MusicOpenApi` 的歌词缓存键改用既有 `musicTrackKey`（`sourceId:id`），不同平台的同名歌曲不再共用一份歌词。每次加载前清空旧文档，完成后仅在缓存键仍等于捕获键时提交；切歌、切偏移或刷新 revision 后，迟到的旧响应返回空文档，不能覆盖新状态或污染后续缓存。
  - **歌词缓存写入串行化**：`CachedLyricSource` 对 forget、clear 与网络回写共用进程内 Future 队列，每次读改写都在前一次提交完成后读取最新存储，避免多个平台包装器并发完成时丢失其他歌曲。clear 同步递增 generation，清空前发起的网络请求即使之后完成也不会把已删除歌词重新写回；清空操作排在已有写入之后，保证最终状态为空。
  - **音频缓存清理容错**：Windows 播放器仍占用某个缓存文件时，`MusicAudioCache.clear()` 捕获该文件的 `FileSystemException` 并继续删除其余文件，不再因首个占用文件中断整批清理。文件仍被占用时保留磁盘文件，但缓存账目仍按用户清理动作清空；没有引入自动重试或活动文件保护锁。
  - **回归覆盖**：新增开放 API 同 ID 跨平台歌词、慢旧请求不能覆盖新歌曲、清空期间在途歌词不复活、两首歌乱序完成均保留，以及音频缓存单文件占用不阻断其余清理五项测试。
  - **配置与主要文件**：无新增持久化配置、Slang key、依赖或主题 token；generation、歌词写入队列和缓存键均属运行时状态。修改 `modules/music/controller/playback/music_open_api.dart`、`modules/music/controller/sources/music_source_cache.dart`、`modules/music/controller/sources/music_audio_cache.dart`、`test/music/music_open_api_test.dart`、`music_browse_and_lyric_wrappers_test.dart`、`music_audio_cache_test.dart` 与本台账。
  - **验证**：本轮六个 Dart 文件完成单文件格式化；App `dart analyze lib`、`dart analyze test` 均 **No issues found**；聚焦回归 **37/37**、音乐模块全套 **243/243**、App 全量测试 **1315/1315（3 分 47 秒）** 通过。仓外 media_core 无本轮修改。
  - **多平台与限制**：修复位于音乐运行时，不区分桌面、平板、手机、TV 或浅色/深色/自定义主题。未构建 APK/桌面产物、未截图或运行 UI，未做真实跨平台同 ID 歌曲、快速切歌、清缓存同时播放、多窗口、TV、触控、大字体或读屏验收；自动测试不能替代这些运行时验收。

- 2026-11-27：第七十九轮（小窗排队交接、音乐引擎重建与下载归属）⇒
  - **小窗排队交接**：`FloatingVideoWindow.show()` 在同一帧插入前收到多次请求时，最新 handoff 覆盖旧 handoff，两个调用方共享同一次插入结果；被替换的旧请求收到带恢复位置的 `onClose`，重入 dismiss 也不会清空尚未返回的 completer。
  - **开放 API 命令与重配**：`/play`、`/pause` 分别调用显式 `playCurrent()`、`pause()`，不再用 toggle 表达暂停；新增 `MusicOpenApiPlayer` 命令接口，隔离播放器具体实现。开关、端口和 LAN 监听改为串行同步，配置变化会停止、重启或重绑当前端点，并保留一次延迟重试。
  - **音乐引擎重建**：Riverpod 3 在依赖变化时保留 Notifier 实例，原 `late final` 引擎字段会在模块切换重建时二次赋值崩溃。本轮把引擎与运行字段改为可变并按 build 代次重置，旧 state、媒体会话、EQ、桌面歌词和恢复回调均校验 generation；启动恢复音量、静音和倍速不再覆盖用户刚发出的新意图。
  - **缓存与下载归属**：窗口作用域的音频缓存 box 销毁时取消所有在途下载，取消令牌同时作为提交所有权，旧会话不能向新会话提交或删除文件。下载自动换源后，初次解析与过期重解析都使用实际音频来源及匹配歌曲读取歌词，避免音频与歌词来自不同平台。
  - **截图文件名**：共享播放器截图时间戳从秒精度提升到毫秒精度，避免连续截图在同一秒互相覆盖。
  - **回归覆盖**：新增同帧小窗 handoff 替换、开放 API play/pause 非 toggle、音频缓存 disarm 取消在途传输三项回归。
  - **配置与主要文件**：无新增持久化配置、Slang key、依赖或主题 token；generation、同步 Future 队列、下载取消令牌和解析来源归属均为运行时状态。修改 `shared/player/floating_video.dart`、`shared/player/player_screenshot.dart`、`modules/music/controller/music_source.dart`、`modules/music/controller/library/music_downloads.dart`、`modules/music/controller/playback/music_open_api.dart`、`music_playback.dart`、`modules/music/controller/sources/music_audio_cache.dart`、`test/shared/floating_video_test.dart`、`test/music/music_open_api_test.dart`、`music_audio_cache_test.dart` 与本台账。
  - **验证**：本轮 Dart 文件仅做单文件格式化；App `dart analyze lib test` 为 **No issues found**；聚焦回归 **31/31**、音乐加共享播放器回归 **248/248**、App 全量测试 **1318/1318（3 分 48 秒）** 通过。仓外 media_core 无本轮修改。
  - **多平台与限制**：修复位于共享播放与音乐运行时，不区分桌面、平板、手机、TV 或浅色/深色/自定义主题。未构建 APK/桌面产物、未截图或运行 UI，未做真实模块切换重建、开放 API 热重绑、自动换源下载歌词、缓存取消同时重开、多窗口、TV、触控、大字体或读屏验收；自动测试不能替代这些运行时验收。

- 2026-11-27：第八十轮（开放 API 实时传输、小窗生命周期与音乐资源竞态）⇒
  - **开放 API 实时传输**：SSE 响应关闭缓冲并启用 chunked 编码，事件能立即到达订阅方；每个订阅保存各自的状态快照，新接入的订阅不会因旧订阅已经推进而漏掉下一次状态变化。订阅断开时移除对应响应。
  - **小窗交接与销毁**：同一帧内多次交接时，旧调用方收到 `false`、最新调用方收到 `true`，被替换 handoff 执行一次关闭回调；`OverlayEntry` 尚未首次构建时也能移除，避免插入后立即替换留下不可达覆盖层。关闭回调按实例身份清理，旧视图销毁不能清掉新窗口的回调。
  - **小窗启动顺序**：先应用倍率、静音和恢复位置，再开始播放；启动任一步失败或视图提前销毁时，静音并释放尚未发布的 handle。七个 VOD 类入口统一通过 `PlayerKernel.create(source:)` 打开，避免绕过注册句柄的失败释放路径，并保留 IPTV 倍率与静音。
  - **共享截图**：同一个播放器 handle 的并发截图共享一次在途捕获，完成后清除单飞记录；保留 media_core 截图写入、格式和失败日志链路。
  - **音乐缓存与同步**：音频缓存关闭所有已取得的流式响应，包括非 200 和流读取失败路径，并保持取消令牌的提交所有权检查。同步连接引入代次守卫，旧认证/连接结果不能关闭新客户端或覆盖新状态；断开完成后也不会把更新的连接改回 idle。
  - **回归覆盖**：新增 SSE 双订阅独立快照、小窗插入未构建即替换、同帧交接返回值、缓存拒绝响应关闭、最新同步连接获胜五项回归。
  - **配置与主要文件**：无新增持久化配置、Slang key、依赖或主题 token；SSE 快照、小窗回调身份、截图单飞和同步代次均为运行时状态。修改 `shared/player/floating_video.dart`、`player_screenshot.dart`、`features/media_preview/media_preview_page.dart`、`modules/vod/pages/vod_video_page.dart`、`vod_season_page.dart`、`modules/huya/pages/huya_video_player_page.dart`、`modules/hongguo/pages/hongguo_player_page.dart`、`modules/iptv/pages/iptv_play_page.dart`、`modules/live/archive/archive_player_page.dart`、`modules/music/controller/playback/music_open_api.dart`、`controller/sources/music_audio_cache.dart`、`controller/sync/music_sync.dart`、对应四个测试文件与本台账。
  - **验证**：当前完整工作树 App `dart analyze lib test` 为 **No issues found**；`flutter test --no-pub` 全量 **1322/1322** 通过，小窗聚焦 **4/4** 通过；隔离补丁 `git diff --check` 无空白错误。尝试在 HEAD 独立工作树复验时，基线缺少当前工作树已有的背景模块与 live_device 等源码/包，分析和 Flutter 测试分别因依赖解析与 native-assets 工具崩溃未能完成，因此不声称隔离基线验证通过。
  - **多平台与限制**：修复位于共享播放和音乐运行时，不区分桌面、平板、手机、TV 或浅色/深色/自定义主题。未构建 APK/桌面产物、未截图或运行 UI，未做真实小窗快速切换、播放中交接、SSE 长连接、同步重连、缓存并发、多窗口、TV、触控、大字体或读屏验收；截图单飞尚无独立回归。自动测试不能替代这些运行时验收，仓外 media_core 无本轮修改。

- 2026-11-27：第八十一轮（歌单搬移目标校验与本地列表同步审查）⇒
  - **歌单搬移防丢失**：`moveTracks` 在源歌单不存在、目标歌单不存在或两者相同时直接返回，不再出现目标无效仍删除源歌曲、同歌单搬移清空选中歌曲的数据丢失路径。输入迭代器先固化为列表，再加入目标和移出源，避免一次性序列被重复消费。
  - **审查未采纳项**：本地列表与 LX 同步的 `pushListsChanged()` 目前没有调用方，但直接接自动推送需要同时处理远端覆盖回环、断线状态和批量编辑合并；本轮不把未验证的监听广播接入。恢复下载任务缺少重试重解析器，受仓外 `media_core_audio` 固定 Git 版本 API 限制，未做依赖逃逸或破坏 resume 语义的重建。
  - **配置与主要文件**：无新增持久化配置、Slang key、依赖或主题 token。修改 `modules/music/controller/library/music_playlists.dart`、`test/music/music_playlists_test.dart` 与本台账。
  - **验证**：两个修改文件单文件格式化无变化；App `dart analyze lib test` 为 **No issues found**；歌单聚焦回归 **6/6** 通过。本轮未重跑 App 全量测试。
  - **多平台与限制**：修复位于音乐数据层，不区分桌面、平板、手机、TV 或浅色/深色/自定义主题。未构建 APK/桌面产物、未截图或运行 UI，未做真实批量搬移、失效目标竞态、同步自动推送、恢复下载重试、多窗口、TV、触控、大字体或读屏验收；自动测试不能替代这些运行时验收，仓外 media_core 无本轮修改。

- 2026-11-27：第八十二轮（LX 同步 WebSocket 生命周期与在途调用收口）⇒
  - **传输状态监听**：`MusicSyncClient` 从 `messages` 的 `onDone/onError` 改为订阅 `LiveWebSocketClient.states`，按 connecting、connected、reconnecting、disconnected 处理连接阶段；握手失败后传输会自行重连，因此 `connect()` 返回时额外校验 socket 身份与实际连接状态，不再把失败握手报告为已连接。
  - **在途调用释放**：主动断开、远端掉线进入重连以及重连耗尽时，立即用错误完成所有 pending RPC，调用方无需等待 30 秒超时；消息与状态订阅统一取消，旧 socket 的迟到状态事件不能关闭或覆盖新连接。
  - **回归覆盖**：新增拒绝握手不误报 connected、主动断开立即释放在途调用、远端掉线重连期间立即释放在途调用三项本地 HTTP/WebSocket 集成回归。
  - **配置与主要文件**：无新增持久化配置、Slang key、依赖或主题 token；socket 订阅、身份守卫与 pending 调用清理均属运行时状态。修改 `modules/music/controller/sync/music_sync_client.dart`、`test/music/music_sync_test.dart` 与本台账。
  - **验证**：两个修改文件单文件格式化无变化；音乐同步聚焦回归 **20/20** 通过；App `dart analyze lib test` 为 **No issues found**；`flutter test --no-pub` 全量 **1326/1326（4 分 34 秒）** 通过。仓外 media_core 无本轮修改。
  - **多平台与限制**：修复位于音乐同步运行时，不区分桌面、平板、手机、TV 或浅色/深色/自定义主题。未构建 APK/桌面产物、未截图或运行 UI，未做真实 LX 服务握手、长连接重连、同步中主动断开、多窗口、TV、触控、大字体或读屏验收；自动测试不能替代这些运行时验收。

- 2026-11-27：第八十三轮（LX 同步坏帧隔离与迟到消息守卫）⇒
  - **坏帧失败路径**：客户端解压或解析远端帧失败时不再让异常从 WebSocket 监听器逃逸，而是按服务端既有策略关闭当前会话、释放在途调用并报告 failed；非法 JSON、损坏的 `cg_` gzip/base64 都走同一路径。
  - **消息身份守卫**：消息监听器携带创建时的 socket 身份，处理帧前先确认它仍是当前连接；旧连接迟到的帧不会重置新连接的空闲计时、回答 RPC 或关闭新会话。
  - **回归覆盖**：新增本地服务发送非法 JSON 后同步会话进入 failed 且 `isConnected` 为 false 的集成回归，测试进程无未捕获监听异常。
  - **配置与主要文件**：无新增持久化配置、Slang key、依赖或主题 token；帧解析错误与 socket 身份均属运行时保护。修改 `modules/music/controller/sync/music_sync_client.dart`、`test/music/music_sync_test.dart` 与本台账。
  - **验证**：两个修改文件单文件格式化无变化；音乐同步聚焦回归 **21/21** 通过；App `dart analyze lib test` 为 **No issues found**；`flutter test --no-pub` 全量 **1327/1327（4 分 08 秒）** 通过。仓外 media_core 无本轮修改。
  - **多平台与限制**：修复位于音乐同步运行时，不区分桌面、平板、手机、TV 或浅色/深色/自定义主题。未构建 APK/桌面产物、未截图或运行 UI，未做真实 LX 服务坏帧注入、断网重连、多窗口、TV、触控、大字体或读屏验收；自动测试不能替代这些运行时验收。

- 2026-11-27：第八十四轮（LX 同步回调生命周期收口）⇒
  - **回调归属与失效**：`MusicSyncClient` 为每次调用记录生成的函数回调名及独立失效计时器；调用超时、发送失败、主动断开、远端掉线重连或最终关闭时，同步移除 pending 与回调表项，迟到或旧连接回调不再执行。重连清理覆盖已正常响应但按协议暂存的回调，不只清理尚未完成的调用。
  - **协议保守边界**：核对 LX Desktop 客户端与固定版本 `message2call@0.1.3` 后，没有“收到响应即可删除函数槽”的完成帧依据；正常响应后回调保留至该调用超时，避免误杀响应后仍可能到达的合法回调；若连接先失效则立即清理，保留时间有界。
  - **回归覆盖**：新增调用超时后迟到回调不执行、旧 socket 断开重连后其回调不能在新连接执行、已响应调用暂存的回调也随重连失效三项本地 HTTP/WebSocket 集成回归；均以客户端 barrier 确认回调帧已按序处理后再断言。
  - **配置与主要文件**：无新增持久化配置、Slang key、依赖或主题 token；回调归属与失效计时器均属运行时状态。修改 `modules/music/controller/sync/music_sync_client.dart`、`test/music/music_sync_test.dart` 与本台账。
  - **下载恢复边界**：复核 `MusicDownloadQueue.restore` 与重试路径后确认，恢复仅把未完成任务标为 paused，不保存也不接受重新解析闭包；App 侧没有可安全挂接 resolver 的公开 API。重启后若旧取流地址失效，恢复任务仍可能重试失败，需在外部 media_core 提供恢复解析扩展点后才能闭环，本轮未修改该包。
  - **验证**：两个修改文件单文件格式化无变化；音乐同步聚焦回归 **24/24** 通过；App `dart analyze lib test` 为 **No issues found**；App 全量测试 **1330/1330** 通过。仓外 media_core 已有并行改动，本轮未修改。
  - **多平台与限制**：修复位于音乐同步运行时，不区分桌面、平板、手机、TV 或浅色/深色/自定义主题。未构建 APK/桌面产物、未截图或运行 UI，未做真实 LX 服务回调、长连接重连、多窗口、TV、触控、大字体或读屏验收；自动测试不能替代这些运行时验收。

- 2026-11-27：第八十五轮（LX 同步异步写入确认收口）⇒
  - **协议依据**：核对 LX Desktop 列表与屏蔽规则的客户端 handler，`list_sync_set_list_data`、`dislike_sync_set_list_data` 都是先等待本地写入再返回的 async handler；客户端提前确认会让服务端在落盘完成前结束同步阶段。
  - **异步 RPC 生命周期**：`MusicSyncClient` 统一等待普通与 push handler 返回的 Future，工作完成后才发送结果或 null 确认；同步异常与异步异常均转换为 RPC error，避免未捕获 Future。所有确认与错误帧继续绑定发起请求时的 socket 身份，旧连接的迟到工作不会写入 replacement socket。
  - **双向写入边界**：列表与屏蔽规则覆盖写入直接返回写入 Future；远端 overwrite action 同样等待实际本地写入，不提前结束 push action。本轮未把仍无生产调用者的本地变更推送接入新流程，也未改变 recent/favourites/playlists 的既有顺序写入。
  - **回归覆盖**：新增普通 async handler 与 async push handler 都在 gate 完成后才确认、旧 socket 的迟到 async reply 不进入新 socket 两项本地 HTTP/WebSocket 集成回归；以 barrier 请求确保后续帧已按序处理后再断言。
  - **配置与主要文件**：无新增持久化配置、Slang key、依赖或主题 token；异步处理与 socket 身份均属运行时状态。修改 `modules/music/controller/sync/music_sync_client.dart`、`modules/music/controller/sync/music_sync.dart`、`test/music/music_sync_test.dart` 与本台账。
  - **验证**：三个修改文件仅做单文件格式化；音乐同步聚焦回归 **26/26** 通过；App `dart analyze lib test` 为 **No issues found**；App 全量测试 **1332/1332（4 分 16 秒）** 通过；`git diff --check` 通过。仓外 media_core 已有并行改动，本轮未修改。
  - **多平台与限制**：修复位于音乐同步运行时，不区分桌面、平板、手机、TV 或浅色/深色/自定义主题。未构建 APK/桌面产物、未截图或运行 UI，未做真实 LX 服务并发写入、落盘失败、长连接重连、多窗口、TV、触控、大字体或读屏验收；自动测试不能替代这些运行时验收。

- 2026-11-27：第八十六轮（LX 同步回调应答与 RSA 安全随机）⇒
  - **协议依据**：核对 `message2call@2.0.3` 的数组 wire 后确认，远端执行本地函数回调后必须收到 `CALLBACK_RESPONSE`；回调返回值、异步结果或异常都需要回帧，已释放回调则返回 `${name} is released`。本轮修复 PureLive 当前采用的 2.x wire，不把旧版 0.1.3 对象协议混入同一解析路径。
  - **回调应答**：`MusicSyncClient` 现在等待同步与异步回调完成并发送类型 3 结果帧；同步异常和 Future 异常转为回调 error，未知回调返回 released error。回调应答绑定原 socket 身份，旧连接的迟到结果不会写入 replacement socket。
  - **RSA 随机源**：首次授权生成 RSA 密钥时的 Fortuna 种子由时间戳线性同余改为 `Random.secure()` 的 32 字节系统安全随机数，避免同一时间窗内授权密钥可预测。
  - **回归覆盖**：新增回调结果应答、异步回调完成后才应答、异常与已释放回调错误应答、旧 socket 的迟到异步回调不进入新连接四项本地 HTTP/WebSocket 集成回归；wire 单测补充 `replyError` 帧断言。
  - **配置与主要文件**：无新增持久化配置、Slang key、依赖或主题 token；回调结果与 socket 身份均属运行时状态。修改 `modules/music/controller/sync/music_sync_client.dart`、`music_sync_codec.dart`、`music_sync_wire.dart`、`test/music/music_sync_test.dart` 与本台账。
  - **验证**：四个修改文件仅做单文件格式化；音乐同步聚焦回归 **30/30** 通过；App `dart analyze lib test` 为 **No issues found**；App 全量测试 **1336/1336（4 分 25 秒）** 通过；`git diff --check` 通过。仓外 media_core 无本轮修改。
  - **多平台与限制**：修复位于音乐同步运行时，不区分桌面、平板、手机、TV 或浅色/深色/自定义主题。未构建 APK/桌面产物、未截图或运行 UI，未做真实 LX 服务回调、授权失败、长连接重连、多窗口、TV、触控、大字体或读屏验收；本地 LX Desktop checkout 锁定的 0.1.3 与当前 2.x wire 不同，真实跨版本互通仍需以目标服务版本抓包联调，自动测试不能替代这些运行时验收。

- 2026-11-27：第八十七轮（LX 同步音质保真、畸形列表容错与服务端异步确认）⇒
  - **音质往返**：`musicSyncTrackFromInfo` 现在读回 `meta.qualitys`，已知 id 映射为共享 `MusicQuality` 常量，未知 id 保留为通用档位；同步后的 recent、favourites 与歌单歌曲不再丢失音质信息，音质徽标、列表说明和 lx 取流梯度可继续读取原有数据。
  - **畸形列表容错**：`musicSyncApplyListData` 对 `userList` 采用与 `defaultList`、`loveList` 一致的类型检查，远端返回对象、字符串或数字时按空歌单处理，不再因单个畸形字段抛 `TypeError` 中断整个列表同步。
  - **服务端异步确认**：`MusicSyncServerSocket` 的 push handler 改为可返回 Future，列表与屏蔽覆盖动作等待实际写入及广播完成后再回包；同步异常和异步异常转为 RPC error，避免服务端在落盘前误报成功。
  - **回归覆盖**：新增已知与未知音质 id 往返、三类畸形列表字段容错、异步 push 在 gate 完成后才确认且后续快请求先返回、异步 push 失败返回 RPC error 四项回归；后两项使用本地 HTTP/WebSocket，不依赖延时猜测。
  - **配置与主要文件**：无新增持久化配置、Slang key、依赖或主题 token。修改 `modules/music/controller/sync/music_sync_data.dart`、`music_sync_server.dart`、`test/music/music_sync_test.dart`、`music_sync_server_test.dart` 与本台账。
  - **验证**：四个 Dart 文件仅做单文件格式化；音乐同步聚焦回归 **47/47** 通过；App `dart analyze lib test` 为 **No issues found**；App 全量测试 **1340/1340（4 分 22 秒）** 通过；`git diff --check` 通过。仓外 media_core 无本轮修改。
  - **多平台与限制**：修复位于音乐同步运行时，不区分桌面、平板、手机、TV 或浅色/深色/自定义主题。未构建 APK/桌面产物、未截图或运行 UI，未做真实 LX 服务音质同步、畸形 payload、落盘失败、多客户端广播、多窗口、TV、触控、大字体或读屏验收；下载恢复仍受外部 `media_core_audio` 缺少 resolver 重绑 API 限制，本轮未修改该包。

- 2026-11-27：第八十八轮（Bilibili 搜索入口、追番分页、UP 主页信息与详情操作区）⇒
  - **搜索用户入口**：用户搜索结果接入既有 `/vod/u/:mid` 路由，不再只展示不可进入的文本行；空或非法 mid 不发起跳转。
  - **追番真实分页**：`vodFollowingSeasonsProvider` 替换为按番剧/影视类型独立的 `vodFollowingProvider`，个人页在首次进入、切换类型和刷新时驱动首屏，滚动继续加载下一页。请求携带正确 `vmid`、`type`、`ps`、`pn`，按季去重、识别无新增页并终止；账号变化、重复刷新及迟到响应均有代次守卫，游客直接显示空状态。
  - **UP 主页信息与关注**：UP 页接入新增的 `vodUploaderCardProvider`，优先展示平台返回的昵称、头像、粉丝数、签名和投稿数，视频列表数据作为回退；可写账号显示关注/已关注按钮，失败沿用本地化提示。搜索入口与主页详情形成闭环。
  - **详情操作区响应式**：点赞、投币、收藏、稍后再看和分享保持胶囊组；容器宽度达到 720px 时下载按钮固定在同行最右，窄容器时下载按钮换到独立行并右对齐，移除 `Wrap` 内 `Spacer` 的不确定布局。
  - **配置与主要文件**：无新增持久化配置、Slang key、依赖或主题 token；追番分页、请求代次与页面标签均为运行时状态。修改 `modules/vod/controller/vod_controller.dart`、`modules/vod/controller/vod_social.dart`、`modules/vod/pages/vod_personal_page.dart`、`vod_search_page.dart`、`vod_uploader_page.dart`、`vod_video_page.dart`、`modules/vod/widgets/vod_widgets.dart`、`test/vod/vod_dynamics_test.dart`、`packages/live_vod/lib/src/bilibili_vod_client.dart` 与本台账；共享工作树其他并行改动保留，未整文件覆盖或回退。
  - **验证**：`dart analyze lib` 为 **No issues found**；`flutter test test/vod` **78/78** 通过；本轮精确路径 `git diff --check` 无空白错误。测试覆盖游客追番、首屏参数、第二页追加去重、分页终止与影视类型；未重跑 App 全量测试。
  - **多平台与限制**：沿用现有 desen_ui、主题和响应式分支，详情操作区覆盖 720px 内容宽阈值，不复制 TV 四列布局，也未改写播放器。未构建 APK/桌面产物、未截图或运行 UI，未做真实搜索跳转、账号切换并发、追番长列表、关注写入、窄屏/大字体/TV/触控/读屏验收；自动测试不能替代这些运行时验收。DASH 音视频轨下载仍作为独立后续任务，本轮未实现。

- 2026-11-27：第八十九轮（Bilibili 分页重试、账号代次与社交写入互斥）⇒
  - **搜索与 UP 分页**：搜索和 UP 投稿控制器监听 VOD 客户端身份变化并递增请求代次，旧账号迟到响应不再写入新状态。搜索失败后的重试保留已加载列表并重试失败页；UP 页新增独立 `retry()`，第二页失败不再退回第一页。UP 分页遇到空页或完全重复页立即终止，避免平台仍声明 `hasMore` 时无限加载。
  - **社交写入互斥**：点赞和关注在请求进行中忽略重复触发，杜绝快速连点产生乱序写请求；失败仍回滚并抛出本地化提示。账号切换同时递增代次，旧写入的失败回滚不会覆盖新账号状态。
  - **UP 头部窄屏降级**：内容宽小于 420px 时，头像与资料保持一行，关注按钮换到独立一行并右对齐；较宽容器维持原有横向布局。复用既有 desen_ui 头像、徽标、按钮与主题 token，不新增配置或依赖。
  - **配置与主要文件**：无新增持久化配置、Slang key、依赖或主题 token；请求代次、写入互斥和分页终止均为运行时状态。修改 `modules/vod/controller/vod_controller.dart`、`modules/vod/controller/vod_social.dart`、`modules/vod/pages/vod_uploader_page.dart`、`test/vod/vod_search_and_pgc_test.dart`、`vod_signed_walks_test.dart`、`vod_social_test.dart` 与本台账；共享工作树其他并行改动保留。
  - **验证**：六个 Dart 文件仅做单文件格式化；App `dart analyze lib` 为 **No issues found**；`flutter test test/vod` **85/85** 通过。新增回归覆盖搜索失败页重试、搜索与 UP 账号切换迟到响应、UP 重复页终止、UP 失败页重试，以及点赞/关注在途重复触发。
  - **多平台与限制**：沿用现有 desen_ui 和浅色/深色/自定义主题；UP 头部按 420px 内容宽降级，桌面和平板保持原布局。未构建 APK/桌面产物、未截图或运行 UI，未做真实账号切换、慢网连续点击、窄屏/大字体/TV/触控/读屏验收；自动测试不能替代这些运行时验收。Bilibili 原生收藏、投币、评论写入和 DASH 轨下载仍不在本轮范围。

- 2026-11-27：第九十轮（Bilibili 评论账号隔离、失败页重试与下载主动停止）⇒
  - **评论账号隔离**：评论控制器监听 VOD 客户端身份变化并递增账号代次；切换账号时清空按视频缓存的评论，旧账号迟到的成功或失败响应均不能写回新状态。每个视频持有独立请求代次，不同视频的并发读取互不取消。
  - **评论分页与排序**：新增独立 `retry()` 重试当前失败页并保留此前评论，失败不再把 `hasMore` 置为 false；手动刷新仍从第一页开始。评论请求进行中禁用最热/最新切换，避免点击被静默忽略。
  - **下载主动停止**：暂停或删除正在运行的任务时，连接关闭异常不再发布为失败，也不调度自动重试；最终状态统一由停止意图转为 paused 或删除记录。排队任务移除无效的“恢复”按钮，仅暂停任务显示该操作。
  - **配置与主要文件**：无新增持久化配置、Slang key、依赖或主题 token；评论账号/请求代次和下载停止意图均为运行时状态。修改 `modules/vod/controller/vod_social.dart`、`modules/vod/controller/vod_downloads.dart`、`modules/vod/pages/vod_video_page.dart`、`modules/vod/pages/vod_downloads_page.dart`、`test/vod/vod_social_test.dart` 与本台账；下载页其他并行改动未纳入本轮。
  - **验证**：五个 Dart 文件仅做单文件格式化；App `dart analyze lib` 为 **No issues found**；`flutter test --no-pub test/vod` **88/88** 通过；本轮精确路径 `git diff --check` 无空白错误。新增评论失败页重试、第二页失败保留第一页、跨视频并发读取、账号切换迟到响应四项回归。
  - **多平台与限制**：修复位于 VOD 运行时和现有下载操作行，不区分桌面、平板、手机、TV 或浅色/深色/自定义主题。未构建 APK/桌面产物、未截图或运行 UI，未做真实账号切换、慢网暂停/删除、排队任务操作、大字体/TV/触控/读屏验收；自动测试不能替代这些运行时验收。Bilibili 原生收藏、投币、评论写入和 DASH 轨下载仍不在本轮范围。

- 2026-11-27：第九十一轮（Bilibili 本地收藏可靠性、点赞数字与统计胶囊适配）⇒
  - **收藏写入可靠性**：本地收藏由乐观更新改为串行写入队列，快速连续点击按调用顺序持久化，写失败回滚到操作前状态并抛出错误；视频详情页与个人页不再把失败提示为成功。批量删除合并为一次最终快照写入，减少磁盘写入并避免中间状态。
  - **点赞数字即时一致**：详情页记录首次读取的点赞基线，点赞或取消点赞后按当前状态与基线差值更新展示数字；请求失败回滚时数字同步恢复，初始读取完成前不开放点赞，避免把未知状态当成未点赞。
  - **大字号统计胶囊**：`VodStatPill` 取消固定 32px 高度，改为最小高度 32px 加纵向留白；默认字号保持原观感，系统大字号或自定义字体放大时胶囊随内容增高。
  - **配置与主要文件**：新增 `vod.saveFailed` 中英文 Slang key；无新增持久化配置、依赖或主题 token，收藏队列和点赞基线均为运行时状态。修改 `modules/vod/controller/vod_library.dart`、`modules/vod/pages/vod_video_page.dart`、`modules/vod/pages/vod_personal_page.dart`、`modules/vod/widgets/vod_widgets.dart`、`test/vod/vod_library_history_test.dart`、VOD 中英文文案、生成翻译文件与本台账；个人页既有 `PageLayoutScope` 并行改动未纳入本轮。
  - **验证**：五个 Dart 文件仅做单文件格式化并重新生成 Slang；App `dart analyze lib` 为 **No issues found**；`flutter test --no-pub test/vod` **91/91** 通过。新增收藏写失败回滚、快速连续切换顺序、批量删除单次写入三项回归。
  - **多平台与限制**：收藏与点赞逻辑不区分平台或主题；统计胶囊沿用现有 desen_ui token，默认尺寸不变并允许大字号自然增高。未构建 APK/桌面产物、未截图或运行 UI，未做真实存储失败、慢网点赞、大字体/TV/触控/读屏验收；自动测试不能替代这些运行时验收。Bilibili 原生收藏、投币、评论写入和 DASH 轨下载仍不在本轮范围。

- 2026-11-27：第九十二轮（Bilibili 失败页重试、搜索状态恢复、下载暂停与历史写入竞态）⇒
  - **搜索失败页重试**：新搜索请求开始时固定当前页码，首页失败不再沿用旧查询的下一页；重试始终请求失败页并保留已加载结果。
  - **影视目录重试**：新增独立 `retry()` 重试失败 cursor，失败不再永久关闭 `hasMore`；目录错误按钮从整目录刷新改为失败页重试，已加载剧集保留。
  - **搜索页状态恢复**：重新进入页面时恢复上次结果类型、排序和时长条件；同一页面实例的路由查询词变化会更新输入框并在帧后重新搜索。
  - **社交与下载停止**：旧关注读取失败不再清除读取期间产生的乐观关注状态；运行中任务暂停立即发布并持久化 paused，暂停全部会取消尚未执行的自动重试定时器。
  - **历史清空可靠性**：历史保存、单条删除和清空串行执行；清空扫描存储中的全部进度键并取消待刷新，不再遗漏页面防抖刷新期间刚写入的记录。
  - **配置与主要文件**：无新增持久化配置、Slang key、依赖或主题 token。修改 `modules/vod/controller/vod_controller.dart`、`vod_pgc.dart`、`vod_social.dart`、`vod_downloads.dart`、`vod_library.dart`、`modules/vod/pages/vod_search_page.dart`、`vod_pgc_page.dart`、`test/vod/vod_search_and_pgc_test.dart`、`vod_social_test.dart`、`vod_downloads_test.dart`、`vod_library_history_test.dart` 与本台账；两个页面既有 `PageLayoutScope` 并行改动未纳入本轮。
  - **验证**：本轮 Dart 文件仅做单文件格式化；App `dart analyze lib` 为 **No issues found**；`flutter test --no-pub test/vod` **97/97** 通过。新增回归覆盖替换搜索首页失败、影视失败 cursor、搜索页恢复所需状态、旧关注读取失败、运行中暂停落库、暂停全部取消重试和立即清空新历史。
  - **多平台与限制**：修复位于 VOD 控制器和现有页面状态，不区分桌面、平板、手机、TV 或浅色/深色/自定义主题。未构建 APK/桌面产物、未截图或运行 UI，未做真实搜索深链、慢网暂停、进程中断恢复、大字号/TV/触控/读屏验收；自动测试不能替代这些运行时验收。DASH 音视频轨下载仍不在本轮范围。

- 2026-11-27：第九十三轮（Bilibili 设置搜索、下载续传竞态、DASH 下载边界与账号状态隔离）⇒
  - **设置搜索补全**：VOD 播放页已有的“接口类型”和“App 扫码登录”加入设置搜索目录，可按接口、扫码、账号等关键词直达对应页面。
  - **下载暂停续传**：单个恢复和全部恢复会先等待旧 worker 释放停止信号，再重新入队，避免刚暂停就恢复时第二次下载被旧停止信号吞掉；worker 结束仅清理自己对应的句柄。
  - **DASH 下载边界**：站点回退为仅含视频 essence 的 `m4s` 地址时明确失败，不再把无声视频保存为完成任务；完整音视频轨下载仍留待后续实现。
  - **账号状态隔离**：B 站账号切换会推进动态列表请求代次，旧账号迟到的响应不能写入新账号界面。
  - **会话写入一致性**：App 扫码登录的 access token、device id 和 UID 通过同一偏好事务写入，避免崩溃或部分写入形成半套会话。
  - **下载连接清理**：HttpClient 清理不再依赖任务代次仍为当前值，弹幕 sidecar 写入未完成时清理已完成任务也不会漏关连接。
  - **配置与主要文件**：无新增持久化配置、Slang key、依赖或主题 token。修改 `modules/vod/controller/vod_app_login.dart`、`vod_downloads.dart`、`vod_social.dart`、`features/settings/surface/settings_search.dart`、`test/vod/vod_downloads_test.dart`、`vod_social_test.dart`、`test/features/settings/settings_search_test.dart` 与本台账；设置搜索文件中的多词搜索、弹幕显示方式及 IPTV 目录并行改动未纳入本轮。
  - **验证**：本轮 Dart 文件仅做单文件格式化；App `dart analyze lib test` 为 **No issues found**；`flutter test --no-pub test/vod test/features/settings/settings_search_test.dart` **111/111** 通过。新增回归覆盖暂停后立即恢复、DASH 单 essence 拒绝落盘、账号切换动态隔离，以及接口类型和 App 扫码登录搜索命中。
  - **多平台与限制**：修复位于 VOD 控制器、登录会话和设置搜索层，不区分桌面、平板、手机、TV 或浅色/深色/自定义主题。未构建 APK/桌面产物、未截图或运行 UI，未做真实慢网恢复、进程中断、大字号/TV/触控/读屏验收；自动测试不能替代这些运行时验收。DASH 音视频轨下载仍不在本轮范围。

- 2026-11-27：第九十四轮（Bilibili 登录轮询、个人页状态隔离、TV 方向键与进度条无障碍）⇒
  - **扫码登录轮询**：二维码登录的轮询增加在途保护，慢请求不会与下一次定时轮询重叠；重新发起登录时推进请求代次，旧二维码或旧轮询的迟到响应不能覆盖新尝试。
  - **个人页账号状态**：账号读取中显示骨架，读取失败显示可重试错误，不再把加载或失败误报为未登录；稍后再看、历史、收藏等个人页签切换时清除共享的页内筛选，避免筛选条件跨页签泄漏。
  - **TV 方向键**：剧集播放页在 TV 上把方向键交还焦点遍历；控制栏隐藏时方向键仅负责唤醒控制栏。桌面键盘继续保留左右seek、上下音量、逗号/句号倍率与统计信息快捷键。
  - **进度条键盘与读屏**：自定义 Bilibili 进度条可聚焦，左右方向键每次 seek 5 秒，Home/End 跳到首尾，并暴露焦点环与读屏增减语义；鼠标、触控和拖动逻辑保持不变。
  - **下载生命周期**：下载失败后的自动重试调度先检查 provider 是否仍挂载，避免已释放容器中的迟到失败路径读取无效 `Ref`。
  - **配置与主要文件**：无新增持久化配置、Slang key、依赖或主题 token。修改 `modules/vod/widgets/vod_app_login_dialog.dart`、`modules/vod/pages/vod_personal_page.dart`、`vod_season_page.dart`、`modules/vod/widgets/vod_player_chrome.dart`、`modules/vod/controller/vod_downloads.dart`、`test/vod/vod_seek_bar_test.dart` 与本台账；个人页和剧集页既有 `PageLayoutScope` 并行改动未纳入本轮。
  - **验证**：本轮六个 Dart 文件仅做单文件格式化检查，结果为 0 个变更；App `dart analyze lib test` 为 **No issues found**；`flutter test --no-pub test/vod` **101/101** 通过。新增回归覆盖进度条聚焦、方向键、Home/End seek；下载测试覆盖 provider 释放后的迟到失败路径。
  - **多平台与限制**：修复位于 VOD 页面、登录弹窗、播放器控件和下载控制器，不区分桌面、平板、手机、TV 或浅色/深色/自定义主题。未构建 APK/桌面产物、未截图或运行 UI，未做真实扫码慢网、账号读取失败、TV 遥控器、触控、大字号和读屏验收；自动测试不能替代这些运行时验收。DASH 音视频轨下载仍不在本轮范围。

- 2026-11-27：第九十五轮（Bilibili 分P/剧集完成状态、播放面板与账号切换）⇒
  - **完成状态语义**：普通视频只有当前分P是最后一个分P且触发播放结束事件才标记整稿完成；非末P结束写入下一P的零秒续播点，不再因接近片尾或打开最后一集而提前完成。剧集同样只有最后一集播放结束才标记整季完成，切集、周期保存和页面释放不会覆盖该完成标记。
  - **分P跳过点隔离**：片头、片尾按 `bvid + cid` 独立保存，读取优先使用当前分P记录并回退旧版整稿记录；切换分P时重新加载对应跳过点。
  - **控制面板生命周期**：剧集页清晰度、倍率和选集面板打开时取消闲置隐藏，关闭后重新计时；已有计时器不能在面板打开后把面板一起隐藏。
  - **账号状态隔离**：动态页的账号读取失败与未登录分离，提供失败提示和重试；推荐、热门浏览源随 VOD 客户端变化重置，旧账号迟到的响应不能写入新账号。
  - **配置与主要文件**：无新增 Slang key、依赖或主题 token；跳过点偏好键由整稿键扩展为分P键，并保留旧键读取。修改 `modules/vod/controller/vod_controller.dart`、`vod_library.dart`、`modules/vod/pages/vod_page.dart`、`vod_season_page.dart`、`vod_video_page.dart`、`test/vod/vod_library_history_test.dart`、`vod_signed_walks_test.dart` 与本台账；三个页面既有 `PageLayoutScope` 并行改动未纳入本轮。
  - **验证**：本轮 Dart 文件仅做单文件格式化；App `dart analyze lib test` 为 **No issues found**；`flutter test --no-pub test/vod` **104/104** 通过，全量 `flutter test --no-pub` **1367/1367** 通过。新增回归覆盖分P跳过点隔离与旧记录回退、零秒续播点、最后一集不等于已完成、账号切换浏览源与迟到响应隔离。
  - **多平台与限制**：修复位于 VOD 状态与播放页逻辑，不区分桌面、平板、手机、TV 或浅色/深色/自定义主题。未构建 APK/桌面产物、未截图或运行 UI，未做真实多P播放结束、剧集切集、账号慢请求、TV 遥控器和读屏验收；自动测试不能替代这些运行时验收。DASH 音视频轨下载仍不在本轮范围。

- 2026-11-28：第九十六轮（Bilibili 分区/影视账号重载、PGC 迟到响应与下载重试设置）⇒
  - **页面账号重载**：已打开的分区页和影视页监听 VOD 客户端变化，自动重新请求当前分区或当前影视分类；页面只观看 feed 状态，不直接承担请求代次管理。
  - **PGC 账号隔离**：影视控制器随账号变化清空全部目录缓存并推进请求代次，旧账号的成功或失败响应不能覆盖新账号目录。
  - **下载重试设置**：关闭自动重试会取消全部等待中的重试计时器；调整重试间隔会按新值重新排程；计时器触发时再次校验当前重试次数上限。
  - **参考结论**：核对 newBV 的 `PlayRelated` 与 PGC 详情链路后确认影视详情不产生相关视频列表，空列表会回退下一集/结束行为；PureLive 现有下一集语义已一致，未新增猜测接口或把 PGC `aid` 当作 `bvid` 请求。
  - **配置与主要文件**：无新增持久化配置、Slang key、依赖或主题 token。修改 `modules/vod/controller/vod_pgc.dart`、`vod_downloads.dart`、`modules/vod/pages/vod_regions_page.dart`、`vod_pgc_page.dart`、`test/vod/vod_search_and_pgc_test.dart`、`vod_downloads_test.dart`、新增 `test/vod/vod_account_reload_test.dart` 与本台账；两个页面既有 `PageLayoutScope` 并行改动未纳入本轮。
  - **验证**：本轮 Dart 文件仅做单文件格式化；App `dart analyze lib test` 为 **No issues found**；`flutter test --no-pub test/vod` **109/109** 通过。新增回归覆盖分区/影视页面账号切换重载、PGC 旧账号迟到成功隔离、关闭重试取消等待、缩短间隔后按新值重试。
  - **多平台与限制**：修复位于 VOD 页面监听、控制器状态和下载计时器，不区分桌面、平板、手机、TV 或浅色/深色/自定义主题。未构建 APK/桌面产物、未截图或运行 UI，未做真实账号切换慢网、电视遥控器、触控、大字号和读屏验收；自动测试不能替代这些运行时验收。DASH 音视频轨下载仍不在本轮范围。

- 2026-11-28：第九十七轮（Bilibili App 解析回退、分享身份、小窗完成状态、下载并发与记录上限）⇒
  - **App 解析回退**：UGC/PGC 在 App 返回成功但没有可播放视频时抛 `VodFailure`，让既有页面回退到 Web；FLAC、Dolby 只接受 HTTP 地址，无效高级音轨不再伪装成有声结果或阻止静音视频播放。
  - **影视身份与空态**：PGC 搜索保留 `episode_id`，预览优先使用该集；详情没有集数时返回空而不是抛异常；`nav` 只有明确的 `-101` 才视为游客，风控、无效 JSON 和异常数据继续作为失败处理。
  - **分享与小窗完成状态**：普通视频分享保留当前分P，影视分享指向当前剧集；共享小窗关闭时回传其最终 position/duration，并在距结尾 5 秒内传递完成状态，VOD 历史与追剧据此保存，替换尚未显示的小窗不会误报完成。
  - **下载并发释放**：删除运行中任务后，无论清理成功或失败都会补启动下一项；提高并发上限时扣除已在运行的任务数，避免超额启动。
  - **记录持久化裁剪**：历史与追剧写入后从 `StoragePrefs.snapshot()` 读取权威集合再删除最旧记录，不再依赖可能滞后 800ms 的内存 state；并发突发写入仍保留各自上限。
  - **配置与主要文件**：无新增持久化配置、Slang key、依赖或主题 token；共享小窗 callback 扩展可选 `duration`/`completed`。修改 `packages/live_vod/lib/src/bilibili_app_client.dart`、`bilibili_vod_client.dart`、`test/bilibili_app_client_test.dart`（新增）、`test/bilibili_vod_client_test.dart`，App 的 `modules/vod/controller/vod_library.dart`、`vod_downloads.dart`、`modules/vod/pages/vod_video_page.dart`、`vod_season_page.dart`、`modules/vod/widgets/vod_preview.dart`、`lib/shared/player/floating_video.dart`、五个既有小窗消费者、`test/vod/vod_library_history_test.dart`、`vod_downloads_test.dart`、`test/shared/floating_video_test.dart` 与本台账；并行布局、PiP 与其他模块改动未纳入本轮。
  - **验证**：本轮 Dart 文件仅做单文件格式化；App `dart analyze lib test` 为 **No issues found**；`flutter test --no-pub test/vod test/shared/floating_video_test.dart` **118/118** 通过；`packages/live_vod` 的 `dart analyze lib test` 为 **No issues found**，`dart test` **73/73** 通过。新增回归覆盖 App 空 ladder、无效高级音轨、游客错误码、PGC 集数身份、并发记录裁剪、删除任务释放 lane、动态并发上限和小窗完成阈值。
  - **多平台与限制**：解析、队列与持久化修复不区分平台或主题；共享小窗关闭逻辑统一服务桌面、平板、手机和 TV 宿主。未构建 APK/桌面产物、未截图或运行 UI，未做真实 App/Web 回退、扫码风控、分享打开、小窗真实进度、TV 遥控器、触控和读屏验收；自动测试不能替代这些运行时验收。账号登录竞态、newBV 试看流与 DASH 音视频轨下载留待后续独立任务。
