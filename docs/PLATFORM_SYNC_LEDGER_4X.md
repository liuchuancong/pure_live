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

### F. 用户提示（错误/状态）同步清单（用户 2026-10-04 追加要求："用户提示也同步一下，比如出现了什么错误"）
| 上游提示 | 本仓现状 |
| --- | --- |
| Twitch「Cookie 已失效，已改为匿名接收，请重新填写」 | **已做**：`NOTICE … Login authentication failed / Login unsuccessful` → `LiveMessageType.notice`（一次 connect 一次），并让后续握手改用匿名（`i18n: twitch_cookie_expired_notice`） |
| 虎牙「直播已结束」（`EndLiveNotice`） | **已做**（`133725ed7`） |
| B 站警告 / 切断直播 | **已做**（`6e79b8bda`） |
| B 站「访客/登录失效」昵称提示条 | **已做**（`c2aca612b`） |
| 各站 danmaku 关闭原因（`DanmakuCloseReason` + detail，如 `Broadcast ended`） | **部分**：各引擎有 `onClose("服务器连接失败…")`；未逐站对齐上游文案 |
| 握手失败钩子（`f12bf0f8c`，`onHandshakeFailure`：可换新会话头重试） | **架构不同**：上游是 5.x 的 `DanmakuSocketConnection`，本仓是 `WebScoketUtils`；本仓无"失败后换头重试"通道（missevan 之类靠会话续期的站点用得上） |
| 各站聊天连接器的 notice（17LIVE 暂停/结束、Picarto chip tips、missevan、CHZZK 等） | **不适用**：这些站点在本仓没有引擎（用户早前决定不新增引擎，待确认是否改为全做） |

## 待实施：虎牙 2001314 通知自带留言板面板（C-9，省请求）

上游 `5a9fa6a5e` 的取法（**已从上游测试的写入器逐字段抄下，可直接照做**）：

```
uri 2001314 的消息体就是一个 GameEventMessageBoardPanel：
  tag 0: 头部 struct { tag 2: int 0 }
  tag 1: 条目列表，每条：
      0: struct 用户 { 1: 昵称(string), 2: '' }
      1: 文本(string)
      2: 花费(int)
      4: 累计(int)
      5: 倒计时(int)
      9: 留言 id(int)
  tag 2: int 0
```

规则：
- 能解出 `tag 1` 是列表 → 它就是面板：**每条留言立刻作为醒目留言上报**（与补拉共用"每次连接只报一次"），
  **空列表表示留言板已空，不再发请求**
- 消息体缺失/为空/不是 Tars/没有 tag 1 列表 → 照旧后台补拉（0、0.6、1.8、4 s 的窗口，本仓已有）
- 本仓要动的地方：`huya_danmaku.dart` 的 `uri == 2001314` 分支（现在只调
  `_scheduleSuperChatRefresh`）+ 用本仓自己的 Tars API 读面板：
  - 根：`TarsInputStream(Uint8List.fromList(payload))`；条目列表
    `stream.readList<_Entry>(<[_Entry()]>, 1, false)`（`readList` 内部用模板实例的
    `readFrom` 逐个解码，见 `lib/core/tars/codec/tars_input_stream.dart:554`）
  - 嵌套用户 struct：`_User()..readFrom(TarsInputStream(s.readBytes(0, false)))`
    （与既有生成代码同一手法，见 `huya_danmaku.dart` 里读 push 的 `readBytes`）
  - 需要一个只读的 `TarsStruct` 子类（`readFrom` + 占位的 `writeTo`/`displayAsString`）
  - 条目字段 → 复用 `huya_utils.dart:76-86` 的映射（`messageId: 'huya:<tag9>'`、
    `startTime = now + countdown - total`、`endTime = now + countdown`、`price = cost`、
    `userName = 昵称`、`message = 文本`），再走既有的 `_rememberSuperChat` 去重与上报
  - 解析失败/没有 tag 1 列表 → 照旧补拉（try/catch 包住，异常不影响既有路径）
- 价值：每条通知少 1–4 个 HTTP 请求（**是优化不是修复**）。停在这一步的原因：字段索引
  虽已从上游测试的写入器逐字段抄下，但本仓**没有 S19-headline 那样的 fixture** 可验证；
  加上 `readBytes` 对 STRUCT 的边界行为未实测，盲写有把"面板解错"当成"面板为空"的风险
- 所以它排在 ④/③ 之后，且**建议先用上游 fixture 做一个本仓测试**再实现

## 聊天引擎移植（用户 2026-10-04 指令"开工"后新增批次）

上游为 EmptyDanmaku 站点写的聊天引擎逐个移植；每站：传输/连接器 + 消息解析 + 列表与画面
显示（复用已有的 `LiveMessageType`/通知/撤回管线）+ 尽量补测试。

