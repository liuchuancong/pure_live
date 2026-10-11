# pure_live packages 迁移技术方案（v2）

> 状态：方案已定，实施开始。第一片已完成：workspace 基建（根 pubspec / lint / .gitignore）+
> `live_net` 的 LiveHttp 契约与 `DioLiveHttp`（dio ^5 传输、按 ProxyRoute 池化、分型错误映射、
> 流式 open/中途 close、便捷调用层），分析器零问题、22 个单测全绿（loopback 服务器，不碰真实网络）。
> 范围：`pure_live-master` 的 `packages/`（11 包）向本仓库的迁移、细分与现代化改造。
> 播放器部分（`live_player` 及 media_kit fork）**不迁移**，播放编排统一改用 `F:\media_core` 工作区。
> v2 变更：引入 dio / riverpod_annotation / freezed / json_serializable 等主流开源轮子；`live_core` 改名 `live_sites` 并将站点契约改为 **LiveRoom 优先**；新增 `live_logging`、`live_platform`、`live_state` 三个支撑包；本地存储优先采用 pub.dev 成熟组件。
> 本文档先定技术方案，技术选型见第 4 节；方案评审通过后再动代码。

---

## 1. 源仓库审查结论

### 1.1 总览

源仓库是 Dart pub workspace（`pure_live_workspace`），11 个 packages 全部 `resolution: workspace`，SDK `^3.13.0`，统一 `very_good_analysis`。除 `live_ui` 外全部是**纯 Dart 包（无 Flutter 依赖）**，与 UI 彻底分层。

| 包 | 规模（lib 行数） | 测试文件 | 一句话职责 |
|---|---|---|---|
| live_core | 56,162 | 81 | 平台抽象：模型 + `LiveSite` 接口 + 34 个站点实现 |
| live_danmaku | 23,704 | 40 | 弹幕：连接/编解码/过滤 + 28 个站点协议实现 |
| live_ui | 15,116 | 22 | 设计系统：主题/图标/约 40 个通用组件（Flutter） |
| live_store | 5,822 | 21 | 存储：drift 手写 SQL + typed settings + 3.x 数据迁移 |
| live_record | 5,356 | 10 | 录制内核：调度/选流/分段/合并/弹幕录制，FFmpeg 注入 |
| live_vod | 4,792 | 4 | B 站点播（PGC/UGC）+ 音乐播放 |
| live_net | 4,517 | 11 | 网络内核：HTTP/WS/代理/竞速/节流 |
| live_media | 3,896 | 8 | 播放喂流层：回环中继/FLV 拼接/HLS 预取（不依赖播放器） |
| live_iptv | 3,094 | 5 | IPTV：M3U/TXT 解析、EPG、时移回看、伪装成直播站点 |
| live_player | 3,169 | 7 | mpv 播放引擎封装 —— **本次不迁移** |
| live_cast | 1,872 | 8 | 纯 Dart DLNA 投屏（SSDP/SOAP/AVTransport） |

另有：根级 `fixtures/`（59MB，34 平台脱敏回放样本 + 冻结期望输出，是站点解析回归的验收基准）、`third_party/media_kit*`（自维护 fork，随 live_player 淘汰）。

### 1.2 各包审查摘要

**live_net（网络内核）** — 核心是 `LiveHttp` 接口（`send`/`open` 流式）+ `IoLiveHttp` 实现（按代理路由池化 `HttpClient`）；`LiveRequest`/`LiveResponse`/`CancelToken`/`TransportFailure` 分型错误。周边：`CookieVault`（cookie 注入接口）、`ProxyRoute`/`ProxyPolicy`（全局+按站点代理）、`race`（多请求竞速 + GitHub 镜像竞速）、`ThrottledHttp`（按站点限速）、`LiveSocket`（多端点故障转移 + 心跳看门狗 + generation 防旧回调）、`ReplayHttp`（回放 fixtures 的测试实现）。`codec/brotli*` 约 2500 行纯 Dart brotli 解码（RFC 7932）。**评价：接口抽象质量高；传输实现是手写 `dart:io` HttpClient，属可替换轮子（v2 改 dio）。**

**live_core（平台抽象）** — `LiveSite` 抽象类（目录/搜索/详情/清晰度/取流/状态），扩展能力用可选接口 + 模式匹配（`LivePlayUrlResolver`、`LivePlayRecoveryResolver` 等，经 `LiveSiteCalls` extension 统一调用）。`SiteRegistry` 懒构建按 id 缓存。模型层 `LiveRoom`（834 行，状态按索引存、限制按名字存，兼容 3.x JSON）、`LivePlayLine`+`PlayLease`（自描述线路：租约/续租/断连语义）、`LiveMessage`、`LiveArea`、`LiveGift`、`LiveQualityLabel`。横切工具：`aes.dart`（**手写** AES-128-CBC）、`html.dart`（**手写**容错 HTML 解析）、`tars.dart`（虎牙 WUP）、`hls_master.dart`、`input_recipe.dart`。34 个站点目录，固定 `xxx_api.dart` + `xxx_site.dart` 模式。**评价：领域模型和站点资产是核心价值；手写的 aes/html 是 pub.dev 有现成方案的轮子；接口签名以 roomId 为主，需改造成 LiveRoom 优先。**

**live_danmaku（弹幕）** — 三层：`connection.dart` 纯接口 + sealed 事件；`connection_base.dart` 抽象基类（generation 生命周期）；`socket_connection.dart` 基于 `LiveSocket` 的共享运行时。`exact_websocket.dart` 是手写 RFC6455（dart:io 强制小写 Upgrade 头导致 YY/SOOP 握手失败，**pub 上无替代方案**）。编解码：`BinaryReader/Writer`、无 schema 单层 protobuf（抖音）。8 种过滤器。28 个站点协议实现。**评价：协议层是硬资产；过滤器与 media_core_danmaku 职责重叠（§2 D6）。**

