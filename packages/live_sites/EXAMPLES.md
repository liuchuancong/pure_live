# Live Sites 目录实例与文件模板（EXAMPLES）

> **地位**: [ARCHITECTURE.md](ARCHITECTURE.md) §3 目录结构的**实例化展开**；[MODELS.md](MODELS.md) 字段规范的**代码骨架示范**。
> **用法**: 新建平台/模型/测试时，复制本文对应骨架改名填肉。本文代码是**模板**（`.md` 内嵌，不参与编译）；以骨架为准起步，细节以两份规范文档为准。
> **样板平台**: `douyu`（纯 REST、无签名，Phase 2 首迁）。
> **目录形态**: 模型一类型一目录（`models/<域>/<类型>/`）；枚举独立 `models/enums/` 单文件；converter 独立 `models/converters/` 单文件；每领域一个 barrel。

---

## 1. 完整目录树（douyu 全展开，其余平台缩写）

```
packages/live_sites/
├── ARCHITECTURE.md / MODELS.md / EXAMPLES.md / README.md / CHANGELOG.md
├── pubspec.yaml / analysis_options.yaml
├── lib/
│   ├── live_sites.dart                          # 唯一公共出口（见 §6 实例）
│   └── src/
│       ├── core/
│       │   ├── live_site.dart                   # abstract interface class LiveSite
│       │   ├── live_site_manifest.dart          # 平台身份与多语言元数据
│       │   ├── live_site_context.dart           # 运行环境（目标平台/语言/配置）
│       │   ├── live_site_runtime_info.dart      # 运行态 enum + info
│       │   ├── live_site_registry.dart          # 进程内 id→site 集合
│       │   └── live_site_error.dart             # sealed 错误族（@freezed union）
│       ├── capabilities/                        # 11 个能力接口，一文件一接口
│       │   ├── live_site_capability.dart        # marker 接口
│       │   ├── live_room_provider.dart
│       │   ├── live_anchor_provider.dart
│       │   ├── live_area_provider.dart
│       │   ├── live_hot_provider.dart
│       │   ├── live_discovery_provider.dart
│       │   ├── live_search_provider.dart
│       │   ├── live_web_search_provider.dart
│       │   ├── live_playback_provider.dart
│       │   ├── live_danmaku_provider.dart       # 含 LiveDanmakuSession
│       │   └── live_link_resolver.dart
│       ├── models/                              # ★ 一类型一目录 + enums + converters + 领域 barrel
│       │   ├── room/                            # 域：房间
│       │   │   ├── live_room/
│       │   │   │   ├── live_room.dart
│       │   │   │   ├── live_room.freezed.dart
│       │   │   │   └── live_room.g.dart
│       │   │   ├── live_room_ref/
│       │   │   │   ├── live_room_ref.dart
│       │   │   │   └── live_room_ref.freezed.dart
│       │   │   ├── room_broadcast/
│       │   │   │   ├── room_broadcast.dart
│       │   │   │   └── room_broadcast.freezed.dart
│       │   │   ├── room_content/
│       │   │   │   ├── room_content.dart
│       │   │   │   └── room_content.freezed.dart
│       │   │   ├── room_links/
│       │   │   │   ├── room_links.dart
│       │   │   │   └── room_links.freezed.dart
│       │   │   ├── room_audience/
│       │   │   │   ├── room_audience.dart
│       │   │   │   └── room_audience.freezed.dart
│       │   │   ├── room_local/
│       │   │   │   ├── room_local.dart
│       │   │   │   └── room_local.freezed.dart
│       │   │   ├── room_runtime/
│       │   │   │   ├── room_runtime.dart
│       │   │   │   └── room_runtime.freezed.dart
│       │   │   └── room.dart                    # barrel: export 本域全部
│       │   ├── anchor/
│       │   │   ├── live_anchor/
│       │   │   │   ├── live_anchor.dart
│       │   │   │   └── live_anchor.freezed.dart
│       │   │   └── anchor.dart                  # barrel
│       │   ├── area/
│       │   │   ├── live_area/
│       │   │   │   ├── live_area.dart
│       │   │   │   └── live_area.freezed.dart
│       │   │   └── area.dart                    # barrel
│       │   ├── audience/
│       │   │   ├── live_audience_update/
│       │   │   │   ├── live_audience_update.dart
│       │   │   │   └── live_audience_update.freezed.dart
│       │   │   └── audience.dart                # barrel
│       │   ├── guide/
│       │   │   ├── room_guide/
│       │   │   │   ├── room_guide.dart
│       │   │   │   └── room_guide.freezed.dart
│       │   │   ├── guide_catch_up/
│       │   │   │   ├── guide_catch_up.dart
│       │   │   │   └── guide_catch_up.freezed.dart
│       │   │   └── guide.dart                   # barrel
│       │   ├── message/
│       │   │   ├── live_message/
│       │   │   │   ├── live_message.dart
│       │   │   │   └── live_message.freezed.dart
│       │   │   ├── message_sender/
│       │   │   │   ├── message_sender.dart
│       │   │   │   └── message_sender.freezed.dart
│       │   │   ├── live_badge/
│       │   │   │   ├── live_badge.dart
│       │   │   │   └── live_badge.freezed.dart
│       │   │   ├── live_emote/
│       │   │   │   ├── live_emote.dart
│       │   │   │   └── live_emote.freezed.dart
│       │   │   ├── live_message_color/
│       │   │   │   ├── live_message_color.dart
│       │   │   │   └── live_message_color.freezed.dart
│       │   │   ├── live_message_style/
│       │   │   │   ├── live_message_style.dart
│       │   │   │   └── live_message_style.freezed.dart
│       │   │   ├── live_retraction/
│       │   │   │   ├── live_retraction.dart
│       │   │   │   └── live_retraction.freezed.dart
│       │   │   └── message.dart                 # barrel
│       │   ├── gift/
│       │   │   ├── live_gift/
│       │   │   │   ├── live_gift.dart
│       │   │   │   └── live_gift.freezed.dart
│       │   │   ├── live_gift_value/
│       │   │   │   ├── live_gift_value.dart
│       │   │   │   └── live_gift_value.freezed.dart
│       │   │   ├── live_gift_combo/
│       │   │   │   ├── live_gift_combo.dart
│       │   │   │   └── live_gift_combo.freezed.dart
│       │   │   └── gift.dart                    # barrel
│       │   ├── super_chat/
│       │   │   ├── live_super_chat_message/
│       │   │   │   ├── live_super_chat_message.dart
│       │   │   │   └── live_super_chat_message.freezed.dart
│       │   │   ├── live_super_chat_price/
│       │   │   │   ├── live_super_chat_price.dart
│       │   │   │   └── live_super_chat_price.freezed.dart
│       │   │   ├── live_super_chat_display/
│       │   │   │   ├── live_super_chat_display.dart
│       │   │   │   └── live_super_chat_display.freezed.dart
│       │   │   └── super_chat.dart              # barrel
│       │   ├── play/
│       │   │   ├── live_play_quality/
│       │   │   │   ├── live_play_quality.dart
│       │   │   │   └── live_play_quality.freezed.dart
│       │   │   ├── live_play_line/
│       │   │   │   ├── live_play_line.dart
│       │   │   │   └── live_play_line.freezed.dart
│       │   │   ├── live_play_lease/
│       │   │   │   ├── live_play_lease.dart
│       │   │   │   └── live_play_lease.freezed.dart
│       │   │   ├── play_geometry/
│       │   │   │   ├── play_geometry.dart
│       │   │   │   └── play_geometry.freezed.dart
│       │   │   ├── infer_stream_format.dart     # 纯函数，无生成物
│       │   │   └── play.dart                    # barrel
│       │   ├── search/
│       │   │   ├── live_search_request/
│       │   │   │   ├── live_search_request.dart
│       │   │   │   └── live_search_request.freezed.dart
│       │   │   ├── live_search_result/
│       │   │   │   ├── live_search_result.dart
│       │   │   │   └── live_search_result.freezed.dart
│       │   │   └── search.dart                  # barrel
│       │   ├── page/
│       │   │   ├── live_page_request/
│       │   │   │   ├── live_page_request.dart
│       │   │   │   └── live_page_request.freezed.dart
│       │   │   ├── live_page/
│       │   │   │   ├── live_page.dart
│       │   │   │   └── live_page.freezed.dart
│       │   │   └── page.dart                    # barrel
│       │   ├── asset/
│       │   │   ├── live_asset_ref/
│       │   │   │   ├── live_asset_ref.dart
│       │   │   │   └── live_asset_ref.freezed.dart
│       │   │   └── asset.dart                   # barrel
│       │   ├── enums/                           # ★ 枚举：一文件一枚举，纯 .dart
│       │   │   ├── live_status.dart
│       │   │   ├── live_restriction.dart
│       │   │   ├── live_follow_group.dart
│       │   │   ├── live_stream_format.dart
│       │   │   ├── live_stream_codec.dart
│       │   │   ├── live_play_format_source.dart
│       │   │   ├── live_message_type.dart
│       │   │   ├── live_audience_metric_type.dart
│       │   │   ├── live_audience_signal_kind.dart
│       │   │   ├── live_audience_online_availability.dart
│       │   │   ├── live_gift_kind.dart
│       │   │   ├── live_gift_unit.dart
│       │   │   ├── live_message_placement.dart
│       │   │   ├── live_notice_kind.dart
│       │   │   ├── live_search_target.dart
│       │   │   ├── live_asset_type.dart
│       │   │   ├── live_anchor_role.dart
│       │   │   ├── live_room_activity.dart
│       │   │   └── enums.dart                   # barrel: export 全部枚举
│       │   └── converters/                      # ★ converter：一文件一 converter
│       │       ├── live_status_by_name_converter.dart
│       │       ├── epoch_millis_converter.dart
│       │       ├── iso_time_converter.dart
│       │       ├── audience_number_converter.dart
│       │       ├── uri_string_converter.dart
│       │       ├── stringify_converter.dart
│       │       └── converters.dart              # barrel: export 全部 converter
│       ├── platforms/
│       │   ├── douyu/                           # ★ 样板：全部文件见 §2 逐个展开
│       │   │   ├── douyu_site.dart
│       │   │   ├── douyu_manifest.dart
│       │   │   ├── api/
│       │   │   │   ├── douyu_endpoints.dart
│       │   │   │   ├── douyu_request_signer.dart
│       │   │   │   └── douyu_http.dart
│       │   │   ├── parsers/
│       │   │   │   ├── douyu_room_parser.dart
│       │   │   │   ├── douyu_directory_parser.dart
│       │   │   │   ├── douyu_play_parser.dart
│       │   │   │   └── douyu_danmaku_decoder.dart
│       │   │   ├── capabilities/
│       │   │   │   ├── douyu_room_provider.dart
│       │   │   │   ├── douyu_playback_provider.dart
│       │   │   │   ├── douyu_danmaku_provider.dart
│       │   │   │   └── douyu_search_provider.dart
│       │   │   └── fixtures/
│       │   │       ├── room_detail_live.json
│       │   │       ├── room_detail_offline.json
│       │   │       ├── room_detail_missing_fields.json
│       │   │       ├── directory_page.json
│       │   │       └── play_urls.json
│       │   ├── huya/                            # 同 douyu 结构（含 quirk 隔离示范）
│       │   ├── bilibili/
│       │   ├── douyin/
│       │   ├── iptv/                            # live_iptv 的接入适配器（MODELS.md §6 映射）
│       │   └── …                                # 其余平台按需建目录，禁止空壳
│       ├── common/                              # ≥2 平台证实的工具才准入
│       │   ├── normalization/
│       │   │   ├── site_text.dart               # 去不可见占位符
│       │   │   ├── site_counts.dart             # parseAudienceNumber（亿/万/k）
│       │   │   ├── site_images.dart
│       │   │   └── site_headers.dart
│       │   ├── site_ids/site_ids.dart           # 平台 id 大小写白名单（身份数据，§7.4 例外）
│       │   ├── site_urls/site_urls.dart
│       │   ├── quality/quality_label.dart       # 清晰度标签归一
│       │   ├── gift/                            # 礼物连击合并、价值计算
│       │   └── codec/                           # brotli / tars / protobuf 编解码（虎牙等）
│       └── internal/
│           └── built_in_sites.dart              # createBuiltInLiveSites()
└── test/
    ├── contracts/
    │   ├── site_contract_harness.dart           # 所有平台共跑的一套契约测试
    │   └── douyu_contract_test.dart             # harness(douyu) 实例化
    ├── models/
    │   ├── room_test.dart                       # 身份/归一化幂等/copyWith
    │   ├── audience_test.dart                   # int? 语义、converter 往返
    │   ├── play_test.dart                       # inferStreamFormat 后缀表
    │   └── schema_migration_test.dart           # v1 旧 JSON → v2 读入
    ├── common/
    │   └── site_counts_test.dart
    └── platforms/douyu/
        ├── douyu_room_parser_test.dart          # 金样本：读 fixtures 断言模型
        ├── douyu_play_parser_test.dart
        └── douyu_request_signer_test.dart
```