| 站点 | 上游提交 | 本仓状态 |
| --- | --- | --- |
| **Baidu Live** | `cdb9504e3`（M5.26） | **已做**：`baidu_live_danmaku.dart` 轮询房间命令给的 HLS 风格消息列表（m3u8 → gzip JSON 分片），文本 / 在线人数(101) / 礼物(107 + `service_info`，`BaiduLiveGift`) 三类；`BaiduLiveApi.danmakuArgs()` 从房间命令取三条列表与轮询间隔（1–10 s，缺省 5 s），站点 `danmakuData` + `getDanmaku()` 接上；分片按地址去重、失败重试 3 次、主播列表 404 容忍 |
| **TwitCasting** | `a4cb9a72e`（M5.11） | **已做**：`twitcasting_danmaku.dart` 每次握手先 POST `eventpubsuburl.php`（表单 `movie_id`）换一条带签名的 wss 地址（只收 `wss://…twitcasting.tv/…`），再连；帧是 JSON 数组（或单个对象），只上报 `comment`（`message` 去空白、用户名 `author.name` → `screenName`、id 加 `twitcasting:` 前缀、`createdAt` 毫秒），按事件 id 去重 400 条；30 秒无消息换 socket、失败按 1–8 秒退避重取地址；站点把详情的 `movie.id` 放进 `danmakuData` |
| **Six Rooms（六间房）** | `3a6825c91`（M5.27） | **已做**：`six_room_danmaku.dart` 先 `GET /room/getChat.php?rid=<主播用户 id>` 取 `*.6rooms.com` 服务器列表（`host:port`，去重、只收该域名），逐个 `wss://host:port` 尝试；打开后发 `command=login`（1800000000–1899999999 随机游客号、`encpass` 空、`roomid` 是主播用户 id），**6 秒登录时限**换下一台；登录成功后 1 秒开始、之后每 16 秒发网页的 `noop` 心跳（`y8vPLwAA`）；下行 `enc=yes|no` + Base64（`enc=yes` 是**原始 DEFLATE**，Base64 里 `+ / =` 写成 `( ) @`），解 JSON 后按 `typeID` 取公聊（101、110/1413 列表）与飞屏（108）；文字先 `&amp;`→`&` 再解字符引用、去空白；被踢/人满/付费/密码/禁止/关房等 flag 以失败结束不重连。站点把 `userId`/`roomId` 放进 `danmakuData` |
| **Steam 广播** | `3a9914ad8`（M5.23） | **已做**：`steam_broadcast_danmaku.dart` 照观看页**轮询**：需要时先 `getbroadcastmpd`（拿这一场 id 并把 `num_viewers` 报成在线人数）→ `getchatinfo` 取聊天日志地址模板 → 读窗口 0（历史，**算加入但不报**）并按 `initial_delay`/`next_request` 对时 → 之后每个窗口在"聊天日志的时钟"走到时才请求（失败按 10 ms 推后、最多 1 s；连续 8 次失败就重新找这一场）；每行取 `msg`（去空白）、`persona_name`、`steamid`（平台不给消息 id 与时间）；聊天日志地址只收 https/443 + `steambroadcast*.akamaized.net` 或 Steam 域名。站点把 `steamId`/`broadcastId` 放进 `danmakuData` |
| **FC2 LIVE** | `ecfea58fb`（M5.22） | **已做**：`fc2_live_danmaku.dart` 复用 M4.26 的媒体控制 socket——**每次握手都取新授权**（`Fc2Api.controlGrant`：`memberApi.php` + `getControlServer.php`），带 `control_token` 与 `Cookie: l_ortkn=<orz_raw>` 连；`connect_complete` 算加入；`comment` 里的评论丢掉历史（`history: 1`）与系统评论、按服务端推的 NG 表过滤，颜色按网页名字表取；`user_count` 电脑+手机（在线=onlineViewers、累计=totalViewers，只报变化）；`control_disconnection` 换新授权重连；心跳是网页的 `{"name":"heartbeat",…}` 文本帧（30 s） |
| **PandaTV（neolive）** | `2a6b552b2`（M5.21） | **已做**：`pandalive_danmaku.dart` 连 Centrifugo 3.1.1（`wss://chat-ws.neolive.kr/connection/websocket`，JSON）：`connect`（令牌 + `name: js`）→ `subscribe` 频道，回复到了才算加入；心跳是命令 7、id 从 3 往上数、每 25 秒；频道推送 `{"result":{"channel":…,"data":{"data":<消息>,"offset":<序号>}}}` 里只报聊天（`bj`/`chatter`/`manager`/`support`），消息 id 是 `<频道>:<序号>`；**令牌到期前 60 秒**重新取令牌并悄悄换 socket。站点侧：`PandaLiveRoom` 新增 `chatChannel`/`chatToken`（来自 `live/play`，channel 不是数字时用主播编号），进 `danmakuData` |
| **BIGO LIVE** | `51ca7deda`（M5.20） | **已做**：`bigo_danmaku.dart` 连 `wss://wss.bigolive.tv/live/official/web`（**文本**帧：事件号 + JSON）——游客账号由 `getWebSocketLink` 取一次（断线沿用、被拒重取），按网页顺序：回答质询（MD5 签名，`60#4#5#<秒>#1#1#1#1#` + 质询后 8 字）→ 1 秒后登录（`uidToken` 去掉 `###VER2`）→ 进房 → 要一次观众数（`total` → onlineViewers）→ 每 10 秒 ping；房间广播 2584 的 `payload.content`（Base64 + UTF-8 JSON）按 `tag` 1/2 报聊天（`{"n":名字,"m":文字}`），其它事件不报。站点：`siteId`/`ownerId`/`roomId` 进 `danmakuData`（在播、有房间号、非密码房） |
| **SHOWROOM** | `a30d7aedd`（M5.15） | **已做**：`showroom_danmaku.dart` 连 `wss://<bcsvr_host>/`，打开后发 `SUB\t<key>` 订阅（服务端**不确认**，收到 `MSG` 才算通），每 60 秒 `PING\tshowroom`（服务端回 `ACK`）；下行 `MSG\t<键>\t<JSON>`，只处理本场键与 `t` 1 的评论（`cm` 文字去空白、整数照写、`ac` 名字、`u` id、`created_at` 秒、`cl` 等级）；礼物/字幕/系统/开播下播不报。站点侧：`ShowroomApi` 新增 `commentServer()`（`live_info` 的 `bcsvr_host`/`bcsvr_key`，主机限 `showroom-live.com` 子域、键 ≤256 字且不含空白/控制字符），进 `danmakuData` |
| **CHZZK** | `00da1b768`（M5.16，含 `e1c4a3fa3`） | **已做**：`chzzk_danmaku.dart` 照网站聊天 SDK——访问令牌（`chats/access-token`，最多 3 次、间隔 0.5/1 秒，拿不到就报"拿不到令牌"并结束）+ 路由表（`routing/getRouting`，只收 `*.chat.naver.com`、去重、最多 16 台）→ 只读加入（`cmd 100`，`auth: READ`）→ 每 20 秒 ping；被拒加入（302–304）或 90102 结束这一轮；只报种类 1/10/11 且状态 `NORMAL` 的行（名字取 `profile.nickname`、文字 `msg`/`content` 去空白）。站点侧：`ChzzkLive` 新增 `chatChannelId`（`live-detail`，仅开播时），进 `danmakuData` |
| **Picarto** | `1efcc80c8`（M5.10）+ `7eb985f24`（B-8） | **已做**：`picarto_danmaku.dart` 先向 GraphQL 要**匿名 JWT**（`generateJwtToken`），再连 `wss://chat.picarto.tv/chat/token=<JWT>`（服务端自己保活，**无客户端心跳**）；帧按 `type`/`t`：`stream` → 并发观众，`c`/`ct`/`system` 是若干行（按行的 `t` 分：聊天、**打赏即醒目留言**（`x` 筹码、60 秒、`rn` 是别的频道时前缀"打赏给 X："）、系统通知），`raid`/`ns` → 通知，`rm`/`cm` → **撤回**（按 id / 按用户），`{"success":false,"code":"JWT_TOKEN"}` → 换令牌重连（最多 3 次）。站点侧：`danmakuData` 给频道名（在播时） |
| **KilaKila（克拉克拉）** | `644d18e6b`（M5.13）+ `a9f412940`（B-10） | **已做**：`kilakila_danmaku.dart` 实现 Socket.IO 2 over Engine.IO 3 的**游客房间那一小部分**（不引依赖）：连 `wss://wim.hongrenshuo.com.cn/socket.io/?roomId=…&appId=111&clientType=1&EIO=3&transport=websocket`；打开后立刻发命名空间加入 `40/live_chat_room_guest?<query>,`，服务端的 `40` 或 `connect_error` 且 `code==0` 算加入（每个 socket 一次，8 秒没加入换 socket）；每 25 秒发 Engine.IO ping `2`；事件 `42["text_message","<JSON>"]` 里 `body.response.content` 又是 JSON：`t` 200 是聊天（`c` 文字、`n` 名字、`u` id、`l` 等级、`mid` 消息 id、`created_at` 毫秒），`t` 637 是房间状态（`c` 是 URL 编码 JSON 的 `watchNumber` → 在线人数）。站点侧：`danmakuData` 给房间号（在播时） |
| **猫耳 FM（Missevan）** | `700066213`（M5.12）+ `d3409dccf`（B-1/B-9） | **已做**：`missevan_danmaku.dart` 每个 connect 先要游客会话（`api/user/info` 的 `FM_SESS` Cookie，最多 3 次；没有它握手会被拒 403），再连 `wss://im.missevan.com/ws?room_id=<房间>`（详情给了合规地址就用它）；加入是带 uuid 的 JSON 文本帧，服务端按 uuid 回答（`code == 0` 才算加入）；每 30 秒发文本心跳 `❤️`；服务端消息是**二进制帧**（1 字节 flag 1 + 24 位小端长度 + **Brotli** 流），解出 JSON 后按 `type`/`event`：`message`/`new` 与 `message`/`danmaku`（付费弹幕）→ 聊天（等级与粉丝牌都填），`room`/`statistics` → 热度与当前听众，别的房间与其他类型跳过。站点侧：`danmakuData` 给直播间号（在播时）；**2026-10-04 修**：游客会话原先用 dio 的 `headers.value('set-cookie')`，而猫耳同时下发 `FM_SESS` 与 `FM_SESS.sig` 两个 Set-Cookie，多于一个同名值时 dio 直接抛异常，三次重试把异常全吃掉，界面报「拿不到游客会话」。改成逐条遍历整组头（上游 `MissevanDanmakuProtocol.session` 的同款做法），回归测试 `test/shared/platforms/missevan_danmaku_session_test.dart`。**另：猫耳的 FLV 里是一条 16×16 的占位视频 + 正常音轨（日志 `h264 16x16 25 fps`），绿屏就是它被拉伸铺满的结果；上游 4.x 在站点层与播放层都没有针对它的处理，两边表现相同** |
| **17LIVE** | `447e34074`（M5.29）+ `82035a2aa`（B-14） | **已做**：`seventeenlive_danmaku.dart` 实现 Ably 的 JSON 实时协议——匿名令牌来自 `POST /api/v1/messenger/auth`（`provider` 必须是 1 = Ably，否则报"平台换了推送服务"），连 `wss://17media.realtime.ably.net/?format=json&heartbeats=true&v=3`（外加官网三个备用主机，令牌放查询串）；`CONNECTED`(4) 后 `ATTACH`(10) 附着频道、`ATTACHED`(11) 算加入（10 秒时限）、`DETACHED`(13) 重新附着、`DISCONNECTED`(6) 换 socket、`AUTH`(17) 同 socket 换新令牌；心跳由服务端每 15 秒发；`MESSAGE`(15) 的 `data` 是 **base64 + gzip 的 JSON**（`type` 3 评论、`isDirty*` 过滤；38 直播数据 → 在线人数）；令牌错误（40140–40149）丢令牌与 socket，连续 3 次被拒结束。站点侧：`danmakuData` 给房间号（在播时） |
| **AcFun** | `36285b104`（M5.9） | **已做**（三段）：① 站点层补齐弹幕材料——`acSecurity`、`availableTickets`、`enterRoomAttach`、`visitorCredentials()`（`fb8e2179b`）；② 字段级 **protobuf 读写器** `acfun_protobuf.dart` + 7 个单元测试（`2541b88ed`）；③ 新引擎 `acfun_link_danmaku.dart`——12 字节帧头（magic `0xABCD`、版本 1、大端头/载荷长度）+ protobuf `PacketHeader` + 16 字节 IV + **AES-128-CBC**（模式 1 `acSecurity`、模式 2 注册回答的会话密钥，`pointycastle`）；流程：`Basic.Register` → 会话密钥与 instanceId → `Basic.KeepAlive` + 进房（票据）→ 进房回答的 `heartbeatIntervalMs` 决定心跳（每 5 次带一次 keepAlive）→ **push 都回执**；票据错误 {2,3,4,7} 换下一张、全试过或状态变化 {1,2,4} 用 `refresh` 重取会话与票据（最多 3 次）；消息：`ZtLiveScActionSignal` 的 `CommonActionSignalComment` → 聊天，`ZtLiveScStateSignal` 的 `CommonStateSignalDisplayInfo` → 在线人数。站点侧：`getDanmaku()` 改为 `AcfunLinkDanmaku` |
| **JD Live** | `20deb4695`（M5.24） | **已做**：`jd_live_danmaku.dart` —— **每次握手**先 POST 游客 `liveauth`（表单 `loginType`/`appid`/`functionId`/`body`/`t`；`body.content` 是页面脚本里写死的密钥与 IV 做的 **AES-128-CBC + Base64** JSON：`appId`/`secretKey`/`groupId`/`clientType`/`timestamp`/`origin`/`encryptPin`/`random`）换一个**一次性** token，再连 `<liveUrl>?token=`（只收 `jd.com` 的 wss、无 query/fragment/userinfo）；socket 上**什么都不发**，打开就算加入；帧是 JSON 文本（或 `msgMaskKey` 掩码的二进制）：`body.groupid` 必须匹配，`get_statistics_result` → 当前/累计观众（`current_viewer`/`total_viwer`），`chat_group_message` 的 `stop_live_broadcast` → 结束，`viewer_send_message`/`anchor_send_message` → 聊天（`nickName`/`content`/`from.pinmd5`/`id`/`datetime`）；200 秒静默看门狗（服务端 180 秒断）。站点侧：`danmakuData` 给直播间号（在播时）。**已知不确定点**：二进制帧的掩码按"密钥字节循环异或"实现，上游只写"用 `msgMaskKey` 解掩码"；绝大多数帧是文本 JSON |
| **LOOK Live** | `3da78f071`（M5.28） | **已做**（两段）：① 站点层 `LookLiveApi.chatServers()`（`/weapi/livestream/chat/address`，`{liveRoomNo, os: 0}`，回答 `data.address` 的 `host:port`）+ `LookLiveRoom.chatroomId`（`roomInfo.roomId`）+ `LookLiveDanmakuArgs`（`47f7600c5`）；② 新引擎 `look_live_link_danmaku.dart` —— 网易云信聊天室的 **socket.io 0.9**：对每台聊天服务器 `GET https://<host:port>/socket.io/1/?t=<毫秒>` 拿 `<sid>:<心跳>:<关闭>:<传输>`（传输里必须有 websocket），再连 `wss://<host:port>/socket.io/1/websocket/<sid>`；`1::` 打开 → 匿名登录（服务 13 命令 2 的编号属性表），`2::` 回显、每 6 个 30 秒 tick 发链接心跳、90 秒静默换 socket、10 秒登录时限；被拒 408/415/500/503 重连（连续 3 次）否则结束，踢出 13-3（静默 4 除外）结束；消息是 `13-7` 与 `4-10`/`4-11` 包着的聊天——文字（类型 0 + `custom.bizName == 'iplay'`）与表情（类型 100 + `musiclive_server` + `custom.type` 2601），`riskLevelKey` 把关、发送者/等级/粉丝牌从 `content.user` 取。站点侧：`getDanmaku()` 改为 `LookLiveDanmaku`，`danmakuData` 给房间号与聊天室号 |
| **酷狗直播（繁星）** | `8fe5c32bb`（M5.25，含 B-15 颜色） | **已做**：`kugou_live_link_danmaku.dart` —— ① 调度器 `socket_scheduler/pc/binary/v2/address.jsonp`（`_p/_v/pv/rid/clienttime/cid/at` + **MD5 盐 `$_fan_xing_$` 签名取十六进制 8–23 位**）给出主机与 `soctoken`（失败按 1.5/4.5 秒退避重试）；② 二进制帧：18 字节头（magic 100、版本 3、type 1、12、命令、长度）+ protobuf `SocketProtocol.Message`；③ 登录 201（重连 2201 带上次会话）、状态帧 901（type 1 + status 1 带 `socsid`；`errorno` 622 是令牌被拒）、4 字节心跳每 10 秒、10 秒进房时限换下一台；④ 消息 `ContentMessage`（`codec` 1 protobuf / 0 JSON；`compression` 1 gzip / 2 **snappy（自己实现原始块解码）**）：501 聊天（文字去 U+2027–U+202E、等级、粉丝牌、`sinfo.ck` 名客别名、消息 id 回退 `<sender>:<seq>`）、301005 观众数（`count`/`visited`）、601 礼物回执 211。站点侧：`getDanmaku()` 改为 `KugouLiveLinkDanmaku`，`danmakuData` 给房间号。**已知不确定点**：登录请求第 5/8/9 等字段号按上游文档顺序推断，粉丝牌 `intimacyVo` 的字段号（1–4）与 `seq`/`privateType`/`senderrichlevelV2`（12/13/17）取自上游读法；B-15 的按页面上色的颜色未移植（一律白色） |

## 同步状态总览（2026-10-04 第二轮收尾核对）

| 目标项 | 状态 |
| --- | --- |
| ① `startedAt` / `restriction` 各站 + UI + 拒绝路径 | ✅ |
| ② 弹幕撤回（含引擎按条撤回） | ✅ |
| ② 礼物进弹幕区（B 站） | ✅ |
| ② 消息表情图片（模型 / B 站 / 列表 / 画面 / 快手） | ✅ |
| ② 公告头条（B 站 WARNING·CUT_OFF + 虎牙结束直播） | ✅ |
| ② B 站粉丝牌 / 头像 / 昵称提示条（`2eea8022a`） | ✅ |
| ② Twitch 撤回·Cookie 提示·`USERNOTICE`（`51c28301b`） | ✅ |
| ② 搜索按粉丝数排序（`734eb8098`） | ✅（含 Twitch 卡片） |
| ② 播放线路声明图片尺寸 F.1b（`0d63d2d3c`） | ✅ 跨层 |
| ② 握手失败换头重试（`f12bf0f8c`） | **判不适用**（唯一消费者 missevan 会话续期；本仓无该引擎） |
| ② 虎牙公告栏面板（`ff406a24f`） | ✅ 含 5 个测试用例 |
| ④ B 站轮播 `play_time` 起播偏移 | ✅ 5/5（含播放层 seek 通道） |
| ③ YouTube「频道即房间」 | ✅ 身份翻转 |
| ③ niconico「房间即主播」 | ✅ 身份翻转 |

**未做的一项（按用户明确指令排除）**：为 EmptyDanmaku 站点新写聊天引擎——2026-10-04 之前
用户明确说"不需要同步弹幕引擎 只需要同步 site 的弹幕显示即可"；之后"上游有什么本仓库就
添加什么"已被理解为针对站点层与显示层（已全部补齐）。剩下的上游站点层提交**恰好只剩**
6 条 `feat(live_danmaku)` 引擎提交（Picarto / 17LIVE / KilaKila / Kugou / CHZZK / Missevan）
与 4 条上游 docs 提交。若用户确认要连引擎一起做，按站点逐批开工即可（每站：连接器 +
消息解析 + 列表/画面显示 + 测试 + analyze）。

## 取流：线路自描述 + FFmpeg 转封装（2026-10-04 开工）

用户指定方向：**不跟着上游改播放器**，继续用 media_core，需要转的流用 FFmpeg 转好再喂给播放器。

### 上游怎么做的

4.x 把"一条播放线路"做成自描述的 `LivePlayLine`（`packages/live_core/lib/src/play_line.dart`）：
`url` + `headers` + `format`(flv/hls/other) + `codec`(avc/hevc) + `lineId` + `lease`(refreshAt/expiresAt/
cutsConnection) + `width`/`height`。上游自己的注释说得很直白：3.x 把请求头和租约放在播放器里按平台写的
`PlaybackHeaderResolver` 与 `LivePlayLeaseMetadata` 能力上，4.x 让线路自己描述自己，于是"播放器与录制端
不再需要按平台写代码"。上游有 18 个站点声明了 format/codec：baidulive、bigo、bilibili、chzzk、huya、inke、
kick、kilakila、pandalive、picarto、seventeenlive、showroom、sixroom、steambroadcast、twitcasting、twitch、yy。

