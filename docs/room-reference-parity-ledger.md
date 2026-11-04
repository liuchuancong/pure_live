# 直播间对照参考（E:\study\Pure_live）优化台账

> 本文件是「参考 E:\study\Pure_live 优化直播间」这条任务线的唯一进度依据。
> 每轮先读本文件，挑队列最上面一项做完就勾选并补「运行记录」，**已核对为持平的条目不要重做**。
> 参考是 v5 旧架构（`apps/pure_live/lib/features/live_play` + `packages/live_*`），只读，不改。

## 车道规格

- 仓库：`D:\flutter\pure_live`（分支 `v2`）；播放/弹幕内核 `C:\Users\XA-158\projects\flutter\media_core`（分支 `main`，**授权可改**）。
- 提交/推送：英文 `feat/fix/perf(...)`；`dart analyze` 干净即提交并推送。media_core 只按 pathspec 提自己的文件。
- 验证门：改动目录 `dart analyze` 0 issues（app 侧 `apps/pure_live`；内核侧 `dart analyze packages` + 相应包 `flutter test`）。l10n 只跑 `dart run slang`，**不跑 build_runner**。
- 观感类改动不做构建/截屏/临时测试；运行期由用户自测。
- 禁区：`recorder_page.dart` / `recorder_library_pane.dart` / `recorder_card_parts.dart`（录像 lane 在改）；`favorites|popular|areas` 页面与 App 壳（壳层 lane 在改）；直播模块的设置导航顺序（用户点名不许重排）。

## 重新对照后的新队列（2026-11-04 第二次全量审计，自上而下）

> 来源：把参考 `features/live_play/player/*`、`danmaku/*`、`logic/room_menu_button.dart` 与我们 `room/page` + `room/chat` 逐控件再比一遍。已排除本表"已修/已持平"两节里的全部条目（含本轮 P23 的两处）。

- [x] **T13 关注动词进不去全屏**（P25 做完）。参考把 `FollowButton` 画在横屏底条（`player/player_controls.dart:700-705`）与竖屏顶条（`:375-383`）。我们只有页头那条 `_FollowPill`（`room/page/room_page.dart:1405-1427`），`roomMenuItems` 与顶条都没有关注 → 全屏里想关注必须先退出。**做法**：底条右侧加一枚 PlayerBarButton（关注/已关注两态，复用 `_FollowPill` 的 provider 与文案），别再开第二个状态。
- [x] **T14 页签不报「别处积了多少」**（P24 做完）。参考在 弹幕列表 页签上计未读、超级弹幕 页签上计条数（`danmaku/chat_panel.dart:97-117`）。我们五个页签标签是死的（`chat/room_chat.dart:88-96`）⇒ 停在屏蔽/录制页签时房间说了多少话完全看不出。**做法（设计已定，别再重新推导）**：计数要活在切页签不会销毁的地方——`_RoomChatPanelState` 里 `ref.listen(roomChatProvider)`，`tab != danmaku` 时按增量累加、选中 danmaku 页签时归零；超聊条数直接 `ref.watch(roomSuperChatsProvider).messages.length`。**用 `DsTab(count: …)`**（控件库自带计数与"99+/读屏"语义，别手搓 DsBadge Row）。在 danmaku 页签上当列表浮层已报过同一个数，那一档就别再显示（一行只说一次）。
- [ ] **T15 无锁定全屏**。参考 `bar_parts.dart:314-339` 的 LockButton 挂在右侧中（`player_view.dart:929-937`）：锁上后隐藏条、吞掉手势/滚轮（`:276`）。我们滚轮调音量与双击播放暂停在满屏时一直生效（`player_surface.dart:800-824`）⇒ 看电视时误触就改音量。
- [x] **T16 睡眠定时进不了全屏**（P26 做完）。`_SleepChip` 只在页头（`room_page.dart:1896`），`roomMenuItems` 没有它（参考在房间菜单里带剩余分钟第二行：`room_menu_button.dart:152,254-259`）。做法：菜单里加一组时长项，复用 `kAsmrSleepMinuteChoices` 与 `asmrSleepDurationLabel`，别再开一套选择器。
- [ ] **T17 桌面"在新窗口打开这间房"缺失**。参考 `room_menu_button.dart:166,357-359` 走 `DesktopWindow.openNewWindow`；我们有房间窗口（`room_opener.dart:46`）但房间菜单没有这一行。
- [x] **T18 被掩码名之外的一条：登录提示是常驻条**（P27 做完）。参考在列表上方常驻 `ChatNameHintBar` 并带登录按钮（`chat_list.dart:421-433,603-649`）；我们一次 toast 过完就没了（`controller/room_controller.dart:1646`）⇒ 错过了就只能等下一次连接。
- [ ] **T19 满屏钟与电量**。参考底条每分钟重画时钟/电量（`bar_parts.dart:22-144`）。桌面价值低（系统托盘已有），手机价值高：留到最后。
- [ ] **已判定不平**：参考的本地"+1/存为常用语"回放体系（`message_panel.dart:219-341`）——我们的发送框真发（`room_chat.dart:360+`），这是两套子系统的边界，不是缺功能；参考的投屏只有 Android（`player_controls.dart:177`），我们桌面也有（此项我们更强）。

