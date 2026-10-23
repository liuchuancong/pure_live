import 'package:live_sites/src/common/normalization/site_counts.dart';
import 'package:live_sites/src/common/normalization/site_urls.dart';
import 'package:live_sites/src/models/anchor/live_anchor/live_anchor.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/enums/live_audience_metric_type.dart';
import 'package:live_sites/src/models/enums/live_status.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/room/room_audience/room_audience.dart';
import 'package:live_sites/src/models/room/room_broadcast/room_broadcast.dart';
import 'package:live_sites/src/models/room/room_content/room_content.dart';
import 'package:live_sites/src/models/room/room_links/room_links.dart';
import 'package:live_sites/src/models/search/live_search_result/live_search_result.dart';
import 'package:live_sites/src/platforms/douyu/douyu_manifest.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_failure.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_gift_parser.dart';
import 'package:live_sites/src/platforms/douyu/parsers/douyu_json.dart';

final RegExp _digits = RegExp(r'^\d{1,18}$');

/// Pure parsing of the douyu catalog/search/room responses
/// (reference `DouyuApi`, gold samples under `fixtures/douyu/`). Each
/// function takes the response text and HTTP status and returns shared
/// models, or throws a [DouyuFailure].
abstract final class DouyuRoomParser {
  /// The `{error|code, msg, data}` envelope: status checks first, then a
  /// non-zero `error`/`code` is [DouyuFailureKind.apiChanged] with the
  /// platform's message.
  static Map<String, dynamic> checked(String body, {required int status, required String what}) {
    statusChecks(status, what, body);
    final decoded = decodeJson(body);
    if (decoded is! Map<String, dynamic>) {
      throw DouyuFailure(DouyuFailureKind.apiChanged, '$what: HTTP $status, not an object (${jsonSnippet(body)})');
    }
    final code = jsonInt(decoded['error'] ?? decoded['code']);
    if (code != null && code != 0) {
      throw DouyuFailure(DouyuFailureKind.apiChanged, '$what: error $code ${jsonString(decoded['msg']) ?? ''}'.trim());
    }
    if (status < 200 || status >= 300) {
      throw DouyuFailure(DouyuFailureKind.apiChanged, '$what: HTTP $status (${jsonSnippet(body)})');
    }
    return decoded;
  }

  /// Status codes every endpoint shares: 403 is the edge refusing the
  /// client (risk control), 412 and 429 rate limiting, 5xx network.
  static void statusChecks(int status, String what, String body) {
    if (status == 403) {
      throw DouyuFailure(DouyuFailureKind.riskControl, '$what: HTTP 403 (${jsonSnippet(body)})');
    }
    if (status == 412 || status == 429) {
      throw DouyuFailure(DouyuFailureKind.rateLimited, '$what: HTTP $status');
    }
    if (status >= 500) {
      throw DouyuFailure(DouyuFailureKind.network, '$what: HTTP $status');
    }
  }

  // Catalog -------------------------------------------------------------------

  /// `m.douyu.com/api/cate/list`: `cate1Info` sorted by numeric id, each
  /// with the `cate2Info` areas of that id in platform order. The area
  /// picture is `icon`, else `smallIcon`, else `pic`.
  static List<LiveArea> areas(String body, {int status = 200}) {
    final data = jsonObject(checked(body, status: status, what: 'cate/list')['data']);
    final groups = data?['cate1Info'];
    final areaTable = data?['cate2Info'];
    if (groups is! List || areaTable is! List) {
      throw const DouyuFailure(DouyuFailureKind.apiChanged, 'cate/list: no cate1Info or cate2Info');
    }
    final result = <LiveArea>[];
    for (final raw in groups) {
      final group = jsonObject(raw);
      final parentId = group == null ? null : jsonString(group['cate1Id']);
      if (group == null || parentId == null) continue;
      final parentName = decodeHtmlEntities(jsonString(group['cate1Name']) ?? '');
      for (final rawArea in areaTable) {
        final area = jsonObject(rawArea);
        if (area == null || jsonString(area['cate1Id']) != parentId) continue;
        final areaId = jsonString(area['cate2Id']);
        if (areaId == null) continue;
        result.add(
          LiveArea.normalized(
            platform: douyuSiteId,
            areaId: areaId,
            areaName: decodeHtmlEntities(jsonString(area['cate2Name']) ?? ''),
            parentAreaId: parentId,
            parentAreaName: parentName,
            iconUrl: _areaPicture(area),
          ),
        );
      }
    }
    result.sort((a, b) => (int.tryParse(a.areaId) ?? 0).compareTo(int.tryParse(b.areaId) ?? 0));
    return result;
  }

