# 直播间对照参考（E:\study\Pure_live）优化台账

> 本文件是「参考 E:\study\Pure_live 优化直播间」这条任务线的唯一进度依据。
> 每轮先读本文件，挑队列最上面一项做完就勾选并补「运行记录」，**已核对为持平的条目不要重做**。
> 参考是 v5 旧架构（`apps/pure_live/lib/features/live_play` + `packages/live_*`），只读，不改。

## 当前状态（2026-11-05 收尾，先读这九行再挑活）

1. **第 1 部分（桌面控件/弹幕列表/录制显示）**：与参考逐控件比过三轮并已持平或更强；`T13–T23`、`P27–P39` 是成果清单。**再动就是凭喜好重排**——参考底条动词与我们的"条 + ⋮ 菜单"分工按参考自己的 `menuEntriesOnBars` 规则等价（它把条上有的从菜单里删掉，我们把同类动词收进菜单，都是一个入口）。
2. **第 2 部分（打开速度）**：网络三段已实测（bilibili 351 ms、douyu 471 ms；见「进房分段实测」）⇒ 剩下的只在**引擎侧**（create→open→首帧）。分段计时与详情面板已入库，但**缺一次真运行的 `room-open` 行**；没有它任何"再快一点"的改动都是猜。T24/T25 已判定**不是**速度原因，别当提速项重开。**例外：第十八轮的 P58 不是靠猜的**——它量的是盘上已有的 `attaching engine … {line: N}` 行（恢复每次从 line 0 开始，观众选的线路被丢掉），修的是恢复路径的线路身份，与首帧耗时无关，见「第十八轮」。
3. **第 3 部分（竖屏/16:9/沉浸）**：窄窗三停靠点面板（P22）、竖屏进入提示（P30）、顶部两条控制行不再叠（P31）、锁定全屏（P28）都落了；**剧场模式参考没有**，不许照抄删。
4. **第 4 部分（live_core / live_danmaku）**：22 个能力接口逐个查过读者；9 个过滤器族做过**逐文件 diff**；撤回/回放/正则/表情/错误分类/lease 全部对齐或以更强形态存在（`project` 侧 `LiveHotProvider` 是零实现冗余接口，删除是包侧决定）。**弹幕 socket 运行时（心跳/静默看门狗/握手超时/有界重连与计数复位）已按 22 站逐条普查为持平**，唯一缺口 `shutdownTimeout` 已补（P45）——别再拿 `HeartbeatConfig(` 的计数当结论，见「弹幕 socket 运行时普查」。参考 `hls_master.dart` 的选档对 Steam 是真洞，见「第六次对照」。**测试这一维是第十九轮才补上的**：我们 `live_sites` 的弹幕解码器**此前零直接测试**（`danmaku/*.dart` 里有 `static …decode(` 的文件共 20 个；参考侧有 20 个站点测试文件），bilibili（P59，25 条）、douyu（P60，20 条）与 yy（P62，25 条）已钉住，其余站点按「第十九轮/第二十轮」给的顺序欠着——那不是"持平"，是"没人验过"。
5. **欠账已清（2026-11-05 第十三轮）**：`displayLabel` 的显示位全部落地——房间的两处随别的 lane 的提交进了 HEAD（`player_surface.dart:430,1246`），多视图两处是 `2208ce785`（`:1099,:1105`）。别再当待办；新加画质显示位时直接用 `displayLabel`，身份仍用 `label`/`qualityId`。
6. **决定只剩一个**：①**Bigo 已定案并落地**（用户拒绝回环中继 ⇒ `01075c532` 让 `getLines` 带可读原因失败，见「第十二轮」；不要再提做中继）。②Steam 的档位（P44 之后至少不再假装重开有效）要真生效，得决定改写后的 master 怎么交给引擎：**1** 环回中继只应答那一份文本，**2** 写临时文件以 `file://` 交出（证据与取舍见「第六次对照」）。**没点名之前不做**。
7. 规矩本身也长了一条：**`git commit -- <文件>` 只挡别人的文件，挡不住同一文件里别人的 hunk**（`746fec7d7` 事故）；提交前逐 hunk 读 `git diff`。
8. **四道护栏在 HEAD 上的现状（第十七轮实测）**：`check_architecture.ps1`、`check_responsive.ps1`、`check_settings_ia.ps1` 全绿；`check_prefs_manifest.ps1` 剩 **7 条**，逐条归属与证据见「第十七轮」——**2 条是判据本身看不见 helper（录像），5 条是点播登录态该进"故意不备份"名单而不是 `kBackedUpPrefs`（名单在 `tool/`，本轮不动）**，都不是直播间这条线的活，别再重新解剖。
9. **更新内容这条线（第二十一轮，用户新加：先拉参考、再按更新优化）**：`git pull --ff-only` 只带进 `assets/releases.json` 与 `assets/version.json`（`8743e5a6e..f00bebd91`），**克隆里的源码仍是 5.6.2** ⇒ 5.6.3/5.6.4 那十几条是需求清单，不是可抄的代码；逐条对照、「缺但被什么挡住」的证据和四项开工顺序都在「第二十一轮」；本轮已落里面唯一不需要新协议证据的那一半（**P61**：SOOP 的 assign/key 带上了 20 s 等待上限）。

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
- [x] **T15 无锁定全屏**（P28 做完）。参考 `bar_parts.dart:314-339` 的 LockButton 挂在右侧中（`player_view.dart:929-937`）：锁上后隐藏条、吞掉手势/滚轮（`:276`）。我们滚轮调音量与双击播放暂停在满屏时一直生效（`player_surface.dart:800-824`）⇒ 看电视时误触就改音量。
- [x] **T16 睡眠定时进不了全屏**（P26 做完）。`_SleepChip` 只在页头（`room_page.dart:1896`），`roomMenuItems` 没有它（参考在房间菜单里带剩余分钟第二行：`room_menu_button.dart:152,254-259`）。做法：菜单里加一组时长项，复用 `kAsmrSleepMinuteChoices` 与 `asmrSleepDurationLabel`，别再开一套选择器。
- [x] **T17 桌面"在新窗口打开这间房"缺失**（P32 做完）。参考 `room_menu_button.dart:166,357-359` 走 `DesktopWindow.openNewWindow`；我们有房间窗口（`room_opener.dart:46`）但房间菜单没有这一行。**上一轮把它判成"窗口层没有按路由开一扇的能力"是错的**：`openRoom` 就在做这件事（`room_opener.dart:61` `windows.open(role: panel, route:, businessKey:)`，命中已有窗口就 `DesktopNavigate` + raise），门本来就是活的，缺的只是房间菜单那一行。门条件照参考的 `offersNewWindow` 收窄：桌面 + `roomWindowsProvider` 开 + `secondaryWindowsProvider != null` + 当前页不是房间窗口自己（`roomLeaveProvider == null`，在窗口里再开同一扇只是 raise 自己）。
- [x] **T18 被掩码名之外的一条：登录提示是常驻条**（P27 做完）。参考在列表上方常驻 `ChatNameHintBar` 并带登录按钮（`chat_list.dart:421-433,603-649`）；我们一次 toast 过完就没了（`controller/room_controller.dart:1646`）⇒ 错过了就只能等下一次连接。
- [x] **T19 满屏钟与电量**（P29 做完）。参考底条每分钟重画时钟/电量（`bar_parts.dart:22-144`）。桌面价值低（系统托盘已有），手机价值高：留到最后。
- [x] **T21 满屏没有弹幕开关，也进不去弹幕设置**（P31 做完）。参考在横屏底条放 `live-play-danmaku-toggle` + `live-play-danmaku-settings`（`player_controls.dart:681-699`）。我们的开关只在**非** identity 那条 strip（`player_surface.dart:1455`）⇒ 全屏后弹幕开关不见了；样式与区域在聊天列第 4 页签，而全屏没有聊天列 ⇒ 满屏进不去。做法：把开关抽成 `_DanmakuTogglePill`（一处实现两处用，读同一个 `playbackSettingsProvider.danmakuVisible`），identity 那条也画；房间菜单加一行 `t.settings.navDanmaku`，push 与聊天列那行同一个 `SettingsSectionRoute(danmaku)`（同一个门、同一套词，不再开第二个设置面）。
- [x] **T22 满屏 tap 被飞行弹幕吃掉**（P31 做完，参考 D-038）。`_onPictureTap` 原来只管"命中就开面板"⇒ 条已隐藏时那一跳本该叫回控制条，却开了某条弹幕的行动作；竖屏全屏里控制条就是出口，手机于是可能出不去。参考的规则：`shownBefore && !paused` 才把命中的消息当消息（`player_view.dart:364-410`）。现已照做，并顺手拆掉竖屏全屏自己飘在右上那两枚按钮——它们与 strip 的返回键/开关/集群/⋮ 画在同一条带上（会重叠），而返回键本来就先退竖屏全屏（`leave()` 的第一支）。`room.portraitFullscreenExit` 改给 strip 的返回键按形态用（竖屏时念"退出竖屏全屏"），于是一个动词一个入口。
- [x] **T20 竖屏滑动换直播间是个打不开的功能**（P30 做完）。第三次对照发现的不是"参考有我们缺"，而是我们自己有读没人喂：`portraitSwipeSwitchProvider` 只有 room_page 在读（`room_page.dart:889`），全仓没有任何设置行调它的 `set()`，默认 false ⇒ 这条手势对所有人都不存在。补法：开关接进"画面"页那组 room-only 行（与布局模式/自动全屏同段）并登记进设置搜索目录；再按参考的 `PortraitEntryHint`（`bar_parts.dart:340-395`）在进入竖屏全屏时把这条看不见的手势说一次（3 s 后淡掉，reduce-motion 直接消失），且只在开关为真时画——教一条已被关掉的手势比不教更糟。
- [ ] **已判定不平**：参考的本地"+1/存为常用语"回放体系（`message_panel.dart:219-341`）——我们的发送框真发（`room_chat.dart:360+`），这是两套子系统的边界，不是缺功能；参考的投屏只有 Android（`player_controls.dart:177`），我们桌面也有（此项我们更强）；参考的横屏底条对 iptv 源挂"节目单"入口（`player_controls.dart:405-415` `showIptvGuide`），而我们的直播间从不装 iptv 频道（`modules/live/**` 内没有 `SiteIds.iptv`；iptv 走 `modules/iptv/pages/iptv_play_page.dart` 与 `iptv_guide_page.dart`）⇒ 模块边界，不是缺入口。

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
| P28 | `30ab1e8e0` | 锁定全屏 | T15：满屏右侧中一枚锁（`PlayerGlassPill` + `PlayerBarButton`，50×50，图标 `lock`/`unlock`，新串 `room.lockControls`/`room.unlockControls`）。锁上后：条与唤醒条与码率面板都不画、滚轮调音量/上下半拖动/单击/双击暂停/点弹幕全部吞掉、录制标只留数字（`onStop` 交 null，控件不能长得一样却按下去没反应）；解锁键在锁上后常驻（房间掉线/失败也还在，否则满屏没有门可开）；`didUpdateWidget` 在退出全屏时释放锁（参考同规则，否则锁键会飘在页面自己的画面上而手势还关着）。`immersive`＝`ownsWindow \|\| 竖屏全屏`，与参考 `arrangement != inline` 同一档。**门里没有的一条**：本 app 没有任何测试泵过 `PlayerSurface`（它要播放器 handle 与整张房间 provider 图），所以锁的判据只过编译与既有测试，行为待真机。 |
| P29 | `ec577f210` | 钟与电量 | T19：满屏顶条在返回键右侧加一枚玻璃条（钟 + 电量图标 + 百分数）。钟按「分钟翻牌」定时重画（不是 60 s 周期：21:04:30 开的会在 21:05:00 还写 21:04 半分钟），电量读一次然后每分钟一次；`PlatformBatteryService.readLevel()` 回 -1 就是"这台机器没有电池"，那种机器不画任何数字（画 0 会被读成快没电的笔记本）。门：只给 `immersive`（`_PlayerTopBar.fullscreen`），页面内不画——页头那条系统标题栏本来就有时间。图标按档取 `batteryEmpty/Low/Medium/High`，数字用 `typography.numeric`。 |
| P30 | `2bbdf6c26` | 竖屏手势 | T20：`portraitSwipeSwitchProvider` 之前只有读者没有写者（全仓没有一行设置调它的 `set()`，默认 false）⇒ "上下滑画面中段换直播间"这条手势对所有人都等于不存在。开关进"画面"页 room-only 段（`playback_panes.dart`，紧跟自动全屏），同步进设置搜索目录；进入竖屏全屏时按参考 `PortraitEntryHint` 给一条 3 s 后淡掉的玻璃提示（`_PortraitSwipeHint`，reduce-motion 用 `Duration.zero`），并且只在 `swipeSwitch && mobile` 为真时画——提示不能教一条被关掉的手势。`_buildPortraitFullscreen` 因此多了 `canSwipeRooms`，与 `onPortraitSwipe` 用同一个判据，两处不会各说一遍。 |
| P31 | `454afe83d` | 满屏动词 | T21+T22：①弹幕开关抽成 `_DanmakuTogglePill`（一处两处用），identity（全屏）那条 strip 也画——之前它只在非 identity 分支，全屏就没了；②房间菜单加"弹幕"一行，push 与聊天列页签里那行同一个 `SettingsSectionRoute(danmaku)`（同一个门、同一套词），全屏没有聊天列时才有地方改样式；③`_onPictureTap` 落参考 D-038：条不在时那一跳一律叫回条（`shownBefore`），只有条已显示且在播才把命中的消息当消息，冻结过的那条 `resumeAllPaused()`；④竖屏全屏自己飘在右上的两枚按钮拆掉——它们与 strip 的返回/开关/集群/⋮ 画在同一条带上会重叠，返回键本来第一支就是退竖屏全屏，切换直播间在 ⋮ 里；`room.portraitFullscreenExit` 改给 strip 的返回键按 `portraitExit` 用，动词还是只有一个入口。门：`dart analyze lib` 0 issues、`flutter test test/live` 48 例中 47 绿（唯一红仍是录像 lane 那条）。运行期未验证：满屏点一下应先叫回条、竖屏全屏顶部不再叠两层。 |
| P32 | `866489388` | 新窗口 | T17：房间菜单加"在新窗口打开"（`DsIcons.appWindow` + `t.room.openInNewWindow`，与画中画同一族动词）。**同时纠正上一轮自己的判断**：台账里写的"窗口层还没有按路由开一扇的能力"是没读 `openRoom` 就下的结论——`room_opener.dart:61` 早就 `windows.open(role: WindowRole.panel, route:, businessKey:)`，命中同 businessKey 的窗口就发消息导航 + raise。教训：**判"做不了"之前先把现成入口的源码读完**，别把已有能力记成缺口。条件照参考 `offersNewWindow` 收窄（桌面 + 房间窗口开关 + 有 secondaryWindows + 本页不是房间窗口）。带 `playlist: roomPlaylistProvider?.rooms`，新窗口进去后竖屏滑动能沿同一份列表走。运行期未验证：多窗口是同 lane 别人正在改的层，真机上验一次再说。 |
| P33 | `224550c67` | 直链 | T23（第四次对照）：正在播的房间菜单加「获取直链」，开的是已有 `toolbox/direct_link_dialog.dart`（房卡菜单与工具箱早就用它的同一个弹窗，逐档列线、每条 URL 自带复制）。行只在该站声明了 `LivePlaybackProvider` 能力时出现——否则这行点下去只会说"这个房间暂时没有可用的直链"，是打不开的门。 |
| P36 | `36b1bd70c` | Cookie 被拒 | 第四次对照留下的"有写没读"第二条：`LiveCookieRefusalFeed.cookieRefusals`（twitch 实现，包侧两条测试在讲语义：播放令牌带 cookie 被拒→丢 cookie 匿名重取、同一 cookie 只报一次）app 从来不订，反而拿 `TwitchDanmakuCodec.cookieExpiredNotice().text` 逐字比**聊天**通知的文本 ⇒ 播放侧被拒时观众一个字也看不见，且通知文案一改提示就静默消失。改成订能力流（`open()` 订、`_teardown` 取消），文案换成不点平台名的 `room.cookieRefused`（提示条本身带"去这一站重填 Cookie"的按钮，站点身份已经在条上）；删 `_twitchCookieRefusalText`/`_onTwitchNotice`/`_twitchRefusalShown` 与 `room.twitchCookieExpired`。门：app `dart analyze lib` 0 issues、`flutter test test/live` 53 例中 52 绿（唯一红仍是录像 lane）、live_sites `twitch_test.dart` 2 绿。**别人 lane 的痕迹**：slang 是全树生成，本轮生成物里带进两条尚未提交的 `settings.*` 串；别人的 messages JSON 没被我提交。 |
| P37 | `b0d097b97` + `746fec7d7` | 画质诚实 | **能力读者普查**（本轮方法，可复用）：把 `packages/live_sites/lib/src/capabilities/` 的 22 个接口逐个 grep app 侧消费数，零读者的有 `LiveAnchorProvider`/`LivePlayLeaseLookup`/`LivePlayRecovery`/`LivePlaybackPlanResolver`/`LiveStatusCheck`/`LiveWebSearchProvider`。逐个核完：`LivePlayLeaseLookup` 已经由 `line.lease` 读到（T11/P18，接口只是声明处）；`LivePlayRecovery` 各实现者的 `refetchLines` 本身就等于 `playback.getLines`（douyu/douyin/huya 源码里就写着 "the recovery read is the playback read"），而我们恢复缝 `onRecoverySources`/`lineResolver` 一直重取 getLines ⇒ **语义已满足，别再当缺口"接"**。**真缺口 = `LivePlaybackPlanResolver`**：5 站能回答实际档位（bilibili `current_qn`、cc `vbrname_sel`、douyin 真实 variant、yy/twitch 答复），而 `LivePlaybackPlan.appliedQuality`/`qualityUnconfirmed` 全仓无人读 ⇒ 匿名请求被悄悄降档时条上写的是"我要的"（1080P 名义播 720P）。包侧加 `isSamePlayTier` + `resolveServedPlayQuality`（参考 C01.4：在册用册里那条、不在册顶替所问那条、平台不说就不猜）；app 侧 `_resolveLines` 优先取 plan、**读不到就退回原 getLines**（确认机制不能变成拿不到流的代价），`_showServedQuality` 就地换掉 qualities 那一格并同步 `_wantedQuality`/`state.quality`。**行为副作用**：`_startPlayback` 从回调里 fire-and-forget 改成整条 await（切画质会等引擎接过源）。**故意没接**：`plan.start`（我们没有轮播）、`LivePlayQuality.isPlaybackUnconfirmed`（要写"可能已降档"得先定文案与呈现，别造没读者的标记）。门：live_sites `dart analyze lib` 0 issues + `dart test` **468 绿**（含新 `live_playback_plan_test.dart` 5 例）、app `dart analyze lib` 0 issues、`flutter test test/live` 53 例中 52 绿（唯一红仍是录像 lane）。运行期未验证：无登录态开 bilibili 最高档，条上应写实际档。 |
| P38 | `34578f23c` | 未确认档位的记号 | P37 里我故意没接的那条，本轮补齐包侧：`isPlaybackUnconfirmed` 是模型早就写着的"服务器可能悄悄降档"，全仓没人显示 ⇒ 名字在替平台打保票。照参考加 `LivePlayQuality.displayLabel`（参考三处都是**名字后面挂一个 `?`**：`stream_menu.dart:52,73`、`multiview/widgets/cell_controls.dart:15`，没有句子也没有 tooltip），标识/匹配/入库仍用 `label`+`qualityId`，记号不进身份。已改的显示位：直链弹窗的画质下拉（`toolbox/direct_link_dialog.dart:110`）。**还差两处（工作区里已改好但没提交，因为文件上有别人未入库的 hunk，见下面的事故）**：`player_surface.dart:430`（画质面板条目）与 `:1246`（条上的画质按钮）—— getter 已先进 HEAD，别人那笔提交把它们带走也不会编译不过；下轮确认这两行已在 HEAD 即可划掉。multiview 的两处（`multiview_page.dart:1099,1104`）同理待他那笔落定。门：live_sites `dart analyze lib`+`dart test test/models` 15 绿（新 `live_play_quality_test.dart` 2 例）、app `dart analyze lib` 0 issues、`flutter test test/live` 53 例中 52 绿（唯一红仍是录像 lane）。 |

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