## 已修（本轮线，全部已推送）

| # | 提交 | 面 | 内容 |
| --- | --- | --- | --- |
| P1 | media_core `70797f9` | 打开速度 | 直播输入用直播探测预算：`demuxer-lavf-probesize=1MiB`、`analyzeduration=1s`、`cache-on-disk=no`、`network-timeout=15`、`hwdec-software-fallback=1`（[media_kit_player_adapter_engine.dart:29](../packages/media_core_media_kit/lib/src/adapter/media_kit_player_adapter_engine.dart)）。参考实测同值首帧 1802→708 ms。属性可写性已用本仓 `libmpv-2.dll` FFI 探针验证（返回 0）。 |
| P2 | `0bd0006e6` | 打开速度 | bilibili `detail()` 不再等 `getDanmuInfo`（第二次签名请求，结果没人读，弹幕会话自己再取新的）。进房少一次请求；录制开播检测同样少一次。 |
| P3 | media_core `330d339` | 录制 | `UrlRefresher` 可带回 header（`RefreshedSource = ({url, headers})`），换线路才有对的 referer；`_relaunch` 换 `_activeSource`。 |
| P4 | `501df30ce` `7d30495eb` | 录制 | take 掉线后由引擎自己重签地址（按任务的画质、带该线 header），上一个尝试没写出字节就换下一条线；IPTV 等不能重签的平台回到"重开原地址"（不给 null，否则后端不再重试）。 |
| P5 | `408b96e2c` | 房间 | 后台重读不重建播放器（`refreshRoom({manual})`）。 |
| P6 | `0203294f9` | 录制 | 开播检测并发读（≤4 路），写与启动仍串行（引擎在登记会话前数 `maxTasks`）。 |
| P7 | `dc06e021a` | 录制 | 重签请求加 20 s 上限（它在进程已死时跑，挂了会把 take 冻住）。 |
| P8 | `eb8a4802e` | 弹幕列表 | 空态/失败态换 `_chatStateArea`：装得下居中、装不下滚动（日志里 343 px 溢出 8 次，溢出吃掉的正是"重试"按钮）。 |
| P9 | `01b0b418b` | 录制显示 | 指示器带 `figures`（时长后跟已写大小）与 `word`（等待开播/处理中/失败；此时不画红点），合并中不给按压。复用 recorder 组现有串。 |
| P10 | `25904bc61` | 弹幕列表 | 悬浮「{count} 条新消息」一键到底；计数按"到达条数"（列表有上限，按行数会自己变小像丢消息）。新串 `room.newMessagesCount`。 |
| P11 | `53993f089` | 录制显示 | 合并中的词带上进度百分比（`合成中 45%`，参考角标同款；`postProcessingProgress<0` 时只说"处理中"）。 |
| P12 | `fb25f1cf8` | 弹幕/shield | 礼物改走屏蔽名单：屏蔽某人后他的礼物行与飞行动画不再进屏（录制侧本来就拦，之前屏幕与文件两套行为）。gate 不参与——连击本就是多条包，`GiftChatFilter` 才是要合它的。 |
| P13 | `c4a1485e4` | 撤回 | 平台的 `retraction` 真正落实：`_onSiteMessage` 先分派它（空文本本来会被 shape/gate 丢掉），聊天列表按 `LiveRetraction.matches` 删行、只删 `chat` 类型（礼物与通知留下，同参考 `chat_feed.dart:285`），飞行层 `barrage.retractWhere` 把排队中和已在屏上的同三条匹配一并收回。测试 `apps/pure_live/test/live/room_retraction_test.dart`（4 例：按 id、按用户 id/昵称、all、无命中不动状态）。 |
| P14 | media_core `7c97dab` + `36c998de9` | 打开后聊天 | gate 的补发窗口：`DanmakuMessage.replayed` + `DanmakuConfig.maxReplayAge`（135 s＝参考里 17LIVE 的 resume 窗口），按消息选限长；未到 `endTime` 的付费卡不因时间丢。app 两处缝（`acceptExternal` 前与 `_ChatMirrorSink` 回落成 `LiveMessage`）都带上这个旗标，否则进了列表的历史会自称"现在说的"，`room_chat.dart:651` 的「之前发的」也永远不出现。 |
| P15 | media_core `cea97d6` + `eeeda8c10` | 正则屏蔽 | 房间终于吃 `/…/`：`DanmakuFilterPolicy` 加 `blockedPatterns`（host 编译好的 `RegExp`）与 `patternMatchLength=200` 上限，按原文匹配（大小写规则在编译时就定好了）；app 侧 `_shieldPolicyFor` 用 `live_sites` 的 `DanmakuBlockPattern` 拆词（格式与 ReDoS 判据只有一份，在站点包里），录制侧本来就用 `DanmakuBlockList`。屏蔽词输入框加 `acceptsPatterns`，跑不动的正则当场拒绝并说明原因（否则列表把它当空气、UI 却说"已添加"）；`keywordFieldHint` 说明 `/…/` 是正则。新串 `shield.patternRejected`/`patternTooSlow`。 |
| P16 | `6374af2c1` | 屏蔽纯表情/超长 | `danmakuMessageShape` 加可选 `emoticonPattern`；app 在 `danmakuShapeBlockedByRules` 里传 `EmojiAtlas.instance.regex`（就是聊天绘制用的那张表）。之前斗鱼/虎牙的 `[笑哭][笑哭]` 被当成 8 个字符：表情屏蔽放行、超长屏蔽多算。图集没加载完就退回旧读法（不因此拦掉没要求拦的行）。测试 `packages/live_sites/test/models/danmaku_text_shape_test.dart` 5 例。 |
| P17 | media_core `49e418c` + `af59be0f1` | 屏蔽可见 | 「本场已屏蔽 N 条」：引擎把 policy 的判定（屏蔽的人/词）用 `onSuppressed(message, reason)` 报给 host，app 只把**观众自己的四条**计入（屏蔽名、屏蔽词含正则、纯表情、超长）；重复/相似/重发不算——那度量的是房间有多吵，不是屏蔽有没有在跑。位置=房间屏蔽面板第一行（参考同处），设置页不放第二个入口。`RoomShieldCountController` 计数立刻、通知按帧合并；开房/关房/离场三处归零。新串 `shield.blockedThisStream`。测试：引擎 2 例（只报 policy、按名字算）、app 2 例（计数、归零）。 |
| P18 | `27daeda3f` | 稳定/秒开 | lease 驱动的提前换链：chzzk/douyu/fc2live/pandalive 的解析器会给 `LivePlayLease.requiresReconnect=true`，app 此前零读者 ⇒ 地址到期就是一段冻屏，直到引擎自己发现线死了才走恢复重签。现在 `_armLeaseRenewal()` 在 `refreshAt` 到点前重读计划并重开（同一条恢复路径，提前到故障之前）；能 resume 的线（FLV）继续不管——定时重开正是 T6 判过的那个缺口。换 handle 与换线两处重挂、`_teardown` 取消、已经过期的 lease 最少隔 5 s 再读（不空转）。 |
| P19 | `4e9150798` | 错误分类 | `LiveSiteError` 一次补齐三个判据（对齐参考 `live_core/site_error.dart:19,47-58,63-71`）：`isTransient`（只有 network 与 rateLimit 为真，其余一律假——猜一次就要花配额）、`retryAfter`（限流自带就带上）、`cookieSuspect`（登录被拒 ≠ 没登录）。生产者先只接 baidulive 的"弹幕签名过期"（唯一已经知道自己原因的地方）；测试 5 例（含相等性把新字段算进去）。 |
| P20 | `6f214f8ff` | 弹幕稳定 | 房间按新判据自己重连弹幕：blink 走 2 s/4 s/6 s 退避，限流按 `retryAfter`（没给就 15 s），不可重试的类不试；三次封顶后仍留给列上的"重试"按钮；`_installDanmaku` 成功归零、换房/`_teardown` 取消。被拒登录改用新串 `room.chatCookieExpired`，不再把平台英文诊断当 toast。 |
| P22 | `fdd1491b4` | 竖屏形态 | 窄窗竖屏源改成参考那套：画面满幅 + 底部三停靠点面板（新 `room/page/room_bottom_panel.dart`：`AnimationController.unbounded` + `onVerticalDrag*`，`dart:ui clampDouble`，动效取 `DsMotion.moveSpringOrNull`，reduce-motion 直接跳）。停靠点用参考实值：地板 250 px（不是百分比）、44 %、68 % 且给画面留 120 px；手柄行 48、grip 38×4（桌面画 grip，手机在中间放「竖屏全屏」入口——条上那个入口在窄 bar 会被自己的宽度门藏掉）；右侧 pill＝条上同一个全屏动词（本 app 不强制转屏，所以不冒充「横屏全屏」）。拖动只动面板：`onCoverChanged` 把落定高度交给 `PlayerSurface.bottomInset`，控制条与唤醒条抬到面板之上，视频不重建。横屏源仍堆叠，但信箱加 `min(width/ratio, height*0.6)`。玻璃卡从 `_RoomChatGlass` 提成 `room/page/room_glass_card.dart`，剧场与面板共用一层玻璃。门：`dart analyze lib` 0 issues、`flutter test test/live` 42 绿（仍只录像 lane 一红）。运行期未验证：停靠手感、键盘顶起面板、旋转回宽窗都要真机。 |
| P21 | `26bc82f77` | 录制显示 | 房间聊天列第 5 个页签「录制」＝参考右侧 RoomSidePanel 的只读状态卡：状态徽标、1 s 一跳的钟、`第 N 段 · 每 M 分钟一段`、chips 已录大小/平均码率/画质/弹幕条数，末了唯一动词＝打开录制中心（`RouteNames.recorder`，没有录制设置的深链就不挂第二个门）。为此引擎开一个公开读数 `RecorderEngine.chatEntries(taskId)`（写手本来就私有）；时钟复用 `RecordingIndicator.formatElapsed`（从 State 挪到 widget，一份两处用）；没开弹幕保存的 take 不出条数 chip（0 会被读成丢光了）。**不做**：页签里不放开始/停止/画质——条上和中心已有，重复就是两处会打架。

