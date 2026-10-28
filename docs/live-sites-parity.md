# Live Sites 参考对齐台账（站点能力 / 线路 / 弹幕 / 登录）

> 目的：以参考仓库 `E:\study\pure_live\packages`（`live_core/lib/src/sites`、`live_danmaku/lib/src/sites`，v5 monorepo，2026-10-09）为准，逐站核对 `packages/live_sites`（v2 能力发现式，34 站）的能力、流类型与线路、弹幕消息、登录，缺失的补齐、错误的修正。
>
> 规则：参考仓库只读，不照搬其架构（参考是 `LiveSite` + 可选接口，目标是 `capability<T>()`）；目标源码注释用英文，本文用中文；平台特例只留在 `platforms/<id>/`；不伪造能力（`capability<T>()` 返回 null 即不支持）。每次改动后 `dart analyze packages/live_sites` 必须 0 issues。
>
> 盘点日期：2026-10-27。基线：`dart analyze packages/live_sites` 通过。

---

## 0. 总览

两边的平台集合一致：各 34 站；参考有弹幕的 28 站与目标一致（CC、映客、LiveMe、TikTok、微博、小红书 无弹幕）。

目标 `lib/src/capabilities/` 已声明的 20 个能力接口里，**站点实际装配的只有 9～10 个**；下表是逐站装配现状（✓ = 已接线，— = 该站不适用，空 = 能力存在但该站未实现）：

| 能力 | 参考对应 | 目标装配站点 |
|---|---|---|
| `LiveRoomProvider` | `getRoomDetail` | 34/34 |
| `LiveAreaProvider` | `getCategories` / `getCategoryRooms` | 30/34（liveme、tiktok、xiaohongshu、youtube 无分区，与参考一致） |
| `LiveDiscoveryProvider` | `getRecommendRooms` | 34/34 |
| `LiveSearchProvider` | `searchRooms` / `searchAnchors` | 34/34；主播搜索 7 家（acfun、bilibili、cc、douyu、huya、kuaishou、yy）与参考一致 |
| `LivePlaybackProvider` | `getPlayQualities` / `getPlayUrls` | 34/34 |
| `LiveDanmakuProvider` | `LiveDanmaku` 注册表 | 28/28（无弹幕的 6 站与参考一致） |
| `LiveLinkResolver` | `LiveSiteLinks` | 34/34 |
| `LiveAuthCapability` | 平台账号 9 家（cookie / 扫码） | 9/9（bilibili、cc、douyin、douyu、huya、kuaishou、soop、twitch、yy） |
| `LiveCookieRefusalFeed` | `LiveSiteCookieRefusals`（仅 Twitch 实现：过期 cookie 被拒后匿名继续） | 1/34：twitch（`cookieRefusals` 广播流；播放令牌先带会话、被拒后匿名重取，同一 cookie 只报一次）；App 尚未消费 |
| `LiveSuperChatFeed` | `getSuperChatMessage` 有真实看板的仅 bilibili、huya | 2/2：huya、bilibili（2026-10-27 接线） |
| `LiveStatusCheck` | 34 站均实现 `getLiveStatus` | **34/34**（2026-10-27 第二批完成） |
| `LiveRoomRefresh` | 34 站均实现 `LiveSiteRoomRefresher` | **34/34**（历史刷新全平台可用） |
| `LivePlayRecovery` | 10 站实现 `LivePlayRecoveryResolver` | **10/10**（2026-10-27 第三批完成：huya、douyu、douyin 直接委托；kick、kuaishou、picarto、soop、twitcasting、twitch、xiaohongshu 先加 `fresh` 缝再委托） |
| `LivePlayLeaseLookup` | 参考仅 huya 实现 `LivePlayLeaseMetadata`（按 URL 反查租约） | **13/34**：huya（`wsTime`/`seqid`）、bilibili（`expires`）、acfun/cc/kilakila（`auth_key`）、kuaishou（`txTime`/`wsTime`/`auth_key`）、inke（`wsABStime`）、kugoulive（`txTime`）、missevan（`expires`）、tiktok（`expire`）、youtube（`expire`）、yy（FLV `t`）、douyin（`expire`/`volcTime`/`wsTime`/`t`）；已过期地址返回过去的租约而非 null |
| `LivePlaybackPlanResolver` | 参考以 `appliedQualityData` 表达（B 站访客降画质、CC `vbrname_sel`、抖音实际 variant、YY 实际档位、Twitch 换档回退） | **5/34**：bilibili、cc、douyin、yy、twitch（bilibili 轮播另带 `play_time` 起始偏移） |
| `LiveSuggestCapability` | 参考无（4.x 未做搜索联想） | 0/34；App 入口已接（`search_controller.dart:202`），无站点时静默 |
| `LiveAnchorProvider` | 参考 `getAnchor` 无独立接口（主播搜索在搜索里） | 0/34 |
| `LiveHotProvider` | 参考热门页走 `getRecommendRooms`（即 Discovery） | 0/34；仅工具箱测速兜底用到 |
| `LiveDanmakuSending` | 参考无发送能力 | 0/28；App 的 `canSendDanmaku` 因此恒 false |
| `LiveWebSearchProvider` | 参考网页搜索在 App 层 | 0/34 |

参考另有一个目标没有的接口，暂不新增（App 未消费，且属于展示层）：
- `LiveDirectoryNotice`（分区页的常驻说明文案）。

---

## 1. 站点能力差异

### 1.1 已声明未实现（优先级从高到低）

