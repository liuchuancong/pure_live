# 直播间 · 播放页 · 音乐 UI 优化方案（已确认）

按 `docs/ai/PRODUCT_DEVELOPMENT_STANDARD.md` 的强制流程（§4）产出，用户于 2026-11-01 确认：先落地 A（直播间 + 播放页），并允许使用能力位门控的新控件（截屏、统计层、音频输出设备）。本页记录方案与逐项状态，避免分批之间丢失上下文。

## 现状审计（2026-11-01，只读核对）

- 播放页：顶栏（清晰度/线路/画面适配）、底栏（播放、静音、音频模式、音量、录制、投屏、全屏/PiP）、聊天三页签、6 个快捷键、加载/缓冲/离线/失败/回放结束状态齐全；薄在状态呈现、诊断信息与桌面空间利用。
- 音乐：歌曲表、推荐/精选、音质胶囊、队列/歌词/评论面板、四种播放模式、全局迷你条齐备；对照 §18 缺专辑/歌手浏览、迷你条右侧缺音效与输出设备、播放页无模式切换、歌词不能点行跳转、队列无分组、频谱单一。

## 控件位置分析（2026-11-01，按含义重新分区）

先给每个控件定性，再决定它属于哪个区域——而不是把"能放的地方"填满。

| 控件 | 含义 | 类别 | 位置 |
| --- | --- | --- | --- |
| 返回/关闭 | 离开这个房间 | 身份 | 顶部左 |
| 主播 · 标题 | 这是谁、播什么 | 身份 | 顶部，占满剩余宽度、单行省略 |
| 直播中 / 回放徽标 | 现在是不是实时 | 状态 | 顶部（标题右侧） |
| 观看数 | 人气 | 状态 | 顶部，≥480 才显示 |
| 播放/暂停 | 最基础的播放控制 | 播放 | 底部最左（TV 首焦点） |
| 静音 | 同上，必须单手可达 | 播放 | 底部第二（任何宽度都保留） |
| 音量 | 精确调节 | 播放 | 底部左侧，桌面宽度 |
| 音频模式 | 只留声音 | 播放 | 底部左侧，桌面宽度 |
| 直播进度线 | ~~延迟与缓冲示意~~ **2026-11-01 删除**：直播没有可定位时间轴，画成"能拖的样子"是误导；缓冲/延迟改由画面状态层与统计层（`I`）表达 | — | 无（条隐藏时只留 14 px 透明唤醒带 `_IdleWakeStrip`） |
| 弹幕显示开关 | 覆盖层是否显示，不改流 | 覆盖层偏好 | 底部右簇起点 |
| 清晰度 | 改**正在播的东西** | 流参数 | 底部右簇 |
| 线路 | 同上 | 流参数 | 底部右簇（多于一条才出现） |
| 画面适配 | 画面怎么填满盒子 | 视图 | 底部右簇 |
| 截屏 | 从当前画面取一帧 | 捕获 | 底部右簇，桌面宽度（能力位门控） |
| 录制 | 开始/停止录制；**正在录是画面的状态** | 呈现 | **顶部右簇**（录制中换成闪烁指示 + 计时），窄档进 ⋮ |
| 投屏 | 送到别的屏 | 呈现 | **顶部右簇**（有流时），窄档进 ⋮ |
| 窗口全屏（桌面） | 浏览器式窗口占满 | 窗口 | 底部最右簇 |
| 竖屏全屏（竖流） | 手机竖屏铺满 | 窗口 | 底部最右簇 |
| 全屏 | 呈现模式 | 窗口 | 底部最右 |
| 画中画 | 把画面搬进小窗 | 呈现 | **顶部右簇**，窄档进 ⋮ |
| 房间详情、切台、方向、睡眠、自动录像、刷新、分享、外部打开、复制链接、重试、统计、截屏、关闭、**录制、画中画、投屏** | 房间级动作，低频 | 房间动作 | ⋮ 菜单（页头与沉浸式各一个入口，同一份列表） |

分区规则（2026-11-01 第二次修订）：**顶部＝身份 + 状态 + 呈现**——左是离开，中是"这是谁"，右簇依次是 直播中/回放 → 观众数 → 录制（或闪烁指示+计时）→ 画中画 → 投屏 → ⋮；**底部＝播放 + 播什么**——左半播放/静音/音量/音频模式，右半弹幕开关、清晰度/线路/适配、截屏、窗口全屏/竖屏全屏/剧院/全屏；**房间级动作全部进 ⋮**，呈现三动词在窄档也退到 ⋮；**面板从触发它的按钮向上弹出**。依据：录制/画中画/投屏改的都是"画面在哪儿、以什么形态在"，与直播中、观众数同属"此刻的状态"，需要一眼看见；清晰度/线路/适配改的是"正在播什么"，与播放控制同条。与主流的差异要说明白：PC 播放器（含 B 站自有播放器的 `bottom-left/center/right` 结构）通常把画中画放在底栏右下，本项目按用户决定把它与录制、投屏一起上到右上，形成"呈现状态簇"。

宽度档位（每档是下一档的超集）：

- `<460`：顶栏＝返回｜标题省略｜（录制中才有的）闪烁点｜⋮；底栏＝播放、静音、（分隔）弹幕、清晰度/线路/适配（图标）、全屏。录制/画中画/投屏都在 ⋮ 里。
- `460–720`：顶栏右簇完整（录制/小窗/投屏图标 + 录制计时），底栏仍无标签。
- `≥720`：底栏再加音频模式、音量滑杆、截屏、窗口全屏、竖屏全屏、剧院；选择器带当前值文字。

沉浸式与页内：页内布局的页头本来就有 ⋮，所以播放层**不再重复**一个；进入全屏/窗口全屏/竖屏全屏/PiP 后页头消失，播放层顶部才出现 ⋮，内容与页头同一份 `roomMenuItems`。

## A. 直播间 / 播放页

| 项 | 内容 | 标准依据 | 状态 |
| --- | --- | --- | --- |
| A1 | 离线/封禁/回放结束等"有画面替身"的状态用**房间封面**做底（模糊 + 减弱遮罩），封面缺失才退纯黑；状态卡结构不变 | §16、§8.4 | ✅ 2026-11-01 |
| A2 | 统计层：分辨率/帧率/码率·带宽/缓冲/丢帧比例/解码·渲染器/进程占用/内核，1 秒刷新，`I` 或菜单开关 | §9.2、§16 | ✅ 2026-11-01 |
| A3 | 截屏：控制条相机 + 菜单项 + `S`，走 `captureScreenshot`（引擎优先、表面回退），存入「文件 → 截图」目录并 toast 文件名；不可截的内核不出现该控件 | §9.2、§16 | ✅ 2026-11-01 |
| A4 | 宽屏聊天分隔条可拖拽、双击复位（复用 `chatPanelWidthProvider`） | §10.4 | ✅ 2026-11-01 |
| A5 | 剧院模式：舞台铺满、聊天浮为右侧玻璃层，`T` 切换 | §8.3、§10.4 | ✅ 2026-11-01 |
| A6 | `?` 快捷键帮助浮层，从同一份绑定生成 | §9.5 | ✅ 2026-11-01 |
| A7 | 超宽源（>2.4:1）提供"铺满宽度"，把钳制改成默认值 + 可覆盖 | §10.4 | ✅ 2026-11-01 |
| A8 | TV：常显控制条的焦点环/间距/字号单独一档 | §10.5 | ✅ 2026-11-01 |

明确不做：直播不套可定位进度条（§18.5 明文禁止；C3 起连"画成进度条样子"的细线也不留）；不恢复已删除的"本机互动"。

## C. 直播间控件重排（2026-11-01 第二轮指令）

用户指令：「画中画应该在右上角，录制也应该在右上角，录制中应该添加录制闪烁的图标，其它图标也帮我优化一下位置」+「投屏应该也放右上角」+「直播又不是放视频要什么进度条」+「窄档只留闪烁点、PiP 进 ⋮」「闪烁点 + 计时文本，按钮仍在顶栏」。

| 项 | 内容 | 依据 | 状态 |
| --- | --- | --- | --- |
| C1 | 呈现三动词（录制 / 画中画 / 投屏）从底栏上移到顶部右簇，底栏删除；`<460` 收进 ⋮ | §10.4、§8.3 | ✅ 2026-11-01 |
| C2 | 录制中闪烁指示 + 计时（红点 1.6 s 呼吸 + `mm:ss`/`h:mm:ss`），顶栏与 PiP 小窗条各挂一处 | §16、§9.2 | ✅ 2026-11-01 |
| C3 | 删除直播进度条 `_LiveBar`，底栏收回一行高度；条隐藏时改 14 px 透明唤醒带 | §18.5 | ✅ 2026-11-01 |
| C4 | 聊天列表徽章轨：平台徽章图片 + 身份（主播/房管/官方）+ 粉丝牌 + 等级，矩形小牌、等级弱文字 | §16、§10.4 | ✅ 2026-11-01 |
| C5 | 飞弹幕默认样式（字号 18、描边 1.8、阴影 blur 2 默认开；速度 120 与 `bottomMargin 0.5` 核对后无需改） | §16 | ✅ 2026-11-01 |
| C6 | ⋮ 菜单分四组（房间 / 呈现与捕获 / 刷新与分享 / 帮助与离开），分隔线只在相邻两组都非空时出现 | §10.4、§6 | ✅ 2026-11-01 |
| C7 | 页内播放层不再重复身份：顶栏在页内只留右上呈现簇，全屏/窗口全屏/竖屏/TV 才带返回与标题（与点播、红果同一规则） | §10.4、§8.3 | ✅ 2026-11-01 |
| C8 | 房间信息卡的"打开详情"指示符移到卡片右缘，并按面板真实开法（侧栏 / 抽屉）指方向 | §10.4、§13 | ✅ 2026-11-01 |
| C9 | 其余页面（热门/分区/点播/红果/IPTV/多画面）控件审查 | §10.4 | 已核对，无需改动（见下） |

| C10 | 剧院玻璃列的上下留白随 C3/C7 重算（56/64 → 44/52），推导写进注释 | §10.4 | ✅ 2026-11-01 |
| C11 | 播放器画面上的白字与"直播/录制中"红点收进设计常量（`playerInk` / `playerSignal`），消掉 8 个文件里的裸色值 | §13 | ✅ 2026-11-01 |
| C12 | 闪烁指示接上 TV 档（点 8→12、文字 caption→label、簇间距 4→8），符合 A8 的 TV 规则 | §10.5 | ✅ 2026-11-01 |
| C13 | 聊天面板四种空态（连接中 / 无聊天 / 被拒 + 重试 / 真的没人说话）——此前一律显示「还没有弹幕」 | §8.4、§16 | ✅ 2026-11-01 |
| C14 | 聊天行加悬停反馈（每行都带右键/长按菜单，纯文本从不说明） | §20.2 | ✅ 2026-11-01 |
| C15 | 房间卡「直播中」徽标的红收进 `playerSignal`（此前是第二份裸色 `0xE6FF3B5C`） | §13 | ✅ 2026-11-01 |
| C16 | PiP 小窗的闪烁点接成停止录制的控件（此前是死控件），并给按下限 24×24 命中 | §9.2、§20.2 | ✅ 2026-11-01 |
| C17 | 录制中的指示器不随控制条隐藏：条收起时左上角保留同一枚胶囊（点它仍可停止） | §8.4、§9.2 | ✅ 2026-11-01 |

### C16（2026-11-01 19:19）

- 文件：`modules/live/room/page/player_surface.dart`（`_PipBar` 的指示器接 `onStop`）、`shared/player/recording_indicator.dart`（可点时给 24×24 命中下限并居中）。
- 为什么：C2 把小窗里的闪烁点画成了只读状态（`onStop: null`），而 PiP 条本身没有 ⋮ 菜单——录制中开小窗后，用户在这个窗口里根本停不掉录制，必须先恢复房间。这既是"可见控件必须能改变东西"的反例，也是我上一批自己引入的缺口。现在点它即停（与顶栏同一个 `toggleRoomRecording`，toast 同源）。
- 命中：点 + 内边距在 `showTimer: false` 时只有 ~14 px 高，低于本应用桌面的 24 px 下限；可点状态下用 `ConstrainedBox(minWidth/minHeight: 24)` 把内容居中撑起来，只读状态不受影响。
- 顺带核完 §20.2 的全仓扫描：10 处 `DsContextMenuRegion` 中，除聊天行（C14 已补）外全部包在 `DsPressable` 或卡片上（自带悬停），壁纸预览的整屏 `media` 不该铺 hover 也正确——**没有第二处缺口**。
- 验证：`dart analyze lib` → 0 issues；`flutter build bundle` → exit 0（`kernel_blob.bin` 19:19:36）；`flutter test test/live test/app` → 109 passed；`dart format` 无改动；无新增偏好键与文案键。
- 未验证：真窗目视——28 px 高的 PiP 条里 24 px 命中是否够用、点中的反馈（hover 亮底）在小窗上是否可见；实际录制启停链路（本会话未开房间）。

