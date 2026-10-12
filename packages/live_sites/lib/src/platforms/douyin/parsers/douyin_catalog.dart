import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// Pure parsing of Douyin's catalog, directory and search answers (the web
/// APIs; request signing and the anonymous cookie are the adapter's). Each
/// function takes a response body (and status/headers) and returns this tree's
/// models or throws a `SiteError`.
///
/// Archived from the reference and mapped onto this tree's models: a room is
/// keyed by its `web_rid` (as the enter flow already is); the audience is the
/// int `watching`/`onlineViewers` (the reference's cumulative count becomes
/// `watching`); areas are a flat `LiveArea` list (this tree has no
/// `LiveCategory`), and a card carries no `link`/`userId`/popularity.
abstract final class DouyinCatalog {
  /// The origin of the room pages and of the web APIs.
  static const String origin = 'https://live.douyin.com';

  /// The area a recommended room that names none shows.
  static const String recommendArea = '热门推荐';

  /// Room ids of 17 or more digits are per-broadcast room ids; shorter ones
  /// are web rids, the room's lasting identity.
  static bool isRoomId(String id) => RegExp(r'^\d{17,}$').hasMatch(id.trim());

  // Catalog -------------------------------------------------------------------

  /// The areas of the `live.douyin.com/?from_nav=1` page, whose data is the
  /// page's React Server Component payload (`self.__pace_f.push`). Ids are
  /// `id_str,type`. Flattened to this tree's `LiveArea`: each category is its
  /// own "all" area (`parentId` its id), then its sub-partitions (the category
  /// as parent) and their games (the sub-partition as parent); a game listed
  /// twice appears once, under the first.
  static List<LiveArea> areas(String html, {int status = 200, Map<String, String> headers = const {}}) {
    _checkHttp(html, status, headers, 'home page');
    final raw = _flightObject(_flightRows(html), 'categoryData')?['categoryData'];
    if (raw is! List) throw const SiteApiChangedError('douyin home page: categoryData missing');
    final seen = <String>{};
    void add(List<LiveArea> into, ({String id, String name})? partition, ({String id, String name}) parent) {
      if (partition != null && seen.add(partition.id)) {
        into.add(LiveArea(id: partition.id, name: partition.name, parentId: parent.id));
      }
    }

    final result = <LiveArea>[];
    for (final item in raw) {
      final top = _partition(_obj(item)?['partition']);
      if (top == null) continue;
      add(result, top, top);
      for (final sub in _arr(_obj(item)?['sub_partition'])) {
        final partition = _partition(_obj(sub)?['partition']);
        if (partition == null) continue;
        add(result, partition, top);
        for (final game in _arr(_obj(sub)?['sub_partition'])) {
          add(result, _partition(_obj(game)?['partition']), partition);
        }
      }
    }
    return List.unmodifiable(result);
  }

  /// The `partition` and `partition_type` of an area id `id_str,type`; anything
  /// else is `NotFound`.
  static ({String partition, String type}) partition(String areaId) {
    final comma = areaId.lastIndexOf(',');
    if (comma <= 0 || comma == areaId.length - 1) {
      throw SiteNotFoundError('douyin: area id "$areaId" is not id_str,type');
    }
    return (partition: areaId.substring(0, comma).trim(), type: areaId.substring(comma + 1).trim());
  }

  // Directory -----------------------------------------------------------------