  static String _areaPicture(Map<String, dynamic> area) {
    for (final key in const ['icon', 'smallIcon', 'pic']) {
      final url = normalizeImageUrl(area[key]);
      if (url.isNotEmpty) return url;
    }
    return '';
  }

  // Lists ---------------------------------------------------------------------

  /// `mixList` (area rooms, 120 a page) and `allpage` (recommendations,
  /// 40 a page). Only `type == 1` entries are rooms, all live. The page
  /// ends on an empty `rl` or at `pgcnt` (mixList; allpage always says 0),
  /// never by count.
  static ({List<LiveRoom> rooms, bool hasMore}) roomList(String body, {required int page, int status = 200}) {
    final data = jsonObject(checked(body, status: status, what: 'room list')['data']);
    final raw = data?['rl'];
    if (data == null || (raw != null && raw is! List)) {
      throw DouyuFailure(DouyuFailureKind.apiChanged, 'room list: no rl (${jsonSnippet(body)})');
    }
    final items = jsonList(raw);
    final rooms = <LiveRoom>[
      for (final item in items)
        if (jsonObject(item) case final room? when jsonInt(room['type']) == 1) ?_listRoom(room),
    ];
    final pages = jsonInt(data['pgcnt']) ?? 0;
    return (rooms: rooms, hasMore: items.isNotEmpty && (pages <= 0 || page < pages));
  }

  static LiveRoom? _listRoom(Map<String, dynamic> item) {
    final id = roomId(item['rid']);
    if (id == null) return null;
    final hot = jsonString(item['ol']);
    return LiveRoom.normalized(
      platform: douyuSiteId,
      roomId: id,
      content: RoomContent.of(
        title: decodeHtmlEntities(jsonString(item['rn']) ?? ''),
        coverUrl: normalizeImageUrl(item['rs16']),
      ),
      anchor: LiveAnchor.normalized(
        platform: douyuSiteId,
        name: decodeHtmlEntities(jsonString(item['nn']) ?? ''),
        avatarUrl: anchorAvatar(item['av']),
      ),
      area: LiveArea.normalized(platform: douyuSiteId, areaName: jsonString(item['c2name']) ?? ''),
      audience: RoomAudience.of(popularity: parseAudienceNumberOrNull(hot)),
      broadcast: RoomBroadcast.of(liveStatus: LiveStatus.live),
      links: RoomLinks.of(webUrl: 'https://www.douyu.com/$id'),
    );
  }

  /// An anchor avatar: an absolute address as it is, and a bare path
  /// (`avatar_v3/2026…`) made into the CDN's own
  /// `https://apic.douyucdn.cn/upload/{path}_middle.jpg` — the room lists'
  /// `av`, the search's `avatar` and the detail's `owner_avatar` all give the
  /// path form, and an unhosted string handed to an image loader is a codec
  /// error rather than a missing picture. Empty for anything that is neither.
  static String anchorAvatar(Object? value) {
    final url = normalizeImageUrl(value);
    if (url.isNotEmpty) return url;
    final path = value?.toString().trim() ?? '';
    // The endpoints write the word `null` for an anchor with no picture; the
    // old client turned that into `…/upload/null_middle.jpg`, a 404 per card.
    if (path.isEmpty || path.toLowerCase() == 'null' || !RegExp(r'^[\w./-]+$').hasMatch(path)) return '';
    return 'https://apic.douyucdn.cn/upload/${path.startsWith('/') ? path.substring(1) : path}_middle.jpg';
  }

  // Search --------------------------------------------------------------------