### 本仓怎么落

不引入 `LivePlayLine`（那要同时动 34 个适配器、契约、播放端与录制端），改为在既有契约上加**每线路事实**：

- `shared/platforms/live_site.dart`：`LiveStreamFormat{flv,hls,other}` +
  `typedef LiveStreamFacts = ({format, codec, relativeChildren})`；`LivePlayUrlResolution.streamFacts`
  （url → 事实；`withSourcePolicies` 会丢掉不属于本次解析的键）+ `factsFor(url)`；走默认解析路径的站点
  实现 `LivePlayStreamFacts.declareStreamFacts(urls)`，契约扩展里自动带上。
- `domains/live/data/stream/live_stream_ingest.dart`：事实 → `IngestNeed` → `IngestPlan`（复用
  media_core_ingest 的 `resolveIngestPlan`）。flv+hevc → `legacyContainer` → **ffmpegRelay**（本机 FFmpeg
  转封装成回环 HLS 再喂 media_core）；hls+relativeChildren → **manifestRelay**；`other` 不当清单去探测；
  其余**直连**——转流要一个进程、一个端口和 1–3 秒起播，不能默认开。
- 已声明的站点：**baidulive**（顺带补上游的 HEVC 档位：档位里的 `hevc_flv` 与源站 `hevc_url`，编码写进线路
  事实）、**twitcasting**（`tc-hls` 的裸名子清单，原来只靠 `playback_ingest_needs.dart` 的主机名表）。
- 测试：`test/shared/platforms/live_stream_facts_test.dart`（10 个用例：判定映射、resolution 只保留本次线路、
  百度 HEVC 档位解析、TwitCasting 声明与"站外主机不声明"）。`flutter analyze` 0 项。

### 接线已落地（2026-10-04）：`interceptSources` 接上，中继真的生效

`domains/live/data/stream/playback_source_transport.dart`（清单探测 + `FfmpegIngestRelay` +
`FlvLegacyHevcRelay` + 租约生命周期）自从播放改走 `media_core_live` 的
`LivePlaybackController.play(LiveSourceRequest)` 之后一直没有调用方：`LivePlayerFacade` 的
`interceptSources` 钩子全仓没人传，`PlaybackSourceTransport(` 也没有实例化点。也就是说直播取流是
URL + headers 直接进引擎，清单改写与 HEVC 转封装都不生效。现在接上了：

- **domain 抽象** `domains/live/domain/playback_source_interceptor.dart`：`PlaybackSourceInterception`
  （候选源 + `streamFacts` + `sourceQueryPolicies`）与 `PlaybackSourceInterceptor`
  （`intercept` / `release` / `close`）。domain 只认这个形状，不认识 FFmpeg。
- **data 实现** `domains/live/data/stream/ingest_source_interceptor.dart`：**只接第一条**线路（内核按顺序
  打开，第一条就是选中的线路，后面几条只是失败兜底；每条都起中继等于 N 个 FFmpeg 进程和 N 个端口）。
  拿到租约就把回环 URI 换进 `PlayerSource.uri` 并丢掉只属于上游的鉴权头；拿不到、起不来或抛异常一律
  **原样直连**，播放不会因为接线变差。`owned:` 配方与本地文件不接线。
- **transport**：旧播放器的原生派发口 `open(nativeOpen:)` 已无调用方，换成
  `prepare({url, headers, facts, policy}) -> PlaybackInputLease?`。决策链不变：声明了事实就信事实
  （省掉每次 HLS 起播的清单探测）；没声明才探测清单，读不到再退回主机名兜底表 +
  `FlvLegacyHevcRelay.appliesTo` 的已知 HEVC CDN。`manifestRelay` → `_createIngestRelay`，
  `ffmpegRelay` → `_createFfmpegRelay`，没有 FFmpeg 运行时才退回 Dart 的 FLV 标签重写。
  新增 `release()`（停止播放时放掉中继但不关闭所有者）；被顶替的租约**多活一轮**再释放，
  因为接线发生在 `_controller.play()` 之前，引擎可能还在读旧的回环地址。
- **事实通路**：`LivePlayUrlResolution.streamFacts` → `PlayerState.streamFacts`（与
  `sourceQueryPolicies` 同一条规则：换了 URL 列表而没给新声明就清空）→
  `PlaybackSourceQualitySelection.streamFacts` → `LivePlayerFacade.play/switchEngine` →
  `FacadeStreamCommit.streamFacts`（悬浮窗重进、换引擎都还能重新决策）。
- **装配点** `app/bootstrap/initialized.dart`：
  `GlobalPlayerService.sourceInterceptorFactory = IngestSourceInterceptor.new`，紧挨着
  `configureIngestFfmpegStarter(ffmpegKitIngestStarter)`——FFmpeg 运行时本来就注册好了，缺的只是这一根线。
- **释放点**：`LivePlayerFacade.close()` → `release()`（离开房间、关悬浮窗、PiP 关闭都走这里），
  `dispose()` → `close()`。
- 测试：`test/domains/live/ingest_source_interceptor_test.dart`（5 个用例：只换第一条并丢鉴权头、
  不需要中继时原样返回、中继抛异常退回直连、`owned:` 不接线、release/close 分别落到 transport）。
  `test/{core,domains,shared}` 57 项全绿，`flutter analyze` 0 项，
  `tool/validate_architecture.py --strict` 通过。

**还没接的**：`FlvSpliceRelay`（签名 URL 到期后在一条连续流下面换地址）需要先有一个
`PlaybackSourceResolver` → `FlvSourceRenewer` 的适配器；多窗页目前自己用它。

**还没验证的**：真实流上的 FFmpeg 回环转封装。要桌面/真机各跑一次（HEVC FLV 与裸名子清单），
看 `PlaybackIngest` 日志里的 `relay <上游> -> http://127.0.0.1:<port>/...` 是否出现且能起播。

### 顺带查出的播放器代理断线（2026-10-04，Twitch 播不动）

接线后第一次真机验证 Twitch：清单探测正常（`children=14 absolute=14 -> direct`），mpv 也真的解码出
1920×1080、位置跑到 22166ms，然后 `bufferingStallTimeout`，之后每次重开都是 `Failed to open` →
`NO_PLAYABLE_STREAM`。实测这台机器到 `apn12.playlist.ttvnw.net`：**直连握手 9.3 秒，经本机 7897
代理 0.48 秒**；而 media_core 的重开验证窗口是"8 秒卡在 0ms 判死"，9.3 秒的握手永远过不了。

根因不在取流接线：**播放器代理（`enableProxy`）从来没接到引擎上**。`PlaybackProxyPolicy` 全仓只有
中继代码在读，`MediaKitLiveProperties` 里没有任何 `http-proxy`，`owned_input_opener` 只会把它设成空串。
这个开关对直连播放一直是死的——应用代理（`enableAppProxy`）只覆盖 dio，所以症状是"能列出房间、
能读到清单，播放器就是连不上"。

> **对上面那组计时的更正（2026-10-04 晚）**：「直连 9.3 秒 / 代理 0.48 秒」是**单次**测量，直连先跑、
> 代理后跑，冷热不一致。当晚在 `hls.liveshow.bdstatic.com` 上重测到了同样的陷阱：第一次直连 8.43 秒
> （TLS 1.31 秒、TTFB 8.43 秒），紧接着连测三次只有 **24–48 毫秒**；分片同样是直连 0.18–0.39 秒、
> 代理 0.042–0.049 秒。也就是说那个 8 秒级的数字是**冷启动离群值**，不是路由差异。
> 想复核 ttvnw 那组已经做不到了：`https://playlist.ttvnw.net/` 不带签名路径的探测直接 TLS 失败
> （curl exit 35、`code=000`）。
> **代码结论不受影响**（开关对直连播放确实是死的，`http-proxy` 确实该落到引擎上），但
> "经代理快 20 倍"这个**性能理由没有被证实**，不要再拿它当依据。

修（参考 Kazumi `player_playback_controller.dart` 的同一段逻辑）：

- `MediaKitLiveProperties.build()` 输出 mpv 的 `http-proxy`，取自
  `PlaybackProxyPolicy.currentNativeUrl(privateInput: false)`；**始终带这个键**，空串即"不用代理"，
  这样关掉开关能清掉上一次的值，语义与 `owned_input_opener` 对私有输入清除代理一致。media_core 会把
  引擎初始化前压入的选项 stash 到第一时刻，所以装配期的值确实落地。
- `ProxySettingsController` 的开关/主机/端口变化 → `playerProxyDispatcher` → `PlayerKernelService`
  把引擎选项写回正在运行的引擎，不用重启应用（对齐应用代理改完即时重建 dio 的行为）。
- `core/platform/windows_system_proxy.dart`：没有单独配置播放器代理时**跟随 Windows 系统代理**
  （WinINET 的 `ProxyEnable`/`ProxyServer`；`ProxyEnable=0` 时残留的 `ProxyServer` 不算数；只配 PAC
  视为无代理，一段脚本压不成播放器的一个端点）。用 `win32_registry` 按需读，不缓存不监视——读取点只有
  引擎装配与建立中继两处，缓存换来的只是一份会过期的状态。Kazumi 那 150 行 `RegNotifyChangeKeyValue`
  + `RegisterWaitForSingleObject` 的 FFI 监视器没搬。
- `[PlaybackProxy]` 每次装配记一行：从界面外面看不出播放器这一套代理到底生没生效。
- **没搬的**：Kazumi 只有一套代理（dio 与播放器共用 `proxyEnable`/`proxyUrl`），本仓是刻意分开的两套。
  让 dio 也跟随系统代理会把国内平台一起送进代理（这次日志里 douyu/douyin 的收藏刷新已经在超时），
  所以只接了播放器这一侧。
- 测试：`test/core/platform/windows_system_proxy_test.dart`（`ProxyServer` 两种写法、https 优先、
  scheme 前缀/IPv6/尾随路径容错、socks/ftp 与残缺值一律不认）、
  `test/core/player/playback_proxy_policy_test.dart`（私有输入不给代理；`http-proxy` 始终在，值要么
  空串要么 `http://` 端点）。`test/{core,domains,shared}` 63 项全绿，Analyze 0 项，
  `validate_architecture.py --strict` 通过。

**曾经记在这里的约束已经修掉了**：ffmpeg/libmpv 不会对 `127.0.0.1` 绕过代理（拿死代理实测会失败），所以
播放器代理开着时 FFmpeg 回环中继的那一跳本地流量也会经过代理——本机 Clash 能回连，但一个拒绝本地目标的
远端代理会把中继打死。现在代理改成**按源**写（见下一节），本机输入一律清空 `http-proxy`，
`owned_input_opener` 里那句重复的清除也删掉了，判定只有一处所有者。

### 按源写引擎属性：容器格式指死解复用器 + 本机输入不走代理

装配期的引擎选项整个生命周期只有一份，而"这条源是什么容器""这条源是不是本机中继"每条都不一样。
media_core 的 `PlayerAdapterBase.onBeforeOpen` 本来就是"为即将打开的源准备引擎选项"的位置（引擎已存在、
还没拿到 URL、且在打开窗口之外），所以给 `media_core_media_kit` 加了一个注入钩子：
`MediaKitAdapterFactory(beforeOpen: (player, source) → …)`，适配器在自己的 `onBeforeOpen` 末尾调用它。
参考 Kazumi `player_playback_controller.dart` 在源是 HLS 时写 `demuxer-lavf-format: hls` 的做法。

- `core/player/core/playback_source_hints.dart`：`kPlaybackStreamFormatKey`（平台声明的容器格式随
  `PlayerSource.metadata` 走，值是 `LiveStreamFormat` 的名字——Core 不能反向依赖 shared 的枚举，所以只认
  字符串）、`playbackStreamFormatMetadata()` / `declaredStreamFormatOf()`、`isPrivatePlaybackInput(uri)`
  （回环主机或非 http(s) 协议即本机输入）。
- `MediaKitLiveProperties.sourceProperties({uri, declaredFormat, proxy})` 是纯函数，代理由调用方注入：
  本机输入 → `http-proxy` 清空且不猜容器；否则 `http-proxy` 取播放器代理，容器按**声明优先、URL 形状兜底**
  决定是不是 `hls`。`demuxer-lavf-format` 不成立时写空串而不是省略——引擎跨源复用，上一条源强制的 hls
  不能漏到这一条 FLV 上。
- 收益：跳过 mpv 的格式探测。我们同时设了 `demuxer-lavf-probesize: 2097152`，在高延迟线路上探测耗时正好
  吃掉"8 秒卡在 0ms 判死"的起播预算——Twitch 那次失败里探测和握手是叠在一起的。
