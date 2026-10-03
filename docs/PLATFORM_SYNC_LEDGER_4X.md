# 平台层同步账本（wzgrx 4.x → 本仓）

本仓（`liuchuancong/pure_live`，3.x 分层结构）与参考实现 **wzgrx/pure_live 4.0.0**
（本机副本 `C:\Users\m1779\Downloads\pure_live-master\pure_live-master`，
git ref `wzgrx/master`，2026-10-03）同为 3.x 血统：4.x 是把 3.x 整仓重构成 Dart
workspace（`packages/live_core` 平台层、`live_danmaku` 弹幕、`live_net` 网络、
`live_media`/`live_player` 播放），契约与目录都变了，因此**不能整包拷贝**。

同步方式：**逐平台摘取**。以 `wzgrx/master` 的提交为单位，把与站点相关的语义搬进
本仓 `lib/shared/platforms/<站点>`，保留本仓既有契约与独有能力
（`LiveSiteExternalRoomResolver`、`LivePlayLeaseMetadata` 租约续期、
`w_rid` 签名、游客名屏蔽、FLV splice relay 等）。

> **范围（用户指定）**：**不**为 EmptyDanmaku 的站点新写聊天/弹幕引擎；只同步
> **站点侧的弹幕显示相关改动**（已有引擎的连接参数、消息解析与展示，礼物/公告/
> 撤回在弹幕区的呈现）以及房间详情/画质/取流与线路解析、状态与限制。
> 因此各站点小节里"弹幕本体/新引擎"一类未做项属于**明确不做**，不再是待办。

- 本仓最后合并 wzgrx 的点：`4802611aa`（2026-09-27，3.x 树）。
- 该点之后 wzgrx 有 1290 个提交，其中 **328** 个动过平台/弹幕包。
- 其中真正的站点 `fix` 只有十几个，其余是 4.x 新功能（超级留言、礼物上报、
  公告/撤回、按站点补齐的弹幕事件）。因此同步的价值主要在**新能力**，
  而不是"本仓落后了一堆播放修复"。

## 每站点上游提交数（4802611aa..wzgrx/master）

| 站点 | 提交数 | 状态 |
| --- | --- | --- |
| bilibili | 24 | 进行中（见下） |
| douyin | 20 | 本轮已摘取（见下） |
| kuaishou | 16 | 本轮已摘取（见下） |
| youtube | 15 | 待办（本轮评估：主要是新增 YouTube 聊天与新频道模型，见下） |
| huya | 15 | 本轮已摘取（见下） |
| douyu | 14 | 本轮已摘取（见下） |
| yy | 12 | 本轮已摘取（见下） |
| niconico | 11 | 待办 |
| pandalive / picarto / seventeenlive | 11 | pandalive、picarto 已摘取（见下）；seventeenlive 本轮已摘取（见下） |
| twitch | 10 | 本轮已摘取（见下） |
| soop | 10 | 本轮已摘取（见下） |
| chzzk | 10 | 本轮已摘取（见下） |
| kugoulive | 10 | 本轮已摘取（见下） |
| bigo / fc2live | 9 | 两站本轮均已摘取（见下） |
| missevan / kilakila / acfun | 8 | 三站均已摘取（见下） |
| jdlive / looklive / steambroadcast / twitcasting / showroom / sixroom / baidulive | 7 | 七站均已摘取（见下） |
| cc | 5 | 本轮已摘取（见下） |
| tiktok | 5 | 本轮已摘取（见下） |
| inke / xiaohongshu / weibo / liveme | 4 | 四站均已摘取（见下） |

## 同步状态总览（2026-10 收尾核对）

| 目标项 | 状态 | 证据 / 提交 |
| --- | --- | --- |
| ① `startedAt` 与 `restriction` 接入各站点 + UI + 拒绝路径 | **完成** | `restriction:` 39 处、`startedAt:` 20 处（`lib/shared/platforms/**`）；`LiveRestriction` 枚举与 `effectiveRestriction` 在 `core/models/live_room.dart`；拒绝路径 `live_play_controller.dart:790/818` + `_roomStateMessage`；`restriction_*` 文案在 `assets/i18n/{zh,en}.json` |
| ② 弹幕撤回 | **完成** | 模型 `LiveMessageType.retraction` + `LiveRetraction`（`89248f0ff`）、B 站解析（`0533df81b`）、显示层（`db09fc212`）、引擎按条撤回 `retractWhere`（flame_barrage `efada9c`）+ 本仓接线（`4966ca1ce`） |
| ② 礼物进弹幕区 | **完成（B 站）** | 解析 `SEND_GIFT`/`COMBO_SEND`/`GUARD_BUY` + 列表分支（`11a47144e`）；其余站点的 gift 上报可复用同一分支 |
| ② 消息表情图片 | **完成** | 模型 `43540cc10`、B 站解析 `9fb1ef1da`、列表渲染 `c4699764d`、画面渲染 `f587c26a3`、快手表情表 `c217b86bc` + `dffed3f69` |
| ② 公告头条 | **完成（B 站 + 虎牙结束通知）** | `LiveMessageType.notice` + B 站 `WARNING`/`CUT_OFF`（`6e79b8bda`）；虎牙 `uri 8001` 结束直播（`133725ed7`）。虎牙 board 面板解析（通知自带面板时省一次请求）属优化，未做 |
| ③ YouTube 频道即房间 | **功能已等价，身份未翻转** | 链接层有 `YouTubeLinkKind.channel`；`resolveReference` 能把频道解析成当前直播。翻转身份需连迁移一起做，建议不做（见下） |
| ③ niconico 房间即主播 | **部分**：链接形态与主播链接可打开已完成（`abb4c7269`、`bb1f6fbae`）；**身份翻转未做**（与列表 `providerType` 映射是同一件事，需连迁移一起做） |
| ④ bilibili 付费房限制 | **完成** | `7f31d7756` |
| ④ bilibili 详情开播时间 | **完成** | `021741490` |
| ④ bilibili 新增弹幕事件 | **完成** | 撤回 / 贴纸表情 / 礼物 / 公告，见上 |
| ④ bilibili 轮播 `play_time` 起播偏移 | **3/5**：站点解析 + 契约 + 播放层结果已做（`4291990b6`）；第 4-5 步需**新增播放层 seek 通道**（本仓 `lib/` 里没有任何 seek 调用），已记账 |

**待用户决策（唯一）**：是否翻转 YouTube / niconico 的**房间身份**（视频/节目 → 频道/主播）。
收益：同一频道/主播换场后收藏、历史、多画面指向同一房间；代价：存量 key 需迁移或惰性升级，
"回看某一场"的语义变化。不做则现状功能等价（能打开、能播、能看弹幕），只是每场是新房间。

## 待实施：③ 身份模型（YouTube 频道即房间 / niconico 房间即主播）

2026-10 实测本仓现状（与上游 4.x 的身份模型对照）：

| 站点 | 本仓现状 | 上游 4.x | 差异 |
| --- | --- | --- | --- |
| YouTube | `roomId = videoId`（`youtube_site.dart:71`），`userId = channelId`（:72），链接是视频链接（:79） | **房间 = 频道**：频道是房间身份，当前直播只是它的属性 | **身份要翻转**：`roomId` 改成频道（handle/`UC…`），视频变成"当前节目"属性 |
| YouTube（链接层） | `youtube_link.dart` **已经有** `YouTubeLinkKind.channel`（`@handle` 与 `UC…`，含 `channelPath`） | 频道链接是房间链接 | 链接层基本就绪，缺的是"房间身份也用频道" |
| YouTube（解析层，2026-10 补测） | `YouTubeApi.resolveReference()`（`youtube_api.dart:172`）**已经能把频道引用解析成"该频道当前在播的视频"**（依次看重定向、canonical、`ytInitialPlayerResponse.videoDetails`、`ytInitialData` 里的直播 id；没有在播就 `notLive`）；搜索/打开链接都走它 | 上游同样需要这一步 | **功能性等价已经具备**：粘频道链接就能打开它当前的直播 |
| niconico | 只认 `https://live.nicovideo.jp/watch/<id>`（`niconico_link.dart:7`），id 必须是节目号（`NiconicoWatch.validateProgramId`） | **房间 = 主播**：`watch/user/<id>`、`watch/ch<n>`；官方节目保持 lv | 要接受主播链接形态，并让房间身份是主播 id |