  /// `japi/search/api/searchShow`: `isLive == 1` with `roomType == 0` is
  /// live, `roomType == 3` a loop room (replay), the rest offline.
  static List<LiveSearchResult> searchRooms(String body, {int status = 200}) {
    final root = checked(body, status: status, what: 'searchShow');
    return [
      for (final item in jsonList(jsonObject(root['data'])?['relateShow']))
        if (jsonObject(item) case final room?) ...[?_listRoomSearch(room)],
    ];
  }

  static LiveSearchResult? _listRoomSearch(Map<String, dynamic> item) {
    final id = roomId(item['rid']);
    if (id == null) return null;
    final hot = jsonString(item['hot']);
    final status = switch ((jsonInt(item['isLive']), jsonInt(item['roomType']) ?? 0)) {
      (1, 0) => LiveStatus.live,
      (1, 3) => LiveStatus.replay,
      _ => LiveStatus.offline,
    };
    return LiveSearchResult.room(
      LiveRoom.normalized(
        platform: douyuSiteId,
        roomId: id,
        content: RoomContent.of(
          title: decodeHtmlEntities(jsonString(item['roomName']) ?? ''),
          coverUrl: normalizeImageUrl(item['roomSrc']),
        ),
        anchor: LiveAnchor.normalized(
          platform: douyuSiteId,
          name: decodeHtmlEntities(jsonString(item['nickName']) ?? ''),
          avatarUrl: anchorAvatar(item['avatar']),
        ),
        area: LiveArea.normalized(platform: douyuSiteId, areaName: jsonString(item['cateName']) ?? ''),
        audience: RoomAudience.of(popularity: parseAudienceNumberOrNull(hot)),
        broadcast: RoomBroadcast.of(liveStatus: status),
      ),
    );
  }

  /// `japi/search/api/searchUser`: streamers; live only with `roomType 0`.
  static List<LiveSearchResult> searchAnchors(String body, {int status = 200}) {
    final root = checked(body, status: status, what: 'searchUser');
    return [
      for (final item in jsonList(jsonObject(root['data'])?['relateUser']))
        if (jsonObject(jsonObject(item)?['anchorInfo']) case final anchor? when roomId(anchor['rid']) != null)
          LiveSearchResult.anchor(
            LiveAnchor.normalized(
              platform: douyuSiteId,
              anchorId: roomId(anchor['rid'])!,
              name: decodeHtmlEntities(jsonString(anchor['nickName']) ?? ''),
              avatarUrl: anchorAvatar(anchor['avatar']),
              liveStatus: jsonInt(anchor['isLive']) == 1 && (jsonInt(anchor['roomType']) ?? 0) == 0
                  ? LiveStatus.live
                  : LiveStatus.offline,
            ),
          ),
    ];
  }

  // Room detail ---------------------------------------------------------------