**live_media（喂流层）** — 独立于播放器引擎的"播放核心"，核心资产：`LoopbackRelay`（绑 127.0.0.1 的本地 HTTP 中继，播放与录制共享）、`FlvSplicer`（同画质同线路 URL 续租无缝拼接，新流在新关键帧交接 + 时间轴对齐，支持 HEVC/AV1）、`HlsRelay`/`HlsSessionCookies`/`HlsMediaWindow`（HLS cookie 钉源站、保留窗口预取 48 段/96MB）、`PlaybackTransport`（源事务）、`SourceEventFence`（generation 隔离）、`LineFallback`（线路降级游标）、`PlayerErrorType` 稳定机器码、站点配方（Bigo 每段解扰、niconico 现取 cookie + master 裁剪）。**评价：旧仓最值钱的非站点资产，pub.dev 无任何等价物，整体保留。**

**live_record（录制内核）** — `RecordScheduler` 并发上限 FIFO 队列；`RecordStreamResolver`"续租→同画质换线→换画质"；所有直播流一律走回环中继；`FfmpegRunner` 只定契约、实现由 app 注入（ffmpeg_kit_extended_flutter 0.6.2）；`SegmentClock` clock-v1 CSV 精确分段 + `RecordMerger` 合 MP4；弹幕录制经 app 桥接；`pinyindart` 安全命名。**评价：领域内核完整，与 media_core_recording_ffmpeg 两套分段方案需收敛（§2 D4）。**

**live_store（存储）** — drift + sqlite3，**不用 codegen、全手写 SQL**，12 张表，多进程共享（busy_timeout + `data_version` 同步第二窗口）。`Setting<T>` sealed 类型化设置（约 245 条，坏值归一化，key 沿用 3.x Hive key）；`SecretCipher` 接缝（**手写** Android Keystore / Windows DPAPI）；多平台多账号 `AccountRoster`；**手写** WebDAV 客户端；`BackupService` 完全兼容 3.x 分节格式；`legacy/` 直接解析 3.x hive_ce 帧格式（CRC-32）做一次性迁移。**评价：3.x 迁移链路必须保留；secrets/WebDAV 是 pub.dev 有成熟方案的轮子（v2 替换）。**

**live_ui（设计系统）** — 主题（品牌/动态取色/TV 配色/网格断点/弹簧运动）、图标（Remix 映射 + 35 平台 logo）、约 40 个组件 + 3 库共 85 种 loading；`LiveUiScope` 注入文案与图片 Referer 解析器。**评价：与业务解耦好，按"foundation/widgets"两拆。**

**live_iptv** — M3U/TXT 双解析器、XMLTV（含 .gz）EPG + 频道唯一匹配、时移回看 URL 模板展开、drift 持久化 + 乐观锁、9 级唯一键 reconcile、`IptvSite extends LiveSite` 伪装成直播平台。**评价：自洽领域，原样保留。**

**live_vod** — 面向 B 站点播：UGC/PGC API、`BilibiliVodClient`（CookieVault、WBI 签名复用 live 适配器、-352 风控重签重试）、错误映射到 `SiteError`、分段 protobuf 弹幕（内嵌精简读取）；`music/` 基于 B 站音频的歌单/匹配/LRC 歌词/每日推荐/播放队列/音频缓存。**评价：按 bilibili/music 天然两拆。**

**live_cast** — 纯 Dart DLNA。与 `media_core_cast_dlna` 功能重叠，**决策弃用**（§2 D5）。

**live_player** — mpv 引擎封装，依赖自维护 media_kit fork。**本次不迁移**。

### 1.3 资产取舍速览

- **核心资产（必须保真迁移）**：34 站点解析 + fixtures 回放验收、28 弹幕协议、ExactWebSocket、FLV 拼接/HLS 预取中继、录制内核、3.x 数据迁移链、typed settings、设计系统。
- **淘汰**：`live_player`、`third_party/media_kit*`、`live_cast`、`live_danmaku` 过滤器中与 media_core_danmaku 重复的部分（待验证，O2）。
- **可替换轮子（pub.dev 有成熟方案，v2 换掉）**：手写 HTTP 传输（→ dio）、手写 AES（→ cryptography）、手写 HTML 解析（→ package:html）、手写 secrets 加密（→ flutter_secure_storage）、手写 WebDAV（→ webdav_client）、手写 fromJson/toJson（→ json_serializable）、手写状态样板（→ riverpod codegen）。
- **必须保留自研（pub.dev 无等价物，理由见 §4.5）**：ExactWebSocket、纯 Dart brotli、无 schema protobuf、回环中继/FLV 拼接/HLS 预取、竞速/节流/代理策略、typed settings 领域逻辑、clock-v1 录制分段。

### 1.4 接口契约问题（v2 重点修正）

旧 `LiveSite` 接口以 `roomId` 为出入参（`getRoomDetail({required String roomId})`、`getLiveStatus({required roomId})`），导致：

1. 关注列表刷新时只有 roomId，站点侧平台专属上下文（抖音 live_id、B 站房间长号短号映射、FC2 会话等）丢失，得先查一次详情才能判断状态，浪费请求；
2. 从搜索结果/分类页进入房间时，已经拿到完整 `LiveRoom`，却要拆成 roomId 再让站点重建。

v2 契约改为 **LiveRoom 进、LiveRoom 出**（详见 §3.3）：本地保存的就是完整 `LiveRoom`（含平台专属 payload），刷新状态、取清晰度、取流全部直接把 room 喂给站点。

---

## 2. 与 media_core 的能力对照与边界决策

media_core 是"与平台无关的播放编排层 + 按能力拆分的 24 包"：`PlayerKernel` 句柄式 API、会话与代际、命令串行化、唯一恢复决策点 `RecoveryLadder`、池化、四后端（media_kit/fvp/ijk/better_player）+ 六套设计语言控制条 UI。逐项对照：