---

## 2. 平台目录实例（douyu 逐文件）

### 2.1 `douyu_site.dart` —— 站点入口，只做三件事
```dart
import 'package:live_sites/live_sites.dart';
import 'package:live_sites/src/platforms/douyu/capabilities/douyu_room_provider.dart';
import 'package:live_sites/src/platforms/douyu/capabilities/douyu_playback_provider.dart';
import 'douyu_manifest.dart';

/// Douyu site: manifest + capability discovery + lifecycle. No I/O here.
final class DouyuSite implements LiveSite {
  DouyuSite({required DouyuHttp http}) : _http = http;

  final DouyuHttp _http;
  bool _initialized = false;

  @override
  LiveSiteManifest get manifest => douyuManifest;

  @override
  LiveSiteRuntimeInfo get runtimeInfo => LiveSiteRuntimeInfo(
    status: _initialized ? LiveSiteStatus.ready : LiveSiteStatus.uninitialized,
  );

  @override
  T? capability<T extends LiveSiteCapability>() {
    // Only capabilities douyu genuinely implements. null = unsupported.
    return switch (T) {
      const (LiveRoomProvider) => DouyuRoomProvider(http: _http) as T,
      const (LivePlaybackProvider) => DouyuPlaybackProvider(http: _http) as T,
      _ => null,
    };
  }

  @override
  Future<void> initialize(LiveSiteContext context) async => _initialized = true;

  @override
  Future<void> dispose() async => _initialized = false;
}
```