### C14–C15（2026-11-01 19:06）

- 文件：`modules/live/room/chat/room_chat.dart`（新 `_ChatHover`，两条返回路径各包一层）、`modules/live/room/page/room_page.dart`（`_LiveBadge` 的底色改走 `playerSignal.withValues(alpha: 0.9)`）。
- C14：每一行弹幕都带动作（桌面右键、触屏长按打开同一份菜单），但一行纯文本上没有任何东西说明这件事——§20.2 的口径是"一个控件的可达性由悬停或聚焦说明"。现在行落在 `_ChatHover` 上：进入/离开 `MouseRegion` 切状态，`AnimatedContainer` 120 ms 铺主题自己的 `colors.hover`（半强度，避免压过醒目留言卡自己的底色），圆角走 `theme.radii.controlCorners(null, 24)` 与其它行一致。系统通知行同样包（它也有复制动作）。
- C15：C11 的色值收口漏了一处——房间卡的「直播中」徽标写的是 `Color(0xE6FF3B5C)`，是"直播/录制中"那支红的第二份拷贝（带 alpha）。改为 `playerSignal.withValues(alpha: 0.9)`，全仓再没有裸的 3B5C。
- 状态：无新增偏好键、无 l10n 改动（未跑 slang）。
- 验证：`dart analyze lib` → 0 issues；`flutter build bundle` → exit 0（`kernel_blob.bin` 19:06:16，含两批）；`flutter test test/live test/app` → 109 passed；`dart format -l 120` 无改动。
- 未验证：真窗目视——悬停底色在浅色主题与玻璃聊天层上的可见度、120 ms 是否跟手；房间卡徽标在封面水洗上的对比。

### C13（2026-11-01 18:54）

- 文件：`modules/live/room/controller/room_controller.dart`（`RoomChatStatus` / `RoomChat`、`RoomState.chat`、`_setChat`、`retryChat`、四处状态写入）、`modules/live/room/chat/room_chat.dart`（`_ChatFeed` 的空态分支）、`l10n/messages/room/room_{zh-CN,en}.i18n.json`（`chatConnecting`/`chatUnsupported`/`chatFailedTitle` 3 键/语言）。
- 为什么：`roomChatProvider` 只是一条消息列表，面板唯一的空态是「还没有弹幕」。握手被拒时 `_openDanmaku` 只发一条会消失的 hint，`_reopenDanmaku`（登录变化后重连）干脆把失败吞掉；回放与无聊天能力的平台也从不说自己为什么没有聊天。也就是 §8.4「不允许只考虑正常状态」与「不能静默回退」两处同时违反。
- 现在的四态：`connecting`（转圈 + 正在连接聊天…）、`unsupported`（回放或该平台没有聊天 → 这个房间没有实时聊天）、`failed`（标题 + 复用 `danmakuConnectFailed(reason)` 说平台给的原因 + 「重试」按钮走 `retryChat()`，真的重跑一次握手且不动画面）、`connected` 且空（才是「还没有弹幕」）。hint 保留，状态在 hint 消失后继续留在面板上。
- 状态：无新增偏好键（连接状态是运行时事实，不写盘、不进备份与设置刷新）。
- 验证：`dart analyze lib` → 0 issues；`flutter build bundle` → exit 0（`kernel_blob.bin` 18:54:07）；`flutter test test/live test/app` → 109 passed；`dart run slang` 已生成；`dart format -l 120` 1 处重排。
- 未验证：真窗目视——四种态的文案与图标、断网重试是否真能连回；`retryChat` 在回放房间不会被触发（无按钮），未实测。

### C12（2026-11-01 18:39）

- 文件：`shared/player/recording_indicator.dart`（新增 `tv` 形参）、`modules/live/room/page/player_surface.dart`（呈现簇读 `_BarTier` 并传入，簇间距 4→8）。
- 为什么：A8 定的规则是"TV 构建里播放层的控件升一档"（32→48 px、图标 16→20、间距 4→8、文字升一级），C2 新加的闪烁指示当时写死 8 px 点 + caption 数字，在 48 px 的按钮旁边会糊成一粒。现在 TV 档点 12 px、文字 `label`、横向内边距 8→12；PiP 小窗条不传（永远非 TV 档）。
- 验证：`dart analyze lib` → 0 issues；`flutter build bundle` → exit 0（`kernel_blob.bin` 18:39:34）；`flutter test test/live test/app` → 109 passed；`dart format` 无改动。未验证：TV 实机（本会话无 GUI，也无 TV 设备）。

### C11（2026-11-01 18:36）

- 文件：`shared/player/player_overlay.dart`（新 `playerSignal`）、`shared/player/recording_indicator.dart`、`shared/player/media_bar_button.dart`、`modules/live/room/page/player_surface.dart`、`modules/live/room/page/room_page.dart`、`modules/live/room/page/audio_only_cover.dart`、`modules/live/popular/room_card.dart`、`modules/live/multiview/multiview_page.dart`。
- 为什么：压在视频上的白字此前在 8 个文件里各写裸 `Color(0xFFFFFFFF)`，"直播中/录制中"的红点也在 `_VideoLiveBadge` 与新建的指示器里各写一份 `0xFFFF3B5C`——同一语义两个来源，改一处就会漂移。白色统一走既有的 `playerInk`，红色新增 `playerSignal` 并由两处共用；像素零变化。
- 核对未改：`gift_flights.ink`（金色礼物轨迹，独立语义，已有名字）、`kPlayerStageColor`（画面底黑，已命名）、`DanmakuStyle.strokeColor/shadowColor` 的 `0xFF000000`（用户可改的存储值，不是设计令牌）。
- 验证：`dart analyze lib` → 0 issues；`flutter build bundle` → exit 0（`kernel_blob.bin` 18:36:31）；`flutter test test/live test/app` → 109 passed；`dart format` 3 处重排。

### C8–C9（2026-11-01 18:29）

- 文件：`modules/live/room/page/room_page.dart`（`_RoomHero` 内容包一层 `Row`，chevron 移到卡片右缘）。
- C8：整张卡是 `DsPressable`（开 `showRoomDetails`），但指示符 `chevronDown` 挂在标题行末尾、夹在标题与睡眠胶囊之间，读起来像"展开这段文字"。现在 chevron 在卡片右缘垂直居中（`iconSm` + `textSubtle`），方向按 `showDsPanel` 的真实形态给：窗口宽 ≥ `LiveWindow.sheet`（640）→ 侧栏面板 → `chevronRight`；否则底部抽屉 → `chevronUp`。判据与 `room_details.dart:22` 同源，不另立规则。标题行只剩 标题 + 睡眠胶囊。
- C9（只读核对，未改代码）：点播 `vod_video_page.dart:1010` 与红果 `hongguo_player_page.dart:1504` 的顶栏都是 `immersive && showBar` 才画，页内不重复身份——直播间此前是唯一的不一致者，C7 已对齐；两页都没有长 ⋮ 菜单（`DsMenuDivider` 计数 0，动作都在控制条/页头），C6 的分组规则无处套用；IPTV 播放页的 `top: 0` 是 zapper 侧栏而非身份条；热门页工具条已是"tabs + 排序同行、窄档收进 ⋮、平台墙与布局开关在 tabs 行内"的形状。**结论：这几页不需要改，硬改属于制造工作量。** 真正的剩余缺口是运行期目视（本会话无 GUI）。
- 验证：`dart analyze lib` → 0 issues；`flutter build bundle` → exit 0（`kernel_blob.bin` 18:28:43）；`flutter test test/live test/app` → 109 passed；`dart format -l 120` 仅本次 1 文件；无新增偏好键与文案键。
- 未验证：真窗目视——chevron 与头像行的垂直关系、窄窗 `chevronUp` 是否被误读为"上滑"。

### C10（2026-11-01 18:34）

- 文件：`modules/live/room/page/room_page.dart`（`_theaterTopInset` / `_theaterBottomInset`）。
- 为什么改：剧院的玻璃聊天列用这两个常量给播放层两条横条让位，但 C3 删了底条上的进度线（底条矮 10 px）、C7 让页内顶条只剩右上角那枚小胶囊（矮 ~12 px），常量没跟着动，于是玻璃列上下各留出一段无主空隙。新值按条自身的几何推：顶 44 = 8 内边距 + 32 控件 + 胶囊余量；底 52 = 8 + 32 + 8。推导与来源写进注释，改控件时必须同步改注释里的式子。
- 验证：`dart analyze lib` → 0 issues；`flutter build bundle` → exit 0（`kernel_blob.bin` 18:34:05）；`flutter test test/live test/app` → 109 passed；`dart format` 无改动。未验证：真窗目视——玻璃列与两条横条的实际间距。

### C6–C7（2026-11-01 18:24）

- 文件：`modules/live/room/page/room_page.dart`（`roomMenuItems` 改为四个 section 列表 + 折叠插入分隔线）、`modules/live/room/page/player_surface.dart`（`_PlayerTopBar` 新增 `identity` 开关与页内分支）。
- C6：16 项一条分隔线的平铺菜单 → 房间（详情、切台）｜呈现与捕获（录制、画中画、投屏、画面方向、截屏、自动录像、统计）｜刷新与分享（刷新、重试、分享、外部打开、复制链接）｜帮助与离开（快捷键、关闭）。分组用 `List<List<Widget>>` 折叠，空组连同其前置分隔线一起消失，避免出现两条紧挨的细线；能力位（截屏、外链、链接、TV 无快捷键）不再影响其它项的观感。
- C7：页头本来就有头像、直播环、平台/分区、直播状态、观众数与标题，播放层顶栏在页内重复一份并压一条深色渐变带。现在 `_PlayerTopBar.identity` 由 `immersive || tv` 决定：页内只剩右上角的呈现簇（无渐变、无返回、无标题），进入全屏/窗口全屏/竖屏全屏后身份回来，TV 常显。核对：点播（`vod_video_page.dart:1010`）与红果（`hongguo_player_page.dart:1504`）本来就是 `immersive && showBar` 才画顶栏，直播间是唯一的不一致者，本项把它对齐；IPTV 的 `top: 0` 是 zapper 侧栏，不属身份条。
- 状态：无新增偏好键、无新增 provider、无 l10n 改动。
- 验证：`dart analyze lib` → 0 issues；`flutter test test/live test/app` → 109 passed；`flutter build bundle` → exit 0（`kernel_blob.bin` 18:24:05）；`dart format -l 120` 无改动。
- 未验证：真窗目视——页内画面右上角只剩三枚小胶囊后的观感、全屏下顶栏恢复身份的过渡、菜单四组在手机/平板整屏菜单里的密度。

### C4–C5（2026-11-01 18:10）

