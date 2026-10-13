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
| iptv | ✅(seam) | 基线既有,跨包 seam,非典型直播站 |
| kuaishou 快手 | ⬜ | 下一站候选 |
| douyin 抖音 | ⬜ | protobuf PushFrame + X-Bogus 签名 |
| bilibili B站 | ⬜ | WS + protobuf,房间/分区/弹幕齐 |
| kuaishou 快手 | ⬜ | |
| weibo 微博 | ⬜ | 快照门控站(无 cursor 分页) |
| acfun / bigo / chzzk / fc2live / jdlive / kick / kilakila / kugoulive / looklive / missevan / niconico / pandalive / picarto / seventeenlive / showroom / sixroom / soop / steambroadcast / twitcasting / twitch / youtube / yy | ⬜ | 其余含弹幕站,一站一站来 |
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

## 环境缺口(影响交付门,重要)
本机工作区 **无法 `dart pub get`**:`packages/live_playback` 依赖 `media_core` 路径 `../../../../media_core/packages/media_core`(即 `D:\media_core\packages\media_core`),该外部工作区在本机不存在,导致整个 workspace 解析失败、`dart test` 直接跑不起来(与本次站点代码无关)。为跑本包测试,曾临时在 `D:\media_core` 造桩再删。要长期跑测试门,需把真实 `media_core` 工作区放到 `D:\media_core`(或在 live_playback 里改成实际存在的路径/移除该 member)。在此之前,"交付门 = dart analyze + dart test" 中的 test 步骤依赖人工补 media_core。