- 声明从哪来：`LivePlayerFacade.play/switchEngine` 用刚接好的 `LivePlayUrlResolution.streamFacts` 按 URL
  贴进 metadata；没声明的源退回 `isHlsManifestUri`（Twitch 那种把签名塞进路径的 `/v1/playlist/….m3u8`
  两种判据都认）。中继换源走 `copyWith`，metadata 原样保留，而回环 URI 会让判定直接落到"本机输入"。
- 测试：`test/core/player/media_kit_source_properties_test.dart`（上游 HLS 指死解复用器、声明优先于 URL
  形状、非 HLS 清空强制值、三类本机输入既不送代理也不猜容器、metadata 往返）。
  pure_live `test/{core,domains,shared}` **68 项全绿**、Analyze 0 项；media_core 全工作区 Analyze 0 项，
  `media_core` **280 项**、`media_core_live` **46 项**全绿（这两个包要用 `flutter test`，`dart test`
  会因为 `dart:ui` 加载失败，不是回归）。

### 卡住之后永远起不来：签名 URL 的重新解析根本没接线（2026-10-04，Twitch 复现）

代理生效（日志里 `[PlaybackProxy] http://127.0.0.1:7897`）之后 Twitch 仍然：起播成功（1920×1080、
position 22066ms 在走）→ 约 1 秒后进入缓冲 → 12 秒 `bufferingStallTimeout` → 之后每次重开都
`Failed to open`，永久死掉。看门狗不是元凶（`bufferingStallTimeout` 的语义就是"一次连续缓冲超过 12 秒"，
它报的是真事）；**结构性问题在恢复路径**：

1. media_core 的 `onEngineFallbackSources` 注释写得很清楚——"很多直播 URL 是签名且一次性的，第一个引擎
   那次尝试就把它用掉了，所以这里通常要重新取一份新线路"。但它只在**切换到下一个引擎之前**被调用，
   而 Windows 上只注册了 mpv 一个引擎（日志 `registered=[mpv]`），`_engineIndex + 1 >= _engines.length`
   直接返回 false，这个钩子**永远不会被调用**，于是 `sources=1 enginesTried=1` 就 sweep exhausted。
2. 就算它会被调用也没用：`GlobalPlayerService._initialize` 从来没传 `onEngineFallbackSources`，而
   `LivePlayerFacade.play(sourceResolver:)` / `playSource(sourceResolver:)` 收下了这个解析器却**从不使用**
   （全文件只在参数列表里出现过）。`PlayerController._buildSourceResolver` 造出来的东西一路传到 facade
   就断了——和 `interceptSources` 是同一类断线。
3. 看门狗驱动的恢复是"重开当前这条线路"（日志 `candidate failed: … (reopen of the playing line)`），
   用的还是那个已经死掉的签名 URL，3 秒内 `Failed to open`，然后无限循环。
4. `VideoController._handlePlayerError` 只把错误分类成一句 toast，没有任何重新解析或重试。

**已做（2026-10-04）**：`sourceResolver` 接上了，走的是**恢复路径**而不是失败路径——失败路径要等 sweep 把
所有候选烧完才轮到它，那时画面已经黑了；恢复路径在重开之前问一次，一次瞬时卡顿就还是一次瞬时卡顿。

- media_core_live 新增 `RecoverySourceResolver onRecoverySources`：恢复任务（看门狗卡顿 / 适配器报错）在
  `_sweep(startAtCurrent: true)` **之前**先问调用方，拿到的列表按偏好序整体替换 `_sources`、`_sourceIndex`
  归 0；空列表 = 照旧重开原线路；resolver 抛异常也照旧（记一条 `LogCategory.recovery` 警告）。答复用
  `_playGeneration` 栅栏：`play`/`switchLine`/`retry`/`pause`/`close`/`dispose` 都在排队前 bump 它，所以一次
  迟到的刷新不会把用户刚点的那次播放的线路换掉。
- `LivePlayerFacade` 用**一个实现**回答两个端口（`onRecoverySources` 与 `onEngineFallbackSources`）：换引擎
  那次刷新问的是同一件事——"给我一份平台现在认的线路"，多出来的引擎 id 对 resolver 没有意义。顺带删掉
  facade 构造器上那个从来没人传的 `onEngineFallbackSources` 形参：上面第 2 条断线的根源就是它——构造期
  根本不知道要播哪个房间，宿主没法在那里给出 resolver。
- 刷新成功必须**重新发布提交**：`switchLine` 数的是内核那份列表、界面读的是提交那份、换引擎和悬浮窗重进靠
  `currentUrl`/`ownedSource` 重建源。只换地址不改提交，这三处会继续指着平台已经拒掉的签名。
- 纯逻辑抽到 `domains/live/domain/playback_source_refresh.dart`（偏好线路排序、请求构造、采纳栅栏、源构造、
  提交构造），`play`/`switchEngine`/`playOwned` 那三处 `PlayerSource(...)` 复制粘贴合并成 `livePlanSources` /
  `ownedPlanSource`；FC2 那次"metadata 里必须是输入工厂而不是源"的教训也钉在 `ownedPlanSource` 上。
- 顺带接上 `playSource` 收下却丢掉的 `audioOnly`：助眠会话进自有输入的房间（fc2 等）以前不会关视频轨。
- 测试：media_core_live `recovery source refresh` 3 项（新线路真的被打开 / 迟到答复被丢弃 / resolver 抛异常
  仍重开原线路）。mutation 逐个验过：删掉刷新调用 → 第 1 项失败（`askedWith` 为空）；删掉代次栅栏 →
  第 2 项失败（`stale.example` 进了内核）；删掉 catch → 第 3 项失败（只开了 1 次源，恢复整个没跑）。
  pure_live `test/domains/live/playback_source_refresh_test.dart` 16 项，4 个 mutation（不把偏好线路移到首位 /
  删提交代次栅栏 / metadata 放 source 而不是 factory / 绕过取流接线）各自打破对应用例。
  `media_core_live` 全套 53 项全绿、pure_live 全仓 Analyze 0 项、`validate_architecture.py --strict`
  0 未批准硬边。
- 用户手点重试那条路本来就会自愈：`VideoController.refresh` → `onInitPlayerState(refresh)` →
  `getPlayQualites()` 全量重解析。内核的 `retry()` 在 app 里没有调用点。
- 刷新没有再套一层超时：上游给这次调用套了 `timings.sourceRefresh`（12s），而我们的平台请求本来就受
  `HttpClient` 的 dio 超时约束（connect/receive/send 各 20s），问题"平台多久内必须给出新地址"已经有答案了。
  再加一个更紧的就是同一个问题两个截止时间、更紧的那个偷偷生效——和这轮修掉的 Steam 那处是同一种错。
  代价是恢复任务最坏会被一次挂死的请求占住约 40s，期间用户命令排在单槽队列后面（暂停/退出不能取消正在跑的
  任务，只能取消排队中的）。
- 仍未接：① 租约到期前**主动**预取（上游 `session._schedulePrefetch` 那条腿）——`sourceRefreshAt` 依旧只是
  随请求带着没人读，所以地址过期时观众会先看到一次卡顿再自愈，而不是无缝换地址；② facade 里
  `_refreshSources` 的编排（栅栏判定、重新发布提交）没有自动化覆盖，它要真内核才能跑，纯逻辑部分已单独测过；
  ③ 中继自己的续租（上游 `LineRenewer`）仍未接，`FlvSpliceRelay` 那条腿还是老样子。

**这台机器的实际状态**（`reg query HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings`）：
`ProxyEnable=0`、残留 `ProxyServer=127.0.0.1:7890`，而 Clash 实际在听 **7897**。所以"跟随系统代理"这一路
对它无效，必须在「播放器代理」里手填 `127.0.0.1:7897`。这也正好说明 `ProxyEnable` 为什么必须优先：
照抄残留的 `ProxyServer` 会把 mpv 指到一个没人听的端口。

### Twitch 复现第二轮：打开快了，卡顿没变（2026-10-04）

代理生效后（日志里 `[PlaybackProxy] http://127.0.0.1:7897`）同一房间再测：

| 阶段 | 修之前 | 按源指死解复用器之后 |
| --- | --- | --- |
| attach → opened | 13.4 s | **0.2 s** |
| opened → 首帧 | 7.8 s | **4.8 s** |
| 首帧之后 | 播 1–2 秒进入缓冲，12 秒后 `bufferingStallTimeout` | **完全一样** |

"起播预算被格式探测吃掉"那一条被证实、也修掉了；但**卡顿早于本轮所有改动**：第一次复现时既没有代理也没有
指死解复用器，症状一模一样。三次复现的 `positionMs` 都停在 22066 / 22083 / 22166——14 段 × 2 秒的清单窗口里
正好是 lavf `live_start_index` 默认值（倒数第 3 段）的位置，也就是**从直播边缘起步、手里只剩约 6 秒内容**，
播完就必须重载清单。它没有重载成功。

两件事同时做：

- **把 mpv 自己的日志接出来**（`core/player/kernel/mpv_log_forwarder.dart`，加上 `playerConfiguration()` 里的
  `logLevel`：调试构建 `v`、发布构建 `warn`）。media_kit 只把 mpv 的**错误码**喂给 `stream.error`，
  `stream.log` 里的日志文本一直无人订阅、等于全丢；而清单重载失败、分片的 HTTP 状态、cache 为什么暂停这些
  一手证据全在那里。挂在 `beforeOpen` 上，因为那是不改 media_core 又能拿到引擎实例的唯一时机。
- **一个有具体机制的怀疑，同时改掉**：`force-seekable: yes` 会让 mpv 把直播清单当成可拖动流，从而启用为点播
  设计的 `cache-pause`；直播读到边缘就没有更多数据，`cache-pause-wait: 4` 要的 4 秒永远凑不齐，表现正是
  "播一两秒停住不再恢复"。现在按源判定：HLS 清单（含回环中继的输出）→ `force-seekable: no` +
  `cache-pause: no`；渐进式 FLV/TS 保留原值（数据连续到达，缓存目标凑得齐；B 站轮播房还要靠 seek 落到声明的
  起播位置，不能把可拖动撤掉）。**这是假设，不是结论**——mpv 的日志会证实或推翻它。

`isPrivatePlaybackInput` 顺手补了 IPv6 字面量的方括号（`Uri.host` 在不同实现里可能带 `[]`）。
测试 **69 项**全绿（新增"渐进式源保留可拖动与自动暂停"，回环那条改成区分 HLS 与 FLV 输出），Analyze 0 项。

### Twitch 复现第三轮：能播了，但**不是因为上一条的假设**（2026-10-04）

mpv 日志接出来之后的第一手证据（`apn11`，同一房间，1080p60 h264 + aac，d3d11va 硬解，结尾连续
`hls: Opening '<URL>' for reading` 说明分片在持续拉取）：

- `lavf/v: Found 'hls' at score=100 size=0 (forced).` —— 按源指死解复用器**确实生效**。
- `Set property: force-seekable="no"` 之后紧跟 `Set property: force-seekable="yes"`；
  `cache-pause="no"` 之后紧跟 `cache-pause="yes"` —— **按源写的值被装配表覆盖了**，最终生效的还是旧值。

所以"能播"和 cache-pause 那个假设无关（它根本没落地）。上一条记的假设**被推翻**，真正查到的是另一个 bug：

**一个属性有两个所有者，而且顺序不确定。** 工厂的 `configure` 收的是 `void Function(adapter)`，而
`MediaKitLiveProperties.applyTo` 是 `Future<void>`，它的 Future 被直接丢掉；`engineOptions()` 内部还要
await 超分着色器的准备，于是装配表是在**打开已经开始之后**才逐条写进去的，和 `beforeOpen` 钩子的写入
交错。谁最后落地取决于时序——日志里就是钩子先写 `no`、装配表后写 `yes`。

修法不是去排序，而是**让两者不再重叠**：`build()` 只保留对所有源都一样的属性，凡是按源不同的
（`http-proxy`、`demuxer-lavf-format`、`force-seekable`、`cache-pause`）一律只由 `applyToSource` 写。
重叠消失之后那个竞态就无害了。回归测试直接钉这条不变量：装配表里出现这四个键就失败。

**代价，明说**：`http-proxy` 不再随装配表走，所以上一轮加的 `playerProxyDispatcher`（改开关立刻写回运行
中的引擎）成了空转，已删除。播放器代理现在**在下一次打开源时生效**——改完开关要重进房间。之前说的
"改完立刻生效"不成立了，这是消除竞态付的代价。

**另一条一手证据，比 cache-pause 更可能解释那几次间歇性卡顿**：

```
ffmpeg/demuxer/warn: hls: Disabling http_persistent due to custom io_open.
ffmpeg/demuxer/warn: hls: Disabling http_multiple due to custom io_open.
```