  /// `partition/detail/room/v2` at [offset]: every room is live; the area is
  /// `tag_name`, else [areaName]. More pages follow while `data.count` is
  /// positive and `data.offset` advances past [offset].
  static ({List<LiveRoom> rooms, bool hasMore}) partitionRooms(
    String body, {
    required int offset,
    String? areaName,
    int status = 200,
    Map<String, String> headers = const {},
  }) {
    final data = _obj(_checked(body, status, headers, 'partition rooms')['data']);
    final list = data?['data'];
    if (data == null || list is! List) throw const SiteApiChangedError('douyin partition rooms: data.data missing');
    final seen = <String>{};
    final rooms = <LiveRoom>[];
    for (final raw in list) {
      final item = _obj(raw);
      final room = _obj(item?['room']);
      if (item == null || room == null) continue;
      final owner = _obj(room['owner']) ?? const <String, Object?>{};
      final id = _firstId([item['web_rid'], owner['web_rid'], room['id_str']]);
      if (id == null || !seen.add(id)) continue;
      rooms.add(
        _listRoom(
          id,
          room: room,
          title: _text(room['title']) ?? '',
          nick: _text(owner['nickname']) ?? '',
          cover: _firstImage([room['cover']]),
          avatar: _firstImage([owner['avatar_thumb']]),
          area: _text(item['tag_name']) ?? areaName,
        ),
      );
    }
    final count = SiteCounts.integer(data['count']);
    final next = SiteCounts.integer(data['offset']);
    return (rooms: rooms, hasMore: (count == null || count > 0) && next != null && next > offset);
  }

  /// `webcast/feed/` recommendations, both generations: the envelope list of
  /// 2026-08 (room in `data[].data`, possibly a JSON string, or in `room`) and
  /// the older `data.data` room list. Identity is the web_rid, else the room_id;
  /// duplicates drop. A room without an area shows [recommendArea].
  static List<LiveRoom> feed(String body, {int status = 200, Map<String, String> headers = const {}}) {
    final root = _checked(body, status, headers, 'feed');
    var list = root['data'];
    if (list is Map) list = list['data'];
    if (list is! List) throw const SiteApiChangedError('douyin feed: room list missing');
    final seen = <String>{};
    final rooms = <LiveRoom>[];
    for (final raw in list) {
      final envelope = _obj(raw);
      if (envelope == null) continue;
      final room = [
        _obj(envelope['data']),
        _obj(envelope['room']),
        envelope,
      ].firstWhere((candidate) => candidate != null && _looksLikeRoom(candidate), orElse: () => null);
      if (room == null) continue;
      final owner = _obj(room['owner']) ?? _obj(envelope['owner']) ?? const <String, Object?>{};
      final id = _firstId([envelope['web_rid'], owner['web_rid'], room['web_rid'], room['id_str'], room['id']]);
      if (id == null || !seen.add(id)) continue;
      rooms.add(
        _listRoom(
          id,
          room: room,
          title: _firstText([room['title'], envelope['title'], owner['nickname']]) ?? '',
          nick: _firstText([owner['nickname'], envelope['nickname']]) ?? '',
          cover: _firstImage([room['cover'], envelope['cover']]),
          avatar: _firstImage([owner['avatar_thumb'], owner['avatar_large'], envelope['avatar_thumb']]),
          area: _feedArea(envelope, room) ?? recommendArea,
        ),
      );
    }
    return rooms;
  }

  // Search --------------------------------------------------------------------

  /// Live search and general search (whose body is hex-length framed JSON
  /// documents). A room may be nested (`lives.rawdata`, `aweme_info.live_info`,
  /// …, JSON strings included). Identity is `owner.web_rid`, else the room_id;
  /// `status` 2 is live; duplicates drop. The card's picture is the streamer's
  /// large avatar, then the cover; a missing nickname stays empty.
  static List<LiveRoom> searchRooms(String body, {int status = 200, Map<String, String> headers = const {}}) {
    _checkHttp(body, status, headers, 'search');
    final items = <Object?>[];
    for (final chunk in _chunks(body)) {
      final data = _checked(chunk, 200, const {}, 'search')['data'];
      if (data is List) items.addAll(data);
    }
    final seen = <String>{};
    return List.unmodifiable([
      for (final item in items)
        if (_searchRoom(_obj(item) ?? const <String, Object?>{}) case final room? when seen.add(room.roomId)) room,
    ]);
  }