1. ~~**`LiveSuperChatFeed` / bilibili**~~：2026-10-27 已接（`BilibiliSuperChatFeedProvider`，读 `av/v1/SuperChat/getMessageList`）。参考实现：`live_core/lib/src/sites/bilibili/bilibili_site.dart:412`。
2. ~~**`LiveRoomRefresh` / 34 站**~~：2026-10-27 已全部接入。参考每站 `getRoomDetailForRefresh`，多数与详情同一次请求；重的读做了更轻的缝：acfun 不调 `startPlay`、cc 同元数据、chzzk 不读 masters、kilakila 不读 `roomInfo`、showroom 不读 stream rows、sixroom 用 `summary`、kugoulive 只读 info、pandalive 只读 member、picarto `stream:false`、tiktok 不取 media、twitcasting 只读 streamserver、liveme/jdlive/looklive/steambroadcast `media:false`、bigo 用复用 token。
3. ~~**`LiveStatusCheck` / 34 站**~~：2026-10-27 已全部接入（复用各站刷新读的一比特；bilibili 仍走独立 `get_info`）。
4. ~~**`LivePlayLeaseLookup` / 签名站**~~：2026-10-27 已接 13 站。huya 按 `wsTime`/`seqid` 反查；bilibili（`expires`）、acfun/cc/kilakila（`auth_key`）、kuaishou（`txTime`/`wsTime`/`auth_key`）、inke（`wsABStime`）、kugoulive（`txTime`）、missevan（`expires`）、tiktok/youtube（`expire`）、yy（FLV `t`）、douyin（`expire`/`volcTime`/`wsTime`/`t`）按 URL 的绝对过期时间反推。解析器新增 `allowExpired`（或用无过期检查的 `lease`）：已过期地址返回过去的租约而非 null，避免被读成「无租约 = 永久有效」。douyu 的 `expire` 是签发时长、chzzk 的变体可能继承 master 的令牌、niconico/kick 的过期不在行 URL 里，暂缓。
5. ~~**`LivePlayRecovery` / 参考 10 站**~~：2026-10-27 已完成。huya、douyin、douyu 直接委托；kick、kuaishou、picarto、soop、twitcasting、twitch、xiaohongshu 先给流读取加 `fresh` 参数绕过缓存，再由 `PlayRecovery` 委托 `refetchLines`。
6. ~~**`LivePlaybackPlanResolver`**~~：2026-10-27 已接 5 站：bilibili（`current_qn`）、cc（`vbrname_sel`）、douyin（实际 variant）、yy（流管理器实际档位；降级线路标未确认）、twitch（按 id/VIDEO/标签匹配，找不到时回退源流并报告实际档位）。bilibili 轮播计划另带 `play_time` 起始偏移。App 尚未消费，P1。
7. **`LiveSuggestCapability` / `LiveHotProvider`**：目标 App 已有入口，参考没有对应站点接口；只有确证站点有联想/热榜 API 才实现，不伪造（`ARCHITECTURE.md` §7.5）。当前清单里没有证据，保持空。
8. **`LiveDanmakuSending`**：参考无发送；目标接口已定义、App 已接 `session is LiveDanmakuSending`。没有站点级发文协议证据前不实现。
9. ~~**`LiveCookieRefusalFeed` / twitch**~~：2026-10-28 新增能力接口（参考 `LiveSiteCookieRefusals` 的唯一实现者也是 twitch）。站点在播放令牌带会话被拒（401 或人机挑战）后记下该 cookie 并匿名重取，同时向 `cookieRefusals` 广播一次；同一 cookie 不再重试，因此每个 cookie 只报一次。聊天侧原本就有过期提示（`TwitchDanmakuProtocol.cookieExpiredNotice`），两者互不替代。

### 1.2 已存在能力正确性（本轮抽查）

- 搜索目标：7 家主播搜索与参考一致；yy/douyin 额外支持分区搜索（参考 `searchAreas` 同类）。
- 分区：liveme/tiktok/youtube 无 `LiveAreaProvider`，与参考的目录能力一致（youtube 只有推荐流）。
- 弹幕能力覆盖：28 站与参考一致；CC/映客/LiveMe/TikTok/微博/小红书 无弹幕，与参考相同。
- 登录 9 家与参考的 `accountPlatforms`（bilibili、douyu、huya、douyin、kuaishou、yy、cc、twitch、soop）完全一致，详见 §4。
- 流类型枚举比参考多（dash、webrtc、mp4、mpegts 等），每站的线路都声明 `format` + `formatSource`，没有留空的。
- 实际画质确认：参考里 `appliedQualityData` 真正来自服务端确认的是 bilibili（`current_qn`）、cc（`vbrname_sel`）、douyin（实际 variant）、yy（流管理器档位）、twitch（换档回退）；huya/kuaishou/soop 只是回显请求档位，不计入 `LivePlaybackPlanResolver`。目标已按这条界线接入 5 站，降级/兜底线路标 `qualityUnconfirmed`。
- 参考独有的接口逐项核对：`LivePlayUrlCursorResolver`（douyu/huya/niconico 逐线录制）与 `LiveQualityDiscovery`（chzzk/fc2live/niconico 可取消画质发现）在目标没有对应接口，App 也未逐线/带 `CancelToken` 调用，暂不新增；`LiveSearchPaginationPolicy`（inke/kilakila/missevan/youtube）在目标由 `LivePage.hasMore` 按响应表达，App 不消费按关键词的策略；`LiveSiteDirectoryPager` 家族由 `LiveRoomProvider.getRooms`（`LivePageRequest.cursor`）与 `LiveAreaProvider` 承担。
- 房间元数据（2026-10-28 复核）：`introduction`/`notice` 逐站对照后，niconico 的节目说明、youtube 的频道简介与在线人数说明已补齐（L31）；其余写 `introduction`/`notice` 的站点（acfun、fc2live、kilakila、missevan、pandalive、bilibili、chzzk、douyu、huya、kuaishou、seventeenlive、soop、twitch、weibo、xiaohongshu）与参考一致；参考给 twitch/douyin/soop 写空串的地方目标直接省略，语义相同。弹幕心跳间隔 24 站逐站相同（10/15/16/20/25/30/40/45/50/60 秒）。

---

## 2. 流类型与线路信息

目标 `LivePlayLine` 的字段：`url`、`format`（必填）、`formatSource`、`headers`、`codec`、`lineLabel`、`lease`、`geometry`、`singleUse`。参考 `LivePlayLine` 只有 `url`、`headers`、`format?`、`codec?`、`lineId`、`lease`、`width/height`——目标字段不缺失（`lineId` 由 `lineLabel` 承担，宽高在 `geometry`）。

逐站线路元数据覆盖（`format` 全部有，下表只列其余）：

| 站点 | format | lease | codec | lineLabel | geometry |
|---|---|---|---|---|---|
| acfun | flv/hls | ✓ | — | ✓ | — |
| baidulive | flv/hls | — | ✓ | ✓ | ✓ |
| bigo | hls | —（自带分片保护，无签名过期） | — | ✓ | — |
| bilibili | flv/hls/mp4/other | ✓ | ✓ | ✓ | — |
| cc | flv/hls/other | ✓ | — | ✓ | — |
| chzzk | hls | ✓ | ✓ | ✓ | ✓ |
| douyin | flv/hls | ✓ | ✓ | ✓ | ✓ |
| douyu | other（FLV/TS 由首字节判定） | ✓ | — | ✓ | — |
| fc2live | hls | ✓ | — | ✓ | — |
| huya | flv/hls | ✓ | ✓ | ✓ | — |
| inke | flv | ✓ | ✓ | ✓ | — |
| jdlive | flv/hls | — | — | ✓ | — |
| kick | hls | ✓ | ✓ | ✓ | ✓ |
| kilakila | flv/hls | ✓ | — | ✓ | — |
| kuaishou | flv/hls | ✓ | ✓ | ✓ | — |
| kugoulive | flv/hls | ✓ | ✓ | ✓ | — |
| liveme | flv/hls | — | — | ✓ | — |
| looklive | flv/hls | — | ✓ | ✓ | — |
| missevan | flv/hls | ✓ | — | ✓ | — |
| niconico | hls | ✓ | ✓ | ✓ | ✓ |
| pandalive | hls | ✓ | ✓ | ✓ | ✓ |
| picarto | hls | — | ✓ | ✓ | ✓ |
| seventeenlive | flv | — | ✓ | ✓ | — |
| showroom | hls | — | — | ✓ | — |
| sixroom | flv | — | ✓ | ✓ | ✓ |
| soop | flv/hls | — | ✓ | ✓ | — |
| steambroadcast | hls | — | ✓ | ✓ | ✓ |
| tiktok | flv/hls | ✓ | ✓ | ✓ | ✓ |
| twitcasting | hls | — | — | ✓ | — |
| twitch | hls | — | ✓ | ✓ | ✓ |
| weibo | flv/hls/other | — | ✓ | ✓ | — |
| xiaohongshu | flv/hls | — | ✓ | ✓ | — |
| youtube | dash/hls/mp4 | ✓ | ✓ | ✓ | ✓ |
| yy | hls/other | ✓ | — | ✓ | ✓（移动 HLS） |

