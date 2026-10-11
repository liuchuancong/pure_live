import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the Inke web and app live APIs.
abstract final class InkeParser {
  /// Web API base.
  static const String webApi = 'https://webapi.busi.inke.cn/web';

  /// App API base.
  static const String appApi = 'https://service.inke.cn/api/live';

  /// Home page, for links.
  static const String origin = 'https://www.inke.cn';

  /// Request headers.
  static const Map<String, String> headers = {
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'referer': 'https://www.inke.cn/',
  };

  /// The `live_share_pc?uid=` URL.
  static Uri shareUrl(String uid) => Uri.https('webapi.busi.inke.cn', '/web/live_share_pc', {'uid': uid});

  /// The `now_publish?id=` URL.
  static Uri publishUrl(String uid) => Uri.https('service.inke.cn', '/api/live/now_publish', {'id': uid});

  /// A uuid: digits.
  static bool isUid(String value) => RegExp(r'^\d{1,20}$').hasMatch(value.trim());

  /// The id of the website's top list, which is also the first area of the
  /// catalogue. A channel key is alphanumeric and can never collide with it.
  static const String topAreaId = 'Live_top_pc';

  /// The name of the top-list area.
  static const String topAreaName = '官网推荐';

  /// A channel key (`tab_key`).
  static final RegExp _tabKey = RegExp(r'^[A-Za-z0-9_]{1,64}$');

  /// The website's channel list, which is also the catalogue: its channels
  /// are the areas, and their rows are the rooms.
  static Uri channelListUrl() => Uri.parse('$webApi/Live_channel_pc');

  /// The website's top list (eight slots).
  static Uri topUrl() => Uri.parse('$webApi/Live_top_pc');

  /// The app's hot list, which is what the site recommends.
  static Uri hotUrl() => Uri.parse('$appApi/simpleall');

