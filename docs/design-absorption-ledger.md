# 设计思路吸收台账（参考仓 E:/study/PureLive → v2）

2026-11-06 五代理分区扫描的结论全部立项。每项含参考实现路径与 v2 落点；状态 ⬜ 未做 / 🟡 进行中 / ✅ 已吸收。
规则：主会话串行提交（pathspec 精确、英语叙述、commit 前必 analyze）；media_core 侧遵守 fast-iteration（无注释/无测试/用户自测，analyze+commit 必做）；另一会话 WIP 文件不碰。

## W0 立即修
- ✅ 代理 DIRECT 绕过（5e193e4df）：`proxy_http_overrides.dart` 的 findProxy 不看 uri，LAN 同步配对/DLNA SOAP 全被送代理。参考 `live_net/src/io_http.dart:30`。修法=findProxy 按 uri 判断回环/私网/链路本地/`.local` → 'DIRECT'，规则放 live_net。

## W1 小而高价值
- ✅ mpv 有界直播缓冲（e90544d8f，落 app balanced 预设）：cache-secs 6 / demuxer-readahead 2s / 缓存 32MiB、缓冲 4MiB 上限。参考 `live_player/src/mpv_options.dart:152-161`。落 media_core media_kit 适配器 engine options。
- ✅ 启动失败自救页（62c0ad088；存储失败保留优雅降级语义）：替身 UI+重试+导出日志+预置系统语言翻译；存储失败不再吞掉继续跑。参考 `app/launch_failure.dart:16`。
- ✅ 备份 .part 原子写（1db04bb46；快照式命名无覆盖故 .previous 不需要）：.part→旧文件改名 .previous→part 转正，失败回滚；启动先恢复中断。参考 `live_store/src/backup/backup_service.dart:168-204`。修 `backup_actions.dart:149` 直接 writeAsString。
- ✅ 历史按所见删除（8d2a07099）：clear(shown) 事务内比对 lastWatchedAt，变了的保留。参考 `live_store/src/rooms.dart:189-199`。修 `history_repository.dart:65` 裸 deleteAll。

## W2 数据面
- ✅ 还原前差异预览+三入口互斥锁（b198bbfde；WebDAV 入口由 6232512f8 补齐）：对每部分按身份键集合差（新增/删除/设置项变化数），全入口共用对话框；跨入口互斥锁。参考 `shared/backup/backup_data.dart:253-367`、`backup_service.dart:158`。
- ✅ WebDAV 定时自动备份（6232512f8；还原进行中跳过 tick）：目标 JSON 指纹、失败 15min→6h 退避、前缀保留 N 份、只前台调度。参考 `features/web_dav/web_dav_auto_backup.dart`。
- ✅ 关注/历史回写（85bce4a96 关注整批/冷却/unknown/重绑/详情回填；1acc536b4 历史整批+工作池）：房间详情合并回关注卡、整批一次写回、失败置 unknown+5min 冷却、bindToFollow 校 id。参考 `room_controller.dart:840-844`、`follow_refresher.dart:32-117`。

## W3 房间体验
- ✅ ChatFeed（e0748b332）：每帧批通知+本地发送即刷、礼物配额 150/500+每秒 10 行贵礼豁免、combo replace、removalsSince、RoomChatListMemory 保滚动/暂停/未读标。参考 `chat_feed.dart:132-338`。
- ✅ 双向屏蔽（e0748b332）：屏蔽即从列表与飞行层移除（gift 航线句含），本地行豁免；计数语义不变。参考 `room_controller.dart:1791-1814`。
- ✅ RoomPanelKind 面板总线（f0e856116）：枚举现覆盖 details/sleepTimer 两常驻侧板（对话框带临时参数保持直开，总线文件注明取舍）；Scope 回退 sheet；互斥=routeSettings 名 popUntil。后续录制/弹幕设置面板=加枚举值+一 case。参考 `shared/panels/room_panel.dart`。
- ✅ SuperChat 同事件判定（575936a0a）：有 id 按 id；无 id 轮询榜单带 hasEstimatedStartTime 按展示窗口重叠匹配（专用方法不进 ==）。参考 `live_message.dart:491-544`。修 `room_super_chats.dart:63` 全字段 Set。
- ✅ 观众数分层排序键（575936a0a；B 站 1 值回退进 mergedWith 与进房）：档位 3 在线/2 可在线/1 热度/0 无，identityKey 稳定兜底；B 站详情=1 且前值≥1000 回退旧值。参考 `audience.dart:310-345`、`live_room.dart:506-575`。