结论：流类型比参考只多不少；几何信息从 2 站扩到 13 站（baidulive、chzzk、douyin、kick、niconico、pandalive、picarto、sixroom、steambroadcast、tiktok、twitch、youtube 及 yy 的移动 HLS 线路写入 `PlayGeometry`，平台声明多少写多少）；huya/soop/kuaishou 暂缓（height 未流入线路函数 / 线路函数无分辨率 / 分辨率仅页面脚本样本）。**没有租约的 15 站已逐站核对源码注释，均为「地址本身无签名/无过期」**（baidulive 无签名、bigo 分片保护、jdlive 无签名或过期、liveme `wsABStime` 不被校验、looklive 无签名、picarto 无签名、seventeenlive 未签名、showroom 不过期、sixroom 无过期、soop 播放列表自持、steambroadcast 无签名、twitcasting 无签名、twitch 播放列表长于 token、weibo 无签名、xiaohongshu 未签名），不需要补 lease。`LivePlayLeaseLookup` 只对 URL 里带绝对过期时间的签名站有意义；douyu（`expire` 是签发时长）、niconico/kick（过期不在行 URL 里）、chzzk（变体可能继承 master 令牌）不适用。

---

## 3. 弹幕与礼物

逐站对比参考 `live_danmaku/lib/src/sites/<id>.dart` 与目标 `platforms/<id>/danmaku/<id>_danmaku_codec.dart` 上报的消息类型：

| 站点 | 参考类型 | 目标类型 | 差异 |
|---|---|---|---|
| acfun | chat/gift/online | chat/gift/audienceUpdate | 一致 |
| baidulive | chat/gift/online | chat/gift/audienceUpdate | 一致 |
| bigo | chat/gift/online | chat/gift/audienceUpdate | 一致（参考调研里 BIGO 礼物的缺口已补） |
| bilibili | chat/gift/notice/online/retraction/superChat | 同 | 一致 |
| chzzk | chat/notice/retraction/superChat | 同（订阅是 notice） | 一致 |
| douyin | chat/online | chat/audienceUpdate | 一致；礼物匿名端收不到（参考 V03.5 受阻项） |
| douyu | chat/gift/superChat | 同 | 一致 |
| fc2live | chat/online | chat/audienceUpdate | 一致；打赏/礼物仍缺（参考亦缺，须先录样本） |
| huya | chat/gift/online/superChat | 同 | 一致 |
| jdlive | chat/online | 同 | 一致（平台无礼物） |
| kick | chat/gift/notice/retraction/superChat | +system | 目标更全 |
| kilakila | chat/gift/online/superChat | 同 | 一致 |
| kuaishou | chat/online | 同 | 一致（平台限制，参考 V03.5：不做） |
| kugoulive | chat/gift/online | 同 | 一致（参考里 601 礼物缺口已在目标补齐） |
| looklive | chat/gift | 同 | 一致（参考里 LOOK 102 缺口已补） |
| missevan | chat/gift/notice/online/retraction/superChat | 同 | 一致 |
| niconico | chat/gift/notice/online | 同 | 一致 |
| pandalive | chat/gift | 同 | 一致（参考里 후원 缺口已补） |
| picarto | chat/notice/online/retraction/superChat | 同 | 一致（Kudos 走 superChat） |
| seventeenlive | chat/gift/notice/online/superChat | 同 | 一致（参考里礼物 13 缺口已补） |
| showroom | chat/gift | 同 | 一致（参考里礼物缺口已补） |
| sixroom | chat/gift/superChat | 同 | 一致（飞屏 108 按参考 V03.5 当醒目留言） |
| soop | chat/gift/notice | 同 | 一致（星气球/订阅已解） |
| steambroadcast | chat/online | 同 | 一致（平台无礼物） |
| twitcasting | chat/gift | 同 | 一致（`gift=1` 已开） |
| twitch | chat/gift/notice/retraction | 同（Bits 为 gift） | 一致（参考里 Bits 缺口已补） |
| youtube | chat/gift/notice/online/retraction/superChat | +membershipJoin +送会员通知 | 目标更全（`GiftPurchaseAnnouncement` / `GiftRedemptionAnnouncement` 已补） |
| yy | chat/online | 同 | 一致（参考 V03.5：C-20 受阻） |

结论：**礼物同步已基本完成**；剩余的是平台限制/受阻项（douyin 匿名、kuaishou、yy、fc2 打赏）与目标独有的 `enter/leave/follow/like/membershipJoin/system` 类型尚未在更多站点使用（参考也没有，不补造）。

---

## 4. 登录能力

9 家与参考 `apps/pure_live/lib/features/account/account_platforms.dart` 一致。目标实现与参考的 cookie 校验方式对照：

| 站点 | 参考校验方式 | 目标 `LiveAuthCapability` | 结论 |
|---|---|---|---|
| bilibili | 在线查询（`x/web-interface/nav`），另有扫码 / 网页登录 | cookie 粘贴 + 扫码（`supportsQrLogin`）+ 在线校验 | ✓ |
| douyin | 在线查询昵称 | cookie 粘贴 + 在线校验 | ✓ |
| douyu | 本地解析 session token / 到期 / 续期对 | cookie 粘贴 + 本地判定（无账号接口） | ✓ |
| huya | 本地 `yyuid` | cookie 粘贴 + 本地判定 | ✓ |
| kuaishou | 无校验（存 cookie） | cookie 粘贴，`fetchAccount` 不支持 | ✓ |
| yy | 无校验（存 cookie） | 同上 | ✓ |
| cc | 无校验（存 cookie，`usedByRequests=false`） | cookie 粘贴，读取/校验不支持 | ✓（与参考一致：CC 目前只存不发给弹幕） |
| twitch | 本地 `auth-token` + `login` | cookie 粘贴 + 本地解码校验 | ✓ |
| soop | 无校验（存 cookie） | cookie 粘贴，`fetchAccount` 不支持 | ✓ |

结论：登录能力与参考对齐，没有缺失的站点。运行期验证仍需要真实 cookie（见任务队列 V 项）。过期 cookie 的站点侧反馈：twitch 已接 `LiveCookieRefusalFeed`（播放令牌被拒时广播一次，带聊天侧的过期提示），其余站点没有「拒绝后仍匿名可用」的对应行为。

---

## 5. 任务队列

### P0 本轮实施（2026-10-27 完成）