| P23 | `6a765f802` | 弹幕行动作 | 掩码名（`观***`）不再给「屏蔽此用户」：屏蔽列表把它读成“所有同前缀的人”，所以我们自己就把它当不拦任何词（`block_list.dart` 的 `isMaskedName`，为此从私有提出来共用），但行菜单照旧提供这一项、点了还说“已屏蔽” ⇒ 一行会藏掉一群人的动作。复制改成参考的 `名字: 内容`，并且复制的是列上显示的那串字（带表情码的原文不再进剪贴板）。 |
| P24 | `7412aeca7` | 页签计数 | T14 落地：聊天页签在**别的页签上**时按「最后看到的那条 id 之后有几条」计（不能按长度差——列表有 200 上限，满了以后长度不动），计数放在面板而不是列表（列表一切页签就被销毁）；用 `DsTab(count:)`让控件库自己画 99+ 与读屏；超聊页签是板上现存条数（付费卡按自己的时长挂着，那不是未读）。回到聊天页签即算读过；浮层那条计数继续管本页签。 |

| P25 | `b7464e12a` | 关注 | T13：房间菜单里加「关注/取消关注」。关注以前只在页头那枚 pill 上，而浮层/全屏时页头消失（`menuItems: widget.immersive ? widget.roomMenu : const []`）⇒ 满屏里想关注必须先退出。放菜单而不放底条：底条是画面自己的动词（播放/音量/源目录/窗口），房间的事在详情与切换旁边；pill 仍是非全屏的快捷入口，两处读同一个 `followsRoomProvider`，不会各说一奔。 |
| P26 | `5e4e68a05` + `67cd6c4cc` | 睡眠定时 | T16：定时关闭进房间菜单（弹一个 `showDsPanel` 面板，标题＝定时关闭，运行中则先给关闭项），并且时长列表成了一份 `roomSleepTimerChoices()`：原本 chip 的 hover 菜单里写了一遍十个分钟，菜单再写一遍就是下次加档位漏掉的那个地方。 **同时纠正自己**：本轮第三次犯同一个错——`dart format lib/modules/live/room` 把 gift_text/gift_flights/room_switcher 重排后跟着提交了，已用 `67cd6c4cc` 把三个文件退回原样。**只 format 本轮真改的那几个文件路径，别再指向目录。** |
| P27 | `6899475a4` | 登录提示 | T18：房间说"你看到的名字全是被打了码的"或"Twitch 的 cookie 被拒了"时，不再丢一枚 toast，而是在它影响的聊天列上方挂一条常驻条（`roomChatNoticeProvider` + `_ChatNoticeBar`），条上直接给「Cookie 登录」入口（`showAccountSignInAlternative(..., exit: AccountQrExit.cookiePage)`）与"我知道了"。toast  Shape 不对的原因：提示出现时人正在看画面，而修复是去登录页花一分钟，不是一瞥。条在下一次连接不再像登录死了时自己消失（`_installDanmaku` 清），换房/`_teardown` 也清 ⇒ 旧抱怨不会活得比造成它的那次登录长；同一房同一句话重复上抛不改状态（不闪烁）。 |

