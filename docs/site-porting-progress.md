# live_sites 逐站迁移进度台账

> 权威进度文档。每完成一个站点回来更新此表并勾选 DoD。动手前先读这里,不要另起炉灶。
> 参考实现源:`E:\study\pure_live`(镜像 `D:\flutter\_ref_pure_live`)——每站 = `packages/live_core/lib/src/sites/<site>/`(房间/分区/搜索/推荐/播放/登录)+ `packages/live_danmaku/lib/src/sites/<site>.dart`(弹幕协议)。
> 现行基线:模型/契约以本仓库 `packages/live_sites` 的 **v2** 为准(core + capabilities + models 按关注点分组),不要回到任何旧写法。

## 交付门(每站完成标准 DoD)
1. 覆盖参考站点的**全部能力**:凡参考实现了的,就实现对应 provider——`LiveRoomProvider` / `LiveAreaProvider` / `LiveDiscoveryProvider` / `LiveSearchProvider` / `LivePlaybackProvider` / `LiveDanmakuProvider` / `LiveLinkResolver` / `LiveHotProvider` 等(参考没有的能力不硬造;有但不支持的按契约返回 `left(unsupported)`)。
2. 结果一律走 `Either<LiveSiteError, T>`;错误经站点 `Failure → toLiveSiteError` 映射,不裸抛过边界(会话内重连等生命周期除外,依 `LiveDanmakuProvider` 文档)。
3. 弹幕:协议编解码 + 心跳/保活 + **断线重连护栏**(双开互斥 + 失败上限后终止并上报)+ 礼物/会员牌等**在目录内的定价**,与参考逐字段对齐。
4. 解析忠实:字段用共享模型(LiveRoom/LiveAnchor/LiveArea/LiveMessage/LiveGift/LivePlayLine…),数字即字符串要容错,缺键不崩。
5. 离线纯逻辑测试:`test/platforms/<site>/` 覆盖编解码/解析/定价等无需网络的路径。
6. `cd packages/live_sites && dart format <改动> && dart analyze`(整包 **No issues found**)+ `dart test` 全绿。
7. 按 pathspec 提交(`git add` 仅限本站文件 + 本台账),`git push`。

## 方法(每站复用)
派一个只读子代理对参考↔现状做**逐条功能对照**,产出 PRESENT/PARTIAL/MISSING/N-A 清单 + 已疑缺陷确认;据此实现,再补离线测试,过门后提交推送并回填本表。性能型内部项(并发去重、缓存 LRU/退避、isolate 卸载)不计入"功能",可延后,但要在下方"延后项"记录。

## 站点队列与状态
图例:✅ 完成并推送 · 🟡 进行中 · ⬜ 未开始。参考站集合取自 `live_danmaku/lib/src/sites`(28 个含弹幕)+ 仅 `live_core` 有的站点(纯目录)。

| 站点 | 状态 | 备注 |
|---|---|---|
| douyu 斗鱼 | ✅ | 见下方"douyu 明细" |
| huya 虎牙 | ✅ | 见下方"huya 明细" |
| douyin 抖音 | ✅ | 见下方"douyin 明细" |
| bilibili B站 | ✅ | 见下方"bilibili 明细" |
| kuaishou 快手 | ✅ | 见下方"kuaishou 明细" |
| youtube | ✅ | 见下方"youtube 明细" |
| twitch | ✅ | 见下方"twitch 明细" |
| iptv | ✅(seam) | 基线既有,跨包 seam,非典型直播站 |
| weibo 微博 | ⬜ | 快照门控站(无 cursor 分页) |
| acfun / bigo / chzzk / fc2live / jdlive / kick / kilakila / kugoulive / looklive / missevan / niconico / pandalive / picarto / seventeenlive / showroom / sixroom / soop / steambroadcast / twitcasting / yy | ⬜ | 其余含弹幕站;**下一站候选 acfun**(按本行顺序) |
| cc / inke / liveme / tiktok / xiaohongshu | ⬜ | 仅 `live_core` 有(纯目录/播放,无弹幕) |

