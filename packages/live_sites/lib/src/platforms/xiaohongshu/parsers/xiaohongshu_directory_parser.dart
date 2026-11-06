import 'dart:convert';

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
import 'package:live_sites/src/platforms/xiaohongshu/api/xiaohongshu_endpoints.dart';
import 'package:live_sites/src/platforms/xiaohongshu/parsers/xiaohongshu_area_tiles.dart';
import 'package:live_sites/src/platforms/xiaohongshu/parsers/xiaohongshu_failure.dart';
import 'package:live_sites/src/platforms/xiaohongshu/xiaohongshu_manifest.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.

/// One page of the visitor feed: the rooms, whether more follow, and the
/// score the next page asks for.
typedef XiaohongshuFeedPage = ({List<LiveRoom> rooms, bool hasMore, String? nextCursor});

/// Pure parsing of the public web directory, independent of the visitor
/// bootstrap (the reference's `XiaohongshuDirectory`). Both answers are
/// `{success, code, data}` envelopes: a refusal is an api-changed failure,
/// never an empty page.
abstract final class XiaohongshuDirectoryParser {
  /// The parent group every category sits under (the reference's one
  /// `LiveCategory(id: 'live', name: '小红书')`, carried flat).
  static const String groupId = 'live';

  /// The parent group's display name.
  static const String groupName = '小红书';

  /// The platform-supplied names and ids, including its "all" category,
  /// returned flat with [groupId]/[groupName] as the
  /// parent of every row. Gates kept from the reference: a numeric id of at
  /// most eight digits, a name of at most 100 characters, and one row per id.
  static List<LiveArea> categories(String body) {
    final values = _data(body)['categories'];
    if (values is! List || values.length > 100) {
      throw const XiaohongshuFailure(XiaohongshuFailureKind.apiChanged, 'missing categories');
    }
    final areas = <LiveArea>[];
    final seen = <String>{};
    for (final value in values) {
      final item = value is Map ? value : const <Object?, Object?>{};
      final id = _string(item['id']) ?? '';
      final name = _string(item['desc']) ?? '';
      if (!XiaohongshuEndpoints.isCategoryId(id) || name.isEmpty || name.length > 100 || !seen.add(id)) continue;
      areas.add(
        LiveArea.normalized(
          platform: xiaohongshuSiteId,
          areaId: id,
          areaName: name,
          parentAreaId: groupId,
          parentAreaName: groupName,
          iconUrl: switch (xiaohongshuAreaTiles[id]) {
            final path? => '${LiveArea.bundledIconPrefix}$path',
            null => null,
          },
        ),
      );
    }
    return List.unmodifiable(areas);
  }

  /// One feed page. A row carries a score on each line: the last usable one
  /// is the next page's cursor. The endpoint is inclusive at the tail — a
  /// repeated final score terminates paging, even if it repeats a room; no
  /// page number is fabricated and exhaustion is never inferred from the row
  /// count. Rows that are not live cards, and cards whose room id is not one,
  /// are left out.
  static XiaohongshuFeedPage page(String body, {required String cursor}) {
    final values = _data(body)['feeds'];
    if (values is! List || values.length > 200) {
      throw const XiaohongshuFailure(XiaohongshuFailureKind.apiChanged, 'missing feeds');
    }
    final rooms = <LiveRoom>[];
    final seen = <String>{};
    String? next;
    for (final value in values) {
      final row = value is Map ? value : const <Object?, Object?>{};
      final score = row['cursor_score'];
      if (score is String && score.isNotEmpty && score.length <= 128) next = score;
      if (row['type'] != 'live' || row['model_type'] != 'live_v2') continue;
      final live = row['live'] is Map ? row['live']! as Map<Object?, Object?> : const <Object?, Object?>{};
      final info = live['t_room_info'] is Map
          ? live['t_room_info']! as Map<Object?, Object?>
          : const <Object?, Object?>{};
      final host = live['t_live_host_info'] is Map
          ? live['t_live_host_info']! as Map<Object?, Object?>
          : const <Object?, Object?>{};
      // JS numbers lose precision for these ids. The API's explicit string
      // wins even if the numeric room_id disagrees; no id is read from a URL.
      final id = _string(info['room_id_str']) ?? _string(info['room_id']) ?? '';
      if (!XiaohongshuEndpoints.isRoomId(id) || !seen.add(id)) continue;
      final online = _count(info['member_count']);
      final total = _count(info['uv']);
      rooms.add(
        LiveRoom.normalized(
          platform: xiaohongshuSiteId,
          roomId: id,
          content: RoomContent.of(title: _string(info['name']) ?? '', coverUrl: normalizeImageUrl(info['cover'])),
          anchor: LiveAnchor.normalized(
            platform: xiaohongshuSiteId,
            anchorId: _string(host['user_id']) ?? '',
            name: _string(host['nickname']) ?? '',
            avatarUrl: normalizeImageUrl(host['avatar']),
            liveStatus: LiveStatus.live,
          ),
          audience: RoomAudience.of(
            onlineViewers: online,
            totalViewers: total,
            primaryMetric: total != null ? LiveAudienceMetricType.totalViewers : LiveAudienceMetricType.onlineViewers,
          ),
          broadcast: RoomBroadcast.of(liveStatus: LiveStatus.live),
          links: RoomLinks.of(webUrl: XiaohongshuEndpoints.roomUrl(id).toString()),
        ),
      );
    }
    final hasMore = values.isNotEmpty && next != null && next != cursor;
    return (rooms: rooms, hasMore: hasMore, nextCursor: hasMore ? next : null);
  }

  // Envelope -------------------------------------------------------------------

  /// The `{success, code, data}` envelope's payload: a refusal (success not
  /// true, a code other than 0, no data object) and a non-JSON or oversized
  /// body are api-changed errors — a bootstrap refusal is never disguised as
  /// an offline room or an empty page.
  static Map<Object?, Object?> _data(String body) {
    if (body.length > XiaohongshuEndpoints.responseLimit) {
      throw const XiaohongshuFailure(XiaohongshuFailureKind.apiChanged, 'directory response too large');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const XiaohongshuFailure(XiaohongshuFailureKind.apiChanged, 'directory response is not JSON');
    }
    final root = decoded is Map ? decoded : const <Object?, Object?>{};
    final code = _int(root['code']);
    if (root['success'] != true || code != 0 || root['data'] is! Map) {
      throw XiaohongshuFailure(XiaohongshuFailureKind.apiChanged, 'visitor directory refused (${code ?? 'unknown'})');
    }
    return root['data']! as Map;
  }

  /// A trimmed non-empty string from a JSON value, or null (the reference's
  /// `jsonString`, which stringifies the ids the platform writes as numbers).
  static String? _string(Object? value) {
    if (value == null) return null;
    final text = '$value'.trim();
    return text.isEmpty ? null : text;
  }

  /// A whole number from a JSON number or integer string, or null.
  static int? _int(Object? value) => switch (value) {
    final int number => number,
    final double number when number == number.truncateToDouble() => number.toInt(),
    final String text => int.tryParse(text.trim()),
    _ => null,
  };

  /// A count: [_int] when zero or more.
  static int? _count(Object? value) => switch (_int(value)) {
    final int count when count >= 0 => count,
    _ => null,
  };
}
