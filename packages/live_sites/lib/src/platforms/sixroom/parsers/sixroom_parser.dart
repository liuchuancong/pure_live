import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the 6.cn (六间房) live APIs.
abstract final class SixRoomParser {
  /// Web origin.
  static const String origin = 'https://v.6.cn';

  /// Request headers.
  static const Map<String, String> headers = {
    'user-agent':
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
    'referer': 'https://ios.6.cn/?ver=8.0.3&build=4',
  };

  /// The room page URL of [roomId].
  static Uri roomUrl(String roomId) => Uri.parse('$origin/$roomId');

  /// The inroom POST URL.
  static final Uri inroomUrl = Uri.parse('$origin/coop/mobile/index.php?padapi=coop-mobile-inroom.php');

  /// The inroom form of [userId].
  static Map<String, String> inroomForm(String userId) => {
    'av': '3.1',
    'encpass': '',
    'logiuid': '',
    'project': 'v6iphone',
    'rate': '1',
    'rid': '',
    'ruid': userId,
  };

  /// A room number: 2-12 digits, not starting with 0.
  static bool isRoomId(String value) => RegExp(r'^[1-9]\d{1,11}$').hasMatch(value.trim());

  /// A broadcaster user id: 2-13 digits, not starting with 0.
  static bool isUserId(String value) => RegExp(r'^[1-9]\d{1,12}$').hasMatch(value.trim());

