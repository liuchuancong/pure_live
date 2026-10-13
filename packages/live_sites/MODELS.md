# Pure Live 数据模型字段规范（MODEL SPEC）

> **状态**：基准稿 v2 · 2026-10-13
> **适用范围**：`packages/live_sites` 全部共享模型；`live_iptv` → `live_sites` 的字段映射。
> **使用方式**：本文档是唯一字段字典。**先改这里，再改代码**；代码评审以本文档为准。
> **目录形态**：模型一类型一目录（`models/<域>/<类型>/`）；枚举独立 `models/enums/` 单文件；converter 独立 `models/converters/` 单文件；每领域一个 barrel。详见 [ARCHITECTURE.md](ARCHITECTURE.md) §3、§9.1a。
> **标记约定**：`[保留]` 现有字段不动；`[改名]` 现有字段重命名（附原名）；`[新增]` 本次补充的字段；`[废弃]` 仅为兼容保留、新代码禁止使用。

---

## 1. 全局命名规范

### 1.1 类型命名

| 规则 | 示例 |
|---|---|
| 共享领域类型带 `Live` 前缀；**子对象/值对象不带**（避免 `LiveRoomLiveBroadcast` 式冗余） | `LiveRoom` → 内含 `RoomBroadcast`、`RoomLinks`、`RoomContent` |
| 一对多集合元素用单数 | `LivePlayLine`（不是 `Lines`） |
| 枚举值 lowerCamelCase，`unknown`/`none` 永远放最后，禁止中间插入 | `LiveStatus.unknown` |
| 能力接口名词为「平台角色」：`XxxProvider` | `LivePlaybackProvider` |
| "身份对"（platform + id）统一叫 `XxxRef`，不叫 `XxxLink`（Link 留给 URL） | `LiveRoomRef` |

### 1.2 字段命名

| 语义 | 规则 | 示例 |
|---|---|---|
| 时间点 | `xxxAt`，**一律 UTC DateTime**，存 ISO-8601 | `startedAt`、`createdAt` |
| 时长/区间 | `xxxMs` / `start`+`end` 成对 | `lease.refreshAt` |
| 数量 | `xxxCount`，**`int?`**（null=未知） | `followerCount` |
| URL | `xxxUrl`（String）；能失败的解析结果用 `Uri?` | `iconUrl`、`homepage` |
| 布尔 | `is/has/can` 前缀 | `isVerified` |
| 平台原始 id | `xxxId`，String，**永不解析其内部结构** | `roomId`、`anchorId` |
| 本地（不上行平台）数据 | 集中在 `RoomLocal`，不混入平台字段 | `RoomLocal.tagIds` |

### 1.3 铁律（工业级模型的底线）

1. **null = 未知/未提供；`0`、`''`、`false` 永远表示已知值。** 禁止哨兵值（旧模型的 `watching='0'` 即违规实例）。
2. 数量字段一律 `int?`，**原始文本（"1.2万"）在适配器边界解析**，展示格式化（`1.2万`）属于 UI 层。
3. 所有存储型实体保留 `createdAt/updatedAt`。**不保留平台原始 payload（rawData 已裁撤）**——schema 变更靠读入层迁移，不靠重解析。
4. 平台特例（Huya 热度、B 站瞬时掉 1）写在**各平台适配器**，共享模型禁止出现平台名字的 switch。
5. 持久化 JSON 的键名 = 字段名（camelCase）。

---

## 1.5 代码生成与构造模式（freezed / json_serializable / equatable）

**手写 `==`、`hashCode`、`copyWith`、`toJson/fromJson` 一律违规——全部交给生成器。** 手写只允许三处：归一化工厂体、业务方法（`mergedWith` 等）、JsonConverter。加一个字段 = 在工厂里声明字段 + `dart run build_runner build`，结束。

### 1.5.1 模型分三类（含目录形态）

| 类别 | 工具链 | 目录形态 | 模型 |
|---|---|---|---|
| **A 值对象**（全字段相等即语义） | `@freezed`（持久化的加 json） | `models/<域>/<类型>/<类型>.{dart,freezed.dart[,g.dart]}` | RoomContent/Links/Local/Runtime、RoomBroadcast、RoomAudience、RoomGuide、GuideCatchUp、PlayQuality/Line/Lease/Geometry、MessageSender、Badge、Emote、Gift 族、SuperChat 族、Page/PageRequest、Search 族、AssetRef |
| **B 身份实体** | `@freezed` + 身份下沉 `LiveRoomRef` | 同上 | LiveRoom、LiveArea、LiveAnchor |
| **C 密封联合** | `@freezed` union | 同上 | LiveLinkResolution、LiveSearchResult、LiveSiteError |

**B 类的相等约定**：freezed 不允许覆写 `==`，因此——

- `LiveRoomRef(platform, roomId)`：freezed 生成全字段相等，**恰好就是身份相等**；
- `LiveRoom` 自身 `==` 是全字段相等（值语义）：同一房间刷新后标题变化 ⇒ 不相等，这是**正确**的；
- **身份比较/去重/合并一律显式走 `room.ref` 或 `ref.identityKey`**（`Set`/`Map` 用 `Map<String, LiveRoom>` keyed by `identityKey`），禁止依赖 `Set<LiveRoom>` 的去重行为。

`equatable` 只用于非模型的不可变手写类（错误详情、配置对象）；模型本体不用。

### 1.5.2 归一化模式：raw 工厂