### 2.2 `douyu_manifest.dart` —— 身份常量
```dart
const douyuManifest = LiveSiteManifest(
  id: 'douyu',                       // 小写 ASCII，永不改
  name: {'zh-CN': '斗鱼直播', 'en-US': 'Douyu'},
  version: '1.0.0',
  contractVersion: '1.0.0',
  supportedPlatforms: {LiveTargetPlatform.android, LiveTargetPlatform.ios,
      LiveTargetPlatform.windows, LiveTargetPlatform.macos, LiveTargetPlatform.linux},
);
```

### 2.3 `api/douyu_endpoints.dart` —— 端点与签名输入（纯数据）
```dart
/// Douyu open API endpoints. Path/query shapes live here; signing lives in the signer.
abstract final class DouyuEndpoints {
  static Uri roomDetail(String roomId) => Uri.https('open.douyucdn.cn',
      '/api/RoomApi/room/$roomId');
  static Uri directory(String cateId, int page, int limit) => Uri.https(
      'open.douyucdn.cn', '/api/RoomApi/live/$cateId',
      {'page': '$page', 'limit': '$limit'});
  // 录制的真实端点迁移时补全；未验证的端点不得写入。
}
```

### 2.4 `api/douyu_request_signer.dart` —— 签名（纯函数）
```dart
/// Douyu's authUa / `sign=md5(rid + authUa + ts)` dance. Pure: (input) -> (output).
abstract final class DouyuRequestSigner {
  static String authUa() => 'douyu_web';

  static String sign({required String roomId, required DateTime now}) {
    final ts = now.millisecondsSinceEpoch ~/ 1000;
    return md5.convert(utf8.encode('$roomId${authUa()}$ts')).toString();
  }
}
```