**共同影响面（两个站点一样）**：收藏、观看历史、标签、刷新合并、多画面选房都以
`LiveRoom.roomId`（+`platform`）为 key，翻转身份意味着**存量条目（按 videoId/节目号存）与新条目（按频道/主播存）不一致**，必须给出迁移或兼容策略：

- 方案 A（稳妥）：新身份为主，读取旧条目时按"该 videoId/节目号属于哪个频道/主播"惰性升级
- 方案 B（激进）：一次性迁移本地库
- 无论哪种，都需要站点提供"由旧 id 找新 id"的一次解析（YouTube 用 `videos?id=` 拿
  `channelId`，niconico 用 watch 页拿主播）

实施顺序建议（先易后难）：
1. **YouTube**：链接层已就绪 → 站点侧把 `roomId` 改为频道，`data` 里保留当前 videoId 供取流；补"频道 → 当前直播"的解析与列表/搜索按频道去重
2. **niconico**：先加主播链接形态（`watch/user`、`watch/ch`、`ch.nicovideo.jp`），再把房间身份从节目号改为主播 id（官方节目保持 lv），最后补列表/搜索按 `providerType` 映射
3. 两者都要接一套**旧 key → 新 key 的惰性升级**，并在账本记下取舍

**2026-10 复评（重要修正）**：YouTube 这一项**功能上已等价**——链接层有频道形态，`resolveReference` 能把频道解析成当前直播，搜索/打开都可用；与上游的差别**只剩"存下来的身份"**（本仓 `roomId=videoId`，上游是频道）。因此：

- 收益：同一频道换场后收藏/历史仍指向同一房间（跨场一致）
- 代价：收藏/历史/标签/多画面选片全部按 `roomId` 存的**存量数据要迁移或惰性升级**；且"房间回放/回看上一场"的语义会变
- 结论：**建议暂不做身份翻转**（功能等价、迁移风险高），按"仅身份不同，功能已具备"记账；
  若将来要做，按上面第 3 条先定迁移策略
- niconico 无此捷径：本仓只认节目号链接，连"粘主播链接"都不支持，**必须做**

## 待实施：niconico 房间即主播（③ 的剩余部分）

**已做（2026-10）**：
- 节目链接形态：`http` / `sp.live.nicovideo.jp` / `nico.ms/lv…`（`abb4c7269`）
- 主播链接可打开：`watch/user/<id>`、`watch/ch<n>`、`www.nicovideo.jp/user/<id>`、
  `ch.nicovideo.jp/ch<n>` → 一次 watch 页请求换成"当前在播的节目号"（`bb1f6fbae`）；
  **房间身份仍是节目号**，存量收藏/历史不受影响

**剩余（= 身份翻转本身，无中间态）**：上游 `NiconicoApi.roomIdOf`
（`niconico_api.dart:465`）按 `providerType` 决定房间身份——
`community`/`user` + `userId` → `user/<id>`，`channel` + `channelId` → 频道房间 id，
其余（含 `official`）→ 节目号。本仓 `niconico_directory.dart:88` **已经**按同一集合
校验 `providerType`（`{community, channel, official}`），但一律 `roomId: id`（节目号）。

也就是说：本仓与上游在这条上的差别**就是身份模型本身**，没有"只做映射不动身份"的
中间步骤。要做就得连迁移一起做（见上文 YouTube 一节的迁移路线 A/B），收益是
"同一主播/频道的多场节目归为一个房间"，代价是存量 key 迁移与"回看某一场"的语义变化。

## 待实施：B 站轮播 `play_time` 起播偏移（方案已定）

上游语义：`getRoundPlayVideo` 的 `data.play_time` 是**已经播过的秒数**，播放应从那里开始
（非数字/负数从 0 开始；回答自带的 `play_url` 是死链，不读）。

已核实的三层现状：
- 站点层：`parseRoundPlayVideo` 只返回 `(bvid, cid)`，丢掉了 `play_time`；
  `LivePlayUrlResolution` 没有起播位置字段
- 本仓播放层：`PlaybackSource`（`UrlPlaybackSource`/`OwnedPlaybackSource`）没有位置字段，
  整条 playback 路径搜不到 `seek`/`startPosition`
- `F:\media_core`：`PlayerAdapter` 有 `open(PlayerSource)` 与 `seek(Duration)`，
  但 **`open` 不接受起播位置**，只能"打开完成后 seek 一次"

实施步骤（按顺序，一处不漏）：
1. `bilibili_site.dart`：`parseRoundPlayVideo` 多返回 `start`（`Duration`，非数字/≤0 → 0）；
   `_resolveCarouselVideo` 放进 `LivePlayUrlResolution` —— **已做**（`c101b0f0` 一类提交）
2. `live_site.dart`：`LivePlayUrlResolution` 新增 `startAt`（默认 `Duration.zero`，向后兼容）—— **已做**
3. `player_controller.dart`：`PlaybackSourceRefreshResult` 带上 `startAt`（与现有
   `refreshAt`/`invalidAt` 同一处、同一条通道）—— **已做**
4. 结果消费处（source commit → open）：把 `startAt` 交给源/播放会话 —— **未做**
5. 播放器：open 完成后的第一个状态事件里 `if (startAt > 0) seek(startAt)`，**每条源只做一次**
   （重连/切档不重复跳）—— **未做**

**第 4-5 步的关键障碍（2026-10 实测）**：本仓 `lib/` 里**没有任何 seek 调用**
（`seek`/`jumpTo`/`setPosition` 全量搜索只命中滚动、菜单与 M3U 解析），也就是说
播放层**没有向应用暴露 seek**；`media_core` 的 `PlayerAdapter.seek(Duration)` 虽有，
但要先在"应用 → facade → adapter"之间打通一条 seek 通道。因此这两步不是"补两处调用"，
而是**新增播放层能力**，方案需要先定：

- 通道放哪：`LivePlayerFacade` 暴露 `seekTo(Duration)`，经 `_playerManager` 落到 adapter
- 谁来调用：`VideoController._handleSourceCommit` 里记下"本次源带 `startAt`"，
  在**首个 position/duration 事件**里调用一次（`duration > startAt` 才调），并用
  revision/source identity 保证"每条源一次"
- 播放中继（FLV splice relay）/重连/换档都必须显式跳过，否则会把直播拉回起点

验证要求：全仓 `flutter analyze --no-pub` + `tool/validate_architecture.py --strict`；
真机确认需观察轮播房首帧是否落在当前进度上。

## bilibili

上游相关提交（按时间）：

| 提交 | 内容 | 本仓状态 |
| --- | --- | --- |
| `0811c21f7` | 心跳人气占位值 1 不再顶掉详情里的真实热度（REG-BILIBILI-015） | **已同步** |
| `12d03ac89` | `live_status` 2 = 轮播（详情/刷新/搜索）、`startedAt`、付费房限制 | **部分同步**：状态与轮播取流已做；付费房限制已做（`special_type` 1 且在播 → paid）；**`startedAt` 详情已做**（`room_info.live_start_time` → UTC），搜索行的 `live_time`（北京时间文本）与轮播 `play_time` 起点未做 |
| `8d7da2dfc` | 轮播视频播放（`getRoundPlayVideo` + `x/player/playurl`）、`LivePlayUrlResolution.start` | **部分同步**：取流已做；`start` 起点（`play_time` 续播）未做 —— 方案已定，见下 |
| `81733c1e6` | 游客可用分区页、搜索分区标签、弹幕撤回与公告 | **已同步（撤回与公告）**：公告的 op-24 回执本仓早有；**撤回整条链路已打通** —— 公共模型 `LiveMessageType.retraction` + `LiveRetraction`（观众/单条 id/全部）、B 站解析（`RECALL_DANMU_MSG` 排在 `DANMU_MSG` 前、`recall_type` 2/3、`SUPER_CHAT_MESSAGE_DELETE` 按 id）、显示层（聊天列表 `removeDanmakuWhere` + 画面弹幕按条撤下）。为让画面也能按条撤，引擎侧在 `E:\software\flame_barrage` 新增 `BarrageItem.id` 与 `BarrageController.retractWhere`（该仓库提交 `efada9c`），`pure_live` 改为该仓库的路径依赖。分区页/搜索标签待对照 |
| `e8a00e0d4` | 弹幕在线人数与礼物上报 | 待办 |
| `2eea8022a` | 游客名提示、粉丝牌与头像 | 待办 |
| `fffd28b31` | 弹幕消息携带表情图 | 待办（需要 `LiveMessage` 模型扩展） |
| `95cf8473e` | 弹幕回到 protover 3 | 无需（本仓一直是 3，且同时解 zlib） |