```dart
@freezed
abstract class LiveRoom with _$LiveRoom {
  const LiveRoom._();

  /// 唯一 redirecting 工厂：字段已归一；copyWith 与 fromJson 生成代码走它。
  @visibleForTesting
  const factory LiveRoom.raw({required LiveRoomRef ref, RoomContent content = const RoomContent()})
      = _LiveRoom;

  /// 业务工厂：先归一（trim/lowercase/UTC/去占位符）再委托 raw。必须幂等。
  factory LiveRoom({required String platform, required String roomId, RoomContent content = const RoomContent()}) =>
      LiveRoom.raw(
        ref: LiveRoomRef(platform: platform.trim().toLowerCase(), roomId: roomId.trim()),
        content: content,
      );

  factory LiveRoom.fromJson(Map<String, Object?> json) => _$LiveRoomFromJson(json);
}
```

要点：`raw` 带默认值（copyWith 不传就保持）；归一化只写在业务工厂体内；fromJson 走 json_serializable 生成的 `_$XxxFromJson`（对旧 schema 的兼容读入放在 `@JsonKey(fromJson:)` 指向的 converter，不放工厂）。

part 指令示例（一类型一目录）：
```dart
part 'live_room.freezed.dart';
part 'live_room.g.dart';
```

### 1.5.3 converters（脏解析的唯一居所）

`models/converters/` 目录独立，**一 converter 一文件**，`converters/converters.dart` 为 barrel：

| Converter | 文件 | 干什么 |
|---|---|---|
| `LiveStatusByNameConverter` | `live_status_by_name_converter.dart` | 枚举 name 字符串读写；读入兼容 v1 index int |
| `EpochMillisConverter` | `epoch_millis_converter.dart` | 毫秒 ↔ `DateTime?`（UTC） |
| `IsoTimeConverter` | `iso_time_converter.dart` | ISO-8601 ↔ `DateTime?`（UTC） |
| `AudienceNumberConverter` | `audience_number_converter.dart` | `"1.2万"/"3,400"` → `int?`（null=未知） |
| `UriStringConverter` | `uri_string_converter.dart` | 字符串 ↔ `Uri?`，非法给 null 不抛 |
| `StringifyConverter` | `stringify_converter.dart` | 平台数字 id → String |

枚举专属 converter **放 `converters/`，不放枚举同文件**——枚举文件保持纯声明，converter 集中统一审查。

### 1.5.4 五件套同升同降

`freezed_annotation / freezed / json_annotation / json_serializable / build_runner`（**`analyzer` 不直接声明**，由 `very_good_analysis` 与生成器牵引）整体升级：升 SDK 约束 → 升五件套 → `dart run build_runner build --delete-conflicting-outputs` → `dart analyze` 全绿 → 源与生成物**同一 PR**提交。生成物永远与源同目录同名，手改生成物直接打回。

当前基准（`packages/live_sites/pubspec.yaml`，`sdk: ^3.13.0`、`resolution: workspace`）：

```yaml
dependencies:
  equatable: ^2.0.7
  freezed_annotation: ^3.1.0
  json_annotation: ^4.12.0

dev_dependencies:
  build_runner: ^2.16.0
  freezed: ^4.0.2
  json_serializable: ^6.14.0
  very_good_analysis: ^11.0.0
```

---

## 2. 枚举字典（全量）

> 所有枚举文件位于 `models/enums/`，**一文件一枚举，纯 `.dart`**，由 `enums/enums.dart` barrel 统一 export。

### 2.1 LiveStatus `[保留]`
文件：`models/enums/live_status.dart`；converter：`models/converters/live_status_by_name_converter.dart`
```dart
enum LiveStatus {
  live,      // 直播中
  replay,    // 录播/回放（可播放但非直播）
  carousel,  // 轮播（主播未开播、平台放录像垫场）
  offline,   // 未开播
  banned,    // 封禁/被切断
  unknown,   // 未知（新增值只能加在 unknown 之前）
}
```

### 2.2 LiveRestriction `[保留]`
文件：`models/enums/live_restriction.dart`
```dart
enum LiveRestriction {
  none, needsLogin, paid, subscribersOnly, private, appOnly, regionBlocked, password, adult, unplayable,
}
```

### 2.3 LiveFollowGroup `[保留]`
文件：`models/enums/live_follow_group.dart`
```dart
enum LiveFollowGroup { live, replay, offline }
```

### 2.4 LiveStreamFormat `[扩充]`（原名保留，值补全）
文件：`models/enums/live_stream_format.dart`
```dart
enum LiveStreamFormat {
  flv,     // HTTP-FLV 长连接流（douyu/huya 常见，后缀 .flv）
  hls,     // HLS 播放列表（.m3u8）
  dash,    // DASH 清单（.mpd，YouTube/部分海外站）
  rtmp,    // RTMP 直播流（少数站点直接下发）
  rtsp,    // RTSP（摄像头源）
  udp,     // IPTV 组播 udp://@239.x.x.x:port（udpxy 转换后变 http+mpegts）
  rtp,     // RTP 封装
  webrtc,  // WebRTC 拉流（SDP/WHIP/WHEP 或私有信令，如部分海外站）
  mpegts,  // 裸 MPEG-TS over HTTP（IPTV 单播、.ts 后缀、无后缀 TS 流）
  mp4,     // MP4 点播/回放文件
  other,   // 单一 HTTP(S) 响应、容器只能靠首字节探测
}
```
**配套工具（必须提供，平台与 IPTV 共用）**，位于 `models/play/infer_stream_format.dart`（纯函数，无生成物）：
```dart
/// 从 URL 推断流格式：后缀 → 枚举；推断不出返回 null（不得编造 other）。
LiveStreamFormat? inferStreamFormat(String url);
// 规则表：.m3u8→hls  .flv→flv  .mpd→dash  .ts→mpegts  .mp4→mp4
//          scheme udp://→udp  rtp://→rtp  rtsp://→rtsp  rtmp(s)://→rtmp
// udpxy 路径特征（/udp/、/rtp/）→ mpegts
```

### 2.5 LiveStreamCodec `[新增]`（替代 PlayLine.codec 的 String?）
文件：`models/enums/live_stream_codec.dart`
```dart
enum LiveStreamCodec {
  avc,     // H.264（平台标注 avc/h264）
  hevc,    // H.265（hevc/h265）
  av1,
  vp9,
  unknown, // 平台未声明（保留探测回退）
}
```

