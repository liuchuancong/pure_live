import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the Missevan (猫耳 FM) live APIs.
abstract final class MissevanParser {
  /// API request headers.
  static const Map<String, String> headers = {
    'referer': 'https://fm.missevan.com/',
    'origin': 'https://fm.missevan.com',
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
  };

  /// The `live/{id}` URL.
  static Uri detailUrl(String roomId) => Uri.https('fm.missevan.com', '/api/v2/live/$roomId');

  /// Validates the envelope (`code` 0) and returns the root; HTTP 404 and
  /// the unknown-room code are "not found".
  static Map<String, Object?> checked(String body, {required String roomId, int status = 200}) {
    switch (status) {
      case 200:
        break;
      case 401 || 403:
        throw SiteRiskControlError('missevan live/$roomId: HTTP $status');
      case 404:
        throw SiteNotFoundError('missevan live/$roomId: HTTP 404');
      case 429:
        throw SiteRateLimitedError('missevan live/$roomId: HTTP 429');
      default:
        throw SiteApiChangedError('missevan live/$roomId: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const SiteApiChangedError('missevan: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const SiteApiChangedError('missevan: body is not an object');
    }
    final code = SiteCounts.integer(decoded['code']);
    if (code == null) {
      throw const SiteApiChangedError('missevan: no code');
    }
    if (code == 500030004) {
      throw SiteNotFoundError('missevan live/$roomId: room not found');
    }
    if (code != 0) {
      throw SiteApiChangedError('missevan live/$roomId: code $code');
    }
    final data = decoded['data'];
    if (data is! Map<String, Object?>) {
      throw const SiteApiChangedError('missevan: no data object');
    }
    return data;
  }

  /// The guest session the chat socket needs (`Set-Cookie: FM_SESS`, without
  /// which the handshake is refused).
  static final Uri guestSession = Uri.https('fm.missevan.com', '/api/user/info');

  /// A Missevan room id: a positive integer of up to 18 digits.
  static final RegExp idPattern = RegExp(r'^[1-9][0-9]{0,17}$');

  /// The chat socket url of a room answer (`data.room.websocket`, a
  /// `wss://im.missevan.com/ws?room_id=…`), or null when the answer has none.
  static String? chatSocket(String body, {required String roomId, int status = 200}) {
    final row = checked(body, roomId: roomId, status: status)['room'];
    if (row is! Map<String, Object?>) return null;
    final url = row['websocket']?.toString().trim() ?? '';
    return url.isEmpty ? null : url;
  }

  /// `live/{id}` → the room with its catalog, state and pull URLs.
  static LiveRoom room(String body, {required String roomId, int status = 200}) {
    final data = checked(body, roomId: roomId, status: status);
    final row = data['room'];
    if (row is! Map<String, Object?>) {
      throw const SiteApiChangedError('missevan: live.room missing');
    }
    final id = row['room_id']?.toString() ?? '';
    if (id != roomId) {
      throw SiteApiChangedError('missevan live/$roomId answered room $id');
    }
    final state = row['status'];
    final open = state is Map<String, Object?> ? SiteCounts.integer(state['open']) : null;
    final live = open == 1;
    final statistics = row['statistics'];
    final score = statistics is Map<String, Object?> ? SiteCounts.integer(statistics['score']) : null;
    final creator = data['creator'];
    final creatorMap = creator is Map<String, Object?> ? creator : const <String, Object?>{};
    return LiveRoom(
      platform: SiteIds.missevan,
      roomId: roomId,
      title: row['name']?.toString() ?? '',
      nick: row['creator_username']?.toString() ?? creatorMap['username']?.toString() ?? '',
      avatar: image(creatorMap['iconurl'] ?? row['creator_iconurl']),
      cover: image(row['cover_url']),
      areaName: row['catalog_name']?.toString(),
      watching: score,
      status: live ? LiveStatus.live : LiveStatus.offline,
      startedAt: live ? _startedAt(state is Map<String, Object?> ? state['open_time'] : null) : null,
      data: live ? _channel(row) : null,
    );
  }

  /// The play lines of a live room: the pull URLs of its channel.
  static List<LivePlayLine> playLines(Object? channel, String roomId) {
    if (channel is! Map<String, Object?>) {
      return const [];
    }
    final lines = <LivePlayLine>[];
    final hls = channel['hls_pull_url']?.toString() ?? '';
    final flv = channel['flv_pull_url']?.toString() ?? '';
    if (hls.startsWith('http')) {
      lines.add(LivePlayLine(url: hls, headers: headers, format: StreamFormat.hls, lineId: 'hls'));
    }
    if (flv.startsWith('http')) {
      lines.add(LivePlayLine(url: flv, headers: headers, format: StreamFormat.flv, lineId: 'flv'));
    }
    return lines;
  }

  /// The area namespaces of the `meta/data` tabs, and the tab field each id
  /// lives in.
  ///
  /// A catalog and a tag with the same number are *different* areas, which is
  /// why the namespace is part of an area's identity here rather than a
  /// label: the request that lists an area is chosen by the namespace, and
  /// collapsing the two would send the wrong one.
  static const Map<String, String> areaNamespaces = {'catalog': '分区', 'list': '团播', 'tag': '标签'};

  static const Map<String, String> _tabIdField = {'catalog': 'catalog_id', 'tag': 'tag_id', 'list': 'list_type'};

  /// `meta/data` → the site's areas, flattened.
  ///
  /// The catalogue lives under `info`, not under the `data` object the room
  /// answers use — the same site, two envelopes — so it is read here rather
  /// than through the room reader, which would reject it.
  ///
  /// One request carries every namespace: each tab names its kind (`type`),
  /// its id (under the field that kind uses) and its label. A row without a
  /// usable id or label is skipped, and a file with no usable tab at all is
  /// an API change — an empty catalogue and a changed answer must not look
  /// the same.
  static List<LiveArea> areas(Map<String, Object?> body) {
    final data = SiteJson.object(body['info']).isEmpty ? SiteJson.object(body['data']) : SiteJson.object(body['info']);
    final tabs = SiteJson.list(data['tabs']);
    if (tabs.isEmpty || tabs.length > 100) {
      throw const SiteApiChangedError('missevan meta/data: no tabs');
    }
    final areas = <LiveArea>[];
    final seen = <String>{};
    for (final tab in tabs) {
      if (tab is! Map<String, Object?>) {
        continue;
      }
      final type = SiteText.trimmed(tab['type']);
      final idField = _tabIdField[type];
      final id = idField == null ? null : SiteCounts.integer(tab[idField]);
      final name = SiteText.title(SiteText.text(tab['name']));
      if (id == null || id <= 0 || name.isEmpty) {
        continue;
      }
      if (!seen.add('$type:$id')) {
        continue;
      }
      areas.add(LiveArea(id: '$id', name: name, parentId: type));
    }
    if (areas.isEmpty) {
      throw const SiteApiChangedError('missevan meta/data: no usable tab');
    }
    return areas;
  }

  /// The name shown for a namespace, or its own id when unknown.
  static String areaNamespaceName(String type) => areaNamespaces[type] ?? type;

  /// The rows one `chatroom/open/list` page answers with (the site's own
  /// page size, fixed).
  static const int serverPageSize = 20;

  /// The highest directory page the site serves.
  static const int maxPage = 10000;

  /// The list parameter [area] asks for: the namespace the area belongs to
  /// chooses it ([areaNamespaces] — `catalog` is `catalog_id`, `tag` is
  /// `tag_id`, `list` is `list_type`). Null (the recommendations) is no
  /// filter at all. An area of an unknown namespace, or with an id that is
  /// not a positive number, is a caller error refused before any request.
  static Map<String, String> areaQuery(LiveArea? area) {
    if (area == null) {
      return const {};
    }
    final parameter = _tabIdField[SiteText.trimmed(area.parentId)];
    final id = SiteText.trimmed(area.id);
    if (parameter == null || !_areaId.hasMatch(id)) {
      throw ArgumentError.value(area, 'area', 'not a Missevan area');
    }
    return {parameter: id};
  }

  static final RegExp _areaId = RegExp(r'^[1-9][0-9]{0,9}$');

  /// A `chatroom/open/list` page at [page]: the live rooms of its rows, each
  /// once, and whether the site's last page is still ahead.
  ///
  /// The page must echo [page] and [serverPageSize], and carry a `maxpage`
  /// and a `count`; a page past the site's last one must be empty. A row that
  /// cannot be read is skipped, but a page whose every row is unreadable is a
  /// changed endpoint rather than an empty page (the unified fault-tolerance
  /// rule). The promoted rows of the first page come again at their own place
  /// on a later page, so rooms this page already showed are dropped.
  static LivePage<LiveRoom> roomList(String body, {required int page, int status = 200}) {
    final data = payload(body, what: 'open/list', status: status);
    final pagination = SiteJson.object(data['pagination']);
    final max = SiteCounts.integer(pagination['maxpage']);
    final count = SiteCounts.integer(pagination['count']);
    final rows = SiteJson.list(data['Datas']);
    if (SiteCounts.integer(pagination['p']) != page ||
        SiteCounts.integer(pagination['pagesize']) != serverPageSize ||
        max == null ||
        max < 0 ||
        count == null ||
        count < 0 ||
        rows.length > 100 ||
        (page > max && rows.isNotEmpty)) {
      throw SiteApiChangedError('missevan open/list page $page: unexpected pagination $pagination');
    }
    final rooms = <String, LiveRoom>{};
    var readable = false;
    for (final raw in rows) {
      final room = roomRow(raw);
      readable = readable || room != null;
      if (room != null && room.status == LiveStatus.live) {
        rooms.putIfAbsent(room.roomId, () => room);
      }
    }
    if (!readable && rows.isNotEmpty) {
      throw SiteApiChangedError('missevan open/list page $page: no readable row');
    }
    final hasMore = page < max;
    return LivePage(
      items: rooms.values.toList(),
      hasMore: hasMore,
      nextPage: hasMore ? page + 1 : null,
      totalCount: count,
    );
  }

  /// One `chatroom/open/list` row as a room, or null when the row carries no
  /// room id.
  ///
  /// A row has the shape of a room's own object with the creator's name and
  /// avatar on the row itself; its `statistics.score` is the audience figure
  /// the site publishes, and only a broadcasting row carries a start time.
  /// A row carries no pull URLs — the play path reads the room itself — so
  /// the room's runtime cache is left unset here.
  static LiveRoom? roomRow(Object? raw) {
    final row = raw is Map<String, Object?> ? raw : null;
    if (row == null) {
      return null;
    }
    final id = SiteText.trimmed(row['room_id']);
    if (id.isEmpty) {
      return null;
    }
    final state = SiteJson.object(row['status']);
    final live = SiteCounts.integer(state['open']) == 1;
    final area = SiteText.trimmed(row['catalog_name']);
    return LiveRoom(
      platform: SiteIds.missevan,
      roomId: id,
      title: SiteText.text(row['name']),
      nick: SiteText.text(row['creator_username']),
      avatar: image(row['creator_iconurl']),
      cover: image(row['cover_url']),
      areaName: area.isEmpty ? null : area,
      watching: SiteCounts.integer(SiteJson.object(row['statistics'])['score']),
      status: live ? LiveStatus.live : LiveStatus.offline,
      startedAt: live ? _startedAt(state['open_time']) : null,
    );
  }

  /// Validates the envelope (`code` 0) of a list endpoint and returns its
  /// payload: the same envelope [checked] reads for one room, minus the
  /// per-room identity.
  ///
  /// The list endpoints answer under `info` (the detail endpoint's `data`)
  /// and, like the catalogue, an answer that carries only the other key is
  /// read rather than rejected.
  static Map<String, Object?> payload(String body, {required String what, int status = 200}) {
    if (status != 200) {
      throw SiteApiChangedError('missevan $what: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw SiteApiChangedError('missevan $what: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw SiteApiChangedError('missevan $what: body is not an object');
    }
    final code = SiteCounts.integer(decoded['code']);
    if (code != 0) {
      throw SiteApiChangedError('missevan $what: code ${decoded['code']}');
    }
    final info = decoded['info'];
    final data = info is Map<String, Object?> ? info : decoded['data'];
    if (data is! Map<String, Object?>) {
      throw SiteApiChangedError('missevan $what: no payload object');
    }
    return data;
  }

  static Map<String, Object?>? _channel(Map<String, Object?> row) {
    final channel = row['channel'];
    return channel is Map<String, Object?> ? channel : null;
  }

  /// `status.open_time`: epoch milliseconds from 2000 on.
  static DateTime? _startedAt(Object? value) {
    final milliseconds = SiteCounts.integer(value);
    if (milliseconds == null || milliseconds < 946684800000 || milliseconds >= 10000000000000) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
  }

  /// Passes a full image URL through, else null.
  static String? image(Object? value) {
    final url = value?.toString() ?? '';
    return url.isEmpty ? null : url;
  }
}