本次落地的改动：

1. `bilibili_danmaku.dart`：`operation == 3` 的心跳人气 `<= 1` 直接丢弃。
2. `LiveStatus.carousel`（追加在枚举末尾，`index` 持久化不受影响）、
   `isPlayableNow` 纳入轮播、新增 `isCarouselNow`。
3. `bilibili_site.dart`：`live_status` 统一走 `_status()`（1 直播 / 2 轮播 / 其余下播），
   详情与搜索都改用它；轮播房走 `getRoundPlayVideo` + `x/player/playurl`
   取循环视频，清晰度给出唯一的「轮播」档。
4. `multiview_room_picker` 状态徽标与 `zh/en` 新增 `carousel`（轮播中 / In rotation）。

未做/风险：

- 轮播视频的请求头沿用本仓按平台统一的 Referer（`live.bilibili.com`），
  上游用的是视频页 Referer（`https://www.bilibili.com/video/<bvid>/`）。
  若 CDN 拒收会表现为轮播起播失败——需要实机确认。
- `LivePlayUrlResolution` 尚无 `start`（上游用 `play_time` 从上次位置续播），
  本仓轮播从头播放。
- 弹幕的新消息类型（撤回/公告/礼物/表情/粉丝牌）需要先扩展
  `LiveMessage` 模型与渲染层，属于跨站点的公共改动，留到专用批次。

## douyu

上游相关提交：

| 提交 | 内容 | 本仓状态 |
| --- | --- | --- |
| `398f68f87` | 房间 `rss` 包（`ss@=0`）表示本房间下播，结束这一路弹幕 | **已同步** |
| `8eca75a32` | 分区图标空 `icon` 时退到 `smallIcon`/`pic` | **已同步** |
| `8eca75a32` | `dgb` 礼物包上报为 gift 消息 | **已同步**：礼物消息现在会进弹幕列表展示 |
| `20c9ea20e` | `expire=0` 的 FLV 强制续期（构造开关，默认关） | 未做：上游默认关闭，且本仓没有这个设置项；本仓对 `expire<=0` 仍视为无租约 |
| `20c9ea20e` | `startedAt` 取 betard `show_time` | **已同步**：在播时 `show_time`（Unix 秒）填进 `LiveRoom.startedAt`（房间详情路径） |
| `20c9ea20e` | 别名大小写不敏感（`lpl`/`LPL` 同一 rid） | 待评估：需要本仓的房间身份归一化一起改 |
| `bedce82aa` | 登录会话状态与 passport 续期 | 未做：属 cookie 仓储（本仓有 `douyu_cookie_controller`/`douyu_utils` 自己的实现），不在站点适配器范围 |

本次落地：

1. `douyu_danmaku.dart`：`rss` + `ss@=0` 且 `rid` 为本房间（缺 `rid` 不拦）时，
   先 `stop()` 再回调 `onClose('直播已结束')`，弹幕不再挂在一个已结束的房间上。
2. `douyu_site.dart`：`_areaPicture()` 依次取 `icon`/`smallIcon`/`pic`，
   并走本仓的 `normalizeNetworkImageUrl`。

## huya

上游相关提交：

| 提交 | 内容 | 本仓状态 |
| --- | --- | --- |
| `ce7de2d01` | 搜索与分组树必须带 User-Agent，否则 HTTP 403 `Not allowed` | **已同步** |
| `ce7de2d01` | `preferH264` 开关（关闭时 FLV 线路要 `codec=265`） | 未做：本仓没有该播放设置项，且默认行为（`codec=264`）与上游默认一致 |
| `ce7de2d01` | `uri 6501` 礼物包上报为 gift | **已同步**：礼物消息进弹幕列表展示（同斗鱼） |
| `dc2080a18` | REPLAY 房播放录制（`liveData.hls` + `moment/getMomentContent` 的清晰度）、`startedAt`、付费/密码房限制 | **部分同步**：搜索卡片的付费标记 `isRoomPay`（true→paid / false→none / 缺失→null）已接；**REPLAY 录制取流、`startedAt`、详情里的付费/密码房限制（`isRoomPay`/`isPayRoom`/`isSecret`）仍未做**（需要新接口与字段） |
| `9c8da06e1` | REPLAY 房保持 replay 状态 | 无需：本仓 `huya_site.dart` 已把 `REPLAY` 映射为 `LiveStatus.replay` |
| `5a9fa6a5e` | 公告板取 headline，下播关闭弹幕run | 部分待做：弹幕 run 结束与斗鱼同类，但要先确认本仓虎牙弹幕的对应包 |
| `8613f92bd` | 单条推送携带 `lMsgId`（撤回需要） | 待做：与撤回消息类型一起做 |

本次落地：`huya_site.dart` 的 `getSubCategores`、`searchRooms`、`searchAnchors`
三处补上 `user-agent: kUserAgent`（本仓已有同一个移动端 UA 常量）。

## douyin

上游相关提交：

| 提交 | 内容 | 本仓状态 |
| --- | --- | --- |
| `68de720c2` / `107bd1aa7` | 4-1：enter 的 room 无 `status` 时由 `data.room_status` 判定（0 直播 / 其余下播），status 存在时以它为准 | **已同步**：`_douyinIsLive()` |
| `59602ec7b` | 详情分区取游戏名（`game_data.game_tag_info.game_tag_name`），否则 `partition_road_map` 最具体一层标题 | **已同步**：`_detailArea()`，webRid 与 roomId 两条详情路径都用它（此前一律留空） |
| `95b769763` | 在线人数优先用 `RoomUserSeqMessage.total`（精确值），展示文本 `onlineUserForAnchor` 只作退回 | **已同步** |
| `95b769763` | 聊天时间退回 `ChatMessage.eventTime`（录制帧常只有它） | **已同步** |
| `59602ec7b` | 开播时间：enter 无 `startedAt` 时补一次 reflow（最多 3 秒，按 room_id 记忆） | **部分同步**：详情在播时用 `start_time`（退 `create_time`）填 `LiveRoom.startedAt`；"无值再补一次 reflow"未做（要多一次请求） |
| `49ea1ccc4` | 游戏分区与更完整的推荐页分页 | 分区已随 `_detailArea()` 覆盖；推荐页分页未对照 |
| `03aa04354` | 关注一个新开播（换场后跟随） | 未做：属播放会话与弹幕重连策略 |
| `95b769763` | 套接字拆除不再等待 cancel（可能挂住） | 未做：属本仓自己的 `web_socket_util` 生命周期 |

## kuaishou

上游相关提交：