### 2.5 `api/douyu_http.dart` —— 本平台 HTTP 封装（唯一的 I/O 边界）
```dart
/// All douyu network I/O. Maps transport failures to typed site errors so
/// parsers stay pure and capabilities stay Either-shaped.
final class DouyuHttp {
  DouyuHttp({required LiveNetClient client}) : _client = client;
  final LiveNetClient _client;

  Future<Either<LiveSiteError, Map<String, Object?>>> getJson(Uri uri) async {
    try {
      final response = await _client.get(uri);
      if (response.statusCode == 404) {
        return left(LiveSiteNotFound(siteId: 'douyu', message: '${uri.path} missing'));
      }
      if (response.statusCode == 429) {
        return left(const LiveSiteRateLimitError(siteId: 'douyu', message: 'rate limited'));
      }
      final decoded = jsonDecode(response.body);
      return switch (decoded) {
        final Map<Object?, Object?> m => right(m.cast<String, Object?>()),
        _ => left(const LiveSiteParseError(siteId: 'douyu', message: 'non-object body')),
      };
    } on TimeoutException {
      return left(const LiveSiteNetworkError(siteId: 'douyu', message: 'timeout'));
    } catch (error) {
      return left(LiveSiteUnexpectedError(siteId: 'douyu', message: 'transport failed', cause: error));
    }
  }
}
```

