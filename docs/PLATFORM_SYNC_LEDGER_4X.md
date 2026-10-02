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
| douyin | 20 | 待办 |
| kuaishou | 16 | 待办 |
| youtube | 15 | 待办 |
| huya | 15 | 待办 |
| douyu | 14 | 待办 |
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