## W4 播放健壮性（media_core）
- ✅ 恢复阶梯预算/记忆/节奏：刷新→换线→重建播放器→降软解→延时重试轮（750ms/2s），预算每轮重置、稳定 30s 恢复；平台明确拒绝直接终止。参考 `session.dart:1448-1622`、`fallback.dart:4-54`。落 media_core recovery_ladder+sweep e514db6。
- ✅ 位置推进=健康：互证结束缓冲（位置墙钟+2s 或 1s 内 10 帧）+静止 4s 提示档 positionStallNotice、15s 判死、恢复计数经 onRecoveryChanged 公开、30s 稳定清零。参考 `session.dart:1129-1320`。落 media_core sweep+watchdog_arms e514db6。app 接线待做：room 订阅 onRecoveryChanged 渲染"重连(第 N 次)"。
- ✅ 原生日志诊断门：非故障白名单、打开期扣留到新源起播、1.2s 撤销窗、2s 去重、分类前剥 URL。参考 `diagnostics.dart`。落 media_core media_kit 适配层 074981b。
- ✅ 有界释放：stop/dispose 限时 5s、在途释放≥2 拒绝新建、open 超时退役引擎。参考 `session.dart:583-792`。落 player_kernel 074981b；闲置保留 45s v2 引擎池已有等价。
- ✅ 断网态机：传输层无应答=断网不切线不扣预算，2s 探测、20s 宽限发布 networkUnavailable，恢复即新预算重开原线；断网期引擎错误/停滞忽略。参考 `session.dart:1632-1735`。落 media_core sweep e514db6。app 接线缺口：room lineResolver 现把网络类错误 fold 成空列表，应让网络类上抛、只留业务拒绝。

## W5 多画面与录制 UX
- 🟡 多画面预算（c6827016a）：✅ 小格最低清晰度/晋升换质（tap 升格+原大格回落）/进页"恢复上次？"提议制（拒绝=清文档）；⬜ 隐藏格停解码（v2 各布局全可见无消费者）与单弹幕连接（v2 多画面尚无弹幕）。参考 `multiview_controller.dart:857-871`、`wall.dart:85-101`。
- ⬜ AutoRoomSwitch：只认真实状态、先刷新当前房两次、候选新鲜详情确认+仍需关注中、30s 健康复位、组内同步预约防撞。参考 `shared/rooms/auto_room_switch.dart`。
- ✅ 录制显示态单表（938f619c2）：RecordingDisplayState 六态纯函数（word/tone/sortRank/showsOnBar），bar 与录制中心共用；v2 无任务槽位模型故 queued/preparing/深链不适用。参考 `shared/record/record_state.dart`。

## W6 录制吸收（media_core）
- 🟡 录制输入本地中继：渐进流（FLV/TS）可经 RecordingInputRelay 走回环字节管道，停止=关上游连接→FFmpeg EOF 自收尾→5s 排空窗才强杀；默认关（FfmpegRecordConfig.inputRelay），HLS 与中继起不来的回退直连。参考 `live_record/src/capture.dart:120-127`。落 media_core 737413b，150 测全绿。未做：坏尾包"尾部截断"记法（尾部截断语义已由 _secondPass 留尾段+失败分类承担）；HLS 保留窗口中继=W6 另一条；app 侧录制引擎尚未开此开关。
- ✅ 分类退避：进程遗言分类器（401/403/404=需新签名、EOF/重置=地址到期、拒连/超时/解析失败=纯网络）；需新签名走 2s→15s 快车道且预算翻倍，纯网络失败不计次。参考 `policy.dart:19-46`、`recorder.dart:494-516`。落 media_core recording_failure_shape+backend 尾日志 2114ade，5 测，录制包 150 测全绿。
- ✅ refreshAt 前 5s 预取新签名地址，快速恢复直接用。参考 `recorder.dart:1022-1061`。落 app 录制引擎：会话挂 leaseTimer/leasedFromUrl/prefetched，refreshTake 先消费预取（同源+租约未过期才收），预取自身带下一轮时钟。
- ✅ HLS 保留窗口+并发预下载：录制侧 HLS 捕获走与渐进流同一 inputRelay 开关的保留窗口回环中继（media_core 98c45cb）：中继按上游滚出仍为读者保留 48 段/96MiB（4 路并发预取、单段 32MiB 不持有、空闲 12 轮即停）、段 URL 重写回环、KEY/MAP 连续合并+URI 绝对化、LL-HLS 粒度标签丢弃、master 透传+warning；上游滚走且无人取走的段=缺口上报（HlsCoverageGap 回调+计数+日志，不默默隐藏）；stop=冻结窗口补 EXT-X-ENDLIST 让 FFmpeg 排空自收尾（5s 窗口外仍 kill），起不来只丢干净停。参考 `live_media/src/relay/hls_window.dart`。未搬：加密段密钥下载策略/Set-Cookie 会话/query 令牌传播/Bigo 式段还原器（录制地址是预签名完整 URL 用不上）；master 形态 clean-end 退化为 kill；FFmpeg 侧"skipping N segments"日志行未进失败形状。
- 🟡 完整性判定：合并读自身日志——trailer 写失败/ muxer 拒包=输出不可信，不改名不提交；失败合并一遍重试留尾段（干净前缀提交，被切段留旁边）。参考 `ffmpeg.dart:332-369`、`merge.dart:93-110`。落 media_core recording_remuxer 974ac38，150 测全绿。未做 -xerror（v2 无它的两遍回退语义配套，加了会让良性输入包损坏丢整个输出）。