### 2.6 `parsers/douyu_room_parser.dart` —— 纯函数，金样本可测
```dart
/// Map<String,Object?> (douyu RoomApi response) -> LiveRoom. Pure; no I/O,
/// no platform branching outside this directory.
abstract final class DouyuRoomParser {
  static Either<LiveSiteError, LiveRoom> parse(Map<String, Object?> json) {
    final data = json['data'];
    if (data is! Map) {
      return left(const LiveSiteParseError(siteId: 'douyu', message: 'missing data object'));
    }
    // 字段映射以 MODELS.md §3 为准；"1.2万" 等文本在这里 parse 后即弃。
    final room = LiveRoom(
      platform: 'douyu',
      roomId: data['room_id']?.toString() ?? '',
      content: RoomContent(
        title: data['room_name']?.toString() ?? '',
        coverUrl: data['room_src']?.toString() ?? '',
        notice: data['show_details']?.toString(),
      ),
      anchor: LiveAnchor(
        platform: 'douyu',
        anchorId: data['owner_uid']?.toString() ?? '',
        name: data['owner_name']?.toString() ?? '',
        avatarUrl: data['avatar']?.toString(),
      ),
      audience: RoomAudience(
        popularity: parseAudienceNumber(data['hot']?.toString()), // douyu 热度=popularity
      ),
      broadcast: RoomBroadcast(
        liveStatus: switch (data['isVertical'] ?? data['show_status']) {
          '1' || 1 => LiveStatus.live,
          '2' || 2 => LiveStatus.offline,
          _ => LiveStatus.unknown,
        },
      ),
    );
    return right(room);
  }
}
```

### 2.7 `capabilities/douyu_room_provider.dart` —— 能力实现（Either 边界）
```dart
final class DouyuRoomProvider implements LiveRoomProvider {
  DouyuRoomProvider({required DouyuHttp http}) : _http = http;
  final DouyuHttp _http;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoom(String roomId) async {
    if (roomId.trim().isEmpty) {
      return left(const LiveSiteInvalidArgument(siteId: 'douyu', message: 'roomId is blank'));
    }
    final json = await _http.getJson(DouyuEndpoints.roomDetail(roomId));
    return json.match(left, DouyuRoomParser.parse); // Left 直通，Right 进 parser
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRooms(LivePageRequest request) async {
    // 目录页走 directory parser；分页语义照 douyu 实际（page/limit），不伪造 cursor。
    throw UnimplementedError('migration step: wire DouyuDirectoryParser');
  }
}
```

> **quirk 隔离示范**（Huya 对照）：若解析里出现 `if (platform == 'huya') popularity = onlineViewers` 之类的平台历史特判——它**只允许**出现在 `parsers/huya_room_parser.dart` 里，douyu 目录里永远看不到别家的名字。

---

## 3. 模型文件实例（一类型一目录 + freezed + raw 工厂）

### 3.1 `models/room/live_room/live_room.dart` 骨架