## 第四次对照（2026-11-05：参考 live_core/live_danmaku 与我们引擎、以及条上动词的最后一族）

| 查的东西 | 参考 | 我们 | 结论 |
| --- | --- | --- | --- |
| 弹幕过滤器族 | `live_danmaku/lib/src/filters/`（block_list/block_pattern/message_filter/message_gate/notice_throttle/partial_ratio/repeated_filter/similarity_filter/text_shape） | `live_sites/lib/src/common/danmaku/filters/` 同名九件 | **齐**，别再造第十件 |
| 表情库 | `apps/.../shared/danmaku/emotes.dart` `EmoteLibrary` + `assets/emo/json` + 每平台图片文件 | `shared/player/emoji_atlas_loader.dart`：`live_sites` 用 `tool/pack_emoji_atlas.py` 打成**一张图集 + manifest**，飞层与列表共用 | **同一能力、不同形态**（我们更省：一次解码全目录）。列表已用 `_wordSpans` 画图集表情（`room_chat.dart:1165`），别照抄参考的逐平台 JSON/图片 |
| 大小写敏感握手 | `live_danmaku/lib/src/exact_websocket.dart`（YY/SOOP 边缘节点） | `packages/live_websocket/lib/src/client/exact_web_socket*.dart` | **齐** |
| 底条中间那个发送框 | `LocalDanmakuComposer.onVideo`（属于 `local_interaction/`：+1/常用语本地回放体系） | 我们的真发送在聊天列 `_ChatComposer` | 已判定不平（见上"已判定不平"）。参考全屏也只发本地条，不是我们缺入口 |
| HLS 主列表选流/查询串策略 | `live_core/lib/src/hls_master.dart`、`hls_source_query_policy.dart`（后者明确"只对验证过的 TTing/FLEX NCP 契约开启"） | 我们把 master URL 交给 mpv/ffmpeg 自己 ABR | 不动：参考自己也说这不是全局规则；要为某站补需要该站的实测证据 |
| 房间菜单族 `streamLink` | `room_menu_button.dart:268,351-352` → `showStreamPanel(..., copy)` | 有 `toolbox/direct_link_dialog.dart`（房间卡片菜单、工具箱都能开），**但正在播的房间自己没这一行** | **T23 补上**（P33） |

## 待办队列（自上而下，一项一轮）

- [x] **T1 录制状态卡的完整数字**（P21，随 T5 一起做）。参考 `shared/record/record_status_card.dart:341-388`：`第 n 段 · 每 N 分钟一段`、36 px 时钟、chips `已录 356 MB` / `3.2 Mbps` / 画质 / `弹幕 1,284 条`。P9/P11 已把大小与合并百分比放上条上、并让非写入态有名；**条上到此为止是刻意的**——参考的条/角标也只放时钟与状态词，段数/码率/弹幕条数属于卡（面板）。故这些数字随 T5 的只读面板一起做，不要塞进玻璃 pill。
- [x] **T2 竖屏直播的三停靠点面板**（P22）。参考解剖见上；窄窗竖屏源已从"堆叠"改成"画面满幅 + 可拖底部面板（250 px 地板 / 44 % / 68 % 且留 120 px 画面，手柄行 48、grip 38×4、进竖屏全屏的按钮、右侧全屏 pill）"。样张给过 B/C/D 三档但任务被逐字重发（`feedback-carry-clarified-decision-into-code`），按最贴参考又覆盖"16:9"那句的 **D** 当轮落实：横屏源仍堆叠但信箱加 `min(width/ratio, height*0.6)` 上限。要退回 B 只需去掉那条上限；要 C 只需把面板换成只包聊天列。**沉浸式（剧场）没动**——参考没有这一档。
- [x] **T3 弹幕列表：过滤计数可见**（P17）。参考把被屏蔽条数只放屏蔽页「本场已屏蔽 N 条」（`blocked_count.dart:5`、`block_manager.dart:293`）。我们此前根本没有计数（包与 app 都只回 bool）⇒ 已补：引擎报 policy 判定、房间只数观众的四条规则、面板第一行显示；设置页不放第二个入口。
- [x] **T4 live_core / live_danmaku 能力差**（第四次对照做完，见上表 + P33）。九件过滤器、大小写敏感握手、表情库、错误分类、撤回、gate 键、lease 都已对齐或以更强形态存在；这一轮查出来的唯一真缺口是"正在播的房间自己拿不到直链"（工具箱和房卡能拿），已补。HLS 主列表选流与查询串策略**不搬**（参考自己写明只对验证过的 TTing/FLEX NCP 契约开启）。
- [x] **T6 已判定不做**：到期前主动换地址——bilibili 自己的 lease 注释写着"expiry does not cut an established connection"（`parsers/bilibili_play_parser.dart:240`），主动重开会**制造**缺口；`requiresReconnect` 默认 false。礼物/SC 结构化 XML 需要改 `DanmakuEntry` + 全部 5 种渲染器，不在房间线里做。`forceDestroy` 默认 true 已实测只值 ~60 ms，不改默认。
- [x] **T5 房间侧「录制」只读面板 + 跳「录制中心」**（P21）。**不做**其中的画质**选档** chips 与"开播自动录"开关：改画质是录像 lane 的待办（页签只读显示 `task.quality` 的标签，这不算选档），后者与订阅卡片右端开关重复（同项一个入口）。

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

- 2026-11-04 P28：T15 勾提（锁定全屏）。门：app `dart analyze lib` 0 issues、`dart format` 只点 player_surface.dart（0 changed）、`flutter test test/live` 48 例中 47 绿（唯一红仍是录像 lane 的 `recording_schedule_test.dart`，不是本轮改的）。运行期未验证：锁只在真全屏里看得出——误触滚轮不该改音量、锁上后录制标不该能停。新串两枚（`room.lockControls`/`room.unlockControls`）经 `dart run slang`（在 apps/pure_live 跑）生成；生成文件里 4 处 `settings.*`/`vod.*` 行只是换了 switch 分桶位置（字节相同），是生成器自己的产物，不是别人 lane 的内容改动。剩下 T17（新窗口，窗口层还没有"按路由开一扇"的能力，别挂打不开的门）、T19（钟与电量，价值最低）。

- 2026-11-04 P29：T19 勾提（满屏钟与电量）。门：app `dart analyze lib` 0 issues、`flutter test test/live` 48 例中 47 绿（唯一红仍是录像 lane 的 `recording_schedule_test.dart`，不是本轮改的）、`dart format` 只点 player_surface.dart。运行期未验证：桌面机 readLevel 应回 -1（于是只画钟），手机要真机才看得出百分数与每分钟一跳。新队列只剩 T17（"在新窗口打开这间房"）——窗口层现在只有 `secondaryWindowsProvider.open(role: WindowRole.panel)`，没有按路由开一扇的能力，先把能力做出来再挂门，别挂打不开的门。本轮另外落地的还有 P28（T15 锁定全屏）与 P27（T18 常驻登录提示条），三条都只过静态门，真机观感交用户。

- 2026-11-04 P30：第三次对照（参考 `player_controls.dart` 底条动词清单 → 我们的条/菜单；`bar_parts.dart` 竖屏提示 → 我们的竖屏全屏）。新发现一条真缺口并已补（T20：竖屏滑动换直播间有读无写 + 无可教手势的提示），另外把参考给 iptv 源挂"节目单"那条判成模块边界（我们的直播间不装 iptv 频道，iptv 有自己的播放页与节目单页）。门：app `dart analyze lib` 0 issues、`flutter test test/features` 12 绿、`flutter test test/live` 48 例中 47 绿（唯一红仍是录像 lane 的 `recording_schedule_test.dart`）、`dart format` 只点本轮三个 dart 文件。运行期未验证：提示要真在手机上开开关才看得见（默认关）。队列剩 T17（新窗口——先给窗口层加"按路由开一扇"的能力，别挂打不开的门）。

- 2026-11-04 P31：第三次对照的第二批（T21 满屏弹幕开关/设置门、T22 参考 D-038 的 tap 规则 + 竖屏全屏顶部两层叠在一起）。门：app `dart analyze lib` 0 issues、`flutter test test/live` 48 例中 47 绿（唯一红仍是录像 lane 的 `recording_schedule_test.dart`）、`dart format` 只点本轮两个 dart 文件（0 changed）。运行期未验证：满屏点一下应先叫回控制条而不是开某条弹幕的面板；竖屏全屏顶部只有一条 strip。台账自己出过一次事故：用行首做 old_string 去插新行，把 T20 那行的前半截吃掉了（现已拆回，T20 行完整）——**插行要拿整行的唯一尾串做锚，别用别行的开头**。队列仍剩 T17（新窗口，先给窗口层"按路由开一扇"的能力）。

- 2026-11-05 P32：T17 勾提（房间菜单开自己的窗口）。门：app `dart analyze lib` 0 issues、`flutter test test/live` 48 例中 47 绿（唯一红仍是录像 lane 的 `recording_schedule_test.dart`）、`dart format` 只点 room_page.dart（0 changed）。这一轮把自己上一条误判写进台账了：T17 曾被记成"要先给窗口层加按路由开一扇的能力"，实际 `openRoom` 早就这么开，缺的只是房间菜单那一行——以后判"能力不存在"必须先读完那条现成路径再落字。第三次审计的队列（T13–T22）至此全部勾完。

- 2026-11-05 P33 + 第四次对照：把参考 `live_core`/`live_danmaku` 逐文件过了一遍（过滤器九件、exact_websocket、表情库形态、HLS 两件、错误分类），结论都写进上表——我们要么齐要么更强（表情是单张精灵图集，不是每平台 JSON+散图）。唯一真缺口是房间自己拿不到直链，已补（T23/P33）。门：app `dart analyze lib` 0 issues、`flutter test test/live` 48 例中 47 绿（唯一红仍是录像 lane 的 `recording_schedule_test.dart`）、`dart format` 只点 room_page.dart（0 changed）。运行期未验证：直链弹窗要真站点才看得见线列表；新窗口那行要桌面多窗口真机验。**本轮又自己犯了同一种编辑事故两次**：拿"别行的开头"当 old_string 去插行（把 T20 前半截吃掉）、以及替换时漏掉一条守卫行与造出一行重复 T5——都已当场修回。规矩：**插行用整行唯一尾串；改完立刻 grep 计数复核，别只看工具说成功**。

## 进房耗时（第五次，2026-11-05：先量，再谈快）

- 2026-11-05 P34（`c3bc627b3`）：把参考 `live_player/lib/src/timing.dart` 的 `StartupMarks`/`PlaybackTiming` 抄成我们自己的 `RoomOpenTiming`（`modules/live/room/controller/room_open_timing.dart`）。一条 `room-open site=… room=… result=… detail=… qualities=… lines=… request=… firstFrame=… playing=… chat=… total=…`（毫秒，缺的段落打 `-`），写在 `appLog.forCategory('room')`。**为什么先做这个**：这轮翻遍盘上日志，最新的 `pure_live.log` 是 10-28 的（`apps/pure_live/build/windows/x64/runner/Debug/pure_live_debug/data/logs/`），11-03 之后没有新日志 ⇒ 没有任何当期数字能证明"慢在哪一段"。"打开慢"是一个症状压着四个不同病灶（详情/画质/线路/引擎到首帧），每个的修法不同（超时、缓存、换线、探针预算），没有数字就又是猜。**规矩**：下次用户报"慢"，先 grep `room-open`，按段的毫秒数定病灶，别再回炉 P1/P2 已修过的两条真因（`project-pure-live-room-open-latency`）。
- 门：app `dart analyze lib` 0 issues、`flutter test test/live` 53 例中 52 绿（新增 5 例 `room_open_timing_test.dart`；唯一红仍是录像 lane 的 `recording_schedule_test.dart`）、`dart format` 只点本轮三个文件。
- **下一轮的两条候补（都要先有 `room-open` 数字才动）**：
  - T24 抢占的在途请求不取消：参考把 `CancelToken` 塞进发现过程（`live_core/live_site.dart:575` `LiveQualityDiscoveryScope`），我们靠 epoch 把迟到答案丢掉但请求仍在跑——快速连续换房时，上一间的详情/画质/线路还在占连接与 DNS。若数字显示 `qualities`/`lines` 段在大、且用户是连换几间房，再考虑把取消信号接进 `getRoom/getQualities/getLines`（那是 34 站的接口面，别无证据动）。
  - T25 三次串行请求：`getRoom → getQualities → getLines` 是三次网络往返才交源（参考同样两次 `getRoomDetail → discover → _openQuality`）。要合并必须先证明本站两个调用打的是同一端点且第二个不依赖第一个的字段（bilibili 的"双 playinfo 是 API 固有"已经判过一次，别再当成免费午餐）。
- 2026-11-05 P35（`1ff3e9358`）：数字要有人能看见才算数。`RoomOpenTiming.stages`（`name`+`took` 的清单，chat 从 T0 起算）交给 `roomOpenRecordProvider`，**直播间详情**里多一段「进房耗时 · 共 N 毫秒」：房间信息/画质列表/线路地址/交给播放器/首帧/开始播放/弹幕握手，未到达的阶段**不列**（列 0 会被读成"这步很快"而不是"没走到"）。开新房间先 `clear()`，上一间的数字不能冒充这一间的。日志行仍写（`room-open …`），两处同源——`line()` 现在由 `stages` 生成，不会漂成两套数。门：`dart analyze lib` 0 issues、`flutter test test/live` 53 例中 52 绿（含 timing 5 例）、`dart format` 只点本轮三个文件。运行期未验证：这一段要在真开一次房之后才有内容（进房没走完就退出 ⇒ 没有记录，段落自己藏起来）。
- 2026-11-05 第六次（进房先有数据）：**参考的“秒开”有一半是页面先有数据**。参考播放页带的是 `LiveRoomArgs(room, playlist)`，`LiveRoomController` 以列表卡片的 `LiveRoom` 起家，详情回来前就能画出标题/封面；我们的 `RoomRoute` 只带 `platform/roomId`，`RoomState` 初值 `room: null`，详情没回来前页面是空的。现在按参考直接传：`openRoom(..., room:)` 把卡片对象交给路由 `extra`，`RoomPage(room:)` 首帧就用它垫上；桌面独立窗口的路由是字符串，改走同一 isolate 的 `room_seed` 临时架（最多 8 条，取走即删），失败回退时清掉。`RoomController.open()` 收 `known`，详情回来覆盖；`retry`/切房/播放器重试也带当前房间。门：改动路径（路由/页面/各卡片入口/种子架）`flutter analyze` 13 项 0 issues；`room_controller.dart` 本身被并行 lane 的 `_resolveLines` 半成品挡着（缺 `Either`/`right`，闭包用了未定义的 `resolved`），未替其修，等那条 lane 落地后再补跑整文件分析。运行期未验（当前跑的 exe 是 11-04 12:06 的构建，早于 P34/P35，盘上没有 `room-open` 行）。
  - 仍缺数字：热重载/重启后开一间房，详情里的「进房耗时」或日志里的 `room-open` 才有 detail/qualities/lines/request/firstFrame/playing 分段。数字出来再决定是否做 T24（取消在途请求）或 T25（合并请求）；视频段慢时先看 `request→firstFrame`，引擎创建/探测成本目前没有单独的阶段。