| # | 旧包/能力 | media_core 对应 | 决策 |
|---|---|---|---|
| D1 | live_player + media_kit fork | media_core（编排）+ media_core_media_kit / media_core_ijk_player（后端）+ media_core_ui（控制条） | **弃旧用新**。后端组合：桌面 media_kit（libmpv）；Android FLV/H.265 软解用 ijk（flv_lzc pin）。风险见 O1 |
| D2 | live_media 回环中继/FLV 拼接/HLS 预取 | media_core_ingest（LoopbackIngestRelay HLS 重写 / FfmpegIngestRelay DASH 合流） | **两包并存、边界划清**：直播专用的 FLV 拼接续租、HLS 保留窗口预取、站点配方 media_core_ingest 没有——`live_media_relay` 保留并作为 media_core 的上游输入；ingest 仅用于 DASH 合流等 media_core 独有能力。回环 URL 经 `PlayerSource` 喂给 kernel |
| D3 | live_media LineFallback + live_player policies | media_core RecoveryLadder + media_core_live LivePlaybackController staged 扫描 | **恢复决策唯一化到 media_core**。pure_live 侧职责收缩为：把 `LivePlayLine[]` 排序成候选源序列，经 `onEngineFallbackSources`/`onRecoverySources` 插入口喂给恢复梯；`LineFallback` 退役（或仅保留 lineKey 失败记账供排序） |
| D4 | live_record（clock-v1 分段 FLV→MP4 合并） | media_core_recording_ffmpeg（分段 MPEG-TS + CSV 清单） | **保留 live_record 内核**；`FfmpegRunner` 接缝继续注入 ffmpeg_kit_extended_flutter。media_core 的 `RecordingManager` 仅作宿主侧任务挂载点。冲突时以 live_record 为准（O3） |
| D5 | live_cast（SSDP/SOAP DLNA） | media_core_cast_dlna（DlnaCastBackend，SSDP+SOAP+DIDL-Lite） | **弃 live_cast**，投屏走 kernel 的 `CastController` + DlnaCastBackend。投屏 URL 必须用原始公网 URL（回环 URL 仅本机可见，不得投屏） |
| D6 | live_danmaku filters（8 种） | media_core_danmaku（DanmakuController + epoch 围栏 + DanmakuMessageGate + 屏蔽过滤 + FlameBarrageSink 渲染） | **分层**：live_danmaku 只保留"连接与解码"，LiveMessage 流交给 media_core_danmaku 做会话/过滤/渲染；屏蔽规则存 live_store，适配成 gate 策略注入。filter 包**暂缓迁移**（O2） |
| D7 | 屏幕常亮/系统媒体通知 | media_core_mediasession | **用 media_core** |
| D8 | 多画面 | media_core_multiview（视频墙 + 逐格弹幕 + 解码预算） | **用 media_core** |
| D9 | 桌面窗口（无框/置顶小窗/PiP） | media_core_win32 + media_core_pip/floating/presentation | **用 media_core**，window_manager 仅保留托盘/基础窗口管理 |
| D10 | IPTV 时移 catchup | （无对应） | catchup URL 生成保留在 live_iptv，产出后转 `PlayerSource` 进 kernel |
| D11 | 日志（旧仓散落 print/自制诊断） | media_core_logging（MediaCoreLog，默认静默） | 新建 **live_logging** 统一门面（§3.2），media_core_logging 的 sink 桥接到 LiveLog，live_net 诊断日志同路 |

**一句话边界**：pure_live 侧负责"**把一个直播间变成一组可播放的候选源 + 弹幕字节流 + 领域数据**"（站点、弹幕协议、喂流中继、存储、UI 设计系统）；media_core 负责"**从 PlayerSource 开始的一切播放体验**"（编排、恢复、多后端、渲染、呈现、录制后端）。

---

## 3. 技术方案

### 3.1 目标架构总图

```text
┌────────────────────────── apps/pure_live（应用壳，riverpod codegen + go_router，另行立项）─────────────────────────┐
│                                                                                                                  │
│   ┌── media_core 工作区（path/git 依赖引入）──────────────────────────────────────────────────────────────┐       │
│   │  PlayerKernel + media_core_live + media_core_media_kit/ijk + media_core_ui + media_core_danmaku      │       │
│   │  + media_core_recording_ffmpeg + media_core_cast_dlna + media_core_multiview + mediasession …        │       │
│   └──────────────▲──────────────────▲──────────────────▲───────────────────────────────────────────────┘       │
│                  │ PlayerSource      │ DanmakuSink      │ RecordingBackend / CastController                     │
│   ┌──────────────┴────────────────────────────────────────── 应用支撑层 ────────────────────────────────┐       │
│   │  live_state（riverpod_annotation 状态架构包） · live_ui_foundation ── live_ui_widgets                │       │
│   │  live_platform（平台判定 + 各平台路径/目录） · live_logging（日志门面，领域包也可用）                  │       │
│   └───────────────────────────────────────────────────────────────────────────────────────────────────┘       │
│   ┌──────────────────────────────────────────────────────── 领域包 ─────────────────────────────────────┐      │
│   │  媒体管线    live_media_source ── live_media_relay（回环中继/FLV拼接/HLS预取）                        │       │
│   │  垂直领域    live_iptv · live_vod_bilibili ── live_vod_music · live_record_core                      │      │
│   │  弹幕        live_danmaku_protocol ── live_danmaku_sites                                             │      │
│   │  站点        live_sites（契约+模型+工具）── live_sites_cn / jp / kr / global                          │      │
│   │  网络        live_net（LiveHttp 契约 + dio 实现 + 竞速/节流/代理） · live_net_brotli                    │      │
│   │  存储        live_store_{db,settings,identity,backup,legacy}                                         │      │
│   └───────────────────────────────────────────────────────────────────────────────────────────────────┘       │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

播放主链路（以 B 站为例）：

```text
关注列表（本地存完整 LiveRoom JSON）
  → live_state 的 storeListProvider 读出 rooms → site.refreshLiveStatus(room) 批量刷新状态（room 直进接口）
  → 进入房间：site.getRoomDetail(room) → getPlayQualities(room) → getPlayUrls(room, quality)
  → LivePlayLine[] →（需要中继的）live_media_relay 起回环输入 → MediaInput
  → PlayerSource(uri, headers, format, live) → PlayerKernel.create()
  → media_core_live LivePlaybackController staged 扫描 + 看门狗
  → 恢复失败时经 onRecoverySources 拿下一候选（续租后的新 URL 由 relay 现产）