- 文件：`modules/live/room/chat/room_chat.dart`（`_ChatBadge` → `_SenderTag`，新 `_BadgeImage`，行内徽章块重写）、`features/settings/danmaku/danmaku_style_providers.dart`（`_defaults` 三项）、`l10n/messages/room/room_{zh-CN,en}.i18n.json`（`roleAnchor`/`roleModerator`/`rolePlatform` 各 3 键）。
- 徽章轨：`sender.badges`（平台自己发来的图片徽章：舰长徽、VIP、头衔）此前**全仓无人绘制**，现在按行的字号高度画（`fontPx × 1.3` 夹在 14–22，槽宽 = 高 × 1.5，非 http 或加载失败留零宽），顺序为 平台图片 → 身份 → 粉丝牌 → 等级；身份牌用 `LiveAnchorRole`（anchor/moderator/platform → 主播/房管/官方，accent/success/info 三色），粉丝牌改矩形并加同色 32% 描边（浅色主题上纯 tint 会消失），等级去掉灰底色块、改 `Lv.N` 弱文字并按 10/20 档着色。价格牌（醒目留言）同样改矩形。行内所有 tag 同一高度，消掉此前 pill 高低不齐造成的行高跳动。
- 飞弹幕默认：字号 16→18（16 在直播画面上像贴上去的说明文字）、描边 1.5→1.8、阴影由关改为默认开（blur 2 + offset 1/1——纯描边在雪景/白墙/游戏 HUD 上会糊）。核对后**不改**：`baseSpeed` 已是 120 px/s，`area: 1.0` + `bottomMargin: 0.5` 已经让弹幕只走上半屏，原方案的"改成顶部 50%"是重复劳动。默认值只影响未存过偏好的用户与「恢复默认」，已保存的样式不动。
- 状态：无新增偏好键；`_defaults` 同时是加载器缺省与恢复默认的唯一来源，无需别处同步。
- 顺带修：`features/settings/panes/data_cache_panes.dart` 恢复「本地媒体」入口（并发会话 13:50 重写该页时把 `SettingsChildEntry(localMedia)` 删掉了，页面成为孤儿、`check_settings_ia.ps1` 报"never opened from its parent pane"）。现回到 存储位置 组内、与 存储位置 并列。
- 验证：`dart analyze lib` → 0 issues；`flutter test test/live test/app` → 109 passed；`flutter build bundle` → exit 0（`kernel_blob.bin` 18:10:17）；`dart run slang` 已生成；`tool/check_responsive.ps1` → passed；`tool/check_prefs_manifest.ps1` → 368 / 353 / 132 不变；`tool/check_settings_ia.ps1` → passed（75 sections / 61 页 / 302 命中）；`dart format -l 120` 仅本次文件。
- 未验证：真机观感——平台图片徽章在 13–15 px 字号下的可读尺寸、`badges` 只有图片没有文字时是否被误读为粉丝牌、三种身份色在浅色主题上的对比、字号 18 + 阴影在密集弹幕下的拥挤度与帧率（`maxVisibleCount: 48` 未动）；真实房间的徽章数据只有联网才看得到。

### C1–C3（2026-11-01 17:58）

- 文件：`shared/player/recording_indicator.dart`（新 `RecordingIndicator`）、`shared/player/player.dart`（导出）、`modules/live/room/page/player_surface.dart`（新 `_PresentationCluster`、`roomRecordingTaskOf`/`toggleRoomRecording`/`toggleRoomPip` 三个共享入口、顶栏改造、底栏删三枚与 `_LiveBar`、`_RecordButton` 删除、新 `_IdleWakeStrip`、PiP 条挂只显闪烁点）、`modules/live/room/page/room_page.dart`（⋮ 菜单补 录制/画中画/投屏，加 `recording`/`pipOn`/`line` 判据）。
- 结构：呈现簇自带 `PlayerGlassPill`，三枚都没有内容时整块返回 `SizedBox.shrink()`，不在顶栏留空玻璃洞。顶栏与菜单共用同一组动作函数，`toggleRoomRecording` 自己从任务存储读"此刻是否在录"，不接调用方传来的旧状态，避免两处各算一份真相。`_LiveBar` 的 `position/buffered/duration` 只喂过它，随之删除；`transport` 仍留（音量滑杆读它）。
- 指示：`RecordingIndicator` 的计时每秒按 `task.startedAt` 重算差值（不累加），所以更早会话开始的录制、后台窗口、丢帧都不会漂；只有 `startedAt != null` 才开表与开动画，`dispose` 取消；系统"去除动画"或 `TickerMode.valuesOf(context).enabled == false` 时退为常亮。闪烁点顶掉录制按钮本身，所以顶栏不会出现两枚红色控件。
- 状态：无新增偏好键、无新增 provider、无新增设置项。
- l10n：零新增——复用 `room.record`/`stopRecording`/`recordStarted`/`recordStopped`/`recordFailed`/`pipOn`/`pipOff`/`cast` 与 `common.pipUnavailable`，故未跑 slang。
- 验证：`dart analyze lib` → 0 issues；`flutter test test/live test/app` → 109 passed；`flutter build bundle` → exit 0（`build/flutter_assets/kernel_blob.bin` 17:58:19 真实重编译）；`dart format -l 120` 仅本次 4 个 Dart 文件；`tool/check_responsive.ps1` → passed。
- 未验证：真窗目视——460–520 宽时顶栏标题与四枚玻璃胶囊的挤压、计时白字在明亮画面上的对比、闪烁点在 TV 距离下的感知、窄档 ⋮ 里三项的位置、PiP 条 28 px 高度里 8 px 点的垂直居中；录制/小窗/投屏的真实动作链路（本会话未开房间）。

### C17（2026-11-01 22:15）

- 文件：`modules/live/room/page/player_surface.dart`（`PlayerSurface.build` 里读一次 `roomRecordingTaskOf`，Stack 加常驻胶囊）。
- 为什么：C1/C2 把闪烁点放在顶栏里，而顶栏整条 `if (showBar && !mini)` —— 直播播放几秒后控制条自动收起，"我还在录吗"这个最该常驻的答案跟着没了，磁盘却还在写。属于 §8.4「只考虑了正常态」的另一种：只考虑了控制条在场的时候。
- 做法：`recording && !showBar && !mini` 时在画面左上角画同一枚 `PlayerGlassPill(RecordingIndicator)`，带计时、点它即停（与顶栏同一个 `toggleRoomRecording`）。位置选**左上**而不是右上：右上在统计面板打开时归它（`top: 12, end: 12`），两枚玻璃胶囊叠在一角会读成 bug；控制条收起时顶栏整条不在，左上是空的。
- 验证：`dart analyze lib` → 0 issues；`flutter build bundle` → exit 0（`kernel_blob.bin` 22:15:58）；`flutter test test/live test/app` → 109 passed；`dart format` 无改动；无新增偏好键与文案键。
- 未验证：真窗目视——统计面板与常驻胶囊是否真的不再同角、竖屏全屏下左上角是否被系统状态栏压到。

## C 段运行期验收清单（本会话无 GUI，需真窗走查）

每条写"看什么 / 期望 / 不合格时改哪里"。走查方式同 `docs/recording-runtime-qa.md`：开一个有弹幕的真实房间，分别在页内、全屏、剧院、窄窗（<460）、TV 档各看一遍。

| # | 看什么 | 期望 | 不合格时改哪里 |
| --- | --- | --- | --- |
| Q1 | 页内画面右上角 | 只有 直播中/观众/录制/小窗/投屏 的小玻璃簇，没有深色渐变带、没有重复标题与返回 | `player_surface.dart` `_PlayerTopBar.identity` |
| Q2 | 全屏顶栏 | 返回 → 主播·标题 → 直播中 → 观众 → 呈现簇 → ⋮ 一行不挤；460–560 px 时标题仍读得出（不被挤成 3 个字） | 簇的 `narrow` 阈值 460；观众数阈值 480 |
| Q3 | 开始录制后 | 录制按钮原地变成呼吸红点 + `mm:ss`，画面上不出现第二枚红点；点它即停止并 toast | `RecordingIndicator` / `_PresentationCluster` |
| Q4 | 呼吸节奏 | 1.6 s 一个来回，alpha 1.0↔0.35；系统"去除动画"或切到后台时退为常亮 | `recording_indicator.dart` `_halfCycle` 与 `still` 分支 |
| Q5 | 录制中开小窗 | PiP 条 28 px 高度里闪烁点垂直居中、不压住标题省略号 | `_PipBar` 的 `RecordingIndicator(showTimer: false)` |
| Q6 | 底条 | 画面底部没有进度条样的东西；条隐藏时 14 px 透明带仍可点出控制条 | `_IdleWakeStrip` |
| Q7 | 剧院模式 | 玻璃列与上下两条横条之间不再有多余空隙（44/52 是按控件几何推的） | `room_page.dart` `_theaterTopInset/_theaterBottomInset` |
| Q8 | 聊天行徽章 | 平台图片徽章高度≈字号×1.3（14–22 px），与名字同一基线不跳行；图片加载失败不留空洞 | `_BadgeImage` 的槽宽/高、`tagHeight` |
| Q9 | 粉丝牌与等级 | 粉丝牌是矩形带 32% 同色描边（浅色主题上看得见），等级是弱文字不是灰底块；`Lv.9` 与 `Lv.24` 不打断阅读 | `_SenderTag` 的 border、`levelInk` 分档 |
| Q10 | 身份牌 | 主播/房管/官方三色在浅色与深色主题下都能一眼区分，且不与粉丝牌同色混淆 | `_ChatLine` 里 role 的 background/foreground switch |
| Q11 | 飞弹幕默认观感 | 字号 18 + 描边 1.8 + 阴影 blur 2 在明亮画面上清晰；只走上半屏（`bottomMargin 0.5`），不压主播与字幕 | `danmaku_style_providers.dart` `_defaults` |
| Q12 | 密集弹幕帧率 | 48 条同屏上限下滚动不掉帧（阴影是新增开销） | 必要时把 `showShadow` 默认退回 false，或降 `maxVisibleCount` |
| Q13 | ⋮ 菜单 | 四组之间有且只有一条细线；关掉截屏能力/无外链时不出现双线和首尾多余线 | `roomMenuItems` 的 sections 折叠 |
| Q14 | 房间卡 | 右缘 chevron 与头像行垂直居中；宽窗指右（侧栏）、窄窗指上（抽屉） | `_RoomHero` 的 `LiveWindow.sheet` 判据 |
| Q15 | TV 档 | 呈现簇控件 48 px 时红点 12 px、计时用 `label` 字号，远距离可读；焦点环顺序顶栏→底栏 | `RecordingIndicator(tv: true)` 与 `_BarTier` |
| Q16 | 窄档手机横屏 | 顶栏只有闪烁点（录制中）+ ⋮；录制/小窗/投屏在 ⋮ 里且状态与顶栏一致 | `_PresentationCluster.narrow` + `roomMenuItems` |
| Q18 | 鼠标划过聊天行 | 整行铺一层很淡的主题 hover 底（120 ms 淡入淡出），右键/长按菜单照旧；浅色主题与剧院玻璃层上都要看得见 | `room_chat.dart` `_ChatHover` 的 alpha 与圆角 |
| Q19 | 房间卡「直播中」徽标 | 与播放层顶栏、录制闪烁点是同一支红（`playerSignal`），不再各写一份 | `room_page.dart` `_LiveBadge` |
| Q25 | 录制中把鼠标移开让控制条收起 | 左上角仍留一枚呼吸胶囊（带计时），点它可以停止；与统计面板不同角 | `player_surface.dart` 的 `recording && !showBar && !mini` 分支 |
| Q20 | 录制中开画中画小窗 | 小窗条上的闪烁点可点，点它即停止录制并 toast；hover 有亮底 | `_PipBar` 的 `RecordingIndicator(onStop:)` |
| Q17 | 聊天面板四种空态 | 连接中＝转圈 +「正在连接聊天…」；平台无聊天/回放＝「这个房间没有实时聊天」；握手被拒＝标题 + 平台原因 +「重试」按钮（点了真的重连）；已连上没人说话＝「还没有弹幕」 | `room_chat.dart` `_ChatFeed` 的 status 分支；状态来源 `RoomChatStatus`（`room_controller.dart`） |
| Q21 | 点播页内画面右上 | 只有一枚小窗胶囊（无渐变带、无标题、无退出）；底栏不再有画中画 | `vod_video_page.dart` `_vodTopStrip` 的 `!immersive` 分支 |
| Q22 | 点播全屏 | 顶栏＝退出 + 标题 + 心形收藏 + 小窗；收藏的状态与页体动作行一致 | `savedOf(bvid)` 单点读 |
| Q23 | TV 上的点播/红果 | 控制条按钮明显变大（48 px）且聚焦有白环；统计层与红果覆盖层不被顶栏压住 | `PlayerBarTier` 包裹 + `controlSize(context)` 推导的 top |
| Q24 | 红果全屏 | 顶栏只有 退出 + 标题，动作仍来自画面右缘竖排栏（**不应**出现两份收藏） | D7 已回退，走查确认回退生效 |

## D. 其它模块的播放器对齐（2026-11-01 第三轮指令：「其它模块的视频播放器也帮我优化一下」）

先审后改。审出来的最大问题不是控件位置，而是 **A8 的 TV 规则只覆盖了直播间**。

