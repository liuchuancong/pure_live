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
| iptv | ✅(seam) | 基线既有,跨包 seam,非典型直播站 |
| huya 虎牙 | ⬜ | 下一站候选(与 douyu 同为 WS+签名,最宜复用其形态) |
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