```

弹幕链路：`DanmakuRegistry` 工厂（app 组装）→ `live_danmaku_sites` 连接解码 → `LiveMessage` 流 → media_core_danmaku `DanmakuController`（gate/屏蔽/相似度）→ `DanmakuSink` 渲染。

### 3.2 包细分方案（11 → 25）

> 细分原则：按"改动节奏 + 复用边界"拆，不按文件数拆。站点按地区分组；`live_store_legacy` 是有生命周期的一次性包；`live_logging`/`live_platform`/`live_state` 是本次新增的支撑包。

**基础设施层（9）**

| 新包 | 来源 | 内部模块 | 说明 |
|---|---|---|---|
| live_net | live_net 重构 | **contract**（LiveHttp/LiveRequest/LiveResponse/CancelToken/TransportFailure）+ **dio 实现**（DioLiveHttp，含代理路由、native adapter 可选）+ socket（LiveSocket）+ race + throttle + replay + headers + ua | 契约与测试层保持自研语义，传输层换 dio（§4.3）；ReplayHttp 不变 |
| live_net_brotli | live_net/codec | brotli + tables + dictionary | 独立编译单元；pub.dev 的 brotli 包 SDK 约束装不上，纯 Dart 实现保留（§4.5） |
| **live_logging（新）** | 新建 | `LiveLog` 门面（分级/分类/字段）/ ring buffer / sink（console、文件轮转、app 注入）/ 脱敏过滤器（URL 签名参数、cookie） | 纯 Dart 零依赖，领域包允许依赖；media_core_logging 与 live_net 诊断日志统一桥接进来 |
| **live_platform（新）** | 新建（吸收旧 app/lib/platform） | `PlatformKind`/`formFactor`（desktop/mobile/TV，含 Android leanback 判定）/ `AppDirectories`（support/data/cache/logs/records，基于 path_provider + Windows 便携版检测）/ 能力探针（托盘/PiP 可用性） | Flutter 层包；领域包不依赖它，目录经 app 注入 |
| live_store_db | live_store | database / 门面 / rooms / tags / block_lists / local_events / meta | drift + sqlite3 保留（drift 本身就是 pub.dev 成熟组件，手写 SQL 语义见 §4.4） |
| live_store_settings | live_store/settings | setting / settings / settings_store | 245 条 typed 设置 |
| live_store_identity | live_store | accounts / secrets | secrets 落 **flutter_secure_storage**（Keystore/Keychain/DPAPI/libsecret 全覆盖），自研 DPAPI/Keystore 通道退役 |
| live_store_backup | live_store/backup + webdav | backup_service / webdav | WebDAV 传输换 **webdav_client**，备份分节格式（3.x 兼容）逻辑保留 |
| live_store_legacy | live_store/legacy | hive_reader / snapshot / rules / import / identity 迁移 | **一次性**，全量迁移完成后归档 |

**领域核心层（5）**

| 新包 | 来源 | 说明 |
|---|---|---|
| **live_sites**（原 live_core 更名） | live_core 的模型 + 抽象 + 工具三合一 | `site/`：LiveSite 抽象（**LiveRoom 优先契约**，§3.3）+ 全部可选扩展接口 + SiteRegistry + SiteIds + links + input_recipe；`model/`：LiveRoom/PlayLine/Message/Area/Gift/QualityLabel/SiteError 等（**freezed + json_serializable 重写**，JSON 兼容 3.x）；`toolkit/`：tars / hls_master / hls_source_query（aes、html 换开源库后不再需要自研文件） |
| live_sites_cn（17 站） | live_core/sites | bilibili、douyu、huya、douyin、cc、acfun、baidulive、kuaishou、kugoulive、jdlive、yy、missevan、inke、liveme、looklive、weibo、xiaohongshu |
| live_sites_jp（6 站） | live_core/sites | niconico、fc2live、showroom、twitcasting、kilakila、sixroom |
| live_sites_kr（3 站） | live_core/sites | chzzk、pandalive、soop |
| live_sites_global（7 站） | live_core/sites | twitch、youtube、kick、picarto、bigo、steambroadcast、tiktok |

站点包内部保持 `xxx_api.dart` + `xxx_site.dart` 双文件模式；解析函数入参从裸字符串/roomId 改为以 `LiveRoom`（及其 `data` payload）为上下文；测试继续走 fixtures 回放。

**弹幕层（2 迁移 + 1 缓迁）**

| 新包 | 来源 | 说明 |
|---|---|---|
| live_danmaku_protocol | connection* / socket_connection / exact_websocket / binary / codec.protobuf / registry / sender / emoji | 协议与连接基座 |
| live_danmaku_sites | sites/ 全部 28 站 | 单文件每站，按 cn/jp/kr/global 分目录 |
| live_danmaku_filter | filters/ 8 种 | **缓迁**：先验证 media_core_danmaku gate 覆盖度（O2） |

**媒体管线层（2）**

| 新包 | 来源 | 内部模块 |
|---|---|---|
| live_media_relay | relay + upstream + proxy + inputs | loopback_relay / flv + flv_splicer / hls_relay + cookies + window / upstream / recipes |
| live_media_source | 其余 | source / input / transport / fence / errors / fallback（收缩为记账） |

**垂直领域层（4）**

| 新包 | 来源 | 说明 |
|---|---|---|
| live_iptv | 原样 | 内部分 playlist / guide / catchup / library 四模块 |
| live_vod_bilibili | live_vod 主体 | client / ugc / pgc / parse / streams / danmaku / models / store；依赖 live_sites（WBI 在 bilibili_api，随站点进 live_sites_cn） |
| live_vod_music | live_vod/music | matcher / lyrics / daily / queue / audio_cache / third_party |
| live_record_core | live_record | recorder / scheduler / resolver / input / segments / merge / chat / naming / policy / storage / settings / metrics；FfmpegRunner 契约保留 |

**应用支撑层（3，新增/重命名）**

| 新包 | 来源 | 说明 |
|---|---|---|
| **live_state（新）** | 新建 | riverpod_annotation 状态架构包，见 §4.2 |
| live_ui_foundation | live_ui/theme + icons + scope | 设计令牌、平台 logo 资产、LiveUiScope 注入契约 |
| live_ui_widgets | live_ui/widgets + loading | 约 40 组件；对接 media_core_ui 槽位 |

合计 **25 包**（迁移 20 + 新增 3 + 由 live_store 拆分产生的 2 个额外粒度包），淘汰 live_player、live_cast。

### 3.3 LiveRoom 优先的站点契约（live_sites）

新的 `LiveSite` 接口，出入参统一为领域对象，本地保存的 `LiveRoom` 可直接回流：

```dart
abstract class LiveSite {
  String get id;
  String get name;