- [x] L1 bilibili：`LiveSuperChatFeed`（接 `BilibiliRoomProvider.superChats`）
- [x] L2 bilibili：`LiveStatusCheck`（接 `BilibiliRoomProvider.liveStatus`）
- [x] L3 bilibili：`LiveRoomRefresh`（元数据读，不含弹幕握手；录制读同一元数据）
- [x] L4 huya：`LiveRoomRefresh` + `LiveStatusCheck`（`profileRoom`，与参考同开销）
- [x] L5 huya：`LivePlayLeaseLookup`（`HuyaPlayParser.lease`，按 URL 的 `wsTime`）
- [x] L6 douyu：`LiveRoomRefresh` + `LiveStatusCheck`（详情复用）
- [x] L7 acfun：`LiveRoomRefresh`（`live/info`，不调 `startPlay`）+ `LiveStatusCheck`
- [x] L8 chzzk / kick / kilakila：`LiveRoomRefresh` + `LiveStatusCheck`（刷新用更轻的读：chzzk 不读 masters、kilakila 不读 `roomInfo`、kick 不带聊天运行时句柄）
- [x] L9 douyin / kuaishou：`LiveRoomRefresh` + `LiveStatusCheck`（详情复用；douyin 刷新不取开播时间、不带弹幕句柄）

### P1 下一轮

- [x] L10 其余 25 站（cc、yy、soop、twitch、youtube、seventeenlive、showroom、sixroom、weibo、xiaohongshu、inke、liveme、baidulive、bigo、fc2live、jdlive、kugoulive、looklive、missevan、niconico、pandalive、picarto、steambroadcast、tiktok、twitcasting）：`LiveRoomRefresh` + `LiveStatusCheck`（2026-10-27 完成，34/34）
- [x] L11a `LivePlayRecovery` 剩余 7 站：kick、kuaishou、picarto、soop、twitcasting、twitch、xiaohongshu——给各自的流读取加 `fresh` 参数（绕过 `_streams`/`_entries`/`_cached`），provider 增加 `refetchLines`，再由 `<id>_play_recovery.dart` 委托
- [x] L11b `LivePlayRecovery`：huya、douyin、douyu（`getLines` 无缓存，直接委托）
- [x] L12 `LivePlayLeaseLookup`：bilibili、acfun、cc、kuaishou、inke（解析器加 `allowExpired`，已过期时返回过去的租约而非 null，避免「无租约=永久有效」的误判）。douyu/yy 的到期是「签发时长」而非绝对时间，不能只凭 URL 反查，暂缓。
- [x] L13 `LivePlaybackPlanResolver`：bilibili（`current_qn` 实际画质、轮播起始偏移）
- [x] L14 流类型/线路复核：参考对 12 个无租约站均有明确注释（baidulive 无签名、bigo 分片保护、picarto 无签名、seventeenlive 未签名、showroom 不过期、sixroom 无过期、soop 播放列表自持、steambroadcast 无签名、twitcasting 无签名、twitch 播放列表长于 token、weibo 无签名、xiaohongshu 未签名），确认无需补 lease
- [x] L19 `LivePlaybackPlanResolver` 扩到 5 站：cc（`vbrname_sel`，3.x 兜底档位标未确认）、douyin（实际 variant）、yy（流管理器实际档位，降级线路未确认）、twitch（匹配失败回退源流并报告实际档位）；bilibili 已在前批完成
- [x] L20 `LivePlayLeaseLookup` 扩到 12 站：新增 kilakila、kugoulive、missevan、tiktok、youtube、yy（URL 带绝对过期时间；已过期返回过去租约）。同时修正台账：jdlive/liveme/looklive 实际无 lease，分区能力为 30/34
- [x] L21 线路几何信息：niconico、pandalive、picarto、steambroadcast、youtube、yy（移动 HLS）把解析器已有的宽高/帧率/码率写入 `PlayGeometry`；几何覆盖 2 → 8 站
- [x] L22 线路几何信息（续）：chzzk、sixroom、tiktok、twitch 接入；几何覆盖 8 → 12 站。huya（height 未流入线路函数）、baidulive（变体未保留 height）、soop（线路函数无分辨率）、kuaishou（分辨率仅在页面脚本样本里）暂缓
- [x] L23 收尾：douyin 接入 `LivePlayLeaseLookup`（无签发时间的绝对过期解析，13/34）；niconico 线路补 `CODECS` 与帧率；baidulive 变体保留 height 并写入几何（13 站）；huya/soop/kuaishou 仍暂缓（height 未流入线路函数 / 线路无分辨率 / 分辨率仅页面脚本样本）
- [x] L24 弹幕补齐：YouTube 的送会员两种 renderer（`liveChatSponsorshipsGiftPurchaseAnnouncementRenderer`、`…GiftRedemptionAnnouncementRenderer`）按参考补为通知（购买为 `subscription`，收到为 `giftedSubscription`）
- [x] L25 新增 `LiveCookieRefusalFeed` 能力并接 twitch：播放令牌被拒时广播一次（同一 cookie 只报一次），站点继续匿名取令牌；补 twitch 两条测试（拒绝 → 事件 + 匿名重取 + 后续不再带该 cookie；接受 → 无事件）
- [x] L26 弹幕字段收尾审计：Bigo `ticket_num`（主播豆子总数）、Missevan `lucky`（抽奖来源礼物）、seventeenlive `combo.validDurationMs`（连送窗口）属参考站点子类里的检查用信息，目标共享模型无对应字段，保持现状（解析器注释已说明），不为单站扩公共模型
- [x] L27 全量复核（§7）：醒目留言/通知/emote/badge/礼物表/事实表逐项与参考一致；参考独有的录制详情、可取消搜索、画质发现、目录分页、CatchUp/EPG、目录说明逐项判定不适用或已等价
- [x] L28 修正三处已存在能力的事实/注释错误：`LiveMessageType.superChat` 的 payload 说明、`LiveSuperChatFeed` 的看板平台列表（去掉 douyu）、`SiteFacts.caseInsensitiveRoomIds` 补 TikTok/PandaTV
- [x] L29 用参考向量给已存在能力补回归测试：huya 的 `rotateUid` 向量与 `lease`（web 签名 125 s/100 s、native FLV 以 `wsTime` 结尾且不重连、静态令牌按构建时间、令牌窗口取最早、已过期仍返回过去租约、无界返回 null）；`SiteFacts` 五张事实表；礼物档位阈值（10/100 元、各币种汇率、不可评级单位）
- [x] L30 线路与礼物再补回归测试（对照参考注释与 REG 结论）：bilibili 线路候选排序（请求档优先、`http_stream` 先于 `http_hls`、flv<ts、avc 先、mcdn 靠后）、同 codec 与 URL 去重、`expires` 租约、画质取各 codec 的 `qn` 并按档降序、访客请求 10000 实际 250（REG-BILIBILI-001）、未知容器不出线路与缺 `playurl` 报 api-changed；pandalive `SponCoin` 心（`tip`、하트 计价、附言转聊天、엑셀방송 收礼人、`ItemCoin`/0 心/坏 JSON 不出消息）；looklive 礼物 102（音符计价、图标升 https、收礼人、非 102/无 id/坏 custom 不出礼物）
- [x] L31 房间元数据复核：逐站比对 `introduction`/`notice` 与心跳间隔后发现两处真缺口——niconico 补房间说明（未开播/匿名不可看的限制原因/节目收藏范围，文本按参考 zh.json，去掉已接入弹幕后不再适用的尾巴）、youtube 补 `shortDescription` 说明与「只在有并发字段时显示在线人数」的常驻说明；其余站点（acfun/kilakila/missevan/pandalive/fc2live 等）两边一致；24 站弹幕心跳间隔逐站相同。补 niconico、youtube 测试 7 条
- [x] L32 关注数与链接复核 + sixroom 礼物/飞屏回归测试：关注数在目标是 `LiveAnchor.followerCount`，15 站已按参考的 `followers` 来源填充（含 kilakila `statisticInfo.followerNumber`、missevan `attention_count`），无缺口；房间链接 34 站都有 `RoomLinks.webUrl`。sixroom 补 6 条测试（108 飞屏=1000 六币醒目留言、324 跟风飞屏=2000 六币且 id 前缀 `follow-fly:`、201 礼物含 `giftCoin`/连送键 `fid:tmp_id`/收礼人/图标升 https、飞屏购买商品不算礼物、库存礼物无价值）。**有意保留的差异**：库存礼物（`giftCoin` 0）目标记 `LiveGiftUnit.free`，参考仍记 `sixCoin` 但价值为空——目标更准确，不回退
- [x] L33 showroom 礼物表回归测试：付费礼物按表内 `point × n` 计价并用表内名字/图片，免费礼物凭表内 `free` 或事件 `gt` 2 判为免费（无价值），无表时只留 id/图片/赠送价未知；`live/gift_list` 的 `normal`+`enquete` 按正整数 `gift_id` 合并、0 号行跳过。补 5 条测试
- [x] L34 测试覆盖扩到 6 站（26 条）：bigo（760969 礼物/送礼行/两种观众数）、kugoulive（601 礼物：星币计价、连送键、收礼人、免费单位、无连送 id 仍有次数）、missevan（礼物钻石计价/免费/无名，付费提问=钻石醒目留言一分钟）、chzzk（文本/盲屏、치즈 打赏按档位时长与匿名、订阅通知+同文聊天）、kick（Kicks 无附言为礼物、有附言为醒目留言、`pinned_time` 覆盖时长且上限一天）、douyin（`expire`/`wsTime+keeptime`/十六进制、短寿命按四分之一续期、持有 URL 的 `leaseOf` 返回过去租约）
- [x] L35 测试覆盖再扩 3 站（20 条）：picarto（Kudos 打赏按 `x` 计价并附一分钟、多路直播收礼人前缀、0/字符串 chips 拒绝、社区赠送/订阅等级文案）、kilakila（220 礼物单发/连送/送礼行 10004 计价、免费 0 红钻、别房帧拒绝）、yy（FLV `t` 租约：10 分钟提前 1 分钟续、短寿命按四分之一、m3u8/无 `t`/`t<1e9` 无租约、过期仅 `allowExpired` 返回过去租约；流管理器画质去重/同名加档位/按码率降序、线路 `//` 升 https/去重/`line_seq` 标签/租约、`otherLines`、`withLines` 只并同档；移动 HLS 的 JSONP 解析/拒绝、按流去重取高码率、线路几何与媒体头）
- [x] L36 测试覆盖补完剩余 13 站（166 条），34/34 站均有站点级回归测试：acfun（protobuf 礼物/香蕉/评论/观众数/gzip/失效票据、AES 密钥与帧）、soop（STT 包分帧、聊天/별풍선·애드벌룬·영상풍선/订阅与月数、握手头大小写）、twitcasting（socket URL 校验、签名脱敏、`gift=1`、评论与礼物+附言）、kuaishou（双层 JSON、轮询周期钳制、评论哈希 id、表情表、NG 无关的退避）、steambroadcast（getchatinfo 模板、窗口 `next_request`、聊天钟 nudge/resync、等待阶梯）、jdlive（liveauth 解密体/掩码帧、观众双指标、主播名、结束标记）、fc2live（清洗 HTML、FC2 id 偏移解码、NG 关键词/管理员/共享列表/发送者与移除、观众分半相加）、tiktok（房间卡与限制、画质 H.264 优先/跨档排序、FLV/HLS 线路与几何、14 天租约）、xiaohongshu（页面 hydration、公开/付费/私密/地区/未知访问、pullConfig 地址规则、线路 codec/格式排序）、cc（档位去重/映射/未确认、CDN 线与 `auth_key` 租约、未覆盖 CDN、410）、inke（详情/离线、app 广播与合卡、FLV/原画画质、Wangsu/Zego 地址规则）、liveme（媒体字段扁平化与 https 升级、原画/流畅、线路标签、私有/付费标记）、douyu（STT 转义与分帧、聊天等级/粉丝牌/颜色、两类醒目留言、礼物目录计价/背包免费、`rss` 结束、码率/CDN 排序、`expire` 与强制续期租约）
- [x] L37 斗鱼弹幕的用户等级/粉丝牌/牌子等级贯通：live_sites 的 `DouyuStt` 早已从 `chatmsg`/`dgb` 读出 `level`、`bnn`、`bl` 并放进 `MessageSender`（`userLevel`、`fanBadgeName`、`fanBadgeLevel`），但应用层 `RoomController.accept` 构造 `DanmakuMessage` 时只带了名字与颜色，三者在进管线时丢失、聊天列表又经 `_ChatMirrorSink` 读回空格。现补齐 `userId/userLevel/fansLevel/fansName/sentAt/isLocal` 的转发，聊天行在名字前显示粉丝牌（牌名+牌级）与 `Lv.N`（随「显示昵称」开关，系统行不显示）。对照参考 `legacy/lib/core/danmaku/douyu_danmaku.dart` 的字段来源（`level`、`bl`、`bnn`）确认一致；参考只在 `if == 1` 时显示聊天，目标是「可疑机器人可选过滤」，保留不回退

