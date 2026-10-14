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
| acfun AcFun | ✅ | 见下方"acfun 明细" |
| bigo Bigo Live | ✅ | 见下方"bigo 明细" |
| chzzk CHZZK(치지직) | ✅ | 见下方"chzzk 明细" |
| iptv | ✅(seam) | 基线既有,跨包 seam,非典型直播站 |
| weibo 微博 | ⬜ | 快照门控站(无 cursor 分页) |
| fc2live / jdlive / kick / kilakila / kugoulive / looklive / missevan / niconico / pandalive / picarto / seventeenlive / showroom / sixroom / soop / steambroadcast / twitcasting / yy | ⬜ | 其余含弹幕站;**下一站候选 fc2live**(按本行顺序) |
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
## acfun 明细(2026-10-14)
整站从 `live_core/sites/acfun`(api/site)+ `live_danmaku/sites/acfun.dart` + `live_core/aes.dart` + `live_danmaku/codec/protobuf.dart` 迁到 `platforms/acfun/`。**无新依赖:AES-128 与 protobuf 全纯 Dart 手写**。
- 能力:room / area(channelList 的 filterType+filterId 树) / discovery(推荐页 + 目录 cursor 链) / search(`type=user` 作者索引,rooms 与 anchors 共用同一份页切分) / playback / danmaku / link_resolver,注册齐;`Either` + `AcfunFailure → toLiveSiteError('acfun')`。访客会话 = `sid=acfun.api.visitor` 表单登录存 `_did=web_+16` 与 `visitor_st`,startPlay/giftList 带 `kpn=ACFUN_APP&kpf=PC_WEB&subBiz=mainApp&userId=0&did=<访客>`。
- 弹幕 = **自定义二进制帧 + 双密钥 AES**:帧头 `magic 0xABCD / version / inLen / outLen`(`u16 u16 u32 u32`);**AES-128-CBC + PKCS#7**(与参考 `live_core/aes.dart` 同表同轮数),register 用 `acSecurity`(base64 → 16 字节),会话期用 register answer 的 `bytes(2)`;下行 IV = 载荷前 16 字节,上行随机 IV 前置。头 `appId1,uid2,instanceId3,decodedLen7,encMode8,tokenInfo9,seqId10,kpn12`、上行 `cmd1,seq2,retry3,data4,subBiz9`、下行 `cmd1,seq2,err3,data4,msg5` 与参考逐号对齐;RegisterRequest 的 appInfo/deviceInfo(platform=6, model=h5)/ztCommonInfo 字段号照搬。
- 派发:`ZtLiveScActionSignal` 按信号名分发 comment / `CommonActionSignalGift`(目录定价,消息 id `<sender>:<comboId>:<combo>`)/ `AcfunActionSignalThrowBanana`(平台免费币)/ `ZtLiveScStateSignal` displayInfo 观看数 / ticket 失效 `{2,3,4,7}` / `ZtLiveScStatusChanged {1,2,4}`;心跳定频、每第 5 个心跳附带保活 + ticket 轮换 + 刷新预算 3;重连双开互斥 + 连续失败上限终止上报(与 douyu/huya/douyin/bilibili/twitch 同款)。
- 播放:`/api/live/info?authorId` → `startPlay`(pullStreamType=FLV),清晰度/线路/lease 从播放答案;收费专场(380205)与未开播(129004)按契约返回 left。礼物目录缓存,取失败记空。
- 链接:`live.acfun.cn/live/{id}`、`m.acfun.cn/live/detail/{id}`、`www.acfun.cn/u/{id}`(含遗留 `.aspx`)、`m.acfun.cn/upPage/{id}`(参考在此**不**剥 `.aspx`,已照搬);作者号即房间号(≤20 位正数)。
- **延后/取舍**:参考搜索的并发分页(`_Search` + 8 s 超时 + CancelToken + 重启)在 v2 `searchRooms(keyword,{page,pageSize})` 形态下无对应面 → 用本地页切分,`data-total` 收尾语义保留;礼物信号的 `value`(字段 6)参考只"留着核对"、不驱动任何展示,v2 `LiveGift` 无落点 → 未读;`LiveGiftUnit` 无 banana 档,香蕉记 `free`,目录价为 0 的非香蕉礼物同样记 `free`(对齐参考 `free: banana || price == 0`)。
- 验证:整包 `dart analyze` No issues found;`dart test` **300 项全绿**(acfun 110:AES 金标与往返、protobuf 逐字段、帧封解、register/session 密钥换取、push 各类信号、访客与端点参数、目录 cursor、搜索切页 + anchors 目标、链接各形态)。douyin_test 的内置站点等值断言已随之更新为含 acfun。