| 提交 | 内容 | 本仓状态 |
| --- | --- | --- |
| `c5ebffe2e` | H.265 里 H.264 没有的档位（4K、蓝光质臻）也列出：名字/id 带 ` · H.265`，排在所有 H.264 档位之后 | **已同步**：`parsePlayQualities()` 两套都收，按（编码优先、档位从高到低）排序 |
| `4f1a8b4a8` | A-3：房间页没有直播标题时，`fillFromDetail` 保留卡片标题 | **已同步**：`LiveRoom.fillFromDetail` 补上 `title`（本仓此前只填 area/nick/avatar） |
| `ab456b879` | 开播时间取卡片 `statrtTime`（epoch 毫秒） | 未做：本仓 `LiveRoom` 没有该字段 |
| `ab456b879` | 限制 `unplayable`（平台说在播但没有任何可播清晰度） | **已同步**：在播房间按 `playUrls` 是否有可播档位给 none/unplayable（三处房间构建都接了） |
| `4f1a8b4a8` | 快手卡片标题之外的 Twitch 部分 | 见 twitch 章节 |

## 批次 ② 核查表：已有引擎站点的弹幕改动

本仓有弹幕引擎的 8 站（bilibili、douyu、huya、douyin、kuaishou、soop、twitch、yy），
把上游 `packages/live_danmaku/lib/src/sites/<site>.dart` 的改动逐条分类
（不含 docs 与"refactored from v3"这类重写）：

| 站点 | 上游提交 | 内容 | 判定 |
| --- | --- | --- | --- |
| bilibili | `81733c1e6` | 撤回与公告 | 公告回执**已有**；撤回**需跨层**（新消息类型 + 渲染层移除） |
| bilibili | `40dc22279` | 打码昵称不能用于屏蔽 | **已摘**（屏蔽侧）；菜单与启动清理未做 |
| douyu | `398f68f87` | `rss`+`ss@=0` 表示下播，结束这一路 | **已摘**（本轮目标之前） |
| douyu | `8eca75a32` | `dgb` 礼物包上报为 gift | **已做**：礼物消息进弹幕列表展示 |
| huya | `5a9fa6a5e` | 公告栏头条（headline board）+ 下播结束这一路 | 待评估：头条展示需弹幕层支持；"下播结束"可能可摘 |
| huya | `8613f92bd` | 单片推送带 `lMsgId` | 待评估：本仓 huya 引擎是否有对应去重/串联逻辑 |
| kuaishou | `fffd28b31` | 消息带上表情图片（M13.16） | **已同步（跨层）**：`LiveMessage.emotes` + `LiveEmote`（模型）、B 站贴纸/内联解析、列表 `Image.network`、画面侧 `DanmakuEmoteLoader`（宿主持图 + 引擎 `EmojiAtlas` 注册）、快手房间页 `pcConfig…emojiPanel` → `KuaishouDanmakuArgs.emotes` → 解码器 `LiveEmote.inText` |
| soop | `083fac138` | `1`/`-1`/`bar` 文本、发送者 id、走代理的聊天 | **可摘**：纯站点层解析 |
| yy | `c991163f0` | 从弹幕上报热度（M4.D） | **已摘**（YY 热度字段），其余（分区列出/占位主播）见 YY 小节 |
| kuaishou/twitch/douyin | `84b9fe205` 等 | 生命周期/监听释放 | **不适用**（本仓无 `ConnectorBase`） |

结论：②"纯站点层可摘"的只剩 **kuaishou 表情图片**、**soop 文本与发送者 id**、
**huya 下播结束/`lMsgId`** 三类；撤回、礼物展示、头条公告都要动本仓公共弹幕层，
需要另行确认。



| 上游提交 | 内容 | 本仓状态 |
| --- | --- | --- |
| `aadad46ef` | 平台留在"原本有图"位置的不可见占位字符（快手标题里的 U+FFFC 会画成 "OBJ"）在创建时就清掉：房间的 title/nick/introduction/notice、弹幕的消息与用户名 | **已同步**（房间与弹幕消息两层）；超级留言文本未覆盖 |
| `40dc22279` | B 站游客看到的昵称是打码的（观***），按整名匹配的屏蔽表会把所有同样打码的观众一起挡掉（审计 B-1） | **已同步（屏蔽侧）**：`_isBlocked` 不再匹配打码名，`_refreshFilters` 也把历史/导入进来的打码名一并忽略；**上游的另外两处未做** —— 消息长按菜单不再为打码名提供"屏蔽该观众"，以及启动时清理一次存量打码屏蔽 + 提示 |
| `84b9fe205` | 每次等待/轮询后释放 stop 监听（上游 `ConnectorBase` 的 `stopped` future 会随长轮询累积监听） | **不适用**：本仓没有 `ConnectorBase` 这套运行时（`live_danmaku.dart` 只是接口）。酷狗/快手这类轮询在适配器内自己管理：快手是单个可取消的 `_pollTimer`（`kuaishou_danmaku.dart` 明确避免重叠定时器），不存在每次轮询注册监听的问题 |

本仓实现：新增叶子文件 `lib/core/utils/invisible_placeholders.dart`
（刻意不依赖任何东西，模型层不用为一条正则拉进 UI 依赖链），
`LiveRoom` 构造函数与 `fromJson`、`LiveMessage` 构造函数各自应用。
保留零宽空格/连接符/U+FEFF 与替换符 U+FFFD，只去掉对象替换符、
行间注记符、非字符与 C0/C1 控制符（制表与换行除外）。

## youtube（本轮仅评估）

上游 15 个提交里，站点侧只有两类内容，都不适合零散摘取：

- `abe77a889` / `da62d0146` / `476f578eb` / `f7f0922d3`：YouTube 直播聊天接入
  （超级留言、公告、撤回、观众数、全部聊天）。本仓 `YoutubeSite.getDanmaku()`
  仍是 `EmptyDanmaku`，要接就得把整套 live chat 拉进来，属新功能批次。
- `75e747f74` / `87bc61dfc`：频道即房间（UC + 22 字符）的新模型、
  `startedAt`、限制与轮播，需要 `LiveRoom` 新字段与新解析。

因此 youtube 暂不动，等"新功能批次"或用户点名再做。可选的小项只有一条：
`19f59f525` 把房间公告里"远端聊天尚待接入"的文案去掉——但本仓确实还没接聊天，
公告与现状一致，不该改。

## cc（网易 CC）

上游相关提交：`c64520ece`（M4.U.9，9-1 至 9-7）。

| 项 | 内容 | 本仓状态 |
| --- | --- | --- |
| 9-2 | 推荐卡片的分区读 `gamename`（这些行没有 `game_name`） | **已同步**：推荐与搜索卡片都改成 `gamename` 优先，再退 `game_name` |
| 9-3 | 在播但标题以「【重播】」开头 = 回放（不是直播，但照常可播） | **已同步**：`_onAirStatus()` 用在分类/推荐/详情/搜索四处 |
| 9-1 | 清晰度改由 `video_play_url` 给出（服务端档位、`vbrname_mapping` 命名、hs/ali 双线路 + auth_key 租约），失败再退回 3.x 的 redirect playlist | 未做：整块换掉本仓的清晰度发现，需要连播放一起验，留作单独批次 |
| 9-4 | 目录改用移动端 `gamecategory` API（4 分类 106 分区） | 未做 |
| 9-5/9-6/9-7 | 搜索卡片亮封面与热度、详情关注数、关注刷新走 `recommendbyccid` | 未做：属列表/详情字段与刷新路径 |
| 开播时间 / 限制 | `startat`（北京时间）与"有档位即无限制" | **已同步**（详情与推荐卡片）：在播/回放时把 `startat`（北京时间 → UTC）填进 `startedAt`；`stream_list` 非空或给了 `quickplay` → 无限制，否则 null（CC 这些回答里没有付费/私密状态） |

## yy

上游相关提交：