## 已核对为持平或更强（别重做，附证据）

| 面 | 参考 | 我们 |
| --- | --- | --- |
| 桌面条音量 | 条上 96 px 滑杆 + 静音（`player/bar_parts.dart:150`） | 宽条 `DsSlider`（TV 140 / 桌面 90）+ 静音（`room/page/player_surface.dart:1943`） |
| 控件隐藏 | 硬编码 4 s、淡 200 ms（`player/player_view.dart:345`） | 设置项 `controlsAutoHideSeconds`，面板打开/暂停/TV 不隐藏（`player_surface.dart:472`） |
| 聊天列 | `34% clamp(300,400)` + 22×56 折叠把手（`logic/room_layout.dart:317`） | 可拖 + 方向键/Shift + 双击复位 + `collapseChat` 折叠（`room/page/chat_splitter.dart`、`room_page.dart:1025`） |
| 名字色 | 平台色走到 ≥4.5:1 并缓存（`danmaku/chat_list.dart:31-78`） | 同机制（`room/chat/room_chat.dart:812-840`） |
| 弹幕行 | 徽章图片 + 粉丝牌 chip + 角色；名字 w600 +「：」；列表内无时间戳；无 maxLines | 最多 3 枚平台徽章 + 角色 + 粉丝牌 + 等级、`tagHeight` 统一、连续同人合并（`room_chat.dart:496-515`） |
| 竖屏 | 三停靠点拖面板（min 250 / 44% / 68%）+ 手柄 48 + grip 38×4 + 「横屏全屏」pill | 已同形态（P22：`room/page/room_bottom_panel.dart` 250 px 地板 / 44 % / 68 % 且给画面留 120 px、手柄 48、grip 38×4、右侧 pill；`PlayerSurface.bottomInset` 让控制条站到面板之上）|
| 沉浸式 | **absent**（只有 fullscreen / portraitFullscreen / windowFullscreen 三态） | 我们有剧场（玻璃卡聊天叠在画面上）——我们更多，别照抄删掉 |
| 打开链路请求数 | detail(+弹幕票) → discover → urls 串行，且明确不缓存播放地址（`live_core/live_site.dart:385`） | 同数量级；双 `getRoomPlayInfo` 是 API 固有（bilibili 只在 `accept_qn` 里列其它档， douyu 档表无 URL） |