## bigo 明细(2026-10-14)
整站从 `live_core/sites/bigo`(api/site)+ `live_danmaku/sites/bigo.dart` 迁到 `platforms/bigo/`。**新增共享件:AES 原语上移 `src/common/crypto/aes_cbc.dart`**(acfun 的私有副本删除,两处一起用;§3 规定 ≥2 平台的共享工具归 common,§7.4 不许 common 里出现平台名)。
- 能力:room / area(只有一个区:公开推荐 = `vedioList/72`)/ discovery(同一快照切片)/ search(仅 rooms)/ playback / danmaku / link_resolver,注册齐;`Either` + `BigoFailure → toLiveSiteError('bigo')`(needsLogin→authentication,受限/离线/无 hls→contentUnavailable,401/403→rateLimit)。
- **Web token 链**:`sec.bigo.sg/v1/webjs/t` 取服务器时间 → `webjs/status?data=<加密>` 换 token → `getInternalStudioInfo?siteId&verify=&token=`(POST 空体)。**只有 token 的首次使用**才回 `hls_src` 与 `passRoom`,后续使用回状态/名字/图但没有这两样。所以 entry / input 用新 token(3 请求),refresh 用 30 分钟内复用的 token(1 请求);`tokenReuse=30min` 是余量不是实测过期。**签名**:`data` = base64(`Salted__` + 8 字节 salt + AES-256-CBC(PKCS7)),密钥由 OpenSSL `EVP_BytesToKey`(md5,1 轮)从站点公开口令 `undefinedval0x01` 派生(前 32 密钥、后 16 IV);两个答案都是 JSONP,回调名 `jsonpcallback_<ms>_<µs>` 必须逐字对上。
- 解析按参考的**严格**口径:字段类型不对就是 apiChanged(`needLogin` 非 bool、`isPaidShow` 不在 {''、'0'、'1'}、`alive` 非 0/1、`hls_src` 非 https `.m3u8` 且出现在非公共/未开播房间…);列表里单行读不通就跳过该行(参考也是逐行跳),整批读不通才 apiChanged。**取舍**:参考的三条中文提示语(chat/login/restricted notice)不进模型——v2 用 `broadcast.restriction` + `audience.primaryMetric` 表达同一事实,措辞归应用层。
- 弹幕 = **WebSocket 文本帧 `<uri><JSON>`**(服务端帧间可带 tab):256 challenge → 79108 应答(`sign = md5("60#4#5#<秒时间>#1#1#1#1#<challenge 末 8 位>")`)→ 等 1s → 512279 登录(visitor 来自 `studio/getWebSocketLink` 表单 POST)→ 512535 `res=="200"` → 1304 进房 → 1560 `resCode=="200"`(`sid=="0"` = idle → 终止)→ 10776 拉观众;10264 `totalUserCount` / 11032 `total` = 在线数,2584 按 `payload.tag` 派发(1/2 = 聊天、6 = 礼物线报送礼者名),`oriUri=="760969"` = 礼物动画(目录价不查,`LiveGiftValue` 留 unknown 不造假 0;`comboTotal = vgift_count × send_times`,送礼者行等 1s 关联)。聊天正文是 **Base64 的 UTF-8 JSON `{n,m}`**;`messageId = <uid>:<seqId>`(参考记录过同 seqId 重发)。心跳 10s(登录后起)、静默 90s 换 socket、join 10s 超时、拒绝 4 次终止 + 双开互斥与连续失败上限同款。
- 播放:单清晰度 `直播自动`(id `live`);线路 = 首次使用 token 的 `hls_src`,`singleUse: true`(同一地址重开无效,播放器必须重新解析)、无 lease(URL 本身不带过期参数)、线路标签 = CDN host。
- 链接:`bigo.tv` 及任意子域、仅默认端口、无 userinfo、`/<id>` 或 `/<两字母语言>/<id>`、保留路径不算房间、忽略 fragment;作者号即房间号(`^[A-Za-z0-9_][A-Za-z0-9_.-]{0,63}$`)。
- **延后/取舍**:①**HLS 分段反混淆没有落地面**——参考的 `BigoHlsProtection`(`#EXT-X-BIGO-WEB-PROTECTION:VERSION=1,SEED=N`,前两个 188 字节包各前 16 字节 xorshift XOR,对合)已逐字节移植并有往返测试,但 v2 契约的 `LivePlayLine` 不带"分段变换"钩子,`live_playback` 也没有 relay 注入口 → 目前解不了混淆段,需要跨包 seam 才能真正播 bigo(下一条);②参考的 `resolveInput`/录制专用输入与 20s `_scoped` 截止已并入 site 的 deadline,但参考的 cancel-token 传播语义在 v2 能力签名里没有对应面(能力不接受 CancelToken);③参考搜索的 `_share()` 并发共享只保留了"无 cancel 调用者共享在途 fetch"这一半(另一半依赖 CancelToken);④参考即无热度榜、无登录、无发送弹幕、无关播信号、无徽章/表情 → 本站不做。
- 验证:整包 `dart analyze` No issues found;`dart test` **372 项全绿**(bigo 72:EVP_BytesToKey/AES-256 金标与 OpenSSL 密文金标、JSONP 回调错配、HLS seed 解析与变换对合、列表逐行跳过/去重/预算、studio 三门与 alive 修正、`complete` 语义、链接各形态、帧编解码与 tag 派发、礼物行关联、请求次序与 token 复用、能力接线与内置站清单)。douyin/twitch 测试的内置站点等值断言已随之更新为含 bigo。