| 提交 | 内容 | 本仓状态 |
| --- | --- | --- |
| `393de73fc` / `dfcb14000` | 分区名预置表（含 `zonghe` → 综合）：没有列表模块的分区留不住"从分区页学到的名字" | **已同步**：`presetBizAreaNames` + `areaNameForBiz()`（学到的名字优先，未知退回原始 biz） |
| `4a825d7da`（6-2） | YY 默认标题 `<昵称> 正在直播` 去后缀 | **已同步**：`_title()` 用在列表/详情/搜索四处 |
| `c991163f0` | 弹幕 app 103 的 `3139586` 报告频道热度 | **已同步**：`_readPopularity()` 按热度上报（不是在线人数） |
| `c991163f0` | 无 JSON 列表的分区（手机直播/综合）改读页面里渲染的卡片 | 未做：要解析页面卡片 |
| `c991163f0` | 剔除占位主播（`YY用户` + 默认头像） | 未做：本仓只在弹幕侧兜底这个名字 |
| `c991163f0` | 小视频页没有 pageInfo 时返回空而不是报错 | 未做 |
| `784ca749e` | 移动端 HLS 优先、刷新请求数 | 无需：本仓即 3.x 行为 |
| `4a825d7da` 其余 | `flvFirst` 开关、搜索去后缀之外的分区归一、FLV 多线路 gear 复核 | 未做：开关/线路策略，按需再做 |

## twitch

上游相关提交：`5d9911bdd`（M4.U.8，8-1 至 8-8）、`4f1a8b4a8`（B-7、8-8）。

| 项 | 内容 | 本仓状态 |
| --- | --- | --- |
| 8-7 | 图片直连 Twitch 图片 CDN，不再改写成第三方代理 `i2.wp.com`（分类图、头像、列表封面/详情封面共 4 处） | **已同步**。风险：若境内直连 `static-cdn.jtvnw.net` 不通，Twitch 图片会空；这条是上游明确批准的改动，要回退只需把那 4 处的 `replaceFirst` 加回来 |
| 8-7 | 媒体线路不再携带登录 Cookie（CDN 授权在 usher 签名里） | **已同步**：`playback_header_resolver` 的 twitch 分支去掉 cookie，只留 UA/Origin/Referer |
| 8-5 | 在播时详情封面用直播截图，而不是主播头像 | **已同步** |
| 8-2 | 详情分区取所玩游戏的 `displayName`（此前是空字符串） | **已同步** |
| 8-4 | 详情带频道简介 | 未做：GraphQL 查询与 `User` 模型都要加 `description` |
| 8-1 / 8-3 / 8-6 | 搜索游标分页、语言筛选与推荐、未知目录视为 NotFound | 未做：分页/推荐策略与错误类型 |
| 8-8 | usher 带 `supported_codecs`（按引擎解码能力） | 未做：本仓没有 preferH264 之类的播放设置 |
| 开播时间 | 在播时 `stream.createdAt` 是开播时间 | **已同步**（详情路径：`startedAt` 填 UTC 的 `createdAt`） |
| B-7 | Twitch 被拒 Cookie 只上报一次（新接口 `LiveSiteCookieRefusals`） | 未做：本仓没有该接口 |
| 弹幕 | `RECONNECT`、撤回、公告、Cookie 过期 | 未做：与跨站点弹幕消息类型批次一起做 |

## soop

上游相关提交：`046a5866d`（M4.U.7，7-1 至 7-7）、`7ea69383c`。

| 项 | 内容 | 本仓状态 |
| --- | --- | --- |
| 7-2 | 标题与昵称解码 HTML 实体（卡片、详情、主播站） | **已同步**：`_display()` 用在列表/分类/搜索/详情四处 |
| 7-3 | 搜索卡片分区读 `broad_cate_name`（`standard_broad_cate_name` 现在的回答已不带） | **已同步**：`broad_cate_name` 优先，再退旧字段 |
| 7-6 | CHIP 拼出的聊天主机在 sooplive.com | 无需：本仓已是 `chat-<...>.sooplive.co.kr` |
| 7-4 | RESULT 0 / -2 在进房时是 offline / banned | 无需：本仓详情与录制路径都已这样处理 |
| 7-1 | 清晰度命名：`hd4k`(720p) 是「超清」、`hd8k` 是「蓝光」，顺序在原画之后 | 未做：要与本仓 `LiveQualityLabel` 的映射逐条对照后再改 |
| 7-5 | 进房同时读 station API（头像、标语、观众数）、未知主播 NotFound | 未做：多一次请求与新字段 |
| 7-7 | `afreecatv.com` 链接也算房间 | 未做：外部链接识别 |
| 弹幕 | 走代理、`1/-1/bar` 文本、发送者 id（B-6） | 未做：与跨站点弹幕批次一起做 |

## chzzk

上游相关提交：`8cc5fc996`（M4.U.20，20-1 至 20-10）。

| 项 | 内容 | 本仓状态 |
| --- | --- | --- |
| 20-4 | 频道页 `chzzk.naver.com/<id>`（后面最多一个页签）也是这个频道 | **已同步**：`ChzzkLink.parse` 同时接受 `/live/<id>` 与 `/<id>[/<页签>]` |
| 20-5 | 关键词超过 100 个 UTF-16 单元时截断（不切断代理对），不是拒绝 | **已同步**：`ChzzkApi.searchKeyword()` |
| 20-5 | 搜索每页固定 20 行 | **已同步**：页长与 offset 都用 `searchPageSize = 20`（服务端无论请求多少都回 20 行，按调用方页长算 offset 会漏房间） |
| 20-7 | live-detail 说没开播就是下播，不管频道的 `openLive` | **已同步**：`_channelCard(forceOffline: true)` |
| 20-6 | 游标之后的分页要 30 行（游标是排他的） | 无需：本仓已按 `size + 1` 请求再裁剪 |
| 20-1 | 目录改用平台自己的分区页（GAME/ENTERTAINMENT/SPORTS/ETC 等，最多 4 次请求） | 未做：本仓目前只有一个"公开目录"分区 |
| 20-8 | `blindType` ABROAD 也按地区限制（卡片与详情都带地区提示） | 部分：本仓已有 `krOnlyViewing` 与地区提示，ABROAD 分支未加 |
| 20-9 | 进房/录制只读 channel + live-detail（4→2 次请求），清晰度同时读两个 master | 未做：请求数与清晰度发现 |
| 20-10 | 回放提示文案 | 未做：文案 |
| 20-2 / 弹幕 | 弹幕参数带频道 id；CHZZK 弹幕本体 | 未做：本仓 `getDanmaku()` 仍是 `EmptyDanmaku`，要接得整套 live chat |

## kugoulive

上游相关提交：`53adeb466`（M4.U.29）。

| 项 | 内容 | 本仓状态 |
| --- | --- | --- |
| 根因 | `limitType` 是公开聊天限制（谁能发言），不是观看限制：被限制的房间照样推流，3.x 把它们当未知并拒绝播放 | **已同步**：不再产生 `restricted` 状态，房间按 `liveType`/`liveSessionId` 判定。枚举值保留（UI 分支还在，只是不会命中） |
| 29-1 | 卡片上任何正的状态值都算在播（6 是手机/游戏直播） | **已同步**：`> 0` 即 live |
| 29-2 | 房间信息没有直播标题（`publicMesg`/`privateMesg` 是聊天公告），详情留空标题并保留调用方标题，公告排进 notice | **已同步**：`KugouLiveRoom` 新增 `notice`；详情用 `fillFromDetail(liveroom)` 保留卡片标题 |
| 29-3 | 搜索行只在直播中且大于 0 时计观众数 | 未做：待核 |
| 29-4 | 手机分享页 `mfanxing.kugou.com/...?roomId=` 也识别为房间 | 未做：链接解析 |
| 29-6 | 聊天/限制/目录文案改写 | 未做：文案 |
| 29-5 | 酷狗直播弹幕本体（3.x 与 v4 归档都没有，靠站点脚本与匿名只读会话逆出） | 未做：整套新引擎，属新功能批次 |

## pandalive

上游相关提交：`50d9e9fd4`、`fc5008aa8`、`dd06718f6`（M4.U.25）。