| 项 | 内容 | 依据 | 状态 |
| --- | --- | --- | --- |
| D1 | 把直播间的私有档位 `_BarTier` / 私有按钮 `_BarIcon` 提升为共享的 `PlayerBarTier` / `PlayerBarButton`，点播与红果的播放条接上：TV 下控件 32→48、图标→20、焦点环、控制间距 4→8 | §10.5、§13 | ✅ 2026-11-01 |
| D2 | 点播的画中画从底栏移到顶栏右簇（与直播间同构：页内只有右簇、沉浸式才有身份） | §10.4 | ✅ 2026-11-01 |
| D3 | 红果：无画中画可搬（它压根没有 PiP），底栏顺序已符合"播放→流参数→窗口"，不动 | — | 已核对，无需改动 |
| D4 | IPTV 播放页：无覆盖式控制条（zapper 是侧栏），不适用 | — | 已核对，无需改动 |
| D5 | 沉浸式不再弄丢页体动作：红果顶栏加 ⋮（收藏/评论/分享，与竖排栏共用同一个 `_toggleSeriesFavorite`），点播顶栏加收藏按钮（`savedOf` 单点读） | §8.3、§9.2 | ✅ 2026-11-01 |
| D6 | 覆盖层的 top 偏移不再写死（房间统计层 56、红果两处 64）：改由档位算，TV 下控件长到 48 后写死值会被顶栏压住 | §10.5 | ✅ 2026-11-01 |

### D1（2026-11-01 19:45）

- 文件：`shared/player/player_bar_tier.dart`（新：`PlayerBarTier` + `PlayerBarButton`）、`shared/player/player.dart`（导出）、`modules/live/room/page/player_surface.dart`（删私有 `_BarTier`/`_BarIcon`，14 处调用改共享按钮）、`modules/vod/pages/vod_video_page.dart`（8 处按钮 + 控制条间距 + 整页 surface 包一层档位）、`modules/hongguo/pages/hongguo_player_page.dart`（5 处按钮 + 紧凑 Wrap 与 Row 的间距 + 档位包裹）。
- 为什么：两个页面都已经算出 `tv`（用来常显控制条、关掉键盘方向键），却没人拿它去放大控件——同一台电视上直播间是 48 px 带焦点环，点播/红果仍是 32 px 无环，遥控器走到哪看不出。共享后规则只有一份：`PlayerBarButton` 自己读 `PlayerBarTier.tvOf(context)`，页面不再把 `tv` 逐个穿给按钮；显式传了 `size`/`iconSize` 的调用点（如点播下载胶囊里的 28 px 暂停键）保持原尺寸，档位只补空缺。
- 做法注意：包裹档位用括号配对定位，不靠肉眼数缩进——第一次改点播时把 `tv` 用在了 `_vodControlBar`（另一个方法，不在作用域），并把闭合括号插错一层，改回后用 `PlayerBarTier.tvOf(context)` 读取；红果紧凑档的 `runSpacing` 一度被我改成无条件 s8（会让手机触屏上的换行间距变大），已收回档位判断内。
- 验证：`dart analyze lib/modules/live/room lib/modules/vod lib/modules/hongguo lib/shared/player` → 0 issues；`flutter build bundle` → exit 0；`flutter test`（整套）→ 271 passed；`flutter build bundle` → exit 0（`kernel_blob.bin` 19:44:58）。整库 `dart analyze lib` 另有 7 条 info，全部落在并发会话 19:2x 新建的未跟踪文件 `features/lan_sync/data/tls_identity_provider.dart`，未代改。
- 未验证：TV 实机（无设备）。点播/红果在 TV 上的焦点顺序未测——档位只改尺寸与焦点环，不改遍历顺序。

### D2（2026-11-01 19:53）

- 文件：`modules/vod/pages/vod_video_page.dart`（顶栏常驻但页内只画右簇、`_vodTopStrip` 加 `immersive` 形参与画中画簇、底栏删画中画）。
- 形状：`if (showBar)` 才画顶栏（不再 `immersive &&`）；页内 → 一个右对齐的 `PlayerGlassPill(画中画)`，无渐变带、无退出键、无标题（页头已经写了存档名）；沉浸式 → 退出 + 标题 + 右簇。底栏的画中画整块删除，`selected` 态随 `PresentationMode.pip`。
- 取舍（记录在案）：YouTube/Twitch 的画中画在底栏右下、紧邻全屏，这一条是**明知偏离主流**的统一——用户先要求直播间右上，再要求"其它模块的视频播放器也帮我优化一下"。回退成本：把那 12 行搬回 `_vodControlBar` 并把顶栏调用改回 `immersive && showBar`。
- 验证：`dart analyze lib/modules/vod` → 0 issues；`flutter build bundle` → exit 0（`kernel_blob.bin` 19:52:47）；`flutter test test/live test/app test/vod test/hongguo` → **151 passed**。整套 `flutter test` 另有 6 条失败，全部在并发会话新建的 `test/features/lan_sync/`（含一个 `dbg_test.dart: dumps the pkcs8 head` 的调试用例），非本会话文件，未代改。
- 未验证：真窗目视——页内画面右上角多出一枚小胶囊的观感、沉浸式下标题与右簇的间距；PiP 在 Windows/Android 的真实进入与退出。

### D5（2026-11-01 20:25）

- 文件：`modules/vod/pages/vod_video_page.dart`（顶栏收藏按钮 + 抽出 `savedOf`）、`modules/hongguo/pages/hongguo_player_page.dart`（抽出 `_toggleSeriesFavorite`；本轮照误判加的 ⋮ 已整块回退）。
- 为什么（点播成立、红果不成立）：两页都是 `if (immersive) return Scaffold(body: _playerSurface(...))`。点播的 收藏 在 `_info()` 里——播放层之外的页体，沉浸式确实拿不到，所以顶栏右端加一枚心形按钮（只有一项，不做"一项的菜单"）；`savedOf(bvid)` 提成方法后，页体动作行与顶栏按钮同读一处，不会互相说错"已收藏"。
- **红果是这一轮的误判，已撤销**：我以为它的 收藏/评论/分享 竖排栏在页体里，实际它渲染在 `_playerSurface` 的 Stack 内（`hongguo_player_page.dart:1553`，注释写明"展开的目录与按住会让位"），沉浸式下本来就在。照误判加的 ⋮ 会让同一屏出现两份相同动作，35 行已回退；顺手抽出的 `_toggleSeriesFavorite(detail)` 保留（竖排栏自己调用它，`onPressed` 从 14 行收成 1 行，`HongguoSeries(...)` 不再重复构造）。
- 验证：`dart analyze lib/modules/vod lib/modules/hongguo` → 0 issues；`flutter build bundle` → exit 0（`kernel_blob.bin` 20:25:02）；`flutter test test/live test/app test/vod test/hongguo` → 151 passed。整套 `flutter test` 的 6 条失败仍在并发会话的 `test/features/lan_sync/`（含 `dbg_test.dart` 调试用例），未代改。
- 未验证：真窗目视——点播沉浸式顶栏多一枚心形按钮后标题的省略点、该按钮在浅色画面上的对比；红果回退后顶栏恢复原状（未再实测）。

- 教训（写死在这里）：判断"沉浸式会不会弄丢动作"，不能看它名义上属于页体还是播放层，要看渲染点在哪一层——`grep 方法名` 找到调用行是这一步的必需检查，缺了这一步就会像红果这样做出重复控件。

### D6（2026-11-01 20:31）

- 文件：`shared/player/player_bar_tier.dart`（新 `PlayerBarTier.controlSize(context)`）、`modules/live/room/page/player_surface.dart`（统计层 top）、`modules/hongguo/pages/hongguo_player_page.dart`（两处覆盖层 top）。
- 为什么：D1 把控件在 TV 下从 32 长到 48，而三个覆盖层的"躲开顶栏"用的是**写死的数字**——房间统计层 `top: 56`、红果两处 `top: DsSpace.s64`。按各页顶栏自己的内边距算，非 TV 是 52 / 60（写死值刚好盖住），TV 变成 68 / 76，写死值就比顶栏矮一截：统计面板与红果那两个覆盖层会被顶栏压住 12 px。这是 D1 引入的漂移，不是老问题。
- 做法：`controlSize(context)` 由档位回答（`tv ? sizes.lg : sizes.sm`），三处改成 `DsSpace.s8 + controlSize + 各自的底边距`；核对全仓只有这三处（点播没有停在顶栏下方的覆盖层，房间只有统计层一处）。
- 验证：`dart analyze lib/modules/live/room lib/modules/hongguo lib/shared/player` → 0 issues；`flutter build bundle` → exit 0（`kernel_blob.bin` 20:31:44）；`flutter test test/live test/app test/vod test/hongguo` → 151 passed；`dart format` 见台账。
- 未验证：TV 实机——统计层与红果覆盖层在 48 px 控件下是否真的不再被压。

## B. 音乐（§18）

| 项 | 内容 | 依据 | 状态 |
| --- | --- | --- | --- |
| B1 | 专辑页/歌手页：源支持则接（如 `music_source_kw._albumDetail`），不支持显示"该来源不支持专辑浏览" | §18.2、§16 | ✅ 2026-11-01 |
| B2 | 迷你播放器按左/中/右分组重排，补音效与输出设备入口（能力位门控） | §18.3 | ✅ 2026-11-01 |
| B3 | 播放页加模式切换（标准/黑胶/歌词）与音效入口；设置里的模式降为默认值 | §18.4 | ✅ 2026-11-01 |
| B4 | 歌词点行跳转 + 保留拖动擦洗 | §18.7 | ✅ 2026-11-01 |
| B5 | 队列"接下来播放/已播放"分组、单曲失效态、超长提示 | §18.6 | ✅ 2026-11-01 |
| B6 | 频谱柱/圆/波形三档 + 暂停/静音/无数据静默态 + 性能档（只重建自绘层） | §18.8 | ✅ 2026-11-01 |
| B7 | 首页 rails 补专辑/歌手（依赖 B1） | §18.2 | ✅ 2026-11-01 |

## 已落地部分的交付说明（A1–A8）

- 文件：`page/player_surface.dart`（状态层、控制条按钮、统计层挂载）、`page/player_stats_overlay.dart`（新：provider + 面板）、`page/room_screenshot.dart`（新：抓帧落盘 + 统一 toast）、`page/room_page.dart`（`I`/`S` 快捷键与菜单项）、`l10n/messages/room/room_{zh-CN,en}.i18n.json`（9+3 键）。
- 状态：`roomStatsVisibleProvider`（视图偏好，不持久化）；截图使用已有 `AppPaths.screenshots`（「文件 → 截图」这一设置此前无消费者，现在生效）。
- 平台/主题：统计层与截屏都只在能力可用时出现；统计层用播放器自己的深色玻璃（与既有 `playerInk*` 约定一致），不随主题反色；封面底在任何主题下都叠固定遮罩。
- 验证：`dart analyze lib` 0 issues；`flutter build bundle` exit 0（2026-11-01 03:34）；`flutter test test/live test/app` 103 passed（未新增测试：A1 是绘制、A2/A3 依赖真实内核能力）。**未做视觉检查**——本会话无法启动 GUI，A1/A2/A3 的实际观感需按 `docs/recording-runtime-qa.md` 的方式补一段截图走查。

### A4（2026-11-01 04:14）

- 文件：`page/chat_splitter.dart`（新：宽屏分隔条）、`page/room_page.dart`（宽屏分支的宽度钳制与接线）、`features/settings/danmaku/chat_display_settings.dart`（默认值公开为 `kChatPanelWidthDefault`，新增 `preview` 供拖拽时只改状态不写盘）、`l10n/messages/room/room_{zh-CN,en}.i18n.json`（`resizeChat` 1 键/语言）。
- 行为：分隔条 12 px 命中带、1 px 细线，悬停/拖拽/聚焦时变 2 px 品牌色；向左拖加宽聊天、向右拖收窄；双击回到 340 px 默认值。拖动过程只走 `preview`（provider 状态），抬手才 `set` 落盘一次，避免每个指针事件都写偏好。键盘：聚焦后 ←/→ 8 px、Shift+←/→ 32 px；TV 布局（`keyboard: false`）不进入焦点环，避免遥控器方向键被分隔条吃掉。最大宽度由窗口宽度减舞台地板（420 px）与 520 px 上限取小；设置里的滑杆与拖拽共用同一个 `chatPanelWidthProvider`。
- 状态：无新增偏好键（沿用 `danmaku.chatPanelWidth`）。
- 验证：`dart analyze lib` 0 issues；`flutter test test/live test/app` 103 passed；`flutter build bundle` exit 0。**未做视觉/手感走查**：拖动跟手度、双击复位时 340 px 的观感、窄宽屏（840–960）下舞台地板的实际比例、触屏平板上 12 px 命中带是否够宽，均需真机。

### A5（2026-11-01 04:38）