  static LiveRoom? _searchRoom(Map<String, Object?> item) {
    Object? at(Object? node, String key) => _obj(node)?[key];
    final raw = [
      at(at(item, 'lives'), 'rawdata'),
      at(at(item, 'lives'), 'raw_data'),
      at(at(item, 'live'), 'rawdata'),
      at(at(item, 'live_info'), 'rawdata'),
      at(at(at(item, 'aweme_info'), 'live_info'), 'rawdata'),
      at(at(item, 'data'), 'rawdata'),
      item['rawdata'],
      item['lives'],
      item['live'],
      item['live_info'],
      at(at(item, 'aweme_info'), 'live_info'),
      item['aweme_info'],
      item['data'],
      item,
    ].map(_obj).firstWhere((candidate) => candidate != null, orElse: () => null);
    if (raw == null) return null;
    final room = _obj(raw['room']) ?? const <String, Object?>{};
    final owner = _obj(raw['owner']) ?? const <String, Object?>{};
    final roomOwner = _obj(room['owner']) ?? const <String, Object?>{};
    final roomId = _firstId([
      raw['id_str'],
      raw['room_id_str'],
      room['id_str'],
      room['id'],
      raw['room_id'],
      raw['roomId'],
    ]);
    if (roomId == null) return null;
    final id = _firstId([owner['web_rid'], raw['web_rid'], roomOwner['web_rid']]) ?? roomId;
    final nickname = _firstText([owner['nickname'], raw['nickname'], roomOwner['nickname'], item['nickname']]);
    final roadMap = _arr(room['partition_road_map']);
    final live = SiteCounts.integer(raw['status']) == 2;
    final online = _viewers(room) ?? _viewers(raw);
    final total = _totalViewers(room) ?? _totalViewers(raw);
    return LiveRoom(
      platform: SiteIds.douyin,
      roomId: id,
      title: _firstText([raw['title'], room['title'], item['title'], item['desc'], nickname]) ?? '',
      nick: nickname ?? '',
      cover: _firstImage([owner['avatar_large'], raw['cover'], room['cover'], raw['cover_url']]),
      avatar: _firstImage([owner['avatar_thumb'], owner['avatar_large']]),
      areaName: _firstText([
        raw['video_feed_tag'],
        if (roadMap.isNotEmpty) _obj(roadMap.first)?['title'],
        _obj(raw['partition'])?['title'],
        item['search_keyword'],
      ]),
      status: live ? LiveStatus.live : LiveStatus.offline,
      watching: total ?? online,
      onlineViewers: live ? online : null,
    );
  }

  // Cards ---------------------------------------------------------------------

  static LiveRoom _listRoom(
    String id, {
    required Map<String, Object?> room,
    required String title,
    required String nick,
    required String cover,
    required String avatar,
    required String? area,
  }) {
    final online = _viewers(room);
    final total = _totalViewers(room);
    return LiveRoom(
      platform: SiteIds.douyin,
      roomId: id,
      title: title,
      nick: nick,
      cover: cover.isEmpty ? null : cover,
      avatar: avatar.isEmpty ? null : avatar,
      areaName: (area?.isEmpty ?? true) ? null : area,
      status: LiveStatus.live,
      watching: total ?? online,
      onlineViewers: online,
    );
  }

  static bool _looksLikeRoom(Map<String, Object?> value) =>
      value['owner'] is Map || value['title'] != null || value['id_str'] != null || value['stream_url'] is Map;

  static String? _feedArea(Map<String, Object?> envelope, Map<String, Object?> room) {
    final direct = _firstText([room['tag_name'], envelope['tag_name']]);
    if (direct != null) return direct;
    for (final source in [room['partition_road_map'], envelope['tags']]) {
      for (final tag in _arr(source)) {
        final map = _obj(tag);
        final text = map == null ? null : _firstText([map['title'], map['name'], map['tag_name']]);
        if (text != null) return text;
      }
    }
    return null;
  }