  /// The `data` of a website answer (`error_code` 0), which is the envelope
  /// every `Live_*_pc` endpoint uses.
  static Map<String, Object?> webData(String body, {required String what, int status = 200}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('inke $what: HTTP $status');
    }
    final root = SiteJson.decode(body, what: 'inke $what');
    final code = SiteCounts.integer(root['error_code']);
    if (code == null) {
      throw SiteApiChangedError('inke $what: no error_code');
    }
    if (code != 0) {
      throw SiteApiChangedError('inke $what: error_code $code');
    }
    final data = SiteJson.object(root['data']);
    if (data.isEmpty) {
      throw SiteApiChangedError('inke $what: no data');
    }
    return data;
  }

  /// An app answer (`dm_error` 0), which carries the hot list.
  static Map<String, Object?> appData(String body, {required String what, int status = 200}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('inke $what: HTTP $status');
    }
    final root = SiteJson.decode(body, what: 'inke $what');
    final code = SiteCounts.integer(root['dm_error']);
    if (code != 0) {
      throw SiteApiChangedError('inke $what: dm_error ${root['dm_error']}');
    }
    return root;
  }

  /// The catalogue: the website's top list first, then its channels, in the
  /// site's own order.
  ///
  /// One answer carries both the areas and their rooms, which is why the
  /// areas and a channel's listing are read from the same body. A channel
  /// without an alphanumeric key, with a key an earlier one took, without a
  /// name or without a list of rows is skipped; more than a hundred channels
  /// is a changed page.
  static List<LiveArea> areas(String body, {int status = 200}) {
    final data = webData(body, what: 'Live_channel_pc', status: status);
    final groups = SiteJson.list(data['list']);
    if (groups.length > 100) {
      throw SiteApiChangedError('inke Live_channel_pc: ${groups.length} channels');
    }
    final areas = <LiveArea>[const LiveArea(id: topAreaId, name: topAreaName)];
    final seen = <String>{topAreaId};
    for (final group in groups) {
      final row = SiteJson.object(group);
      final key = SiteText.trimmed(row['tab_key']);
      final name = SiteText.title(SiteText.text(row['channel_name']));
      if (!_tabKey.hasMatch(key) || name.isEmpty || !seen.add(key)) {
        continue;
      }
      areas.add(LiveArea(id: key, name: name, sort: areas.length));
    }
    return areas;
  }

  /// The rooms of channel [tabKey] of the website's channel list, in the
  /// site's order; null when the answer has no such channel (the tabs change
  /// between releases, so a stored area can name a channel the site has
  /// retired).
  static List<LiveRoom>? channelRooms(String body, {required String tabKey, int status = 200}) {
    final data = webData(body, what: 'Live_channel_pc', status: status);
    for (final group in SiteJson.objects(data['list'])) {
      if (SiteText.trimmed(group['tab_key']) != tabKey) {
        continue;
      }
      final rows = group['list'];
      if (rows is! List || rows.length > 1000) {
        throw SiteApiChangedError('inke channel $tabKey: ${rows is List ? '${rows.length} rows' : 'no list'}');
      }
      return unique([for (final row in SiteJson.objects(rows)) ?card(row)]);
    }
    return null;
  }

  /// The rooms of the website's top list, one page.
  static List<LiveRoom> topRooms(String body, {int status = 200}) {
    final data = webData(body, what: 'Live_top_pc', status: status);
    final rows = data['list'];
    if (rows is! List || rows.length > 1000) {
      throw SiteApiChangedError('inke Live_top_pc: ${rows is List ? '${rows.length} rows' : 'no list'}');
    }
    return unique([for (final row in SiteJson.objects(rows)) ?card(row)]);
  }

  /// The app's hot list: every card live, with the app's title, cover, start
  /// time and audience.
  ///
  /// A row that is not a live broadcast (`status` 1), or that names no
  /// anchor or broadcast, is skipped.
  static List<LiveRoom> hotRooms(String body, {int status = 200}) {
    final root = appData(body, what: 'simpleall', status: status);
    return unique([for (final row in SiteJson.objects(root['lives'])) ?appCard(row)]);
  }

  /// One showcase row as a room: live, the nickname as its title, the
  /// portrait as avatar and cover, no audience (the showcases carry none).
  /// Null for a row without an anchor, a broadcast or a nickname.
  static LiveRoom? card(Map<String, Object?> row) {
    final uid = SiteText.trimmed(row['uid']);
    final nick = SiteText.title(SiteText.text(row['nick']));
    if (!isUid(uid) || nick.isEmpty || SiteText.trimmed(row['live_id']).isEmpty) {
      return null;
    }
    final portrait = image(row['portrait']);
    return LiveRoom(
      platform: SiteIds.inke,
      roomId: uid,
      nick: nick,
      title: nick,
      avatar: portrait,
      cover: portrait,
      status: LiveStatus.live,
    );
  }

  /// One app hot row as a room, or null when it is not a live broadcast or
  /// names no anchor.
  ///
  /// `numbers.real` is the "N人在看" the app shows (concurrent viewers) and
  /// `online_users` the larger display figure, kept as the audience the site
  /// publishes beside it; a broadcast the app gave no line is not restricted,
  /// a row without a line says nothing.
  static LiveRoom? appCard(Map<String, Object?> row) {
    final creator = SiteJson.object(row['creator']);
    final uid = SiteText.trimmed(creator['id']);
    if (!isUid(uid) || SiteText.trimmed(row['id']).isEmpty || SiteCounts.integer(row['status']) != 1) {
      return null;
    }
    final nick = SiteText.title(SiteText.text(creator['nick']));
    final title = SiteText.title(SiteText.text(row['name']));
    final avatar = image(creator['portrait']);
    final cover = image(row['cover']);
    final numbers = SiteJson.object(row['numbers']);
    final online = SiteCounts.integer(numbers['real']);
    final heat = SiteCounts.integer(row['online_users']);
    final seconds = SiteCounts.integer(row['start_time']);
    return LiveRoom(
      platform: SiteIds.inke,
      roomId: uid,
      nick: nick,
      title: title.isEmpty ? nick : title,
      avatar: avatar,
      cover: cover ?? avatar,
      watching: online ?? heat,
      onlineViewers: online,
      status: LiveStatus.live,
      startedAt: seconds == null || seconds < 946684800
          ? null
          : DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true),
      restriction: (row['stream_addr']?.toString() ?? '').startsWith('http') ? LiveRestriction.none : null,
    );
  }

  /// [rooms] with each anchor once (the first wins), in order: a room is the
  /// anchor's, so a list showing one twice shows it once.
  static List<LiveRoom> unique(Iterable<LiveRoom> rooms) {
    final seen = <String>{};
    return [
      for (final room in rooms)
        if (seen.add(room.roomId)) room,
    ];
  }

  /// Decodes a body and returns its `data` object; null when the answer
  /// says the anchor has no broadcast ("当前用户无直播").
  static Map<String, Object?>? data(String body, {int status = 200, String what = 'response'}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('inke $what: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw SiteApiChangedError('inke $what: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw SiteApiChangedError('inke $what: body is not an object');
    }
    final data = decoded['data'];
    if (data is String && data.contains('无直播')) {
      return null;
    }
    if (data is! Map<String, Object?>) {
      throw SiteApiChangedError('inke $what: no data object');
    }
    return data;
  }

  /// `live_share_pc` → the room; null when the anchor is not broadcasting.
  static LiveRoom? room(String body, {required String uid, int status = 200}) {
    final info = data(body, status: status, what: 'live_share_pc');
    if (info == null) {
      return LiveRoom(platform: SiteIds.inke, roomId: uid, status: LiveStatus.offline);
    }
    final liveUid = info['live_uid']?.toString() ?? '';
    final liveStatus = info['status'];
    if (liveUid != uid || !(liveStatus == 1 || liveStatus == '1' || liveStatus == true)) {
      throw SiteApiChangedError('inke live_share_pc: not the live room of $uid');
    }
    final liveId = info['liveid']?.toString() ?? '';
    final owner = info['media_info'];
    final ownerMap = owner is Map<String, Object?> ? owner : const <String, Object?>{};
    final nick = ownerMap['nick']?.toString() ?? '';
    if (liveId.isEmpty || nick.isEmpty) {
      throw const SiteApiChangedError('inke live_share_pc: incomplete live broadcast');
    }
    final name = info['live_name']?.toString() ?? '';
    return LiveRoom(
      platform: SiteIds.inke,
      roomId: uid,
      title: name.isEmpty ? nick : name,
      nick: nick,
      avatar: image(ownerMap['portrait']),
      cover: image(info['portrait']),
      status: LiveStatus.live,
      data: {'liveId': liveId},
    );
  }

  /// `now_publish` → the broadcast's play lines and live facts; null when
  /// the anchor is not live. `stream_addr` is the Wangsu H.264 pull URL,
  /// `stream_multi_addr` the Zego original.
  static ({List<LivePlayLine> lines, String? cover, int? watching, DateTime? startedAt})? broadcast(
    String body, {
    required String uid,
    int status = 200,
  }) {
    final data = InkeParser.data(body, status: status, what: 'now_publish');
    if (data == null) {
      return null;
    }
    final live = data['live'];
    if (live is! Map<String, Object?>) {
      return null;
    }
    if (live['creator']?.toString() != uid) {
      throw SiteApiChangedError('inke now_publish: a broadcast of ${live['creator']} for $uid');
    }
    if ((live['status'] as num?)?.toInt() != 1) {
      return null;
    }
    final lines = <LivePlayLine>[];
    final pull = live['stream_addr']?.toString() ?? '';
    if (pull.startsWith('http')) {
      lines.add(LivePlayLine(url: pull, headers: headers, format: StreamFormat.flv, lineId: 'flv'));
    }
    final origin = live['stream_multi_addr']?.toString() ?? '';
    if (origin.startsWith('http')) {
      lines.add(LivePlayLine(url: origin, headers: headers, format: StreamFormat.flv, lineId: 'original'));
    }
    final numbers = live['numbers'];
    final online = numbers is Map<String, Object?> ? (numbers['real'] as num?)?.toInt() : null;
    final startedSeconds = (live['start_time'] as num?)?.toInt();
    return (
      lines: lines,
      cover: image(live['cover']),
      watching: online ?? (live['online_users'] as num?)?.toInt(),
      startedAt: startedSeconds == null || startedSeconds < 946684800
          ? null
          : DateTime.fromMillisecondsSinceEpoch(startedSeconds * 1000, isUtc: true),
    );
  }

  /// Passes a full URL through, else null.
  static String? image(Object? value) {
    final url = value?.toString() ?? '';
    return url.isEmpty ? null : url;
  }
}
