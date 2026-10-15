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
| kick Kick | ✅ | 见下方"kick 明细";已注册进 `built_in_sites`(`fc2live` 之后) |
| niconico Niconico | ✅ | 见下方"niconico 明细";已注册进 `built_in_sites`(`kick` 之后) |
| fc2live FC2 Live | ✅ | 见下方"fc2live 明细";已注册进 `built_in_sites` |
| jdlive 京东直播 | ✅ | 见下方"jdlive 明细";已注册进 `built_in_sites` |
| kilakila 克拉克拉 | ✅ | 见下方"kilakila 明细";已注册进 `built_in_sites` |
| kugoulive 酷狗直播 | ✅ | 见下方"kugoulive 明细";已注册进 `built_in_sites` |
| soop SOOP | ✅ | 见下方"soop 明细";已注册进 `built_in_sites` |
| missevan 猫耳FM | ✅ | 见下方"missevan 明细";已注册进 `built_in_sites` |
| pandalive 판다라이브 | ✅ | 见下方"pandalive 明细";已注册进 `built_in_sites` |
| picarto Picarto.TV | ✅ | 见下方"picarto 明细";已注册进 `built_in_sites` |
| looklive LOOKS LIVE | ✅ | 见下方"looklive 明细";已注册进 `built_in_sites` |
| liveme Live.me | ✅ | 见下方"liveme 明细";已注册进 `built_in_sites` |
| xiaohongshu 小红书 | ✅ | 见下方"xiaohongshu 明细";已注册进 `built_in_sites` |
| cc 网易CC | ✅ | 见下方"cc 明细";已注册进 `built_in_sites` |
| inke 映客 | ✅ | 见下方"inke 明细";已注册进 `built_in_sites` |
| showroom SHOWROOM | ✅ | 见下方"showroom 明细";已注册进 `built_in_sites` |
| twitcasting ツイキャス | ✅ | 见下方"twitcasting 明细";已注册进 `built_in_sites` |
| iptv | ✅(seam) | 基线既有,跨包 seam,非典型直播站 |
| weibo 微博 | ⬜ | 快照门控站(无 cursor 分页) |
| seventeenlive / sixroom / steambroadcast / yy | 🔄 | 后台代理进行中(sixroom/yy 测试编译收尾) |
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