## douyu 明细(2026-10-14)
本轮把远程基线里"名不副实"的 douyu 参考适配器补成真正可用:
- **礼物目录定价管道接通**:此前 `giftCatalog()/props()` 无人调用、`giftsFor: cachedGifts` 读空缓存 → 弹幕 `dgb` 礼物恒不定价/无图标。现 `DouyuDanmakuProvider` 持有 `site`,`createSession` 用 `site.cachedGifts` 起会话,连上后异步 `site.giftCatalog(roomId) → session.addGifts(...)`(契合 `LiveDanmakuProvider` 文档"刷新经具体会话 update 方法流入活跃会话")。离线测试直接验证 `dgb` 按目录定价/免费/背包/未知礼物四类路径。
- **新增 `LiveLinkResolver`**:`capabilities/douyu_link_resolver.dart`,把 rid/靓号/别名/`/room/share/<n>` 解析为规范 `https://www.douyu.com/<rid>`,复用 `site.ridFor`(带 rid 缓存),已在 `capability<T>()` 注册。
- **弹幕重连护栏**:双开互斥 `_reconnecting`(watchdog 与 onDone 不再同时重连)+ 连续失败上限 `maxReconnectAttempts=6` 后在 `events` 发系统消息并关闭(不再静默死循环);收到帧即清零计数。
- **搜索违约修正**:`supportedTargets` 判定移到空查询之前,不支持的目标无论关键词都返回 `left(unsupported)`。
- 清理:去掉 douyu 各文件里重复的文档注释/叠加 `@override` 合并残渣,及会话 provider 的三重文档。
- **延后项(性能/边角,不影响功能门)**:`descriptorFor` 同 did 并发去重;礼物缓存的失败退避 + LRU 逐出 + 大表 isolate 卸载;`DouyuGiftInfo.effect`(gift_effect,新模型无落点);passport `set-cookie` 多属性串的续期 cookie 合并边界。
- 验证:`dart analyze` 整包 No issues found;`dart test` 15 项全绿(新增 `test/platforms/douyu/douyu_test.dart`)。

## huya 明细(2026-10-14)
整站从 `E:\study\pure_live` 的 `live_core/sites/huya` + `live_danmaku/sites/huya.dart` 迁到 `platforms/huya/`,照 douyu 的文件形态:
- 能力:room / area / discovery(推荐 allpage) / search(v4 房间+v1 主播) / playback / danmaku / link_resolver,均在 `capability<T>()` 注册。错误经 `HuyaFailure → toLiveSiteError('huya')`,数据面一律 `Either`。
- 播放签名:`signAntiCode` = MD5 模板法(fm base64→`$0..$3`;wsTime hex;seqid=uid+ms;hash=md5("seqid|ctype|t");rotated=低32位循环左移8;wsSecret=md5(填充模板);输出剥离 fm/回填 wsSecret,u=rotated,ver/fs/t/seqid)。线路/清晰度直接取 profileRoom 的 `stream.flv/hls.multiLine` + `bitRateInfo`/`rateArray`(0=原画),含 lease/短传输/媒体头/FLV→https。**延后**:`getCdnTokenInfoEx` 的 WUP token 刷新、消息板(超播 uri 2001314)、回放 deflist。
- 弹幕:`wss://wsapi.huya.com`,**Tars 非 protobuf**(自写 `huya_tars.dart` 最小编解码,裸 Tars 帧无长度前缀)。cmd16 register(live:/chat: 组)、cmd20 心跳(60s,静默180s换),server cmd7 单推 / cmd22 批量;uri 1400 聊天 / 8006 热度 / 6501 礼物(价直接从包 iPayTotal 来,无外部目录)/ 8001 关播。重连沿用 douyu 的双开互斥 + 连续失败上限终止上报。
- 链接:数字 rid 直连;别名页 `TT_ROOM_DATA` 解析;`HuyaRoomParser.isNumericId/roomIdAt/aliasAt/roomIdFromPage`。
- 验证:`dart analyze` 整包 No issues found;`dart test` 全绿(huya 15 项:Tars 往返、chat/gift/online/end/batch 解码、独立复算 md5 命中的签名、链接解析)。

