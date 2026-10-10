// Module: lib/src/models/douyu_row.dart
// Purpose: Turn Douyu's own row shapes into the shared content models, and say whether a row is live.
// Author: liuchuancong
// Created: 2026-10-10
//
// Field names come from the v1-maintained Douyu line (origin/master lib/shared/platforms/douyu/douyu_site.dart):
// the list endpoints answer `data.rl` with two-letter keys, search answers `data.relateShow` with long keys,
// and the room profile is the `room` object of `betard/<roomId>`. Three endpoints, three shapes, one summary.

import 'package:pure_live_platform/pure_live_platform.dart';

/// The source id every douyu row carries.
const String douyuSourceId = 'douyu.live';

/// The room list endpoints page about two dozen rows at a time and ignore a requested size.
const int kDouyuListPageSize = 24;

/// Douyu answers ints as ints on some endpoints and as decimal strings on others.
int douyuInt(Object? value) => value is num ? value.toInt() : int.tryParse('${value ?? ''}'.trim()) ?? 0;

/// A JSON object, or null when the field was absent or was not an object.
///
/// Every endpoint here wraps its payload one level down, and the failure a caller needs to hear about is
/// "the shape changed", not a cast exception from inside a widget.
Map<String, Object?>? douyuObject(Object? value) => value is Map ? Map<String, Object?>.from(value) : null;

/// The rows of a list field, dropping anything that is not an object rather than failing the whole page.
List<Map<Object?, Object?>> douyuRows(Object? value) =>
    value is List ? value.whereType<Map<Object?, Object?>>().toList(growable: false) : const <Map<Object?, Object?>>[];

/// The two rows a live room is *not*: an offline room (`show_status`) and a recording loop (`videoLoop`),
/// plus the re-upload rows whose title announces itself as a replay.
bool douyuRoomPayloadIsLive(Map<Object?, Object?> room) {
  final name = '${room['room_name'] ?? ''}';
  return douyuInt(room['show_status']) == 1 && douyuInt(room['videoLoop']) != 1 && !name.startsWith('【回放】');
}

/// A `data.rl` row is a live room when its `type` is 1; other types are the directory's own filler.
bool douyuListRowIsLive(Map<Object?, Object?> row) => douyuInt(row['type']) == 1;

/// A search row is playable now when the anchor is live and the room is not a replay room (`roomType`).
bool douyuSearchRowIsLive(Map<Object?, Object?> row) => douyuInt(row['isLive']) == 1 && douyuInt(row['roomType']) == 0;

/// One room from a `data.rl` row, shared by the recommend page and a category page.
ContentSummary douyuRoomFromListRow(Map<Object?, Object?> row) {
  final roomId = '${row['rid'] ?? ''}';
  final name = '${row['rn'] ?? ''}'.trim();
  final nick = '${row['nn'] ?? ''}'.trim();
  final area = '${row['c2name'] ?? ''}'.trim();
  return ContentSummary(
    ref: ContentRef(sourceId: douyuSourceId, contentId: roomId, kind: ContentKind.liveRoom),
    title: name.isEmpty ? roomId : name,
    subtitle: <String>[if (nick.isNotEmpty) nick, if (area.isNotEmpty) area].join(' · '),
    cover: douyuAbsoluteUrl('${row['rs16'] ?? ''}'),
    metadata: ContentMetadata(popularity: douyuInt(row['ol'])),
  );
}

/// One room from a `data.relateShow` search row.
ContentSummary douyuRoomFromSearchRow(Map<Object?, Object?> row) {
  final roomId = '${row['rid'] ?? ''}';
  final name = '${row['roomName'] ?? ''}'.trim();
  final nick = '${row['nickName'] ?? ''}'.trim();
  final area = '${row['cateName'] ?? ''}'.trim();
  return ContentSummary(
    ref: ContentRef(sourceId: douyuSourceId, contentId: roomId, kind: ContentKind.liveRoom),
    title: name.isEmpty ? roomId : name,
    subtitle: <String>[if (nick.isNotEmpty) nick, if (area.isNotEmpty) area].join(' · '),
    cover: douyuAbsoluteUrl('${row['roomSrc'] ?? ''}'),
    // Search returns offline rooms too, and the row that says so is the only place that fact survives:
    // `description` would be a UI string, this is the field the contract has for a source's own statement.
    metadata: ContentMetadata(
      popularity: douyuInt(row['hot']),
      extra: <String, Object?>{'isLive': douyuSearchRowIsLive(row)},
    ),
  );
}

/// One room from the `betard/<roomId>` profile document, the only answer that states live status outright.
ContentSummary douyuRoomFromProfile(Map<Object?, Object?> room, {required String roomId}) {
  final name = '${room['room_name'] ?? ''}'.trim();
  final owner = '${room['owner_name'] ?? ''}'.trim();
  final area = '${room['second_lvl_name'] ?? ''}'.trim();
  final details = '${room['show_details'] ?? ''}'.trim();
  final business = room['room_biz_all'];
  final startedAt = douyuStartedAt(room['show_time']);
  return ContentSummary(
    ref: ContentRef(sourceId: douyuSourceId, contentId: '${room['room_id'] ?? roomId}', kind: ContentKind.liveRoom),
    title: name.isEmpty ? roomId : name,
    subtitle: <String>[if (owner.isNotEmpty) owner, if (area.isNotEmpty) area].join(' · '),
    cover: douyuAbsoluteUrl('${room['room_pic'] ?? ''}'),
    description: details.isEmpty ? null : details,
    metadata: ContentMetadata(
      popularity: business is Map ? douyuInt(business['hot']) : 0,
      // A room page says "已直播 2 小时", and the only honest source of that is the profile's own start time.
      extra: <String, Object?>{if (startedAt != null) 'startedAt': startedAt.toIso8601String()},
    ),
  );
}

/// A cover url, with `//host/path` (protocol-relative, which the search endpoint does return) made absolute.
String? douyuAbsoluteUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  if (trimmed.startsWith('//')) {
    return 'https:$trimmed';
  }
  return trimmed.startsWith('http') ? trimmed : null;
}

/// When the broadcast began, from a unix-seconds field. Out-of-range values are read as "not stated": a room
/// that claims 1970 or 2087 is a field that meant something else.
DateTime? douyuStartedAt(Object? raw) {
  final seconds = douyuInt(raw);
  if (seconds <= 0) {
    return null;
  }
  final time = DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  if (time.year < 2000 || time.year > 2100) {
    return null;
  }
  return time;
}