### P2 待证据

- [ ] L15 `LiveSuggestCapability` / `LiveHotProvider`：先找站点 API 证据
- [ ] L16 `LiveDanmakuSending`：先找发文协议证据
- [ ] L17 douyin 礼物、fc2 打赏、yy 礼物：按参考 V03.5 的受阻项，先录样本/登录态验证
- [ ] L18 运行期验证：真实 cookie 下逐家登录校验、真实房间的线路与租约

---

## 6. 进度记录

| 日期 | 项目 | 结果 |
|---|---|---|
| 2026-10-27 | 全量盘点 | 34 站能力/弹幕/线路/登录矩阵完成；确认 P0 清单（见上） |
| 2026-10-27 | L1–L9 | bilibili 醒目留言/状态/刷新、huya 刷新/状态/租约、douyu/acfun/chzzk/kick/kilakila/kuaishou/douyin 刷新+状态接入；`dart analyze` 0 issues；`dart test` 187 通过 |
| 2026-10-27 | L10 | 其余 25 站 `LiveRoomRefresh` + `LiveStatusCheck` 全部接入（34/34）；按参考做轻读缝：showroom 不读 stream rows、sixroom `summary`、kugoulive 只读 info、pandalive 只读 member、picarto `stream:false`、tiktok 不取 media、twitcasting 只读 streamserver、yy `refreshRoom`、liveme/jdlive/looklive/steambroadcast `media:false`、bigo 复用 token；`dart analyze` 0 issues；`dart test` 187 通过 |
| 2026-10-27 | L11b | huya、douyin、douyu 接入 `LivePlayRecovery`（委托无缓存的 `getLines`）；其余 7 站因缓存需先加 `fresh` 缝，记 L11a |
| 2026-10-27 | 顺带修复 | douyin/kuaishou/twitch/yy 四个站点 barrel 漏导出 `*_auth_provider.dart`（`export_surface_test` 长期失败的根因；该测试须在 `packages/live_sites` 目录内运行，在仓库根运行会因相对路径全部失败） |
| 2026-10-27 | L11a | 7 站补齐 `LivePlayRecovery`（10/10）：picarto/soop/twitcasting/xiaohongshu 的 `_stream`/`_broadcast` 加 `fresh`；kick/twitch 的 `_lines`/`_resolve` 加 `force`；kuaishou 的 `getLines` 本就每次重读；各 playback provider 增加 `refetchLines`，新增 `*_play_recovery.dart` 并接线 |
| 2026-10-27 | L12 | 5 站接入 `LivePlayLeaseLookup`（6/34）：解析器 `lease()` 增加 `allowExpired`，已过期返回过去的租约；新增 `*_play_lease_lookup.dart` 并接线。`dart analyze` 0 issues；`dart test` 187 通过 |
| 2026-10-27 | L13 | bilibili 接入 `LivePlaybackPlanResolver`：`resolvedLines` 返回实际 `current_qn`，轮播计划带 `play_time` 偏移；`dart analyze` 0 issues；`dart test` 187 通过 |
| 2026-10-27 | L14 | 复核 12 个无租约站，参考注释逐站确认地址无签名/无过期，维持无 lease；流类型/线路矩阵无缺口 |
| 2026-10-27 | L19 | `LivePlaybackPlanResolver` 扩到 5 站：cc/douyin/yy/twitch 接入（各自解析器暴露实际档位，降级/回退标 `qualityUnconfirmed`）；`dart analyze` 0 issues；`dart test` 187 通过 |
| 2026-10-27 | L20 | `LivePlayLeaseLookup` 扩到 12 站：kilakila、kugoulive、missevan、tiktok、youtube、yy 接入（绝对过期时间反查，已过期返回过去租约）；修正 jdlive/liveme/looklive 的 lease 标记与分区计数；`dart analyze` 0 issues；`dart test` 187 通过 |
| 2026-10-27 | L21 | 线路几何信息覆盖 2 → 8 站：niconico/pandalive/picarto/steambroadcast/youtube/yy（移动 HLS）写入宽高、帧率、码率；`dart analyze` 0 issues；`dart test` 187 通过 |
| 2026-10-27 | L22 | 线路几何信息覆盖 8 → 12 站：chzzk、sixroom、tiktok、twitch 接入（变体/流字段 → `PlayGeometry`）；`dart analyze` 0 issues；`dart test` 187 通过 |
| 2026-10-27 | L23 | douyin 接入 `LivePlayLeaseLookup`（13/34）；niconico 补 codec/帧率；baidulive 补 height 几何（13 站）；`dart analyze` 0 issues；`dart test` 187 通过 |
| 2026-10-27 | L24 | YouTube 补送会员两种通知（购买 `subscription`、收到 `giftedSubscription`）；`dart analyze` 0 issues；`dart test` 187 通过 |
| 2026-10-28 | L25 | 新增 `LiveCookieRefusalFeed` 并接 twitch（播放令牌被拒后匿名回退，同一 cookie 只报一次）；补 twitch 测试 2 条；`dart analyze` 0 issues；`dart test` 189 通过 |
| 2026-10-28 | L26 | 弹幕字段审计收尾：Bigo `ticket_num`、Missevan `lucky`、seventeenlive `combo.validDurationMs` 为参考子类检查字段，目标不扩公共模型，维持现状 |
| 2026-10-28 | L27 | 全量复核（§7）：醒目留言 13 处/11 站、通知种类与 raid、emote/badge、礼物表、事实表、端点计数均与参考一致；参考独有接口逐项判定不适用/已等价 |
| 2026-10-28 | L28 | 修正三处事实/注释：`superChat` payload 说明、`LiveSuperChatFeed` 看板平台（去 douyu）、`caseInsensitiveRoomIds` 补 TikTok/PandaTV；`dart analyze` 0 issues；`dart test` 189 通过 |
| 2026-10-28 | L29 | 按参考向量补回归测试 14 条：huya 租约与 uid 旋转、`SiteFacts` 五张表、礼物档位阈值；`dart analyze` 0 issues；`dart test` 203 通过 |
| 2026-10-28 | L30 | 再补 9 条：bilibili 线路排序/去重/租约/访客降档、pandalive 心与附言、looklive 礼物 102；`dart analyze` 0 issues；`dart test` 212 通过 |
| 2026-10-28 | L31 | 房间元数据复核：niconico 补说明（未开播/限制原因/节目收藏范围），youtube 补频道简介与在线人数说明；心跳间隔 24 站逐站一致；补测试 7 条；`dart analyze` 0 issues；`dart test` 219 通过 |
| 2026-10-28 | L32 | 关注数（`LiveAnchor.followerCount`）15 站与参考同源、34 站都有房间链接；sixroom 补 6 条礼物/飞屏测试；`dart analyze` 0 issues；`dart test` 225 通过 |
| 2026-10-28 | L33 | showroom 补 5 条礼物/礼物表测试（表内计价、免费判定、无表兜底、`gift_list` 合并）；`dart analyze` 0 issues；`dart test` 230 通过 |
| 2026-10-28 | L34 | 测试覆盖扩到 6 站（bigo/kugoulive/missevan/chzzk/kick/douyin）共 26 条；`dart analyze` 0 issues；`dart test` 256 通过 |
| 2026-10-28 | L35 | 测试覆盖再扩 3 站（picarto/kilakila/yy）共 20 条；`dart analyze` 0 issues；`dart test` 276 通过 |
| 2026-10-28 | L36 | 测试覆盖补完剩余 13 站共 166 条，34/34 站均有站点级回归测试；`dart analyze` 0 issues；`dart test` 442 通过 |
| 2026-10-28 | L37 | 应用层贯通斗鱼弹幕的用户等级/粉丝牌/牌子等级：`RoomController.accept` 补齐转发，聊天行显示牌名+牌级与 `Lv.N`（对照 legacy 的 `level`/`bnn`/`bl`）；`dart analyze`（改动文件）0 issues |