- 2026-11-05 盘上旧日志的两条结论（省得下轮再翻）：
  - **旧日志量不出进房耗时**：`apps/pure_live/build/windows/x64/runner/Debug/pure_live_debug/data/logs/`（最新到 10-28 09:51）里 `[network]` 行有 `[#id] 200 <ms>`，但那几份会话没有一次房间入口请求（grep `get_info|getDanmuInfo|livePlay|room/v1/Room|h5getInfo` 全空，只有分区/热门列表）。⇒ "参考两三秒、我们慢"在现有盘上证据里**无法复现也无法否证**；P34/P35 的 `room-open` 行是唯一能拿到当期数字的路，别再回炉 P1/P2 已修的两条真因。
  - **`DsBoxDecoration does not expect to be used for clipping` 已在树里修掉**：旧日志 262/422 次（10-28 那次会话刷屏）。原因＝`Container(decoration: DsBoxDecoration…, clipBehavior: 非 none)`，`_DecorationClipper` 向装饰要 clipPath 而 `DsBoxDecoration` 拒绝（desen_ui 自己从不设 clipBehavior）。现在全仓只有三处 `clipBehavior:`（两处 `Clip.none`，`theme_pane.dart:190` 那处用的是普通 `BoxDecoration`），`multiview_page.dart:681` 还留着这条注释并把 clip 提到 `ClipRRect`。⇒ 已闭环，别当新伤再查；若真机又刷这条，先找新加的 Container+DsBoxDecoration+clip 组合。

- 2026-11-05 **事故（必须记住的那条）**：P37 那笔我用 `git commit -- <我的文件>` 提交了 `room_controller.dart`，但那片刻着**别人 lane 正在写的同一文件**（`open({..., LiveRoom? known})`、`_knownRoomOf`、`_knownRooms`、首帧前的 warm 分支）。⇒ 他们的未完成改动被我署名 `746fec7d7` 提交并推送了。内容没坏（analyze 干净、测试与基线一致），但署名错了，而且已推送不能重写。**规矩升级**：`git commit -- <path>` 之前必须先 `git diff <path>` 逐 hunk 看有没有别人的改动；文件被两条 lane 同时打开时，**这笔不提交**（或等对方先落），别信"pathspec 就安全"——pathspec 只挡别的文件，挡不住同一个文件里的别人的 hunk。本轮已按新规矩把 `player_surface.dart` 的两行留在工作区不提交（那文件此刻也有别人的 hunk）。

## 进房分段实测（2026-11-05，探针直跑 `createBuiltInLiveSites()`）

临时 `flutter/dart test` 探针（跑完即删，规矩见 `feedback-temp-tests-delete-after-verifying`）：每站取推荐第一间的**在播**房，按房间真实的调用顺序量 `getRoom → getQualities → getLines` 三段墙钟（每段 20 s 预算，直连，不经 App 代理/cookie）。单位 ms，`sum` 为三段和（这就是"交源之前"的全部网络时间）。

| 站 | detail | qualities | lines | sum |
| --- | --- | --- | --- | --- |
| bilibili | 168 | 92 (5档) | 91 (6线) | **351** |
| douyu | 104 | 247 (4) | 120 (1) | **471** |
| douyin | 648 | 1 (3) | 3 (2) | 652 |
| huya | 398 | 118 (5) | 544 (6) | 1060 |
| kuaishou | 423 | 557 (4) | 238 (1) | 1218 |
| acfun | 627 | 306 (4) | 315 (1) | 1248 |
| cc | 478 | 221 (4) | 2 | 701 |
| soop | 957 | 1 (4) | 733 | 1691 |
| yy | 29 | 321 (2) | 59 | 409 |
| bigo | **2395** | 430 (1) | 1203 | **4028** |
| liveme | 1914 | 1 (1) | 0 (2) | 1915 |
| pandalive | 1286 | 0 (5) | 0 (1) | 1286 |
| baidulive | 1127 | 1 (3) | 0 (4) | 1128 |
| showroom | 1038 | 1 (4) | 0 | 1039 |
| chzzk | 208 | 1132 (5) | 1 (2) | 1341 |
| 其余小站 | inke 294 / jdlive 468 / kilakila 679 / kugoulive 337 / missevan 127 / sixroom 418 / weibo 140 | | | |

热门为空的站（本机网络或无匿名列表，与 `reference-pure-live-live-site-health` 一致）：youtube/twitch/kick/fc2live/niconico/picarto/looklive/xiaohongshu/steambroadcast/tiktok/twitcasting/17live。

**这次的结论（把两条候补降级）**：
1. **用户主要看的站，"交源前"只有 0.35–0.5 s**（bilibili 351 / douyu 471）。⇒ 之前为"打开慢"排队的 **T24（取消被取代的在途请求）与 T25（合并三次请求）不是慢的原因**：T25 最多省 200 ms 且要动 34 站接口面；T24 只在"快速连换几间房"时有意义。**两条都不许再当作提速项来动**，要做也只能以"换房时不再抢连接"为动机、单独拿证据。
2. 剩下的时间只能花在 **引擎侧**（create→open→首帧）或 UI 等待上；`room-open` 的 `request/firstFrame/playing` 三段能量它，但**当前盘上的 exe 早于计时**（`project-pure-live-room-open-latency` 同样记着这条）⇒ 下一轮要真数字只有一条路：重新构建并跑一次 App（`build/verify_room.py`/`drive_app.py` 已不在仓里，只剩 `scripts/sync_github_mirrors.py`）。
3. **站点侧的真慢点有主了**：bigo 的 `getRoom` 单段 2.4 s（另加 lines 1.2 s）——这是 bigo 适配器/端点的问题，不是进房流程的问题；soop 957、chzzk  qualities 1132 同理。**归站点 lane**，别在房间线里绕。
4. **普查顺手发现**：`LiveHotProvider` 在 34 站里**零实现**（热门实际走 `LiveDiscoveryProvider.getRecommendedRooms`）。`toolbox_controllers.dart:246` 的 `capability<LiveHotProvider>()` 分支永远是 null——它能正确退回 discovery，所以不是 bug，但这是接口冗余；删接口是包侧决定（等点名）。

## 别人的门：`recording_schedule_test.dart` 为什么长期一红（我只报，不改）

`flutter test test/live` 连续多轮 52/53，红的 Always 是这一条。判据现场：

- `modules/live/recorder/data/recording_task.dart:331` 现在是 `bool get needsLiveCheck => isArmed;`
- 同一文件 `:325-330` 的文档注释还在写旧语义（"等待开播的房间一上线就起录；排期结束的等下个窗口再装填；正在录或一次性录完的不必检查"）。
- `test/live/recording_schedule_test.dart:97,103` 断言的正是文档那套：waiting ⇒ true、排期任务 ⇒ true。

⇒ 代码/注释/测试三者两两矛盾，改哪一边都是**录像 lane 的产品决定**（结合 `project-pure-live-recorder-subscriptions` 的"开播检测默认 false"，新语义像是刻意的：没订阅检测就不轮询）。要落新语义，需要同步改掉 `:325-330` 的注释与 `:97/:103` 两条断言；要回旧语义，就把 waiting/排期-结束两支写回 getter。我不碰他们正在编辑的文件，只把冲突点写在这里，省得每轮重新解剖一次。

## 过滤器族逐文件 diff（2026-11-05，把"持平"从散文换成证据）

对 `E:\study\Pure_live\packages\live_danmaku\lib\src\filters\` 的九个文件与 `packages/live_sites\lib\src\common\danmaku\filters\` 同名九个做去 import/空行后的行 diff：

| 文件 | diff 行数 | 差异性质 |
| --- | --- | --- |
| block_pattern | **0** | 完全一致 |
| partial_ratio | **0** | 完全一致（fuzzywuzzy 1.2.0 算法的独立实现，两边同源） |
| message_gate | 35 | 只有模型字段名（`payload`/`sender`/`giftOrNull`/`message.text`）与具名构造写法；判据（`replayed`+`maxReplayAge`、付费卡按 `endTime` 免死、撤回目标并进键）一致 |
| block_list | 36 | 同族字段名 + 我们把 `isMaskedName` 提为公开（P23 用） |
| message_filter | 37 | 同族字段名；纯表情/超长判据一致 |
| text_shape | 37 | **有意的我们更强**：`danmakuMessageShape(..., emoticonPattern:)` 钩子（T10，把内置表情表喂进判据）；正则里 `\u200d\ufe0f\u20e3` 是转义写法差异（含一条 `// ignore: valid_regexps`，因为分析器不认识 UTS#51 的 Extended_Pictographic，Dart 自己编得过也跑得对） |
| repeated_filter / similarity_filter | 11 | 注释与构造写法，无语义差异 |

⇒ **第四部分（对比 live_core/live_danmaku）至此是"逐文件核过"而不是"看起来差不多"**：九个文件里没有一处判据漂移。下轮别再解剖这条线；要动过滤器族只能拿新需求来。

## 已证实的功能洞：Bigo 的 HLS 今天是加扰的，我们没有中继（2026-11-05 实测）

临时探针（跑完已删，规矩同 `feedback-temp-tests-delete-after-verifying`）拿一间在播 Bigo 房，按房间真实链路走 `getRecommendedRooms → getRoom → getQualities → getLines`，然后**用那行的 headers 去 GET 那条 m3u8**，回来的正文第一手证据：

```
status=200 mediaPlaylist=true protectionTag=true seed=3164316742
head=#EXTM3U | #EXT-X-BIGO-WEB-PROTECTION:VERSION=1,SEED=3164316742 | #EXT-X-VERSION:3 | #EXT-X-MEDIA-SEQUENCE:0 | …
segmentUri=2848450172_0&832912293&0.ts
headers=[origin, referer, user-agent, accept, accept-language, x-requested-with]
```

- 我们的 `BigoHlsProtection` 文档早就写着"分段的前两个 TS 包各前 16 字节按 seed 的 xorshift 异或，sync 字节与 PAT/PMT 不可读；**谁播谁中继**"，包侧算法（`seed()`/`transform()`）已经齐备，`live_sites` 里也**没有任何 HTTP 中继**（全仓 grep `relay|loopback|descrambl` 只有测试用的 loopback）。
- ⇒ **现在 Bigo 房间在我们这儿的实际行为 = 把加扰列表交给 mpv**：demuxer 找不到 TS sync byte，等于黑屏且没有任何解释。上一轮的探针显示 bigo 三段都"成功"（detail 2395/qualities 430/lines 1203）——**取到地址不等于播得出来**，这条教训写在这。
- 参考侧对照：`live_media/lib/src/relay/{hls_relay,hls_window,loopback_relay}.dart`（约 800 行：环回 HTTP server + 分段窗口 + byte-range + per-path cookie 钩子 + `restore` 钩子 + `HlsSourceQueryPolicy`），`bigo_site.dart:62,577-590` 明写 Bigo 走中继恢复每段；niconico 用同一台中继做 per-path cookie 与 master 精确变体重写（我们 `niconico_play_parser.dart:372` 直接交 hls 地址，同样没中继——niconico 本机不可达，未实测）。

**两条路（要用户点头才能动，因为这是新媒体子系统 + 架构落点）**：
1. **做中继**：落点候选 `packages/live_sites/lib/src/common/hls_relay/`（它需要 headers/cookies 与 restore 钩子，站点侧最贴近）或 media_core 的播放器包。最小形态：给一行起一个环回端口，`/p.m3u8` 取上游列表并把相对段 URI 改写成 `/s/<n>.ts`，`/s/<n>.ts` 带上该行 headers 取段、有 seed 就 `transform`，随 take 生命周期关端口。要决定：端口安全（只 bind 127.0.0.1、随机 token 路径）、缓存与失败重试、直播窗口只保留最后 N 段、`LivePlayLine` 需要一条"这行要中继"的表达（不能让 app 猜平台）。
2. **先诚实报错**：Bigo 行照现在返回，但房间给出可读的"此平台的 HLS 需要在本地还原，本 App 尚未实现"，别再演"能播"。代价：Bigo 从"黑屏"变成"有原因的失败"，功能面没增加。

**顺手记的另一条方法论**：判断"某站能不能播"必须走到**取回播放列表/首段字节**这一层；只把三段网络调用跑绿是假阳性。

## 本轮（2026-11-05）自查：能落的都落了，剩两处被别人的在途改动卡着

1. **本轮我加过的串逐条核过**（18 个键：`lockControls/unlockControls/portraitSwipeHint/openInNewWindow/cookieRefused/portraitSwipeSwitch(+Desc)/openStages(+Total/+Failed)/openStageValue/openStageDetail/Qualities/Lines/Request/FirstFrame/Playing/Chat`）：每个键在 **zh-CN 与 en 两份源里各出现 1 次**（src=2），且都至少被一处代码引用（users≥1，`portraitSwipeSwitch` 为 2：设置行 + 搜索目录）。⇒ 没有孤儿串、没有单边翻译、没有造了没接的入口。设置新行照规矩进了搜索目录。
2. **`displayLabel` 的四处显示位本轮仍落不了地**，因为文件上挂着别人未入库的 hunk（按 P38 事故立的新规：同一文件两条 lane 在写就不提交）：
   - `room/page/player_surface.dart:430`（画质面板条目）、`:1246`（条上画质按钮）— 该文件此刻还带别人的 `controller.open(known: room)` 改动；
   - `multiview/multiview_page.dart:1099,1104`（格子上的档位名）— 该文件也脏。
   我改的两行**留在工作区**没提交；getter 已在 HEAD（`34578f23c`），所以谁先把这些文件提交进去都不会编不过。下轮开工先 `git status` 看这四个位置还在不在别人手里，不在就把这两处补完。
3. **Bigo 的加扰问题还等一个决定**（证据与两条路见上一节）。要点没变：包侧已有 `BigoHlsProtection.seed/transform`，缺的是"谁来逐段还原"。**没有选之前我不擅自新增一个媒体子系统，也不擅自砍掉一个平台**——参考侧的做法（`record.md:39`）是本平台干脆不给 `LivePlayUrlResolution.lines`，由 `BigoHlsInput` 自己开环回中继，直连 11 次只成 1 次、不解扰 0/2。选 1 我就照这个契约加"这行要先解扰"的表达并接 bigo；选 2 我就让它带原因失败。
4. 顺手记一条与本车道有关的**接口事实**（免得下轮又当新发现）：`LiveHotProvider` 由 34 站中的 **0** 个实现，热门实际一律走 `LiveDiscoveryProvider.getRecommendedRooms`；`toolbox_controllers.dart:246` 的 hot 分支恒为 null（能正确退回 discovery，所以不是 bug，是冗余接口）。删公开接口是包侧决定。

## 本轮（2026-11-05 第三次续）：P39 进房行加上"走哪条路出去"

| P39 | `bd54f39e4` | 进房诊断 | `room-open` 多了 `proxy=direct\|system\|manual`（`RoomOpenProxy` 自带 token，纯类可测），详情的「进房耗时」抬头跟着显示 `不使用代理/跟随系统代理/手动代理`（复用网络页现成三串，不再造第三套词）。**动机**：站点探针记录说 5 站（youtube/twitch/picarto/17live/steambroadcast）只有开 `127.0.0.1:7890` 才通，而 `app proxy.mode` 默认 `off`（`reference-pure-live-live-site-health`）——同一个 detail=10s 的数字，两种病因、两种修法，光看分段量不出来。新例 1 条：`flutter test test/live` 54 绿中 53（唯一红仍是录像 lane 那条）。|

同时复核：**`displayLabel` 的四处仍然落不了地**——`player_surface.dart`、`room_page.dart`、`room_switcher.dart` 此刻都带着别人未入库的 hunk（`controller.open(known: room)` 一族），本轮新提交没有碰这三个文件；Bigo 中继的 1/2 选择继续等点名，我不擅自新增媒体子系统，也不擅自砍平台。

## P37 的回溯验证（2026-11-05，临时探针跑真适配器，用完已删）

P37 把房间取线路改成"能确认的站先要 plan"。这是改了**取流路径**的改动，不能只靠 analyze 过门，所以直接对在册的 resolver 站各开一间在播房，比 `getLines` 与 `resolvePlan` 两份答案：

```
PLAN-CHECK douyin   plain=2 plan=2 firstSame=true  applied=蓝光 served=蓝光 asked=蓝光
PLAN-CHECK bilibili plain=6 plan=6 firstSame=false applied=超清 served=超清 asked=2K
PLAN-CHECK huya     没有注册 resolver
```

- **bilibili 当场证实了这个改动的必要性**：无登录态要 2K，平台答 **超清**。改之前条上会一直写 2K（要来的名字），现在写超清（给的名字）。
- douyin 两边一致（段数与首条 URL 同），说明"能确认的站"里没有确认时行为不变 —— 没有回归。
- `firstSame=false` 是**正常的**：bilibili 每次问线路都重签 CDN 令牌，两次请求的 URL 天然不同；条数一致即可，播放器拿的是 plan 那份，不会再混用。
- **纠正我自己写错的两处散文**（代码没问题，登记以防下轮照抄错事实）：注册 `LivePlaybackPlanResolver` 的是 **bilibili / cc / douyin / twitch / yy** 五站（`*_site.dart:573/416/513/650/678`），**huya 不在其中**；我在 `746fec7d7` 的提交正文里把 huya 也算进去了。
- 探针侧的 cc/yy/twitch 超时是探针自己没包 try（推荐接口 20 s 未回），不是产品分支：房间那条路是 `resolvePlan` 失败就退回 `getLines`，正是今天的行为。
| P40 | `da0be7760` | 门的补票 | 本车道这一路有几个行为是"只有静态门、运行期没验"的：常驻登录提示条（P27）与进房耗时记录（P35/P39）。给它们补了 `test/live/room_notice_record_test.dart`（6 例）钉住可钉的部分——**同平台同文案不再换 state 实例**（换了就是每来一轮掩码名就闪一次条）、**换平台要替换**（条上那个按钮开的必须是这一站的登录）、**新房间要清空上一间的毫秒**、发布的 stage 只列到达过的段、`proxy` 随记录一起出去。门：`dart analyze` 0 issues、`flutter test test/live` 60 例中 59 绿（新增 6；唯一红仍是录像 lane 的 `recording_schedule_test.dart`）。运行期仍未验：条要真坏 cookie、面板要真开一次房。 |