- 文件：`page/room_theater.dart`（新：`roomTheaterProvider`，会话内视图偏好、不写盘）、`page/room_page.dart`（剧院布局、`T` 快捷键、玻璃卡片）、`page/player_surface.dart`（`overlay` 页面层插槽 + 底部窗口簇的剧院按钮）、`page/chat_splitter.dart`（`onDark`：分隔线在画面之上改用画面白）、`chat/room_chat.dart`（`translucent`：面板不再自己铺底色）、`l10n/messages/room/room_{zh-CN,en}.i18n.json`（`theaterOn`/`theaterOff` 各 1 键）。
- 行为：≥840 的宽窗里按 `T` 或控制条窗口簇（竖屏全屏与全屏之间）的剧院按钮 → 播放层铺满整页（画面按自身比例居中，控制条横跨全宽），聊天以右侧玻璃卡浮在画面之上：主题 surface 86% + 24 px 背景模糊、卡片圆角与描边；卡片上/下分别留出顶部条（56 px）与底部条（64 px）的高度。玻璃层交给 `PlayerSurface` 的 `overlay` 插槽，位于画面之上、控制条/选择器/统计层之下，所以剧院里打开清晰度、线路、画面适配、统计层都不会被聊天挡住；分隔条在剧院里同样可拖拽、双击复位。
- 状态：`roomTheaterProvider`（视图偏好，不持久化，不新增设置项与偏好键）；聊天宽度沿用 `danmaku.chatPanelWidth`；进入剧院会自动展开已收起的聊天；剧院里仍可单独收起聊天（右上角变成「展开聊天」）。
- 主题：玻璃用主题自己的 surface 与 border（浅色＝奶白磨砂、深色＝墨色），文字沿用主题色；分隔线在画面上用固定画面白。
- 验证：`dart analyze lib` 0 issues；`flutter test test/live test/app` 103 passed；`flutter build bundle` exit 0；`dart run slang` 已生成；`dart format -l 120` 仅改动文件；`tool/check_responsive.ps1` passed。
- 未验证：实际观感与手感——背景模糊在视频上的渲染开销、浅色主题里玻璃卡的文字对比、840–960 宽窗中玻璃卡占画面的比例、分隔条落在画面上时的命中带、聊天气泡透明后发送者名字的对比回退（`_senderNameInk` 仍按不透明 surface 估算）、TV 焦点顺序里新增按钮的位置。

### A6（2026-11-01 04:56）

- 文件：`page/room_shortcuts.dart`（新：绑定表 `RoomShortcutBinding` / `RoomShortcutAction`、键帽文案 `roomShortcutKeyLabel`、帮助对话框 `showRoomShortcuts`）、`page/room_page.dart`（`CallbackShortcuts` 的映射改为从绑定表派生；⋮ 菜单新增「快捷键」，同一份表随菜单传入页头与沉浸式两处）、`l10n/messages/room/room_{zh-CN,en}.i18n.json`（9 键/语言）。
- 行为：桌面键盘按 `?`（`question` 键或 `Shift + /`）打开「快捷键」面板，再按 `?` 或 Esc 关闭；⋮ 菜单里的同名项打开同一个面板，鼠标用户不必先知道按键。面板逐行列出**当前真正生效**的绑定：Space 播放/暂停、F 全屏、Esc 退出全屏或离开、↑/↓ 音量、T 剧院（仅宽窗）、I 统计、S 截屏（非 TV 且内核可截）、R 重试、? 帮助。键帽用 `Space`/`Esc` 的本地化名与 `↑`/`↓`/`?` 字形，字母键用键面自身字母。
- 结构：键位、动作、说明只有一份表（`roomShortcutBindings`）；页面用同一张表生成 `CallbackShortcuts` 的映射与帮助面板的行，所以「面板上列出的键」与「页面响应的键」不会漂移。TV 遥控器没有键盘，表中不生成 `?` 帮助绑定，⋮ 里的入口也随之消失（入口由表里是否存在 `help` 绑定决定）。
- 状态：无新增偏好键、无新增 provider；帮助面板是一次性路由（`showDsDialog`），关闭后焦点按 WAI-ARIA 对话框规则回到打开它的控件。
- 主题/平台：面板用 `DsDialog` 与主题 token（surface/control/border、`DsSpace`、`radii.control`）；窄窗沿用 DsDialog 的收缩与内边距；浅色/深色都由主题决定，不写死颜色。
- 验证：`dart analyze lib` 0 issues；`flutter test test/live test/app` 103 passed；`flutter build bundle` exit 0（kernel_blob 04:56）；`dart run slang` 已生成；`dart format -l 120` 仅本次两个 Dart 文件；`tool/check_responsive.ps1` passed。
- 未验证：键帽在浅色/深色下的实际对比与行距、`?` 在非 US 键盘布局上的触发、聊天输入框聚焦时输入 `?` 是否被文本层完全吞掉（沿用既有「文本域先消费按键」的结论，未实机复核）、面板在沉浸式（窗口全屏/PiP）里的观感与焦点回归、菜单项在手机/平板（无实体键盘）上的信息价值取舍。

### A7（2026-11-01 05:15）

- 文件：`page/room_orientation.dart`（`kRoomFrameRatioMax` 2.4 / `kRoomFrameRatioMin` 0.5 成为有名字的默认边界，新增 `RoomOrientation.fillWidth`、`roomFramedRatio`、`roomFillsWidth`，对话框接收画面比例并只在超宽时多给一段）、`page/room_page.dart`（`_pictureRatio` 改走 `roomFramedRatio`，窄窗分支不再二次钳 2.4，浮动小窗改用同一组常量，⋮ 的「画面方向」把引擎上报的比例传进对话框）、`l10n/messages/room/room_{zh-CN,en}.i18n.json`（`orientationFillWidth`/`orientationHintWide` 各 1 键）。
- 行为：引擎上报的画面比例超过 2.4:1 时，⋮ →「画面方向」在自动/竖屏/横屏之外多出「铺满宽度」一段；选它并按确定后，这一路按自己的真实比例成框，画面与播放层的上下边贴合、横向占满舞台，不再被 2.4 的画框留出上下边。默认仍是 2.4 的钳制（控制条在很宽的画面里保有自己的高度），只有对这个房间显式选择才解除。画面没有超过 2.4:1 时不出现这一段；已存了铺满宽度但当前流不再超宽（或引擎还没上报）时，对话框按自动显示，成框也与自动一致。上限解除只作用于页内画面框：剧院、全屏/PiP、竖屏全屏本就由播放层铺满，浮动小窗仍按 2.4 钳制。
- 状态：无新增偏好键——选择写进既有的 `room.orientation` JSON（按房间存枚举名，新增值向后兼容），备份与设置刷新无需改动。
- 主题/平台：对话框沿用 `DsDialog` + `DsSegmentedControl`，四段在窄窗由组件自己堆叠；浅色/深色/手机/平板/TV 都由主题与组件决定。入口只在 ⋮ 里出现（房间级低频动作），没有新增底栏控件，宽度档位不变。
- 验证：`dart analyze lib` 0 issues；`flutter test test/live test/app` 103 passed；`flutter build bundle` exit 0；`dart run slang` 已生成；`dart format -l 120` 仅本次两个 Dart 文件；`tool/check_responsive.ps1` passed。
- 未验证：真实超宽源（如 21:9/32:9 的直播或推流）在桌面与手机上的实际观感——铺满宽度后画面与控制条、弹幕覆盖层的比例，窄窗（<840）里最矮画框是否还留得住状态卡；四段式分段控件在 320 px 手机与 TV 焦点下的观感；引擎在各平台上报的 `geometry.aspectRatio` 是否与画面一致（若上报错误，本例与 A7 的触发时机都会跟着偏）。

### A8（2026-11-01 05:38）

- 文件：`page/player_surface.dart`（新 `tv` 参数与 `_BarTier` 作用域；控制条、顶部条、画面适配/清晰度/线路选择器按档取尺寸）、`shared/player/media_bar_button.dart`（新 `focusRing`，聚焦时在按钮盒内描 2 px 画面白环）、`page/room_page.dart`（把已有的 `tv` 传给播放层）。
- 行为：TV 构建里播放层的两条常显横条换一档——控件从 32 px 长到 48 px、图标 16 → 20、条内间距 4 → 8 px、横条内边距与分隔线同步放大、音量滑杆 90 → 140 px；选择器标签从 caption 升到 label 并放宽到 128 px，顶部标题从 title 升到 heading；焦点落在任何控制条按钮或选择器上时按钮盒内描 2 px 白环（画面永远是深色，所以环用画面白而不是主题 `focus`——浅色主题的 `focus` 是深色，在视频上看不见）。
- 结构：档位通过本文件私有的 `_BarTier`（`InheritedWidget`）下发，`PlayerSurface(tv:)` 在整棵播放层外面包一层，`_BarIcon`、`_StreamPickerRow`、`_PlayerTopBarState` 直接读，避免把 `tv` 逐个穿过十几个 `_BarIcon` 调用点；`focusRing` 是 `MediaBarButton` 的显式开关（默认关），其它播放器（点播/红果/IPTV/浮动小窗）本轮不受影响。
- 状态：无新增偏好键、无新增 provider；档位只由启动时判定的 `FormFactor.tv` 决定。
- 验证：`dart analyze lib` 0 issues；`flutter test test/live test/app` 103 passed；`flutter build bundle` exit 0（05:36）；`tool/check_responsive.ps1` passed；`dart format -l 120` 仅本次两个 Dart 文件（`room_page.dart` 只加一行，格式化无改动）。
- 未验证：真机 TV 上的实际观感——48 px 按钮与 8 px 间距在 1080p/4K 距离下的密度、白环在明亮画面（雪景/白底 PPT）上是否仍然可辨（当前是纯白 2 px，没有外扩暗边）、顶部标题升到 heading 后长标题的省略点、音量滑杆在遥控器左右键下的步进手感、首帧自动聚焦时 Android TV 尚未按键、Desen 的 `:focus-visible` 规则会暂时不画环（首个方向键按下后出现）。

### B1（2026-11-01 06:05）

- 文件：`controller/sources/music_browse_source.dart`（新：`MusicAlbum`、`MusicAlbumDetail`/`MusicArtistDetail`、`MusicAlbumSource`/`MusicArtistSource` 能力位、`musicCapabilityOf` 拆歌词包装、`musicMainArtist`）、`controller/music_browse.dart`（新：两个 family provider 与按 sourceId 取能力）、`controller/sources/music_source_kw.dart`（实现两个能力位；`trackOf`/`_albumTrackOf` 补 `artistId` 元数据；`digest-13` 专辑歌单改走 `_albumPlaylist`）、`pages/music_album_page.dart`（新）、`pages/music_artist_page.dart`（新）、`widgets/music_browse_widgets.dart`（新：页头、加载/失败/不支持/空态、歌曲行、专辑卡）、`widgets/music_browse_links.dart`（新：`openMusicAlbum`/`openMusicArtist`/`musicTrackArtistId`）、`pages/music_player_page.dart`（舞台歌手/专辑行改为链接）、`widgets/music_widgets.dart`（歌曲详情里的歌手/专辑行可点开）、`music.dart`、`app/routing/navigation/route_names.dart` 与 `app/routing/router/app_router.dart`（`/music/album/:sourceId/:albumId`、`/music/artist/:sourceId/:artist` 两个手写路由，带 `ScrollEdgeControls`）、`l10n/messages/music/music_{zh-CN,en}.i18n.json`（16 键/语言）。
- 数据/能力：只有酷我（kw）声明 `MusicAlbumSource`/`MusicArtistSource`，其余四个内置源没有这一位——打开它们的专辑/歌手页会明确写「该来源不支持专辑浏览/歌手浏览」并点名平台，而不是给出一个看起来像平台答案的空页。能力位要隔着歌词缓存包装往下找（`CachedLyricSource.inner`，`DisplayLyricSource` 继承它），否则每个源都会被判为不支持。
- 接口（2026-11-01 实测，curl）：专辑 `search.kuwo.cn/r.s?stype=albuminfo`（要带 `mobi=1&newver=1&client=kt&uid=0&rformat=json` 才回严格 JSON；旧的浏览器参数回的是单引号对象，`jsonDecode` 会失败——原 `digest-13` 专辑歌单因此一直是坏的，本次一并修好）；歌手歌曲没有可直接调用的列表接口，取平台搜索并按 ARTIST 过滤（100 条/次）；歌手专辑用 `ft=album` 搜索（rn=50，rn=100 会被退回 10 条）并按 artist 过滤；歌手本名与头像用 `stype=artistinfo`。
- 行为：播放页舞台的歌手行、专辑行（有 `albumId` 时）改为链接，悬停出现下划线，`semanticLabel` 为「查看歌手/查看专辑」；歌曲详情弹窗里的歌手/专辑行同样可点开（先关弹窗再进页）。专辑页＝封面＋名称＋歌手（进歌手页）＋来源/曲数/年份＋「全部播放」「加入歌单」＋曲目表；歌手页＝头像＋名称＋来源/曲数/专辑数＋两个动词＋歌曲表＋专辑横排（点开专辑页）。两页都有加载、失败重试、不支持、空态；Esc 与返回按钮都回上一页。
- 状态：无新增偏好键、无新增持久化；`artistId` 只作为曲目元数据随 `MusicTrack.metadata` 传递，路由参数不写盘。
- 验证：`dart analyze lib` 0 issues；`flutter test test/live test/app test/music` 216 passed；`flutter build bundle` exit 0（06:04）；`dart run slang` 已生成；`dart format -l 120` 仅本次改动的 12 个 Dart 文件；`tool/check_responsive.ps1` passed。
- 未验证：真实观感与手感——专辑页封面在 320 手机与 4K 桌面上的比例、歌手页头像与按钮在窄窗的换行、专辑横排在触屏上的拖动、浅色/深色主题下链接色的对比、TV 方向键在专辑卡上的焦点顺序（歌曲行本身不可聚焦，与榜单一致）、合作曲目只取第一位歌手的取舍、来自无 `ARTISTID` 的歌（博单等）时歌手页没有头像。