| 项 | 内容 | 本仓状态 |
| --- | --- | --- |
| `50d9e9fd4` | Amazon IVS 的 variant 播放列表 URL 会过期（实测 34 分钟还能取、87 分钟已 403），线路要带"签发后 30 分钟刷新"的租约 | **已同步**：`PandaLiveSite` 实现 `LivePlayLeaseMetadata`，解析时记录签发时间；令牌不透明，只有刷新时间、没有失效时间 |
| `fc5008aa8` | 在播但 `onAirType`/`liveType` 为 `rec` 的是录播重播（标题带 `[녹]`）：状态是回放，照常可播 | **已同步**：`isRerun` 进两个模型，目录卡与详情都按回放上报（3.x 显示为直播中） |
| 25-1 / 25-3 / 25-4 / 25-5 | 目录补新主播区、`playCnt` 记入累计观看、房间链接改 `/play/<id>`、清晰度 id 去掉 30fps 后缀且原画在前 | 未做：目录/字段/链接与画质命名，需逐条对照 |
| 25-2 | 弹幕参数 `PandaLiveDanmakuArgs`（`getDanmaku()` 仍是空） | 未做：本仓 pandalive 没有弹幕引擎 |
| `19f59f525` | 房间公告去掉"远端聊天尚待接入" | 无需：本仓确实还没接 PandaTV 聊天，公告与现状一致 |

## picarto

上游相关提交：`f12fb7262`（M4.U.11）、`664aaf5b6`、`863bbf99c`（弹幕）。

| 项 | 内容 | 本仓状态 |
| --- | --- | --- |
| 11-5 | 搜索卡片的简介取资料 `bio`（HTML 实体解码） | **已同步**：`_bio()` |
| `664aaf5b6` | 房间 id 用平台自己的拼写（`TheBaker`），否则关注身份对不上 | 无需：本仓已用详情返回的 `name` 作 `roomId`/`nick` |
| 11-1 | 恢复播放时若播放列表已没有所请求的档位，播最好的一档并如实上报 | 未做：恢复路径的档位回退 |
| 11-2 | 关注刷新不再查边缘/multistream/流名（进房与录制仍查） | 未做：请求深度 |
| 11-3 | 坏分区/探索行/别的分区行/坏搜索结果直接跳过 | 未做 |
| 11-4 | 清晰度按高度再按码率排序，「HLS Auto」显示为「自动」 | 未做 |
| 11-6 | 下播详情用自己最后一场的缩略图当封面 | 未做 |
| 11-9 | 私密频道按 private 限制展示 | **已同步**：不再抛 access，房间照常返回并标 `LiveRestriction.private`（`private` 字段不是布尔才留 null），私密频道也不去问播放列表 |
| `863bbf99c` 等 | Picarto 弹幕本体 | 未做：新功能批次 |

## niconico（本轮仅评估）

上游 11 个提交里，站点侧是两类大改动，不适合零散摘取：

- 17-1 / 17-2：**房间即主播**（`user/<id>`、`ch<n>`，官方节目保持 lv；
  列表与搜索按 `providerType` 映射，链接还要认 http、`sp.live.nicovideo.jp`
  与 `nico.ms`）。这是身份模型改动，牵动本仓的房间身份、关注与历史。
- `bc9e8dd89` / `67dba6d24` / `6c5ded04c`：NDGR 评论引擎与公告/礼物，
  本仓 niconico 的弹幕是 v3 的评论实现，要换就得整套接。

因此 niconico 留待"身份模型"或"弹幕新功能"批次，与 youtube 的频道模型一起做。

## missevan

上游相关提交：`e0495b3e5` 一类（M4.U.13，13-1 至 13-4）。

| 项 | 内容 | 本仓状态 |
| --- | --- | --- |
| 13-1 | 只有一档「原画」（id 10000），线路是 FLV 在前、HLS 作为备份 | **已同步**：此前拆成 HLS/FLV 两个档，界面上是两个条目，档内也没有 FLV→HLS 回退 |
| 13-1 | 每档线路带 `expires` 租约 | 无需：本仓 `MissevanSite` 早已实现 `LivePlayLeaseMetadata` |
| 13-2 | 弹幕参数 `MissevanDanmakuArgs`（`getDanmaku()` 仍是空） | 未做：本仓没有 Missevan 弹幕引擎 |
| 13-3 | 目录按 namespace 分组（分区 / 团播） | 未做 |

## kilakila

上游相关提交：`47f0e2ac8` 一类（M4.U.15，15-1 至 15-4）。

| 项 | 内容 | 本仓状态 |
| --- | --- | --- |
| 15-1 | 资料卡没有在播节目、以及 status 10（已结束）按未开播处理，其余未知状态保持 unknown | **已同步**：三处（资料详情、资料卡、房间快照） |
| 15-2 | 在播房用 `onlineNumber` 当在线人数、`watchNumber` 当累计听众 | 未做：本仓目前 `watching` 留空、观众口径 unknown |
| 15-3 | 时间线在第 100 页 / 空页 / 连续 3 页没有新主播时结束 | 未做：分页终止条件 |
| 弹幕 | KilaKila 弹幕本体（礼物、付费提问） | 未做：新功能批次 |

## weibo

上游相关提交：`de3404bbe`（M4.U.18，18-1 至 18-9）。

| 项 | 内容 | 本仓状态 |
| --- | --- | --- |
| 18-1 | 推荐快照请求 `count=100`（约 51 行） | **已同步**：此前 `count=10` |
| 18-2 | 快照里的卡片都是在播 | **已同步**：目录卡片按直播中上报，此前一律 unknown |
| 18-3 | `status` 5（已结束）是下播 | **已同步**：`WeiboBroadcastState.offline` |
| 18-4 | 受限/关闭的房间保留状态并带限制种类（appOnly/私密/付费） | **已同步**：状态不再被改成 unknown；`watch_limit` 8→appOnly、10/11→private、12→paid、其它→unplayable，关闭播放→unplayable；公开但在播无地址/回放无录像→unplayable |
| 18-5 | 公开回放播 `replay_origin_url`，作为「原画」档（id replay） | 未做：回放取流 |
| 18-6 | 头像优先 1024px；标题与昵称解码 HTML 字符引用 | 未做 |
| 18-8 / 18-9 | 坏行逐条跳过；分享文本与搜索里的 t.cn 短链解析 | 未做 |
| 18-10 | 关注主播 | 上游也阻塞（需要访客 cookie） |

## steambroadcast

上游相关提交：`42067b5d7`（M4.U.27，27-1 至 27-7）。

| 项 | 内容 | 本仓状态 |
| --- | --- | --- |
| 27-1 | 头像用 184px 的 `<hash>_full.jpg`，Steam 默认头像（问号）视为没有头像 | **已同步**：`_avatar()` 重写，此前只认 `avatars.akamai.steamstatic.com` 且原样返回 32px 地址 |
| 27-2 | 名字与头像取 mini profile，标题/游戏/封面取 getbroadcastinfo；占位文案留空 | 未做：请求编排 |
| 27-4 | `/profiles/<id>` 直接是房间；`/id/<name>` 经 `?xml=1` 解析 | 未做：链接解析 |
| 27-5 | 记住的卡片只在房间直播中填补观众数 | 未做 |
| 27-7 | 校验过的 master 每个 variant 加一档（1080p60、720p…） | 未做：清晰度分档 |
| 限制/状态 | `user_restricted` 按封禁、`missing_subscription` 按订阅可见、`is_replay` 按回放 | **已同步**：`user_restricted`→banned、`missing_subscription`→在播+subscribersOnly、`is_replay`→replay（回放也用平台给的 master） |

## liveme

上游相关提交：`996421c3e`（M4.U.21，21-1 至 21-8）。

| 项 | 内容 | 本仓状态 |
| --- | --- | --- |
| 21-4 | 搜索行 `is_live` 0 对所有 project 都是未开播 | **已同步**：此前只信主 liveme 项目的 0，federated 项目的 0 被留成 pending |
| 21-3 | 直播房间简介取资料的 `usign` | 未做 |
| 21-5 | 去掉 `LiveMeState.restricted`：私密/付费是在播 + 限制种类 | **已同步**：`ispvt` 1 → private、`livebptype` 7 或 Paid broadcast 标签 → paid；受限仍照常列出，受限时不读流 |
| 21-8 | `wsABStime` = 开播时间 + 10h/24h | **已同步**：`vtime` 读作开播时间（秒或毫秒，UTC） |
| startedAt / 限制 | 统一规则里的 `vtime` 开播时间与 none/private/paid | **已同步**（见 21-5 / 21-8） |