  static ({String id, String name})? _partition(Object? raw) {
    final map = _obj(raw);
    final id = _text(map?['id_str']);
    final type = _text(map?['type']);
    if (id == null || type == null) return null;
    return (id: '$id,$type', name: _text(map?['title']) ?? '');
  }

  // Audience ------------------------------------------------------------------

  /// The room's concurrent viewers: the exact integers first, then a text
  /// count with a digit; `room_view_stats` only for `display_type` 1 (online).
  static int? _viewers(Map<String, Object?> room) {
    final view = _obj(room['room_view_stats']) ?? const <String, Object?>{};
    final stats = _obj(room['stats']) ?? const <String, Object?>{};
    return _count([
      room['user_count'],
      room['online_user_count'],
      room['online_user_for_anchor'],
      if (SiteCounts.integer(view['display_type']) == 1) view['display_value'],
      view['user_count'],
      view['online_user_count'],
      view['online_user_for_anchor'],
      stats['user_count'],
      stats['online_user_count'],
      stats['online_user_for_anchor'],
    ]);
  }

  /// The room's cumulative viewers (what the page shows as "watched"); null
  /// when the room is shown by its online count (`display_type` 1) or names
  /// none.
  static int? _totalViewers(Map<String, Object?> room) {
    final view = _obj(room['room_view_stats']) ?? const <String, Object?>{};
    final stats = _obj(room['stats']) ?? const <String, Object?>{};
    if (SiteCounts.integer(view['display_type']) == 1) return null;
    final type = SiteCounts.integer(view['display_type']);
    return _count([
      if (type == null || type == 3) view['display_value'],
      view['total_user_str'],
      view['total_user'],
      stats['total_user_str'],
      stats['total_user'],
      room['total_user_str'],
      room['total_user'],
    ]);
  }

  /// The first candidate that reads as a positive count (an exact integer, or
  /// a text with a digit).
  static int? _count(List<Object?> candidates) {
    for (final candidate in candidates) {
      final value = candidate is bool ? null : SiteCounts.integer(candidate);
      if (value != null && value > 0) return value;
    }
    for (final candidate in candidates) {
      final text = candidate is String ? candidate.trim() : '';
      if (text.isEmpty || !RegExp('[0-9]').hasMatch(text)) continue;
      final number = _audienceNumber(text);
      if (number > 0) return number;
    }
    return null;
  }

  /// A display count text (`3055.0万`, `1,250`) as a number.
  static int _audienceNumber(String value) {
    final normalized = value.trim().toLowerCase().replaceAll(',', '').replaceAll('，', '');
    final match = RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*(亿|万|千|[kwm])?').firstMatch(normalized);
    final number = double.tryParse(match?.group(1) ?? '') ?? 0;
    final multiplier = switch (match?.group(2)) {
      '亿' => 100000000,
      '万' || 'w' => 10000,
      '千' || 'k' => 1000,
      'm' => 1000000,
      _ => 1,
    };
    return (number * multiplier).round();
  }

  // Helpers -------------------------------------------------------------------

  static String _firstImage(List<Object?> candidates) {
    for (final value in candidates) {
      final list = _obj(value)?['url_list'];
      if (list is List) {
        final url = _firstText(list);
        if (url != null) return _absolute(url);
      }
      final direct = _text(value);
      if (direct != null && (direct.startsWith('http://') || direct.startsWith('https://'))) return direct;
    }
    return '';
  }

  static String _absolute(String url) => url.startsWith('//') ? 'https:$url' : url;

  static String? _text(Object? value) {
    if (value == null || value is Map || value is Iterable) return null;
    final text = value.toString().trim();
    return text.isEmpty || text == 'null' ? null : text;
  }

  static String? _firstText(Iterable<Object?> values) {
    for (final value in values) {
      final text = _text(value);
      if (text != null) return text;
    }
    return null;
  }