## W7 传输吸收（media_core）
- 🟡 FLV 关键帧拼接续期：字节级决策层全量移植（FlvTagProbe/Policy 关键帧对齐+平移计算/Plan 切换窗口/Timeline 输出台账，320 行零 I/O）。参考 `flv_splicer.dart:144-496`。落 media_core_ingest 11a49b3。评估结论：播放路径无缝（mpv 内部拉流，Dart 无字节接点）；缺的桥=media_core_ingest 的 FLV loopback 中继 I/O 层约 500 行，决策层已备好，待立项。
- 🟡 HLS 中继内换址：LoopbackIngestRelay.renewAddress（根 manifest 改指新址、玩家回环地址不变、已改写子列表照常解析）落 media_core_ingest 33ac392；FfmpegIngestRelay 进程内换址落 0b392f8（同目录第二轮 FFmpeg：先证明新址发布 join 清单、再停旧轮并把 join 服务在玩家已知的 index.m3u8 名下，失败不动旧轮可重试，自灭轮可复活；DASH 合并双输入不续期；join 是新编码轮时间戳重启=已记档的接缝）。参考 `hls_relay.dart:456-512`、`session.dart:1355-1401`。余：app 侧 refreshAt 接线（待首个声明 expiringUrl 的站点）。

## W8 live_sites 基座
- ✅ 弹幕连接基座：Run 令牌按代际失效、sealed 状态事件（连接中/握手完成/已加入/重连中/耗尽）、消息单出口清洗不可见字符——基座+14 测；18 个 session 全量迁移完（15 常规两批 ed078137d+6a225fa65，最后 3 个特殊形态 dc9e4b8e3：niconico 轮询循环的代际参数树换成 run、xiaohongshu 保留 socket-epoch 双记账于 run 之内、seventeenlive 每-socket 代际与 chzzk/kick 同构直换；全程 2210 测零断言改动）。参考 `live_danmaku/src/connection_base.dart:16-160`。
- 🟡 Socket 模板：多端点轮换（每轮等待+1 步封顶 6、耗尽才上报平台接管）已落公共 DanmakuSocket（3 测，单端点行为不变）。参考 `socket_connection.dart:122-396`。余项=入房超时+握手失败续签钩子：迁移已让会话经 run 上报 joined/handshakeDone（states 流为新增面），钩子本身待加。
- ⬜ 可取消能力：CancelToken 进能力接口+DiscoveryScope 持临时会话清理；不支持的平台调用前后检查。参考 `live_site.dart:420-607`。
- 🟡 Link 会话预算：app 侧已落 sharedHttpUrls 全套（中文标点截断/裸域名补 https/prose host 尾点豁免/签名不重编码，LinkText 6 测）+整次解析 12s 硬顶（toolbox 控制器逐站查预算）。参考 `links.dart:56-317`。余项=ShortLinkSession（8 URL 预算/共享取消/redirect 数据跨站递归）：v2 的 LiveLinkResolver 各持自己传输、20+ 个 capability 签名都要加 session 参，等解析器接口重设计一并做。
- ⬜ 屏蔽三维：等级下限（null=未知永不屏蔽）、只显示彩色（r==g==b=灰）、协议标注疑似机器人。参考 `message_filter.dart:174-210`、`live_message.dart:376-385`。