### 本轮改动的文件

**第一批（9 站）**

- bilibili：新增 `capabilities/bilibili_super_chat_feed_provider.dart`、`bilibili_status_check.dart`、`bilibili_room_refresh.dart`；`bilibili_room_provider.dart` 拆出 `refresh()`/`_read()`；`bilibili_site.dart`、`bilibili.dart` 接线与导出。
- huya：新增 `capabilities/huya_room_refresh.dart`、`huya_status_check.dart`、`huya_play_lease_lookup.dart`；`huya_site.dart`、`huya.dart` 接线与导出。
- douyu / acfun：各新增 `*_room_refresh.dart`、`*_status_check.dart`，站点类与 barrel 接线。
- chzzk / kick / kilakila / kuaishou / douyin：各新增 `*_room_refresh.dart`、`*_status_check.dart`，站点类与 barrel 接线。

**第二批（L10 + L11b）**

- 其余 25 站各新增 `capabilities/<id>_room_refresh.dart`、`capabilities/<id>_status_check.dart`，站点类接线（字段、实例、`capability<T>()` 分支）与 barrel 导出。
- 站点级轻读缝：`showroom_site.refreshRoom`、`inke_site.refreshRoom`、`kugoulive_site.refreshRoom`、`pandalive_site.refreshRoom`、`tiktok_site.refreshRoom`、`twitcasting_site.refreshRoom`（sparse room：只带状态/板块）。
- huya / douyin / douyu：新增 `capabilities/*_play_recovery.dart` 并接线 `LivePlayRecovery`。
- 文档：本文件。