  /// `betard/<rid>`: the room as the user asked for it ([requestedId]: the
  /// identity of a follow never changes) and the canonical rid
  /// (`room.room_id`) used for signing, streams and danmaku. The body may
  /// be a JSON-encoded string.
  ///
  /// `videoLoop == 1` is a loop room (replay); `show_status == 1` without a
  /// `【回放】` title is live; anything else offline. A live room starts at
  /// `show_time` (Unix seconds; offline it is the last show's, so it is
  /// left out). A 200 HTML page ("该房间目前没有开放", "已被关闭" for a
  /// 靓号) is not-found; 403 risk control. The room's gifts ride along for
  /// the danmaku connection.
  static ({LiveRoom room, String rid, DouyuGiftCatalog gifts}) roomDetail(
    String body, {
    required String requestedId,
    int status = 200,
  }) {
    statusChecks(status, 'betard', body);
    if (body.trimLeft().startsWith('<')) {
      throw DouyuFailure(DouyuFailureKind.notFound, 'betard/$requestedId: HTML page (${htmlPageText(body)})');
    }
    if (status < 200 || status >= 300) {
      throw DouyuFailure(DouyuFailureKind.apiChanged, 'betard: HTTP $status (${jsonSnippet(body)})');
    }
    var decoded = decodeJson(body);
    if (decoded is String) decoded = decodeJson(decoded);
    final room = jsonObject(jsonObject(decoded)?['room']);
    if (room == null) {
      throw DouyuFailure(DouyuFailureKind.apiChanged, 'betard: no room (${jsonSnippet(body)})');
    }
    final rid = roomId(room['room_id']);
    if (rid == null) {
      throw const DouyuFailure(DouyuFailureKind.apiChanged, 'betard: room.room_id missing');
    }
    final rawTitle = jsonString(room['room_name']) ?? '';
    final replay = jsonInt(room['videoLoop']) == 1;
    final live = jsonInt(room['show_status']) == 1 && !replay && !rawTitle.startsWith('【回放】');
    final hot = jsonString(jsonObject(room['room_biz_all'])?['hot']);
    final id = requestedId.trim();
    final result = (
      rid: rid,
      room: LiveRoom.normalized(
        platform: douyuSiteId,
        roomId: id,
        content: RoomContent.of(
          title: decodeHtmlEntities(rawTitle),
          coverUrl: normalizeImageUrl(room['room_pic']),
          introduction: decodeHtmlEntities(jsonString(room['show_details']) ?? ''),
          notice: '',
        ),
        anchor: LiveAnchor.normalized(
          platform: douyuSiteId,
          name: decodeHtmlEntities(jsonString(room['owner_name']) ?? ''),
          avatarUrl: anchorAvatar(room['owner_avatar']),
        ),
        area: LiveArea.normalized(platform: douyuSiteId, areaName: jsonString(room['second_lvl_name']) ?? ''),
        audience: RoomAudience.of(
          popularity: parseAudienceNumberOrNull(hot),
          primaryMetric: LiveAudienceMetricType.popularity,
        ),
        broadcast: RoomBroadcast.of(
          liveStatus: replay
              ? LiveStatus.replay
              : live
              ? LiveStatus.live
              : LiveStatus.offline,
          startedAt: live ? _seconds(room['show_time']) : null,
        ),
        links: RoomLinks.of(webUrl: 'https://www.douyu.com/$id'),
      ),
      gifts: roomGiftsOf(decoded),
    );
    return result;
  }

  /// A Unix-seconds time; null when missing or not after 1970.
  static DateTime? _seconds(Object? value) => switch (jsonInt(value)) {
    final int seconds when seconds > 0 => DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true),
    _ => null,
  };

  // Room pages ----------------------------------------------------------------

  /// The canonical rid a room page names: `www.douyu.com/<靓号>` is served
  /// directly with `window.room_id = <rid>` (or `"room_id":<rid>` in its
  /// data). Null when the page names none (a missing room gets the home
  /// page).
  static String? roomIdInPage(String html) {
    final match =
        RegExp(r'window\.room_id\s*=\s*(\d+)').firstMatch(html) ??
        RegExp(r'\\?"room_id\\?"\s*:\s*\\?"?(\d+)').firstMatch(html);
    return roomId(match?.group(1));
  }

  /// The rid in a room address [target] (an alias page redirects to
  /// `/<rid>`), or null.
  static String? roomIdAt(Uri target) {
    final host = target.host.toLowerCase();
    if (host != 'douyu.com' && !host.endsWith('.douyu.com')) return null;
    final first = target.pathSegments.where((segment) => segment.isNotEmpty).firstOrNull;
    return first != null && _digits.hasMatch(first) ? roomId(first) : null;
  }

  /// Whether [address] is a room address at all (a rid, a 靓号 or an alias).
  static bool isRoomKey(String address) => RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(address);

  /// Whether [address] is a bare numeric rid.
  static bool isNumericRid(String address) => _digits.hasMatch(address);

  /// A positive douyu room id as text, or null.
  static String? roomId(Object? value) {
    final id = jsonInt(value);
    return id != null && id > 0 ? '$id' : null;
  }
}

/// The gifts of a decoded `betard` answer ([DouyuRoomParser.roomDetail]
/// reads them too); never throws.
DouyuGiftCatalog roomGiftsOf(Object? decoded) => DouyuGiftParser.roomGiftsOf(decoded);