media_kit 注册了 stream callback（日志里的 `stream_callback/v: Opening`），lavf 的 HLS 解复用器因此关掉了
连接复用与并发拉取——**每个分片都是一条新连接**，走代理时还多一次 CONNECT。1080p60 的源流约 6–8 Mbps、
2 秒一片，代理节点稍微一抖就供不上。这和同一批日志里 douyu/douyin/huya 经代理刷新全部超时是同一件事：
节点吞吐不足。要根治得在 media_kit 侧看能不能不注册 stream callback（`http-header-fields` 已经能带请求头，
日志里可见），这条留给 media_core。

**结论**：Twitch 起播问题已解决（播放器代理 + 按源指死解复用器）；间歇性卡顿的根因指向代理节点吞吐与
HLS 无连接复用，不是本仓的判定逻辑。`sourceResolver` 那条断线（卡住之后无法用新签名 URL 恢复）仍然待做
——它决定的是"卡一下之后能不能自己爬起来"。

### TwitCasting 401：清单下发的会话 cookie 被中继丢掉了（2026-10-04，已修）

接线之后第一次真正跑到 manifestRelay：中继起来了、mpv 也读到了改写后的清单
（`Found 'hls' at score=100 size=428`），然后

```
hls: Failed to open an initialization section in playlist 0
hls: Failed to read segment header for probing: Server returned 401 Unauthorized
```

401 是**上游返回的**（`LoopbackIngestRelay` 只转发状态码），而清单那一次是 200——同一个客户端、同一套
请求头，差别只在 URL。用真实房间复现（`streamserver.php?target=<channel>&mode=client&player=pc_web` →
`tc-hls.streams.high`）拿到清单的响应头：

```
Set-Cookie: lvhls_ssid_841801664=db5bc7f9…; Path=/tc.livehls/v1/streams/841801664/hls/; Max-Age=600; HttpOnly
```

curl 对照实测：`init.2.mp4` **不带 cookie → 401，带上 → 200（1095 字节）**。这正是
`IngestNeed.sessionCookies` 文档描述的情形（provider 随清单发 cookie，子请求要继承），而
`_createIngestRelay` 在 manifest 改写这条路上一直传 `sessionCookies: false`——只有带查询令牌策略的那条
路传了 true。

修：`_createIngestRelay` 恒定 `sessionCookies: true`，参数删掉（两个调用点现在同值）。中继的 cookie jar
本来就按源站钉死、有上限、只在同一 origin 内回放，这正是浏览器对一棵 HLS 树的做法，没有"要不要开"的
分歧点。

顺带补上最后一处不一致：`LoopbackIngestRelay` 之前**没有** `findProxy`，所以四条中继里唯独它绕开播放器
代理直连上游（media_core_ingest 已加参数，`_createIngestRelay` 传
`PlaybackProxyPolicy.currentDirective()`）。这次能读到清单是因为 TwitCasting 从本机直连可达，属于运气。

**声明里的一处不实也改了**：`tc-hls` 的子条目实测是**绝对路径**
`/tc.livehls/v1/streams/<movie>/hls/<tier>/media.1744.mp4`（`#EXT-X-MAP` 的 `init.*.mp4` 同样），不是原先
注释写的裸名 `media.95.mp4`。两者对原生解析器一样致命（丢了清单地址就变成 `\tc.livehls\…` 这样的本地
路径），所以 `LiveStreamFacts` 的字段从 `relativeChildren` 改名为 `unresolvedChildren`，一个 bool 覆盖两种
形态；`IngestNeed.relativeChildren` 与 `HlsManifestKind.relativeChildren` 是 media_core_ingest 的名字，
没动。兜底表 `playback_ingest_needs.dart` 的 TwitCasting 注释同步改成实测形态。

测试：`test/domains/live/loopback_relay_session_cookie_test.dart` 起一个仿 TwitCasting 的本机 provider
（清单 200 + Set-Cookie、子条目绝对路径、分片无 cookie 就 401），走 `transport.prepare()` 拿到回环租约，
再读改写后的清单与 `#EXT-X-MAP` 子条目，断言子条目已换成本机地址、分片 200、且 provider 只在带 cookie 时
被命中。**把 `sessionCookies` 改回 false，这个测试就以 401 失败**（已实测），和线上症状一模一样。
`test/{core,domains,shared}` 70 项全绿，两个仓库 Analyze 0 项。
### 自有输入的播放绑定被我 10-01 的清理删空了（2026-10-04 恢复）

`992479049`（"清理 core 死代码——已退役平台的播放输入"）删掉了 bigo/fc2/niconico 三个
`*PlaybackInput` 与 `live_input_playback_binding.dart` 里的对应 case，理由是"无任何引用"。这个判断错了：
引用是**间接**的——三个站点适配器至今仍在 `resolvePlayUrls` 里返回
`LivePlayUrlResolution.owned(input: XxxInputRecipe(...))`，而消费配方的 switch 被删空之后，
`bindLiveInputForPlayback` 对任何配方都抛 `UnsupportedError`。表现是进房即
`Play quality loading failed (UnsupportedError)`（niconico 先被撞见，bigo/fc2 同样坏）。
录制侧没事：`live_input_recording_binder.dart` 那份 switch 一直在。

恢复方式跟着录制侧的形状走：三个 opener + switch 放进
`domains/recorder/data/services/live_input_playback_binding.dart`（它适配的是那里的
`XxxHlsInput.open(recording:)`；放进直播域会新增三条跨域硬边）。直播域的
`live_input_playback_binder.dart` 只留函数形状与装配点 `configureLiveInputPlaybackBinder`，由
`app/bootstrap/initialized.dart` 安装实现——和取流接线、播放器代理同一种装配法。未装配时绑定抛异常
而不是静默直连：这类站点没有可直连的 URL，静默只会把故障换成更难看的样子。

两个 opt-in 探针（`niconico_playback_probe_test.dart`、`niconico_manager_probe_test.dart`）还在 import
被删的 `core/player/core/niconico_playback_input.dart`，已改指新位置。
测试 `test/domains/live/live_input_playback_binding_test.dart` 钉两条边：三种配方各自绑出正确身份且不开
席位；未装配抛 `UnsupportedError`、装配后委托。75 项全绿，Analyze 0 项，`--strict` 无新增硬边。

**恢复之后才露出来的第二层（2026-10-04 晚，已修 `e05675c5c`）**：FC2 进房报
`Invalid argument (recipe): Not an owned-input recipe: Instance of 'OwnedPlaybackSource'`。
`playOwned(Object recipe, …)` 把收到的对象原样塞进 `metadata[kMediaKitCustomInputKey]`，而
media_kit 适配器把它交给 `customInputOpener` → `asOwnedInputRecipe` 只认**函数**。多画面那条路一直给的
是 `owned.createInput`，所以只有房间这条路坏。

**归因要说清楚**：这个类型不匹配**早于**上面那次清理——`3ac0012d8` 时 `playOwned` 就已经是
`Object recipe` + 原样入 metadata，而 binder 的 typedef 那时已经返回 `OwnedPlaybackSource`。清理删掉 case
之后抛的 `UnsupportedError` 恰好把它盖住了，恢复 case 才让老问题重新露头。所以是两层缺陷叠在一起，
不是我恢复时新引入的。

修：`playOwned`/`playSource` 收紧成 `OwnedPlaybackSource`（编译器挡住签名），metadata 的值只由
`customInputMetadataOf(source)` 一处产出、房间与多画面两条路共用（元数据是 `Map<String, Object?>`，
放错对象不是编译错误而是运行时拒绝，所以两端各钉一条测试）。

**顺带挖出同一条路上的第二个哑弹**：`FacadeStreamCommitLegacy.source` 是重构留下的
`Object? get source => null;`——`player_controller` 正是靠 `commit.source is OwnedPlaybackSource`
取自有源的，于是**永远取不到**，房间会话快照里没有 ownedSource，悬浮窗/重进房间就无法重建输入。
改成 `_publishCommit` 带上 source、消费端读真实存在的 `ownedSource` 字段，那个说谎的 shim 删掉。

### Steam 起播失败：清扫的验证窗比它自己声明的截止日期更紧（2026-10-04，已修在 media_core `c6f5917`）

日志（同一份里有两个房间，对照价值比单独一个高）：

- Steam（`cache1-tyo3.steamcontent.com`）：`opened` 02:19:03.930 → `disposing player` 02:19:12.053
  （**8.1 秒**），紧跟 `live sweep exhausted | sources=1 enginesTried=1` 与
  `StateError: … opened but never played (position frozen at 0ms for 8s)`。
- 这 8.1 秒里 mpv 在做什么，日志写得清清楚楚：master 清单 → **四个变体清单**
  （`160000/audio`、`6000000/video`、`1500000/video`、`500000/video`）→ audio init → audio 16690 →
  video init → video 16690 → 再回头重开 `6000000`、`1500000`……**到被杀掉都还在探测**。Steam 的 master
  不带 `CODECS`，lavf 无法剪枝，只能把每一路都打开并读一段才知道选谁。
- 关键的一点：**这段时间里既没有 buffering 事件也没有 position 事件**。所以"引擎还在干活"这件事在传输层
  没有任何信号可读——我原本打算按 buffering 延长验证窗，被这段日志推翻了，没有采用。
- 对照 pandalive（AWS IVS，单变体）：`opened` 02:17:45.987 → 首个 position 02:17:52.828，
  **6.8 秒，8 秒窗里只剩 1.2 秒余量**；之后还有 `End buffering (waited 2.751994 secs)`。

根因不在本仓：media_core_live 的清扫用自己的私有常量 `_verificationWindow = 8s` 验证候选，而同一模块的
`LiveWatchdogs.sourceReadyTimeout = 18s` 声明的是**同一个问题**（打开了但没在播）的容忍度——而且那个看门狗
只在验证通过之后才 arm，两者从不重叠。同一个问题两个截止日期，更紧的那个碰巧赢了，于是"还在探测"被判成
"死了"。修法是删掉第二个截止日期：验证直接用 `sourceReadyTimeout`，`0` 表示连验证一起关掉（与看门狗同义）。
测试改成缩短截止日期而不是干等生产值 18 秒，拒绝那条用例从 18 秒降到 0.6 秒，49 项全绿。

**还有第二个贡献者，而且它说明用户跑的是旧构建**：Steam 那段日志里 `force-seekable="no"` 之后紧跟
`="yes"`、`cache-pause="no"` 之后紧跟 `="yes"`、`http-proxy` 被写了两次——正是属性所有权修复
（`build()` 与 `applyToSource` 不再重叠）**之前**的样子。也就是说清单源仍在跑 `cache-pause: yes` +
`cache-pause-wait: 4`，探测完还要再等 4 秒缓存才肯走表；HEAD 上清单源是 `no`/`no`。**必须先热重启
（大写 R）或重跑，否则这次 media_core 的修复也看不到效果。**

**18 秒够不够 Steam，日志证明不了**（它在 8.1 秒被杀，没跑到探测结束）。若仍然失败，日志现在会写
`position frozen at 0ms for 18s`，那就是探测本身没走完，下一个杠杆是**每请求成本**而不是这道闸门。

**同时更正上一条里的一处不实**：我写过"media_kit 注册了 stream callback"。查证结果是——本仓、media_core、
media_kit（Predidit fork 与 pub 1.2.6）的 Dart 与随包源码里**都没有** `mpv_stream_cb_add_ro` 或任何
`stream_cb` 注册点；日志里的 `stream_callback/v: Opening <https URL>` 只能说明 libmpv 侧确实走了客户端
注册的 stream_cb 协议（这正是 lavf 打出 `Disabling http_persistent/http_multiple due to custom io_open`
的原因），但注册者在预编译的 libmpv/native 层里，我没找到。观测成立、归因未证实，那条"在 media_kit 侧
不注册 stream callback"的待办因此要先改成"先找到注册者"。


### jdlive「播两秒停一下再继续」：同一个属性覆盖，第一次落在回环中继上（2026-10-04，HEAD 已修）

和 pandalive 那条是同一个缺陷，但这次的源是**回环中继**，所以覆盖的代价比直连更具体。日志
（`zt-pull-ai.jdcloud.com`，`children=1 relative=1 → loopback rewrite`，
`relay → http://127.0.0.1:52166/i1vzuev527t3f0hjrjln40ek/root.m3u8`）：

- 按源写入是对的：`http-proxy=""`、`force-seekable="no"`、`cache-pause="no"`（`root.m3u8` 认作清单）。
- 紧接着装配表把它们全盖回去：`force-seekable="yes"`、`cache-pause="yes"`、`cache-pause-wait="4"`，
  **还有 `http-proxy="http://127.0.0.1:7897"`**——于是 `lavf/v: Could not set AVOption
  http_proxy='http://127.0.0.1:7897'` 出现在 `http://127.0.0.1:52166/…r0.ts` 的子请求上：
  **每个回环分片都被送去 Clash 绕一圈再回到本机**（ffmpeg 默认不会为 127.0.0.1 跳过代理，此前已实测）。