**第三批（L11a + L12）**

- `picarto_site`、`soop_site`、`twitcasting_site`、`xiaohongshu_site`：流读取增加 `fresh` 参数；对应 playback provider 增加 `refetchLines`。
- `kick/kuaishou/twitch` playback provider：kick/twitch 内部读取增加 `force` 以绕过缓存；kuaishou 直接委托。
- 7 站新增 `capabilities/<id>_play_recovery.dart`，站点类与 barrel 接线。
- bilibili/acfun/cc/kuaishou/inke：解析器 `lease()` 增加 `allowExpired`；新增 `capabilities/<id>_play_lease_lookup.dart`（注入时钟），站点类与 barrel 接线。
- bilibili：`bilibili_play_parser.dart` 拆出 `resolvedLines`（附带实际 `current_qn`）与 `qualityOf`；`bilibili_playback_provider.dart` 同时实现 `LivePlaybackPlanResolver`，轮播计划带起始偏移；站点类新增分支。

**第四批（L19）**

- cc：`cc_room_parser.dart` 拆出 `resolutionWithApplied`（返回 `vbrname_sel`）与 `appliedQuality`；站点 `planOf` 返回线路/实际档位/是否确认，`CcPlaybackProvider` 实现 `LivePlaybackPlanResolver`。
- douyin：`douyin_play_parser.dart` 拆出 `resolvedLines`（返回实际 variant 的 `LivePlayQuality`）；`DouyinPlaybackProvider` 实现计划能力。
- yy：站点新增 `planOf` 与 `_flvPlan`（流管理器实际档位映射为回应里的质量；移动 HLS 如实报告请求档位；降级线路标未确认），`YyPlaybackProvider` 实现计划能力。
- twitch：provider 抽 `_plan`（按 id/VIDEO/标签匹配，匹配不到回退源流），`TwitchPlaybackProvider` 实现计划能力。

**第五批（L20）**

- 新增 `capabilities/<id>_play_lease_lookup.dart`：kilakila、kugoulive、missevan、tiktok、youtube、yy，站点类与 barrel 接线。
- 解析器：`kilakila_room_parser.dart` 的 `_lease` 公开为 `lease(..., allowExpired:)`；`kugoulive_room_parser.dart` 的 `_lease` 公开为 `lease(Uri)`；`missevan_room_parser.dart` 的 `lease(String)` 直接复用；`tiktok_room_parser.dart`、`youtube_play_parser.dart`、`yy_play_parser.dart` 的 `lease` 增加 `allowExpired`。

**第六批（L21）**

- `niconico_play_parser.dart`：线路写入声明的宽高与码率。
- `pandalive_room_parser.dart`：线路写入高度、帧率、码率。
- `picarto_room_parser.dart`：`PicartoQuality` 保留高度/帧率/码率，线路写入 `PlayGeometry`。
- `steambroadcast_room_parser.dart`：选中变体的宽高/帧率/码率写入线路。
- `youtube_play_parser.dart`：HLS 变体与渐进式 MP4 线路写入宽高/帧率/码率。
- `yy_play_parser.dart`：移动 HLS 线路写入宽高。

**第七批（L22）**

- `chzzk_play_parser.dart`：线路写入变体的高度/帧率/码率。
- `sixroom_room_parser.dart`：`resolution` 与 `bitrate` 写入线路。
- `tiktok_room_parser.dart`：`resolution`（`WxH` 或 `<height>p`）与 `vbitrate` 写入线路。
- `twitch_play_parser.dart`：`TwitchVariantGroup` 保留高度/帧率/码率，线路写入 `PlayGeometry`。

**第八批（L23）**

- 新增 `douyin/capabilities/douyin_play_lease_lookup.dart`，站点类与 barrel 接线；`douyin_play_parser.dart` 拆出无签发时间的绝对过期解析（`leaseOf`）。
- `niconico_play_parser.dart`：变体保留 `CODECS` 与帧率，质量与线路写入 codec/帧率。
- `baidulive_room_parser.dart` / `baidulive_play_parser.dart`：变体保留 height，线路写入高度几何。

**第九批（L24）**

- `youtube_danmaku_codec.dart`：新增 `_sponsorshipGift`，解析送会员（购买/收到）两种 renderer 并上报通知。

**第十批（L25 + L26）**

- 新增 `capabilities/live_cookie_refusal_feed.dart`（`Stream<void> get cookieRefusals`）并导出。
- twitch：新增 `capabilities/twitch_cookie_refusal_feed.dart`；`twitch_site.dart` 加广播 `StreamController`、`cookieRefusals`、`_refused()`（记录 + 广播），`dispose()` 关闭流，`capability<T>()` 接线；barrel 导出。
- 新增 `test/platforms/twitch/twitch_test.dart`（假 `LiveHttp`：401 → 事件 + 匿名令牌；接受 → 无事件）。

**第十一批（L27 + L28）**

- `models/enums/live_message_type.dart`：`superChat` 的 payload 说明改为 `LiveSuperChatMessage`，并写明 bilibili/huya 另有看板。
- `capabilities/live_super_chat_feed.dart`：看板平台由 (bilibili、douyu、huya) 改为 (bilibili、huya)。
- `core/site_facts.dart`：`caseInsensitiveRoomIds` 补 TikTok、PandaTV 及对应注释。
- 文档：新增 §7 全量复核记录。

**第十二批（L29）**

- 新增 `test/platforms/huya/huya_test.dart`：参考 `rotateUid` 向量（1400123456789→1399563556349 等）与 `lease` 六种边界（web 签名、native FLV、静态令牌、令牌窗口、已过期、无界）。
- 新增 `test/core/site_facts_test.dart`：`voiceLive`、`caseInsensitiveRoomIds`（10 站）、`retired`/`retiredHosts`、`superChatPlatforms` 与单位。
- 新增 `test/models/gift_tier_test.dart`：参考阈值 10/100 元、各币种汇率、免费/不可评级单位。

**第十三批（L30）**