## kick 明细(2026-10-14)
整站从 `live_core/sites/kick` + `live_danmaku/sites/kick.dart` 迁到 `platforms/kick/`。**无新依赖**:纯 REST JSON + Pusher WebSocket(手搓 JSON 帧,无 pusher 包)+ M3U8 master 解析。
- 能力:room/area/discovery/search/playback/danmaku/link_resolver,`Either` + `KickFailure`。房间 `/api/v2/channels/<slug>`(chatroom.id ≠ channel id);areas `/api/v1/categories`+`subcategories`;目录 `/stream/livestreams/en`;搜索 `/api/search`(单页)。roomId=slug(小写;kick 忽略大小写,代码无 SiteIds,就地小写)。
- 弹幕 = Pusher `wss://ws-us2.pusher.com/app/32cbd69e4b950bf97679`(app key 字面量),订阅 `chatrooms.<id>.v2`/`channel.<id>`/`channel_<id>`;ping 30s、activity_timeout 120s 重连(douyu 同款双开互斥+失败上限);`App\Events\ChatMessageEvent`(data 为 JSON 串)→chat(#RRGGBB、badges_v2 level、`[emote:id:name]` 内联)、`KicksGifted`→gift、删除/封禁/清屏→撤回、`StopStreamBroadcast`→结束。
- 播放:`playback_url` = 签名 IVS HLS master(`*.live-video.net`,EXT-X-MEDIA+STREAM-INF),lease 取 JWT `exp`。
- **状态**:文件先推送 `fa8f7d61a`,2026-10-15 补逻辑并**已注册进 `built_in_sites`**(douyin/twitch 测试的内置站点有序等值断言同步加 `kick`)。
- 2026-10-15 逐条对照参考(`live_core/sites/kick` + `live_danmaku/sites/kick.dart`)补的逻辑,框架与模型未动:
  - **图片 URL 归一化**:参考 `normalizeImageUrl`(`live_core/json.dart:123`)搬到 `kick_json.dart`,channel 封面/离线横幅、主播头像、分区 banner、列表卡与搜索卡六处全部走它——Kick 的 CDN 常回 `//files.kick.com/…` 甚至裸 `host/path`,不归一化就是一片空白图。
  - **JSON 读数容错对齐参考**:`jsonString` 改为 trim 且空白算 null(参考 `json.dart:88`),`jsonCount` 从 `>0` 改成 `>=0`(参考 `json.dart:82`)——零观众/零粉丝的房间过去读成"未知",现在读成 0。
  - **播放恢复**:`getLines` 命中缓存但 token 已在 2 分钟内到期 → 强制重读 channel+master(参考 `resolvePlayUrlsForRecoveryRaw` 总是重取的原因:token 被服务端提前作废时,只按 10 分钟寿命判缓存就永远回不来)。
  - **分区父级预拒**:`getAreas` 记下的顶级分类 slug 在 `getAreaRooms` 直接 `invalidArgument`,不再发一次请求把整个总目录读回来当空分区(参考 `kick_site.dart:152` 靠 `areaType` 判,本站 `LiveAreaProvider` 只给 areaId,故用已读到的分类集合)。
  - **master 状态与截断**:IVS 401 → riskControl(→ `LiveSiteRateLimitError`),与 403/404 的 streamUnavailable 分开;最后一个 `#EXT-X-STREAM-INF` 下面没有地址(或两个连排)→ apiChanged,不再静默少一个清晰度。
  - **弹幕 `StopStreamBroadcast` 不再拆流**:只报公告、socket 留着(参考 `kick.dart:149-155`)——同 chatroom 下重开的直播能在本会话继续收,之后的静默交回看门狗;`KickFrame.ended` 随之以外删掉(死字段)。
  - **第二传输 `apiHttp`**:参考把 kick.com 的 API 走 app 注入的 Android 系统 TLS(dart:io 握手恒被 Cloudflare 403 "Request blocked by security policy"),IVS 走普通传输。本站同样开 `KickSite({http, apiHttp})` 这个口子,`apiHttp` 缺省等于 `http`,`httpGet` 走 API 传输、`mediaGet` 走媒体传输,`dispose` 各关一次;注册表仍只传 `http`(app 有系统 TLS 传输时注入即可)。
- **延后项(记档不假造)**:①能力签名不收 `CancelToken`,参考每请求透传取消令牌这条在 v2 契约无对应面(与 bigo 那条同一取舍);②公告文案仍是英文(`Broadcast ended`/`Danmaku connection lost`),与参考的中文 `直播已结束` 不同——本站 `site.locale` 注入了但没用到,douyu/huya/acfun/bigo/bilibili/chzzk/douyin/twitch 八家同样写英文,单独给 kick 换语言只会让包内更不一致,归到"平台文案本地化"这条跨站欠账里一起解;③`is_mature` 只落 `content.notice`,**参考就是** `restriction: LiveRestriction.none`(它不把成熟内容当播放限制),所以这不是缺口;④`KickDanmakuSession` 直接构造 `DanmakuSocket`,没有注入假 socket 的口子 → 重连/看门狗时序仍只能在线下起会话(与参考的基类差异,同 bigo/chzzk 记的"无 socket runtime 基类")。
- 验证:`dart analyze lib/src/platforms/kick test/platforms/kick lib/src/internal` No issues;`dart test test/platforms/kick` **49 项全绿**(新增:图片归一化与零计数端到端、`jsonString`/`jsonCount`/`normalizeImageUrl` 单元、401→riskControl、截断 master→apiChanged、租将耗尽时重读 channel+master、顶级分类预拒、七个能力接线 + 已进内置站点);整包 `dart test` **652 项全绿**。整包 `dart analyze` 仍剩 2 条 twitch 文件里的既有 info lint(`avoid_redundant_argument_values`、`prefer_foreach`),不在本轮改动内。

## niconico 明细(2026-10-14)
整站从 `live_core/sites/niconico` + `live_danmaku/sites/niconico.dart` 迁到 `platforms/niconico/`。**无新依赖、匿名运行**:手写 protobuf reader + 手写 HLS master 解析 + 一个 seat WebSocket(web_socket_channel)+ HTTP-protobuf 弹幕轮询。
- 房间:watch 页 `<script id="embedded-data">` 的 HTML-entity JSON(状态是字符串 RELEASED|ON_AIR|ENDED;restriction 由 canWatch/needLogin/isCountryRestrictionTarget/payment 决定)。discovery=`front/api/pages/recent/v1/programs?tab=`(7 tab:common/try/live/req/face/totu/vtuber);search=`.../search/v1/programs`;area 即这 7 tab。
- 播放:seat `{"type":"stream"}` 给 `master.m3u8`(`livedelivery.dlive.nicovideo.jp`)+ `availableQualities`(丢 audio_*)+ `cookies[]`;媒体请求带 path 作用域、可回收的 cookie grant,lease=cookie 过期。
- 弹幕两层:v2 **seat WebSocket**(`a.live2.nicovideo.jp/…/wsapi/v2/watch/`,startWatching→getAkashic,keepSeat/pong,`messageServer`→viewUri,commentable:false,END_PROGRAM→换 seat)+ **HTTP protobuf(NDGR)** 读 ChunkedEntry/ChunkedMessage/NicoliveMessage(chat 字段1/overflowed_chat 20;Chat text1/sender2/id6|5;meta1/Timestamp 2);douyu 同款生成号+双开互斥+失败上限终止。
- **已知取舍**(离线无法验):seat WS 未发 origin 握手头(与 douyu 一致的可移植选择);弹幕按窗口缓冲读取非真流式;会话中途 4xx 折进重试上限而非立刻换新 seat。
- **状态**:文件先推送 `6809f7ae1`,2026-10-15 补逻辑并**已注册进 `built_in_sites`**(douyin/twitch 的内置站点有序等值断言同步加 `niconico`)。
- 2026-10-15 逐条对照参考(`live_core/sites/niconico` 三文件 + `live_danmaku/sites/niconico.dart`)补的逻辑,框架与模型未动:
  - **搜索分页有下文**:`NiconicoRoomParser.searchRooms`/`site.search` 改为带 `hasMore`(参考 `niconico_site.dart:228` 的 `total > page*size`),`NiconicoSearchProvider` 不再交一个 `hasMore` 为 null 的 `LivePage`——之前第二页能不能翻只能靠试。
  - **入口页当 seat 的 bootstrap**:`detail()` 读到能看的房间页就存进 `_bootstraps`(60 秒、最多 8 间、**取一次**),`openSeat` 先用它开 seat,失败(过期/被拒)才重读页再开一次(参考 17-6)。键用的是**返回给调用方的 `room.roomId`**,不是页里的 `lv…`——`user/<id>` 入口的房间,后续正是拿 `user/<id>` 来开 seat 的。省掉的就是"进房 + 播放 + 弹幕"各自再抓一遍 watch 页。
  - **越界不发请求**:新增 `NiconicoFailureKind.invalidArgument` → `LiveSiteError.invalidArgument`;页码限 1–10000、页大小 1–100(参考 `_checkPaging`),关键词限 500 字,`getAreaRooms` 给非 tab 的 id(含父级 `niconico`)判调用方错——**原来会静默按 `common` 去读**,把总榜当成分区列表返回。
  - **响应体积上限**:`responseLimit` 2 MiB,watch 页与列表体都先过 `_limit`(参考 `niconico_api.dart:1152`,字符数与 UTF-8 字节数两道,中文页两者差 3 倍),超了判 apiChanged,不再把代理塞来的大-body 喂给解码器。
  - **媒体读有预算**:`NiconicoHttp.get`/`site.httpGet` 收可选 `timeout`,`NiconicoPlaybackProvider.masterTimeout` = 5s(参考同名)打在 master.m3u8 读上——CDN 卡住时不再回落到传输默认超时把 seat 一起拖死。
  - **seat 可注入**:`NiconicoSite({seatConnector})` 把 `NiconicoSeat` 已有的 `SocketConnector` 口子透出(缺省 `webSocketConnect`),bootstrap 复用与"失败后重读页再开一次"这条时序才有离线测试。
- **延后项(记档不假造)**:①`live_net` 没有"不跟随重定向"的请求参数,参考的 `followRedirects: false` + 3xx 判网络错在本站做不到(需要跨包 seam);②参考的 `masterTimeout` 之外还有 `discoveryDeadline` 30s 总预算和"跟着 `seat.changes`/`seat.done` 换 master",v2 能力签名不收取消令牌 → 未复刻;③`regionBlocked`/`needsLogin` 都折到 `authentication`、`riskControl` 折到 `rateLimit`(`LiveSiteError` 没有地理/风控档,模型不动,记录此折叠);④master 变体缺 `RESOLUTION`/重复 `WxH@BW`/音频歧义,参考判 apiChanged,本站按现有口径跳过坏行(只有整份无可播行才报错);⑤seat 启动计时器仍在握手成功后起(参考在连接前起),最坏 2×20s;dispose 无 `closeTimeout` 约束;⑥3.x 的 `resolveRoomId`(遗留 `lv…` 迁到主播号)与 `notice()` 本地化公告在 v2 无落点;⑦`contribution_rank`/礼物 `message`、画质标签 `800x450 · 1080800 bps` 的差集,现有 `LiveGift`/`LivePlayQuality` 无对应字段。
- 验证:`dart analyze lib/src/platforms/niconico test/platforms/niconico` No issues;`dart test test/platforms/niconico` **39 项全绿**(新增:totalCount→hasMore、非 tab 分区预拒、越界页码/关键词预拒、超 2 MiB 体判 apiChanged、bootstrap 复用 + 失败后重读页各开一次 seat、无 seat 页不留 bootstrap、媒体读带 5s、已进内置站点清单);整包 `dart test` **660 项全绿**。

## fc2live 明细(2026-10-15)
整站从 `live_core/sites/fc2live`(fc2live_api + fc2live_control + fc2live_site)+ `live_danmaku/sites/fc2live.dart` 迁到 `platforms/fc2live/`。**无新依赖**:三张表单 POST + 一条控制 WebSocket(已移上 live_websocket,2683783ae)+ 手写 HLS 应答解析。文件先随 be7ca597e 等提交入库并已注册进 `built_in_sites`;2026-10-15 子代理逐条对照参考收尾,框架与模型未动。
- 能力七个全注册:room / area(单一分类 + 6 分区,含 `all`)/ discovery(目录切片)/ search(快照过滤,精确频道号/链接走 memberApi 仅 page1,NotFound 即无结果)/ playback / danmaku / link_resolver;`Fc2LiveFailure → toLiveSiteError('fc2live')`(401/403 折 rateLimit;transient 仅 network/rateLimited)。
- 数据面:全站目录 = `allchannellist.php` 单快照(page1 强制新拉、20s 复用、在途 fetch 共享、失败快照丢弃);房间 = `memberApi.php` 一请求(status≠1/无 owner → NotFound,五限制旗标 → restricted,离线与受限分得开);播放无地址:`getControlServer.php` 发一条控制 socket grant(wss 子域/路径/token/orz 严格校验),`get_hls_information` 问一次 HLS 应答(3 延迟家族、mode 0–999、5 档 tier + auto、坏行单跳、地址严格校验),媒体地址只在 control 开着时有效 → `LivePlayLease`(签发+1min、提前 6s 刷、requiresReconnect);adapter 每频道持有一个 control 共享给多个观看者,租期起点 = grant 应答时刻。
- 弹幕(参考 667 行逐条对齐):每次握手新 grant 真 socket;页面心跳 30s 逐字节、join 8s 超时、静默 90s 换线;`connect_complete` 进房;`comment`(history/system 跳过、匿名 `[anonymous]`、发送方 id 偏移算法逐位一致、8 色+白、timestamp 越界丢弃)、`user_count`(增量记忆、pc+mobile 求和、变化才发)、NG 全集(keyword/channel/admin/user/share_*,按 id 增删、无名等值删、跨 socket 保留每 socket 重发)、`control_disconnection`(4500 grant 过期/1000 关播)换新 grant、`move_server` 立即换线;重连双开互斥 + 8 次无被答心跳终止上报(心跳被答即清零);token/cookie 不进任何报错。礼物走 system_comment 且参考即无定价,两侧一致跳过。
- 链接:`live.fc2.com/<id>/` 与 `/13 语种/<id>/`,频道号 1–12 位无前导零,`/rank/`、`/archive` 与外 host 拒绝。
- **2026-10-15 对照收尾补的六条**(子代理对照产出,前四条为工作区既有打磨一并入库):
  - 会话在握手在途时被替换/关闭:迟到的 socket 当场关掉,不再挂在死代次上;
  - `_renewNow`(move_server)计入重连预算——节点间 ping-pong 不再无限重开(参考 server 令重连同样计入);
  - `heldOf` 租期起点前移到 grant 应答时刻(control 的握手+HLS 开销不计入租期,地址不会一签发就过期);
  - `jsonInt` 收整数 `num`(`30.0` 与 `30` 同一 mode,小数不算);
  - **`isTransient` 去掉 `riskControl`**(参考 `RiskControl.isTransient=false`:边缘封禁不因重试解除,401/403 首个 grant 即终止会话,不再空转 8 次退避;折入 rateLimit 的映射保留,v2 无独立 kind);
  - **弹幕会话 teardown 取消在途 grant 请求**(`CancelToken` 贯通 `controlGrant → member/post`,disconnect/dispose 即 cancel,对齐参考 `_Grants.cancel`;`CancelledFailure` 视作"正在关闭"不报错;测试用挂起传输验证 token 传导)。
- 清理:删除测试草稿分片 `part2.dart.txt`/`part3.dart.txt`(内容已全部并入 `fc2live_test.dart`)。
- **延后项(记档不假造)**:①owned input recipe / appliedQualityData(v2 无 recipe 面,line label 承担实际档位);②恢复重取解析器(v2 由 lease/requiresReconnect 语义触发重解析);③probeControl 探针交接(v2 无"socket 交给播放器"面,heldOf 共享等效);④`getLiveStatus`/刷新/录制专用入口(无对应 capability,播控路径每次重发 memberApi 等效覆盖);⑤目录 scope 说明文案(v2 无目录级本地化面);⑥重试退避为线性 1s×n(参考 runtime 内建退避,性能型内部项)。
- 验证:`dart analyze lib test` 除 2 条 twitch 既有 info(见 kick 明细)外无新增;`dart test` 整包 **662 项全绿**(fc2live 91,新增 isTransient 分级与 mid-grant 取消两例)。

## jdlive 明细(2026-10-15)
整站从 `live_core/sites/jdlive`(jdlive_api + jdlive_site)+ `live_danmaku/sites/jdlive.dart` 迁到 `platforms/jdlive/`。**无新依赖**:两个匿名 API GET + 一条纯收 WebSocket(live_websocket 的 SocketChannel seam)+ 复用 `common/crypto/aes_cbc.dart`(bigo/acfun 共享的 AES,零新代码)。
- 能力七个全注册:room / area(唯一分区"精选直播购物")/ discovery(同列表独立页序)/ search(rooms;精确 liveId/链接直查,其余过滤目录页序)/ playback / danmaku / link_resolver;`JdliveFailure → toLiveSiteError('jdlive')`(401/403 折 rateLimit;transient 仅 network/rateLimited,401/403 不重试——吸取 fc2live 缺口①教训)。
- 数据面(匿名,无签名,无 cookie):iOS Safari UA + origin/referer;全站列表 = `liveListWithTabToM` **原生页序**(page1 起序记 timestamp,后续页发前页 `currentCount`,页序内去重、无新广播即止;directory/recommend/每关键词各一条页序,搜索页序 LRU 32,卡片记忆 LRU 2000);房间 = `getImmediatePlayToM` 播放答案(状态 1/0/2/3/10/11 → live/preview/offline/replay/paused,`secret` 1 = appOnly)且**无名无封面无人数**——用 `enrich` 从最近卡片补全,follow 因此保留旧值;入场时直播间的 `h5VideoUrl` 播列表**下载并校验**(`#EXTM3U`、1M 字符、引用必须同 host `/live/` 同流名干、1–1000 条,404 → streamUnavailable)。媒体校验:https、`*.jdcloud.com`、`/live/`、无 userinfo/fragment、≤8192;FLV 取 `videoUrl` 否则 `pcVideoUrl` 且流名干必须与 HLS 一致;回放录像 = `*.300hu.com` 的 m3u8。清晰度:直播 HLS(推荐)+ FLV(仅有地址的),回放"原画";线路 host 作 label,带媒体头(origin/referer 指向房间页),**无 lease**(地址无签名无过期)。
- 弹幕(纯收,网页游客 `liveauth`):每次握手 POST `liveauth`(表单 body = {appId:'jd.mall', content:AES-128-CBC(密钥/IV 硬编码在页脚本,PKCS#7+Base64) 的 JSON:groupId=liveId/timestamp/origin=-100/random 六位}),答案给 `wss` liveUrl(*.jd.com、无 query/fragment)+ 一次性 token + 可选 `msgMaskKey`;socket 上**客户端不发任何帧**(进房帧只是访客公告),开箱即 joined;服务端推 JSON 文本或按 maskKey 逐字节 XOR 的二进制:`get_statistics_result`(`current_viewer`→online、`total_viwer`(sic)→累计)、`chat_group_message`(viewer_send_message 用 nickName、anchor_send_message 显示"主播"、正文 content、用户 id=`from.pinmd5`、时间 datetime)、`stop_live_broadcast` → 终态系统消息关流(新直播是新 liveId,不重连);groupid 不符丢弃。时序:静默看门狗 200s(服务端 180s 空闲踢线,留 20s 余量;无统计的安静房间属正常)、重连=完整 liveauth 重握手、双开互斥 + 8 次失败上限终止上报;liveauth 的 `CancelToken` 在 disconnect/dispose 即取消(吸取 fc2live 缺口②教训);token 不进任何报错。
- 链接:`lives.jd.com` 任意大小写、http(s) 默认端口、fragment 路由 `#/<id>(/live|notice|closed|replay)?(\?query)?`;1–18 位无前导零;外 host → unsupported。
- **v2 形态适配(记档)**:①播放能力签名只收 roomId——播放在 `_known` 无播放答案时自取一次(对齐参考 recovery;有则零请求,对齐参考"先开房");②搜索的 hasMore 透出页序的 hasMore(后续页是否命中平台不说);③目录页为平台原生 30 条/页,request.pageSize 不重塑(与 fc2live 快照切片不同,京东页序无法本地重切);④`followRedirects:false` 与参考 `_scope` 的 cancel 透传同 niconico 记档,v2 无对应面;deadline 用 `_scoped`(20s,到时折 network)。
- **延后项(记档不假造)**:①`directoryNoticeKey`(目录 scope 说明)与`getRoomDetailForRefresh/ForRecording/getLiveStatus` 变体、可取消搜索、恢复重取解析器——v2 无对应面(同各家记档);②h5st 签名参考即无(游客接口),若平台收紧需另行补;③`pv`/`max_viewer`/`message_num`/`thumbs_up_num`/`cart_num`、`plus`/`userMemberLevel`/`loveLevel`/`extraTag`/`ext`、`eid` 风控指纹——参考即不读,不做;④回放录像不预下载(JD 整场录制,样本 1.4MB/9500 分段);⑤`LiveGift` 无落点——参考即无礼物,不做。
- 验证:`dart analyze lib test` **No issues found**(含 twitch 既有 2 条 info,已被用户并行改动一并清掉);`dart test` 整包 **712 项全绿**(jdlive 50:信封/状态门、列表逐行跳过与页序、播放媒体校验/回放/appOnly、播列表校验、房间映射/清晰度/线路、AES 往返与 liveauth 表单、帧解码/掩码/群组、会话握手/静默换线/预算终止/mid-handshake 取消、页序分页/分区/搜索序列/播放自取/链接、能力接线与内置站点等值)。

## kilakila 明细(2026-10-15)
整站从 `live_core/sites/kilakila`(kilakila_api + kilakila_site)+ `live_danmaku/sites/kilakila.dart` 迁到 `platforms/kilakila/`。**无新依赖**(crypto 已在 pubspec):AES-128-CBC 解密复用 `common/crypto/aes_cbc.dart`,图片归一化 `normalizeImageUrl` 自 kick 上提 `common/normalization/site_urls.dart`(§3:两平台证实才上提,kick 经 export 切到共享版;douyu/huya 各有一份私有同实现副本,合一另记);手写迷你 HTML 读取器替代 package:html(仅搜索页用)。
- 能力七个全注册:room / area(两条时间线 热门直播 0 + 萌星推荐 107)/ discovery(热门时间线,独立页序)/ search(rooms;uid/锚链/直播间分享链直查,其余走网站用户搜索页)/ playback / danmaku / link_resolver;`KilakilaFailure → toLiveSiteError('kilakila')`(401/403 折 rateLimit;transient 仅 network/rateLimited)。
- **房间即主播**:roomId = 主播 uid,每场直播的 `roomIdStr` 都是新 id(REG-001,follow 因此不失效);身份信息 `Tg/personalH5?uid=` 一请求(code 1013 → notFound;`liveCard` 只有 `roomSourceType`/`recommendSource` 路由默认键 = 无当前直播 → 离线),入场再 `LiveRoom/getRoomInfo?roomId=`(h.code 5201 → notFound、5966 → 历史回放 streamUnavailable;答案的 uid 必须对得上)——两请求都过 `enteredRoom` 合并:卡片才有的开播时间/当前收听数/封面回填进 getRoomInfo 答案,简介与粉丝数随房间走。时间线 `pcLive/timeline` 双层信封(code + data.body.{h,b}),dataType 8(萌星 2)是直播行,坏行单跳、全坏 apiChanged、echo 不符 apiChanged;页序去重 + 连续 3 页无新主播即止(时间线会整页重复)+ 平台 100 页封顶(萌星曾跑到 300 页),记录随页走、重读第 1 页即重置。
- **播放**:拉流地址只认 `https://pull.live.hongrenshuo.com.cn/hrs/<roomIdStr>.flv|.m3u8?auth_key=…`(默认端口、无 userinfo/fragment、恰一个非空 auth_key,push 地址永不读);单一清晰度"原画",FLV+HLS 互为线路(lineLabel = flv/hls),租约 = auth_key 首段 Unix 秒,refreshAt = 到期 − min(10min, 寿命/4),`requiresReconnect` 只标 HLS(过期 m3u8 断播、已建立的 FLV 连接不断——参考 cutsConnection 语义);付费(goldPrice>0)先行拒绝 restriction=paid,状态非 4/无地址同理;存量质量 id `flv`/`hls` 归一到 `original`。
- **弹幕**(15-8,参考 3.x 无):Socket.IO 2 over Engine.IO 3,`wim.hongrenshuo.com.cn/socket.io/?roomId=<roomIdStr>&appId=111&clientType=1&EIO=3&transport=websocket`,命名空间 `/live_chat_room_guest`;开箱即发 `40/namespace?query,` 加入,Engine.IO ping `2` 每 25s(服务端 85s 不 ping 踢线),静默 90s 换线,join 8s 预算;`40`/`connect_error` code 0 = 已进房(清拒绝计数),`44`/其他 code = 拒绝(3 次重试后第 4 次终态),`41`/Engine.IO `1` = 服务端离场换线,8 次无进房终止上报。帧派发:`text_message` 双层 JSON(body.response.content 再解一层),t=200 聊天(c/n/u/l,mid/created_at)、637 房态(c 是 URL 编码 JSON,watchNumber→在线;自写 `decodeURIComponent` 兼容裸中文)、220/10004 礼物(见下)、240/300/301/532/534/706 面板中的付费提问 → superChat(uc.uiType ∈ 问答集合且 goldPrice>0,文本逐字段 URL 解码,价格文案千分位"6,000红豆",展示 5 分钟)。**礼物**:红豆折 `LiveGiftUnit.gold`(v2 无 redBean 档,记档),免费礼物 free;连击 220(isDoubleHit)与 10004 礼物行共享 `c.no` 作 comboKey、`c.doubleCount` 作总数,单价 = 行价格/整倍数;会话内 `KilakilaGiftCombos` 去重(256 容量):只报比已报计数大的连击命中/行,防同数重复。
- **链接**:live.kilakila.cn / www.hongdoufm.com(直播 `/room/<id>`、详情 `?id=`、锚 `/zhubo/<uid>` 无 query)+ live.hongrenshuo.com.cn(https,`/index/roomuser/uid/<uid>`);**加密分享链接**(uxin-security-url-crypto-v2,公开常量非凭据):URL-safe base64 → AES-128-CBC(双公钥逐一试)→ 明文 `<id>?k=v&sign=md5`,MD5 签名绑定 scheme/host/路由原文(重编码即拒)。链接 resolver:锚页免请求 canonical 化,直播间链接一次 getRoomInfo 换锚页。
- **v2 形态适配(记档)**:①播放能力只收 roomId——`_streams[uid]` 缓存入场数据,无则自走一次入场(等效参考 recovery;有则零请求);②用户搜索页不报状态(LiveStatus.unknown)、hasMore 未知;③搜索无分页上万的页越界折 invalidArgument;④follow 刷新/`getLiveStatus` 独立入口无对应面(入场即含);⑤`followRedirects:false` 同各家记档。
- **延后项(记档不假造)**:①`directoryNoticeKey` 目录范围说明、可取消搜索、CancelToken 透传——v2 无对应面;②`pushFlow` 推流地址(主播推流 key)参考即不读;③`rtmpPlayUrl`、点赞/进场/ rank 类事件(101/102/210/211/603/635/636/654/663)、`vip`/`m`/`g`/徽章、提问卡下播按钮——参考即不读/不显示;④历史回放(5966)不可播,落 streamUnavailable。
- 验证:`dart analyze lib test` **No issues found**;`dart test` 整包 **759 项全绿**(kilakila 47:信封与状态门、时间线行过滤/去重/回显门、搜索页 HTML 提取与实体解码、profile/liveCard 路由键、getRoomInfo 码表、拉流地址与租约、房间映射、加密链接三种形态+双钥匙+篡改拒绝、Socket.IO/Engine.IO 帧派发、聊天/房态/礼物/提问解码、连击去重、会话 join/ping/静默/拒绝/预算、页序与空闲截止、能力接线与内置站点等值)。

## kugoulive 明细(2026-10-15)
整站从 `live_core/sites/kugoulive`(kugoulive_api + kugoulive_site)+ `live_danmaku/sites/kugoulive.dart` 迁到 `platforms/kugoulive/`。**无新依赖**:protobuf 复用 douyin 的手写件派生为 `kugoulive_protobuf.dart`(同套一层级无 schema reader/writer);gzip 用 dart:io;snappy 按 snappyjs 逐行手写(60 行,raw block 解码);HTML 实体解码上提 `common/normalization/html_entities.dart`(kilakila 同步改用共享版,两平台证实)。
- 能力七个全注册:room / area(首页链接的 `/pcindex/category/<id>`,个人路由 3001/3009/3014/3015 剔除,空页用 14 条兜底分区表)/ discovery(推荐 8000)/ search(rooms;房间号/房间链接直查,关键词走网站 JSONP 用户搜索)/ playback / danmaku / link_resolver;`KugouliveFailure → toLiveSiteError('kugoulive')`(HTTP 451 折 contentUnavailable——v2 无 region 档,记档;401/403 折 rateLimit;transient 仅 network/rateLimited)。
- 数据面(匿名,房间号即身份,3–11 位无前导零):首页一遍抓分区,`index/list`(推荐)/`list_v4`(分区)房间列表(`star` 行拆包、房间去重、hasNextPage 1/true、`times` 作列表时钟);房间 = `getEnterRoomInfo`(`liveType` -1 离线、有 `liveSessionId` 在播、其余 unknown;`limitType` 是**聊天**限制不是观看限制,不影响播放——记档与 3.x 的差异;无名且 kugouId 0 → notFound;`publicMesg`/`privateMesg` 是聊天公告不是标题,标题置空让 follow 保留);播放 = `streamaddr` 签名腾讯云地址:行×profile 分组为 `<protocol>:<rate>:<codec>:<layout>` 变体(FLV+HLS 两个协议键),`code -1` → needsLogin、status≠1/无可用地址 → streamUnavailable、答非所问 → apiChanged;媒体地址只认 `*.liveplay.live.kugou.com/live/*.flv|.m3u8` + 非空 `txSecret` + 十六进制 `txTime`(`token` 不读——记档 29-7:签名格式变更会让整站失联);租约 = txTime 十六进制 Unix 秒(约 12 小时),提前 5 分钟续(过期即 now);HEVC(codec 2)变体照收,"优先 H.264" 默认开 → H.264 变体排前、默认清晰度永不 HEVC;存量接口偏好 `preferH264` 注入。
- **弹幕**(29-5,M5.25):调度器 `socket_scheduler/pc/binary/v2/address.jsonp`(MD5 签名:键排序 k=v 串 + `$_fan_xing_$`,取 hex[8:24])给 3 个聊天 host + `soctoken`(5 分钟 age);帧 = 18 字节头(100/version 3/type 1/12/command/len)+ protobuf 信封 `SocketProtocol.Message{content 7, codec 16, compression 5, ack 2, rpt 3, msgId 4, offset 1}`;登录 201(重连 2201 + socsid),901 状态帧 type1+status1 = 进房(拿 socsid),否则 `errorno`(622 = token 被拒 → 弃 token 重新调度);心跳 4 字节帧每 10s(服务端答 `64 00 03 00`),静默 90s 换线,join 10s 预算;拒绝 3 次、8 次无进房终止上报;调度器 3 试(1.5s/4.5s 页面退避),token 按-age-复用/被拒/落在未答套接字上则重调度。消息:`Content.ContentMessage` codec1 → 501 聊天(`ChatResponse`)+ ext(39 intimacyVo 粉丝牌/8 userGuard/9 littleGuard → 文本橙 #ff9900,JS truthiness)+ sinfo(ck=1 神秘人 → 金 #CC9900 + ckid 匿名 id)+ 400305 PK 对面房间聊天(tags&1 且带 source.roomid → sourceRoomId);601 礼物(`GiftEffectSocketMsg`:星币价格 → v2 折 **gold** 记档,free=价格 0,comboKey=comboIdV2 否则 comboId≠0,comboTotal=comboGiftSum,图标 s4fx.kgimg.com 补全,ack 1 → 回 211 AckRequest);301005 JSON 房态(actionId roomAuNumber,count→在线、visited→本场累计);gzip/snappy 4MiB 上限;服务端对未 ack 礼物重发两次 → 会话按 msgId LRU 256 去重;聊天剔除私聊(receiverid≠0)/负 senderid/privateType 1/他房。
- 链接:fanxing/mfanxing.kugou.com,`/<roomId>` 单段或任意路径 `?roomId=<n>`(29-4 手机分享页),默认端口、无 fragment/userinfo;无短链。
- **v2 形态适配(记档)**:①播放能力只收 roomId——`_streams[uid]` 缓存入场数据,无则自走一次入场(有则零请求);②搜索关键词 200 条本地切页,hasMore 仅在切页还有余量时为 true(平台不报总数);③follow 刷新/getLiveStatus 独立入口无对应面;④`followRedirects:false`、CancelToken 透传同各家记档;⑤HTTP 451 折 contentUnavailable(v2 无 region 档)。
- **延后项(记档不假造)**:①`directoryNoticeKey`/`chatNotice` 之外的目录 scope 文案(v2 无目录级本地化面;房间级 notice 已带);②`token` 前缀校验(29-7 有意省略);③贵宾/等级外的礼物面板字段;④首页 `staticVersion` 固定 7.0.0(页面实际值可在响应里校验,记档);⑤重连后重新调度的 socketPv/时间戳漂移(与页面一致即未做漂移补偿)。
- 验证:`dart analyze lib/src/platforms/kugoulive test/platforms/kugoulive lib/src/internal lib/src/common` **No issues found**;`dart test test/platforms/kugoulive` **31 项全绿**(信封/状态门、时钟合理性、房间号/链接、分区提取与兜底、列表 star 拆包/去重/搜索卡 viewers 门、房间信息码表、流地址校验与租约、变体分组排序与 preferH264、调度签名/grant、登录帧/心跳/uuid、状态帧 join/refusal、聊天徽章/等级/颜色、礼物星币折算/连击/ack、snappy/gzip 边界、会话调度 3 试/拒绝终止/非房间号预拒、能力接线与内置站点等值)。整包 tests 由并行站会话收尾后统一复跑。

## soop 明细(2026-10-15,后台代理移植)
整站从 `live_core/sites/soop` + `live_danmaku/sites/soop.dart` 迁到 `platforms/soop/`(后台代理按 kugoulive 同款模板与交付门执行,我审查后注册)。**无新依赖**。
- 能力七个全注册:room / area / discovery / search / playback / danmaku / link_resolver;`SoopFailure → toLiveSiteError('soop')`。
- 数据面:`player_live_api/*/live/{id}/playlist.am` 状态门与 RESULT 分支、`station` 页 + `withStation` 合并、在线人数回退链、KST 开播时间、BTIME、VIEWPRESET/qualitySort 清晰度分层、assign/aid/resolution;房间号/站号链接解析(appLink/appLinkRoomId 保留为 endpoints 纯函数)。
- 弹幕:ESC/TAB 定长帧切割、login/heartbeat/join、chat/별풍선(星气球)/애드벌룬(广告气球)/영상풍선(视频气球)/구독(订阅)消息;20s 心跳、90s 看门狗、TLS→明文端口回退、重连预算 8 次终止上报;服务器无 join 确认包,套接字开即 join(faithful)。
- **代理的适配与取舍(记档)**:①参考全程带用户 cookie,v2 context 不传凭证 → 匿名;年龄限制广播(-6)由可播改为 authentication(与 chzzk/bigo 一致),明文端口去-Cookie 逻辑随之删除;②별풍선/영상풍선 付费币折 v2 `gold`(unitPrice 1),애드벌룬折 `other`(无价),礼物文案 kilakila 式 `名 ×数`;③v1 三入口合并为 getRoom,`roomIdsInShareText`/传 detail 的播放/恢复接口无 v2 面 → 恢复=aid 请求被拒(RESULT 0)自然上报+重新进房;④1 MiB 响应上限与 name-only 分区挂卡片为 v2 化适配。
- 验证:`dart analyze` No issues;`dart test test/platforms/soop` **54 项全绿**(状态门/RESULT 分支/合并路径/编解码往返/错误映射/能力接线/会话时序)。

## twitcasting 明细(2026-10-15,后台代理移植)
整站从 `live_core/sites/twitcasting` + `live_danmaku/sites/twitcasting.dart` 迁到 `platforms/twitcasting/`(后台代理按统一模板与交付门执行,我审查后注册)。**无新依赖**。
- 能力六个+link_resolver 全注册:room / area(首页 tabs)/ discovery(top/category)/ search(网站搜索页 HTML 解析)/ playback / danmaku / link_resolver(channelName/channelFromUri 前缀 c:/g:/f:/ig:)。
- 数据面:30s 快照本地分页(快照上限 16),`_streams` 按频道保留含离线数据(REG-001),streamserver 签名地址、roomDetail 合并、qualities/lines(lineLabel=CDN host、format=hls declared、无 lease)。
- 弹幕:eventpubsuburl 每次握手先 POST 换签名 WS URL、客户端不发帧(开箱即 join)、30s 看门狗、退避 1s 递增、8 次重连预算终止上报、失败文本去签名;comment/gift 解码(礼物后附 `<id>:words` 词行)。
- **代理的适配与延后项(记档)**:①follow-card 刷新/getLiveStatus/录制 entry/播放恢复/CancellableSearch/getCategories 分页无 v2 面;②v2 LiveRequest 无 per-request followRedirects → 3xx→notFound 门保留但默认跟随的传输下未知频道落 twitter:creator 门(apiChanged);③v3 `TwitcastingGift.paid` 无 v2 字段丢弃;④restricted(room) 检查无 v2 入口;⑤会话无 join 预算/客户端心跳(faithful 参考);⑥快照分页 hasMore 为新造语义。
- 验证:`dart analyze` No issues;`dart test test/platforms/twitcasting` **63 项全绿**。

## missevan 明细(2026-10-15,后台代理接手补齐)
整站从 `live_core/sites/missevan` + `live_danmaku/sites/missevan.dart` 迁到 `platforms/missevan/`(第一个代理写了大部分 lib 后被配额中断,第二个代理接手补齐 3 个缺文件并修绿,我审查后注册)。**无新依赖**(brotli 用 common/codec 的 es_compression 包装,FFI 在测试环境已实测可用)。
- 能力七个全注册:room / area(meta/data 的 tabs 按 namespace catalog/list/tag 分组为三类,personal 路由剔除,坏 tab 单跳、无可用 tab apiChanged)/ discovery(推荐 open/list)/ search(chatroom/search;房间号直查、长关键词按 rune 截断、控制字符拒绝)/ playback / danmaku / link_resolver(fm.missevan.com/live/{id} 无请求规范化);`MissevanFailure → toLiveSiteError('missevan')`(code 500030004/HTTP404 → notFound;401/403 折 rateLimit;transient 仅 network/rateLimited)。
- 数据面(匿名):`{code, info}` 信封 + 1 MiB 门;列表 echo 门(p/pagesize/maxpage/count 全对上,越界页必须空),推广行保位、目录去重,离线行不进目录;房间 = live/{id}(creator 合并头像/简介、attention_count 粉丝、status.open 1/0 严格、open_time 毫秒合理窗、占位灰猫封面留空、拉流地址必须 *.bilivideo.com 同类型且 ≤1 个十进制 expires,坏地址单条剔除、直播双无 → apiChanged;离线房旧地址忽略 REG-004);单画质 原画(qn=10000),FLV 主线 HLS 备线(存量 hls/flv id 归一),租约 = expires 提前 1 分钟,HLS 过期断流(requiresReconnect)。
- 弹幕(13-2):guest session(/api/user/info 取 FM_SESS cookie,3 试可注入间隔,缓存复用)→ wss(join uuid 确认,重连带 reconnect:1,5s join 超时);心跳 30s 文本 ❤️(服务端回显)、静默 90s 换线;拒答 → 换新 session+socket(≤3 次)后终止;8 次重连预算;消息:brotli 帧(首字节 1,4 字节头)与明文 JSON 双路;chat/room statistics(真实收听数)/付费提问 superChat/message_clear 撤回/noble 贵族(开通/续费文案)/pk 与 global_pk 与 team_pk(中文文案表 + raid 进度)/gift(钻石折 gold、免费折 free,luckyGift 无 v2 字段丢弃记档,combo id/num)。
- **代理的适配与延后项(记档)**:①握手 401/403 续期简化——SocketChannel 接缝看不到状态码,cookie 仅在 join 被拒时强制换新,socket 打开失败沿用缓存 cookie 走重连预算;②luckyGift 嵌套丢弃(v2 LiveGift 无字段);③session 重试间隔可注入(测试 Duration.zero)。
- 验证:`dart analyze lib/src/platforms/missevan test/platforms/missevan` No issues;`dart test test/platforms/missevan` **69 项全绿**(信封门/目录/分页 echo/房间行/detail/拉流校验/租约/legacy id/链接矩阵/七能力接线;弹幕 endpoint/session/join/uuid、明文+真实 brotli 编码帧、负例 4 种、全部消息类型、会话生命周期)。

## pandalive 明细(2026-10-15,后台代理接手补齐)
整站从 `live_core/sites/pandalive` + `live_danmaku/sites/pandalive.dart` 迁到 `platforms/pandalive/`(第一个代理写了 api/parsers 后被配额中断,第二个代理修 16 错 + 补齐全部,我审查后注册)。**无新依赖**。
- 能力六个+link_resolver 全注册:room / area(参考的分区结构)/ discovery / search(精确 id 提前/补查、NotFound 吞掉、bj+live 半页照参考)/ playback / link_resolver;`PandaliveFailure → toLiveSiteError('pandalive')`。
- 数据面:profileCard 语义修复(对外主播 media 回退离线房间与参考不符,改为返回 null=参考语义);会话 kilakila 形态(SocketChannel + site.connect + 注入 Timer),重连预算 8、拒绝预算 3、join 8s、心跳 25s、看门狗 90s、token 续期按 ttl-60s(ttl 短则减半),FakeTimers 驱动。
- **适配与延后项(记档)**:①LiveGiftUnit 无 heart → 하트 후원(红心赞助)记 `other`(unitPrice 1.0),kind=tip;②v2 无 recovery 能力 → kept variants 过期(variantRefresh 30min)后 getLines 自动重进房间换新 token(测试覆盖);③搜索 hasMore 为 null(平台不告知);④搜索去掉参考中不可测的 cancel 分支。
- 验证:`dart analyze` No issues;`dart test test/platforms/pandalive` **56 项全绿**(answers/readers、links、cards/pages、member/play、room entry、streams、chat protocol、comment session、adapter wiring)。

## showroom 明细(2026-10-15,后台代理移植)
整站从 `live_core/sites/showroom` + `live_danmaku/sites/showroom.dart`(277 行轻弹幕)迁到 `platforms/showroom/`(后台代理按统一模板与交付门执行,我审查后注册)。**无新依赖**。
- 能力七项全注册(room/area/discovery/search/playback/danmaku/link_resolver);LiveHot/Anchor 参考 没有 → 注册 null。`ShowroomFailure → toLiveSiteError('showroom')`。
- 数据面:onlives 快照(30s 共享/拉刷新/超时再取)→ genre 分区,推荐 = Popularity genre,搜索 = 快照过滤;房间入口 status → profile + live_info → streaming_url;播放 hls 分层(原画/中画质/低画质 + 自动 master 置尾、无租约);礼物表缓存(30min/失败重试 5min/16 房);链接解析(profile 页/键页/纯数字键 → room/status)。
- 弹幕:SUB/PING/ACK + MSG 帧(聊天+礼物,目录表定价、gt=2 免费、默认图标、字节帧);silence 180s、重连预算 8 次、open 即 joined(服务器不确认,无 join 定时器——照参考)。
- **适配与延后项(记档)**:①礼物表未用 Isolate.run(参考有;包内其他平台均内联,且 isolate 不 web 安全);②playback 按 roomId 无 detail 对象 → 入口记 ShowroomStreamData(offline 标记复刻免请求路径);③目录页固定 30 行/页、推荐与搜索按 pageSize 切片(≤100)照参考;④卡片/详情 area 由 genreName 升级为 LiveArea 对象(参考本就校验 genre_id);⑤未实现(参考也没有):webRTC 等非 hls 类型、t=5/8/18/101/104 等其余 MSG 种类、premium 付费房(无样本)。
- 验证:`dart analyze` No issues;`dart test test/platforms/showroom` **57 项全绿**(状态门/逐行容错/编解码往返含定价/错误分支/七能力接线/快照复用/礼物表缓存/会话生命周期)。

## picarto 明细(2026-10-15,后台代理移植)
整站从 `live_core/sites/picarto` + `live_danmaku/sites/picarto.dart` 迁到 `platforms/picarto/`(后台代理按统一模板与交付门执行,我审查后注册)。**无新依赖**。
- 能力七项全注册(room/area/discovery/search/playback/danmaku/link_resolver);LiveHot/Anchor/WebSearch 参考没有 → 注册 null。`PicartoFailure → toLiveSiteError('picarto')`(7 类,401/403 折 rateLimit)。
- 数据面:双 API host;catalog(languages-categories,公开目录区在前)、explore 分页(30/页,clamp 1–60)、分类过滤、searchProfiles(count 不读、空页收尾);房间入口 detail + HLS master + 公共 API last_live + 弹幕 handle;HLS master 多质量(高度优先排序,外挂音频/媒体 playlist → 单一"自动");频道名规则与 roomIdFromUrl 白名单。
- 弹幕:token GraphQL 解析、wss endpoint、50s 心跳、JWT_TOKEN 拒识(预算 3 次内换 token 重开、被任何非拒识帧证明后清零)、chat/小费超聊(LiveSuperChatMessage + SuperChatPrice currency 'Kudos',名字颜色 k → MessageSender.nameColor,弃 3.x 的 SUPER_CHAT_MESSAGE 占位文本)/system/raid/订阅/rm/cm/观众帧全解码。**无礼物事件(参考亦无)**,无 LiveGift 产出。
- **适配与延后项(记档)**:①follow 刷新(v1 getRoomDetailForRefresh)无 v2 能力面 → getRoom 即入口;②恢复播放无 recovery API → getLines 重入房间(重新 detail+master),请求质量不在新 playlist 时回落最佳质量(注释说明);③3.x `LivePlayQuality.data`(变体 URL 列表)v2 无此字段 → URL 移入 `PicartoStreamData.qualities[i].urls` 由 site 持有;④token 不可用按重连预算重试(参考 runtime 语义),长会话清零规则已注释。
- 验证:`dart analyze` No issues;`dart test test/platforms/picarto` **58 项全绿**(page echo/last_page/坏行容忍/edge 与 stream_name 白名单/质量 id 编解码往返/错误分支 401/403/404/429/5xx/七能力接线/FakeTimers 会话:join 预算、150s 看门狗、拒识换 token、重连预算)。

## looklive 明细(2026-10-15,后台代理移植+修绿代理收尾)
整站从 `live_core/sites/looklive` + `live_danmaku/sites/looklive.dart` 迁到 `platforms/looklive/`(第一代理写完 lib 后配额中断;修绿代理接手:修 5 处测试编译错 + 逐断言对参考修 27 处 + 1 处实现侧修改,我审查后注册)。**无新依赖**。
- 能力七项全注册(room/area/discovery/search/playback/danmaku/link_resolver)。
- **修绿代理的实现侧修改**:discovery/area 两 provider 原先忽略 request.pageSize 返回整页 → 改为调 `site.recommend(page, pageSize)` 按页截断(参考 getRecommendRooms 明确 cut)。其余 27 个失败全判测试侧错误(fixture 缺口:socket.io 握手 GET 无应答、合并页缺 items、`roomInfo.id` 位置错、聊天用户缺 fanClub、短键 custom 缺 bizName、emoji 消息须有 content.user;预期与参考相反:秒级时间戳按毫秒读、data 非对象是 apiChanged、房号不合格卡片计入 unreadable、分帧 break 结束全解析、16 位超 2^53 id 合法、无 giftName 礼物仍产出、null quality 返回默认线路、v2 room 须 withData 才带 handle、掉线 socket 下次 connect 才关闭等)。
- 验证:`dart analyze` No issues;`dart test test/platforms/looklive` **71 项全绿**。

## liveme 明细(2026-10-15,后台代理移植)
整站从 `live_core/sites/liveme` + `live_danmaku/sites/liveme.dart` 迁到 `platforms/liveme/`(后台代理按统一模板执行,我审查后注册)。**无新依赖**。**参考无分类无弹幕**:LiveAreaProvider 与 LiveDanmakuProvider 注册 null,未建 danmaku 目录。
- 能力五个注册:room / discovery(featurelist 目录/推荐)/ search(searchKeyword+短号/房间/主播/分享链接直查)/ playback / link_resolver。`LivemeFailure → toLiveSiteError('liveme')`(HTTP 400→apiChanged、404→notFound、420/429→rateLimited;business 400/404→notFound、"user not exist"→notFound、≥500→network)。
- 数据面:房间入口并行三请求(mapping → getinfo ∥ 签名 queryinfosimple);web 端 `lm_s_*` + `lm-s-sign` md5 签名(random 可注入);流数据缓存上限 64;画质 source 原画/smooth 流畅 + `flv#2` 备线(FLV→HLS、https 升级、CDN host 白名单、legacy 画质 id 迁移、无 lease——URL 对整场有效);ispvt/livebptype 7/hot_label_v2 限制;链接 liveme.com 房间页免请求、主播/分享页一请求,locale 段与任意端口兼容。
- **代理的适配与延后项(记档)**:①v2 无 LiveDirectoryNotice → 目录范围提示弃置,房间级 chatNotice 保留;②搜索无 CancelToken → 仅保留"页 1 才直查/未知房得空"语义;③无恢复入口 → 复播重解析复用缓存流数据;④refresh/record 专用入口统一走 getRoom(media:true),搜索直查 media:false;⑤transport 无 followRedirects → 重定向落 HTML 经 envelope 门折 apiChanged;⑥likenum 严格校验保留在解析层但 v2 房间模型无点赞字段不透出。
- 验证:`dart analyze` No issues;`dart test test/platforms/liveme` **45 项全绿**。

## xiaohongshu 明细(2026-10-15,后台代理移植)
整站从 `live_core/sites/xiaohongshu` 迁到 `platforms/xiaohongshu/`(后台代理按统一模板执行,我审查后注册)。**无新依赖、无弹幕**(LiveDanmakuProvider 与 LiveAreaProvider 注册 null——参考无分类;未建 danmaku 目录)。
- 能力五个注册:room(getRooms 恒空页——平台无列表 API)/ discovery(恒空)/ search(仅 rooms;id/分享页/深链 xhsdiscover:///短链精确查找)/ playback / link_resolver。`XiaohongshuFailure → toLiveSiteError`(needsLogin→authentication、regionBlocked→contentUnavailable、riskControl→rateLimit——沿用 bilibili/kilakila 先例)。
- 数据面:`window.__INITIAL_STATE__` 水合解析(唯一 script 定位、裸 undefined→null 扫描器、2MiB 门);pageStatus/roomId 一致性/status×liveStatus/字符串型字段;拉流 pullConfig 行规则(剔行、32 行上限、xhscdn 地址契约)、单组画质 FLV 先于 HLS、h264 先于 h265、行标签 #N/:hevc、formatSource inferred(kilakila 先例);链接 canonical/dynpath/hina + 深链 xhsdiscover:// + 短链一次 GET 跟随(从 Location 头或落地页水合态取房号,douyin v2 先例);分享文字批量提取 shareTextRoomIds 已移植有测试,未接能力(v2 无 share-text 钩子,记档)。
- **代理的适配与延后项(记档)**:①目录/推荐公告文案(3.x directoryNoticeKey)无处挂载 → 延后;②短链跟随改为一次 GET 由传输层跟随(3.x 逐跳校验弃用,对最终落地仍校验);③refresh/record/getLiveStatus 无对应能力(单一 getRoom)。
- 验证:`dart analyze` No issues;`dart test test/platforms/xiaohongshu` **87 项全绿**(水合解析严格性/限制分支/地址契约剔行/链接正反例/HTTP 状态映射/短链跟随/能力接线/错误边界)。

## cc 明细(2026-10-15,后台代理接手补齐)
整站从 `live_core/sites/cc` 迁到 `platforms/cc/`(接手上一代理的 api 半成品,补齐 parser/link/site/capabilities/测试;我审查后注册)。**无新依赖、无弹幕**(参考无;LiveDanmakuProvider 未注册,Hot/Anchor/WebSearch 亦 null)。
- 能力六个注册:room / area / discovery / search / playback / link_resolver。`CcFailure → toLiveSiteError('cc')`(410/404→contentUnavailable/notFound;401/403 折 rateLimit)。
- 数据面:目录(移动端 gamecategory + Dashen 官方房间/专题)、分区/推荐/搜索三列表、`activitylives`→`live/channel` 房间链路、无频道房间的 `__NEXT_DATA__` 房间页、`video_play_url` tiers/CDN/lines、3.x 档位表 fallback、`auth_key` lease、【重播】→ replay;链接三种(cc.163.com、h5.cc.163.com/cc/、ds.163.com/glive)。
- **适配与延后项(记档)**:①受众数字改 `int?`,followers 入 `LiveAnchor.followerCount`;②目录由 LiveCategory 树改 LiveArea 扁平(parentAreaId/Name);③`LivePlayQuality.data` 不存在 → `_legacy` 标记 + CcRoomData 区分 fallback 线路,quality 缺 `vbrname_sel` 用 isPlaybackUnconfirmed;④推荐页 pageSize 上限截 1000;⑤entry/refresh/status 三档深度与 `wapcc/recommendbyccid` 存在性检查无 v2 面,仅 entry 深度。
- 验证:`dart analyze` No issues;`dart test test/platforms/cc` **37 项全绿**(状态门/4MiB/cuteid/回显校验/行数上限/坏行跳过/错误分支/fallback 链/能力接线)。

## inke 明细(2026-10-15,后台代理接手补齐)
整站从 `live_core/sites/inke` 迁到 `platforms/inke/`(接手上一代理的 1 个 api 文件,补齐其余 12 个 lib + 测试;我审查后注册)。**无新依赖、无弹幕**(LiveDanmakuProvider 未注册,Hot 等亦 null)。
- 能力六个注册:room / area(官网 top+channels `Live_channel_pc`)/ discovery(App 热榜 `simpleall`)/ search(uid/链接精确定位 + 三列表昵称过滤,热榜失败可容忍;limit 10000/60/100 原样拒绝)/ playback / link_resolver(web 房间页+mlive 分享页规范化,保留数字 broadcast id)。`InkeFailure → toLiveSiteError('inke')`(riskControl 折 rateLimit)。
- 数据面:房间 = `live_share_pc` + `now_publish` 合并(占位标题、标题/封面回退、online/heat 观众语义、hasLine→restriction);播放 = FLV(H.264)+ 原画(HEVC/codecInfo=8192)、"优先 H.264"排序、30s answerReuse、App 无线时按 top→hot→channel 顺序 showcase 兜底;`wsABStime` 租约(提前 min(1/4 lifetime,10min))。
- **代理的适配与延后项(记档)**:①playback 按 roomId → `_streams` 会话表存条目 stream handle(kilakila 同款,64 条上限);②getLiveStatus/刷新/录制 resolver、LiveDirectoryNotice、搜索分页策略接口无 v2 面;③列表为有限 showcase,page≥2 恒空不请求,省去 30s snapshot 复用;④v2 LiveRequest 无 followRedirects(参考为不跟随);⑤freezed 4 `copyWith` 非空字段不可传 null → withBroadcast 整体重建 content/broadcast。
- 验证:`dart analyze` No issues;`dart test test/platforms/inke` **48 项全绿**(信封门/showcase/hot/detail/now_publish 解析、pull URL 校验/租约/qualities/lines、链接解析、错误分支、能力接线)。

## 环境缺口
无。此前 `packages/live_playback` 以 `path:` 依赖工作区外的 `D:\media_core` 导致整仓 `dart pub get` 解析失败、`dart test` 跑不起来;2026-10-14 已把 `media_core` / `media_core_danmaku` / `media_core_mediasession` 改为 pub git 源(`github.com/liuchuancong/media_core`),仓库根 `flutter pub get` 即可完整解析,交付门的 test 步骤不再需要人工补 media_core 或造桩。