## showroom

上游相关提交：`021709665`（M4.U.19，19-1 至 19-4）。

| 项 | 内容 | 本仓状态 |
| --- | --- | --- |
| 19-4 | 未开播的房间没有观众数（`view_num` 是上一场残留） | **已同步**：详情里非在播时清空 watching/totalViewers |
| 19-x | 直播详情在 `danmakuData` 带 `live_info`（主机限 showroom-live.com） | 未做：弹幕参数 |
| 19-x | 限制 none/其它（非 0 时留 null）与 `current_live_started_at` | 限制 **已同步**（`premium_room_type` 0→none，其它留 null，不猜成付费）；`current_live_started_at` **已同步**（`/api/room/profile` 里给了就读，转 UTC；该字段只在直播详情出现，读不到即 null） |

## fc2live

上游相关提交：`cb4f450af`（M4.U.26，26-1 至 26-9）。

| 项 | 内容 | 本仓状态 |
| --- | --- | --- |
| 26-8 | 未开播的详情没有观众数 | **已同步**：非在播时清空 watching/onlineViewers/totalViewers 与观众口径 |
| 26-1 / 26-2 | 清晰度按档位（`fc2live:<channel>:<id>`）与 `hlsPlaylists` 读全部播放列表 | 未做：清晰度发现 |
| 26-9 | 受限直播是在播 + 限制（`is_limited`），播放被拒 | **已同步**：`is_limited`→unplayable、`fee`/`ticketid`/`ticket_only`→paid、`login_only`→needsLogin（目录行看 `pay`/`tid`/`login`）；受限时状态为**直播**而非未知 |
| 其它 | startedAt（`start_time`/`start`）、控制权交接 | startedAt **已同步**（在播时带入 `LiveRoom.startedAt`）；控制权交接未做 |

## bigo

上游相关提交：`f4688d9f7`（M4.U.24，24-1、24-2、24-4 至 24-7）。

| 项 | 内容 | 本仓状态 |
| --- | --- | --- |
| 24-1 | 房间封面是直播间截图（下播时是上一场那张），头像仍是头像并作为封面兜底 | **已同步**（详情路径）：新增 `BigoStudioRoom.snapshot`，封面优先用它；此前封面直接拿头像，卡片显示的是主播头像而不是画面。目录卡片按上游同样是 cover 即 avatar，无需改 |
| 24-2 | 上锁的列表行仍列出、在播并标 password；`passRoom`/`isPaidShow` 是在播 + 限制 | **已同步**：登录→needsLogin、密码房→password、付费房→paid、公开但无播放地址→unplayable；受限房状态改为**在播**（此前为未知） |
| 24-4 / 24-5 | 令牌复用（关注刷新与状态检查复用 30 分钟）与目录列表 30 秒缓存 | 未做：请求编排与缓存 |
| 24-6 | 坏行/重复行只丢自己 | 未做 |

## sixroom

上游相关提交：`8e55bea2c`（M4.U.31，31-1 至 31-5）。

| 项 | 内容 | 本仓状态 |
| --- | --- | --- |
| 31-3 | 搜索卡片带页面直播标记（`i.live`）为在播；没有标记但链接指向 `/profile/` 为未开播；否则未知 | **已同步**：此前一律 unknown |
| 31-1 | 详情与刷新用主播自己的头像（`inroom roominfo.uoption.picuser`） | 无需：本仓已用 `headPicUrl`/`picuser` |
| 31-2 | 详情标题在名字之前先退到主播签名 | 未做 |
| 31-4 | 推荐与歌/舞/聊/派对分区改用 App 移动端列表 | 未做：目录来源 |
| 31-5 | 记忆卡片的流行度/开播时间/限制只在同一场直播在播时使用 | 未做 |
| 统一规则 | 私密/黑屏是在播 + 限制（不是未知/下播） | **已同步**：私密 → private、黑屏 → unplayable，状态改按**在播**上报（此前是未知） |

## seventeenlive

上游相关提交：`6d4743f84`（M4.U.33，33-1 至 33-7）。

| 项 | 内容 | 本仓状态 |
| --- | --- | --- |
| 33-6 | `www.17.live`（会跳到 17.live）也是房间链接 | **已同步**：此前只认 `17.live` |
| 33-5 | 只有 `<scheme>://…` 才算网址，`Re:Zero` 这类带冒号的关键词要搜；关键词超过 100 个 UTF-16 单元截断（不切断代理对） | **已同步**：此前任何带 scheme 的都当网址（`Re:Zero` 搜不到），超长关键词直接返回空 |
| 33-1 | 目录按地区（JP/TW/HK）与 sections 接口 | 未做：目录来源 |
| 33-2 | 3.x 的 standard 就是主播源流：id `source`、名为「原画」、sort 500 | 未做：本仓仍是 standard/100，需要与 id 迁移一起做 |
| 33-7 | 在播时 `startedAt` 取 `beginTime` | **已同步**：`beginTime`（秒/毫秒自适应 → UTC）在直播时填进 `LiveRoom.startedAt` |
| 限制 | `premiumContent` 锁定的直播是在播 + 限制（有源但不播） | **已同步**：`premiumType` 1→paid、2→subscribersOnly、其它→unplayable（0 或被 `paymentInfo.paid` 解锁→none，读不出来→null）；锁定时状态仍是**直播** |

## acfun

上游相关提交：`bd9760d7e`（M4.U.10，10-1 至 10-5）。

| 项 | 内容 | 本仓状态 |
| --- | --- | --- |
| 10-2 | 目录不列「全部」（filter 0，它与推荐相同）；存下来的「全部」分区按推荐（不带 filter）读取 | **已同步**：`allFilterId` + 分类过滤 + 目录请求不带 filter |
| 10-1 | 资料链接（`www.acfun.cn/u/<id>`、`acfun.cn/u/<id>`、旧 `.aspx`、`m.acfun.cn/upPage/<id>`）直接是房间 | 未做：链接识别（另一层） |
| 10-3 | 列表/进房/刷新/录制详情的 `startedAt` 取 `createTime` | **已同步**（进房/刷新路径）：在播时 `createTime`（epoch 毫秒）填进 `LiveRoom.startedAt` |
| 10-4 / 10-5 | 弹幕参数 `AcfunDanmakuArgs`；付费节目是在播 + 限制 | 付费限制 **已同步**（`paidShowUuid` 存在且未购买 → paid，在播 + 限制）；弹幕参数**不做**（按范围决定，不新增弹幕引擎） |

## baidulive

上游相关提交：`646cd5fd8`（M4.U.30，30-1 至 30-10）。

| 项 | 内容 | 本仓状态 |
| --- | --- | --- |
| 30-9 | `flv-live.bdstatic.com` 必须用 http 播（它的 https 证书与主机名不匹配） | **已同步**：该主机保持/降为 http，其余允许主机仍 http→https |
| 30-8 | http 房间链接也接受（默认端口按 scheme 判定） | **已同步** |
| 30-1 / 30-2 | 清晰度按档位（原画 + 各高度），平台当前 CDN 作为备份线路；H.265 单列一档 | 未做：清晰度发现 |
| 30-4 | 已结束的直播是回放，播它的录像（`replay_list`/`video_hevc`） | 未做：回放取流 |
| 30-5 | 付费/禁止/封禁保留状态并标 paid/unplayable | **已同步**：禁止访问/封禁→unplayable、付费→paid、在播或回放却没有档位→unplayable、其余→none；这些不再把状态改成"未知"（详情路径） |
| 30-6 / 30-7 | 推荐与 rec 频道各自独立 feed 会话；简介取 `video.description` | 未做 |