### B2（2026-11-01 06:19）

- 文件：`widgets/music_now_playing_bar.dart`（左/中/右三组、按条宽分档、音效与输出入口）、`pages/music_eq_center_page.dart`（新增 `MusicEffectsPage`：带页头的推入版本，Esc 返回）、`app/routing/navigation/route_names.dart`（`/music/effects`）、`app/routing/router/app_router.dart`（路由挂载，复用同一个 `MusicEqCenterPage`）。
- 布局（§18.3）：左＝封面、歌名/歌手、收藏；中＝播放模式、上一首/播放/下一首，宽档在下面加进度（时间 + 可拖滑杆）；右＝歌词、音效、音质胶囊、静音/音量、输出设备、队列。档位按**播放条自身宽度**判定而不是窗口宽度（侧栏先占一截，窗口宽不等于条宽）：≥1020 全量（含进度行与输出设备），≥720 三栏（无进度行、无输出设备），<720 退为封面/歌名/歌手 + 播放/下一首 + 收藏 + 队列，<460 再让掉上一首。标题始终占剩余宽度、单行省略，不因为收按钮被压到不可读。
- 行为：音效入口推入 `/music/effects`——页面就是侧栏「音效中心」的同一个 `MusicEqCenterPage`，只是带自己的返回页头，因此浏览页的停留位置留在原处；输出设备入口是菜单，列出引擎上报的设备、当前项打勾，选择后调用 `selectAudioDevice` 并 invalidate 设备列表；引擎只报一个或零个设备时该入口**不出现**（与设置行同一条规则）。收藏从右侧控制簇挪到左侧信息组（标准把收藏归在左侧）。
- 状态：无新增偏好键、无新增持久化；设备列表读既有 `musicAudioDevicesProvider`，不改引擎选择本身。
- 主题/平台：沿用主题 token、`DsButton`/`DsMenuAnchor`/`DsMenu` 与既有尺寸；浅色/深色都由主题决定。迷你播放器尚无 TV 专用档（§18.3 的 TV 版式未在本项内），已在未验证项列出。
- 验证：`dart analyze lib` 0 issues；`flutter test test/live test/app` 103 passed；`flutter test test/music` 113 passed；`flutter build bundle` exit 0（kernel_blob 06:17）；`dart format -l 120` 仅本次四个 Dart 文件（两处重排）；`tool/check_responsive.ps1` passed；无 l10n 改动（音效/输出沿用 `music.eqCenter`、`music.audioOutput`），故未跑 slang。
- 未验证：实际观感与手感——720/1020 两个分界处三栏的挤压（尤其中英切换后音质胶囊的宽度）、窄条在 320 手机上标题与两个按钮的比例、左移后的收藏在触屏上的命中、音效推入页的页头与滚动、输出设备菜单在真实多设备机器上的排序与选择生效、TV 上的迷你条尺寸与焦点（本项未覆盖）；真实登录/发声链路未跑。

### B3（2026-11-01 06:43）

- 文件：`controller/music_ui_settings.dart`（`MusicPlayerMode.label`、`MusicStageOverride`/`musicStageOverrideProvider` 会话内覆盖）、`pages/music_player_page.dart`（药丸行改 `Wrap`，新增模式胶囊与音效入口，舞台模式改由「本次运行的覆盖 ?? 默认值」决定）、`pages/music_settings_pane.dart`（选项改走 `label`，注释说明该行是默认值）、`l10n/messages/music/music_{zh-CN,en}.i18n.json`（`playerMode`/`playerModeDesc` 改写为默认值语义，新增 `playerModeSwitch` 1 键/语言）。
- 行为：播放页药丸行在收藏/下载/评论/音质之后新增「模式胶囊」——显示当前模式的图标与名称（标准=封面图标、黑胶=唱片、歌词=字幕），点开是三项勾选菜单，选中即切换舞台；同一行末尾是音效入口，推入 `/music/effects`（与迷你条、侧栏同一个 `MusicEqCenterPage`，Esc 返回播放页）。设置里的同一项改称「默认播放器模式」，只决定播放页打开时的初始舞台；播放页里的切换写进会话内 `musicStageOverrideProvider`（不持久化、不改写默认值），本次运行内跨开关页保持，重启后回到默认。
- 结构：药丸行从 `Row` 改为 `Wrap`（居中，8 px 间距）——320 手机上六枚控件自动折行而不是被裁切；胶囊与菜单沿用 `DsButton`/`DsMenuAnchor`/主题 token，无新增组件库依赖。
- 状态：无新增偏好键（`music.playerMode` 仍是默认值，备份与设置刷新不变）；新增的 `musicStageOverrideProvider` 只是运行时视图状态，不写盘。
- 主题/平台：浅色/深色由 DsButton 与菜单主题决定；TV 焦点由组件提供；无轨道/无歌时药丸行本就不出现（沿用既有空态）。
- 验证：`dart analyze lib` 0 issues；`flutter test test/live test/app test/music` 216 passed；`flutter build bundle` exit 0（kernel_blob 06:42）；`dart run slang` 已生成；`tool/check_responsive.ps1` passed；`dart format -l 120` 仅本次 3 个 Dart 文件。
- 未验证：运行期观感——模式胶囊在浅色/深色主题下的对比与图标可读性、320 手机上六枚控件的折行断点与两行高度、胶囊菜单在 TV 遥控器上的展开与焦点、从播放页推入音效页再按 Esc 返回后的焦点位置、默认值与本次运行覆盖在用户心里是否读得通（设置改了默认、播放页这次切过之后重开是否期望仍停在默认）、歌词模式下胶囊与滚动歌词的相对位置。

### B4（2026-11-01 06:55）

- 文件：`widgets/music_lyric_panel.dart`（同步歌词行改为 `DsPressable` + `DsFocusRing`，新增 `_seekToLine`）。
- 行为：**同步歌词**的每一行都是可点目标——点击（或键盘/遥控器聚焦后回车/空格）就跳到该句的起点播放；悬停/键盘聚焦时整行铺 `colors.hover` 底色，鼠标指针为手型，键盘焦点用主题 `focusOffset` 环。点行前先取消三秒回弹计时并收起擦洗线，避免跳转后还挂着上一次拖拽的覆盖层。**不同步歌词**（纯文本、没有时间轴）保持普通文本，不做假跳转。
- 拖动擦洗保留原样：只有设置里「拖拽歌词调整进度」打开时才会出现擦洗线与「从此句播放」按钮；点行与拖动在同一个手势竞技场里互不抢——拖动时滚动视图赢，点按才触发跳转。
- 状态：无新增偏好键、无新增 provider、无新增设置项（点行跳转始终可用，不跟随「拖拽歌词」开关）；无 l10n 改动（屏幕阅读器按行内文本 + 按钮角色播报）。
- 主题/平台：悬停底色与焦点环都取主题 token，浅色/深色一致；触屏、桌面、TV 共用同一实现，TV 上歌词行进入焦点顺序，回车即跳。
- 验证：`dart analyze lib` 0 issues；`flutter test test/live test/app` 103 passed；`flutter test test/music` 113 passed；`flutter build bundle` exit 0（06:53）；`dart format -l 120` 仅本次 1 个 Dart 文件。
- 未验证：真机手感——点按与滚动的判定边界（快速滑动时是否偶发跳句）、悬停底色在浅色主题下的对比、歌词行进入 TV 焦点顺序后在几十行歌词里的遍历长度、聚焦行被自动滚动带走后的焦点位置、点行跳转后面板回弹的动画观感。

### B5（2026-11-01 07:17）

- 文件：`widgets/music_queue_panel.dart`（分组、已播放折叠、两组的按页显示、本地文件探测）、`widgets/music_widgets.dart`（`MusicSongRow.unavailableReason`：标题降为 `textSubtle`、标题旁 `DsBadge`）、`controller/music_playback.dart`（`MusicFailedTracksController`/`musicFailedTracksProvider` 记录本会话被引擎拒绝的曲目；`MusicQueueRevisionController`/`musicQueueRevisionProvider` 在对调队列顺序后通知重建；`playOrder` 把队列位置按**播放顺序**给出）、`l10n/messages/music/music_{zh-CN,en}.i18n.json`（5 键/语言：`queueUpNext`、`queuePlayed`、`queueShowMore`、`queueMissingFile`、`queueUnplayable`）。
- 分组（§18.6）：列表在播放头处切开——**已播放**（播放头之前，最近播放的在上，默认折叠，点组标题展开/收起，行不可拖动）与**接下来播放**（从当前曲开始，可拖动排序，拖动映射回真实队列下标）。分组按 `playOrder` 而不是列表下标计算：随机模式下取引擎已经物化的 `shuffleOrder`、以光标位置为界，所以「已播放」在随机下也是真的播放过；随机模式的顺序是随机排列，行不提供拖动手柄（拖动只会重掷排列），`DsReorderableList.onReorder` 传 null 即退回普通列表。当前曲固定高亮，定位仍按每首歌一次 `ensureVisible`。
- 单曲失效态：本地曲目在面板打开/队列成员变化时异步探测 `File(localPath).exists()`（每首歌一次，签名去重，不阻塞帧），文件不在则标「文件丢失」；远程曲目由播放控制器记录引擎本次会话的失败（`state.error`，跳过逻辑之外单独记），同一首重新成功加载时清掉标记，行上标「无法播放」。两种标记都只改行的呈现（标题变弱 + 徽标），不禁止试播或移除——文件恢复/重试成功会自行消失。
- 超长提示：两组合计只画第一页 100 行，余量用「显示更多（还有 N 首）」按钮逐页展开；已播放默认折叠，所以面板打开时落在正在播放的歌附近，几百首的队列也不一次建完。切歌时两页数与折叠状态回到初始（播放头变了，上下文也变了）。
- 结构细节：引擎的对调快照在 `(track, index, length)` 上与上一帧相等，面板不会自己重建；`musicQueueRevisionProvider` 只在 `moveInQueue` 成功后自增一次，避免为了顺序而 watch 整份播放状态（位置跳动会带着整块面板重建）。
- 状态：无新增偏好键、无新增设置项；`musicFailedTracksProvider` 与 `musicQueueRevisionProvider` 都是运行时状态，不写盘、不进备份与设置刷新。
- 主题/平台：组标题用主题 `label`/`textMuted` + `hover` 底与 `focus` 环（`DsPressable` + `DsFocusRing`）；徽标用 DsBadge 主题样式；浅色/深色、桌面/手机/TV 共用同一实现，TV 上组标题是一个焦点位、行沿用既有焦点顺序。
- 验证：`dart analyze lib` 0 issues；`flutter test test/live test/app` 103 passed；`flutter test test/music` 113 passed；`flutter build bundle` exit 0（kernel_blob 07:16）；`dart run slang` 已生成；`dart format -l 120` 仅本次三个 Dart 文件；`tool/check_responsive.ps1` passed。
- 未验证：真机观感与手感——几百首队列滚动/折叠时的帧率、展开「已播放」时列表跳动的观感、徽标在浅色/深色与播放行（accent 底）上的可读性、随机模式下「已播放/接下来播放」是否符合用户直觉、TV 上组标题与两段列表的焦点顺序、Android 上 file_picker 返回的路径形态（若为 content URI 会被误判为文件丢失）、播放失败标记与「自动跳过」同时开启时的闪烁。