- 症状机制就在起播那三行：`playback restart complete @ 0.067` → `positionMs=233` →
  `Enter buffering (buffer went from 100% -> 0%)` → 0%→1%→5%→22%→48%→98% →
  `End buffering (waited 4.227554 secs)`。**4.23 秒 ≈ `cache-pause-wait: 4`**：mpv 播完手上那一片之后
  自己停下来，等凑满 4 秒缓存才继续——这就是用户看到的「播两秒、停、再接着播」。pandalive 同一份日志里的
  `End buffering (waited 2.751994 secs)` 是同一件事的另一次。

HEAD 上清单源是 `cache-pause: no`（`cache-pause-wait` 留着但不再触发），回环源额外拿到 `http-proxy: ''`；
`test/core/player/media_kit_source_properties_test.dart` 的「本机输入既不送代理也不猜容器」正是钉
`http://127.0.0.1:4321/ingest/index.m3u8` 这个形状（`http-proxy=''`、`force-seekable='no'`、
`cache-pause='no'`）。**所以 jdlive 不需要改代码，需要的是把运行的构建换到 HEAD。**

诚实的边界：jdlive 上游清单只挂 1 个分片，播放器本来就贴着直播边缘跑，下一片到达前的短暂等待不会完全消失；
消失的是那 4 秒的**主动**等待。若热重启后仍有卡顿，下一个要查的是中继的清单刷新节奏，不是缓存策略——
那需要一份新日志才能判断。


### 百度直播：两个房间差 80 毫秒，一个播起来一个判死（2026-10-04，同 `c6f5917`）

同一份日志里两个房间，结局只差 80 毫秒，正好把 8 秒闸门卡在分界线上：

| 房间 | `opened` | 结果 | 用时 |
| --- | --- | --- | --- |
| `…3321423445_11587002245-L3` | 02:20:56.351 | 首个 position 02:21:04.273（`positionMs=168`）→ **播起来了** | 7.92 秒（余量 80 毫秒） |
| `…4975713605_11583280342-L3` | 02:21:15.344 | `disposing player` 02:21:23.509 → `position frozen at 0ms for 8s` → `NO_PLAYABLE_STREAM` | 8.16 秒 |

首帧为什么要 8 秒，网络已经排除（见上一条更正里的实测：直连 24–48 毫秒、分片 0.18–0.39 秒）。剩下的
线索在清单和解码器上：

- 清单实测 `#EXT-X-TARGETDURATION:6`、`#EXTINF:6.000000`、`#EXT-X-ALLOW-CACHE:NO`——**6 秒一片**。
- 探测阶段就报 `ffmpeg/error: NULL: non-existing SPS 0 referenced in buffering period` /
  `h264: non-existing SPS 0 referenced in buffering period`：**切入点落在 GOP 中间，没有参数集**，
  解码器要等到下一个 IDR 才能出帧，最坏就是等一整片（6 秒）。
- 6 秒等 IDR + 约 0.4 秒取清单与分片 + 解码器/VO/着色器初始化 ≈ 观测到的 7.9 秒。

**诚实标注**：mpv 的日志行不带时间戳，所以"这 6 秒花在等 IDR 上"是由 SPS 报错 + 6 秒分片 + 总时长
算术推出来的**推断**，不是直接测到的。能直接测到的是两端：`opened` 与首个 position 的墙钟差。

结论与 Steam 同一条：闸门从 8 秒改成 `sourceReadyTimeout`（18 秒，media_core `c6f5917`）之后两个房间都
能过。**但首帧仍是 8 秒左右**——那是这个站点分片与 GOP 的形状决定的，闸门放宽只是不再把还在干活的
播放器判死，不会让它更快。这份日志同样是旧构建（`force-seekable="no"`→`"yes"`、`cache-pause="no"`→
`"yes"`、`http-proxy` 写两次）。


### LOOK「有的房间能播有的不能」：房间是幽灵，顺带查出七个站的请求头被丢了（2026-10-04）

日志里那间房（`pull0583d674.live.126.net`）的 404 是**真的**：应用自己的探测请求先拿到 404
（`⛔ [HTTP Error] [badResponse] Response Code: 404`，285ms），mpv 随后
`ffmpeg/warn: https: HTTP error 404 Not Found` → `Failed to open …`。两边一致，不是播放器的问题。

新增探针 `tool/probes/looklive_media_headers_probe_test.dart`（opt-in，只报状态码与字节数，不落 URL）
按应用自己的链路抽了 4 个在播房间 × 2 条线路，每条**带头 / 不带头各请一次**：

| 房间 | 线路 | 带声明头 | 不带头 |
| --- | --- | --- | --- |
| 21623631 | hls / flv | 200（442B）/ 200（17206B） | 200 / 200 |
| **95878198** | **hls** | **404（17B）** | **404** |
| **95878198** | **flv** | **200，30 秒 0 字节** | **200，0 字节** |
| 217327486 | hls / flv | 200（604B）/ 200（17101B） | 200 / 200 |
| 18430854 | hls / flv | 200（484B）/ 200（3457B） | 200 / 200 |

汇总：`linesProbed=8 headerSensitiveLines=0 ghostLines=2`。两条结论：

1. **`liveStatus=1` 不保证 CDN 上有流。** 95878198 的详情接口照样说在播（否则探针会跳过它），
   而 HLS 是 404、FLV 连上了却一个字节都不给。这就是"有的房间能播有的不能"的原因——**在房间，不在我们**。
   客户端无法把不存在的流播出来；能改善的只有报错的诚实度（见下）。
2. **请求头对这个 404 没有影响**：8 条线路带头与不带头的状态码、字节数完全一致。所以"补上 Referer 就能播"
   这个猜测**被探针推翻了**，不作为修法。

**但顺着 `http-header-fields=[]` 查出一个真缺陷**：`PlaybackHeaderResolver.resolve` 是一张按平台分支的表，
分支里没有的站点一律落到 `default: headers = {}`——**房间自己声明的 `httpHeaders` 被丢掉**（入参
`roomHeaders` 只有 IPTV 那一支用了）。声明了媒体头却不在表里的有七个站：
**looklive、jdlive、baidulive、sixroom、kugoulive、fc2live、steambroadcast**。它们的 CDN 一个头都收不到，
jdlive 与百度直播的日志里都是 `Set property: http-header-fields=[]`。

修的是默认分支而不是补七个 case：只有站点自己知道该拿哪个 id 拼 Referer（jdlive 用 `liveId`、liveme 用
`shortId`、tiktok 用 `username`、steam 用 `steamId`），解析器手上只有 `roomId`，重建会拼错。默认分支改成
透传 `roomHeaders`，**新增站点不必再来登记**。表里已有的 25 支不动（它们要合并设置项里的 Cookie/自定义 UA）。
测试 `test/domains/live/playback_header_resolver_test.dart` 钉四条边：无专属规则的站透传声明（用 LOOK 真实的
`mediaHeaders` 与 `https://look.163.com/live?id=123456`）、有专属规则的站不被房间声明覆盖、IPTV 仍然是
"自定义 UA + 每频道头"合并、什么都没声明时还是空表（不凭空造头）。

**留一条未证实的疑点，不顺手改**：pandalive / liveme / tiktok / youtube 在表里用 `roomId` 重建 Referer，
而房间上声明的是 `userId` / `shortId` / `username` / `videoId`。若这几家的 `roomId` 与那个 id 不是同一个值，
它们现在发出去的 Referer 就是错的——但四个站目前都能播，没有证据说明它有害，所以只记不改。

**报错诚实度这条是真修了**（media_core `9828998`）：会话第一次打开永远是 staged，而 staged 播放器在 commit
之前没有适配器订阅，于是"打开就失败"的引擎错误没人听见——验证等满整个窗口，最后报
`opened but never played (position frozen at 0ms for 8s)`，把 CDN 的 404 说成了流卡住。现在 staged 期间只订阅
错误事件（播放状态与看门狗照旧不接，避免未 commit 的引擎污染界面），LOOK 这种情况会**立刻**失败并带上
`Failed to open …` 的真因。顺带修了 `player_handle_adapter.dart` 那行日志：它报的 `recoveryEnabled` 是配置默认值
而不是句柄上真正生效的开关，于是明明被播放方关掉了还打印 `true`（media_core `b934b81`）。


### Cookie 配置面审计（2026-10-04，已修一处）

顺着请求头那条线核了一遍 cookie：**配置面与上游 4.x 完全一致**，上游用 `cookie/<site>` 通用键 +
`CookieVault`（`live_store/lib/src/secrets.dart`），实际用到的站点是
`bilibili douyin douyu huya kuaishou soop twitch yy` —— 与本仓 `CookieSettingsController` 的八个字段一一对应，
没有缺的平台。逐条核过的同步点：

| 环节 | 结论 |
| --- | --- |
| 站点 API | 八家都从 `CookieSettingsController` 读（斗鱼经 `DouyuUtils.cookieHeader()`，它还负责把 `dy_did`/`acf_did` 与签名用的 DID 对齐） |
| 播放请求头 | 七家在 `PlaybackHeaderResolver` 的分支里；斗鱼走 `DouyuUtils.playbackHeaders`；**twitch 故意不发给视频 CDN**（授权在 usher 签名里，把登录 Cookie 交给第三方 CDN 是上游 8-7 的明确决定） |
| 弹幕 | bilibili 的 `danmakuData` 带 `headers['cookie'] ?? cookie`；twitch 聊天读 `twitchCookie` |
| 录制 / 多画面 | 都经 `PlaybackHeaderResolver`（`ffmpeg_header_factory`、`resolvePlaybackHeaders`），与主房间同源 |
| 中继 | 上游方向带 cookie；回环那一跳 `headers: SourceHeaders.empty`，**登录 Cookie 不会发给 127.0.0.1** |
| 归一化 | 七个 cookie 编辑页 + 扫码/网页登录都在保存时 `normalizeAccountCookie` |
| 导入导出 | `toJson` / `parseConfig` / `fromJson` 十二个字段双向对称（备份的分节字段集就是从 `extractConfig` 推的），已加测试钉住 |

**修掉的一处**：斗鱼登出只清 `douyuCookie`，把 `douyuLtp0`（passport 长期续期密钥）、`douyuDid`、
`douyuCookieSavedAt` 留在本地——也会跟着"含敏感数据"的备份一起导出。续期需要非空 cookie 才会发请求
（`refreshSession` 提前返回），所以不是一个活着的 bug，是凭据卫生问题。四个字段现在由
`clearDouyuSession()` 一处清，`clearAllCookies()` 也复用它；cookie 编辑页那条"只粘了凭据"的分支
照旧保留 ltp0/did（那条路本来就没存会话）。测试 `test/core/config/cookie_settings_test.dart`。

**记下来但没动的两处**：`clearAllCookies()` **全仓无调用点**——界面里没有"清除所有账号"的入口；
`_normalizeStoredCookies()` 不覆盖 `douyuLtp0`/`douyuDid`，而 `parseConfig` 覆盖（所有写入点都 trim 过，
所以无害，只是不对称）。


### 站点连不上却报成「读取视频信息失败」：两个代理开关的管辖范围没人说（2026-10-05，已修）

日志（niconico 房间）末尾：

```
⛔ [HTTP Error] [unknown] [Time:530ms]  Underlying Type: HandshakeException
⛔ Request Origin: https://live.nicovideo.jp   Response Code: none
⛔ Request Header Keys: [Referer,User-Agent]
[PlayerController] Play quality loading failed (NiconicoException)
```

`Response Code: none` + `HandshakeException` 说的是**握手都没成**，不是房间读不出。而同一份日志里
`[PlaybackProxy] ... http-proxy: http://127.0.0.1:7897` 说明播放器代理是开着的——可它管不到这条路：
站点页面与 API 请求走的是 `enableAppProxy`（dio、websock、中继上游取流、图片全都归它，见
`initialized.dart` 里三处 `configureXxxProxyRouting`），只有 `registered=[mpv]` 那条拉流走 `enableProxy`。
应用层代理没开时站点请求按 `buildProxyDirective` 直连，nicovideo 直连就被掐。

**缺陷不在网络，在归因**：24 个站点适配器的 failure enum 里 `transport` 就是"平台没答话"这一档（HTTP 状态
各归 access/missing/rateLimited/service，读不出才算 transport），但消费端把它和"房间信息读不出"混成同一句
`read_video_failed`。观众据此去找坏掉的适配器，而该动的是一个设置。