### 2.6 LivePlayFormatSource `[新增]`
文件：`models/enums/live_play_format_source.dart`
```dart
enum LivePlayFormatSource {
  declared, // 平台在响应里明确说了（可信）
  inferred, // 由 inferStreamFormat(url) 从后缀/协议猜的（可能错）
}
```
> 用途：`LivePlayLine.format` 必填后，播放器需要知道"这是平台声明还是后缀猜测"，猜测错误的格式要允许被首字节探测推翻。

### 2.7 LiveMessageType `[改名+扩充]`
文件：`models/enums/live_message_type.dart`
```dart
enum LiveMessageType {
  chat,           // 普通弹幕
  gift,           // 礼物（data: LiveGift）
  audienceUpdate, // [改名] 原 online —— 观众数变化（data: LiveAudienceUpdate）
                  // "online"语义像"进入直播间"，必须改
  superChat,      // 醒目留言
  retraction,     // 撤回（data: LiveRetraction）
  notice,         // 平台横幅通知（data: LiveNoticeKind）
  enter,          // [新增] 进入直播间（douyin/bilibili/huya 均有）
  leave,          // [新增] 离开直播间
  follow,         // [新增] 关注主播
  like,           // [新增] 点赞（抖音 like 气泡）
  membershipJoin, // [改名] 原 memberJoin —— 加入粉丝团/舰长/守护（身份变更，与 gift 区分：
                  //  B站上舰、抖音粉丝团、douyu贵族均归此类）
  system,         // [新增] 系统广播（开播通知、禁言、切麦等）
}
```

### 2.8 LiveAudienceMetricType `[保留]`（`RoomAudience.primaryMetric` 的类型；v1 `watching` 的含义来源）
文件：`models/enums/live_audience_metric_type.dart`
```dart
enum LiveAudienceMetricType { popularity, onlineViewers, totalViewers, followers, unknown }
```

### 2.9 LiveAudienceSignalKind `[改名]`（原 LiveAudienceMetricKind —— 实时消息里的信号种类）
文件：`models/enums/live_audience_signal_kind.dart`
```dart
enum LiveAudienceSignalKind { popularity, onlineViewers, totalViewers }
```
> 原 `MetricKind/MetricType` 一字之差、语义不同（消息信号 vs 记录指标），必改。

### 2.10 LiveAudienceOnlineAvailability `[保留]`
文件：`models/enums/live_audience_online_availability.dart`
```dart
enum LiveAudienceOnlineAvailability { unsupported, roomRealtime, roomList }
```

### 2.11 LiveGiftKind `[规范]`
文件：`models/enums/live_gift_kind.dart`
```dart
enum LiveGiftKind {
  normal,       // 普通虚拟礼物（原 gift）
  subscription, // 开通身份类：舰长/贵族/守护（平台常以礼物形式下发）
  tip,          // 现金打赏类
}
```

### 2.12 LiveGiftUnit `[扩充]`
文件：`models/enums/live_gift_unit.dart`
```dart
enum LiveGiftUnit {
  silver,   // 平台免费币（B站瓜子、虎牙金豆的免费档）
  gold,     // 平台付费币（电池/虎牙币/抖币）
  rmb,      // 人民币元
  point,    // 积分/亲密度
  free,     // 无价值礼物
  other,
}
```

### 2.13 LiveMessagePlacement / LiveNoticeKind / LiveSearchTarget / LiveAssetType `[保留]`
文件：分别 `models/enums/live_message_placement.dart`、`live_notice_kind.dart`、`live_search_target.dart`、`live_asset_type.dart`
```dart
enum LiveMessagePlacement { scroll, top, bottom }
enum LiveNoticeKind { system, subscription, raid, giftedSubscription }
enum LiveSearchTarget { rooms, anchors, areas }
enum LiveAssetType { bundled, remote, platformDefault }
```

### 2.14 LiveAnchorRole `[新增]`
文件：`models/enums/live_anchor_role.dart`
```dart
enum LiveAnchorRole { anchor, moderator, viewer, platform, system }
```

### 2.15 LiveRoomActivity `[新增]`（直播间活动形态，douyu videoType / PK / 连麦）
文件：`models/enums/live_room_activity.dart`
```dart
enum LiveRoomActivity {
  none,     // 普通直播
  pk,       // 主播 PK（连麦对战）
  coStream, // 连麦/多人共同直播
  radio,    // 电台/纯音频
  carousel, // 轮播垫场（对应 LiveStatus.carousel 的活动侧描述）
}
```

---

## 3. 模型字段字典

> 每个模型的目录见下表；`part` 指令（`.freezed.dart`/`.g.dart`）与源同目录同名。

### 3.0 类型 → 目录速查