### B6（2026-11-01 07:39）

- 文件：`widgets/music_spectrum.dart`（新：`MusicSpectrum` 三档绘制、静默态、只重绘自绘层）、`pages/music_player_page.dart`（删除页内私有 `_Spectrum`/`_SpectrumPainter` 与三个随之无用的 import，改挂 `MusicSpectrum`）、`controller/music_ui_settings.dart`（`MusicSpectrumStyle { bars, circle, wave }`；`MusicUiVisibility` 改名 `MusicUiSettings` 并携带 `spectrumStyle`；新增 `setSpectrumStyle`；JSON 增加 `spectrumStyle`，缺省柱状）、`controller/music_playback.dart`（新增 `waveform` 暴露引擎 PCM 流，`spectrum` 仍是 FFT）、`pages/music_settings_pane.dart`（「频谱样式」选择行，紧随播放频谱开关；开关关闭时行保留但禁用）、`l10n/messages/music/music_{zh-CN,en}.i18n.json`（5 键/语言；`uiSpectrumDesc` 由「频谱条」改为「频谱」）。
- 三档（§18.8）：柱状＝FFT 平滑频段、底部对齐的圆头竖条（沿用原观感）；圆形＝同一组频段作为从外环向内生长的辐条，画布高 104 px；波形＝引擎 **PCM 时域数据**的镜像包络（填充 22% + 上下描边），画布高 44 px。波形取真实输出采样、每帧压成 96 个峰值桶，而不是把频谱曲线伪装成波形。
- 静默态：暂停、静音、或尚未收到任何帧时不再冻结上一帧，而是画各自的静止形态（柱状＝底部细线、圆形＝暗环、波形＝中线），颜色为 `colors.textSubtle` 40%；恢复播放后新帧到达即恢复。内核根本没有 tap（或该样式所需的那条返回 null）时整条不出现，与旧行为一致。
- 性能（§18.8「高频数据更新不能导致整个页面频繁重建」）：帧只写 `ValueNotifier`，`CustomPaint` 用 `repaint` 监听它，因此 30 Hz 更新只触发重绘，不触发 build 或布局；只订阅当前样式需要的那条 tap（柱/圆＝`stream.fft`，波形＝`stream.pcm`），切换样式时取消另一条——引擎的 tap 按监听者惰性启动，未监听的那条不产生 FFT 计算；PCM 在监听回调里降采样，画布外不保留原始采样。
- 状态：无新增偏好键——样式写进既有 `interface.musicUi`（`{"hidden":[…],"spectrumStyle":"bars"}`）；旧存档没有该字段时按柱状读，重置回到柱状；备份清单、设置刷新控制器与偏好门禁的三项计数均不变。
- 主题/平台：颜色取 `DsTheme` 的 `accent` 与 `textSubtle`，浅色/深色一致；设置行用 `SettingsChoiceRow`（桌面下拉、触屏整行选择+确认），关闭频谱时该行禁用而不是消失。频谱是纯绘制层，不进入焦点环，TV 不新增焦点位。
- 验证：`dart analyze lib` 0 issues；`flutter test test/live test/app` 103 passed；`flutter test test/music` 113 passed；`flutter build bundle` exit 0（kernel_blob 07:38）；`dart run slang` 已生成；`dart format -l 120` 仅本次 5 个 Dart 文件；`tool/check_responsive.ps1` passed；`tool/check_prefs_manifest.ps1` passed（368 prefs / 353 backup / 132 invalidations）；`tool/check_settings_ia.ps1` passed（75 sections / 61 pages / 305 hits）。
- 未验证：真实观感与手感——圆形档在 104 px 下 64 根辐条的密度（窄窗与 4K 桌面）、波形档的幅度映射（安静段是否过平、响段是否贴边）、三档静默形态在浅色主题玻璃舞台上的对比、切换样式时舞台高度 44↔104 的跳动、PCM tap 在各后端（Windows/macOS/Linux/Android）的实际产出与声道布局、引擎静音时 PCM 是否真的归零、页面被其它音乐页盖住但未销毁时仍占用 tap 的 CPU（本轮未加离屏暂停）。

### B7（2026-11-01 07:58）

- 文件：`controller/music_browse.dart`（新增 `MusicAlbumLink`/`MusicArtistLink`、`kMusicBrowseRailSize`、`musicHistoryAlbumsProvider`/`musicHistoryArtistsProvider`）、`widgets/music_browse_widgets.dart`（新增 `MusicArtistCard`）、`pages/music_recommend_view.dart`（两条 rail 与空态条件）、`l10n/messages/music/music_{zh-CN,en}.i18n.json`（`recAlbums`/`recArtists` 各 1 键/语言）。
- 数据来源：平台没有「新碟/歌手列表」接口，所以两条 rail 不再向平台要一份不存在的推荐流，而是从**本机播放历史与收藏**里取真实署名：最近播放在前、收藏补齐，按 `(sourceId, albumId)` / `(sourceId, 歌手首名)` 去重，各取前 12。专辑卡复用 `MusicAlbumCard`（封面来自曲目自身的 `coverUri`），歌手卡是新的圆形卡（首字母兜底＋歌手名＋平台显示名）。能力位仍由 B1 的 `MusicAlbumSource`/`MusicArtistSource` 判定：只有 kw 的曲目会出现在 rail 上，其余平台的曲目被过滤，不产生点了才知道不支持的卡片。
- 行为：rail 位于「继续播放」歌曲表之后、「热门搜索」之前——先看播过的歌，再看这些歌指向的专辑与歌手；点卡片分别推入 `/music/album/...` 与 `/music/artist/...`（与 B1 页面同一套路由）。曲目缺 `albumId`/专辑名或歌手名为空时跳过；没有可指向的内容时整条 rail 不出现（与歌单/榜单同规），首页空态判断也把这二者计入。
- 状态：无新增偏好键、无新增持久化、无新增设置项；两个 provider 只是对既有 `music.recent` / `music.favourites` 的派生。
- 主题/平台：卡片沿用 `DsCard`/主题 token 与 `CoverFallback`；横排在窄窗可拖动、宽窗一次铺满，TV 焦点由 DsCard 提供。无写死颜色。
- 验证：`dart analyze lib` 0 issues；`flutter test test/live test/app` 103 passed；`flutter test test/music` 113 passed；`flutter build bundle` exit 0（kernel_blob 07:54）；`dart run slang` 已生成；`dart format -l 120` 仅本次 3 个 Dart 文件（无改动）；`tool/check_responsive.ps1` passed。
- 未验证：真机观感与手感——kw 搜索行通常不带封面，专辑 rail 多数会落到首字母兜底瓦片，实际密度需实机看；专辑卡（152）与歌手卡（128）并排时的高度差（专辑有事实行、歌手有平台行）在 rail 里是否显得参差；12 张卡在 320 手机与 4K 桌面的横排密度与触屏拖动；浅色/深色下兜底瓦片与标题的对比；TV 上从 rail 末尾返回时的焦点遍历；点击后专辑/歌手页的真实网络结果（本会话未跑联网）。另外这条 rail 只覆盖有专辑/歌手能力的 kw，其它平台用户的首页不会出现这两条，属预期。

## 计划收口（2026-11-01 08:36）

A1–A8、B1–B7 共 15 项的代码与静态验证均已完成，表内没有「待做」。共同剩余缺口只有真机运行期验收：观感、手感、TV 焦点顺序、联网结果、各后端 PCM 采样与设备上报，逐项写在各节「未验证」里，需按 `docs/recording-runtime-qa.md` 的方式补走查。

复验（2026-11-01 08:32–08:35）：`dart analyze lib` 0 issues；`flutter test test/live test/app` 103 passed；`flutter test test/music` 113 passed；`flutter build bundle` exit 0；生成 l10n 晚于 room/music 源文件。

第三次独立复核（2026-11-01 08:54–08:57）：表内仍无「待做」，本轮逐行读了此前只做接线抽查的 A5–A8 与 B5（剧院玻璃层由 `PlayerSurface.overlay` 插槽承载、`T` 只在宽窗入绑定表；`roomShortcutBindings` 单表同时生成 `CallbackShortcuts` 映射与 `?` 帮助面板；`roomFramedRatio` 只对 `fillWidth` 解除 2.4 上限、对话框只在超宽时给该项；`_BarTier` 下发 TV 档、`MediaBarButton.focusRing` 画画面白环；队列按 `playOrder` 在播放头切分，`moveInQueue(upNext[from], upNext[to])` 与 `DsReorderableList` 的「移动后下标」契约一致，随机模式 `onReorder` 置 null），未发现需要改代码的缺陷。复验：`dart analyze lib` 0 issues；`flutter test test/live test/app` 103 passed；`flutter test test/music` 113 passed；`flutter build bundle` exit 0（增量缓存命中，kernel_blob 未变）。**记录一个 watch 项**：队列行 key 仍是位置键（`queue-slot-$queueIndex`），desen_ui 文档要求 key 随条目移动；Flutter 3.47 的 `SliverReorderableList` 抬手时才回调重排、行无内部状态，故当前无可观察缺陷，真机拖动时留意即可。

第四次独立复核（2026-11-01 09:13）：表内仍无「待做」，本轮补做符号与接线抽查——A4 `ChatSplitter` 在宽屏与剧院两处都接 `preview`→`set`（拖动中只改状态、抬手落盘一次）、双击回 `kChatPanelWidthDefault`、TV 下 `keyboard: false` 不进焦点环；A5 `roomTheaterProvider` 与 `T` 绑定、A6 `roomShortcutBindings` 单表、A7 `roomFramedRatio`、A8 `_BarTier` 均在页内真实接线；B1–B7 的 `MusicAlbumSource`、`musicStageOverrideProvider`、`musicFailedTracksProvider`、`MusicSpectrumStyle` 均在位。未发现需要改代码的缺陷。复验：`dart analyze lib` 0 issues；`flutter test test/live test/app` 103 passed；`flutter test test/music` 113 passed；`flutter build bundle` exit 0（真实重编译，kernel_blob 09:12 更新）。

后续新增 UI 项请在下方表格追加一行、状态写「待做」，不要复用已完成的行；本页没有新行即表示计划已清空。

### 第五次复核（2026-11-01 09:30–09:35）

表内仍无「待做」，A1–A8、B1–B7 全部 ✅，未复用已完成的行，本轮不改代码。复验：`dart analyze lib` → 0 issues；`flutter test test/live test/app test/music` → 216 passed；`flutter build bundle` → exit 0（增量缓存命中，kernel_blob 未变）；`list_chat_sessions` 全部 cold，工作区自上一轮 09:13 复核后无新写入（`lib/` 内 09:00 后只有 `shared/images/app_image_cache.dart` 一处，早于上一轮）；计划项关键符号（`ChatSplitter`、`roomTheaterProvider`、`roomShortcutBindings`、`roomFillsWidth`、`_BarTier`、`MediaBarButton.focusRing`、`MusicAlbumSource`、`musicStageOverrideProvider`、`musicFailedTracksProvider`、`MusicSpectrumStyle`）均在位且有真实引用。

**候选后续项（需确认，未实施）**

1. **B6 残留：频谱在播放页被盖住时仍保持 tap 订阅。** `MusicSpectrum` 只在 `dispose` 时取消订阅，播放页被 `/music/effects`、专辑页或歌手页盖住时 FFT/PCM tap 仍在跑。看起来照 `room_page` 的 `RouteAware` 惯例接上即可，但 `RouteObserver<ModalRoute<void>>` 的 `didPushNext` 对透明对话框同样触发——直接接会让 44/104 px 的舞台在弹窗背后塌成 0 高；而给共享观察器加「只认不透明路由」的过滤，会改掉 VOD/红果播放页既有的「任何路由压上来都暂停」语义（`vod_video_page.dart`、`hongguo_player_page.dart` 都依赖它）。正确做法是新增一个只服务音乐页的不透明路由观察器，并挂到各窗口的 navigator 上——属结构决策，未擅自实施。
2. **B5 观察项：队列行 key 仍是位置键**（`queue-slot-$queueIndex`），`desen_ui` 文档要求 key 随条目移动。当前行没有内部状态、`SliverReorderableList` 抬手才回调重排，未观察到缺陷；真机拖动时留意即可。