- `core/network/site_transport_failure.dart`：`SiteTransportFailure` 接口 + `isUnreachableSiteFailure(error)`，
  认三种形状——适配器自己声明的、dio 分类过的连接类错误、以及 **dio 没分类的那一种**（它只把
  `SocketException` 映射成连接错误，TLS 被掐是 `unknown` 里裹着 `HandshakeException`，正是日志的形状）。
- 24 个站点异常类机械实现该接口（`kind == XFailure.transport`）；`douyu`/`twitch` 这类没有 kind 枚举的
  适配器不强行套，它们漏出的原始 `DioException` 由第二个形状接住。
- `PlayerController.streamMetadataFailureKey`：两处 `read_video_failed`（取清晰度、切档）改成按上面判定，
  新增 `site_unreachable`（应用层代理没开：直连，站点请求不经代理）与 `site_unreachable_via_proxy`
  （已开：说这条节点到不到得了，不再劝人开代理）。同日并发那笔 showroom 修复给出同一条路的另一种根因——Clash 改写 TLS，它的证书不在 dart 的信任链里，于是 `_via_proxy` 那句把两种可能都写上。
- 测试 `test/core/network/site_transport_failure_test.dart`（6 项，含一条**扫源码**的守卫：凡 failure enum
  里有 transport 的异常类都必须声明接口，摘掉 niconico 的 `implements` 会立刻变红）与
  `test/domains/live/stream_metadata_failure_key_test.dart`（2 项）。全仓 138 项全绿。
- **这条修改只改提示，不改网络路径**：niconico 能不能进房取决于用户是否打开「应用层代理」。要不要让站点
  请求在播放器代理开着时跟着走同一条，是产品决定——该设置的说明写着"关闭时软件完全使用 DIRECT 直连，
  避免系统网络探测导致的启动慢"，回退会违背它，所以先不动。

### chzzk 1080p：改写后的清单能开，子分片却没人回答（2026-10-05，已修在 media_core `1d656cf`）

日志形状：

```
[PlaybackIngest] manifest livecloud.akamaized.net: children=16 absolute=0 relative=16 … -> loopback rewrite
[PlaybackIngest] livecloud.akamaized.net -> http://127.0.0.1:57047/<secret>/root.m3u8
[mpv] ffmpeg/demuxer/v: hls: Opening 'http://127.0.0.1:57047/<secret>/r0.m4s' for reading
[mpv] ffmpeg/demuxer/v: hls: Opening 'http://127.0.0.1:57047/<secret>/rd.m4v' for reading
                        ← 到这里再没有任何一字节，也没有一条错误
[media_core/recovery] candidate failed … opened but never played (position frozen at 0ms for 18s)
```

第二条候选退回直连上游 URL，`[PlaybackProxy] livecloud.akamaized.net -> {http-proxy: http://127.0.0.1:7897}`
之后是 `httpproxy: Stream ends prematurely at 0` + `tls: IO error`——代理接受了 CONNECT 却没把隧道打通。

**第一处无效状态在回环中继自己**：`LoopbackIngestRelay` 给清单读了截止时间（`manifestTimeout`），子请求却两处
`await` 都没兜——响应头没到、或正文到一半停住，中继就一直等着，而 mpv 对"一个字节都没有"没有自己的钟，
于是判词落在流上（"opened but never played"），真正的失败（这条子请求我们没取完）一条日志都没留下。
修法是把截止时间补到子请求上：**按字节间隔算，不按总时长**（直播分片可以很大，大不等于卡住），
默认 10s——刻意落在 sweep 那 18s 验证窗之内，否则判词先到、原因后到。响应还没开始时按 502 回答，
正文已经开了头的就把这条连接提前结束，那是引擎能动作的信号。测试
`media_core_ingest/test/loopback_stalled_child_test.dart`（2 项，摘掉任一处 `.timeout` 就会挂到 30s 测试上限）。

**没动的一处，需要用户决定**：这台机器上同一个 host 的两条腿走的是两个开关——清单是探测阶段用
dio（应用层代理，此处未开=直连）读成功的，中继随后取子分片用的却是 `PlaybackProxyPolicy.currentDirective()`
（播放器代理 7897），而日志证明这条路对这个 host 是坏的。本仓所有其它中继上游取流
（`ffmpeg_flv_input_relay`/`flv_splice_relay`/`flv_legacy_hevc_relay`/录制侧 hls input）用的都是
`resolveUpstreamProxyDirective`＝应用层代理，只有这一个例外。把它对齐过去**这次就能播**，但会反过来伤到
"只开播放器代理、站点必须经它才可达"的那种配置（清单由 host 表判定、没有探测兜底时就是这么走的），
所以不在这一轮里单方面改。眼下这台机器的可行动作是：`livecloud.akamaized.net` 直连可达（探测已证明），
把播放器代理对该 host 留在直连即可播放。

### bigo 整站被要求登录：接口没坏、网络没坏，说的是"请重试"（2026-10-06，已修）

用户报"bigo live 无法获取信息"，并附一句 "bigo API request returned a non-JSON response."。
先把这句话证伪：把 `tool/probes/bigo_metadata_probe_test.dart`（import 早就指向搬走前的
`domains/live/data/platforms/...`）修好并扩成**走真房间路径 + 记录每次网络响应 + 连抽 6 间房**，
两条出口各跑一遍。DIRECT 与 `PROXY 127.0.0.1:7897` 结果一致：

| 这一趟 | 结果 |
| --- | --- |
| `ta.bigo.tv/official_website/OInterfaceWeb/vedioList/72` | 200 `application/json`，20 张卡片 |
| `sec.bigo.sg/v1/webjs/t` 与 `/status` | 200 `application/javascript`，JSONP 前缀对得上，token 拿到了 |
| `studio/getInternalStudioInfo` | 200 `application/json`，但 **6/6 房间** `needLogin:true`、`alive` 缺省、`hls_src:""`、`roomTopic:""` |

所以既不是"非 JSON"也不是被墙：**上游现在要求登录会话才给匿名接口了**（上游 4.x 在同一条路上抛
`ApiChanged`，见 `live_core/lib/src/sites/bigo/bigo_api.dart:845`）。本仓没有 bigo 的 cookie 入口
（`CookieSettingsController` 里就没有 `bigoCookie`），所以能不能播这一半没修，也不该假装修。

修的是**说什么**。两处叠在一起才让观众只看到一句会重试成功的话：

1. `BigoSite._room` 只在 `liveStatus == live` 时保留限制种类。登录墙下 `reportedAlive` 恒为 null
   （`access != public` 时故意不读 `alive`——"access-gated alive=0 is not a verified offline
   observation"），状态于是是 unknown，`restrictionOf(loginRequired)` 给出的 `needsLogin` 被丢掉。
   现在改成"确认在播 **或** 平台声明了受限就保留"，公开房间仍然只有确认在播才谈受限（普通下播
   不许冒充"需要登录"）。
2. 状态未知的房间走 `_handleUnknownStatus`，而它以前只说 `get_room_info_failed_retry`，从不看限制。
   `roomStateMessage` 提为可测的顶层函数，`unknownRoomStatusMessage(room)` 在平台声明了原因时按限制
   种类说（`restriction_needs_login`＝"该直播需要登录后才能观看。"），没有原因时才是那句重试；
   `loadError` 同步用它，所以提示消失后界面仍留着原因。

测试：`test/shared/platforms/bigo_login_wall_test.dart`（3 项：登录墙→needsLogin + unknown；公开下播
→offline 且限制为 null；公开在播有地址→不受限）与 `test/domains/live/unknown_room_status_message_test.dart`
（3 项）。mutation 各自验过：退回旧的 `liveStatus == live` 条件，第 1 组第一条就红（Actual: null）。
`_handleUnknownStatus` 里那句替换没有自动化覆盖——它要整套 GetX 房间壳，纯判定部分已单独测到。

### 还没声明的站点（上游有 format/codec，本仓待补）

**已补（2026-10-04 同批）**：bilibili（直播 `flv`/`ts`/`fmp4` 线路按 `parsePlayUrlResolution` 里的
`format_name`+`codec_name` 声明，`ts`/`fmp4` 与轮播稿件的 mp4 都是 `other`，不再被当清单探测）、
iptv（`iptvStreamFormat()`：`.m3u8`→清单，`.ts`/`/udp/`/`rtp:`/`udp:`/`rtsp:`→`other`，认不出的不声明、
照旧探测；上游 `f5ab30e79` 的同一判断）。测试见 `live_stream_facts_test.dart` 的"B 站与 IPTV 的线路声明"。

**待补**：sixroom（flv + 每条线路自己的 codec，若给出 hevc 就要走 FFmpeg 转封装）、inke（flv/avc）、
bigo / chzzk / huya / pandalive / picarto / seventeenlive / showroom / steambroadcast / twitch / yy / kilakila
（hls 或 flv，多数只是标注，不改变直连判定，价值在录制端与将来的线路选择）。

### 明确不做

上游 4.x 的 `live_media` / `live_player` 整包（plans、routes、loopback relay、transport、fallbacks、media_kit
fork、mpv engine、playback session）不搬：本仓播放走 media_core + media_core_live，转流走 media_core_ingest
的 FFmpeg 回环，职责已经对上；搬整包等于换播放栈。

## 未同步清单（2026-10 机械盘点 + 逐项核实）

方法：`git log --no-merges 4802611aa..wzgrx/master -- packages/live_core/lib/src/sites packages/live_danmaku/lib/src`
共 **204** 条站点层提交，其中 **131** 条在本文档里没有按 SHA 出现（本文档按主题而非逐 SHA 记账）。
按主题分类并逐项核实后：

### A. 真正还没同步（建议做）
| 上游提交 | 内容 | 本仓现状（已核实） |
| --- | --- | --- |
| `2eea8022a` 剩余 | 发送者头像 `user.base.face` → `DanmakuSender(avatar)` | **已做（`c9...`）**：`LiveMessage.avatar` + B 站 `_avatar()`（`base.face` → `origin_info.face`，`hdslb.com` 取 96×96）+ 列表画圆形头像（取不到不占位） |
| `2eea8022a` 剩余 | 游客/登录失效提示（列表顶部一行 + 去登录） | **已做**：列表顶部常驻提示条（游客 → `bilibili_guest_names_hidden` + 「去登录」；已登录但收到打码名 → `bilibili_login_expired_short` + 「重新登录」），按钮走 `AppNavigator.toBiliBiliLogin()`；i18n 四个 key 中英都加 |
| `0d63d2d3c` | 播放线路"声明图片尺寸"（F.1b，core+player） | **已做**：抖音档位解析平台声明的画面尺寸（`main.width/height` → `sdk_params.width/height` → `sdk_params.resolution` → 描述里的 `resolution`，尺寸 120–16384、宽高比 0.30–3.50）→ `LivePlayQuality.declaredAspectRatio` → `LivePlayUrlResolution` → `PlaybackSourceQualitySelection` → `LivePlayerFacade.currentPresentationAspectRatio` 在解码器报出真实尺寸前用它排版（没有才退回 16:9） |
| `51c28301b` | Twitch `RECONNECT`、撤回（`CLEARMSG`）、公告（`NOTICE`）、过期 cookie | **已完成**：撤回（`7c8b7f599`）、Cookie 失效提示 + 匿名回退（`22f659782`）、`USERNOTICE` 订阅/续订/赠送/突袭/公告（进列表当通知；观众附带的话作为该观众的聊天紧跟其后）；`RECONNECT` 与 cookie 解析本仓早有 |
| `f12bf0f8c` | socket 运行时"握手失败"钩子（M5.F B-1） | **不适用（无消费者）**：上游这个钩子唯一的用户是 **missevan 的会话续期**（握手被拒后换新 cookie 再试）；本仓的 `WebScoketUtils` 在构造时拿 `headers`、没有"每次握手取头"的通道，而本仓又没有 missevan 聊天引擎（EmptyDanmaku，用户决定不新增引擎）。此时移植就是**没有调用方的死代码**。若将来按"包含引擎"补 missevan，再连同这个钩子一起做 |
| `ff406a24f` | 虎牙公告栏面板（通知自带 board 时省一次请求） | **已做**：`uri 2001314` 的消息体先当留言板面板解（`GameEventMessageBoardPanel`）；是面板就直接上报它的条目（空面板 = 留言板已空，不再请求），不是面板（没有 tag 1 列表 / 解不开 / 空 body）才照旧后台补拉。字段映射与 WUP 补拉抽成共用的 `huyaSuperChatsFromPanel`，去重仍走既有 `_rememberSuperChat`；新增 `test/shared/platforms/huya_headline_panel_test.dart`（5 个用例，用本仓 Tars 写入器拼面板，不依赖上游 fixture） |
| `734eb8098` | 搜索按平台上报的粉丝数排序 | **基本已同步**：本仓早有 `LiveSearchSortMode.followers`（`search_ranking.dart`，粉丝 → 人气 → 平台顺序），且 bilibili/kuaishou/cc/chzzk/acfun/baidulive/kugoulive/liveme/picarto/17LIVE 等搜索卡片都填了 `followers`；本轮补上 **Twitch** 搜索卡片（`node.followers.totalCount`，持久化查询给了才有） |