## 待办队列（自上而下，一项一轮）

- [x] **T1 录制状态卡的完整数字**（P21，随 T5 一起做）。参考 `shared/record/record_status_card.dart:341-388`：`第 n 段 · 每 N 分钟一段`、36 px 时钟、chips `已录 356 MB` / `3.2 Mbps` / 画质 / `弹幕 1,284 条`。P9/P11 已把大小与合并百分比放上条上、并让非写入态有名；**条上到此为止是刻意的**——参考的条/角标也只放时钟与状态词，段数/码率/弹幕条数属于卡（面板）。故这些数字随 T5 的只读面板一起做，不要塞进玻璃 pill。
- [x] **T2 竖屏直播的三停靠点面板**（P22）。参考解剖见上；窄窗竖屏源已从"堆叠"改成"画面满幅 + 可拖底部面板（250 px 地板 / 44 % / 68 % 且留 120 px 画面，手柄行 48、grip 38×4、进竖屏全屏的按钮、右侧全屏 pill）"。样张给过 B/C/D 三档但任务被逐字重发（`feedback-carry-clarified-decision-into-code`），按最贴参考又覆盖"16:9"那句的 **D** 当轮落实：横屏源仍堆叠但信箱加 `min(width/ratio, height*0.6)` 上限。要退回 B 只需去掉那条上限；要 C 只需把面板换成只包聊天列。**沉浸式（剧场）没动**——参考没有这一档。
- [x] **T3 弹幕列表：过滤计数可见**（P17）。参考把被屏蔽条数只放屏蔽页「本场已屏蔽 N 条」（`blocked_count.dart:5`、`block_manager.dart:293`）。我们此前根本没有计数（包与 app 都只回 bool）⇒ 已补：引擎报 policy 判定、房间只数观众的四条规则、面板第一行显示；设置页不放第二个入口。
- [ ] **T4 live_core / live_danmaku 能力差**：另派代理解剖（结论未回收）→ 回到本表补队列，别在 app 里重做包能力（`feedback-use-package-facilities-not-app-hacks`）。
- [x] **T5 房间侧「录制」只读面板 + 跳「录制中心」**（P21）。**不做**其中的画质**选档** chips 与"开播自动录"开关：改画质是录像 lane 的待办（页签只读显示 `task.quality` 的标签，这不算选档），后者与订阅卡片右端开关重复（同项一个入口）。
- [ ] **T6 已判定不做**：到期前主动换地址——bilibili 自己的 lease 注释写着"expiry does not cut an established connection"（`parsers/bilibili_play_parser.dart:240`），主动重开会**制造**缺口；`requiresReconnect` 默认 false。礼物/SC 结构化 XML 需要改 `DanmakuEntry` + 全部 5 种渲染器，不在房间线里做。`forceDestroy` 默认 true 已实测只值 ~60 ms，不改默认。