## twitcasting

上游相关提交：`cbff9fd76`（M4.U.12，12-1 至 12-5）。

| 项 | 内容 | 本仓状态 |
| --- | --- | --- |
| 12-1 | 房间标题取直播的 telop（播放器标题下方那行，排除话题标签），没有才退 `twitter:title`；`twitter:description` 不再作退路 | **已同步**：此前只读 `twitter:title`，于是播放页标题永远是 "Live #…" 而不是主播写的 telop |
| 12-2 | 关注刷新与状态检查只问 `streamserver.php`（约 1KB，而非 110KB 频道页） | 未做：请求编排 |
| 12-3 | 直播详情在 `danmakuData` 带 `TwitcastingDanmakuArgs` | 未做：弹幕引擎 |
| 12-4 | 搜索一次请求，之后按关键词 30 秒快照裁剪 | 未做：分页缓存 |
| 12-5 | 私有直播在搜索里是在播 + 限制 | **已同步**：搜索行按播放包装与徽章判定 none/private/unplayable；不是"正在直播"的行不列出，坏行只丢自己（此前一行坏数据会让整页搜索失败）。要"合言葉"的直播也不再抛 access，而是返回带 `password` 限制的房间 |

## jdlive

上游相关提交：`c315d897e`（M4.U.28，28-1 至 28-7）。

| 项 | 内容 | 本仓状态 |
| --- | --- | --- |
| 28-2 | 播放回答里没有的名字就留空：不编 "JD Live"、不把直播 id 当店铺账号、不拿封面当头像 | **已同步**：`nick`/`title` 不再写占位，详情靠列表卡片的记忆（`enrich`）补齐 |
| 28-3 | 封面是列表卡片的 `indexImage`；播放回答的 `blurredImg` 是背景图 | **部分同步**：不再把 `blurredImg` 当封面（卡片封面经 `enrich` 保留）；背景字段本仓模型没有 |
| 28-1 | 精选列表的分页（`currentCount` 前进、空页结束） | 未做：分页 |
| 28-4 / 28-5 | FLV 退到 `pcVideoUrl`；线路带网页媒体头 | 未做 |
| 统一规则 | status 3 是回放并播 JD Cloud 录像；appOnly 是在播 + 限制 | **appOnly/unplayable 已同步**（`secret` 1 → appOnly；在播无地址 → unplayable，此前直接抛 schema）；**回放取录像仍未做**（需要新的录像字段与解析） |

## looklive

上游相关提交：`fc65a5286`（M4.U.32，32-1 至 32-6）。

| 项 | 内容 | 本仓状态 |
| --- | --- | --- |
| 32-2 | `liveStatus` `-10`（FORBID）与 `-4`（违规整改）是封禁，`-2` 是未开播（3.x 一律 unknown） | **已同步**：`LookLiveState.banned` 取代 `restricted`，状态查询本身不再当未知 |
| 32-1 | 合并目录记住每个列表结束的页，不再重复请求 | 未做：分页缓存 |
| 32-3 / 32-6 | 线路带网页媒体头；坏地址只损失那一条线路 | 未做 |
| 32-4 / 32-5 | 列表卡片的流类型取 `liveData.type`；记忆卡片只在直播中填热度与观众数 | 未做 |

## inke

上游相关提交：`26fa56da3`（M4.U.14，14-1 至 14-6）。

| 项 | 内容 | 本仓状态 |
| --- | --- | --- |
| 统一规则 | 去掉 "UID <uid>" 这类占位名 | **已同步**：详情缺名字时留空，不编占位 |
| 14-1 / 14-2 | 推荐与昵称搜索改读 App 热榜（`simpleall`） | 未做：目录来源 |
| 14-3 | `numbers.real` 是并发观众、`online_users` 是热度 | 未做：需要新字段与解析 |
| 14-4 | 进房/刷新/录制补 App 的 `now_publish`（标题、封面、观众、开播时间、线路） | 未做 |
| 14-5 | Zego 原始流（HEVC）作为「原画」档 | 未做：清晰度发现 |
| 统一规则 | `startedAt`、限制 none（App 给线路时） | `startedAt` **已同步**（详情 `start_time` → UTC）；限制种类未做（需要新字段） |
| 统一规则 | 去掉占位标题「正在直播中」 | 无需：本仓未使用该占位 |


## xiaohongshu

上游相关提交：`fc41c1a1d`（M4.U.16，16-1 至 16-4）。

| 项 | 内容 | 本仓状态 |
| --- | --- | --- |
| 16-1 | 分享页 `pageStatus: error` 就是平台自己的「房间不存在」（等价 404）：搜索遇到它返回空，进房与刷新仍如实报 NotFound | **已同步**：此前一律当成笼统的 api 失败，于是搜索一个不存在的房间会抛错而不是返回空 |
| 16-2 | App 深链只要求恰好一个 `room_id`，`source` 不再必需 | **已同步** |
| 16-3 | 每个 `quality_type` 一档（HD，页面叫「原画」），线路是 H.264 在前、H.265 在后，各编解码内 FLV 先于 HLS | 未做：清晰度发现 |
| 16-4 | 破坏规则的拉流行被跳过 | 未做 |
| 16-5 | 主播资料 | 上游也阻塞（重定向到验证码/登录页，网页直播 API 无签名返回 406） |

## tiktok

上游相关提交：`0e2a4ed03`（M4.U.22，22-1 至 22-7）。

| 项 | 内容 | 本仓状态 |
| --- | --- | --- |
| 22-5 | 搜索跟短链跳转（`vm.tiktok.com` / `vt.tiktok.com`，最多 3 次） | **已同步**：此前 `isShortHost` 有定义但从没被用过，粘贴短链既不是官方链接也不是用户名，什么都搜不到 |
| 22-6 | 只填卡片的字段不再让整次回答失败；坏容器/坏档位/坏地址只损失它自己 | **已同步**：容器级与地址级各自容错，坏地址只丢那条线路 |
| 22-1 | 受限直播（私密账号/订阅可见/付费）是在播 + 限制种类，播放时说明谁可以看 | **已同步**：`TikTokState.restricted` 取消，改为 `LiveRestriction.private/subscribersOnly/paid`；受限时不读流，播放时按种类说明原因 |
| 22-2 / 22-4 | 每个档位+编解码一档，FLV 先于 HLS，按站点命名（`options.qualities`、原画、` · H.265`） | 未做：清晰度发现 |
| 22-3 | `preferH264`（默认开）把 H.264 档位排前 | 未做 |
| startedAt | 在播时取 `liveRoom.startTime` | 未做：`LiveRoom` 缺字段 |
| 22-8 | 匿名目录接口 | 上游也阻塞（需要签名或登录） |

## 模型扩展批次（startedAt / restriction）

4.x 把两个跨站点的字段做进了 `LiveRoom`，本仓此前没有，于是十几个站点的条目都卡在这里。
本轮已把模型与消费端补上：

| 部分 | 内容 | 状态 |
| --- | --- | --- |
| 模型 | `LiveRestriction { none, needsLogin, paid, subscribersOnly, private, appOnly, regionBlocked, password, adult, unplayable }`，按 **名称** 存进 JSON（不认识的名称读成 `none`，可任意新增） | **已完成** |
| 模型 | `LiveRoom.startedAt`（UTC，JSON 支持 ISO 8601 与 epoch 毫秒）与 `LiveRoom.restriction`、`effectiveRestriction`/`isRestricted`；`copyWith` 与 `fillFromDetail` 都会带上（详情没提时保留手上那份） | **已完成** |
| 播放 | 房间播不了时按限制种类给文案（登录/付费/订阅/私密/仅 App/地区/密码/成人/无可播流）；受限直播在取流阶段的失败也会给出原因，不再只是静默置为失败 | **已完成** |
| 文案 | `restriction_*` 九个键（zh + en） | **已完成** |
| 站点 | **tiktok** 已接入（22-1）。其余站点按各自上游行继续接（见各站点小节） | 进行中 |