## 全量测试核对（2026-11-05，跑整个 `flutter test` 而不是只看 test/live）

`cd apps/pure_live && flutter test`：**324 绿 / 2 红**。本车道（test/live 里直播间相关、test/app、test/vod、test/hongguo）全绿；两条红都不是本车道造成的，且各自有明确主人，别再重新诊断：

1. `test/live/recording_schedule_test.dart: only the live check moves a waiting or scheduled task` —— 已在「别人的门」一节定性：`recording_task.dart:331` 的 `needsLiveCheck => isArmed` 与它自己 `:325-330` 的注释互相矛盾，测试断言的是注释。改代码还是改注释+测试，归录像 lane。
2. `test/music/music_pages_providers_test.dart: the providers the music pages watch all build` —— 新红，**与本车道无关**：`app/providers/boot/storage_providers.dart:10` 从 `4d8c21365`（"每个文件目录有默认值与选择"）起改成 `UnimplementedError: storagePathsProvider must be overridden at boot`，而音乐这个测试在 `:30` 用裸 `ProviderContainer()`，没有 boot 覆盖 ⇒ provider 处于 error 态。**全仓目前没有任何测试覆盖过 `storagePathsProvider`**（grep 为空），所以这不是"照抄某处现成写法"能解决的：要先定测试该注入临时目录还是让 provider 在非 boot 环境回落。归音乐/存储 lane 决定；本车道只把因果钉在这里。

## mpv 开播属性对照（2026-11-05，第四部分：把"抄参考"限制在测过的数字上）

两边都读源码，不看提交信息：

| 属性 | 参考 `live_player/lib/src/mpv_options.dart:134-158` | 我们 `media_core_media_kit/.../media_kit_player_adapter_engine.dart:52-58` |
| --- | --- | --- |
| `demuxer-lavf-probesize` / `-analyzeduration` | 1048576 / 1（注明是 Bilibili 冷启动 A/B 实测：2MiB/2s 首帧 1802 ms → 1MiB/1s 708 ms） | **同值**（P1 已抄，注释里带着同一组数） |
| `cache-on-disk` | no | no |
| `network-timeout` | 15 | 15（媒体侧默认 5 s 会把"6 秒才应答"的活线读成"房间打不开"） |
| `hwdec-software-fallback` | 1 | 1 |
| `cache-secs` / `demuxer-max-bytes` / `demuxer-max-back-bytes` / `demuxer-donate-buffer` | 6 / 32 MiB / 4 MiB / no（注释自称 3.x 的 LiveBufferPolicy：内存缓存 + 小前后窗） | **不设** |
| `demuxer-readahead-secs` | **2** | 不设 |
| `force-seekable` | yes | 不设 |
| `protocol_whitelist` | 一长串显式白名单 | 不设 |

**为什么这轮不"对齐"**（关键判断，别再当免费午餐抄）：
1. `demuxer-readahead-secs: 2` 是**先攒 2 秒再播**的意思，把它抄进来是拿首帧换平滑——正好与第 2 部分的诉求相反。我们保持不设（跟 mpv 自己的默认），这是**有意的差异**，不是遗漏。
2. `cache-secs`/`demuxer-max-*`/`donate-buffer` 一族的注释只说"有界的直播缓冲（内存、小窗口）"，参考自己**没有**给出这些数对首帧的实测；能引用的实测只有探测那一对，而我们已经有了。
3. `force-seekable: yes` 服务的是时移/回看_seek_；我们的直播线不做 forward seek（`selectLine`/`retry` 重开，不 seek）。
4. `protocol_whitelist` 是**收紧**：抄一份显式白名单等于把"今天能播、名单里没有"的协议判死，而我们没有任何一站需要它。要加必须拿具体失败协议来证。
5. **留给真数字的口子**：等 `room-open` 行给出 `request→firstFrame` 很大（比如 >1.5 s）时，唯一值得先试的是把 `demuxer-max-bytes`/`cache-secs` 调小（少攒就早播），并且要 A/B 出前后中位数——不是照抄 2 秒 readahead。

## 发弹幕能力普查（2026-11-05，防止下轮去"补 34 个发送器"）

怀疑过一条大缺口，实测**不是**缺口，证据钉在这里：

- `LiveDanmakuSending`（`live_sites/lib/src/capabilities/live_danmaku_sending.dart`）在**全包 0 个实现者**（grep 整个 `packages/` + 引擎仓 `media_core/packages/` 都只命中定义文件）。
- 因此 `room_controller.dart:1181 canSendDanmaku` 恒为 false，`sendDanmaku` 走不进发送分支。
- 但界面**没有因此挂死门**：聊天列的发送框在 `room_chat.dart:480` 就 `ref.watch(...canSendDanmaku)` 并据此不渲染输入框与「发送」按钮，所以看不到一个永远发不出去的框（`sendFailed` 那条 toast 也就只会出现在真失败时）。
- **与参考对齐**：参考的 `live_danmaku` 里根本没有"发直播弹幕"这件事——`sender.dart` 是 `DanmakuSender{avatar}`（"这条消息是谁发的"，B06），不是发送器；它真正的发送实现只在 `live_vod/ugc_api.dart`（**视频**弹幕）。参考房间条上那个输入框是 `LocalDanmakuComposer`，属于已判定不平的本地 +1/常用语子系统（见"已判定不平"），并不发平台。
- ⇒ 结论：**这是双方共同的能力边界，不是我们缺的功能**。以后要真做发直播弹幕，是从零按站点接（每站一套签名/凭证/风控），属于逐站点新功能，不属于本对照车道；接口已经在那儿，第一个实现者一接，`canSendDanmaku` 与发送框会自动亮起（不需要再改房间）。
| P41 | 引擎 `1a55218`（media_core，本地提交不推送） | 秒开回归门 | 上一轮做完 mpv 属性对照后，把结论变成挡得住手误的门：新 `packages/media_core_media_kit/test/mpv_live_open_defaults_test.dart`（3 例）钉住"探测预算是实测值"（1048576 / 1）与 network-timeout/hwdec 回退/cache-on-disk，**并且钉住我们没设的那两个键**——`demuxer-readahead-secs`、`cache-secs` 必须保持缺席，谁顺手"对齐参考"就把首帧拿去换平滑，测试会先响。门：包 `dart analyze test` 0 issues、`flutter test` 28 绿（含新 3 例）。参考那侧的 32 MiB/6 s/2 s 一族的取舍理由与"要改就拿 room-open 的 firstFrame 做 A/B"写在「mpv 开播属性对照」一节。|
| P42 | `dabaee163` | 首帧前的分段 | `room-open` 在 `request` 与 `firstFrame` 之间多打一个 **`opened=`**：引擎第一次报"输入已打开"（`PlayerCoreState.ready`）的时刻。为什么值得多一段——那段空白现在装着两种完全不同的病：**等签名 URL 应答（CDN/DNS/探测）** 与 **拿到数据后解码**。`markOpened` 只进日志不进详情面板（观众不需要这一刀），但 `_marks` 把它算进"上一段起点"，所以 `firstFrame` 不再把等 URL 的时间重复记一次。门：`dart analyze lib` 0 issues、`flutter test test/live` 61 例中 60 绿（timing 现在 7 例）、唯一红仍是录像 lane 那条。**下次拿到 `room-open` 行时先读这三段**：`request→opened` 大 ⇒ 网络/线路（先查 `proxy=` 与 fake-ip，见 `reference-local-proxy-fakeip-diagnosis`）；`opened→firstFrame` 大 ⇒ 解码/探测（才轮到 P41 钉住的那张属性表）。 |

- 2026-11-05 **P42 自己被抓到是错的（改在 `7dbcca595`）**：`markOpened` 原来只看 `PlayerCoreState.ready`，但引擎在 `player_adapter_base.dart:190` **初始化完就 ready**（`initializingState().readyState()`），到 `:240` `await onOpen()` 回来后才是 `openingState().withSource(value: true).readyState()`。⇒ 只看 ready 的话 `opened` 与 `request` 同一瞬间，分段**看着有其实是 0**，比没有更坏（会被当成答案读）。改法：`ready && hasSource`；并把 `markRequested` 挪到 `await playback.play(...)` **之前**（play 内含 open 的等待），于是 `request→opened`=CDN/DNS/探测、`opened→firstFrame`=解码。教训：**新加一个计时段，先去引擎里找它由谁在哪一行置位**，别看名字像。门：`dart analyze lib` 0 issues、`flutter test test/live` 61 例中 60 绿（唯一红仍是录像 lane）。

- 2026-11-05 **P43（`38bb13093`）：`firstFrame` 也犯过同一类的错，已改。** 它原来标在 `geometryController` 第一次报出 videoSize 的时刻，但引擎的事件表自己写着两套语义：`videoSizeChanged` "**only describes video geometry**"（demuxer 探测阶段就知道尺寸），`videoFrameProgress` 才是"后端又解出一帧"（`player_adapter_event.dart:66-73`，media_kit 适配层在 `:962 emitVideoFrameProgress()`，且能力位 `supportsVideoFrameProgress` 可能为 false）。⇒ 用几何当首帧会把解码时间记到网络段上，正好毁掉昨天那段拆分要买的东西。现在：`_watchFirstFrame(handle)` 订 `handle.adapterEvents`（引擎文档保证该流跨后端切换仍有效），只认 `PlayerAdapterVideoFrameProgress`；报不了的后备就留 `-`，不猜。订阅随 handle 重建、随 `_teardown` 取消。
- **本轮立的车道规矩**：给"某一时刻"加计时标记之前，先去引擎里读**是谁、在哪一行、因何而发**置的这个状态/事件（昨天 `ready`、今天 `videoSize`，两次都是名字像而语义不同）。判据不是"看起来是那个东西"，是发它的那行代码的注释与前置条件。
- 门：`dart analyze lib` 0 issues、`flutter test test/live` 61 例中 60 绿（唯一红仍是录像 lane 的 `recording_schedule_test.dart`）、`dart format` 只点本文件。

## 第六次对照（2026-11-05 第四次续）：live_core 的 HLS 选流族，实测出一个真洞

参考 `live_core/lib/src/hls_master.dart`（358 行，`HlsMasterPlaylist`/`HlsVariantSelector`/`HlsMasterSelection.rewrite`）+ `hls_source_query_policy.dart`（87 行）。第四次对照时把这一族判成"不搬"，理由是参考自己写明查询串策略只对验证过的 TTing/FLEX NCP 契约开启——那个理由对 `hls_source_query_policy` 仍然成立，但**`hls_master.dart` 的选档（G01.4）对我们是一处真实的功能洞**，本轮用真适配器实测出来：

- 我们的 7 站已经把 master 的变体解析成**自己的 URL 并当作线路**交出去（twitch/youtube/kick/chzzk/niconico/pandalive/picarto 都走 `resolveHlsVariantUri`，`twitch_play_parser.dart:82` 是把 master 交给 mpv 的反例——它每档一条变体地址）。
- **只有 steambroadcast 是"档位名单来自变体、线路却永远是 master"**：`steambroadcast_room_parser.dart:794` 写死 `url: '${data.master}'`，`SteambroadcastVariant` 连 URI 字段都没有；它自己的注释就承认"the master restricted to a variant is not expressible as a line here"。⇒ 今天选 1080p 还是 360p，交给引擎的都是同一条 master，mpv 自己 ABR：**档位是装饰品，而且每次改档都要重新打开一次流**（`selectQuality` 无条件 `_startPlayback`），观众看到的是一次黑屏 + 重缓冲，换来的是标签变了。
- 探针（临时 `dart test`，跑 `DioFactory(proxyPolicy: FixedProxyPolicy(HttpProxyRoute(127.0.0.1:7890)))` + 真 `SteambroadcastSite`，用完已删）实测一间 4 变体的在播房：
  ```
  room=76561199466473501 variants=4 qualities=自适应 HLS,1080p,720p,480p,360p
    MASTER #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="aac",NAME="Default",...URI=".../320000/audio.m3u8?broadcast_origin=ext6-hkg1..."
    MASTER #EXT-X-STREAM-INF:BANDWIDTH=7320000,CODECS="avc1.640028,mp4a.40.2",RESOLUTION=1920x1080,FRAME-RATE=30,AUDIO="aac"
      child 1080p media=true seg=200/1350540B  init: box=ftypiso5 handler vide=true soun=false
      child 720p  media=true seg=200/238358B   …
  ```
  两件事由此钉死：**① 变体地址能独立应答**（200、是媒体播放列表、首片能下）；**② 但它没有音轨**（init 盒 `ftypiso5` 里只有 `vide` handler，`soun=false`；`AUDIO="aac"` 指向 master 的另一条 rendition）。⇒ **照 twitch 的样子把变体 URL 当线路交出去会播出声画分离的哑片**，参考的 `HlsMasterSelection` 保留 `#EXT-X-MEDIA` 那一行、把 master 改窄，正是为了躲这个。
- 所以"接参考的选档"在我们的架构里必须回答"改写后的 master 交给引擎走哪条路"，两条形状都要用户点名（本车道不擅自新增媒体子系统）：
  **1** 环回中继：房间起一个只服务这一份文本的 `127.0.0.1` 小服务（变体与音轨 URI 在 Steam 的 master 里本来就是绝对地址，中继只需应答那一个 master 请求，段流量仍直连 CDN）；`LivePlayLine` 要能表达"这条要先还原/改写"。**2** 交本地文件：把改写后的 master 写进临时目录、以 `file://` 交给引擎（无服务，但 `live_sites` 是纯 Dart 领域包不能做 IO，装配点要在 app/引擎侧；录制侧重签地址的路也会跟着变）。两样都要先决定"谁拥有这段文本"。**没点名之前两样都不做**，本轮先做不需要新形状的那一半 ↓。

| P44 | （本轮）| 档位诚实 | 把"选了平台 serve 不出来的档"从一次重开降成一次改标签：包侧新 `isSamePlayPlan(loaded, asked)`（`live_play_line.dart`：同序、同 URL、同 `format`、同 headers；**同一地址换了 lease 不算换媒体**，到期由 `_armLeaseRenewal` 自己盯），房间侧 `selectQuality` 带 `keepPlayingWhenUnchanged: true`，`_startPlayback` 在"当前在播 + 新计划就是已加载的那份"时直接返回。**只有改画质这一路可以短路**：lease 重建（`:1527`）与进房（`:899`）不带这个旗标——它们要的就是"哪怕地址相同也要重开"。新 `packages/live_sites/test/models/live_play_line_test.dart` 6 例（相同/换地址/换 headers/条数变/顺序变/换 lease）。门：live_sites `dart analyze lib test` 0 issues、`dart test` **475 例中 474 绿**（唯一红是搜索 lane 在途的 `site_facts_test.dart`：他们的 `looklive` 退役让 retired 集合从 11 变 12，测试没跟着改，`site_facts.dart` 是他们脏文件）；app `dart analyze lib` 0 issues、`flutter test test/live` 61 例中 60 绿（唯一红仍是录像 lane）。运行期未验：要在 Steam 房改一次档，画面不该再断。 |

- **Steam 的档位名单本身仍然是假的**（P44 只是不再为它重开流）。要让它真生效，等上面 1/2 点名。这是本车道第二个"等点名"的决定，第一个是 Bigo 的加扰 HLS。

## 弹幕 socket 运行时普查（2026-11-05 第六次，第四部分：把"参考有 DanmakuSocketPolicy 我们没有"证伪）

参考 `live_danmaku/lib/src/socket_connection.dart` + `connection_base.dart`：一个**共享运行时** + 每站一份 `DanmakuSocketPolicy`（`heartbeatInterval`、`inactivityTimeout`（默认=3 个心跳周期、至少 90 s）、`joinTimeout`、`maxReconnects=8`（**收到任何消息就把计数归零**）、端点轮换 + 每轮加一档回退、`connectTimeout=10`、`shutdownTimeout=2`）。第一遍普查我用 `HeartbeatConfig(`/`ReconnectPolicy(` 计数，得出"只有 7 站配了心跳"——**那是错的度量**：我们 22 个 socket 站分两个缝，只有 10 站走 `DanmakuSocket`（`live_websocket` 的 `LiveWebSocketClient`），另外 12 站（yy/acfun/picarto/showroom/soop/kick…）拿 `SocketChannel`（`webSocketConnect`）**自己按协议打拍子**。按正确的词汇重数（`silence/silent/inactivity/quieter`、`joinTimeout/_join/handshakeTimeout`）：

| 检查项 | 结果 |
| --- | --- |
| 心跳 | 22 站全有（7 站用 `HeartbeatConfig`，其余 `Timer.periodic` 发协议帧） |
| 静默看门狗（socket 还在但不吐消息就换） | socket 站**全有**：`acfun_danmaku_session.dart:403 _startSilenceWatch`（"every frame rearms it"）、yy `:237 _watchdog`、bigo/kick/picarto/showroom/soop… 各自的 silence 常量；HTTP 轮询站（youtube/niconico/kuaishou/baidulive/steambroadcast）不适用 |
| 进房握手超时 | 参考逐站设的（acfun 10 s / bilibili 8 s / kilakila 8 s / YY handshakeTimeout）**我们都有**：acfun `joinTimeout=10 处命中`、kick 12、bilibili/chzzk/fc2live/kugoulive/missevan/pandalive/picarto/seventeenlive/kilakila/sixroom 均非零，yy 用 `handshakeTimeout` 起 `_join` 定时器（`:172`） |
| 有界重连 + 计数复位 | `ReconnectPolicy(maxAttempts…)`，`websocket_client.dart:198` 在**连上时 `_retryCount = 0`** ⇒ 与参考"收到消息就归零"同义（不会在看了一晚上之后因为累计断连次数把聊天判死）；10 站显式配置自己的策略，8 站关掉通用重连自己走阶梯（`reconnectPolicy: enabled: false`），无一站留默认 |
| `shutdownTimeout`（关闭握手的最长等待） | **没有——本轮唯一的真缺口**，见 P45 |