```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:live_sites/src/models/anchor/live_anchor/live_anchor.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/room/live_room_ref/live_room_ref.dart';
import 'package:live_sites/src/models/room/room_audience/room_audience.dart';
import 'package:live_sites/src/models/room/room_broadcast/room_broadcast.dart';
import 'package:live_sites/src/models/room/room_content/room_content.dart';
import 'package:live_sites/src/models/room/room_guide/room_guide.dart';
import 'package:live_sites/src/models/room/room_links/room_links.dart';
import 'package:live_sites/src/models/room/room_local/room_local.dart';
import 'package:live_sites/src/models/room/room_runtime/room_runtime.dart';
import 'package:meta/meta.dart';

part 'live_room.freezed.dart';
part 'live_room.g.dart';

/// A live room. Identity lives in [LiveRoomRef]; this class compares by
/// value (all fields) — identity checks go through `room.ref` (MODELS.md §1.5.1).
@freezed
abstract class LiveRoom with _$LiveRoom {
  const LiveRoom._();

  /// Normalized-fields constructor; generated copyWith and codegen target this.
  @visibleForTesting
  const factory LiveRoom.raw({
    required LiveRoomRef ref,
    RoomContent content = const RoomContent(),
    RoomAudience audience = const RoomAudience(),
    RoomBroadcast broadcast = const RoomBroadcast(),
    RoomLinks links = const RoomLinks(),
    RoomGuide guide = const RoomGuide(),
    RoomLocal local = const RoomLocal(),
    RoomRuntime runtime = const RoomRuntime(),
    LiveAnchor? anchor,
    LiveArea? area,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _LiveRoom;

  /// Business constructor: normalize once, delegate to raw. Must stay idempotent.
  factory LiveRoom({
    required String platform,
    required String roomId,
    RoomContent content = const RoomContent(),
    RoomAudience audience = const RoomAudience(),
    RoomBroadcast broadcast = const RoomBroadcast(),
    RoomLinks links = const RoomLinks(),
    RoomGuide guide = const RoomGuide(),
    RoomLocal local = const RoomLocal(),
    RoomRuntime runtime = const RoomRuntime(),
    LiveAnchor? anchor,
    LiveArea? area,
  }) => LiveRoom.raw(
    ref: LiveRoomRef(platform: platform.trim().toLowerCase(), roomId: roomId.trim()),
    content: content,
    audience: audience,
    broadcast: broadcast,
    links: links,
    guide: guide,
    local: local,
    runtime: runtime,
    anchor: anchor,
    area: area,
  );

  factory LiveRoom.fromJson(Map<String, Object?> json) => _$LiveRoomFromJson(json);

  /// Stable identity for merges, dedup and storage keys.
  String get identityKey => ref.identityKey;

  /// Sparse refresh merge: an omitted value never erases a stored one.
  LiveRoom mergedWith(LiveRoom incoming) {
    if (ref != incoming.ref) return this;
    return copyWith(
      content: incoming.content.mergedWith(content),
      audience: incoming.audience.mergedWith(audience),
      broadcast: incoming.broadcast.mergedWith(broadcast),
      anchor: incoming.anchor ?? anchor,
      area: incoming.area ?? area,
    );
  }
}
```

### 3.2 `models/room/live_room_ref/live_room_ref.dart` 骨架

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'live_room_ref.freezed.dart';

/// (platform, roomId) identity pair. freezed's all-field equality IS identity here.
@freezed
abstract class LiveRoomRef with _$LiveRoomRef {
  const factory LiveRoomRef({required String platform, required String roomId}) = _LiveRoomRef;

  /// `platform:roomId` with case normalization for username-rooms (SiteIds).
  static String identityKeyOf({required String platform, required String roomId}) =>
      '$platform:$roomId'; // 大小写归一规则见 common/site_ids.dart
}
```

> 子对象（RoomContent/RoomAudience/…）同样模式：`@freezed` + `mergedWith`，各自位于 `models/room/<type>/`。字段清单逐字对照 MODELS.md §3.2–3.7。

### 3.3 `models/room/room.dart` —— 领域 barrel

```dart
/// Barrel for the room domain. Public export only; no definitions here.
library;

export 'live_room/live_room.dart';
export 'live_room_ref/live_room_ref.dart';
export 'room_audience/room_audience.dart';
export 'room_broadcast/room_broadcast.dart';
export 'room_content/room_content.dart';
export 'room_guide/room_guide.dart';
export 'room_links/room_links.dart';
export 'room_local/room_local.dart';
export 'room_runtime/room_runtime.dart';
```

### 3.4 `models/room/live_room/live_room.freezed.dart`（生成物，勿手改）
由 `dart run build_runner build` 生成，与源同目录同名。`live_room.g.dart` 同理（仅当该类型参与 json 序列化时生成）。

### 3.5 枚举文件示例 `models/enums/live_status.dart`

```dart
/// Live broadcast status. Unknown is always last (MODELS.md §2.1).
enum LiveStatus {
  live,
  replay,
  carousel,
  offline,
  banned,
  unknown,
}
```

### 3.6 枚举 barrel `models/enums/enums.dart`

```dart
/// Barrel for all enums. One enum per file; export only.
library;