## W9 测试面
- 🟡 ReplayHttp 抓包回放传输：✅ 传输+单测 b7fdb3aa3；✅ 样板迁移 3/40（kugoulive/pandalive/liveme，2ca375867，样本在 packages/live_sites/test/fixtures/）；剩 37 个 _FakeHttp 后续批——注意：签名字段要经 http.requests 单独断言、未命中可能被站点包成 Left 误通过、header 不参与匹配（twitch 类保留手写 fake 或加 _Sequenced 工具）、baidulive 1912 行 fake 等于重写留最后。

## W10 大特性
- ⬜ 回放抽象：ArchivePlaybackController 五平台统一面+decoder 退休握手（await entering/retirement）+路由表解耦。参考 `shared/rooms/archive_playback.dart`、`archive_navigation.dart`。
- ⬜ 局域网遥控：HTML 遥控页+6 位配对码→12h Bearer+targetId 界面修订号 ETag+Origin/Host 校验+命令白名单。更新 lan-sync spec 非目标条目。参考 `shared/remote/playback_remote.dart:168-513`。
- ⬜ PhoneBridge：TV 难输入转手机，一次性 64 位随机路径即凭证、1s 自动关、maybeOf 无能力隐藏按钮。注意不放初值敏感数据。参考 `shared/phone_bridge.dart`、`tv/phone/*`。
- ⬜ 开播提醒 WorkManager：app/后台共用小 JSON（原子写+双方合并去重）、后台 check 不开库不持 cookie。需新增 workmanager 依赖。参考 `favorite/live_alert_watch.dart`。
- ⬜ 房间身份迁移框架：存储层定义迁移规则+解析签名，app 注入适配器，刷新前执行、分组 moveRoom 跟迁、重复关注合并。参考 `legacy_import.dart:350-390`。
- ✅ 音乐音频缓存（d2ea031f1）：CachedTrackSource 装饰器挂在 MusicSourceRegistry 上（resolve 先问磁盘、命中 Uri.file、未命中边播边下 .part→commit、LRU 上限设置行+清空钮、传输走 LiveHttp 吃代理策略）。参考 `live_vod/src/music/audio_cache.dart`。
- ⬜ 后台引导 Dart 侧重移植：Kotlin BackgroundGuideChannel.kt 还在，664 行 ROM 分型页从 659089725 恢复适配。
- ⬜ 屏幕镜像（末）：WebRTC 点对点+本地 RFC 8489 STUN 子集+会话绑定媒体槽。需 flutter_webrtc 依赖，做遥控后二期。参考 `shared/remote/screen_share.dart`。

## W11 UI 观感
- ✅ OnVideoColors 全套角色（22 个在用语义角色+shade 渐变工厂）+InkOnColor WCAG 比值选墨（darkInkOn 双比值对比）。参考 `live_colors.dart:9,303`。落 shared/player/on_video_colors.dart，45 处字面量全收编（room 播放面/multiview/hongguo/iptv/vod/media_preview/录制指示），chat 名墨换 darkInkOn；数值沿用房间稿定案只改名不改色。
- ✅ WindowClassScope：约束级尺寸类 InheritedWidget（类变化才通知，无界边回落窗口）+DisplayHinge 折叠避让（find/maybeOf/sideOf/splitRow）+高度 compact 档（短区 48）。参考 `window_layout.dart:22,68`。落 shared/layout/window_class.dart（宽类沿用 app 的 600/960 口径，高类 480/900），壳层包内容区+房间条接高度档，7 测。
- ✅ RoomCard 纯数据入参：app 层映射、组件不 watch provider。参考 `live_ui/src/widgets/room_card.dart:25`。落 `RoomCardView`（纯渲染，3 测裸跑）+ `RoomCard` 壳只做 provider 解析，8 处调用方不变。

## 已核实不必吸收
错误 sealed 体系/清晰度实际下发/礼物连击合并/房间稀疏合并/礼物档位/clock-v1 日志/.partial/配对协议（v2 更强）/DLNA（cast_dlna 更完整）/跨进程存储同步（模型不同各自解决）/AppIcons 按用途命名（方向不同）/danmaku_overlay（flame_barrage 已等价）。