- [x] **T7 撤回落实**（P13）。参考 `features/live_play/danmaku/chat_feed.dart:285` + `live_danmaku/filters/message_gate.dart:71`。我们：`bilibili_danmaku_codec.dart:299,334` 会发 `retraction`，`flame_barrage_sink.dart:95` 有 `retract()`，但 `room_controller.dart` 把非礼物类型统统当 `chat` 灌进管线、空文本又丢掉 ⇒ 房管删除的弹幕永远留在屏幕与列表。**做法**：分派 `retraction` 到聊天 feed 删除 + 飞行层 `retract`；`retractByUser/clear` 的引擎调用一并补。**已按此做完**：一条 `LiveRetraction.matches` 同时喂两个面（列表 `retract`、飞行层 `retractWhere`），`all` 只删说过的话、礼物与通知留下。参考 gate 把撤回目标并进去重键（`message_gate.dart:71`）这 ours 不需要——撤回在进 gate 之前就分派走了。
- [x] **T8 gate 缺 replay / SC / combo 键**（P14）。参考 `message_gate.dart:28-33,61-62,95-98`。我们 `danmaku_message_gate.dart` 无 `maxReplayAge`、不读 payload ⇒ **YouTube 回放与重连补发被 45 s 规则整段吞掉**（`youtube_danmaku_codec.dart:458` 已设 `replayed`，无人读）。**已做完**：`replayed` 与 `maxReplayAge` 进消息/配置/gate，付费卡按 `endTime` 免死。**combo 键刻意不搬**：我们的房间在 `RoomDanmakuPipeline.accept()` 就把礼物分流出管线（连击走 `GiftFlights`），gate 永远看不到礼物，搬进去是死代码；参考那边需要它是因为礼物同过 gate。
- [x] **T9 正则黑名单在直播间失效**（P15）。`media_core_danmaku/danmaku_filter_policy.dart` 过去只 substring；`live_sites/common/danmaku/filters/block_pattern.dart` 只有录制读 ⇒ 同一份名单两处行为不一致。**已统一到包侧**：格式的权威仍在 `live_sites`（它同时管着设置页添加时的耗时探测与指数回溯判据，两份实现会漂），引擎只收编译好的 `RegExp` 并保证代价（只看前 200 字）。app 不重实现，只做一次拆词。
- [x] **T10 「屏蔽纯表情」不吃内置表情表**（P16）。参考 `message_filter.dart:126` 有 shaper hook；我们 `danmaku_filter_settings.dart:250` 用默认 shaper（只认 `message.emotes`），而图集键就在 `shared/player/emoji_atlas_loader.dart:47`。⇒ 斗鱼/虎牙 `[笑哭][笑哭]` 屏蔽不掉。**已做**：包侧 `danmakuMessageShape(..., emoticonPattern:)`（规则在包里，表在 app），app 传 `EmojiAtlas.instance.regex`——和聊天绘制同一张表，屏幕说什么就按什么算。
- [x] **T11 lease 驱动的换链**（P18）。`live_sites` 有 `LivePlayLease`（refreshAt/expiresAt/requiresReconnect）+ 10 个 `*PlayLeaseLookup` capability，**app 内零读者**；播放器只在失败后重取。注意与 T6 的区别：**HLS/需要重连的线**才该提前换（`requiresReconnect`），FLV 建立中的连接不受到期影响。⇒ 已按这条界线做：只有声明 `requiresReconnect` 的线挂定时器。
- [x] **T12 错误分类太薄**（P19+P20）。参考 `live_core/site_error.dart:19,47-58,63-71` 有 `isTransient`/`retryAfter`/`cookieSuspect`；我们 `live_sites/core/live_site_error.dart` 此前三者皆无 ⇒ 429/风控时上层不知该等多久、该不该提示换 cookie。**已一次补齐三个判据并接了第一个消费者**（房间弹幕按判据自恢复）。剩余可继续做的：给更多站点当生产者（baidulive 已接），以及账号页用 `cookieSuspect` 区分"要登录"与"Cookie 被拒"。