## douyin 明细(2026-10-14)
整站从 `live_core/sites/douyin`(api/sign/site)+ `live_danmaku/sites/douyin.dart` + `live_danmaku/codec/protobuf.dart` 迁到 `platforms/douyin/`。**无新依赖**:protobuf 与两套签名全纯 Dart 手写。
- 能力:room / area(首页 RSC categoryData) / discovery(feed) / search(live/search + general/search/stream) / playback / danmaku / link_resolver,全在 `capability<T>()` 注册;`Either` + `DouyinFailure` 映射。访客 bootstrap 取 `ttwid`+`UIFID_TEMP`,msToken 本地生成。
- 签名(最高风险,已用金标向量锁定):`a_bogus`(SM3 双重哈希 + RC4 + `_table` 流变换 + `_alphabet0` base64)与 `X-Bogus`(MD5 定长 stub + RC4 + `_xBogusAlphabet`,值需百分号编码);`douyin_sign.dart` 逐字转写 SM3/RC4/base64 表与大数组 `_table`/`_order`/`_checkOrder`。
- protobuf 弹幕:`douyin_protobuf.dart` 手写 varint/tagged 编解码;WS 每条二进制即一个 PushFrame,payload 按 `gzip`/`1F8B` 解压;Response→envelope.method 派发 WebcastChatMessage(按 common.roomId 过滤)+ WebcastRoomUserSeqMessage(在线数),needAck 回 ack,心跳 `hb` 10s、静默 45s 换、重连双开互斥+上限。礼物/表情/场控参考即无 → 本站不做。
- 播放:web 无 app 式 PlayAddrList 签名,URL 来自 `room.stream_url`(sdk pull_data + legacy flv/hls,按 sdk_key 大小写无关拼接);tier 排序、丢音频轨、FLV→HLS、媒体头、lease 从 URL `expire/volcTime/wsTime+keeptime/t(k)`。
- 验证:`dart analyze` 整包 No issues found;`dart test` 整包 73 项全绿(douyin 43,含 SM3 GB/T 官方向量、a_bogus/X-Bogus 参考金标向量、protobuf/播放/接线/链接/离线违约)。

## bilibili 明细(2026-10-14)
整站从 `live_core/sites/bilibili`(api/site/wbi/cookie)+ `live_danmaku/sites/bilibili.dart` + `codec/protobuf.dart` 迁到 `platforms/bilibili/`。**无新依赖**。
- 能力:room / area(分区树 getList) / discovery(getListByAreaID/getMoreRecList) / search(search_type=live|live_user) / playback(getRoomPlayInfo) / danmaku / link_resolver,注册齐;`Either` + `BilibiliFailure`。
- WBI 签名:`bilibili_wbi.dart` 逐字转写 64 项 `_mixinTable`,img_key/sub_key→mixinKey、query 排序+剥 `!'()*`+encode、`w_rid=md5(query+mixinKey)`;`-352` 续期重试一次。**测试用参考金标向量逐字节锁死**(`bar=514&foo=114&...&w_rid=8f6f2b5b3d485fe1886cec6a0be8c5d4`)。buvid3/4 走 `finger/spi`,`w_webid` 走 `/lol`。
- 弹幕:**JSON 广播协议**(非 DmMsgList)。`bilibili_danmaku_codec.dart` 16 字节大端帧头(version 0=JSON/2=zlib,op 2 心跳/3 心跳回/5 notice/7 auth/8 auth回),auth 键序 `uid,roomid,protover,buvid,support_ack,queue_uuid,scene,platform,type,key`;notice 按 `cmd` 派发 DANMU_MSG→chat / ONLINE_RANK_COUNT→在线 / SEND_GIFT→json 礼物 / SEND_GIFT_V2→`data.pb` base64 经手写 protobuf reader(`bilibili_protobuf.dart`,仅解 SendGiftV2 所需字段) / SUPER_CHAT→superChat / RECALL→撤回。重连双开互斥+上限同款。
- 播放:线路 = `playurl_info.playurl.stream[].format[].codec[].{base_url,url_info[].{host,extra}}` 拼 `host+base_url+extra`,清晰度取 accept_qn∪current_qn(qn 10000=源,guest 请求 10000 降 250),lease 取 extra 里 `expires=`;轮播 `getRoundPlayVideo`。
- **延后/取舍**:protover 用 **2(zlib)** 而非参考的 3 → 服务端不发 brotli,version-3 帧计数跳过并留 `TODO(bilibili-danmaku)`(本包无 brotli 解码器);super chat 无对应能力,改由 `BilibiliRoomProvider.superChats()` + 弹幕流上挂 `LiveMessageType.superChat`;礼物目录内联解析不上 isolate;QR 登录/表情徽章未接。
- 验证:整包 `dart analyze` No issues found;`dart test` **122 项全绿**(bilibili 49,含 WBI 金标、帧头字节串、auth 键序、notice/gift-pb 派发、room/search/play/gift 解析、链接解析)。

