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
| pandalive / picarto / seventeenlive | 11 | pandalive、picarto 本轮已摘取（见下）；seventeenlive 待办 |
| twitch | 10 | 本轮已摘取（见下） |
| soop | 10 | 本轮已摘取（见下） |
| chzzk | 10 | 本轮已摘取（见下） |
| kugoulive | 10 | 本轮已摘取（见下） |
| bigo / fc2live | 9 | 待办 |
| missevan / kilakila / acfun | 8 | 待办 |
| jdlive / looklive / steambroadcast / twitcasting / showroom / sixroom / baidulive | 7 | 待办 |
| cc | 5 | 本轮已摘取（见下） |
| tiktok | 5 | 待办 |
| inke / xiaohongshu / weibo / liveme | 4 | 待办 |

## bilibili

上游相关提交（按时间）：

| 提交 | 内容 | 本仓状态 |
| --- | --- | --- |
| `0811c21f7` | 心跳人气占位值 1 不再顶掉详情里的真实热度（REG-BILIBILI-015） | **已同步** |
| `12d03ac89` | `live_status` 2 = 轮播（详情/刷新/搜索）、`startedAt`、付费房限制 | **部分同步**：状态与轮播取流已做；`startedAt`、付费限制未做 |
| `8d7da2dfc` | 轮播视频播放（`getRoundPlayVideo` + `x/player/playurl`）、`LivePlayUrlResolution.start` | **部分同步**：取流已做；`start` 起点（`play_time` 续播）未做 |
| `81733c1e6` | 游客可用分区页、搜索分区标签、弹幕撤回与公告 | 待办 |
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
| `8eca75a32` | `dgb` 礼物包上报为 gift 消息 | 未做：上游自己也是"只上报不显示"，本仓弹幕层不渲染 gift，单独做等于死代码 |
| `20c9ea20e` | `expire=0` 的 FLV 强制续期（构造开关，默认关） | 未做：上游默认关闭，且本仓没有这个设置项；本仓对 `expire<=0` 仍视为无租约 |
| `20c9ea20e` | `startedAt` 取 betard `show_time` | 未做：本仓 `LiveRoom` 没有该字段 |
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
| `ce7de2d01` | `uri 6501` 礼物包上报为 gift | 未做：同斗鱼，本仓弹幕层不渲染 gift |
| `dc2080a18` | REPLAY 房播放录制（`liveData.hls` + `moment/getMomentContent` 的清晰度）、`startedAt`、付费/密码房限制 | 未做：一整块新能力，需要新接口与新字段 |
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
| `59602ec7b` | 开播时间：enter 无 `startedAt` 时补一次 reflow（最多 3 秒，按 room_id 记忆） | 未做：本仓 `LiveRoom` 没有该字段，且要多一次请求 |
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
| `ab456b879` | 限制 `unplayable`（平台说在播但没有任何可播清晰度） | 未做：本仓没有限制模型 |
| `4f1a8b4a8` | 快手卡片标题之外的 Twitch 部分 | 见 twitch 章节 |

## 跨站点公共

| 上游提交 | 内容 | 本仓状态 |
| --- | --- | --- |
| `aadad46ef` | 平台留在"原本有图"位置的不可见占位字符（快手标题里的 U+FFFC 会画成 "OBJ"）在创建时就清掉：房间的 title/nick/introduction/notice、弹幕的消息与用户名 | **已同步**（房间与弹幕消息两层）；超级留言文本未覆盖 |

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
| 开播时间 / 限制 | `startat`（北京时间）与"有档位即无限制" | 未做：本仓 `LiveRoom` 没有这些字段 |

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
| 11-9 | 私密频道按 private 限制展示 | 未做：限制模型 |
| `863bbf99c` 等 | Picarto 弹幕本体 | 未做：新功能批次 |