## chzzk 明细(2026-10-14)
整站从 `live_core/sites/chzzk`(`chzzk_api` + `chzzk_site`)+ `live_danmaku/sites/chzzk`(`ChzzkDanmakuProtocol` + `ChzzkDanmakuConnection`)迁到 `platforms/chzzk/`。
- 能力七个全注册:room / area / discovery(同一 cursor 列表)/ search(仅 rooms)/ playback / danmaku / link_resolver;`ChzzkFailure → toLiveSiteError('chzzk')`(notFound→notFound,apiChanged→parse,network→network,rateLimited+riskControl→rateLimit,needsLogin→authentication,regionBlocked+streamUnavailable→contentUnavailable,invalidArgument→invalidArgument,其余→unexpected)。
- **没有签名也没有 Cookie**:全靠 `{code:200,message,content}` 信封(非 200 的 HTTP 与 `code != 200` 都要过)+ 固定桌面 UA/Origin/Referer。
- **只挂 `v3.1`**:live-detail 与 live-status 都用 v3.1——v2 端点对海外受限直播回 HTTP 500 / code 9004,整次读直接失败(2026-09-28 记录),v2 契约里没有"再试一次旧版"的余地。
- 目录 = **排他 cursor**:平台没有 page 参数,lives 页只能带 `concurrentUserCount`+`liveId`(本适配器把 cursor 编码成 `{"v","l"}` JSON,不是它造的 cursor 一律 invalidArgument)。超过 30 行裁到 30,并用**最后保留的那一行**当下页起点(照抄平台的 `page.next` 会跳过一行);`page.next` 字段存在却不是合法 cursor 就是 apiChanged;`next == cursor` 视作列表走完;`cvExposure` 为假的行不报在线数。没有 cursor 的"第 N 页"= 从第 1 页重放(≤`maxDirectoryPage=20` 页、`directoryDeadline=20s`),重放里已出现过的频道在后页略去——在线人数会把行在两次请求之间挪动。
- 分区:目录 `categories/live` 最多 4 页 × 50 行,`categoryType` 带中文名表(GAME/STORAGE/…)。v2 的 `getAreaRooms` 只给 areaId,故站点把读过的 `areaId → categoryType` 缓存在 `_areaTypes`,**缓存为空时才读一次目录**;查不到的 area 判 invalidArgument,绝不猜路径。
- 房间 = 两次请求(先 channel 再 live-detail;`channel.channelId` 对不上自己频道就是 apiChanged)。`openDate` 是 KST → 折成 UTC;封面把 `liveImageUrl` 的 `{type}` 模板换成 480;`blindType == 'ABROAD'` 与 `krOnlyViewing` 同算区域受限;限制次序:有播放数据 → none,播放数据读不通 → **不给限制、房间照旧立着**只记原因,区域 → regionBlocked,成人 → adult,付费 → paid,否则 unplayable。
- 播放:`livePlaybackJson` 只取 protocol `HLS` 里 `mediaId ∈ {HLS, LLHLS}` 的 master(>16 项 / 非 JSON 字符串 = apiChanged;单项坏就跳过,全坏才 apiChanged),地址必须 https、无 userinfo/fragment、≤16384 字符、host 在 `*.akamaized.net`;质量 id `<height>p`(FRAME-RATE ≥ 50 再补 `60`),标签 `<id> · HLS`,`platformOrder` 按名次;**只有音频的行(无 RESOLUTION)不算一个质量**,整份 master 无视频行 → streamUnavailable。
- **Akamai 租约** = 变体的 `hdntl=exp=`(LLHLS 写在路径段、普通 HLS 写在 query,**两处都读**)否则 master `hdnts` 的 `exp`(样本里签发后约 17 小时),`refreshAt = expiresAt - min(leaseLead=10min, 生命/4)`,`requiresReconnect: true`(每个分段都是一次新请求,token 过期 = 播放断掉,不是只断下一次读列表)。`_playback[channelId]` 存最近一次读到的 master+变体:行没到期 → 0 请求复用;master 的 token 还没在 10 分钟内到期 → 只重读 master;否则重进房间。
- 弹幕 = **JSON 帧的 WebSocket**(`IOWebSocketChannel`,v2 尚无共享 socket runtime 基类,心跳/看门狗/退避在 session 里自带):进房前 routing(1.5 s,失败退回内置 `kr-ss1..5`)与只读 access token(≤3 次、退避 500ms×次)并行问,首个 server 随机取、连不上就轮下一个;`cmd 100` 加入(`auth: READ`、`devType 2001`、无 uid)→ `10100` 且 `retCode 0` 才算连上,`302/303/304` 重连、其他拒绝终止,`90102` 同样终止;连上后 `cmd 5101`(`retCode 0`)拉 50 条近期聊天 + `notice` 置顶。心跳 20 s、静默 30 s、join 5 s,连续 8 次重连失败发一条终态系统消息后关闭事件流。
- 消息分类:`93101`/`93102` 是实时行、`15101` 是近期表(字段名两套,逐行按形态读)、`94010` 置顶、`94008` 回撤(除 `CANCEL`,回撤 `<user>:<time>`)、`0` 是服务端 ping、`10000/93006/94005/94015` 无内容可读。donation → super chat(`치즈`/KRW,五档 1/2/5/30/60 分钟,金额为 0 时只留文本、无文本只留金额、两者都无就丢掉);subscription / 赠券 / system → notice;`익명의 후원자` 是匿名者名;表情 `{:code:}` 只有本行 `extras.emojis` 给了 http(s) 地址才成 `LiveEmote`。`mbrCnt`/`memberCount`/`userCount` 是 chat **连接数**不是观众数(样本比房间在线数差 4%–75%),不读。
- **静音换房**:连续 3 分钟没有"实时行"才读一次 `live-status`(参考站自己每 30 s 轮询,这里 3 分钟一次);重开的直播会换 `chatChannelId`、旧 socket 立刻哑掉,发现新 id 就换 token 并用同一批 server 重开 socket。每次 join 的近期表会重报超级聊天/通知 → 每 session 记 ≤512 个已报 id 只报一次,普通聊天交给公共重复门。
- 链接:`chzzk.naver.com` 精确 host、http(s)、无 userinfo、空 segment 忽略,`/live/<id>`(遗留形态)与 `/<id>`、`/<id>/<tab>`(任意一级 tab)都算房间,大小写读入统一小写;`/video/<no>`、`m.chzzk.naver.com` 不是房间;频道 id = 32 位十六进制,无短链。
- **延后/取舍**:①参考的 `DanmakuSocketConnection` 基类(心跳、看门狗、退避、`DanmakuReady`/`markDisconnected`/`reopen` 语义)在 v2 没有对等物 → session 自己实现同一套时序,`reopen` 只对 chzzk 一处可见;②3.x 弹幕行里那句 `userName = 'SUPER_CHAT_MESSAGE'` 哨兵(旧 UI 内部用)不带入 v2,直接用发送者名或匿名者名;③订阅/赠券/置顶三句中文措辞**留在平台适配器里**(和参考一致),因为 v2 没有"平台消息本地化"seam,`LiveMessage.text` 就是要显示的那句——这一点与 bigo 那条"措辞归应用层"的取舍相反,理由是两个参考把它们写在不同层;④`timeMachine`(回看)、`paidProduct`(付费)只落成限制与说明,不做回看/购买流;⑤参考即无热度榜、无登录、无发送弹幕、无关播信号、无徽章/表情目录 → 本站不做。
- 验证:整包 `dart analyze` No issues found;`dart test` **453 项全绿**(chzzk 79:信封/cursor/`page.next` 严格性与逐行裁剪、目录与分区、频道/直播卡与限制次序、封面与 KST、搜索 offset 与 keyword 截断(不切断代理对)、master/变体/质量/租约两形态、帧编解码与各类信号、session 的请求次序与 token 重试、能力接线与内置站清单)。douyin/twitch 测试的内置站点等值断言已随之更新为含 chzzk。

## 环境缺口
无。此前 `packages/live_playback` 以 `path:` 依赖工作区外的 `D:\media_core` 导致整仓 `dart pub get` 解析失败、`dart test` 跑不起来;2026-10-14 已把 `media_core` / `media_core_danmaku` / `media_core_mediasession` 改为 pub git 源(`github.com/liuchuancong/media_core`),仓库根 `flutter pub get` 即可完整解析,交付门的 test 步骤不再需要人工补 media_core 或造桩。