| 模型 | 目录 |
|---|---|
| `LiveRoom` | `models/room/live_room/` |
| `LiveRoomRef` | `models/room/live_room_ref/` |
| `RoomBroadcast` | `models/room/room_broadcast/` |
| `RoomContent` | `models/room/room_content/` |
| `RoomLinks` | `models/room/room_links/` |
| `RoomAudience` | `models/room/room_audience/` |
| `RoomLocal` | `models/room/room_local/` |
| `RoomRuntime` | `models/room/room_runtime/` |
| `LiveAnchor` | `models/anchor/live_anchor/` |
| `LiveArea` | `models/area/live_area/` |
| `LiveAudienceUpdate` | `models/audience/live_audience_update/` |
| `RoomGuide` | `models/guide/room_guide/` |
| `GuideCatchUp` | `models/guide/guide_catch_up/` |
| `LiveMessage` | `models/message/live_message/` |
| `MessageSender` | `models/message/message_sender/` |
| `LiveBadge` | `models/message/live_badge/` |
| `LiveEmote` | `models/message/live_emote/` |
| `LiveMessageColor` | `models/message/live_message_color/` |
| `LiveMessageStyle` | `models/message/live_message_style/` |
| `LiveRetraction` | `models/message/live_retraction/` |
| `LiveGift` | `models/gift/live_gift/` |
| `LiveGiftValue` | `models/gift/live_gift_value/` |
| `LiveGiftCombo` | `models/gift/live_gift_combo/` |
| `LiveSuperChatMessage` | `models/super_chat/live_super_chat_message/` |
| `SuperChatPrice` | `models/super_chat/live_super_chat_price/` |
| `SuperChatDisplay` | `models/super_chat/live_super_chat_display/` |
| `LivePlayQuality` | `models/play/live_play_quality/` |
| `LivePlayLine` | `models/play/live_play_line/` |
| `LivePlayLease` | `models/play/live_play_lease/` |
| `PlayGeometry` | `models/play/play_geometry/` |
| `inferStreamFormat` | `models/play/infer_stream_format.dart`（纯函数，无生成物） |
| `LiveSearchRequest` | `models/search/live_search_request/` |
| `LiveSearchResult` | `models/search/live_search_result/` |
| `LivePageRequest` | `models/page/live_page_request/` |
| `LivePage<T>` | `models/page/live_page/` |
| `LiveAssetRef` | `models/asset/live_asset_ref/` |

### 3.1 LiveRoom（聚合根）· `models/room/live_room/`

```dart
final class LiveRoom {
  // ── 身份（沉淀在 LiveRoomRef；LiveRoom 的 == 是全字段值相等，见 §1.5.1）──
  final LiveRoomRef ref;              // [新增] platform+roomId 身份对；身份比较/去重/合并一律走它
  final String platform;              // [保留] ref.platform 便捷访问，小写平台 id
  final String roomId;                // [保留] ref.roomId 便捷访问，平台内房间号 opaque
  final String identityKey;           // [保留] ref.identityKey（大小写归一见 SiteIds）

  // ── 日期 ────────────────────────────────────────────────
  final DateTime? createdAt;          // [保留] 首次入库，UTC
  final DateTime? updatedAt;          // [保留] 最近刷新，UTC

  // ── 子对象（每个关注点一个类型，字段不直接挂在 room 上）────
  final LiveAnchor? anchor;           // 主播（列表接口可能不给）
  final LiveArea? area;               // 分区（含父分区）
  final RoomAudience audience;        // 观众数值
  final RoomBroadcast broadcast;      // 播出状态
  final RoomContent content;          // 展示文本（标题/封面/简介/公告）
  final RoomLinks links;              // 各类链接
  final RoomGuide guide;              // IPTV 节目单/回看
  final RoomLocal local;              // 本地数据（收藏标签/观看时间）
  final RoomRuntime runtime;          // 瞬态句柄（永不持久化）
}
```

### 3.2 RoomBroadcast `[改名]`（原 LiveBroadcast）· `models/room/room_broadcast/`

```dart
final class RoomBroadcast {
  final LiveStatus? liveStatus;      // [保留] null=未说明（≠unknown：unknown 是显式未知）
  final DateTime? startedAt;         // [保留] 本场开播时间，UTC
  final LiveRestriction? restriction;// [保留] 播放限制
  final LiveRoomActivity activity;   // [新增] PK/连麦/电台，默认 none
}
```

### 3.3 RoomContent `[改名]`（原 LiveRoomContent）· `models/room/room_content/`

```dart
final class RoomContent {
  final String title;        // [保留] 房间标题（已去不可见占位符）
  final String coverUrl;     // [改名] 原 cover —— 遵守 xxxUrl 规则
  final String? introduction;// [保留] 简介
  final String? notice;      // [保留] 公告
  final List<LiveBadge> badges;      // [新增] 房间级徽章（付费等级、直播状态角标）
  final List<String> platformTags;   // [新增] 平台打的直播间标签（≠本地 local.tagIds）
}
```

### 3.4 RoomLinks `[改名]`（原 LiveRoomLinks）· `models/room/room_links/`

```dart
final class RoomLinks {
  final String? webUrl;     // [改名] 原 link —— 网页版地址
  final String? appUrl;     // [改名] 原 nativeLink —— App 唤起 scheme（bilibili://live/23058）
  final String? shareUrl;   // [新增] 分享短链（平台生成的推广链接）
}
```
> 同时删除 `LiveRoomLink`（platform+roomId 身份对）这个名字，改叫 **`LiveRoomRef`** —— 与 RoomLinks 仅一字母之差、语义完全不同，是事故级命名。

### 3.5 RoomAudience `[改名]`（原 LiveAudience —— 数值 int? 化）· `models/room/room_audience/`

```dart
final class RoomAudience {
  final int? popularity;     // 平台热度/人气值，非人头数（bilibili 人气值、douyu 热度、huya iAttendeeCount）
  final int? onlineViewers;  // 并发观看人数（twitch/soop/kuaishou 的同时在线）
  final int? totalViewers;   // 本场累计观看（douyin 累计观看、bilibili WATCHED_CHANGE）
  final LiveAudienceMetricType? primaryMetric; // [改名] 原 metricType —— 列表卡片主打上面哪个数
                             //（v1 watching 字段的含义来源；跨平台排序的标签依据）
  // [废弃] watching：仅为旧持久化记录读入保留，读入时按 primaryMetric 归位到上面三个 int? 之一；
  //         "1.2万" 等原始文本由适配器边界 parseAudienceNumber 解析后即弃（不存储）
}
```

### 3.6 RoomLocal `[改名]`（原 LiveRoomLocal）· `models/room/room_local/`