| P45 | `c52f41c76` | 退出不被静默的对端拖住 | 离房要 dispose 聊天 socket，dispose 里 `await sink.close()`。dart:io 的关闭握手**要等对端回应**，所以对端一旦"连着但不应"（代理不再转发、网络到不了边缘节点），这个 await 会挂到操作系统放弃那条连接为止，而后面排队等着的正是弹幕会话的收尾、房间切换、乃至退出程序。两个缝都补了 2 s 期限（与参考 `shutdownTimeout` 同值）：`WebSocketConfig.shutdownTimeout`（客户端，10 站）+ `socket_channel.dart` 的 `_shutdownTimeout`（`SocketChannel.close()`，12 个自打拍子的站）。到期就**当作已关闭返回**，`closeCode` 留 null（各站在打开时本来就当 null 处理，只有卡住这一种情况的行为变了）。门：live_websocket `dart analyze lib test` 0 issues、`dart test` **16 绿**（新 2 例：`drops a socket whose peer never acknowledges the close` 用不回应关闭的假 sink + 1 s 外层期限，`the close deadline is short but not immediate` 钉住默认 2 s）；live_sites `dart test` 475 绿 + 1 红（搜索 lane 在途的 `site_facts_test`）；app `dart analyze lib` 0 issues、`flutter test test/live` 61 例中 60 绿（唯一红仍是录像 lane）。**薄缝（`SocketChannel`）那一路只有代码+文档，没有自动化测试**：它要一个"接受连接但故意不回关闭帧"的真服务器才测得动，dart:io 的服务器会自动回应，所以这 2 s 靠的是与客户端同一份实现的判据，不是钉住的门。运行期未验：断网/关代理后离房不该卡一下。 |

- **教训（度量类）**：普查"某能力哪些站有"之前，先确认**这个包里有几条路通向它**。我们弹幕 socket 有两条缝，用其中一条的配置名去数另一条，会同时造出假缺口（"15 站没心跳"）和假持平（"只有 7 站配了重连"）。
- 结构性差异记录为**不动**：参考一份共享运行时，我们两条缝（`LiveWebSocketClient` 与 `SocketChannel`）。把 12 个自打拍子的站搬到通用客户端是一次跨 22 站的协议重构（每站的心跳是几帧、什么顺序、带不带 ticket 各不相同），没有运行期验收手段就别做——这条留给以后真出现"某站阶梯不一致"的症状时再动。

## 运行期证据（2026-11-05：11-02/11-03 两份旧日志里能榨出来的东西）

盘上最新的两份运行日志（`%APPDATA%\com.purelive\pure_live\debug\data\logs\2026-11-02`、`2026-11-03`，10-31 之后只有这两份，**都在 P34 计时行之前**，所以仍然没有 `room-open`）里有 **1130 条带耗时的网络应答**。把 ≥1 s 的挑出来看，**绝大多数不是进房链路**：

- `raw.githubusercontent.com/.../version.json`（更新检查，1.3–8.8 s，多次）——更新 lane；
- `bing.biturl.top`（必应壁纸，3.1–5.4 s）与 `firebase.google.com`（3.1 s）——背景/网页 lane；
- 站点目录与搜索页（`douyu.com/japi/weblist`、`live.kuaishou.com/u/…`、17app 搜索 502）——列表页，不是房间；
- **房间链路上只有一处慢**：`api.live.bilibili.com/.../getDanmuInfo` 一次 **3666 ms**（同一请求另两次 76 ms / 78 ms）。⇒ 这条正是 P2 从 `detail()` 里摘出去的那张"弹幕票"：它**不在首帧路径上**（`room_controller.dart:879` 起 `_openDanmaku` 是 `unawaited`），所以它慢的时候观众看到的是"画面出来了、聊天空着"，而不是"房间打不开"。`getInfoByRoom` 在这两份日志里 127–223 ms，两次以上；**没有一条证据把首帧的等待指到网络**。⇒ 第 2 部分的判断不变：欠一次带 `room-open` 的重建（`request→opened` 与 `opened→firstFrame` 才是那把尺子）。

| P46 | `b7c832668` | 档位名 | `LiveQualityLabel`（`common/quality_label.dart`）**是从参考逐字搬来的，但全仓零读者、零测试**——所以条上/面板上一直在漏平台的原始词：斗鱼无 `multirates` 时写 **`default`**、有名单但某行缺 `name` 时写 **空字符串**（一档空白）、TwitCasting 写 **`HLS high/medium/low`**（别的站都写 超清/蓝光）、niconico 写 **`1280x720`**、bilibili 遇到 `g_qn_desc` 没描述的 qn 就写**光秃秃的数字**（`20000`）。四处接回共享回落（平台自己的词 → 该码的房名 → 分辨率 → 码率 → `清晰度 <id>` → 默认），douyu 的兜底是 `'default'` 这个 token 而不是硬写中文；**身份不动**：`qualityId` 一律保持原值（`'$rate'` / `high` / `WxH@bandwidth` / `'$qn'`），`isSamePlayTier` 优先按 id 比，录像订阅用的是自己的 `kPreferredResolutionChoices`，所以改名字不影响任何已存的档位选择。新 `test/common/quality_label_test.dart`（7 例，这个文件此前**一个测试都没有**）。门：live_sites `dart analyze lib test` 0 issues、`dart test` **482 绿 + 1 红**（仍是搜索 lane 在途的 `site_facts_test`）、douyu/twitcasting/niconico/bilibili 四个平台族 47 例全绿（没有一站的测试在断言旧的英文标签）；app `dart analyze lib` 0 issues、`flutter test test/live` 61 例中 60 绿（唯一红仍是录像 lane）。运行期未验：要在斗鱼 H5（无 multirates）、twitcasting、niconico 各开一次房看档位名。 |

- **本车道的方法再记一条**：搬到一半的共享件比没搬更危险——它看起来已经解决了。P46 就是"参考有、我们也有文件、但没人调用"的第三例（前两例：`portraitSwipeSwitchProvider` 只有读者没有写者 T20、`LiveCookieRefusalFeed` 只有写者没有读者 P36）。普查的问法必须是**两头都数**：谁写、谁读。

## 第七次对照（2026-11-05）：零读者普查、条上控件的形态普查，和"走掉的那次进房"

| 查的东西 | 结果 |
| --- | --- |
| `common/**` 的共享件谁在读（P46 方法的推广） | 两处**零读者**：`common/danmaku/emotes.dart`（`DanmakuEmoji`/`DanmakuEmojiAsset`/`parseList`，参考 `EmoteLibrary` 的逐平台 JSON 形态——我们早已换成 `EmojiAtlas` 一张图集+manifest，P16 用的就是它）与 `normalization/site_counts.dart` 的 `hasAudienceValue`。**都不删**（删除要点名，见 [[feedback-stay-on-requested-scope]]），登记为死端：`emotes.dart` 被 `danmaku.dart` barrel 导出但无人调用，以后真要做"逐平台表情 JSON"再启用它，别新写第三份。 |
| `LiveAudienceCapability.onlineAvailableInRoomLists` 零读者，是不是缺口？ | **不是**：参考那边同样只有测试读它（`live_core/test/sites/pandalive_api_test.dart:659`、`twitcasting_site_test.dart:129`、`live_danmaku/test/missevan_test.dart:716`），它是**给能力表自证用的读法**，不是生产分支。⇒ 我们缺的是那几条断言，不是这个 getter。 |
| 顶部条的控件在两臂里画齐没有（T21 的方法再走一遍） | 齐：`player_surface.dart:1456` 的非 identity 臂画 弹幕开关 + 集群(拆分档) + ⋮；`:1474` 的 identity 臂多画 返回/钟+电量(仅全屏)/房间名/直播或回放徽标/在线数（`:1519` 窄于 480 px 不收在线数）。in-page 不重复房间名与人数是**设计**（页头已有），不是漏。 |

| P47 | `a0b141e8f` | 进房测量补最疼的一档 | **走掉的那次进房以前一个字都不写**：`_teardown` 里 `_openTiming = null`，注释的理由是"观众没坐完的那段等待不该报"。但这条恰好把第 2 部分最想要的那档藏了：**什么也没失败、首帧也没来、只有观众放弃**——今天这种房间在日志里等于没发生过。现在离开时如果这条请求已经跑了 **≥3 s**（`kSlowEntryBudget`，就是"参考两三秒能开"这把尺子），照样写一行 `result=abandoned`；**低于 3 s 不写**，因为在列表里连点两下是浏览不是证据（这条判据同时挡住日志被刷）。abandoned 只进日志、不进详情面板（面板属于观众留下的那间房）。`RoomOpenTiming.line()` 的 result 从三档变四档（`error/playing/incomplete/abandoned`），新测试 1 例把它和"快点击不该被算成慢房间"钉在一起（`flutter test test/live/room_open_timing_test.dart` **8 绿**）。门：app `dart analyze lib test/live/room_open_timing_test.dart` 0 issues、`flutter test test/live` 62 例中 61 绿（唯一红仍是录像 lane）、`dart format` 只点三个文件且零重排。**这一条不解决慢，它解决"看不见"**：下次用户在慢房间点返回，就会留下 `detail/qualities/lines/request` 到第几段与 `total=` 的数字。 |

- **P44/P47 之后，第 2 部分仍然欠同一件事**：一次重建后的 `room-open` 行（现在连"观众中途走了"也会留下行）。没有 `request→opened` 与 `opened→firstFrame` 的实测数字，任何"再快一点"都还是猜。

## 第八次对照（2026-11-05）：弹幕行的手势、参考的排序尺子，和一条"有写没读"的第四例

| 查的东西 | 结果 |
| --- | --- |
| 参考 `ChatLineView` 的逐行手势（长按/右键 → 复制与屏蔽，**双击 = 复制**，`chat_list.dart:661-712`） | 前两样**我们有且更强**：每行包在 `DsContextMenuRegion` 里（`room_chat.dart:688/867`），按 desen_ui 的文档它吃 **右键 + 长按 + Shift+F10/上下文键 + 读屏"Show menu"**，条目是复制（带说话人名字）与屏蔽（掩码名不给屏蔽项）。**双击复制我们没有**——它只是省一步的便利，且会占掉竖屏"点一下叫回控制条"那一路的判读（T22/D-038 刚立过规矩），不擅自加。 |
| 参考 `ChatListStyle.compact/card`（同一行两种画法）与 `ChatSizing` | 我们有 `fontSize`/行距读设置、礼物/超聊走彩底横幅、普通消息是裸行（`room_chat.dart` 的注释就写着"保持直播聊天的密度"）⇒ **形态等价**，不搬它的 style 枚举。 |
| **`AudienceRankKey`（参考 `audience.dart:310`）我们确实没有** | 参考排序分档：明确并发数 > 待取的并发数 > 热度/累计兜底，理由是"**几百万热度不该压过几千真人**"。我们的排序读的是**卡片那个数**（`search_page.dart:565` `audienceFigureOf(...) ?? -1`），而且设置页那条 `audienceRankingNote` 明说了这个规则（"排序用卡片显示的数值"）⇒ **不是漏，是另一条已登记的取舍**：在 `metric=automatic` + `preferRealOnline` 开着时卡片数就是真实在线数，两条规则在那个档位会同意；不同意的只有"跟随平台 + 关了偏好"或手选热度那几档。要改成参考的分档，得同时改 `search_page.dart`（**搜索 lane 正在改这个文件**，本轮不动它）。⇒ 队列项，等那文件干净或由搜索 lane 一起收。 |

| P48 | `3243455ec` | 房间数字跟着直播走 | **第四例"有写没读"**（前三例：T20 只有读者没写者、P36 只有写者没读者、P46 搬了个 helper 没人调用）：`LiveAudienceUpdate` 有 **12+ 个生产者**（bilibili 心跳/`WATCHED_CHANGE`/operation_3、douyin、acfun、bigo、fc2live、baidulive、kuaishou、seventeenlive、steambroadcast 的编解码器都发 `LiveMessageType.audienceUpdate`，包侧 7 个平台的测试在钉它），app 侧**一个读者都没有** ⇒ 条上的在线数与详情页的三个数只在"页面重读 detail"时动；一间房开播期间涨了万人，屏幕上还是进房那一刻的数。现在 `audienceUpdate` 落到正在播的房间上（三种 kind 一对一写 `RoomAudience` 的三个字段），**与屏幕上已显示的数相同就不换 state**（这些几秒一条，每来一条就重建房间等于为没动的数字重画整页）；并且它不再进弹幕管线——管线本来就把空文本丢掉，同 retraction 的规矩。门：app `dart analyze lib` 0 issues、`flutter test test/live` 62 例中 61 绿（唯一红仍是录像 lane）、`dart format` 零重排、diff 只有我这 29 行。**未加测试**：全仓 app 测试树里没有任何 `RoomController` 的 harness（`grep -l roomControllerProvider apps/pure_live/test` 为空），为这 6 行现造一套是为本测试塑形；运行期请验：**开一间人气跳动的 bilibili 房，条上的数字与详情页的"人气/在线/累计"应在几秒内变，而不用等页面重读**。 |

## 第九次对照（2026-11-05）：第五例"有写没读"——超级弹幕的官方配色

普查方法照 P46（"谁生产、谁消费"两头数），这次数的是 `SuperChatDisplay`：

- **生产者 5 站 6 处**：`bilibili_danmaku_codec.dart:722`、`bilibili_room_parser.dart:359`（房间页那张 SC 板也带配色）、`douyu_stt_codec.dart:236,262`、`huya_danmaku_codec.dart:330`、`seventeenlive_danmaku_codec.dart`、`youtube_danmaku_codec.dart`。
- **消费者：0**。app 里 `display` 一个读者都没有 ⇒ 付费卡上那一条与超聊板用的是主题的 `colors.warning.tint` / `colors.accent` 梯度，**五站的红金配色全被丢掉**，B 站与斗鱼的 SC 看起来一模一样。
- 参考怎么画：它的**行**（`chat_list.dart:777`）用 `parsePlatformColor(backgroundColor) ?? tertiaryContainer` + `InkOnColor.on(...)`；它的**卡片**（`super_chats.dart:171-172`）用两个色做渐变，墨色按对比反推。它的解析器 `parsePlatformColor`（`chat_list.dart:1008`）只剥 `#` 再 `tryParse`，**别的什么都不校验**。

| P49 | `cf0b8d6c7` | 付费卡穿平台自己的颜色 | 新 `room/chat/paid_banner.dart`：`platformColor`（`#RRGGBB`/`#AARRGGBB`/裸 6 位；**名字、`rgb()`、截断串一律判否**，退回主题而不是涂成灰——这条比参考严，参考那把 `int.tryParse(hex...)` 会把 4 位串当数字吃进去）、`paidBanner`（行：填色取平台的色但向 surface 收到 22%、描边收 45%，所以色相在场、正文仍用主题墨色，浅/深主题都成立）、`paidBannerGradient`（超聊板：两色渐变，**权重仍由金额档位 0.05/0.10/0.16 决定**——参考的"按金额分级"和我们已有的"板子按价值读"两条规则都留住）。两处渲染面都接（行 + 板），不留半个读者。**故意不抄**参考的"满色 + 反推墨色"：我们的行里名字/徽章/时间戳各用自己的主题墨色，铺满饱和色会一处一处破；tint 路线让文字一条都不用改。新 `test/live/room_paid_banner_test.dart`（8 例：解析正反、tint 比原色淡但比 surface 深、描边比填色重、墨色在 fill 上仍 ≥4.5、权重随金额变、缺尾色=单色、缺顶色=交回调用方）。门：`dart analyze lib` 0 issues、`flutter test test/live/room_paid_banner_test.dart` **8 绿**、`flutter test test/live` 70 例中 69 绿（唯一红仍是录像 lane）。运行期未验：**要在一间有 B 站/斗鱼付费卡的房间看那条行与超聊页的卡片**（浅色与深色各一次）；若 tint 太淡看不出色相，把 `paidBanner` 的 0.78/0.55 调小即可，规则不用改。 |

- 提交纪律：第一版提交正文把生产者写成"六站（含 Kick）"——Kick 只是早前那次 socket 普查里出现过，本站**不产** `SuperChatDisplay`。**未推送前**改正并折进同一条提交（`--amend -- <我的三个路径>`，别人没在里面），已推送历史不改写。

## 探测预算实测（2026-11-05，第十次对照：P41 那张属性表到底还能不能再压）

第 2 部分欠的那次 `room-open` 还没等到（盘上最新日志仍停在 11-03，且早于 P34）。这一轮换了一条**不用等用户重跑**的测法：临时 `dart test` 用真适配器签一条**活着的 douyu FLV**，紧接着把它交给本机 `D:\ffmpeg\bin\ffmpeg.exe`（mpv 的 `demuxer-lavf-probesize/analyzeduration` 就是转成 ffmpeg 的 `-probesize/-analyzeduration`，所以这一段是同一把尺子），每档**重新签一条新地址**（同一条问两次读的是 CDN 的热路，数字就不是探测的代价了），跑 `-map 0 -t 1 -f null -`：

| 探测预算（probesize / analyzeduration） | 打开+取到第一秒画面 |
| --- | --- |
| ffmpeg 默认（5 MiB / 5 s） | **1202 ms** |
| **1 MiB / 1 s（P1 现在用的）** | **809 ms** |
| 128 KiB / 500 ms | 804 ms（并回 `Application provided invalid, non monotonically increasing dts`） |
| 64 KiB / 0 s | 535 ms |