- 新增 `test/platforms/bilibili/bilibili_test.dart`：线路候选排序与去重、`expires` 租约、画质取 `accept_qn`/`current_qn` 并按档降序、访客请求原画实得超清、未知容器无线路、缺 `playurl` 抛 api-changed。
- 新增 `test/platforms/pandalive/pandalive_test.dart`：`SponCoin` 心为 `tip`（하트 计价）、附言转聊天、엑셀방송 收礼人、非 `SponCoin`/0 心/无名/坏 JSON 不出消息。
- 新增 `test/platforms/looklive/looklive_test.dart`：礼物 102（音符计价、图标升 https、收礼人、id/时间/发送者）与非法帧的拒绝。

**第十四批（L31）**

- `niconico_room_parser.dart`：新增 `noticeText`（参考 zh.json 的五段文案）与 `notice(NiconicoWatch)`（未开播 / 开播但匿名不可看的原因 / 节目收藏范围），`room()` 写入 `RoomContent.notice`。
- `youtube_room_parser.dart`：`room()` 写入 `shortDescription` 作为说明，新增 `chatNotice` 常驻说明（只在有并发字段时显示在线人数）。
- 新增 `test/platforms/niconico/niconico_test.dart`（5 条）与 `test/platforms/youtube/youtube_test.dart`（2 条）。

**第十五批（L32）**

- 新增 `test/platforms/sixroom/sixroom_test.dart`（6 条）：108 飞屏、324 跟风飞屏、201 礼物的价值/连送键/收礼人/图标，以及飞屏购买与库存礼物的边界。

**第十六批（L33）**

- 新增 `test/platforms/showroom/showroom_test.dart`（5 条）：`t` 2 付费/免费礼物、无礼物表的兜底、非礼物事件、`live/gift_list` 的 `normal`+`enquete` 合并。

**第十七批（L34）**

- 新增 `test/platforms/bigo/bigo_test.dart`（4 条）、`test/platforms/kugoulive/kugoulive_test.dart`（3 条）、`test/platforms/missevan/missevan_test.dart`（4 条）、`test/platforms/chzzk/chzzk_test.dart`（6 条）、`test/platforms/kick/kick_test.dart`（4 条）、`test/platforms/douyin/douyin_test.dart`（5 条）。

**第十八批（L35）**

- 新增 `test/platforms/picarto/picarto_test.dart`（4 条）、`test/platforms/kilakila/kilakila_test.dart`（4 条）、`test/platforms/yy/yy_test.dart`（12 条）。

**第十九批（L36）**

- 新增 `test/platforms/acfun/acfun_test.dart`（12 条）、`soop/soop_test.dart`（15 条）、`twitcasting/twitcasting_test.dart`（13 条）、`kuaishou/kuaishou_test.dart`（11 条）、`steambroadcast/steambroadcast_test.dart`（15 条）、`jdlive/jdlive_test.dart`（13 条）、`fc2live/fc2live_test.dart`（14 条）、`tiktok/tiktok_test.dart`（14 条）、`xiaohongshu/xiaohongshu_test.dart`（10 条）、`cc/cc_test.dart`（10 条）、`inke/inke_test.dart`（11 条）、`liveme/liveme_test.dart`（10 条）、`douyu/douyu_test.dart`（18 条）。

> 每次改动后运行：`dart analyze packages/live_sites`（必须 0 issues）；测试在 `packages/live_sites` 目录内运行 `dart test`。
---

## 7. 全量复核（2026-10-28）

参考站点源码最后一笔提交在 2026-10-09（D07.7），之后 `live_core/lib/src/sites` 与 `live_danmaku/lib/src/sites` 没有任何改动，所以本轮以该快照做机械比对（`grep` 集合、模型字段、端点字面量），结论如下。

### 7.1 逐项核对一致（两边集合完全相同）

- 醒目留言生产者：参考 `LiveMessageType.superChat` 13 处 / 11 站（bilibili、chzzk、douyu、huya、kick、kilakila、missevan、picarto、seventeenlive、sixroom×2、youtube×2），目标同样 13 处 / 11 站。
- 通知种类：`LiveNoticeKind` 四个值一致；`raid` 生产者两边同为 kick、picarto、twitch。
- 消息类型枚举：目标 12 值包含参考全部 6 值（多 enter/leave/follow/like/membershipJoin/system）。
- emotes：bilibili、chzzk、kuaishou、youtube 两边一致；badges：seventeenlive 两边一致；`LiveMessageStyle` 两边站点都不上报（不是缺口）。
- 礼物价值档位：目标 `models/gift/gift_tier.dart` 含参考全部汇率并多 `rmb`/`gold`，另有 `giftShownTier` 处理免费单位。
- 礼物表/礼物补全：acfun、bilibili、douyu、showroom 都在会话内后台拉取礼物表；kugoulive 601 的 `ack`（211）与重复抑制、looklive 102（音符）、pandalive 心（하트/SponCoin + 附言）、soop 星气球、showroom `t` 2、twitcasting `gift=1`、kick `channel_` 订阅、twitch 社区礼 2 秒配对均与参考同构。
- 事实表：`voiceLive`、`retired`、`retiredHosts` 与参考完全一致。
- API 端点字面量逐站计数：34 站中目标均不少于参考（没有遗漏端点）。
- 线路 codec 覆盖率逐站计数：目标不落后于参考；bilibili / twitch 的字面量次数差异只是「把 codec 存进变体记录再写入线路」与「构造时直接写命名参数」的写法不同，两边的线路都带 codec。

### 7.2 本轮修正（已存在能力的正确性）

1. `LiveMessageType.superChat` 注释原写「payload 恒为 null，醒目留言只走列表接口」，与 13 处弹幕上报（payload 为 `LiveSuperChatMessage`）矛盾 → 改正，并说明 bilibili/huya 另有看板。
2. `LiveSuperChatFeed` 注释把 douyu 列为有看板的平台，但参考与目标都只有 bilibili、huya 实现 `getSuperChatMessage` → 改为两家。
3. `SiteFacts.caseInsensitiveRoomIds` 漏了参考已列的 TikTok、PandaTV → 补上并补注释（目标 App 目前没有消费方，属事实表纠偏，无行为风险）。

### 7.3 参考独有但判定「不适用 / 已等价」的接口

- `LiveSiteRecordRoomResolver`：参考 App 只在多视图录制入口消费；目标 App 未消费，且目标 `getRoom` 本身用 `Either` 严格返回错误，不存在参考「宽松详情」的前提 → 不新增。
- `LiveCancellableSearch` / `LiveQualityDiscovery`：目标 App 搜索以世代号丢弃过期结果、画质读取不持有可取消的临时会话 → 不新增接口。
- `LiveSiteDirectoryPager` / `LiveSiteCategoryDirectoryProvider`（仅 cc）：目标 App 用 `areaRequestSize` + `RoomWalk` 本地分页，offset 由站点请求窗口决定，与参考固定 30 的效果一致。
- `CatchUp`（IPTV 追时移）与 `epgId/currentProgramme*`：参考只有 IPTV 路径构造 `CatchUp`，34 个直播站点没有一个写入 epg 字段 → `live_sites` 无需建模。
- `LiveDirectoryNotice`：展示层常驻文案，目标未消费 → 不加。