## kuaishou 明细(2026-10-14)
整站从 `live_core/sites/kuaishou` + `live_danmaku/sites/kuaishou.dart` 迁到 `platforms/kuaishou/`。**无新依赖:纯 REST JSON + HTML 轮询,无 protobuf / 无 WebSocket / 无 GraphQL / 无签名**。
- 能力:room / area(8 个硬编码顶级分类) / discovery(home/list) / search(search/author,仅主播) / playback / danmaku / link_resolver,注册齐;`Either` + `KuaishouFailure`。访客 session:裸取房间页存 `did/clientid/client_key/kpn/bfb1s` 30 分钟,`misc2` 上报 best-effort。
- 弹幕 = **HTTP 增量轮询** `livev.m.chenzhongtech.com/wap/live/feed`(回退 m.gifshow.com),双/三重 JSON 编码解包 + `data` 下钻;`currentWatchingCount`→在线(audienceUpdate),`liveStreamFeeds[type=comment]`→chat(sha1 of `time\u0000userId\u0000content` 兜底 id),`result!=1`→rejected。会话 `_tick` 轮询循环,退避 1/2/4/8s,连续失败上限发终止系统消息后关流(与 douyu/huya/douyin 同款互斥/上限)。礼物本协议无,不实现。
- 播放:playUrls 的 h264/hevc `adaptationSet.representation[]`(卡片用 descriptor 列表),按 (name,level/bitrate) 合线,codec 从文件名(`_Avc/_Hevc`),hls(.m3u8)/flv,hevc-only 加 ` · H.265` 后缀置末;lease 读 `txTime/wsTime/hwTime`(8 hex)、`ty_Time/bd-origin wsTime`(10 十进制)、`ali-origin auth_key`,刷新 min(10min,¼)。
- 解析:room 页 `window.__INITIAL_STATE__.liveroom.playList[0]`(isLiving/errorType22→NotFound);卡片 id=liveStreamId、author.id=roomId、`statrtTime` 容错(仅 1e12–1e13)。链接 `/u/{id}`。
- 验证:整包 `dart analyze` No issues found;`dart test` **136 项全绿**(kuaishou 14:feed 解包/仅 comment/backoff/query、txTime+auth_key lease、qualities/lines、mediaHeaders、roomIdOf、sessionCookies、roomDetail 端到端)。