- **结论：P1 的两个值停在曲线的拐点上，别再压。** 1202→809 的 393 ms 是**已经在场的收益**（早拿走了）；再往 128 KiB 只多 5 ms（噪声级），要再快只能 64 KiB/0，那 274 ms 拿的是**探测不足**的风险——FLV 里塞 HEVC/AV1、多节目、头部来得晚的流都会误判（绿屏、时长对分辨率不对、seek 坏），而这条判据不能靠 analyze 过门，得拿房间 `firstFrame` 做 A/B（P41 立的规矩）。⇒ **本轮不改引擎默认，零代码。**
- 顺带纠一条我自己在同一轮里产生的假象：第一次跑（未控温）里 `DEFAULTS` 报了"45 s 无应答"，看着像"默认预算会把直播卡死"。**那条不可复现**，同一间房重测默认档是 1202 ms；第一次那两跑撞上的是**过期地址与 fake-ip DNS**（bilibili 那两条 `-138` 就是打到 `v.smtcdns.net` 这条假地址上，见 [[reference-local-proxy-fakeip-diagnosis]]），不是探测的代价。⇒ 记下教训：**代理侧测出来的"挂了"先当环境问题，别当引擎结论**；控制手段是"每档重签一条 + 同一间房 + 有界等待"。
- 可复现的做法（下轮要测别的站直接照抄）：临时 `dart test` 里 `DioFactory(proxyPolicy: FixedProxyPolicy(global: HttpProxyRoute(host:'127.0.0.1', port:7890)))` → `createBuiltInLiveSites(http:)` → 取热门里 `broadcast.isLiveNow` 的第一间 → `getLines` → `Process.run('D:\ffmpeg\bin\ffmpeg.exe', [...预算, '-headers', 'k: v\r\n...', '-i', url, '-map','0','-t','1','-f','null','-'])`，`.timeout(45 s)` 包住；用完删文件（[[feedback-temp-tests-delete-after-verifying]]）。

## 第十一轮（2026-11-05）：第六例"有写没读"——平台自己的表情

`LiveMessage.emotes` 的生产者：**bilibili / chzzk / kuaishou / youtube** 四站（`LiveEmote.of(code:, url:)`；bilibili 两种形态——整条是一个贴纸 `code=text`，或正文里的 `[dog]` 内联码由 `extra.emots` 名单给出；chzzk 的码形如 `{:이모티콘:}`；kuaishou 是 `[…]`）。app 侧读者：**0**。聊天列一直只按飞行层那张打包图集切词（`room_chat.dart:1171 _wordSpans`），**图集不认识的表情就原样写着代码**，而参考的列表是拿平台的 `EmoteTable` 画的（`chat_list.dart` 的 `emotes` 参数）。

| P50 | `3d6a2029e` | 表情画出来 | 新 `room/chat/room_emotes.dart` 的纯函数 `splitPlatformEmotes(words, emotes)`（**只切正文里真出现的码**、去重取第一个可用 url、同处以长码优先、空 url/空码跳过），`_wordSpans` 把"图集没画到的那些段"交给它；平台表情用 `cachedImage(url, height:)` 在**该行自己的字号**上画（`_PlatformEmote`），**取不到图就退回文字原样**（`errorBuilder`），所以一条 CDN 挂掉的表情只损失那张贴纸、不损失那句话。**图集仍排在前面**：飞行层用的是同一张已解码的图，列表先吃它才不会为每个字发一次网络。两处**故意的边界**（不是遗漏）：①**飞行层不动**——`barrage_item_mapper` 在引擎侧，把平台 URL 塞进飞层要跨包加一条图片装载路，本轮不值；②`LiveMessageStyle`/`LiveMessagePlacement` 仍无人读：它们只服务**本地自绘弹幕**（用户自己发的那条），而全仓 `LiveDanmakuSending` 零实现者（见「发弹幕能力普查」）——**等第一个发送实现者出现再读**，别为没读者的字段做 UI。新 `test/live/room_emote_split_test.dart`（7 例）。门：app `dart analyze lib test/live` 0 issues、`flutter test test/live` **77 绿 + 1 红**（唯一红仍是录像 lane 的 `recording_schedule_test.dart`）。运行期未验：**要在 bilibili/chzzk/kuaishou/youtube 各看一条带平台表情的消息**——参考的判据是"看得到图，图挂了看得到原码"。 |

- 本轮也纠了自己两处口径：先写文档时说 chzzk 的码是 `/{name}`，读源码是 `{:…:}`（`chzzk_danmaku_codec.dart:166 _emojiCode`）；先写的测试用 `[哭笑]`/`[笑]` 举例"长码优先"，但那对码在文本里其实不会同时命中，改成真能重叠的 `[a]`/`[a]b`。**教训：写在注释里的"某站长这样"必须回源码取形状**，别按记忆里的平台习惯猜（同 [[feedback-settings-mirror-capability]] 的"字段名必须从源码取"）。

## 第十二轮（2026-11-05）：Bigo 点名了——不建中继，那就带原因失败

用户在别处已明确**拒绝回环中继**（[[project-pure-live-bigo-hls-relay]]："只能带原因失败"），本轮把那条决定落成代码，不再等点名。

- **此前的事实**：`BigoHlsProtection`（seed 读取 + 两段 TS 包头 XOR）**全包零调用者、零测试**——第七例"有写没读"。bigo 房的线路照旧交给 mpv，mpv 拿到的是加扰段 ⇒ 黑屏 + 转圈；录像订阅要是接上，写进盘的也是加扰包。
- **为什么不"先看一眼播放列表再决定"**：bigo 的播放地址**一次性**（`singleUse`，站方只发一次用的 URL）。为了判断加扰而去 GET 它，就是把那次机会花在判断上；不加扰的房间本来能播，也会被我们烧掉地址。⇒ 用一次多余请求换"可能有一间房不需要拒绝"，代价落在真能播的那批上，不划算。
- **改法（`01075c532`）**：`BigoPlaybackProvider.getLines` 直接 `left(LiveSiteError.unsupported(...))`，message 是一句中文原因（"Bigo 的网页直播流是逐段加密的（播放列表带 #EXT-X-BIGO-WEB-PROTECTION），本版不转码这段流，无法播放"）。**不动 getQualities**：直播中/有密码/付费/下线这些房间事实照旧报（下线仍是 content-unavailable），只是播不了。房间侧不用改：`pictureStateOf` 已把 `state.error` 当原因行显示（`room_status.dart:137`）。`LiveSiteError.unsupported.isTransient=false` ⇒ 上层不会自动重试。
- **删掉的死路**：`BigoSite.playPlaylist`（唯一调用者没了）与 `BigoStudioUse.input`（随之不可达）以及那句"play resolve 不再追问"的分支。**没删** `BigoHlsProtection`：它是"这房间为什么不能播"的根据，也是将来真要做还原时唯一已有的算法——本轮给它补了测试（seed 从 `VERSION=1,SEED=…` 的属性表里读、普通播放列表返回 null、transform 自反）。
- 门：live_sites `dart analyze lib test` 0 issues、`dart test` **475 全绿**（上一轮那条搜索 lane 的 `site_facts_test` 红已自消）；app `dart analyze lib` 0 issues。**运行期待验**：进一间 bigo 房，画面位应该直接说原因而不是黑屏转圈；录像订阅同样应带这个原因失败。
- **已知过窄之处**（写在这里，别当隐藏假设）：若哪天出现**不加扰**的 bigo 网页流，这条一律拒绝会把它一起拒了。到时候选的更细做法是：`getLines` 交回地址并在 `LivePlayLine` 上带一个"需要还原"的表达（P44 那节写过），由能转码的一方决定播或不播；**没有中继之前，这条拒绝仍是正确答案**。

## 第十三轮（2026-11-05）：欠账清掉一笔，两条"参考有我们没有"被实测否掉

| P52 | `2208ce785` | 档位记号补完 | 别的 lane 把 `player_surface.dart` 落地时顺手带走了我那两处 `displayLabel`（`git show HEAD:… \| grep -c displayLabel` = 2 ✓），所以欠账只剩多视图那两个显示位：`multiview_page.dart:1096`（每格的画质 chip）与 `:1101`（画质菜单条目）改用 `displayLabel` ⇒ 匿名要 1080P、平台答超清时，墙上那一格也不再替平台打保票。**身份不动**（`preferredQualityIndex` 仍按 `label`/`qualityId` 匹配，`room_controller.dart:1341`、`multiview_playback.dart:391` 都是匹配点不是显示位，逐处看过才改）。门：`dart analyze lib/modules/live/multiview` 0 issues、`flutter test test/live` 77 例中 76 绿（唯一红仍是录像 lane）。**踩到一次 format 越界**：`dart format` 把同一文件里别人旧的 `DsSegment(...)` 多行折成一行，已逐 hunk 还原后再提交（见 [[feedback-format-only-my-paths]]）。**⇒ 台账第 5 行的欠账已清，可以划掉。** |

## 两条没做的"参考有、我们没有"（实测为不需要，别再当缺口搬）

临时探针（`dart test` + 真 `createBuiltInLiveSites()`，走 7890；用完已删）：