```dart
final class RoomLocal {
  final DateTime? lastWatchedAt; // [改名] 原 int? epoch ms —— 时间点统一 UTC DateTime（持久化走 EpochMillisConverter）
  final List<String> tagIds;     // 本地收藏分组标签（≠平台标签 RoomContent.platformTags）
  final int? watchDurationMs;    // 累计观看时长（时长用 Ms 后缀命名，区别于时间点）
}
```

### 3.7 RoomRuntime `[改名]`（原 LiveRoomRuntime —— 瞬态句柄）· `models/room/room_runtime/`

```dart
final class RoomRuntime {
  final Object? streamHandle;   // [改名] 原 data/streamDescriptor —— 取流所需的平台句柄
  final Object? danmakuHandle;  // [改名] 原 danmakuData —— 连弹幕所需的平台句柄
  // 句柄 = 不透明令牌：只有产出它的平台代码理解，永不序列化、永不跨平台传递
}
```

### 3.8 LiveAnchor `[保留+补]` · `models/anchor/live_anchor/`

```dart
final class LiveAnchor {
  final String platform;        // 小写平台 id
  final String anchorId;        // 主播 uid（≠roomId：B站/抖音两者必须分开）
  final String name;            // 显示名（已去不可见占位符）
  final String? avatarUrl;      // 头像图
  final String? profileUrl;     // 主播主页（space.bilibili.com/…、live.douyin.com/…）
  final int? followerCount;     // 粉丝数
  final String? introduction;   // 主播签名/简介
  final bool? isVerified;       // 官方认证/加 V
  final int? anchorLevel;       // [改名] 原 level —— 平台给主播的等级（避免与 MessageSender.userLevel 混淆）
  final LiveStatus? liveStatus; // 搜索主播列表时单独给出
}
```

### 3.9 LiveArea `[保留+补]` · `models/area/live_area/`

```dart
final class LiveArea {
  final String platform;        // 小写平台 id
  final String areaId;          // 子分区 id（identityKey 组成部分）
  final String areaName;        // 子分区名（"英雄联盟"）
  final String? parentAreaId;   // [改名] 原 areaType —— 父分区 id（"网游"）；
                                //  missevan 把它当目录命名空间用（见 SiteIds.identityKeyFor 注释）
  final String? parentAreaName; // [改名] 原 typeName —— 父分区名
  final String? iconUrl;        // [改名] 原 areaPicUrl —— 分区图标
  final String? shortName;      // 短名（IPTV 分组首字母）
  final int? position;          // 平台排序号
}
```

### 3.10 RoomGuide `[改名]`（原 LiveGuide —— IPTV 专属）· `models/guide/room_guide/`

```dart
final class RoomGuide {
  final String? epgId;                         // [保留] EPG 频道 id（= IptvEntry.tvgId / EpgChannel.channelId）
  final String currentProgramme;               // [保留] 当前节目名
  final String? currentProgrammeDescription;   // [保留] 节目描述
  final GuideCatchUp catchUp;                  // 见 3.11
  final Map<String, String> httpHeaders;       // [保留] 该频道媒体请求专用头（Referer/UA）
}
```

### 3.11 GuideCatchUp `[改名]`（原 LiveCatchUp）· `models/guide/guide_catch_up/`

```dart
final class GuideCatchUp {
  final String? url;             // 回看播放地址（已解析实例；与 urlTemplate 二选一）
  final bool active;             // 正在回看中
  final int? start;              // 回看区间起，epoch ms
  final int? end;                // 回看区间止，epoch ms
  final String? mode;            // M3U 属性 catchup 的取值（append/default/flvlive…），
                                 //  决定 urlTemplate 如何拼参
  final String? urlTemplate;     // [改名] 原 source —— catchup-source URL 模板（{utc}/{start} 占位符）
  final double? windowDays;      // [改名] 原 days —— 回看窗口大小（天），M3U catchup-days
  final double? correctionHours; // EPG 时间戳与流内容的偏差校正（小时），catchup-correction
  final String? catchupId;       // 节目级回看 id（= EpgProgramme.catchupId）
}
```

### 3.12 LiveMessage（弹幕消息）· `models/message/live_message/`

```dart
final class LiveMessage {
  final LiveMessageType type;    // 消息种类（决定 payload 的类型，见 §5 契约表）
  final String text;             // [改名] 原 message —— 正文（礼物时为礼物的 plainText，通知时为通知文本）
  final MessageSender sender;    // 发送者（见 3.13；系统消息 role=system）
  final LiveMessageColor color;  // 弹幕颜色（仅 chat 有意义）
  final LiveMessageStyle? style; // 本地消息样式（仅 isLocal 时非 null）
  final Object? payload;         // [改名] 原 data —— 类型化负载，按 type 定型（gift→LiveGift、
                                 //   audienceUpdate→LiveAudienceUpdate、retraction→LiveRetraction、
                                 //   notice→LiveNoticeKind；见 §5 契约表）
  final List<LiveEmote> emotes;  // 文本中的表情码与图（每个 code 一次）
  final String messageId;        // 平台消息 id（重连重放去重；''=平台未给）
  final DateTime? sentAt;        // 平台时间戳，UTC（null=平台未给，按到达顺序展示）
  final DateTime? createdAt;     // 本地记录时间，UTC（仅录制回放）
  final bool isLocal;            // 本机合成（自己发的弹幕）
  final bool replayed;           // 重连重放/入房补发（非实时发生）
  final String sourceRoomId;     // 消息实际所属房间（PK 对端房间，Kugou）；''=当前房间
}
```

### 3.13 MessageSender `[改名]`（原 LiveMessageSender —— 补头像/角色）· `models/message/message_sender/`