export 'live_anchor_role.dart';
export 'live_asset_type.dart';
export 'live_audience_metric_type.dart';
export 'live_audience_online_availability.dart';
export 'live_audience_signal_kind.dart';
export 'live_follow_group.dart';
export 'live_gift_kind.dart';
export 'live_gift_unit.dart';
export 'live_message_placement.dart';
export 'live_message_type.dart';
export 'live_notice_kind.dart';
export 'live_play_format_source.dart';
export 'live_restriction.dart';
export 'live_room_activity.dart';
export 'live_search_target.dart';
export 'live_status.dart';
export 'live_stream_codec.dart';
export 'live_stream_format.dart';
```

---

## 4. 错误族实例（core/live_site_error.dart 骨架，不在 models/）

```dart
@freezed
sealed class LiveSiteError with _$LiveSiteError {
  const factory LiveSiteError.notFound({required String siteId, required String message}) =
      LiveSiteNotFound;
  const factory LiveSiteError.unsupported({required String siteId, required String message}) =
      LiveSiteUnsupported;
  const factory LiveSiteError.network({required String siteId, required String message, Object? cause}) =
      LiveSiteNetworkError;
  const factory LiveSiteError.parse({required String siteId, required String message, Object? cause}) =
      LiveSiteParseError;
  const factory LiveSiteError.authentication({required String siteId, required String message}) =
      LiveSiteAuthenticationError;
  const factory LiveSiteError.rateLimit({required String siteId, required String message}) =
      LiveSiteRateLimitError;
  const factory LiveSiteError.invalidArgument({required String siteId, required String message}) =
      LiveSiteInvalidArgument;
  const factory LiveSiteError.unexpected({required String siteId, required String message, Object? cause}) =
      LiveSiteUnexpectedError;
}
```

---

## 5. converters 实例（一 converter 一文件 + barrel）

### 5.1 `models/converters/epoch_millis_converter.dart`

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

/// Milliseconds ↔ DateTime? (UTC). The single home for epoch parsing.
final class EpochMillisConverter implements JsonConverter<DateTime?, Object?> {
  const EpochMillisConverter();

  @override
  DateTime? fromJson(Object? json) => switch (json) {
    final num n when n > 0 => DateTime.fromMillisecondsSinceEpoch(n.toInt(), isUtc: true),
    final String s => DateTime.tryParse(s)?.toUtc(),
    _ => null,
  };

  @override
  Object? toJson(DateTime? value) => value?.millisecondsSinceEpoch;
}
```

### 5.2 `models/converters/audience_number_converter.dart`

```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:live_sites/src/common/normalization/site_counts.dart';

/// `"1.2万"/"3,400"/1.2e4` → int? (null = unknown).
final class AudienceNumberConverter implements JsonConverter<int?, Object?> {
  const AudienceNumberConverter();

  @override
  int? fromJson(Object? json) => switch (json) {
    final num n => n.toInt(),
    final String s => parseAudienceNumberOrNull(s), // "1.2万" -> 12000；空/非数 -> null
    _ => null,
  };

  @override
  Object? toJson(int? value) => value;
}
```

### 5.3 `models/converters/live_status_by_name_converter.dart`

```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:live_sites/src/models/enums/live_status.dart';

/// Enum by name string; reads legacy v1 index ints too (MODELS.md §1.5.3).
final class LiveStatusByNameConverter implements JsonConverter<LiveStatus?, Object?> {
  const LiveStatusByNameConverter();

  @override
  LiveStatus? fromJson(Object? json) => switch (json) {
    final String s => LiveStatus.values.where((e) => e.name == s).firstOrNull,
    final int i when i >= 0 && i < LiveStatus.values.length => LiveStatus.values[i],
    _ => null,
  };

  @override
  Object? toJson(LiveStatus? value) => value?.name;
}
```

### 5.4 `models/converters/converters.dart` —— converter barrel

```dart
/// Barrel for all JsonConverters. One converter per file; export only.
library;

export 'audience_number_converter.dart';
export 'epoch_millis_converter.dart';
export 'iso_time_converter.dart';
export 'live_status_by_name_converter.dart';
export 'stringify_converter.dart';
export 'uri_string_converter.dart';
```

---

## 6. 公共出口实例（lib/live_sites.dart）