### 我们在参考之前的地方（别回退）

消息类型与 typed 模型（`LiveGiftValue/LiveGiftCombo/SuperChatPrice/Display`）、房间模型分面、IPTV EPG/回看、相似度过滤的长度预筛、礼物原地合并 + 档位门槛、单张精灵图表情、斗鱼 LTP0 续期与钥匙串分层。

## 运行记录

- 2026-11-04：P1–P10 落地（本文件建立）。`dart analyze` 全仓 0 issues（另 lane 在 `recorder_page|library_pane`、`favorites|popular|areas`、App 壳上的临时红门不算）；media_core `recording_ffmpeg` 145/145、`media_kit` 25/25、`live_sites` 453/453。运行期未验证（盘上最新日志停在 11-03 且无进房记录）。
- 2026-11-04 晚些：P11、P12 落地；live_core / live_danmaku 能力差解剖完成 → T7–T12 入队（撤回、gate 的 replay/SC/combo 键、正则名单、纯表情 shaper、lease 换链、错误分类）。门：`dart analyze lib/modules/live/room` 0 issues；未做运行期验证。
- 2026-11-04 P13：撤回落实（T7 勾掉）。门：`dart analyze lib/modules/live/room test/live/room_retraction_test.dart` 0 issues；`flutter test test/live/room_retraction_test.dart` 4/4 绿。运行期未验证（撤回要有房管动手才看得见，日志里取不到）。
- 2026-11-04 P14：gate 的补发窗口（T8 勾掉）。门：media_core_danmaku `dart analyze lib test` 0 issues、`flutter test` 103/103 绿；app `dart analyze lib` 0 issues。运行期未验证（要看 YouTube/17LIVE 中途进房的回放，由用户自测）。踩到一次坑：在包根跑 `dart format lib test` 顺手重排了两个没碰的文件（`danmaku_similarity_filter.dart`、生成的 `danmaku_session_state.g.dart`），已 `git checkout --` 还原——**包侧只格式化本轮改动的路径**。
- 2026-11-04 P15：正则名单进房间（T9 勾掉）。门：media_core_danmaku `dart analyze lib test` 0 issues、`flutter test` 105/105 绿；app `dart analyze lib` 0 issues。app `flutter test test/live` 有 3 红，都不是本轮：`recorder_page_providers_test`/`room_retraction_test` 是**编译加载失败**（主题 lane 在改 `dynamic_color_provider.dart`↔`theme_persistence.dart`，签名不匹配，整棵 app 编译不过），`recording_schedule_test` 是录像 lane 自己的（10cf6c572 把开播节奏搬到每间房之后就没绿过）。运行期未验证。又踩一个坑：`dart run slang` **必须在 `apps/pure_live` 下跑**，仓库根也有一份 `slang.yaml`，在根跑会往 `lib/gen/strings*.g.dart` 写一套没用的产物（已删）。
- 2026-11-04 P16：表情表进形状判定（T10 勾掉）。门：live_sites `dart analyze lib test` 0 issues、`dart test` 458/458 绿（含新增 `danmaku_text_shape_test.dart` 5 例）；app `dart analyze lib` 0 issues；`flutter test test/live` 40 例只剩录像 lane 那一红（`needsLiveCheck => isArmed` 是 3a2b6d129 改的，测试没跟着改）。运行期未验证（要看斗鱼/虎牙房间的表情刷屏是否真被拦）。
- 2026-11-04 P17：本场屏蔽计数（T3 勾掉）。门：media_core_danmaku `dart analyze lib test` 0 issues、`flutter test` 107/107 绿；app `dart analyze lib` 0 issues、`flutter test test/live/room_shield_count_test.dart test/live/room_retraction_test.dart` 6/6 绿。运行期未验证（数字要真进房才会动）。本轮自己踩一条老规矩：**提交主题里不要夹中文**（第一版主题写了界面原话，推送前 `--amend` 改成英文转述；正文要用英文说界面词，别把中文串塞进 subject）。
- 本轮另外确认：**media_core 的 gate 只做到 `maxReplayAge` 为止**（参考也是），没有给"未声明但很旧"的包再加一套首次放行机制——那会把"后台攒了一批没发的 socket 不许当直播倒"的保护拆掉。`git status` 在包根看的是整个引擎仓，别看错成"我的改动没了"。
- 2026-11-04 P18：lease 提前换链（T11 勾掉）。门：app `dart analyze lib` 0 issues；`flutter test test/live` 42 例绿，只剩录像 lane 那一红（`recording_schedule_test`，别人的）。运行期未验证——要真房间跑到地址到期才看得见，交用户自测。T2 已按规矩出样张（A0 现状 / B 参考同款三停靠点 / C 只给聊天加停靠 / D 照参考+横屏源 16:9 信箱），等用户点方向，没点就不动布局形态。