## youtube 明细(2026-10-14)
整站从 `live_core/sites/youtube`(api/site)+ `live_danmaku/sites/youtube.dart` 迁到 `platforms/youtube/`。**无新依赖**:全 InnerTube JSON POST + 一处 watch 页 HTML 正则 + HLS master 解析,无 protobuf / 无 WS。
- 能力:room / discovery(browse Live 中心 UC4R8… 单页) / search(search,page1 body 带**硬编码字面量 params `EgJAAQ%3D%3D`**(Live 过滤,不做运行时 protobuf),翻页用 continuation token) / playback / danmaku / link_resolver。`capability<T>()` **不注册 LiveAreaProvider**(YouTube 无分区,参考即无)。WEB context clientVersion 2.20260925.01.00;player 用 ANDROID context 匿名拿 HLS;每请求带 `cookie: SOCS=CAI`。
- 弹幕 = `live_chat/get_live_chat` **HTTP 轮询**(kuaishou 会话形态:startAttempts 3、退避、maxFailures 8、终止消息、双开互斥)。首个 continuation 来自 `next` 的 liveChatRenderer,轮询周期 `timeoutMs` 夹到 [1s,5s];`isReplay` → 返回 left(不支持回放)。actions 解析:liveChatTextMessageRenderer→chat(含 runs/emoji)、liveChatPaidMessageRenderer→superChat、paid sticker / membership / giftMessageViewModel→礼物、removeChatItem/markDeleted→撤回。401/403/404 立即结束会话。
- 播放:playabilityStatus→错误;streamingData.hlsManifestUrl GET master,`#EXT-X-STREAM-INF`(≤64)→清晰度/线路(id `hls:<h>:<fps0>:<codec>`,解析不出→`hls:auto`),dash/progressive 兜底;host 白名单 googlevideo.com/youtube.com/youtube-nocookie.com、仅 https;lease 从 `?expire=`/`/expire/`,renew 提前 10min。链接:`^[\w-]{11}` video / `^UC[\w-]{22}` channel,watch/live/youtu.be/embed/channel/@handle→canonical 或 `navigation/resolve_url`。
- 延后(记档不假造):allChat continuation 的 protobuf 重写(跳过即无需 protobuf)、频道名 RSS 富化、会员徽章解码、superChat 之外的分级色。
- 验证:整包 `dart analyze` No issues found;`dart test` **149 项全绿**(youtube 13:room/直播态/首续页、chat+emoji/superChat/gift/撤回、轮询夹取、HLS master→清晰度/线路/lease、host 白名单拒绝、search 字面量 params+continuation、链接解析各形态)。douyin_test 的内置站点等值断言已随之更新为含 youtube。

