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
| yy | 12 | 待办 |
| niconico | 11 | 待办 |
| pandalive / picarto / seventeenlive | 11 | 待办 |
| kugoulive / soop / chzzk / twitch | 10 | 待办 |
| bigo / fc2live | 9 | 待办 |
| missevan / kilakila / acfun | 8 | 待办 |
| jdlive / looklive / steambroadcast / twitcasting / showroom / sixroom / baidulive | 7 | 待办 |
| cc / tiktok | 5 | 待办 |
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