15 项的剩余缺口仍是真机/联网运行期验收（观感、手感、TV 焦点、联网结果、各后端 PCM 与设备上报），本会话无 GUI，无法补走查。

### 第六次复核（2026-11-01 09:53）

表内仍无「待做」，本轮不改代码，只做独立复验与一处**测量更正**。

- 工作区：`list_chat_sessions` 全部 cold，没有 running 会话；`lib/` 内最后一次写入是 07:51（`music_browse_widgets.dart`），早于第四次复核，本轮读到的文件与 09:13 复核时一致（`chat_splitter.dart` 04:32、`room_page.dart` 05:33、`music_spectrum.dart` 07:35）。
- 符号抽查（引用计数）：`ChatSplitter` 9、`roomTheaterProvider` 5、`roomShortcutBindings` 3、`roomFillsWidth` 2、`_BarTier` 11、`MediaBarButton.focusRing` 4、`MusicAlbumSource` 4、`musicStageOverrideProvider` 4、`musicFailedTracksProvider` 3、`MusicSpectrumStyle` 25、`MusicSpectrum` 30——A5–A8、B1–B6 的关键接线仍在位。
- 复验：`dart analyze lib` → 0 issues；`flutter test test/live test/app` → 103 passed；`flutter test test/music` → 113 passed；`flutter build bundle` → exit 0（增量缓存命中，`kernel_blob.bin` 仍是 09:12，与上一轮相同）。l10n 生成（`translations.g.dart` 07:51）晚于 room/music 源文件，无需重跑 slang。无新增偏好键。
- **候选 1（B6 离屏 tap）的前提被测量推翻**：上一轮记录「需要新增只服务音乐页的不透明路由观察器，属结构决策」。实测 Flutter 3.47.7 的 `OverlayState.build`（`packages/flutter/lib/src/widgets/overlay.dart:907`）对被不透明条目盖住、但 `maintainState` 为真的条目设 `tickerEnabled: false`，即 `TickerMode.of(context)` 在被 `/music/effects`、专辑页、歌手页（均为不透明路由）盖住时已经是 `false`，被弹窗（非不透明）盖住时仍是 `true`——正好是想要的语义。仓内也已有同款用法：`modules/live/multiview/multiview_page.dart:441` 就是用 `TickerMode.valuesOf(context).enabled` 决定 `playback.setActive`。
- 修正后的结论：该残留可以在 `music_spectrum.dart` 内部解决——`build` 里读 `TickerMode.of(context)`，为 `false` 时 `_bind()` 退订两条 tap、回到 `true` 再绑回（舞台高度不变，画静默态，不会像 `RouteAware` 方案那样塌成 0 高），不新增观察器、不改 `routeObserverProvider` 对点播/红果「任何路由压上都暂停」的既有语义。本轮**仍未实施**：计划表已清空、该项在上一轮被标为「需确认」，按任务书不擅自扩范围；需要用户一句话放行，下一轮即可按上述方案落地。
- 候选 2（B5 队列行位置键）维持 watch，本轮未观察缺陷。

计划内 A1–A8、B1–B7 已全部完成，剩余工作只有两类：一是 15 项的真机/联网运行期验收（本会话无 GUI），二是候选 1 待放行。

### 第七次复核（2026-11-01 10:12）

表内仍无「待做」，本轮按任务书顺序查找首项时即已清空，不改代码、不追加新项。复验：`dart analyze lib` → 0 issues；`flutter test test/live test/app` → 103 passed；`flutter build bundle` → exit 0（增量缓存命中，`kernel_blob.bin` 仍是 09:12:07）；`list_chat_sessions` 全部 cold（无 running 会话）；09:53 之后 `apps/pure_live/lib` 无写入（最后一处是 09:00 的 `shared/images/app_image_cache.dart`）；无 l10n 改动（未跑 slang）；无新增偏好键。

阻塞项（未实施，均不属于「待做」行）：

1. **候选 1：B6 频谱离屏 tap。** 第六次复核已用实测把方案从「新增不透明路由观察器」修正为「`music_spectrum.dart` 内部按 `TickerMode.of(context)` 退订/重订 tap」，但该项在第五次复核时被标为「需确认」，计划表也无对应行；按任务书「不擅自扩范围」，本轮继续停在这里，需用户一句放行。
2. **候选 2：B5 队列行位置键。** 维持 watch，无观察到的缺陷，真机拖动时留意。
3. **15 项真机/联网运行期验收。** 观感、手感、TV 焦点顺序、真实超宽源、联网结果、各后端 PCM 采样与设备上报，本会话无 GUI，无法补走查。

### 第八次复核（2026-11-01 10:30–10:36）

表内仍无「待做」，A1–A8、B1–B7 全部 ✅，本轮不改代码。工作区 114 项未提交改动都属此前批次已记录的成果（音乐设置拆分、下载工作区、A1–A8、B1–B7），保持不变；`list_chat_sessions` 全部 cold（无 running 会话），`apps/pure_live/lib` 自 09:00（`shared/images/app_image_cache.dart`）后无写入，与 10:12 复核一致。符号抽查（含该符号的文件数）：`ChatSplitter` 2、`roomTheaterProvider` 2、`roomShortcutBindings` 2、`roomFillsWidth` 1、`_BarTier` 1、`MusicAlbumSource` 3、`musicStageOverrideProvider` 2、`musicFailedTracksProvider` 2、`MusicSpectrumStyle` 3、`MusicSpectrum` 4——接线仍在位。复验：`dart analyze lib` → 0 issues；`flutter test test/live test/app` → 103 passed；`flutter test test/music` → 113 passed；`flutter build bundle` → exit 0（增量缓存命中，`kernel_blob.bin` 仍是 09:12:07）。无 l10n 改动（未跑 slang）；无新增偏好键。

阻塞项（与第七次复核相同，均不属「待做」行）：候选 1（B6 频谱离屏 tap，方案已定为在 `music_spectrum.dart` 内按 `TickerMode.of(context)` 退订/重订 tap，但上轮标「需确认」，需用户放行）；候选 2（B5 队列行位置键，维持 watch，无观察到缺陷）；15 项真机/联网运行期验收（观感、手感、TV 焦点顺序、真实超宽源、联网结果、各后端 PCM 采样与设备上报，本会话无 GUI）。

### 第九次复核（2026-11-01 10:50–10:58）

表内仍无「待做」，A1–A8、B1–B7 全部 ✅，本轮不改代码、不新增表格行。

- 工作区：`list_chat_sessions` 全部 cold（无 running 会话）；`apps/pure_live/lib` 自 07:51（`music_browse_widgets.dart`）后无写入；120 项未提交改动仍属此前批次成果，只读未触碰。
- 本轮补做此前几次复核没做的两项独立检查：
  1. **l10n 键完整性**——按扁平键集合比对两份语言文件：room 183 / 183、music 702 / 702，zh-CN 与 en **键集合完全一致、无空值**；计划项点名的 18 个键（`resizeChat`、`theaterOn/Off`、`orientationFillWidth/HintWide`、`queueUpNext/Played/ShowMore/MissingFile/Unplayable`、`playerModeSwitch`、`uiSpectrumStyle/Desc`、`spectrumStyleBars/Circle/Wave`、`recAlbums/Artists`）逐一条目存在。生成的 `translations*.g.dart`（07:51:51）晚于最新源文件（07:51:48），无需重跑 slang。
  2. **硬编码文案扫描**——`modules/live/room/page/` 与 `modules/music/` 的 CJK 命中全部是英文注释里引用的中文设置名（如 "the 弹幕 setting"）和歌词预览样例，没有用户可见的字符串字面量。
- 门禁：`tool/check_responsive.ps1` passed；`tool/check_prefs_manifest.ps1` 368 prefs / 353 backup / 132 invalidations（与前几轮一致，计划项未新增偏好键）；`tool/check_settings_ia.ps1` 75 sections / 61 pages / 305 hits。
- 复验：`dart analyze lib` → 0 issues；`flutter test test/live test/app` → 103 passed；`flutter test test/music` → 113 passed；`flutter build bundle` → exit 0（真实重编译，`kernel_blob.bin` 10:52）。
- 阻塞项不变：候选 1（B6 频谱离屏 tap，方案已定为 `music_spectrum.dart` 内按 `TickerMode.of(context)` 退订/重订，需用户一句放行）、候选 2（B5 队列行位置键，维持 watch）、15 项真机/联网运行期验收（本会话无 GUI）。

### 第十次复核（2026-11-01 11:12）

表内仍无「待做」，A1–A8、B1–B7 全部 ✅，本轮不改代码、不新增表格行。

- 工作区：`list_chat_sessions` 全部 cold（无 running 会话），120 项未提交改动仍属此前批次成果，只读未触碰。
- **更正前几轮的一处说法**：第五、七、八、九次复核写的是「`apps/pure_live/lib` 自 07:51 后无写入」。实测文件 mtime：今日 **10:40–10:41** 另有会话写入 6 个文件——`modules/live/search/search_page.dart`、`modules/live/search/web_search_page.dart`、`modules/live/toolbox/toolbox_controllers.dart`、`modules/live/toolbox/toolbox_page.dart`、`features/settings/dialogs/danmaku_color_dialog.dart`、`features/settings/dialogs/theme_color_dialog.dart`，合计 +47/−12 行。这 6 个文件都不在 A/B 计划项（直播间播放页、音乐模块）的代码路径上；本轮的三项验证已覆盖这些改动。
- 复验：`dart analyze lib` → 0 issues；`flutter test test/live test/app` → 103 passed；`flutter test test/music` → 113 passed；`flutter build bundle` → exit 0（增量缓存命中，`kernel_blob.bin` 仍是 10:52，即 10:40 的那批写入已包含在该产物内）。无 l10n 改动（未跑 slang）；无新增偏好键。
- 阻塞项与第七/八/九次复核一致，均不属「待做」行：候选 1（B6 频谱离屏 tap，需用户一句放行）、候选 2（B5 队列行位置键，维持 watch，无观察到缺陷）、15 项真机/联网运行期验收（观感、手感、TV 焦点顺序、真实超宽源、联网结果、各后端 PCM 采样与设备上报；本会话无 GUI）。

### 第十一次复核（2026-11-01 11:34）

表内仍无「待做」，A1–A8、B1–B7 全部 ✅，本轮不改代码、不新增表格行。

- 工作区：`list_chat_sessions` 全部 cold（无 running 会话）；`apps/pure_live/lib` 自 11:12 后无写入；120 项未提交改动仍属此前批次成果，只读未触碰。
- 本轮补做两项此前未做过的检查：
  1. **格式稳定性**——对 A/B 计划项涉及的 20 个 Dart 文件跑 `dart format -l 120 --output=none --set-exit-if-changed`，输出 `Formatted 20 files (0 changed)`、exit 0，说明这些文件当前仍符合 120 列格式，没有因后续会话写盘而漂移。
  2. **新增 l10n 键的引用情况**——计划项点名的 18 个键（`resizeChat`、`theaterOn/Off`、`orientationFillWidth/HintWide`、`queueUpNext/Played/ShowMore/MissingFile/Unplayable`、`playerModeSwitch`、`uiSpectrumStyle/Desc`、`spectrumStyleBars/Circle/Wave`、`recAlbums/Artists`）在 `lib`（排除 `l10n/` 生成物）中均至少 1 处真实引用，没有「加了文案却没人用」的死键。
- 门禁：`tool/check_responsive.ps1` passed；`tool/check_prefs_manifest.ps1` passed（368 prefs / 353 backup / 132 invalidations）；`tool/check_settings_ia.ps1` passed（75 sections / 61 pages / 305 hits）。
- 复验：`dart analyze lib` → 0 issues；`flutter test test/live test/app` → 103 passed；`flutter test test/music` → 113 passed；`flutter build bundle` → exit 0（增量缓存命中，`kernel_blob.bin` 仍是 10:52，与无源码改动一致）。
- 阻塞项不变：候选 1（B6 频谱离屏 tap，方案已定为 `music_spectrum.dart` 内按 `TickerMode.of(context)` 退订/重订，需用户一句放行）、候选 2（B5 队列行位置键，维持 watch）、15 项真机/联网运行期验收（观感、手感、TV 焦点顺序、真实超宽源、联网结果、各后端 PCM 采样与设备上报；本会话无 GUI）。