## twitch 明细(2026-10-14)
整站从 `live_core/sites/twitch`(api/site)+ `live_danmaku/sites/twitch.dart` 迁到 `platforms/twitch/`。**无新依赖:GraphQL + usher HLS + IRC over WebSocket**。
- 能力:room / area(BrowsePage_AllDirectories 分类标签→目录)/ discovery(全站 `streams` 最热)/ search(SearchResultsPage 仅频道)/ playback / danmaku / link_resolver,注册齐;`Either` + `TwitchFailure`(needsLogin→authentication,regionBlocked/streamUnavailable→contentUnavailable,riskControl→rateLimit)。
- 请求:`POST gql.twitch.tv/gql`,`client-id: kimne78kx3ncx6brgo4mv6wki5h1ko` + 每适配器一个 32 位十六进制 `device-id`,`content-type: text/plain`;五个 persisted query sha256 与两条原始 query(`user`、`streams`)逐字照搬——`$languages` 必须是 `[Language!]`(2026-10 起 `[String!]` 直接报错)。`Accept-Language: zh-CN`,标签无名时一次英文名重试。
- 列表分页:目录一次取 100、最热取 30,快照(30 s 有效)本地切页,页起点越过末尾才跟 cursor;`pageInfo.hasNextPage`+末边 cursor。搜索游标走 `options.targets`(顶层 cursor 服务端忽略),按 `search|词|页` 存,LRU 256。integrity challenge(`extensions.challenge` / `failed integrity check`)在后续页**静默结束**列表。
- 播放:`PlaybackAccessToken`(带 cookie 时 `Authorization: OAuth <auth-token>`,被 401/风控拒绝则记住该 cookie 并转匿名)→ `usher.ttvnw.net/api/channel/hls/<login>.m3u8`(`acmb=e30=`、`allow_source`、`cdm=wv`、`play_session_id` 二选一、`player_version=1.28.0-rc.1`、`supported_codecs` 按“优先 H.264”/引擎能力)。master 解析按 `height:fps:bandwidth:VIDEO` 合线,`chunked`=源置首;变体 URL 比 20 分钟 token 长命 → **无 lease**;恢复按 id→VIDEO 组→label 重取。媒体头不带 cookie。
- 弹幕:`wss://irc-ws.chat.twitch.tv` 文本帧 IRC。握手四行各一帧(`PASS oauth:` / `PASS SCHMOOPIIE`、`NICK`/`justinfan<4-5>`、`CAP REQ`、`JOIN #<小写频道>`),无加入确认计时器。`PING`→`PONG`,客户端心跳 40 s、静默 120 s 换 socket;`RECONNECT` 静默换(10 s 内不连换,超过则走普通重连);`NOTICE *` → 丢弃登录、匿名重开并提示一次 Cookie 失效。双开互斥 + 连续失败上限 6 终止上报(与douyu/huya/douyin/bilibili 同款)。
- 消息面:`PRIVMSG`→chat(display-name/login 回退、`color` 十六进制、`tmi-sent-ts`、`id`;`/me` CTCP 去壳;tag 两套反转义:IRCv3 单遍与 3.x 顺序替换,与参考一致);`bits>0` 前置一条 Bits 打赏(`LiveGiftKind.tip`/`LiveGiftUnit.gold`,id `<id>:bits`);`CLEARMSG`/`CLEARCHAT`→撤回(有 target-user-id 撤人,无 trailing 撤全部);`USERNOTICE`→notice(sub/raid/system 分类)+ 观众原话成 chat,`announcement` 用 trailing 作文案,`sharedchatnotice` 认 `source-msg-id`;社区礼物(`submysterygift` 与 N 条 `subgift` 同一 `msg-param-community-gift-id`)只显公告:成员消息滞留 2 s 等公告,公告记忆 1 分钟/容量 64。
- 验证:整包 `dart analyze` No issues found;`dart test` **190 项全绿**(twitch 41:IRC 行切分/反转义、chat+cheer+撤回+订阅公告+社区礼物标记、master 分组与标签、usher 状态码、房间/搜索/目录解析与登录不符→apiChanged、gql 头与 usher 参数、链接解析、integrity 静默止页、能力接线与内置站清单)。
- **延后/取舍**:参考即无徽章/表情解析、无发送弹幕、无登录流程 → 本站不做;参考的 GraphQL 备用传输(`gqlFallbacks`,Android TLS/WebView 回退)属 app 注入的传输编排,未在本适配器复刻;`cookieRefusals` 事件流在 v2 契约无对应面,改为播放侧静默转匿名 + 弹幕内提示;目录树(参考 `LiveCategory` 两层)按 v2 扁平 `LiveArea`+`parentAreaId/Name` 表达;房间刷新未做 `updated_metadata` 观看数续报。
## 环境缺口(影响交付门,重要)
本机工作区 **无法 `dart pub get`**:`packages/live_playback` 依赖 `media_core` 路径 `../../../../media_core/packages/media_core`(即 `D:\media_core\packages\media_core`),该外部工作区在本机不存在,导致整个 workspace 解析失败、`dart test` 直接跑不起来(与本次站点代码无关)。为跑本包测试,曾临时在 `D:\media_core` 造桩再删。要长期跑测试门,需把真实 `media_core` 工作区放到 `D:\media_core`(或在 live_playback 里改成实际存在的路径/移除该 member)。在此之前,"交付门 = dart analyze + dart test" 中的 test 步骤依赖人工补 media_core。
