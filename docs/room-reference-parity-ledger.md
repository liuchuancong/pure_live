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
| P17 | media_core `49e418c` + `af59be0f1` | 屏蔽可见 | 「本场已屏蔽 N 条」：引擎把 policy 的判定（屏蔽的人/词）用 `onSuppressed(message, reason)` 报给 host，app 只把**观众自己的四条**计入（屏蔽名、屏蔽词含正则、纯表情、超长）；重复/相似/重发不算——那度量的是房间有多吵，不是屏蔽有没有在跑。位置=房间屏蔽面板第一行（参考同处），设置页不放第二个入口。`RoomShieldCountController` 计数立刻、通知按帧合并；开房/关房/离场三处归零。新串 `shield.blockedThisStream`。测试：引擎 2 例（只报 policy、按名字算）、app 2 例（计数、归零）。 |
| P16 | `6374af2c1` | 屏蔽纯表情/超长 | `danmakuMessageShape` 加可选 `emoticonPattern`；app 在 `danmakuShapeBlockedByRules` 里传 `EmojiAtlas.instance.regex`（就是聊天绘制用的那张表）。之前斗鱼/虎牙的 `[笑哭][笑哭]` 被当成 8 个字符：表情屏蔽放行、超长屏蔽多算。图集没加载完就退回旧读法（不因此拦掉没要求拦的行）。测试 `packages/live_sites/test/models/danmaku_text_shape_test.dart` 5 例。 |

## 已核对为持平或更强（别重做，附证据）

| 面 | 参考 | 我们 |
| --- | --- | --- |
| 桌面条音量 | 条上 96 px 滑杆 + 静音（`player/bar_parts.dart:150`） | 宽条 `DsSlider`（TV 140 / 桌面 90）+ 静音（`room/page/player_surface.dart:1943`） |
| 控件隐藏 | 硬编码 4 s、淡 200 ms（`player/player_view.dart:345`） | 设置项 `controlsAutoHideSeconds`，面板打开/暂停/TV 不隐藏（`player_surface.dart:472`） |
| 聊天列 | `34% clamp(300,400)` + 22×56 折叠把手（`logic/room_layout.dart:317`） | 可拖 + 方向键/Shift + 双击复位 + `collapseChat` 折叠（`room/page/chat_splitter.dart`、`room_page.dart:1025`） |
| 名字色 | 平台色走到 ≥4.5:1 并缓存（`danmaku/chat_list.dart:31-78`） | 同机制（`room/chat/room_chat.dart:812-840`） |
| 弹幕行 | 徽章图片 + 粉丝牌 chip + 角色；名字 w600 +「：」；列表内无时间戳；无 maxLines | 最多 3 枚平台徽章 + 角色 + 粉丝牌 + 等级、`tagHeight` 统一、连续同人合并（`room_chat.dart:496-515`） |
| 竖屏 | 三停靠点拖面板（min 250 / 44% / 68%）+ 手柄 48 + grip 38×4 + 「横屏全屏」pill | 我们窄窗是 58% 舞台 + 信息条 + 聊天堆叠（`player_surface.dart:1817`、`room_orientation.dart`）→ **不是同一形态，见 T2** |
| 沉浸式 | **absent**（只有 fullscreen / portraitFullscreen / windowFullscreen 三态） | 我们有剧场（玻璃卡聊天叠在画面上）——我们更多，别照抄删掉 |
| 打开链路请求数 | detail(+弹幕票) → discover → urls 串行，且明确不缓存播放地址（`live_core/live_site.dart:385`） | 同数量级；双 `getRoomPlayInfo` 是 API 固有（bilibili 只在 `accept_qn` 里列其它档， douyu 档表无 URL） |

## 待办队列（自上而下，一项一轮）

- [ ] **T1 录制状态卡的完整数字（挪进 T5 做）**。参考 `shared/record/record_status_card.dart:341-388`：`第 n 段 · 每 N 分钟一段`、36 px 时钟、chips `已录 356 MB` / `3.2 Mbps` / 画质 / `弹幕 1,284 条`。P9/P11 已把大小与合并百分比放上条上、并让非写入态有名；**条上到此为止是刻意的**——参考的条/角标也只放时钟与状态词，段数/码率/弹幕条数属于卡（面板）。故这些数字随 T5 的只读面板一起做，不要塞进玻璃 pill。
- [ ] **T2 竖屏直播的三停靠点面板**。参考解剖见上；决定窄窗竖屏源是否从"堆叠"改成"画面满幅 + 可拖底部面板（min/44%/68%，手柄 + grip + 横屏全屏 pill）"。**注意**：这是布局形态变更，先给用户 2–4 个 HTML 样张选方向（`feedback-ui-variants-before-rebuild`），别直接改。
- [x] **T3 弹幕列表：过滤计数可见**（P17）。参考把被屏蔽条数只放屏蔽页「本场已屏蔽 N 条」（`blocked_count.dart:5`、`block_manager.dart:293`）。我们此前根本没有计数（包与 app 都只回 bool）⇒ 已补：引擎报 policy 判定、房间只数观众的四条规则、面板第一行显示；设置页不放第二个入口。
- [ ] **T4 live_core / live_danmaku 能力差**：另派代理解剖（结论未回收）→ 回到本表补队列，别在 app 里重做包能力（`feedback-use-package-facilities-not-app-hacks`）。
- [ ] **T5 房间侧「录制」只读面板 + 跳「录制中心/录制设置」**（参考右侧 `RoomSidePanel`）。**不做**其中的画质 chips 与"开播自动录"开关：前者是录像 lane 的待办（`task.quality` 已存在、取流已按它选档），后者与订阅卡片右端开关重复（同项一个入口）。
- [ ] **T6 已判定不做**：到期前主动换地址——bilibili 自己的 lease 注释写着"expiry does not cut an established connection"（`parsers/bilibili_play_parser.dart:240`），主动重开会**制造**缺口；`requiresReconnect` 默认 false。礼物/SC 结构化 XML 需要改 `DanmakuEntry` + 全部 5 种渲染器，不在房间线里做。`forceDestroy` 默认 true 已实测只值 ~60 ms，不改默认。