1. **`stripInvisiblePlaceholders`（参考 `live_core/json.dart:59`，宣称快手标题留 U+FFFC）——不搬。** 探针扫了 32 站里所有有匿名热门的站共 **526 间房**的 title / anchor.name / notice，按参考那张字符表（U+0000-08、0B、0C、0E-1F、7F-9F、FFF9-FFFC、FFFE、FFFF）逐 rune 检查：**命中 0**。⇒ 我们的解析层没把这批字符带进显示文本（各站 parser 自己已过滤或数据本就没有）。为没观察到的缺陷加一层全局清洗，等于给每条标题多一次扫描 + 一个新失败模式，**不做**。未覆盖面：聊天正文（要开 30+ 个 socket，本轮没测）；若真出现"弹幕里一个方块"，再按该站那条消息定位，别提前搬整张表。
2. **参考的 21 条命名实体表（我们 `common/quality_label… 不，是 `common/normalization/html_entities.dart` 只有 14 条，缺 ensp/emsp/thinsp/ldquo/rdquo/lsquo/rsquo/yen/reg）——不补。** 同一批 526 间房里的这三类文本，用我们解码器自己的正则（`&([a-zA-Z][a-zA-Z0-9]{1,31});`）扫**残留引用**：**命中 0**。⇒ 要么平台不发，要么各站解码已过一遍；补那 8 条名字现在没有任何数据会走到，是"搬了没人读的表"（正是 P46/P50 那类债）。要补的时机是探针第一次真的扫到一个名字。

## 第十四轮（2026-11-05）：付费卡到了列表里已经不是它自己 —— 我上两轮的接线因此是空的

P49（平台自己的付费卡配色）与 P50（平台随消息给的表情）都从 `LiveMessage` 的字段读数据。本轮顺着"谁把消息交给列表"查下去，发现**聊天列看到的付费行根本不是平台那条消息**：

- `RoomDanmakuPipeline.accept()` 里只有礼物有专路，其他一律 `danmaku.acceptExternal(DanmakuMessage(type: chat, …))`；`_ChatMirrorSink.onDanmaku` 再把这条**重建**成 `LiveMessage.normalized(text/sender/color/messageId/sentAt/isLocal/replayed)`。⇒ `payload`（价格与配色）、`type == superChat`、`emotes` 三样都在这一来一回里没了。⇒ 房间侧那条"醒目留言 = 彩底横幅 + 价签"的分支（`room_chat.dart:838`）对管道来的消息**永远不成立**，平台配色（P49）和普通聊天的表情（P50）都是接了个拿不到数据的读者。
- 参考怎么分派（`live_play/logic/room_controller.dart:1219-1236`）：`chat` 才 `_flying.add(message)`；`superChat` 只进板子 + `chat.add(ChatLine.superChat(superChat))`，**不飞**；`online` → `_applyAudience`（= P48 的同一条判据，第二次对上了）。

| P53 | `239534233` | 付费卡与表情到底 | ①super chat 与礼物同路：在站侧分派处直接 `onChat(原消息)`（价格、配色、表情都在），屏蔽名单在这里也查一次（花钱不是回到观众清过的屏幕），并按 id 去重——平台在卡过期前每轮都会重发：有 id 就是**原地更新**（`replaceId`），没 id 就只画一次、重发丢掉。②普通聊天的表情不再指望重建：`accept()` 把 `emotes` 按 `messageId`（管道原样带过去的键）存住，镜像取用时**读一次即清**，映射有上限（400），不会因为房间跑几小时而涨。行为变化一处，和参考一致：**醒目留言不再飞过画面**（它以前以纯文本聊天飞）。门：app `dart analyze lib` 0 issues、`flutter test test/live` 77 例中 76 绿（唯一红仍是录像 lane）。无 harness 可测这段（全仓没有 `RoomController` 测试），**运行期请验**：bilibili/斗鱼/虎牙买一条 SC ⇒ 列表里应看到彩底 + 价签（若该平台给了配色，是它自己的颜色），且同一条购买不会越刷越多；bilibili 发一条带 `[dog]` 的普通聊天 ⇒ 列表里应是图。**注意 HEAD 里那 53 行是纯增量，验证是在"我的改动 + 别人在途改动"的工作副本上做的。** |

- **共享工作树的一课（技术活）**：`room_controller.dart` 本轮同时被另一条 lane 改（`SchedulerBinding` → 事件队列、`roomChatNoticeProvider` 清理若干处）。`git commit -- <文件>` 会把他们的 hunk 一起卷进去（`746fec785` 事故），不带 pathspec 的 `git commit` 又只会提交索引里已有的东西。做法：把 `git diff` 按 hunk 切开（awk），逐块判断归属，只把我的 6 块 `git apply --cached`，**提交前用 `git diff --cached | grep` 证明里面没有别人的关键字**（本轮：`scheduler|roomChatNoticeProvider` 命中 0），提交后再 `git diff` 确认他们那 5 块仍在未暂存区。索引只用于"选择提交内容"，工作树完全不动。

## 第十五轮（2026-11-05）：P53 只救了表情——被重建吃掉的其实是"谁在说话"

顺着 P53 再往下看一层：`_ChatMirrorSink` 用 `MessageSender.of(userId, userName, userLevel, fanBadgeLevel, fanBadgeName)` 重建聊天行，而 `MessageSender` 有 **10 个字段**。⇒ 管道过的每一条普通聊天都丢了 **头像、平台徽章、角色、名字色、会员档**（`membershipTier`）。列表那些画法（`room_chat.dart` 的 `_BadgeImage`/`roleInk`/`avatarUrl`/`_senderNameInk`）代码一直在，只是**喂不进去**——前几轮"逐控件对过持平"的结论看的是画法，没看数据通路。

| P54 | `34e527833` | 行认得出是谁 | 把 P53 的"只带表情"换成**带整条原始消息**：`_originals: Map<String, LiveMessage>`，键是管道原样带过去的 `_lineKey`（有平台 id 用 id，没有就用 `发送者\u0000文本`——正是 gate 自己判定同一条的那对）；镜像 `originalOf(key)` **读一次即删**（`Map.remove` 直接 tear-off），上限 400。房间自己合成的行（连接通知/过滤反馈）没有原件，仍走重建。礼物/付费卡不受影响（P53 起就在站侧分派处进列表）。门：app `dart analyze lib` 0 issues；`flutter test test/live` **77 绿**（唯一红仍是录像 lane；中途 `recorder_page_providers_test`/`room_bottom_panel_test` 报过"加载失败"，单跑各自全绿——是别的 lane 正在写文件的瞬时态，别当真红）。运行期请验：任一 bilibili/斗鱼房，普通观众行应有头像与平台徽章、房管/主播行有角色色，名字色与平台给的一致。 |

- **与另一条 lane 的冲突，本轮只报告不动手**：`room_controller.dart` 现在带着别人的在途改动——`live_site_ingest.dart`（未跟踪）、`_ingest` 启停、`LiveSiteRuntimeInfo` 上"这站要 ingest"的标志、以及 `resolved.lines` 那段取线重写的 hunk。**他们做的正是 Bigo 的逐段 XOR 还原通道**，而 P51（`01075c532`）把 `BigoPlaybackProvider.getLines` 直接判成 `unsupported` ⇒ 中继拿不到地址。用户当时的原话是"我要的是播放器能正常识别的地址，别瞎改"、并拒绝回环中继（[[project-pure-live-bigo-hls-relay]]）；如果那条 lane 的 ingest 就是"修出播放器能认的地址"的那一步，**P51 的无条件拒绝要改成"没有还原通道时才拒绝"**——但那是 bigo/ingest 那条线的决定，本轮不抢改，等它落地或由用户点名。

## 第十六轮（2026-11-05）：底条的"宽档才有"动词，逐个找第二个入口

第 1/3 部分的控件普查上次做在顶部条（T21 就是这么抓出来的），这次做底条。判据：**`_ControlBar` 里每个 `if (wide)`（≥720 px）的动词，在窄窗/手机上必须有第二个入口**，否则那台设备根本没有这个能力。

| 底条 wide-only 动词 | 第二个入口 | 结论 |
| --- | --- | --- |
| 截图 `DsIcons.camera` | 房间菜单 `t.room.screenshot`（按 `canCaptureScreenshot` 门控） | 齐 |
| 音量滑杆 | **静音按钮在所有宽度都在**，滚动/手势调音量在桌面上另有路 | 齐（滑杆本身不是唯一入口） |
| 录制指示（RecordingIndicator） | 顶部条的 `_PresentationCluster` 两臂都画（P28/P31） | 齐 |
| 小窗 / 投屏 | 同上，strip 的 cluster + 菜单 `pipOn/Off`、`cast` | 齐 |
| 窗口全屏 `rectangleHorizontal` | 无（仅桌面且 wide）——但窗口可拉宽，且 `fullscreen`（沉浸）在任何宽度都有 | **不动**，理由记这条 |
| 竖屏全屏 `rectangleVertical` | 移动端在竖屏布局里有拇指按钮（`room_page.dart:966-971`）；桌面窄窗没有 | **不动**：桌面窄窗=可拉宽，代价低于给一个能拉宽的窗口再加一行 |
| **音频模式 `headphones`** | **没有**。`setAudioOnly` 只有底条 wide 档一个入口，菜单 24 行里也没有 | ⇒ **P55** |

| P55 | `9e1a470d6` | 手机能切音频模式 | 房间菜单在"画面能做的事"那一组里加一行（截图行之后）：`t.room.audioOnlyMode` / `t.room.restoreVideo` 现成两串（底条在用），`checked: room.audioOnly`，动词 `ref.read(roomProvider.notifier).setAudioOnly`。**不需要门控**：`setAudioOnly` 在没有 handle 时只记状态（`room_controller.dart:1119-1130`），不会挂一个打不开的门。为什么值得做：应用自己在房间进后台时会自动切到这个模式（`room_page.dart:523-532`），却给用手机看直播的人留了唯一一条不能主动选它的路——而省流量/省电恰恰是手机上最需要的。**零新串**（l10n 仍属别的 lane 在飞的树，没跑 slang）。门：`dart analyze lib/modules/live/room` 0 issues；**提交用的是"hunk 切分 + `git apply --cached`"**（`room_page.dart` 当时带着另一条 lane 的 SchedulerBinding→`_writeAfterFrame` 重构 4 个 hunk，他们的改动原样留在工作树）。运行期未验：手机上开房间 → ⋮ 里应有"音频模式"，点了画面停、声音继续；桌面宽窗仍然只有底条那一枚（一行一个入口）。 |

## 第十七轮（2026-11-05）：四道护栏跑在 HEAD 上，清掉我那批积压提交欠下的两条

第 1/3/4 部分的普查方向本轮没有新洞（见下面"模型字段普查见底"），于是把这轮花在**验证门本身**：今早 09:41–09:46 那批"按主题拆分"的积压提交把两道护栏弄红过，我在 HEAD 上重跑并归属。判据是同一命令在两个提交上的差：`2bec9260a`（09:35，批次之前）= IA 绿 / manifest 7 条，`16bed7c8c`（批次之后）= IA 2 条 / manifest 8 条 ⇒ 批次净增 3 条，其中 2 条属我。

| 护栏，跑在 `git worktree add --detach ../pl-guard-head` 的 HEAD 上 | 本轮结束时 |
| --- | --- |
| `check_architecture.ps1` | Architecture checks passed |
| `check_responsive.ps1` | responsive layout gate passed |
| `check_settings_ia.ps1` | settings IA gate passed（404 hits，本轮由 406 并成 404） |
| `check_prefs_manifest.ps1` | 7 条，与批次之前同数 ⇒ 我这两笔还清；逐条归属见下 |

| P56 | `899b12877` | 搜索排除的平台能过备份、也能被别的窗口叫醒 | `5bdf4c654`（feat(search): align live search with the reference，我提的）把排除平台集写进 `search.allExcluded` 却没登记 ⇒ 备份丢这个选择、恢复或另一窗口写入后 `searchExcludedProvider` 仍持旧值。两处：`kBackedUpPrefs` 加 `('search.allExcluded', BackupPrefKind.string)`（**它是 controller 自己 `jsonEncode` 的一枚字符串，不是 `stringList`**，注释写进表里防下轮改错档），`kSettingsProviders` 加 `searchExcludedProvider`。**提交用的是 hunk 切分**：`settings_refresh.dart` 正被另一条 lane 改（`refreshSettings`/`refreshSettingsFromWidget` 的 post-frame 重构，36 增 8 删），我从 `git show HEAD:<path>` 出发只插我那两行、`git apply --cached` 后不带 pathspec 提交；提交后 `git diff --stat` 仍是 36/8，他们的 hunk 一字未动。`search.dart` barrel 不导出 `search_scope.dart`，所以按该文件里别的单符号 import 的写法直接 `show searchExcludedProvider`，没有为了两行去动模块 barrel。门：`dart analyze` 这两个文件 0 issues，manifest 门禁里我那两条归零。 |
| P57 | `be1913c9e` | 局域网同步在设置搜索里只剩一行，和它自己画的那一行一致 | IA 门禁报 `lanSyncPaired`/`lanSyncNearby` 两枚命中"打开 LanSyncPane，但那一页渲染的文件里没有这两个词"。真因：`lan_sync_pane.dart:230-243` 把**已配对**与**附近**两类行放进同一个 `DsListSection`，段头是 `lanSyncDevices`，而目录仍按旧的"两个分节"登记三行 ⇒ 前两枚是幽灵行，搜"已配对"的人被许诺了一个页面上不存在的段。**修法选了目录侧**（一行 `_hit`，把两段的词并进 keywords）而不是给别人的页面重新加分节段头：那是音乐/局域网 lane 的版式决定，而"一行只说一次"这条量规在目录侧同样成立。副作用如实记：`lanSyncPaired`/`lanSyncNearby` 两串现在零消费者，**删它们要跑 slang，而 `lib/l10n` 是别人的在飞树 ⇒ 本轮没删**。门：`check_settings_ia.ps1` 在工作树与 HEAD 上都是 passed；`dart analyze` 该文件 0 issues；`dart format` 0 changed。 |

**剩下 7 条 manifest 红灯的归属与证据（都不是直播间的活，下轮别重新解剖）**
- **录像 2 条＝判据本身看不见 helper**：`recorder.pollingEnabled`/`autoStartOnBoot` 报"declares boolean while the call sites speak string"。实际写只有 `_write('recorder.pollingEnabled', value)`（`recording_settings.dart:506-510`、`:528-532`、恢复路径 `:737,:741`），`_write(String key, Object value)` 按运行期类型分派到 `setBool`；全仓没有这两枚键的 `setString`。**是 `tool/check_prefs_manifest.ps1` 的键↔档推断穿不过这两个 helper**，而 `tool/` 是禁区 ⇒ 不动判据。
- 顺带量到一个真现象（录像 lane 自己在飞的方向，`10cf6c572` 把节奏挪到每间房之后）：`build()`（`recording_settings.dart:304-345`）重建 `RecordingScheduleSettings` 时**不读**这两枚键，注释写明"设计上就是开"；而调用方 `recorder_page.dart:176`、`room_page.dart:1786` 只把 setter 当"打开检测"的命令用、只写真 ⇒ 盘上的值恒为 `true`，恢复路径却会把旧文档里的 `false` 写回 state，重启又被默认 `true` 盖掉。这是"只写不读"的键，不是备份档的档别问题；改法（删键、或补 `_storedBool` 读回）归录像 lane，且 `recorder_page.dart` 在禁区里。
- **点播 5 条**：`vod.app.accessKey`/`deviceId`/`mid` 是**登录态**，按 manifest 自己的文档和判据里 `$unbackedAllowed` 的先例（`check_prefs_manifest.ps1:353-368`，`hongguo.account.credentials`="登录 cookie 不进备份文档"）该走"故意不备份"名单，而那份名单在 `tool/` 里 ⇒ 不动；`vod.playback.apiType` 确实是普通偏好、该注册，但只注册它一枚会把另外三枚继续挂着红灯，而"点播 API 选择要不要跨机器走"是点播 lane 的决定 ⇒ 报，不改。`vodAppSessionProvider` 缺失效同理（它持的就是那三枚凭据的会话）。

**模型字段普查见底（第四部分的一个方向可以关掉了）**：脚本对 `models/{message,gift,super_chat,anchor,audience,room,play}/*/*.dart` 逐类抽 `final <type> <name>;`，再数 `apps/pure_live/lib`（排除 `.g.dart`）里的 `\.name\b` 读者数与 `platforms/**` 里的 `name:` 生产者数。结果：**零读者且站侧有生产者的字段已经清零**，只剩 `LiveDanmakuStyle` 两枚 `fixedDurationMs`/`shadowOffset`——它们**生产者也是 0**，属于"样式接口留了口子没人用"，不是数据通路断。⇒ "谁生产谁消费"这条线在模型层到此为止；下轮要再找洞得换方向（装配点、显示位、参考的算法），别重跑这个普查。

**更正第十五轮的一处措辞**：那一轮写"重建丢了头像、平台徽章、角色、名字色、**会员档（`membershipTier`）**"。前四项成立，`membershipTier` **不成立**：本轮普查 `packages/live_sites/lib/src/platforms/**` 里没有任何站点传过它（`MessageSender.normalized/of` 的这枚参数零调用），应用侧也零读者，只有 `message_sender.dart:17,36,48,68,79,121` 的声明与文档。所以那条字段从来没被丢掉过，谈不上"喂不进去"；参考侧同样只在 `GUARD_BUY` 礼物上带 `guardLevel`，发送者身上没有档。P54 的修复本身不受影响。

**Bigo 那条冲突本轮复核过，仍未变**：`packages/live_sites/lib/src/core/live_site_ingest.dart` 与 `live_site_runtime_info.dart` 还是未跟踪/在飞（连同 `bigo_site.dart`、`bigo_playback_provider.dart`、`core.dart`、`site_facts.dart`、`test/platforms/bigo/bigo_test.dart`、`docs/live-sites-parity.md`、app 的 `room_controller.dart`、`room_page.dart`、`stream_resolver.dart`、`player.dart`、`player/live_ingest.dart`、`pubspec.yaml`、各端 plugin registrant 与 `pubspec.lock`），所以 P51（`01075c532`）那一刀切的 `unsupported` 在 **HEAD 上仍然成立**（第十八轮复核：`git show HEAD:` 那行还在），而**工作树里他们已把它换成 recipe 通道**（`runtimeInfo.ingest` + `media_core_ingest` 的环回还原，与用户 11-05"要播放器能正常识别的地址、别自己瞎改"的决定并不冲突——那是站点声明需求、通用执行层做钩子）。⇒ 本轮**没有**碰 bigo 的任何文件，也没跑 `slang`/`build_runner`；等他们入库后由他们决定 P51 的收法。

## 第十八轮（2026-11-05）：恢复重取地址时，观众选的那条线路被丢掉了（第 2 部分）

盘上的运行证据（`%APPDATA%\com.purelive\pure_live\debug\data\logs\2026-11-03\PureLive.log`，`attaching engine mpv for …` 带 `{line: N}`）：同一条 douyu 地址在 09:11:44.633 与 09:11:53.042 各 attach 一次都是 `line: 0`；YY 房间 10:26:21→10:32:20 七次 attach 全部 `line: 0`（地址的 serial 每次重取都在换），最后一次 `live sweep exhausted {sources: 1, enginesTried: 1}`。⇒ 恢复路径每次从头一条开始，这与"进房慢"不同，是**卡一下之后回不到我选的那条**。

参考的做法（`live_player/lib/src/session.dart`）：`_matching()`（`:1237`）用 `lineKey = line.lineId ?? line.url`（CDN 码，重签名不变）把"正在放的这条"映射进新 plan，attempt 0 就重开它；只有再失败一次才 `markFailed` + `next()` 换下一条（`:1298`、`:1370`），并且每个 retry round `_lines.reset()`。我们的 `_refreshSourcesForRecovery` 把刷新后的列表**写死从 index 0 开始**（原注释自己就矛盾："the engine-switch resume point follows it, having been the line the user was watching"——`_sweepStart` 被同一行归零了）。

| P58 | `media_core a85c0b6` | 恢复不换线路 | **线路身份用 host+path**：签名单次有效、每次重取都变，而 host+path 正是"哪条 CDN"这件事本身（`_lineAddress()` 已经是这个形状，日志也用它）。刷新回来后按它找那条线路，找到就从它继续（`_sourceIndex`/`_sweepStart` 一起跟上），找不到才回 0——**只改顺序、从不拒绝播放**，所以不会新挂一扇打不开的门。app 侧不用改：`room_controller.dart:1579` 本来就把 `_playback.sourceIndex` 镜像进 `state.lineIndex`，修完之后那条镜像不再骗人。**外部仓，按规矩只本地提交、不推送。** |
| 测试 | 同上 | 新增一条会咬人的用例 | `live_playback_controller_test.dart` 的 `recovery source refresh` 组里加"观众选的线路活过一次重排计划的刷新"：两条线路、`switchLine(1)`、恢复解析回 `{primary, backup}`（backup 在 index 1），断言 `sourceIndex == 1` 且引擎最后开的是 `cdn-backup.example`。**自证**：把 lib 改动还原后同一条测试 = `Expected: <1> Actual: <0>`；改回来后 `flutter test` 整包 **57 绿**。判据本身：`dart analyze lib test` 0 issues。 |

**这轮的提交坑（同文件混着别人的 hunk，第三次遇到）**：`live_playback_sweep.dart` 里躺着另一条 lane 未提交的 22/7 行日志改动，media_core 整仓 **91 个文件在飞**（`packages/media_core/lib/**` 大范围重构、`live_playback_pipeline.dart`、`live_watchdog_arms.dart`）。做法仍是 hunk 切分：`git show HEAD:<path>` 起底 → 只把我的那段替换进去 → `git apply --cached` → 索引里确认只有我的两个路径 → `git commit`（不带 pathspec）。提交后他们的 hunk 原样在工作树（`git diff --stat` 从 41/13 变 22/7）。还原/复原全程用仓外副本 `/d/flutter/_sweep.keep` 的 md5（`0612869b0a989b0f8cdec7d88b03998e`）核对，逐字节一致。

**查过但判定不搬的两条（别再当缺口重开）**
- `live_core/lib/src/hls_source_query_policy.dart`（87 行）：参考**自己的站点零调用**（全仓只有 live_media 的管道参数和它自己的测试在传）。它描述的是"某个 provider 会把 master 的 `token` 手动加到子请求"这件事，不是通用 HLS 规则——没有观测到的站点，就没有要接的东西。
- `live_media/lib/src/fallback.dart` 的 `DecoderFallback`（硬件解码失败后换 `hwdec=no`，参考确有消费者 `session.dart:183`）：我们把解码档做成了**观众的设置**（`playback.hwdec`、`effectivePlayerHardwareDecoder()`、preset 的 `lockedOutputKeys`）再加引擎间兜底；自动换档会覆盖一个人明确选过的解码方式，还会让"为什么这次是软解"变成设置里读不出来的事 ⇒ 记为有意差异，不改。
- `LineFallback` 的失败线路记忆（markFailed 只在 attempt>0 生效）：我们一次 `_sweep` 本来就把每条线路走完，记忆只影响"跨恢复任务的第一条试谁"，代价是一条候选的验证预算 ⇒ 等下一次有 `room-open`/`recovery` 的重建运行数据再判，别先写。

## 第十九轮（2026-11-05）：弹幕解码器一个测试都没有（第 4 部分，先给最忙的那条线钉住）

普查 `packages/live_sites/test/**`：**站点测试全部只覆盖播放地址/画质/目录，弹幕解码器零直接测试**（有 `decode(` 的 `danmaku/*.dart` 共 20 个文件，测试数 0）（唯一沾弹幕的测试是 `danmaku_text_shape_test.dart`，那是过滤器的字形归一）。参考侧 `live_danmaku/test/sites/` 有 **20 个站点测试文件**。⇒ "逐文件 diff 过 9 个过滤器族"从来不含**线格式**：包帧、认证体、压缩层、cmd 分派，这些正是"进房后弹幕一条都不出"会藏的地方。

| P59 | `443003128` | bilibili 的弹幕线格式被测试钉住 | 新增 `packages/live_sites/test/platforms/bilibili/bilibili_danmaku_test.dart`，**25 条**，从"我们往socket写什么"与"我们读出什么"两侧钉：头 16 字节（大端、version 0、sequence 1、心跳的 base64 逐字节）、auth 体的**键序**与 `protover 3`、`queue_uuid` 八位小写十六进制且 20 个种子互不重复、只有 `p_is_ack` 为真且 `msg_id`/`cmd`/整型 `p_msg_type` 齐了才回执（六种缺法都不回）、`**`/`＊＊` 才算打码名；解侧钉：包序、**故障前已到的条目要留下**（零长包与尾随字节两种）、超 `maxMessageBytes`/超 `maxPackets`/超 `maxInflatedBytes`/超过两层嵌套四种都有 `FormatException` 而不是崩溃、zlib 与 brotli（protover 3，含 brotli 套 zlib）都能解、op 3 人气与 op 8 认证码、`DANMU_MSG` 的 who/colour/时间戳（毫秒与秒两种）/dmid、`RECALL_DANMU_MSG` **不是聊天行**（它的 cmd 里就含 `DANMU_MSG`，且 uid 0 的撤回必须整条丢掉）、`WATCHED_CHANGE`/`ONLINE_RANK_COUNT` 走 audience、`GUARD_BUY` 是 subscription 礼物且档位名缺了也有名字、`SUPER_CHAT_MESSAGE` 带价与两条官方色、`SUPER_CHAT_MESSAGE_DELETE` 逐条撤回、`WARNING`/`CUT_OFF` 成系统条、未知 cmd 与非 JSON 只跳过不算错。 |

**结果要说实话**：这 25 条**没有测出解码器的错**（全绿）——它的价值是线格式从此有钉，改协议常量（比如 `protocolVersion`、`maxNesting`）会当场红，而参考能逐个站点做对照的只剩测试这一维。`dart test`（纯 Dart 包，不是 flutter test）整包 **500 绿**（原 475）。

**下一轮接着钉的顺序**（按弹幕量，别一次开 20 个）：huya（`huya_danmaku_codec.dart` + `huya_tars.dart`，fixture 要自己用 TARS 写）、kuaishou、douyin、yy（`yy_packet.dart`）、twitch——douyu 已在第二十轮钉住（P60）。判据同本轮：`dart analyze test/platforms/<site>` 0 issues + `dart test test/platforms/<site>`。

**写站点测试的一个坑（本轮踩了一次）**：只 import 平台 codec 文件不会把 `LiveMessage` 的成员名带进来——`effectiveSender`/`effectiveColor` 这类模型 getter 必须**直接 import 模型文件**（`src/models/message/live_message/live_message.dart`），否则 analyzer 报 "getter isn't defined for the type LiveMessage"，看着像模型坏了。另外 `LiveMessageType` 里那一档叫 **`audienceUpdate`**，不是 `audience`。

## 第二十轮（2026-11-05）：斗鱼的 STT 线格式钉住，顺手掉一个空转三元

按上一轮给的顺序做第二个站点。`packages/live_sites/test/platforms/douyu/douyu_danmaku_test.dart` 新增 **20 条**，`dart test test/platforms/douyu` **38 绿**（原 18），整包 `dart test` **520 绿**（原 500）。钉住：转义一层一个 `@A`/`@S`、浅读只解一层（**内层留成文本**）、map 的"无键段跳过/后到的重复键赢"、list 丢空段、包体是**小端双长度**+ type 689 + 两个标志位 + 结尾 `\0`（长度不含自己那 4 字节）、进房两包（loginreq → joingroup gid −9999）、心跳 `mrkl/`、尾巴坏掉是**丢弃而不是硬解**；显示侧钉：聊天的等级/粉丝牌（`bnn` 为空时 `bl` 不算牌）/六种官方色表/秒与毫秒两种时间戳/别的房间与空文本不落列表、**疑似机器人规则逐条重读**（中途改设置立刻生效）、一条抛异常的包**不吞掉同帧后面的包**、`rss` 停帧且只对**这间房**停、付费消息的 `cprice` 是分（`￥20`、时长 60 s、官方两色）、礼物（目录价与图、不认识的礼物只留名字、`gfcnt` 0 也算 1 个、`hits` 进 combo 且 comboKey 是 `uid:gfid`、`gpf=1` 或 `gfid=0+pid` 是背包免费、别的房间与无名字不给）。提交 `594ccb64b`。

| P60 | `594ccb64b` | 斗鱼的 STT 线格式被钉住（20 条），并去掉一处空转三元 | 见本节四条：fixture 的四个初判失败全是我的写法错（小端双长度、转义结果少算、超 int64 的 `cst` 是 null 不是抛、语音包嵌套层数）；真收获是 `toLiveGift` 的 `kind: free ? normal : normal`（免费与付费本来就由 `value.unit` 带，分层规则读的就是它）；`voice_trlt` 有意不钉，等真帧。 |

- **本轮 4 条初判失败全是我 fixture 自己错，不是解码器的错**（如实记，免得下轮误以为挖到 bug）：① 长度字段是小端，我按大端写了 `[0,0,0,19]`；② `escape('a@b/c')` 的结果我少算了结尾字符；③ `cst@=999999999999999999999` 超 int64，`int.tryParse` 给 **null 而不是抛**，要拿"能解析但超 `DateTime` 范围"的值（`9007199254740992`）才测得到那条 catch；④ `voice_trlt` 的嵌套转义我猜错层数。
- **真收获是一处空转代码**：`toLiveGift` 里 `kind: free ? LiveGiftKind.normal : LiveGiftKind.normal`（`douyu_gift_parser.dart:213`）。`LiveGiftKind` 只有 `normal/subscription/tip`，免费与付费的差别本来就由 `value.unit`（`free`/`other`/`fen`）带着，而那正是分层规则读的东西（`gift_chat_filter.dart:67`、`gift_flights.dart:137`）；参考侧的斗鱼根本不带 `kind`（走模型默认）。⇒ 删掉那行与它的 import，行为不变（本轮的礼物测试钉着 `value.unit`）。
- **有意没钉的**：`voice_trlt`（语音付费消息）。它的 `list` 与 `uat` 是**三层转义**，而本仓与参考**都没有一条真包样本** ⇒ 写出来只会把测试钉在我的猜测上。要在钉它，先抓一条真帧（进语音付费房抓 socket 或加临时日志），别先写。
- **队列更新**：还剩 **huya**（要先用 `huya_tars.dart` 造 TARS fixture，最贵的一条）、kuaishou、douyin、yy（`yy_packet.dart`）、twitch。bilibili 与 douyu 已钉。

## 第二十一轮（2026-11-05）：先拉参考，然后把 5.6.3/5.6.4 的更新内容逐条对照到我们仓

本轮起用户加了两个要求：**先 `git pull` 参考仓**，再**按更新内容优化我们的项目**。拉取结果（`E:\study\Pure_live`，master，工作树干净，`git pull --ff-only`）：`8743e5a6e..f00bebd91` 四个提交，改的只有 `assets/releases.json`（+202 行）与 `assets/version.json`（60 行改写）。

> **这条线以后必须先分清的两件事**：这个克隆的**源码仍是 5.6.2**。全仓 grep `只看彩色`、`最低用户等级`、`向上滚动` **零命中**，`soop_site.dart:344` 也还只发一次 assign。⇒ 5.6.3/5.6.4 的条目是**需求清单**，不是"参考已有代码可对照"。照抄无从抄，照描述硬写就是编（[[feedback-no-line-number-patching-of-source]]、"你咋瞎改呢"那次）。

逐条对照（更新条目 → 我们现在的状态，带证据 → 结论）：

| 更新条目（版本/issue） | 我们的状态（证据） | 结论 |
| --- | --- | --- |
| 小红书"首次弹幕初始化与视频打开同时启动"（5.6.4 #177） | **已经是这样做**：`room_controller.dart:940-948` 弹幕是 `unawaited(_openDanmaku(...))`，注释写明"一次握手独吞 10 s 预算，await 它会让观众干等首帧"；回放/无聊天平台走 `RoomChatStatus.unsupported` | 持平，别再当提速项重开 |
| SOOP 多官方 CDN 线路、去重、部分失败保留、限并发与等待、修 assign 不结束响应（#195） | 我们 `soop_site.linesOf` **返回 1 条**（`soop_site.dart:368-387`：一次 assign + 一次 key），用房间答案里那一个 `CDN`；**参考 5.6.2 同样只发一次** | 两边都只有一条 ⇒ 不是"参考有我们没有"。要加线路，先探一个真在播的 SOOP 房看平台到底回不回多个 CDN（`#EXT`/`CDN` 列表），**别按说明硬造多线路** |
| SOOP 公开直播回放（分段、画质、本地分段进度）（#196） | 我们 soop 目录里没有任何回放能力（grep `replay\|archive` 只命中注释） | 缺；被"端点证据"挡住 ⇒ 浏览器网络面板抓一个 SOOP 回放页（[[feedback-dead-endpoint-use-browser-panel]]）再动 |
| 抖音礼物消息与连击总量、快手保留接口给的礼物文字、缺的元数据保持未知（#192） | `douyin_danmaku_codec.dart:35` 明写"gifts…are not read"；`kuaishou_danmaku_codec.dart:61` 明写该协议无礼物行 | 缺；**要 protobuf 字段号证据**（进真房抓一条礼物报文），照 changelog 编字段号不做 |
| 网易CC 原生游客文字弹幕与在线人数、按主播过滤礼物（#198） | 我们 **2026-11-05 已删 CC**（站点队列 32 站） | 不适用 |
| 竖屏全屏弹幕新增"左下角向上滚动"布局，设置可选、默认保留横向（#193） | 我们竖屏全屏只有飞行层 + 窄窗三停靠点面板（P22），弹幕样式页没有这一档 | 缺（真功能）。落点是 `room_page.dart`（**正被 ingest lane 改**）+ 样式设置页 + 新串（`lib/l10n` 也在别人手里）⇒ 三桩都占，本轮不抢 |
| 回放列表接近底部自动续加载 + 标题/主播关键词搜索 + 今天/昨天/3/7/30/90/一年/自定义日期（5.6.4 第二条） | 我们的直播回放清单在 `room/player/room_playlist.dart`（**该文件在飞**）；日期档与搜索是否齐备本轮没量 | 待查（等文件空出来再对照，别在别人的在途版面上加行） |
| 屏蔽管理新增"只看彩色/最低用户等级/最低粉丝牌等级"（默认不限），六类过滤计入本场数量，同一传输重包不重复计数，平台未给等级不猜 0（5.6.3 #181） | 我们已有：屏蔽用户/关键词/重复/相似/斗鱼疑似机器人 + 「本场已屏蔽 N 条」（`onShielded`）；`MessageSender.userLevel` 是 `String?`（**没给就是没给**，这条的默认行为我们已经对） | 缺三档过滤。过滤判定在 `RoomDanmakuPipeline`（**在 `room_controller.dart` 里，在飞**），设置行在 `danmaku_filter_settings.dart`（干净）——**只加设置行 = 挂一扇打不开的门**（[[feedback-no-doors-that-open-walls]]）⇒ 一起等 |
| 宽屏：聊天收放按钮贴聊天列边界；视频下方常驻信息栏（人数/开播时长/画质/线路）（5.6.3 #180） | 我们宽屏的收放按钮在画面右上（`room_page.dart:1139-1159`，`end: s8`），不贴列边界；人数/画质/线路在 stats overlay 与条上，没有"视频下方常驻栏"这一形态 | 缺（形态差异）。落点 `room_page.dart`（在飞） |
| 横屏/宽屏侧面板点外侧可关闭，且关闭点击不穿透到播放/切台/退出全屏（5.6.4 #202） | 我们**没有** outside-tap 关闭；不穿透这件事靠路由自带透明不可关闭 ModalBarrier + PageSurface 吃指针（[[project-pure-live-page-surface]]），但面板本身没有点外侧的动作 | 缺。落点 `room_page.dart`（在飞） |
| 画面方向与竖屏全屏画面模式统一成"和画质/线路一样的紧凑菜单"，选中即生效；长按/悬停看说明（5.6.3 第五条） | 我们的紧凑菜单形态在 `player_surface.dart` 的 streamPickers（**干净文件**），但画面模式选择行在 room_page 的 strip/⋮（在飞） | 缺（统一形态）。要动的是在飞那半边 |
| Android 小窗绕过"离开应用自动小窗"、任务移除清理、PiP 接收器泄漏、重复音频状态写入、缓存清理（#194）；平板自定义壁纸下统一侧栏/顶栏表面与安全区（#200）；移动数据提醒持久开关（#182）；小红书游客分类/推荐/分页与独立原生连接（#177-K） | 前三项属 App 壳/背景/流量 lane（[[project-pure-live-app-shell-unified]]、[[project-pure-live-background-tone]] 的车主），最后一项我们 xiaohongshu **没有 danmaku 目录**（`ls platforms/xiaohongshu/*/` 只有 api/capabilities/parsers）⇒ 游客聊天根本没有 | 归属别的 lane 或需要协议证据；本报告点名，不动手 |

**本轮落了唯一不需要新证据的那一半（P61：SOOP 请求的等待上限）**。其余能对照出"缺"的条目，落点全在两条在飞车道手里（`room_page.dart`、`room_controller.dart`、`room_playlist.dart`、`lib/l10n`），或需要先拿到平台协议证据（SOOP 多线路/SOOP 回放/抖音礼物/小红书弹幕）。按 [[feedback-shared-workspace-commit-by-pathspec]] 与"参考有代码才抄、没代码别编"这两条，本轮把**清单和判据**落成台账，把四项**可独立开工**的排在前面：

1. **小红书游客弹幕**（#177-K）：站点侧新能力，干净目录（`platforms/xiaohongshu/danmaku/` 还没有），要的是浏览器网络面板一次抓取。做完能同时补上第 4 部分的一条真缺口，并给我们第十九/二十轮那种"线格式钉住"的测试落点。
2. **SOOP 多 CDN 线路 + assign 超时**（#195）：探针先行，确认平台回多个 CDN 才动；顺带把"分配接口不结束响应"的超时上限接进 `soop_http.dart`（这条**不依赖多线路**，是独立可证的修复）。
3. **抖音礼物与连击**（#192）：需要一条真礼物报文。
4. **竖屏左下角向上滚动弹幕**（#193）：等 `room_page.dart` 空出来再做，一次做三层（版式 + 设置行 + 串）。

其中第 2 项的**独立可证那一半已经落了**（它不需要多线路证据）：
| P61 | `37ffd7e71` | SOOP 的 assign/key 不再无限等 | `SoopHttp` 的两个请求原来都不带 `timeout`，`LiveRequest.timeout` 为 null 就是交回 Dio 的默认（我们 `dio_http.dart:191-198` 的 `BaseOptions` 没设任何 timeout）⇒ 平台那条"分配接口迟迟不结束响应"的路径在我们这变成**永远转圈**。现在两路都带 `SoopEndpoints.requestTimeout = 20 s`（与同仓 fc2live 的 `requestTimeout` 同值，不是我另起的数），失败就是普通 `SoopFailure(network)`，房间念得出来、`SoopPlayRecovery` 也能重取。**多 CDN 线路那半仍未做**：要先探一个真在播的 SOOP 房确认平台回不回多个 `CDN`，别照 changelog 造。测试 +1（假 `LiveHttp` 记下每个请求，断言 `timeout` 带着；不带就是 null，这条会红）。门：`dart analyze lib/src/platforms/soop test/platforms/soop` 0 issues，`dart test test/platforms/soop` **16 绿**，整包 **521 绿**。 |
| 本轮自己犯的老毛病（记下来防再犯） | 同上 | 我对整个 `lib/src/platforms/soop` 目录跑了 `dart format`，于是把**别人已入库**的 `soop_play_recovery.dart` 的一段长签名重排成了我的格式（`git status` 里它自己冒出来 M）。⇒ 判据还是那条：format 只点**本轮真正编辑过的那几个文件**；发现混进来的自己没写过的文件，先 `git diff` 确认纯格式、再 `git checkout -- <那一个文件>` 退回，别连带提交。 |

## 第二十二轮（2026-11-05）：参考没拉成，YY 的 H5 握手与包格式钉住（第 4 部分，队列第三站）

**参考的拉取这次没成**：`git pull --ff-only` 与 `-c http.version=HTTP/1.1` 都是 `OpenSSL SSL_connect: SSL_ERROR_SYSCALL (github.com:443)`，同时 `curl https://github.com` 回 **000**、`raw.githubusercontent.com` 回 **200** ⇒ 是 GitHub 443 这一跳不通，不是脚本或凭据问题。仓已在上轮快进到 `f00bebd91` 且工作树干净 ⇒ **本轮没有少拿东西**，但下轮开工第一件事是再 pull 一次。