```dart
final class MessageSender {
  final String userId;        // 平台用户 id（''=系统/匿名）
  final String userName;      // 显示名
  final String? avatarUrl;    // 头像（聊天记录回放必需）
  final String? userLevel;    // 平台用户等级（B站 UL、斗鱼用户等级），显示在昵称旁
  final String fanBadgeLevel; // [改名] 原 fansLevel —— 粉丝勋章等级（B站 21 级）；''=未佩戴
  final String fanBadgeName;  // [改名] 原 fansName —— 粉丝勋章名（即直播间名）；''=未佩戴
  final LiveMessageColor? nameColor; // 昵称颜色（房管绿/舰长粉等平台配色）
  final List<LiveBadge> badges;      // 佩戴的徽章图列表（17live styleID 等）
  final LiveAnchorRole role;         // 发言者身份：anchor/moderator/viewer/platform/system
  final int? membershipTier;         // [改名] 原 guardLevel —— 付费身份档位
                                     //  （B站 3=总督/2=提督/1=舰长；douyu/huya 贵族档；null=无）
}
```

### 3.14 LiveBadge / LiveEmote / LiveMessageColor / LiveMessageStyle / LiveRetraction `[保留]`
目录：`models/message/live_badge/`、`live_emote/`、`live_message_color/`、`live_message_style/`、`live_retraction/`
```dart
final class LiveBadge { final String url; final String id; }        // id='' 平台未给
final class LiveEmote { final String code; final String url; }
final class LiveMessageColor { final int r, g, b; }                  // white / numberToColor 工厂保留
final class LiveRetraction { final String? userId; final String? messageId; final bool all; }
```

### 3.15 LiveGift · `models/gift/live_gift/`

```dart
final class LiveGift {
  final String giftId;         // 礼物 id（连击合并、礼物图鉴的键）
  final String name;           // 礼物名（"小花"）
  final String? iconUrl;       // 礼物图标
  final LiveGiftKind kind;     // normal/subscription/tip
  final int count;             // 本次赠送数量（一次连击送 N 个；累计看 combo.comboTotal）
  final LiveGiftValue value;   // 计价（见 3.16）
  final LiveGiftCombo combo;   // 连击状态（见 3.17；comboKey=''=平台无连击概念）
  final String recipientName;  // [改名] 原 receiverName —— 收礼人（PK 对端主播名）；''=当前主播
}
```

### 3.16 LiveGiftValue `[保留]` · `models/gift/live_gift_value/`

```dart
final class LiveGiftValue {
  final LiveGiftUnit unit;   // 计价单位（free=免费礼物，此时 unitPrice/totalValue 均无意义；
                             //  不再单设 free 布尔，unit 已表达）
  final double? unitPrice;   // 单个礼物在 unit 下的价格（null=平台未给）
  final double? totalValue;  // 本次赠送总价值（含数量；null=平台未给）
}
```

### 3.17 LiveGiftCombo `[保留]` · `models/gift/live_gift_combo/`

```dart
final class LiveGiftCombo {
  final String comboKey;   // 连击分组键（平台 comboId；''=无）
  final int? comboTotal;   // 连击累计个数（B站 combo_total）
}
```

### 3.18 LiveSuperChatMessage / SuperChatPrice / SuperChatDisplay `[保留]`
目录：`models/super_chat/live_super_chat_message/`、`live_super_chat_price/`、`live_super_chat_display/`
```dart
final class LiveSuperChatMessage {
  final String messageId;        // 平台事件 id（快照去重主键；''=平台未给，按用户+文本+价格判等）
  final String userName;         // 买家昵称
  final String faceUrl;          // 买家头像
  final String text;             // [改名] 原 message —— 留言正文
  final SuperChatPrice price;    // 价格（见下）
  final DateTime startTime;      // 展示开始，UTC
  final DateTime endTime;        // 展示结束，UTC（倒计时依据）
  final SuperChatDisplay display;// 展示配色（见下）
}

final class SuperChatPrice {
  final int? amount;         // 数额（平台原生数值；null=平台未给）
  final String? currency;    // 币种代码（CNY/JPY/USD…；null=平台未给）
  final String displayText;  // 平台已格式化的价格文本（"￥50"、"50元"），UI 直接展示
}

final class SuperChatDisplay {
  final String backgroundColor;       // 主背景色，#RRGGBB（bilibili SC 的红金渐变主色）
  final String backgroundBottomColor; // 底部/价格栏背景色，#RRGGBB
}
```

### 3.19 播放族 · `models/play/`

```dart
// models/play/live_play_quality/
final class LivePlayQuality {
  final String label;               // [改名] 原 quality —— 显示名（"原画蓝光10M"、"超清"）
  final String? qualityId;          // [改名] 原 selectionId(id+data) —— 平台画质 id，请求时原样回传
                                    //  （bilibili qn=80、douyu rate=0）；适配器边界统一转 String
  final int platformOrder;          // [改名] 原 sort —— 平台原生顺序（0=平台首推）
  final bool isPlaybackUnconfirmed; // 服务器实际下发的画质未确认（游客被降清时）
  final LiveStreamCodec? codec;     // 该画质的视频编码（同画质多编码时区分线路）
}

// models/play/live_play_line/
final class LivePlayLine {
  final String url;                    // 可直接交给播放器的地址
  final Map<String, String> headers;   // 该线路专用请求头（Referer/UA/Cookie）
  final LiveStreamFormat format;       // 必填：流格式（探测不出给 other，见 §2.4）
  final LivePlayFormatSource formatSource; // declared=平台声明 / inferred=后缀推断（可被探测推翻）
  final LiveStreamCodec? codec;        // 视频编码；null=未声明
  final String? lineLabel;             // [改名] 原 lineId —— 展示用线路名（"主线/备线/华为CDN"）
  final LivePlayLease? lease;          // 短时效签名续租（null=长期有效）
  final PlayGeometry geometry;         // 声明的分辨率/帧率/码率
}

// models/play/live_play_lease/
final class LivePlayLease {
  final DateTime refreshAt;        // 此刻前应换新 URL（提前续租）
  final DateTime? expiresAt;       // 此刻后旧 URL 必失效
  final bool requiresReconnect;    // [改名] 原 cutsConnection —— 换用新 URL 是否必须断开重连
}

// models/play/play_geometry/
final class PlayGeometry {
  final int? width;        // 声明分辨率宽（px）
  final int? height;       // 声明分辨率高（px）
  final int? frameRate;    // 声明帧率（fps；海外站 60fps 线路）
  final int? bitrateKbps;  // 声明码率（画质排序/省流模式用）
}
```