- 2026-11-04 P19+P20：错误分类与房间自恢复（T12 勾提，队列剩 T1/T5、T2 等用户点方向）。门：live_sites `dart analyze lib test` 0 issues、`dart test` 463/463 绿；app `dart analyze lib` 0 issues、`flutter test test/live` 42 例绿、仍只剩录像 lane 的 recording_schedule_test 一红。踩坑：sealed 联合的 **转发式 const factory 不能给新参数写默认值**（报 default_value_in_redirecting_factory_constructor），所以 `cookieSuspect` 用可空参数 + 私有字段 + 覆盖 getter，对外仍是非空 bool。运行期未验证：要真断网/限流才看得见重连。

- 2026-11-04 P21：房间录制页签（T1+T5 勾掉，队列只剩 T2 等点方向）。门：app `dart analyze lib` 0 issues、`flutter test test/live` 42 例绿（仍只录像 lane 那一红）。运行期未验证——页签要真录起来才有数字，交用户自测。踩坑again：`dart format lib/modules/live/room/chat` 顺手重排了 gift_text/gift_flights（已 `git checkout --` 还原），**只格式化本轮真改的文件这条我又破了一次**。
- 2026-11-04 P22：竖屏三停靠点面板（T2 勾掉，队列已空）。方向没等到点名，按最贴参考的 D 当轮落实（样张在上一轮给过：B 纯参考 / C 只拖聊天 / D 参考+横屏信箱上限）。退回 B 只需去掉信箱上限，退回 C 只需把面板内容换成聊天列本身。
- 本轮事故：用 python `s.index(锚点)` 删私有类 `_RoomChatGlass` 时，锚点文本在文件更早处也出现一次，`end < start` 于是把中间整段代码切掉并复制了一份，room_page.dart 直接语法崩。恢复办法是 `git checkout -- 单文件`（本轮该文件的改动全在我自己路径内、且已推送过基线），然后逐条用唯一全文的 Edit 重做。教训回到老规矩：**删整段用 Edit 带唯一 old_string，绝不用字符串索引做区间删除**。
- 2026-11-04 P22 补：`test/live/room_bottom_panel_test.dart` 6 例（44 %→352、地板 250、顶档 544、300 px 矮窗地板压过两条比例规则且不抛、上抛落 544、小拖回 352）。门：`dart analyze test/live/room_bottom_panel_test.dart lib` 0 issues、`flutter test test/live/room_bottom_panel_test.dart` 6/6 绿。竖屏面板的几何与手势就此有门可把，只剩真机手感/键盘/旋转由用户自测。

- 2026-11-04 P23+P24：参考第二次全量审计的前两项落地（掩码名不再提供屏蔽动作、复制带名字；T14 页签计数）。门：app `dart analyze lib` 0 issues、`flutter test test/live` 48 例绿（仍只录像 lane 一红）；live_sites 463/463。运行期未验证：页签计数要真房间切来切去才看得见。新队列剩 T13（关注进不了全屏）、T15（锁定全屏）、T16（睡眠定时进菜单）、T17（新窗口）、T18（常驻登录提示条）、T19（钟与电量）。

- 2026-11-04 P25+P26：T13、T16 勾提（关注与定时关闭进房间菜单，后者顺手把十个时长收成一份）。门：app `dart analyze lib` 0 issues、`flutter test test/live` 48 例绿（仍只剩录像 lane 那一红）。运行期未验证。剩下 T15（锁定全屏）、T17（新窗口）、T18（常驻登录提示条）、T19（钟与电量）。

- 2026-11-04 P27：T18 勾提（常驻登录提示条）。门：app `dart analyze lib` 0 issues、`dart format` 只点这两个文件（0 changed）、`flutter test test/live` 48 例中 47 绿——唯一红仍是录像 lane 的 `recording_schedule_test.dart`「只有开播检查能推动等待/排期中的任务」（`needsLiveCheck => isArmed`，`3a2b6d129` 引入，不是本轮改的）。运行期未验证：条要真用坏 cookie 连 bilibili/twitch 才看得到，交用户自测。顺手把"已持平"表里那条过期行（窄窗仍是 58 % 舞台）按 P22 的现状改了。剩下 T15（锁定全屏）、T17（新窗口，窗口层还没有"按路由开一扇"的能力，别挂打不开的门）、T19（钟与电量，价值最低）。