```dart
/// Live Sites — unified integration contract for live platforms.
///
/// One package, one public surface: core contracts, optional capabilities,
/// model domains (one barrel per domain) plus enums/converters barrels.
/// Platform implementations under src/platforms/ are private.
library;

// core
export 'src/core/live_site.dart';
export 'src/core/live_site_context.dart';
export 'src/core/live_site_error.dart';
export 'src/core/live_site_manifest.dart';
export 'src/core/live_site_registry.dart';
export 'src/core/live_site_runtime_info.dart';
// capabilities
export 'src/capabilities/live_anchor_provider.dart';
export 'src/capabilities/live_area_provider.dart';
export 'src/capabilities/live_danmaku_provider.dart';
export 'src/capabilities/live_discovery_provider.dart';
export 'src/capabilities/live_hot_provider.dart';
export 'src/capabilities/live_link_resolver.dart';
export 'src/capabilities/live_playback_provider.dart';
export 'src/capabilities/live_room_provider.dart';
export 'src/capabilities/live_search_provider.dart';
export 'src/capabilities/live_site_capability.dart';
export 'src/capabilities/live_web_search_provider.dart';
// models — 领域 barrel
export 'src/models/anchor/anchor.dart';
export 'src/models/area/area.dart';
export 'src/models/asset/asset.dart';
export 'src/models/audience/audience.dart';
export 'src/models/gift/gift.dart';
export 'src/models/guide/guide.dart';
export 'src/models/message/message.dart';
export 'src/models/page/page.dart';
export 'src/models/play/play.dart';
export 'src/models/room/room.dart';
export 'src/models/search/search.dart';
export 'src/models/super_chat/super_chat.dart';
// models — 枚举与 converter barrel
export 'src/models/enums/enums.dart';
export 'src/models/converters/converters.dart';
// internal entry point
export 'src/internal/built_in_sites.dart';
```

---

## 7. 测试实例（parser 金样本骨架）

```dart
// test/platforms/douyu/douyu_room_parser_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';

void main() {
  test('parses a live room fixture into the shared model', () {
    final json = jsonDecode(
      File('test/platforms/douyu/fixtures/room_detail_live.json').readAsStringSync(),
    ) as Map<String, Object?>;

    final result = DouyuRoomParser.parse(json);

    final room = result.getRight().toNullable()!;
    expect(room.ref, const LiveRoomRef(platform: 'douyu', roomId: '9999'));
    expect(room.broadcast.liveStatus, LiveStatus.live);
    expect(room.audience.popularity, greaterThan(0)); // int?，非 "1.2万"
  });

  test('maps a malformed body to a parse error, not an empty room', () {
    final result = DouyuRoomParser.parse({'error': 'no data'});
    expect(result.isLeft(), isTrue);
  });
}
```
> fixture 来源：浏览器 DevTools 录制真实响应，脱敏后入库。每 parser 至少 3 份：正常 + 畸形 + 缺字段。

---

## 8. 新增一个平台的 Checklist

1. `mkdir lib/src/platforms/<id>/`，按 §2 建齐 `api/ parsers/ capabilities/ fixtures/`（缺能力不建对应文件）。
2. 复制 §2.2 改 manifest（id 小写、多语言名）。
3. 写 parsers（纯函数）→ 录 fixtures → 写 parser 测试（§7 骨架）。
4. 写 `api/<id>_http.dart` 错误映射（§2.5 骨架），capabilities 组装（§2.7 骨架）。
5. 站点类接上（§2.1 骨架），在 `internal/built_in_sites.dart` 注册。
6. `test/contracts/<id>_contract_test.dart`：跑 harness（§1 test 树）。
7. 自查 ARCHITECTURE.md §15 PR 清单——尤其：本目录 grep 不到其他平台名；models/common 零改动。

---

## 9. 新增一个模型类型的 Checklist

1. 确定领域（room/anchor/area/audience/guide/message/gift/super_chat/play/search/page/asset）与类型名。
2. `mkdir lib/src/models/<域>/<类型>/`，建 `<类型>.dart`：
   - `part '<类型>.freezed.dart';`（需 json 则加 `part '<类型>.g.dart';`）
   - `@freezed abstract class`，`raw` 工厂 + 业务工厂（归一化）+ `fromJson`（如需持久化）。
   - `dart run build_runner build --delete-conflicting-outputs` 生成 `.freezed.dart`/`.g.dart`（与源同目录同名）。
3. 若是枚举：放 `lib/src/models/enums/<enum>.dart`（纯 `.dart`，无生成物），并更新 `enums/enums.dart`。
4. 若是 converter：放 `lib/src/models/converters/<converter>.dart`，并更新 `converters/converters.dart`。
5. 更新对应领域 barrel（如 `room/room.dart`）加 `export '<类型>/<类型>.dart';`。
6. 写模型单测（身份/归一化幂等/copyWith/序列化往返）；跑 `dart format` + `dart analyze` + `dart test`。