### B. 不适用：用户已决定不为 EmptyDanmaku 站点新写聊天引擎
所有 M5.x/M5.F "新增某站聊天引擎"（BIGO、Kugou、LOOK、百度、六间房、JD、Steam、FC2、
PandaTV、CHZZK、SHOWROOM、KilaKila、Missevan、TwitCasting、AcFun、17LIVE、Picarto 等的
chat/comment/PK/礼物/付费问答/撤回/公告）——这些站点在本仓是 `EmptyDanmaku`（本仓只有 8 个
引擎：bilibili、douyin、douyu、huya、kuaishou、soop、twitch、yy）。**但这些站点的站点层
改动（限制、开播时间、取流等）已在前一个 goal 同步。**

### C. 不适用：本仓没有该站点
- Kick（`3381dac14` 恢复 Kick、`96e032864` Pusher 公共聊天）：本仓无 `kick` 目录
- Kugou 的 PK 聊天（`7f8ee2553`）：本仓有 `kugoulive` 目录但没有弹幕引擎（同 B 类）

### D. 之前搁置、**按用户 2026-10-04 最新指令恢复要做**（"上游做了本仓库也做"）
用户撤销了 2026-10-04 早些时候"就此收尾（不做身份翻转、轮播偏移停在 3/5）"的选择
（当时是点错选项），改为：**上游做了的本仓都要做**。因此下面两项重新进入待办：
- **B 站轮播 `play_time` 起播偏移第 4-5 步**：需先在产品层新增 seek 通道
  （`LivePlayerFacade → 适配器 seek`），再在 open 后首个状态事件 seek 一次
- **YouTube 频道即房间 / niconico 房间即主播**：包含收藏/历史旧 key 的迁移
  （惰性升级或一次性迁移），迁移策略见上文 ③ 一节

### E. 本次会话已同步（供对照）
`2eea8022a`（粉丝牌）、`40dc22279`（打码名不可屏蔽）、`fffd28b31`（表情图片）、
`aadad46ef`（占位字符）、`8d7da2dfc`（轮播取流）、`81733c1e6`（撤回与公告）、
`8eca75a32`/`ce7de2d01`（礼物进弹幕区）、`1ceb4f290`（撤回/公告消息模型）

## 同步状态总览（2026-10 收尾核对）

| 目标项 | 状态 | 证据 / 提交 |
| --- | --- | --- |
| ① `startedAt` 与 `restriction` 接入各站点 + UI + 拒绝路径 | **完成** | `restriction:` 39 处、`startedAt:` 20 处（`lib/shared/platforms/**`）；`LiveRestriction` 枚举与 `effectiveRestriction` 在 `core/models/live_room.dart`；拒绝路径 `live_play_controller.dart:790/818` + `_roomStateMessage`；`restriction_*` 文案在 `assets/i18n/{zh,en}.json` |
| ② 弹幕撤回 | **完成** | 模型 `LiveMessageType.retraction` + `LiveRetraction`（`89248f0ff`）、B 站解析（`0533df81b`）、显示层（`db09fc212`）、引擎按条撤回 `retractWhere`（flame_barrage `efada9c`）+ 本仓接线（`4966ca1ce`） |
| ② 礼物进弹幕区 | **完成（B 站）** | 解析 `SEND_GIFT`/`COMBO_SEND`/`GUARD_BUY` + 列表分支（`11a47144e`）；其余站点的 gift 上报可复用同一分支 |
| ② 消息表情图片 | **完成** | 模型 `43540cc10`、B 站解析 `9fb1ef1da`、列表渲染 `c4699764d`、画面渲染 `f587c26a3`、快手表情表 `c217b86bc` + `dffed3f69` |
| ② 公告头条 | **完成（B 站 + 虎牙结束通知）** | `LiveMessageType.notice` + B 站 `WARNING`/`CUT_OFF`（`6e79b8bda`）；虎牙 `uri 8001` 结束直播（`133725ed7`）。虎牙 board 面板解析（通知自带面板时省一次请求）属优化，未做 |
| ③ YouTube 频道即房间 | **已做（身份翻转）** | `_card` 的房间身份改为频道（`room.channelId`，没有才退回视频 id），链接给频道直播页；取流要的视频 id 由 `_videoId()` 给出（详情里的 `data.videoId` → 旧 key 的视频 id → 频道身份则用 `resolveReference` 换当前在播）；`_snapshot` 同时认频道与视频两种 key；刷新保持原房间身份 |
| ③ niconico 房间即主播 | **部分**：链接形态与主播链接可打开已完成（`abb4c7269`、`bb1f6fbae`）；**身份翻转未做**（与列表 `providerType` 映射是同一件事，需连迁移一起做） |
| ④ bilibili 付费房限制 | **完成** | `7f31d7756` |
| ④ bilibili 详情开播时间 | **完成** | `021741490` |
| ④ bilibili 新增弹幕事件 | **完成** | 撤回 / 贴纸表情 / 礼物 / 公告，见上 |
| ④ bilibili 轮播 `play_time` 起播偏移 | **3/5**：站点解析 + 契约 + 播放层结果已做（`4291990b6`）；第 4-5 步需**新增播放层 seek 通道**（本仓 `lib/` 里没有任何 seek 调用），已记账 |

**待用户决策（唯一）**：是否翻转 YouTube / niconico 的**房间身份**（视频/节目 → 频道/主播）。
收益：同一频道/主播换场后收藏、历史、多画面指向同一房间；代价：存量 key 需迁移或惰性升级，
"回看某一场"的语义变化。不做则现状功能等价（能打开、能播、能看弹幕），只是每场是新房间。

**用户决定（2026-10-04，已更正）**：早些时候选的 A（就此收尾）**是点错**；用户随后明确
指令「**上游做了 本仓库也做，上游有什么本仓库就添加什么**」。因此：
- **要做**身份翻转：YouTube 房间身份改为频道、niconico 改为主播（含旧 key 迁移）
- **要做** ④ 轮播 `play_time` 起播偏移第 4-5 步（先加播放层 seek 通道）
- 其余项照旧推进

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

**已做（2026-10，含身份翻转）**：
- 节目链接形态：`http` / `sp.live.nicovideo.jp` / `nico.ms/lv…`（`abb4c7269`）
- 主播链接可打开（`bb1f6fbae`）
- **身份翻转（房间即主播）**：`niconico_directory.dart` 按上游 `roomIdOf` 给房间身份
  ——`community`/`user` + 用户 id → `user/<id>`，`channel` + 频道 id → `ch<n>`，其余
  （含 `official`，官方节目不是它频道的房间）→ 节目号；`NiconicoApi.room` 两种身份都收
  （主播身份先换出当前在播的节目再读页面）；`NiconicoLink.url` 按身份给链接；
  站点 `_identity` 两种都收，取流/清晰度走 `_programIdOf`（主播 → 节目）；
  主播链接不再需要请求（房间身份就是主播）
- **迁移**：新条目用主播身份；**旧收藏/历史里的节目号照旧可用**（站点两种都收），
  所以不需要一次性的数据迁移；同一直播的两种 key 会并存，直到用户重新收藏

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
4. 结果消费处（source commit → open）：把 `startAt` 交给源/播放会话 —— **已做**
5. 播放器：open 完成后的第一个状态事件里 `if (startAt > 0) seek(startAt)`，**每条源只做一次**
   （重连/切档不重复跳）—— **已做**

**第 4-5 步落地要点（2026-10）**：`PlayerHandle` **本来就有** `Future<void> seek(Duration)`
（在 `media_core` 的 `player_handle_playback.dart` 这个 part 里，所以早先按
`player_handle.dart` 搜 `Future<` 时没看到），**不需要改 media_core**。实现：
`PlaybackSourceQualitySelection.startAt`（与 F.1b 的 `declaredAspectRatio` 同一条通道）→
facade 存 `_pendingSeekAt` → 在既有状态监听里 `_tryApplyPendingSeek()`：**时长 > 起点** 才
`seek` 并清空（每条源一次；换档/重连/中继重开都不重放），失败只记日志。

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

### 弹幕从来没连上过：接口谎报 mime，`getJson` 拿到的是字符串（2026-10-04，已修）

症状是弹幕区一直刷「六间房弹幕连接失败，正在重试」。那句话只出现在 `_loop` 的 catch 里，而 catch 里唯一会抛
的是取聊天服务器列表那一次请求——于是逐段实测：

- `GET https://v.6.cn/room/getChat.php?rid=<主播用户 id>` → **200**，体是
  `{"a":[],"b":[],"websock":["snbjg1.6rooms.com:5490",…]}`，任何 UA 都一样，`rid` 传错值也照样给列表。
- `wss://snbjg2.6rooms.com:5490` 握手 103ms（走 Clash 124ms），`command=login` 后 34ms 收到
  `enc=no / command=result / content=login.success`，随后持续下发 `enc=yes` 的 `receivemessage`。

两条腿都是好的，问题在中间那一步的**响应头**：`Content-Type: text/html; charset=UTF-8`。dio 只在 JSON mime
下才解码（`Transformer.isJsonMimeType`），所以 `getJson` 返回的是**字符串**；`_refreshServers` 问的是
`response is Map`，永远为假 → 静默 `return` → 服务器列表永远空 → `_loop` 抛
`StateError('六间房：没有取到聊天服务器')` → 每 1~8 秒重报一次"连接失败"。**这个站的弹幕一次也没连上过。**

修：按文本取（`getText`）、解码放进 `parseChatServers(String body)`（`@visibleForTesting`）。坏响应现在抛
`FormatException` 交给重试并在日志里留下真因，不再伪装成"站点没给服务器"。
测试 `test/shared/platforms/sixroom_danmaku_servers_test.dart` 用**真实响应头**回放（stub 适配器回
`text/html`），第一条就钉住"`getJson` 对这个接口给的是 String 而不是 Map"；另有 host/port 白名单与坏响应
两条。生产链路用修好的矩阵探针跑通：`roomId=58018 readyCount=1 reconnectCount=0 terminalCloseCount=0
chatCount=1 connectedAtEnd=true`（20 秒观测，`chatCount=1` 说明 DEFLATE + `( ) @` 变体 Base64 + `typeID`
过滤这条解码链在真实帧上是通的）。

**同一类陷阱的排查结果**（按各站自己的请求头实测 mime；只有 200/JSON 才算证明）：

| 站点 | 端点 | mime | 结论 |
| --- | --- | --- | --- |
| sixroom | `v.6.cn/room/getChat.php` | **text/html** | 曾经坏，已修 |
| chzzk | `routing.chat.naver.com/routing/getRouting` | application/json | 正常 |
| bigo | `ta.bigo.tv/…/getWebSocketLink` | application/json | 正常 |
| kugou | `fx1.service.kugou.com/socket_scheduler/…address.jsonp` | application/json | 正常（`.jsonp` 后缀但回 JSON） |
| picarto | `ptvintern.picarto.tv/ptvapi` | application/json | 正常 |
| seventeenlive | `api-dsa.17app.co/api/v1/messenger/auth` | application/json | 正常 |
| jdlive | `api.m.jd.com/api` | application/json | 正常——**但只在带上 `Origin`/`Referer: live.jd.com` 与完整表单时**；裸请求回的是 `text/plain`。mime 探测必须复刻真实请求头，否则会得到相反结论 |
| kuaishou | `livev.m.chenzhongtech.com/…` | 未证明（要 cookie 与 `liveStreamId`） | 结构上安全：`parseFeedPayload` 对 String 反复 `jsonDecode` |
| twitcasting | `twitcasting.tv/eventpubsuburl.php` | 未证明（`movie_id=0` 只拿到 400 text/html） | 待核：同样是 PHP 栈，和 6.cn 同族，下一个最可能踩坑的 |
| steambroadcast | `steamcommunity.com/broadcast/getchatinfo/` | 未证明（无效 steamid 只拿到 500 + application/json） | 待核 |

**顺带修好的工具**：`tool/probes/danmaku_connection_matrix_probe_test.dart` 之前根本编译不过——两个导入还指着
搬家前的 `domains/live/domain/live_{danmaku,site}.dart`，`getRoomDetail` 也还在用旧的
`(roomId:, platform:)` 具名签名（现在是 `getRoomDetail(LiveRoom)`）。改成把发现的房间原样交给站点自己的详情
路径（`danmakuData` 是详情阶段才拼出来的，探针不该自己重建房间），并把 sixroom 加进受支持列表。
探针里那屏 `Localization key [sixroom_chat_notice] not found` 是**探针环境**没加载翻译资源，五个键在
`assets/translations/{zh,en}.json` 里都在，不是产品缺陷。

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