  // 目录与搜索 —— 返回统一分页类型
  Future<LivePage<LiveRoom>> getRecommendRooms({int page});
  Future<LivePage<LiveRoom>> getCategoryRooms(LiveArea area, {int page});
  Future<LivePage<LiveRoom>> searchRooms(String keyword, {int page});
  Future<LivePage<LiveAnchor>> searchAnchors(String keyword, {int page});

  // 房间 —— 全部以 LiveRoom 为入参（不再有裸 roomId 重载）
  Future<LiveRoom> getRoomDetail(LiveRoom room);
  Future<List<LivePlayQuality>> getPlayQualities(LiveRoom room);
  Future<List<LivePlayLine>> getPlayUrls(LiveRoom room, LivePlayQuality quality);
  Future<List<LiveSuperChatMessage>> getSuperChatMessages(LiveRoom room);

  /// 状态刷新：关注列表场景，把本地保存的 room 直接喂回站点。
  /// 站点用 room.roomId + room.data（平台专属 payload）判断，
  /// 返回带新 status/观众数/标题/开播时间的同身份 room。
  Future<LiveRoom> refreshLiveStatus(LiveRoom room);
}
```

配套约定：

1. **LiveRoom 持久化即契约**：关注/历史在 live_store_db 里存的就是 `LiveRoom` 的 JSON（json_serializable 生成，字段与 3.x 兼容），平台专属上下文放 `room.data`（`Map<String, Object?>`），站点自行解释；
2. **批量刷新编排**：`SiteRegistry` 提供 `refreshAll(Iterable<LiveRoom>)` 助手（按站点分组、节流并发、失败不影响整批），供 live_state 的关注刷新 provider 调用；
3. **同身份判断**：刷新返回的 room 以 platform+roomId 为身份，界面/存储按此合并，避免旧数据抖动；
4. 可选扩展接口（PlayUrlResolver / RecoveryResolver / RecordRoomResolver / CancellableSearch 等）保持旧设计，入参同步改为 LiveRoom 优先。

### 3.4 依赖方向规则

```text
live_logging ────────────────────────────────── （零依赖，所有包可用）
live_net_brotli ─────────────────────────────── （零依赖）
live_net           → dio, live_logging
live_sites         → live_net, crypto, cryptography, package:html, live_logging
live_sites_{cn,jp,kr,global} → live_sites, live_net, live_logging
live_danmaku_protocol → live_sites, live_net, live_logging
live_danmaku_sites → live_danmaku_protocol, live_sites, live_net
live_media_relay   → live_sites, live_net, clock
live_media_source  → live_media_relay, live_sites, live_net, clock
live_record_core   → live_media_source, live_sites, live_net, pinyindart, clock
live_iptv          → live_sites, live_net, xml, path
live_vod_bilibili  → live_sites, live_sites_cn（WBI）, live_net
live_vod_music     → live_vod_bilibili
live_store_db      → drift, sqlite3（不依赖 live_sites）
live_store_settings → live_store_db
live_store_identity → live_store_db, flutter_secure_storage
live_store_backup  → live_store_db, live_store_identity, webdav_client
live_store_legacy  → live_store_db, live_sites（LiveRoom 模型）
live_platform      → Flutter/path_provider（应用支撑层）
live_state         → flutter_riverpod, riverpod_annotation, live_store_db, live_store_settings
live_ui_foundation → Flutter 生态（不依赖领域包）
live_ui_widgets    → live_ui_foundation
```

强制规则（进 CI 检查）：
1. 依赖严格单向，禁止反向 import；领域包之间禁止横向 import。
2. 领域包（sites/danmaku/media/record/iptv/vod/store）**禁止依赖 Flutter**，也禁止依赖 live_platform/live_state/live_ui_*——平台路径、目录、呈现一律经 app 注入。
3. `live_logging` 是唯一允许所有包依赖的支撑包（类似 meta 的地位）。
4. media_core 只允许 app 壳与 live_ui_widgets 依赖；领域包不得 import 任何 media_core 包。
5. 唯一例外依赖：`live_vod_bilibili → live_sites_cn`（复用 B 站 WBI/签名算法），评审记录在案。

### 3.5 与 media_core 的接缝设计

接缝全部在 app 壳装配（经 live_state / live_ui 暴露给界面），领域包保持对 media_core 无感知：

1. **取流 → PlayerSource**：`LivePlayLine` →（需要时）`live_media_relay` 回环输入 → `PlayerSource(uri, headers, protocol/format, type: live)`。`PlayerAdapterSelector` 按声明协议/格式选后端（桌面 media_kit、Android FLV/H.265 ijk）。
2. **恢复**：候选源序列经 `LivePlaybackController` 的 `onEngineFallbackSources`/`onRecoverySources` 喂 RecoveryLadder；续租型源在恢复时由 relay 现产新 URL。pure_live 不再自建恢复状态机。
3. **弹幕**：`DanmakuConnectionFactory`（app 组装）产 `LiveMessage` 流 → media_core_danmaku `DanmakuController` → `DanmakuSink`。屏蔽设置从 live_store_db 读出（live_state 提供 `blockRulesProvider`），转成 gate 策略注入。若 FlameBarrageSink 样式不满足旧仓视觉规范，自定义 Sink 复用 `EmoteText`（O7）。
4. **录制**：`RecordScheduler`/`RecordStreamResolver`/`RecordChatRecorder` 照旧；`FfmpegRunner` 绑定 ffmpeg_kit_extended_flutter（`ffmpeg_kit_extended_config` 本地 bundle 方案随迁）。media_core `RecordingManager` 只做任务面板挂载。
5. **投屏**：kernel `CastController` + DlnaCastBackend；投屏源取原始 URL，禁止回环 URL；搜索/互斥对话框逻辑在 app 层重写。
6. **系统媒体面/呈现**：`MediaSessionBootstrap.enable()` 一行；桌面无框/快照 media_core_win32，安卓 PiP media_core_pip，多画面 media_core_multiview。
7. **封面/头像**：`LiveRoom.httpHeaders` 经 `LiveUiScope.imageHeadersResolver` 注入图片加载。

### 3.6 迁移映射表（旧 → 新）

| 旧位置 | 新位置 | 动作 |
|---|---|---|
| packages/live_net/**（除 codec） | packages/live_net | **重构**：IoLiveHttp → DioLiveHttp，契约/竞速/节流/回放保留 |
| packages/live_net/codec/brotli* | packages/live_net_brotli | 移动 |
| packages/live_core/lib/src/模型、抽象、工具 | packages/live_sites | 移动 + **freezed/json_serializable 重写模型** + 契约改 LiveRoom 优先 |
| packages/live_core/lib/src/sites/{分区域 33 站} | packages/live_sites_{cn,jp,kr,global} | 移动 + 签名改造 |
| packages/live_danmaku/lib/src/{连接、编解码、registry} | packages/live_danmaku_protocol | 移动 |
| packages/live_danmaku/lib/src/sites/** | packages/live_danmaku_sites | 移动（按地区归目录） |
| packages/live_danmaku/lib/src/filters/** | （缓迁，O2） | 暂不迁移 |
| packages/live_media/** | packages/live_media_{relay,source} | 移动 |
| packages/live_record/** | packages/live_record_core | 移动 |
| packages/live_iptv/** | packages/live_iptv | 原样 |
| packages/live_vod/** | packages/live_vod_{bilibili,music} | 移动 |
| packages/live_store/** | packages/live_store_{db,settings,identity,backup,legacy} | 移动 + secrets 换 flutter_secure_storage、WebDAV 换 webdav_client |
| packages/live_ui/** | packages/live_ui_{foundation,widgets} | 移动 |
| 旧 app/lib/platform/ 的平台与路径逻辑 | packages/live_platform | 抽取新建 |
| 旧 app 内散落的日志/诊断 | packages/live_logging | 收敛新建 |
| 旧 app 内手写的状态样板（loader/分页/刷新） | packages/live_state | 抽象新建 |
| packages/live_player/** | — | **不迁移** |
| packages/live_cast/** | — | **不迁移**（media_core_cast_dlna 替代） |
| third_party/media_kit* | — | **不迁移**（O1 评估补丁归属） |
| fixtures/** | fixtures/** | 原样（59MB，保留脱敏门禁） |
| tools/gate（脱敏检查、timeshift） | tools/gate | 挑选移植 |
| assets/version.json、releases.json | assets/ | 原样（更新检查依赖，不能删） |

### 3.7 分阶段迁移计划

每阶段独立可验证，门禁（analyze + test + fixtures 回放 + 依赖方向检查）全绿才算完成。

| 阶段 | 内容 | 验收标准 |
|---|---|---|
| P0 基建 | workspace 根 pubspec、analysis_options、CI 门禁、fixtures 移植、**codegen 工具链**（build_runner / riverpod_generator / freezed / json_serializable 统一版本与生成约定） | `dart pub get` + 一次 `build_runner build` 通过；门禁脚本可跑 |
| P1 基础设施 | live_logging、live_platform、live_net（dio 化）、live_net_brotli、live_state 骨架 | dio 实现通过 ReplayHttp 全部回放用例；LiveLog sink 桥接 media_core_logging 冒烟；live_state 分页/设置 provider 有单元测试 |
| P2 领域核心 | live_sites（模型 freezed/json 重写 + LiveRoom 优先契约 + SiteRegistry） | 模型 JSON 对拍 3.x（旧 fixtures 的 expected.json 仍可解析）；契约改造完成 |
| P3 站点 | 4 个 regional 包 | 33 站 ×（api+site）fixtures 回放全绿——最大的单一工作量 |
| P4 弹幕 | live_danmaku_protocol/sites | 40 个测试文件全绿；YY/SOOP 握手样本验证 ExactWebSocket |
| P5 媒体管线 + 首次联通 | live_media_relay/source；app 最小接入 media_core（B 站端到端：取流→PlayerSource→kernel→media_core_ui） | B 站真实房间可播；FLV 续租拼接与 HLS 预取回放绿；RecoveryLadder 能拿到续租候选 |
| P6 存储 | live_store_* + legacy 迁移链 + flutter_secure_storage 切换 | settings/关注/历史/标签/屏蔽/**cookie 密文**从 3.x 迁移成功（Android + Windows 便携版真机）；secure_storage 在 Windows DPAPI 读回一致 |
| P7 垂直领域 | live_iptv、live_vod_bilibili/music、live_record_core | 各包测试绿；Windows 录制出 MP4；IPTV catchup URL 对拍 |
| P8 设计系统 | live_ui_foundation/widgets + live_state 全量接入 | 组件金样测试迁移；MediaCorePlayerView 槽位接入 LiveUiScope 令牌 |
| P9 app 壳 | riverpod codegen 全量业务状态、go_router、i18n、TV、桌面 | 另行立项 |

工作量提示：P3 与 P6 是风险最集中的两段；P5 是架构联通关键节点，宜最早安排一次"薄切片"验证 §3.5 全部接缝假设；P2 的模型 codegen 重写是纯机械但量大的活，配合 fixtures 对拍防回归。

---

## 4. 技术选型

### 4.1 工程基建

| 项 | 选型 | 理由 |
|---|---|---|
| Flutter / Dart | Flutter 3.47.x / Dart ^3.13 | 旧仓已验证；满足 media_core 下限（≥3.35） |
| 多包管理 | Dart 原生 pub workspace | 与旧仓、media_core 一致；不引入 melos |
| Lint | very_good_analysis ^11 + **riverpod_lint + custom_lint** | 沿用；riverpod_lint 保证 codegen 状态规范（§4.2） |
| 代码生成 | build_runner（统一版本管理；生成物**不进 git**，CI 构建时生成） | riverpod/freezed/json_serializable 共用一条工具链 |
| media_core 引入方式 | 开发期 path 依赖，稳定后转 git 依赖锁 commit | 见 O5 |
| 测试 | `test` ^1.32 + ReplayHttp 回放 + fixtures 脱敏门禁 | 旧仓验收体系整体保留 |

### 4.2 状态管理：riverpod codegen + live_state 架构包

**基础选型**（版本按当前可用稳定锁定）：

```yaml
flutter_riverpod: ^3.3.2        # Riverpod 状态管理
riverpod_annotation: ^4.0.3     # Riverpod 注解生成依赖
riverpod_generator: ^4.x        # dev：@riverpod 代码生成
riverpod_lint: ^4.x             # dev：状态规范 lint
freezed_annotation: ^3.1.0      # 数据模型冻结类注解
freezed: ^3.x                   # dev：freezed 生成
json_annotation: ^4.12.0        # JSON 序列化基础注解
json_serializable: ^1.x         # dev：JSON 生成
```

**live_state 包**——解决"每次写状态都要重写样板"的问题，把可复用的状态范式沉淀成包，业务侧只用 `@riverpod` 声明：

| 模块 | 提供能力 | 典型消费方 |
|---|---|---|
| pagination | `PagedController<T>` 范式：refresh / loadMore / retry / 状态 sealed（loading·ok·empty·error）、页码与游标两种分页、防抖节流刷新、保位置刷新 | 分类页、搜索、历史、IPTV 频道 |
| collection | `storeListBinder`：把 live_store 的 watch 流（关注/历史/标签/屏蔽）接成 provider，附带乐观更新钩子 | 关注列表、标签管理 |
| settings | `settingProvider<T>(Setting<T>)` 泛型 family：同步读、写透传、变更自动广播，直接吃 live_store_settings 的类型化设置 | 全部设置界面 |
| refresh | `roomStatusProvider`：关注列表批量刷新编排（调 `SiteRegistry.refreshAll`、节流、失败隔离、逐房间更新） | 关注/热门刷新 |
| task | 一次性异步任务视图（submit/progress/result/cancel） | 导入、备份、恢复、迁移 |
| presenter | 播放/弹幕会话的 presenter 基类（**media_core 类型不进本包**，暴露 duration/position/buffer 等中性接口，app 用 media_core handle 实现之） | 播放页、迷你窗 |

约定：所有 feature 状态用 `@riverpod` codegen，禁止手写 ChangeNotifier/InheritedWidget 状态；provider 命名与文件组织规范写进 ENGINEERING 规范；riverpod_lint 进 CI。

### 4.3 网络层：契约自研 + dio 传输

- `LiveHttp` 契约（send/open/CancelToken/TransportFailure 分型）**保留**——它是 ReplayHttp 回放测试、按站点节流、竞速、代理策略的地基；
- 传输实现换 **dio ^5**（`DioLiveHttp`）：拦截器（日志→live_logging、UA、重试预算）、`CancelToken` 双向映射、按 ProxyRoute 构建 dio 实例（保持旧"每个代理路由一个 client"的池化语义）、流式 `open` 用 dio 的 ResponseType.stream；
- 可选进阶：Android 用 **cronet_http**、iOS 用 **cupertino_http**（经 dio native adapter 获得平台级 HTTP/2/QUIC 与系统 TLS），桌面保持默认；
- brotli：dio 不解 brotli，且 B 站弹幕的 brotli 在 WS 载荷上，`live_net_brotli` 保留；
- `LiveSocket`/`ExactWebSocket` 不受影响（WS 走 dart:io + 手写握手）。

### 4.4 存储选型

| 需求 | 选型 | 说明 |
|---|---|---|
| 结构化存储 | **drift ^2.35 + sqlite3 ^3.7**（保留） | drift 本身就是 pub.dev 成熟组件；手写 SQL 保留是因为多进程 watch（`data_version`）与 3.x 兼容需要精确控制，不引入 codegen 表定义，评审通过后不再动摇 |
| 密钥/Cookie | **flutter_secure_storage**（新） | 替代手写 DPAPI/Keystore；Android Keystore、iOS Keychain、Windows DPAPI、Linux libsecret 全覆盖，一份 API |
| WebDAV | **webdav_client**（新） | 替代手写客户端；备份分节格式（3.x 兼容）逻辑保留在 live_store_backup |
| 3.x Hive 读取 | hive_ce（dev only，保留） | 一次性迁移，无替代 |
| 设置 | typed settings（自研领域逻辑，保留） | 245 条设置 + 坏值归一化 + legacy key 映射是业务逻辑不是轮子 |
| 图片缓存 | cached_network_image + flutter_cache_manager（沿用） | — |
| 文件选择/分享/打开 | file_picker、share_plus、open_filex（沿用） | — |

### 4.5 自研保留清单（pub.dev 无等价物）

| 自研件 | 为什么不用现成包 |
|---|---|
| ExactWebSocket | pub 的 web_socket_channel 同样走 dart:io，Connection/Upgrade 头被小写化，YY/SOOP 服务器拒绝握手；手写 RFC6455 是唯一解 |
| 纯 Dart brotli（live_net_brotli） | pub `brotli` 包 SDK 约束 <3.0 装不上；WS 载荷解压也必须纯 Dart（不能引 FFI） |
| 无 schema protobuf（抖音弹幕） | `protobuf` 包需要编译期 schema；这里是运行时无 schema 单层解码 |
| 回环中继/FLV 拼接/HLS 预取 | 无任何等价物；直播续租无缝切换的核心 |
| race/throttle/proxy 策略 | dio 只管单请求传输；竞速、按站点节流、全局+站点代理路由是业务层 |
| typed settings | 245 条设置 + 3.x key 映射 + 坏值归一化是领域逻辑 |
| LiveSocket | 多端点故障转移 + 心跳看门狗 + generation 防旧回调，pub 无对应 |
| clock-v1 录制分段/合并 | 精确时长合并 MP4，media_core 方案（TS+CSV）保真度不如它 |

### 4.6 三方库总清单

| 库 | 用途 | 处置 |
|---|---|---|
| dio ^5 | HTTP 传输 | **新增**（替代手写 IoLiveHttp） |
| flutter_riverpod ^3.3.2 / riverpod_annotation ^4.0.3 / riverpod_generator / riverpod_lint | 状态管理 + codegen | **新增**（用户指定版本） |
| freezed_annotation ^3.1.0 / freezed | 不可变模型 | **新增**（用户指定版本） |
| json_annotation ^4.12.0 / json_serializable | JSON 序列化 | **新增**（用户指定版本） |
| flutter_secure_storage | 密钥/Cookie 存储 | **新增**（替代手写 DPAPI/Keystore） |
| webdav_client | WebDAV 备份传输 | **新增**（替代手写客户端） |
| package:html | 容错 HTML 解析 | **新增**（替代手写 html.dart，fixtures 对拍守护） |
| cryptography ^2 | AES-CBC 等站点加密 | **新增**（替代手写 aes.dart） |
| crypto ^3 | 站点签名/SHA | 沿用 |
| xml ^7 | live_iptv XMLTV | 沿用 |
| drift ^2.35 + sqlite3 ^3.7 | 结构化存储 | 沿用 |
| pinyindart | 录制命名拼音 | 沿用 |
| clock / path / meta / collection | 基础 | 沿用 |
| ffmpeg_kit_extended_flutter 0.6.2 | 录制 FFmpeg（本地 bundle 9.0.2） | 沿用 |
| media_kit / fvp / ijk(flv_lzc) / better_player | 播放后端 | 经 media_core 引入，本仓不直接依赖 |
| flame_barrage | 弹幕渲染 | 经 media_core_danmaku 引入（或自定义 Sink，O7） |
| dynamic_color / material_ui | 动态取色 | live_ui_foundation 沿用 |
| remixicon + flutter_svg + CustomIcons.ttf | 图标 | 沿用 |
| qr ^4 | 二维码 | 沿用 |
| flutter_spinkit / loading_animation_widget / loading_indicator | loading 样式 | 沿用 |
| scroll_animator | 滚动动画 | 沿用 |
| go_router ^18 / go_router_builder | 路由（app 壳） | 沿用 |
| flutter_inappwebview 6.2.0-beta.3 | Web 登录（app 壳） | 沿用 |
| bonsoir ^7 | mDNS 设备同步（app 壳） | 沿用 |
| window_manager / tray_manager / screen_retriever | 桌面基础窗口（app 壳） | 沿用（无框/快照归 media_core_win32） |
| path_provider | 平台路径（live_platform） | **新增** |

**明确不引入**：GetX、bloc、easy_localization、hive（新数据全走 drift）、dlna_dart。

---

## 5. 风险与开放问题

| 编号 | 问题 | 影响 | 处置 |
|---|---|---|---|
| O1 | 旧仓 media_kit fork 有 `setVideoOutputEnabled`/`frameRevision` 补丁，media_core pin 的 fork（803c4a2）**不含** | 若 media_core_ui 的截图/帧率能力依赖帧回调，功能缺口 | P5 薄切片验证；缺则把补丁提到 media_core 侧 fork |
| O2 | 双弹幕过滤栈：live_danmaku filters（ReDoS 安全审查、正则屏蔽、表情判定）vs media_core_danmaku DanmakuMessageGate | 过滤能力回退或重复过滤 | P4 后做覆盖度对照，缺口回迁 live_danmaku_filter |
| O3 | 双录制栈：live_record（clock-v1 精确合并）vs media_core_recording_ffmpeg（TS+CSV） | 录制质量口径不一 | 已决策以 live_record 为准；冲突时重新评审 |
| O4 | LineFallback 退役后，续租失败场景是否全被 RecoveryLadder 候选源覆盖 | 边缘场景换线回退缺失 | P5 用 FLV 续租回放用例专项验证 |
| O5 | media_core path 依赖在 CI/他人机器不可用 | 构建断裂 | P0 定 git 依赖切换时间点（P5 联通后） |
| O6 | fixtures 59MB 进 git + 脱敏门禁脚本移植 | 仓库体积与合规 | 保留旧仓脱敏规则，gate 随 P0 移植 |
| O7 | FlameBarrageSink 弹幕样式是否满足旧仓视觉规范 | 弹幕视觉回退 | P5 验证；不满足则自定义 DanmakuSink 复用 EmoteText |
| O8 | 33 站点拆包 + LiveRoom 优先签名改造，import 与函数签名双变 | 纯机械但量大，易漏 | 脚本移动 + 分包跑测试 + fixtures 对拍；签名改造与 P3 站点迁移同批做 |
| O9 | **dio 迁移回归**：dio 的 header 处理、错误分型、代理行为与手写实现存在差异 | 站点请求失败模式变化 | P1 用 ReplayHttp 全量用例对拍 dio 实现；保留 LiveHttp 契约，出问题可回退实现而不动业务 |
| O10 | **freezed/json_serialical 重写模型后 3.x JSON 兼容**：LiveRoom 状态按索引存、限制按名字存、遗留占位名等特殊规则 | 用户旧数据解析失败或丢字段 | 自定义 JsonConverter 承接特殊规则；P2 用 fixtures 的 expected.json + 3.x 备份样本双向对拍 |
| O11 | **flutter_secure_storage 切换后旧密文迁移**：3.x/4.x 早期密文存在文件里，secure_storage 是另一套存储 | 用户 cookie 丢失需重新登录 | legacy 迁移链先解旧密文 → 明文只过内存 → 写入 secure_storage；失败项进 `unreadable` 并提示重登 |
| O12 | **webdav_client 兼容性**：旧自研客户端可能适配过某些自建服务器（非标准路径/digest） | 备份/恢复失败 | P6 用旧用户的常见服务器矩阵验证；不兼容时保留旧实现作为 fallback 策略注入 |
| O13 | codegen 全家桶的构建时长与版本矩阵（build_runner/freezed/json/riverpod 四件套联动升级） | 开发体验、升级成本 | 统一由根 workspace 锁版本；生成物不进 git，CI 缓存 build_runner |

---

## 附：审查数据

- 包规模与测试数见 §1.1；合计迁移量约 **12.4 万行** lib 代码（不含 live_player）+ **210 个测试文件** + 59MB fixtures。
- 源仓库文档体系（docs/STATUS、PROCESS、DECISIONS、tasks.toml）与各包 `record.md` 是迁移时的决策依据，遇到"为什么这样实现"先查旧仓 docs。
- 3.x 基线约束（AGENTS.md）：功能与操作习惯以 3.x 为基线；用户可见文案中英双语；测试不访问真实平台；真实 Cookie/账号不入库。