### 3.20 分页与搜索 `[保留]`
目录：`models/page/live_page_request/`、`live_page/`、`models/search/live_search_request/`、`live_search_result/`
```dart
final class LivePageRequest { final int page; final int pageSize; final int? offset; final String? cursor; }
final class LivePage<T>      { final List<T> items; final int? totalCount; final String? nextCursor; final bool? hasMore; }
final class LiveSearchRequest { final String query; final LiveSearchTarget target; final int page; final int pageSize; }
// LiveSearchResult: sealed — .room(LiveRoom) / .anchor(LiveAnchor) / .area(LiveArea)
```

### 3.21 平台元数据 `[保留]`
```dart
// LiveSiteManifest: id/name(多语言)/version/contractVersion/description/aliases/
//                   author/license/homepage/icon(LiveAssetRef)/assets/supportedPlatforms
// LiveAssetRef（models/asset/live_asset_ref/）: type(bundled/remote/platformDefault) + path/uri/fallback
// LiveRoomRef（models/room/live_room_ref/，原 LiveRoomLink）: platform + roomId 身份对
// LiveLinkResolution: sealed — LiveLinkRoom(roomId) / LiveLinkRedirect(Uri)
```

---

## 4. LiveSiteError 摘要 `[保留]`
```
LiveSiteError (sealed)
├─ LiveSiteNotFound         房间/源不存在
├─ LiveSiteUnsupported      平台不支持该能力
├─ LiveSiteNetworkError     网络失败（含 cause）
├─ LiveSiteParseError       响应形状损坏（含 cause）
├─ LiveSiteAuthenticationError 需要登录/凭证失效
├─ LiveSiteRateLimitError   限流
├─ LiveSiteContentUnavailable  内容不可用（在播但无流推送，重试无意义）
├─ LiveSiteInvalidArgument  参数不合法
└─ LiveSiteUnexpectedError  兜底（含 cause）
```

---

## 5. LiveMessage.payload 负载契约（必须遵守的枚举→类型表）

| type | payload 类型 | 说明 |
|---|---|---|
| gift | `LiveGift` | 本地礼物为 Map |
| audienceUpdate | `LiveAudienceUpdate` | 旧引擎可能发 int，读取端需兼容 |
| retraction | `LiveRetraction` | |
| notice | `LiveNoticeKind` | 正文在 text |
| superChat | null | SC 走独立列表接口，不经弹幕流（现状保留） |
| 其余 | null | enter/leave/follow/like/membershipJoin/system 信息在 sender+text |

---

## 6. IPTV（live_iptv）→ live_sites 映射表

| IptvEntry / Epg 模型字段 | live_sites 目标字段 | 备注 |
|---|---|---|
| `IptvEntry.name` | `content.title`（兜底 `anchor.name`） | 频道名 |
| `IptvEntry.url` | `LivePlayLine.url`（首线） | `alternatives` → 后续线路 |
| `IptvEntry.group` | `area.areaName`（`parentAreaName`=null） | 分组即分区 |
| `IptvEntry.tvgId` | `guide.epgId` | EPG 对齐键 |
| `IptvEntry.tvgLogo` | `content.coverUrl` | 频道台标 |
| `IptvEntry.channelNumber` | `area.shortName` 或 `local` | 按排序需求定 |
| `IptvEntry.headers` | `guide.httpHeaders` | 每频道请求头 |
| `IptvEntry.catchupSource/catchupMode/catchupDays` | `guide.catchUp.urlTemplate/mode/windowDays` | |
| `EpgProgramme.title` | `guide.currentProgramme` | 匹配当前时段 |
| `EpgProgramme.description/subtitle` | `guide.currentProgrammeDescription` | |
| `EpgProgramme.start/stop` | `guide.catchUp.start/end`（回看区间） | |
| `EpgProgramme.catchupId` | `guide.catchUp.catchupId` | 节目级回看 |
| `EpgChannel.iconUrl` | `content.coverUrl` 兜底 | |
| `IptvStreamType.hls/flv` | `LiveStreamFormat.hls/flv` | 枚举对齐 |
| `IptvStreamType.other` | 用 `inferStreamFormat(url)` 细分 | `.ts`→mpegts、`.mp4`→mp4、udpxy→mpegts |
| `IptvChannel.favorite/pinned/hidden/position` | `RoomLocal`（本地域） | 不上移到共享模型 |

---

## 7. 持久化 JSON schema 键名（收藏/历史/备份）

现有扁平键**继续兼容读入**；新写入遵循本表（键名=字段名）。旧键 → 新键迁移在读入层完成，存储层只认识新键。

| 旧键（现 toJson） | 新键 | 说明 |
|---|---|---|
| `watching` | 删除（读入时按 metricType 归位到 popularity/onlineViewers/totalViewers） | 哨兵 `'0'` 消灭 |
| `popularity/onlineViewers/totalViewers`（String） | 同名 **int?** | "1.2万"在适配器解析 |
| `cover` | `coverUrl` | |
| `link` / `nativeLink` | `webUrl` / `appUrl` | |
| `nick/avatar/userId/followers` | 嵌套 `anchor: {…}` | 收藏文件已嵌套存储 `area`，anchor 同理 |
| `area`（字符串或对象） | 仅对象 `{areaId,areaName,parentAreaId,parentAreaName,…}` | 读入兼容字符串 |
| `liveStatus`（index int） | 同名，**改为 name 字符串**（`'live'`） | index 对枚举插值脆弱；读入兼容 int |
| `isRecord`/`status` | 删除，统一为 `liveStatus` | 读入时折算 |
| `tagIds/lastWatchedAt` | `local: {tagIds,lastWatchedAt,watchDurationMs}` | |
| `epgId/currentProgramme/…/catchUp*/httpHeaders` | `guide: {…}` | |
| `roomId/platform/createdAt/updatedAt/startedAt/restriction` | 保持 | |
| —（新增） | `broadcast.activity`、`content.badges/platformTags`、`links.shareUrl` | |