- [x] **T7 撤回落实**（P13）。参考 `features/live_play/danmaku/chat_feed.dart:285` + `live_danmaku/filters/message_gate.dart:71`。我们：`bilibili_danmaku_codec.dart:299,334` 会发 `retraction`，`flame_barrage_sink.dart:95` 有 `retract()`，但 `room_controller.dart` 把非礼物类型统统当 `chat` 灌进管线、空文本又丢掉 ⇒ 房管删除的弹幕永远留在屏幕与列表。**做法**：分派 `retraction` 到聊天 feed 删除 + 飞行层 `retract`；`retractByUser/clear` 的引擎调用一并补。**已按此做完**：一条 `LiveRetraction.matches` 同时喂两个面（列表 `retract`、飞行层 `retractWhere`），`all` 只删说过的话、礼物与通知留下。参考 gate 把撤回目标并进去重键（`message_gate.dart:71`）这 ours 不需要——撤回在进 gate 之前就分派走了。
- [x] **T8 gate 缺 replay / SC / combo 键**（P14）。参考 `message_gate.dart:28-33,61-62,95-98`。我们 `danmaku_message_gate.dart` 无 `maxReplayAge`、不读 payload ⇒ **YouTube 回放与重连补发被 45 s 规则整段吞掉**（`youtube_danmaku_codec.dart:458` 已设 `replayed`，无人读）。**已做完**：`replayed` 与 `maxReplayAge` 进消息/配置/gate，付费卡按 `endTime` 免死。**combo 键刻意不搬**：我们的房间在 `RoomDanmakuPipeline.accept()` 就把礼物分流出管线（连击走 `GiftFlights`），gate 永远看不到礼物，搬进去是死代码；参考那边需要它是因为礼物同过 gate。
- [x] **T9 正则黑名单在直播间失效**（P15）。`media_core_danmaku/danmaku_filter_policy.dart` 过去只 substring；`live_sites/common/danmaku/filters/block_pattern.dart` 只有录制读 ⇒ 同一份名单两处行为不一致。**已统一到包侧**：格式的权威仍在 `live_sites`（它同时管着设置页添加时的耗时探测与指数回溯判据，两份实现会漂），引擎只收编译好的 `RegExp` 并保证代价（只看前 200 字）。app 不重实现，只做一次拆词。
- [x] **T10 「屏蔽纯表情」不吃内置表情表**（P16）。参考 `message_filter.dart:126` 有 shaper hook；我们 `danmaku_filter_settings.dart:250` 用默认 shaper（只认 `message.emotes`），而图集键就在 `shared/player/emoji_atlas_loader.dart:47`。⇒ 斗鱼/虎牙 `[笑哭][笑哭]` 屏蔽不掉。**已做**：包侧 `danmakuMessageShape(..., emoticonPattern:)`（规则在包里，表在 app），app 传 `EmojiAtlas.instance.regex`——和聊天绘制同一张表，屏幕说什么就按什么算。
- [ ] **T11 lease 驱动的换链**。`live_sites` 有 `LivePlayLease`（refreshAt/expiresAt/requiresReconnect）+ 10 个 `*PlayLeaseLookup` capability，**app 内零读者**；播放器只在失败后重取。注意与 T6 的区别：**HLS/需要重连的线**才该提前换（`requiresReconnect`），FLV 建立中的连接不受到期影响。
- [ ] **T12 错误分类太薄**。参考 `live_core/site_error.dart:19,47-58,63-71` 有 `isTransient`/`retryAfter`/`cookieSuspect`；我们 `live_sites/core/live_site_error.dart:38` 三者皆无 ⇒ 429/风控时上层不知该等多久、该不该提示换 cookie。扩 `LiveSiteError`（一次补全字段，别逐条加）。

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