  /// The first value usable as a room id (not `0` or another placeholder).
  static String? _firstId(Iterable<Object?> values) {
    for (final value in values) {
      final text = _text(value);
      if (text != null && !const {'0', 'undefined', 'nan', 'none'}.contains(text.toLowerCase())) return text;
    }
    return null;
  }

  /// A map, a `Map`, or a JSON-encoded object string; else null.
  static Map<String, Object?>? _obj(Object? value) {
    if (value is Map<String, Object?>) return value;
    if (value is Map) return value.map((key, entry) => MapEntry('$key', entry));
    if (value is String && value.trimLeft().startsWith('{')) {
      try {
        final decoded = jsonDecode(value);
        return decoded is Map<String, Object?> ? decoded : null;
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  static List<Object?> _arr(Object? value) => value is List ? value.cast<Object?>() : const <Object?>[];

  /// A JSON API answer: [_checkHttp], then `status_code`: 4001038 (no such web
  /// rid) is `NotFound`, 2483 and 20003 (not signed in) `NeedsLogin`, any other
  /// non-zero code `ApiChanged`. A body that is not JSON is a challenge page:
  /// `RiskControl`.
  static Map<String, Object?> _checked(String body, int status, Map<String, String> headers, String what) {
    _checkHttp(body, status, headers, what);
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw SiteRiskControlError('douyin $what: not JSON (${_snippet(body)})');
    }
    if (decoded is! Map<String, Object?>) {
      throw SiteApiChangedError('douyin $what: not a JSON object (${_snippet(body)})');
    }
    final code = SiteCounts.integer(decoded['status_code']);
    if (code == null || code == 0) return decoded;
    final data = _obj(decoded['data']);
    final message = _firstText([decoded['status_msg'], data?['prompts'], data?['message']]) ?? '';
    final detail = 'douyin $what: status_code $code $message'.trim();
    throw switch (code) {
      4001038 => SiteNotFoundError(detail),
      2483 || 20003 => SiteNeedsLoginError(detail),
      _ => SiteApiChangedError(detail),
    };
  }

  /// HTTP-level failures before the body is read: a captcha (`bdturing-verify`),
  /// 401/403 and an empty 200 (no ttwid, a rejected signature) are risk; 429
  /// throttling; 5xx and any other non-2xx an API change.
  static void _checkHttp(String body, int status, Map<String, String> headers, String what) {
    String? header(String name) {
      for (final entry in headers.entries) {
        if (entry.key.toLowerCase() == name && entry.value.isNotEmpty) return entry.value;
      }
      return null;
    }

    if (header('bdturing-verify') != null || header('x-vc-bdturing-parameters') != null) {
      throw SiteRiskControlError('douyin $what: captcha (bdturing-verify)');
    }
    if (status == 429) {
      final seconds = int.tryParse(header('retry-after')?.trim() ?? '');
      throw SiteRateLimitedError('douyin $what: 429${seconds == null ? '' : ' retry ${seconds}s'}');
    }
    if (status >= 500) throw SiteApiChangedError('douyin $what: HTTP $status');
    if (status == 401 || status == 403) throw SiteRiskControlError('douyin $what: HTTP $status');
    if (status < 200 || status >= 300) throw SiteApiChangedError('douyin $what: HTTP $status');
    if (body.trim().isEmpty) throw SiteRiskControlError('douyin $what: empty body (no ttwid, signature or captcha)');
  }

  /// The JSON documents of a body; the general search frames them as
  /// `<hex byte length>\r\n<document>\r\n` chunks ending with `0\r\n\r\n`.
  static List<String> _chunks(String body) {
    if (!RegExp(r'^[0-9a-fA-F]+\r?\n').hasMatch(body)) return [body];
    final bytes = utf8.encode(body);
    final documents = <String>[];
    var position = 0;
    while (position < bytes.length) {
      final end = bytes.indexOf(0x0A, position);
      if (end < 0) break;
      final size = int.tryParse(latin1.decode(bytes.sublist(position, end)).trim().split(';').first, radix: 16);
      if (size == null) throw const SiteApiChangedError('douyin search: bad chunk header');
      if (size == 0) break;
      final start = end + 1;
      if (start + size > bytes.length) throw const SiteApiChangedError('douyin search: truncated chunk');
      documents.add(utf8.decode(bytes.sublist(start, start + size), allowMalformed: true));
      position = start + size;
      if (position < bytes.length && bytes[position] == 0x0D) position++;
      if (position < bytes.length && bytes[position] == 0x0A) position++;
    }
    if (documents.isEmpty) throw const SiteApiChangedError('douyin search: no chunk');
    return documents;
  }

  static String _snippet(String body) {
    final text = body.trim().replaceAll(RegExp(r'\s+'), ' ');
    return text.length <= 80 ? text : '${text.substring(0, 80)}…';
  }

  // React Server Component payload --------------------------------------------

  static Map<String, ({bool text, String value})> _flightRows(String html) {
    final flight = StringBuffer();
    for (final match in RegExp(r'self\.__pace_f\.push\(\[1,"').allMatches(html)) {
      final start = match.end - 1;
      var index = start + 1;
      while (index < html.length) {
        final unit = html.codeUnitAt(index);
        if (unit == 0x5C) {
          index += 2;
        } else if (unit == 0x22) {
          break;
        } else {
          index++;
        }
      }
      if (index >= html.length) break;
      try {
        final chunk = jsonDecode(html.substring(start, index + 1));
        if (chunk is String) flight.write(chunk);
      } on FormatException {
        throw const SiteApiChangedError('douyin page: undecodable __pace_f chunk');
      }
    }
    final bytes = utf8.encode(flight.toString());
    final rows = <String, ({bool text, String value})>{};
    var position = 0;
    while (position < bytes.length) {
      final colon = bytes.indexOf(0x3A, position);
      if (colon < 0) break;
      final id = latin1.decode(bytes.sublist(position, colon)).trim();
      if (colon + 1 < bytes.length && bytes[colon + 1] == 0x54) {
        final comma = bytes.indexOf(0x2C, colon + 2);
        final size = comma < 0 ? null : int.tryParse(latin1.decode(bytes.sublist(colon + 2, comma)), radix: 16);
        if (size == null) break;
        final end = _min(comma + 1 + size, bytes.length);
        rows[id] = (text: true, value: utf8.decode(bytes.sublist(comma + 1, end), allowMalformed: true));
        position = end;
      } else {
        var end = bytes.indexOf(0x0A, colon + 1);
        if (end < 0) end = bytes.length;
        rows[id] = (text: false, value: utf8.decode(bytes.sublist(colon + 1, end), allowMalformed: true));
        position = end + 1;
      }
    }
    return rows;
  }

  /// The first object in the page's JSON rows that has [key] and satisfies
  /// [where] (pages also carry empty initial stores).
  static Map<String, Object?>? _flightObject(
    Map<String, ({bool text, String value})> rows,
    String key, {
    bool Function(Map<String, Object?> object)? where,
  }) {
    for (final row in rows.values) {
      if (row.text || !row.value.contains('"$key"')) continue;
      if (!row.value.startsWith('[') && !row.value.startsWith('{')) continue;
      final Object? decoded;
      try {
        decoded = jsonDecode(row.value);
      } on FormatException {
        continue;
      }
      final found = _findKey(decoded, key, where ?? (_) => true);
      if (found != null) return found;
    }
    return null;
  }

  static Map<String, Object?>? _findKey(Object? node, String key, bool Function(Map<String, Object?>) where) {
    if (node is Map<String, Object?>) {
      if (node.containsKey(key) && where(node)) return node;
      for (final value in node.values) {
        final found = _findKey(value, key, where);
        if (found != null) return found;
      }
    } else if (node is List) {
      for (final value in node) {
        final found = _findKey(value, key, where);
        if (found != null) return found;
      }
    }
    return null;
  }

  static int _min(int a, int b) => a < b ? a : b;
}