> **schemaVersion**：新写入顶层加 `"schemaVersion": 2`，读入端无此键按 v1 兼容路径走。

---

## 8. 改名迁移对照表（现有 → 目标）

| 现有 | 目标 | 原因 |
|---|---|---|
| `LiveRoomLink` | `LiveRoomRef` | 与 RoomLinks 混淆，语义是"身份引用" |
| `LiveRoomLinks` | `RoomLinks` | 子对象去 Live 前缀 |
| `LiveRoomContent` | `RoomContent` | 同上 |
| `LiveBroadcast` | `RoomBroadcast` | 同上 |
| `LiveAudience` | `RoomAudience` | 同上（`LiveAudienceUpdate` 保留，消息域） |
| `LiveRoomLocal` | `RoomLocal` | 同上 |
| `LiveRoomRuntime` | `RoomRuntime` | 同上 |
| `LiveGuide` | `RoomGuide` | 同上 |
| `LiveCatchUp` | `GuideCatchUp` | 属于 guide 域 |
| `LivePlayGeometry` | `PlayGeometry` | 同上 |
| `LiveMessageSender` | `MessageSender` | 同上 |
| `LiveAudienceMetricKind` | `LiveAudienceSignalKind` | 与 MetricType 一字之差 |
| `LiveMessageType.online` | `LiveMessageType.audienceUpdate` | 语义错误 |
| `LiveRoom.cover` 等访问器 | `coverUrl` 等带 Url | 命名规则统一 |
| `LivePlayQuality.id`+`.data` | `qualityId`（String?） | 请求时回传给平台的画质 id（qn/rate），边界统一转 String |
| `LivePlayQuality.quality` | `label` | 显示名，与 id 区分 |
| `LivePlayQuality.sort` | `platformOrder` | "排序"谁排的不明确 |
| `LivePlayLine.lineId` | `lineLabel` | 是展示名不是稳定 id |
| `LivePlayLease.cutsConnection` | `requiresReconnect` | 主语不明 |
| `LiveMessage.message` | `text` | 与类名/类型重复，正文语义 |
| `LiveMessage.data` / `RoomRuntime.data` | `payload` / `streamHandle`、`danmakuHandle` | "data"无信息量；句柄=不透明令牌 |
| `MessageSender.fansLevel/fansName` | `fanBadgeLevel/fanBadgeName` | 准确概念是粉丝勋章 |
| `MessageSender.guardLevel` | `membershipTier` | guard 是 B站黑话；跨平台统一为付费身份档 |
| `LiveMessageType.memberJoin` | `membershipJoin` | 与 membershipTier 对称 |
| `LiveAnchor.level` | `anchorLevel` | 与用户等级区分；`secondaryRoomId` 删除（无平台出处） |
| `LiveArea.areaType/typeName/areaPicUrl` | `parentAreaId/parentAreaName/iconUrl` | areaType 实际是父分区 id；分区图用 icon |
| `GuideCatchUp.source/days` | `urlTemplate/windowDays` | source 无信息量；days 是窗口大小 |
| `RoomAudience.metricType` | `primaryMetric` | "主数值"说不清是谁的主数值 |
| `LiveGift.receiverName` | `recipientName` | 收礼人标准英文 |
| `LiveGiftValue.free` | 删除 | `unit=free` 已表达，双份状态 |
| `RoomLocal.lastWatchedAt: int?` | `DateTime?` | 遵守 §1.2 时间点规则 |
| `LiveSuperChatMessage.face/message` | `faceUrl/text` | 命名规则统一 |
| `PlayLine.codec: String?` | `LiveStreamCodec?` + `formatSource` | 类型安全+可信度 |
| `IptvStreamType` | 由 `LiveStreamFormat` + `inferStreamFormat` 取代 | 消除双枚举 |

---

## 9. 落地顺序建议（对照本文档改代码时）

0. **目录重构**：按 ARCHITECTURE §3 新树建 `models/<域>/<类型>/` 与 `models/enums/`、`models/converters/`；每领域加 barrel（含 `enums/enums.dart`、`converters/converters.dart`）；`dart run build_runner build --delete-conflicting-outputs` 确认生成物与新目录对齐。
1. **枚举先行**：§2 全部枚举定稿（进 `models/enums/`，纯 `.dart`；converter 进 `models/converters/`），含 `inferStreamFormat` 工具+单测，枚举是最多处引用的底座。
2. **播放族**（§3.19）：format 必填 + codec 枚举 + formatSource，连同 live_iptv 的 `IptvStreamType` 一起切换。
3. **RoomAudience int? 化**（§3.5）+ 持久化读写兼容（§7）：一步到位，杜绝半 String 半 int。
4. **消息族**（§3.12–3.14）：找回 `avatarUrl`、新增 role/membershipTier、扩展 MessageType。
5. **Room 子对象改名**（§8 表）：纯重命名，IDE/分析器兜底。
6. **字段补齐**（§3 各 `[新增]`）：按平台迁移节奏逐个补，禁止一次全铺（避免无适配器验证的死字段）。
7. 每步跑 `dart format` + `dart analyze` + 既有测试；新字段必须带平台出处注释（哪个站哪个接口的哪个键）。