| P62 | `4e70e2b35` | YY 的弹幕线格式被钉住（25 条） | 新增 `packages/live_sites/test/platforms/yy/yy_danmaku_test.dart`，**站点 lib 一行未动**。钉三组事：**包格式**——10 字节小端头（长度含自己、uri、响应码 200），九种字段类型写读往返（u8/u16/u32/u64/bytes/`u16` 计数字节/`u32` 计数字节/Latin-1 串/UTF-8 串/UCS-2LE），读过尾部抛 `FormatException` 而不是给 0，头自己撒谎（长度 <10 或 > 包长）也抛，UCS-2 落单末字节丢掉。**握手**——`beginHandshake()` 回到 waitingUdb 并清空上次登录；AP 登录前 `heartbeat()` 必须是 null（3.x 那时不发心跳）；四步梯子每步该发什么（778244→778500→775684→775940→513035+538456→进房后两条 537944）；envelope/result 非 0/200、`realUri` 不是 20078、uid 0 都失败；别的频道的 join、`loginStatus != 4`、router 的 `responseCode` 拒绝都失败并念出 `errorInfo`；**读坏了分两种**——握手期间是 failure，进房之后只是 warning 且相位不变。**进房后**——app 31 的 `3104600` 聊天（发言人、`YY用户` 兜底、XML 解包、extras 尾巴不吞正文、空文本与别的频道不落列表）、app 103 的 `3139586` 热度→`popularity`（别的频道丢、`3165186` 不读、app 15012 不订、被擦短的 <10 字节体不读）、一帧多包按序、尾短或长度撒谎是 warning 并停在原处。`chatText`（前缀只认 `<?xml` 与 `<msg`）与 `compactFailure`（压成一行、120 字截尾）也钉住。 |
| 计数 | 同上 | 546 绿 | 新文件 **25 绿**；`test/platforms/yy` 整目录 55 绿；`packages/live_sites` 整包 **546 绿**（上轮 521）；`dart analyze test/platforms/yy` 0 issues。 |

**首轮 4 红仍然全是我的 fixture 错，解码器没有错**（连着第三轮这样，写下来当我自己的判据）：① uri 4321 的字节我写成 `0x11 0x11`，小端应是 `E1 10 00 00`；② XML 实体我按"先解 `&amp;` 再解 `&lt;`"推成 `a<b c A B`，真答案是 `a&b <c A B`（每个引用各自替换一次，不叠加）；③ 我拿裸 `<txt …>` 当会被解包，而 `chatText` 只认 `<?xml`/`<msg` 前缀；④ router 信封里的 `533080` 载荷是**裸字段**（`_readUserGroup(YyPacketReader(payload))` 不带包重读），我又套了一层包头，那条聊天就没被认出来。⇒ **钉协议前先把被测函数"按什么顺序读几个字段"抄成注释再写 fixture**，别凭平台印象；本轮另有两条 lint 也是同因（`writeByteArray('x')` 直接给了 String、单表达式里写级联返回 void）。

**没做**：只加测试，`platforms/yy/**` 的 lib 未动；`room_page.dart`/`room_controller.dart` 本轮复核仍被 ingest lane 占着 ⇒ 第二十一轮表里那四条 UI 缺口继续挂。站点测试队列剩 **huya（要自己写 TARS fixture，最贵）→ kuaishou → douyin → twitch**。