  /// The room id of [raw]: a room number or a `v.6.cn`/`m.6.cn` link.
  static String? roomIdOf(String raw) {
    final value = raw.trim();
    if (isRoomId(value)) {
      return value;
    }
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        !(uri.host == 'v.6.cn' || uri.host == 'm.6.cn')) {
      return null;
    }
    for (final segment in uri.pathSegments.reversed) {
      if (isRoomId(segment)) {
        return segment;
      }
    }
    return null;
  }

  static final RegExp _pageIds = RegExp(
    r'''\brid\s*:\s*['"]([1-9]\d{1,12})['"]\s*,\s*roomid\s*:\s*['"]?([1-9]\d{1,11})(?!\d)['"]?''',
  );

  /// The room page → the broadcaster user id of [roomId].
  static String userIdOf(String body, {required String roomId, int status = 200}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('sixroom room page: HTTP $status');
    }
    for (final match in _pageIds.allMatches(body)) {
      if (match.group(2) == roomId) {
        return match.group(1)!;
      }
    }
    throw SiteNotFoundError('sixroom room page of $roomId: no rid/roomid');
  }

  /// The inroom answer → the room. `flag` 001 is the payload; 402 is
  /// "not found"; anything else is risk control.
  /// The site's areas and where each room list comes from: most areas are a
  /// type of the mobile list, 星颜 is the web's subarea 10, and 全部 is the
  /// homepage — which the mobile list has no "all" for, and whose 星颜
  /// answers `content: []`.
  static const List<({String id, String name, String? mobileType, int? subarea})> areaCatalog = [
    (id: 'all', name: '全部', mobileType: null, subarea: null),
    (id: 'song', name: '歌区', mobileType: 'u0', subarea: null),
    (id: 'dance', name: '舞区', mobileType: 'u1', subarea: null),
    (id: 'talk', name: '脱口秀', mobileType: 'u2', subarea: null),
    (id: 'face', name: '星颜', mobileType: null, subarea: 10),
    (id: 'party', name: '派对', mobileType: 'u8', subarea: null),
  ];

  /// The catalogue: six constant areas, so no request is spent finding them
  /// out.
  static List<LiveArea> areas() => [
    for (final (index, area) in areaCatalog.indexed) LiveArea(id: area.id, name: area.name, sort: index),
  ];

  /// The mobile list type of the recommendations: the live rooms of every
  /// area by popularity.
  static const String recommendType = 'special';

  /// Rooms one directory page carries (the mobile lists take any size).
  static const int pageSize = 30;

  /// The last directory page a caller may ask for.
  static const int maxPage = 10000;

  /// The headers of the mobile lists (the app's own client, which the
  /// `coop` endpoints answer).
  static const Map<String, String> listHeaders = {
    'user-agent':
        'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
    'accept': 'application/json,text/plain,*/*',
    'accept-language': 'zh-CN,zh;q=0.9,en;q=0.7',
    'referer': 'https://ios.6.cn/?ver=8.0.3&build=4',
  };

  /// Page [page] of [size] rooms of the mobile list [type] (`u0`,
  /// `special`).
  static Uri listUrl(String type, {required int page, int size = pageSize}) =>
      Uri.parse('$origin/coop/mobile/index.php').replace(
        queryParameters: {
          'padapi': 'coop-mobile-getlivelistnew.php',
          'av': '3.1',
          'encpass': '',
          'logiuid': '',
          'isnew': '1',
          'size': '$size',
          'p': '$page',
          'type': type,
        },
      );

  /// The web's list of subarea 10 (星颜): every live room of it in one
  /// answer.
  static Uri subareaUrl() =>
      Uri.parse('$origin/subareaIndex/getSubareaIndexNew.php').replace(queryParameters: {'subarea': '10'});

  /// The `content` of a 6.cn JSON answer whose `flag` is `001`; another flag
  /// is risk control (with its message), no flag a changed endpoint.
  static Object? content(String body, {required String what, int status = 200}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('sixroom $what: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw SiteApiChangedError('sixroom $what: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw SiteApiChangedError('sixroom $what: body is not an object');
    }
    final flag = decoded['flag']?.toString() ?? '';
    if (flag != '001') {
      throw SiteRiskControlError('sixroom $what: flag $flag ${decoded['content'] ?? ''}'.trim());
    }
    return decoded['content'];
  }

  /// Page [page] of the mobile list [type]: the rows of `content[type]` as
  /// live cards, once per room, and whether the list goes on — the page had
  /// rows and `roomListCount[type]` reaches past it (a full page when the
  /// count is missing).
  ///
  /// A type without rooms answers `content: []`, which is an empty page, not
  /// a change; a list whose rows are all unreadable is a changed endpoint
  /// rather than an empty one.
  static LivePage<LiveRoom> list(String body, {required String type, required int page, int status = 200}) {
    final content = SixRoomParser.content(body, what: 'mobile list $type', status: status);
    if (content is List && content.isEmpty) {
      return const LivePage<LiveRoom>(items: []);
    }
    final map = SiteJson.object(content);
    final rows = SiteJson.list(map[type]);
    if (rows.isEmpty && content is Map) {
      throw SiteApiChangedError('sixroom mobile list $type page $page: no $type list');
    }
    final seen = <String>{};
    final items = <LiveRoom>[];
    var unreadable = 0;
    for (final row in SiteJson.objects(rows)) {
      final room = card(row);
      if (room == null) {
        unreadable++;
        continue;
      }
      if (seen.add(room.roomId)) {
        items.add(room);
      }
    }
    if (items.isEmpty && unreadable > 0) {
      throw SiteApiChangedError('sixroom mobile list $type page $page: $unreadable unreadable rows, none usable');
    }
    final total = SiteCounts.integer(SiteJson.object(map['roomListCount'])[type]);
    final hasMore = rows.isNotEmpty && (total == null ? rows.length >= pageSize : page * pageSize < total);
    return LivePage<LiveRoom>(items: items, hasMore: hasMore, nextPage: hasMore ? page + 1 : null);
  }

  /// The web's subarea list (星颜): the featured rows of `bigLiveList.list`,
  /// then `liveList` (an object by user id), as live cards once per room.
  /// One answer — the area has no second page.
  static List<LiveRoom> subareaRooms(String body, {int status = 200}) {
    final content = SiteJson.object(SixRoomParser.content(body, what: 'subarea list', status: status));
    final featured = SiteJson.list(SiteJson.object(content['bigLiveList'])['list']);
    final others = content['liveList'];
    final rows = [...featured, if (others is Map) ...others.values else if (others is List) ...others];
    if (featured.isEmpty && others is! Map && others is! List) {
      throw const SiteApiChangedError('sixroom subarea list: no bigLiveList or liveList');
    }
    final seen = <String>{};
    final items = <LiveRoom>[];
    for (final row in SiteJson.objects(rows)) {
      final room = card(row);
      if (room != null && seen.add(room.roomId)) {
        items.add(room);
      }
    }
    return items;
  }

  /// The homepage's rooms: the `typeList` of the embedded
  /// `window.__SMARTY_ALL_VARIABLES__` object, in its order, once per room.
  /// No room at all is a changed page.
  static List<LiveRoom> homeRooms(String body, {int status = 200}) {
    if (status != 200) {
      throw SiteApiChangedError('sixroom homepage: HTTP $status');
    }
    const marker = 'window.__SMARTY_ALL_VARIABLES__ = ';
    final at = body.indexOf(marker);
    final start = at < 0 ? -1 : body.indexOf('{', at + marker.length);
    if (start < 0) {
      throw const SiteApiChangedError('sixroom homepage: no __SMARTY_ALL_VARIABLES__');
    }
    var depth = 0;
    var quoted = false;
    var escaped = false;
    for (var index = start; index < body.length; index++) {
      final code = body.codeUnitAt(index);
      if (quoted) {
        if (escaped) {
          escaped = false;
        } else if (code == 0x5c) {
          escaped = true;
        } else if (code == 0x22) {
          quoted = false;
        }
        continue;
      }
      if (code == 0x22) {
        quoted = true;
      } else if (code == 0x7b) {
        depth++;
      } else if (code == 0x7d && --depth == 0) {
        return _embeddedRooms(body.substring(start, index + 1));
      }
    }
    throw const SiteApiChangedError('sixroom homepage: __SMARTY_ALL_VARIABLES__ does not end');
  }

  /// The `typeList` of an embedded variables object (JSON, or JSON text).
  static List<LiveRoom> _embeddedRooms(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const SiteApiChangedError('sixroom homepage: variables are not JSON');
    }
    var rows = SiteJson.object(decoded)['typeList'];
    if (rows is String) {
      try {
        rows = jsonDecode(rows);
      } on FormatException {
        throw const SiteApiChangedError('sixroom homepage: typeList is not JSON');
      }
    }
    final seen = <String>{};
    final items = <LiveRoom>[];
    for (final row in SiteJson.objects(rows)) {
      final room = card(row);
      if (room != null && seen.add(room.roomId)) {
        items.add(room);
      }
    }
    if (items.isEmpty) {
      throw const SiteApiChangedError('sixroom homepage: typeList has no room');
    }
    return items;
  }

  /// One list row as a room, or null when it names no room number or user
  /// id: the name (`username`, the subarea's featured rows `alias`), the
  /// title (else the signature `userMood`, else the name), the avatar
  /// (`picuser`, which the mobile lists lack), the cover
  /// (`pospic`/`pic`/`pospic_sp`), the area, `count` as the site's热度 and
  /// `realstarttime` (Unix seconds) as the start.
  static LiveRoom? card(Map<String, Object?> row) {
    final roomId = SiteText.trimmed(row['rid']);
    final userId = SiteText.trimmed(row['uid']);
    if (!isRoomId(roomId) || !isUserId(userId)) {
      return null;
    }
    final nick = _firstText([row['username'], row['alias']]);
    final area = SiteText.trimmed(row['anchor_area']);
    final seconds = SiteCounts.integer(row['realstarttime']);
    return LiveRoom(
      platform: SiteIds.sixroom,
      roomId: roomId,
      title: _firstText([row['livetitle'], row['userMood'], nick]),
      nick: nick,
      avatar: _image(row['picuser']),
      cover: _firstImage([row['pospic'], row['pic'], row['pospic_sp']]),
      areaName: area.isEmpty ? null : area,
      watching: SiteCounts.integer(row['count']),
      status: LiveStatus.live,
      startedAt: seconds == null || seconds <= 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true),
    );
  }

  /// The first non-empty text of [values].
  static String _firstText(List<Object?> values) {
    for (final value in values) {
      final text = SiteText.title(SiteText.text(value));
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }

  /// The first usable picture of [values].
  static String? _firstImage(List<Object?> values) {
    for (final value in values) {
      if (_image(value) case final image?) {
        return image;
      }
    }
    return null;
  }

  /// The inroom answer → the room of [roomId], as the broadcaster [userId]'s
  /// live facts (the play data rides in `content`).
  static LiveRoom room(String body, {required String roomId, required String userId, int status = 200}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('sixroom inroom: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const SiteApiChangedError('sixroom inroom: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const SiteApiChangedError('sixroom inroom: body is not an object');
    }
    final flag = decoded['flag']?.toString() ?? '';
    if (flag != '001') {
      final message = decoded['content']?.toString() ?? '';
      if (flag == '402') {
        throw SiteNotFoundError('sixroom inroom of $userId: $message');
      }
      throw SiteRiskControlError('sixroom inroom of $userId: flag $flag $message'.trim());
    }
    final content = decoded['content'];
    final contentMap = content is Map<String, Object?> ? content : const <String, Object?>{};
    final roomInfo = contentMap['roominfo'];
    final liveInfo = contentMap['liveinfo'];
    final params = contentMap['roomParamInfo'];
    if (roomInfo is! Map<String, Object?> || liveInfo is! Map<String, Object?>) {
      throw const SiteApiChangedError('sixroom inroom: no roominfo or liveinfo');
    }
    final paramsMap = params is Map<String, Object?> ? params : const <String, Object?>{};
    final actualRoomId = roomInfo['rid']?.toString() ?? '';
    final actualUserId = (roomInfo['id'] ?? paramsMap['uid'])?.toString() ?? '';
    if (actualRoomId != roomId || actualUserId != userId.trim()) {
      throw SiteApiChangedError('sixroom inroom of $roomId/$userId names $actualRoomId/$actualUserId');
    }
    final liveId = liveInfo['id']?.toString() ?? '';
    final flvTitle = liveInfo['flvtitle']?.toString() ?? '';
    final live = liveId.isNotEmpty && flvTitle.isNotEmpty;
    final nick = roomInfo['alias']?.toString() ?? '';
    final operation = paramsMap['operation'];
    final operationMood = operation is Map<String, Object?> ? operation['userMood'] : null;
    final title = (liveInfo['title'] ?? roomInfo['userMood'] ?? operationMood ?? nick).toString();
    final startSeconds = SiteCounts.integer(liveInfo['starttime']);
    return LiveRoom(
      platform: SiteIds.sixroom,
      roomId: roomId,
      title: title,
      nick: nick,
      avatar: _image(roomInfo['headPicUrl'] ?? roomInfo['picuser']),
      cover: _image(liveInfo['spredPic'] ?? liveInfo['largepic'] ?? liveInfo['pic']),
      areaName: (roomInfo['anchor_area'] ?? roomInfo['rtypename'])?.toString(),
      watching: SiteCounts.integer(paramsMap['fans_num']),
      status: live ? LiveStatus.live : LiveStatus.offline,
      startedAt: live && startSeconds != null && startSeconds > 0
          ? DateTime.fromMillisecondsSinceEpoch(startSeconds * 1000, isUtc: true)
          : null,
      data: live ? {'userId': actualUserId, 'liveId': liveId, 'flvTitle': flvTitle} : null,
    );
  }

  /// The play lines of a live room whose data carries the flv title: the
  /// `httpflv` address derived from `v<userId>-<liveId>`.
  static List<LivePlayLine> playLines(Object? data) {
    if (data is! Map<String, Object?>) {
      return const [];
    }
    final userId = data['userId']?.toString() ?? '';
    final liveId = data['liveId']?.toString() ?? '';
    final flvTitle = data['flvTitle']?.toString() ?? '';
    if (!isUserId(userId) || !isUserId(liveId)) {
      throw const SiteNotFoundError('sixroom: no stream identity');
    }
    final expected = 'v$userId-$liveId';
    if (!(flvTitle == expected || flvTitle == '$expected-many')) {
      throw SiteApiChangedError('sixroom: stream name $flvTitle for live $liveId');
    }
    return [
      LivePlayLine(
        url: 'https://wlive.6rooms.com/httpflv/$flvTitle.flv',
        headers: headers,
        format: StreamFormat.flv,
        lineId: 'flv',
      ),
    ];
  }

  static String? _image(Object? value) {
    final url = value?.toString() ?? '';
    if (url.isEmpty) {
      return null;
    }
    return url.startsWith('//') ? 'https:$url' : url;
  }
}
