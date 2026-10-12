import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the FC2 Live member API.
abstract final class Fc2LiveParser {
  /// Web origin.
  static const String origin = 'https://live.fc2.com';

  /// The member API endpoint.
  static const String memberPath = '/api/memberApi.php';

  /// Request headers.
  static const Map<String, String> headers = {
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'accept': 'application/json, text/javascript, */*; q=0.01',
    'accept-language': 'ja,en-US;q=0.9,en;q=0.8',
    'origin': origin,
    'referer': '$origin/',
    'x-requested-with': 'XMLHttpRequest',
    'content-type': 'application/x-www-form-urlencoded; charset=UTF-8',
  };

  /// Media headers of the channel page.
  static Map<String, String> mediaHeaders(String channelId) => {
    'user-agent': headers['user-agent']!,
    'referer': '$origin/$channelId/',
  };

  /// The whole-channel-list endpoint: the directory is one answer carrying
  /// every channel on air, paged locally.
  static const String snapshotPath = '/contents/allchannellist.php';

  /// Rooms one directory page shows (the site's own page size).
  static const int directoryPageSize = 20;

  /// The last directory page a caller may ask for.
  static const int maxPage = 10000;

  /// The id of the area that keeps every channel.
  static const String allAreaId = 'all';

  /// The areas, in the site's own order: everything first, then the
  /// categories the site files its channels under.
  static const List<({String id, String name})> areaCatalog = [
    (id: allAreaId, name: '全部公开直播'),
    (id: '1', name: '闲聊'),
    (id: '2', name: '游戏 / 作业'),
    (id: '4', name: '视频'),
    (id: '9', name: '音频'),
    (id: '5', name: '其他'),
  ];

  /// The catalogue: six constant areas, so no request is spent finding them
  /// out.
  static List<LiveArea> areas() => [
    for (final (index, area) in areaCatalog.indexed) LiveArea(id: area.id, name: area.name, sort: index),
  ];

  /// The category an area id keeps: null for [allAreaId] (everything), else
  /// 1, 2, 4, 5 or 9; null too for an id the catalogue does not know, which
  /// is the caller's mistake rather than a listing this site has.
  static int? areaFilter(LiveArea area) {
    if (area.id.trim() == allAreaId) {
      return null;
    }
    final value = SiteCounts.integer(area.id);
    return value != null && const {1, 2, 4, 5, 9}.contains(value) ? value : null;
  }

  /// Whether a channel of [categoryId] belongs to the area [filter] keeps:
  /// every area for null, and the site's own "game or work" area (2) also
  /// keeps category 3, which has no area of its own.
  static bool inArea(int categoryId, int? filter) =>
      filter == null || categoryId == filter || (filter == 2 && categoryId == 3);

  /// The name of the area [categoryId] belongs to; empty for the site's own
  /// categories outside the catalogue (0 and 8 are its "unknown", 6 premium,
  /// 7 official).
  static String areaName(int categoryId) => switch (categoryId) {
    1 || 4 || 5 || 9 => areaCatalog.firstWhere((area) => area.id == '$categoryId').name,
    2 || 3 => '游戏 / 作业',
    _ => '',
  };

  /// The `allchannellist` URL.
  static Uri snapshotUrl() => Uri.parse('$origin$snapshotPath');

  /// An `allchannellist` answer: every channel on air, in the site's order,
  /// with the category each is filed under.
  ///
  /// Rows that are not public rooms (`type` 1 is a public broadcast; open
  /// chats and private two-shots are the others) are skipped. Restricted
  /// channels — paid, ticketed, for signed-in viewers — stay listed, live and
  /// marked, because the site shows them and the play path is where the
  /// refusal belongs. A row that cannot be read costs itself, while an answer
  /// none of whose rows can be read is a changed endpoint. `time` must be a
  /// moment, which is what tells a real answer from an empty stand-in.
  static List<({LiveRoom room, int categoryId})> snapshot(String body, {int status = 200}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('fc2live allchannellist: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const SiteApiChangedError('fc2live allchannellist: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const SiteApiChangedError('fc2live allchannellist: body is not an object');
    }
    if ((SiteCounts.integer(decoded['time']) ?? 0) < 1) {
      throw const SiteApiChangedError('fc2live allchannellist: no time');
    }
    final rows = decoded['channel'];
    if (rows is! List || rows.length > 1000) {
      throw const SiteApiChangedError('fc2live allchannellist: no channel list');
    }
    final seen = <String>{};
    final channels = <({LiveRoom room, int categoryId})>[];
    var unreadable = 0;
    for (final raw in rows) {
      final data = SiteJson.object(raw);
      if (SiteCounts.integer(data['type']) != 1) {
        continue;
      }
      final channel = card(data);
      if (channel == null) {
        unreadable++;
        continue;
      }
      if (seen.add(channel.room.roomId)) {
        channels.add(channel);
      }
    }
    if (channels.isEmpty && unreadable > 0) {
      throw SiteApiChangedError('fc2live allchannellist: none of $unreadable rows can be read');
    }
    return channels;
  }

  /// One list row as a room with the category it is filed under, or null when
  /// the row names no channel.
  ///
  /// The title falls back to the broadcaster's name, the card's `pay`/`tid`
  /// marks make a paid broadcast and its `login` mark one for signed-in
  /// viewers, and `start_time` is Unix milliseconds.
  static ({LiveRoom room, int categoryId})? card(Map<String, Object?> data) {
    final roomId = channelId(SiteText.text(data['id']));
    if (roomId == null || !RegExp(r'^[0-9]{1,12}$').hasMatch(roomId)) {
      return null;
    }
    final categoryId = SiteCounts.integer(data['category']) ?? 0;
    final name = SiteText.title(SiteText.text(data['name']));
    final title = SiteText.title(SiteText.text(data['title']));
    final pay = SiteCounts.integer(data['pay']) ?? 0;
    final ticket = SiteCounts.integer(data['tid']) ?? 0;
    final login = SiteCounts.integer(data['login']) ?? 0;
    final restriction = pay != 0 || ticket != 0
        ? LiveRestriction.paid
        : login != 0
        ? LiveRestriction.needsLogin
        : LiveRestriction.none;
    final startedMilliseconds = SiteCounts.integer(data['start_time']);
    final started = startedMilliseconds == null || startedMilliseconds < 946684800000
        ? null
        : DateTime.fromMillisecondsSinceEpoch(startedMilliseconds, isUtc: true);
    return (
      room: LiveRoom(
        platform: SiteIds.fc2Live,
        roomId: roomId,
        title: title.isEmpty ? name : title,
        nick: name,
        cover: _image(data['image']),
        areaName: areaName(categoryId),
        watching: SiteCounts.integer(data['count']),
        status: LiveStatus.live,
        startedAt: started,
        restriction: restriction,
      ),
      categoryId: categoryId,
    );
  }

  /// The channel id of the input: a channel number or a channel link.
  static String? channelId(String raw) {
    final input = raw.trim();
    if (RegExp(r'^\d{1,12}$').hasMatch(input)) {
      return input;
    }
    final uri = Uri.tryParse(input);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host != 'live.fc2.com') {
      return null;
    }
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
    for (final segment in segments.reversed) {
      if (RegExp(r'^\d{1,12}$').hasMatch(segment)) {
        return segment;
      }
    }
    return null;
  }

  /// `memberApi` → the room and the channel's `version` (the control grant
  /// needs it, the room does not keep it). `status` 1 with data means the
  /// channel exists; `is_publish` 1 means on air.
  static ({LiveRoom room, String version}) room(String body, {required String channelId, int status = 200}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('fc2live memberApi: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const SiteApiChangedError('fc2live memberApi: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const SiteApiChangedError('fc2live memberApi: body is not an object');
    }
    if ((decoded['status'] as num?)?.toInt() != 1) {
      throw SiteNotFoundError('fc2live memberApi: no channel $channelId');
    }
    final data = decoded['data'];
    final channel = data is Map<String, Object?> ? data['channel_data'] : null;
    if (channel is! Map<String, Object?>) {
      throw const SiteApiChangedError('fc2live memberApi: no channel_data');
    }
    final id = channel['channelid']?.toString() ?? '';
    if (id != channelId) {
      throw SiteApiChangedError('fc2live memberApi: answered $id for $channelId');
    }
    final rawProfile = data is Map<String, Object?> ? data['profile_data'] : null;
    final profile = rawProfile is Map<String, Object?> ? rawProfile : const <String, Object?>{};
    final published = (channel['is_publish'] as num?)?.toInt() == 1;
    final emailOnly = (channel['is_limited'] as num?)?.toInt() == 1;
    final loginOnly = (channel['login_only'] as num?)?.toInt() == 1;
    final name = (profile['name'] ?? channel['tname'])?.toString() ?? '';
    final startSeconds = (channel['start'] as num?)?.toInt();
    final version = channel['version']?.toString() ?? '';
    return (
      room: LiveRoom(
        platform: SiteIds.fc2Live,
        roomId: channelId,
        title: channel['title']?.toString() ?? name,
        nick: name,
        avatar: _image(profile['icon'] ?? profile['image']),
        cover: _image(channel['image']),
        watching: (channel['count'] as num?)?.toInt(),
        status: published ? LiveStatus.live : LiveStatus.offline,
        restriction: published && emailOnly
            ? LiveRestriction.needsLogin
            : published && loginOnly
            ? LiveRestriction.needsLogin
            : null,
        startedAt: published && startSeconds != null && startSeconds > 0
            ? DateTime.fromMillisecondsSinceEpoch(startSeconds * 1000, isUtc: true)
            : null,
      ),
      version: version,
    );
  }

  /// The `getControlServer.php` path, the anonymous control grant.
  static const String controlPath = '/api/getControlServer.php';

  /// `getControlServer` → the control socket of [channelId] and its handshake:
  /// the `wss://` endpoint carrying the `control_token`, and the headers with
  /// the `l_ortkn` session cookie. `status` other than 0 is a channel not on
  /// air or restricted (a [SiteNotFoundError]). A socket that is not this
  /// channel's `wss` control socket, a token or `orz_raw` that is empty, too
  /// long, or not cookie-safe, are a [SiteApiChangedError].
  static ({Uri endpoint, Map<String, String> headers}) grant(
    String body, {
    required String channelId,
    int status = 200,
  }) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('fc2live getControlServer: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const SiteApiChangedError('fc2live getControlServer: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const SiteApiChangedError('fc2live getControlServer: body is not an object');
    }
    if ((decoded['status'] as num?)?.toInt() != 0) {
      throw SiteNotFoundError('fc2live getControlServer: not on air or restricted (status ${decoded['status']})');
    }
    final url = decoded['url']?.toString() ?? '';
    final token = decoded['control_token']?.toString() ?? '';
    final orz = decoded['orz_raw']?.toString() ?? '';
    final socket = url.isEmpty || url.length > 2048 || token.isEmpty || token.length > 4096 ? null : Uri.tryParse(url);
    if (socket == null ||
        socket.scheme != 'wss' ||
        socket.userInfo.isNotEmpty ||
        !_isControlHost(socket.host) ||
        socket.path != '/control/channels/$channelId' ||
        socket.hasQuery ||
        socket.hasFragment ||
        orz.isEmpty ||
        orz.length > 256 ||
        !RegExp(r'^[A-Za-z0-9._~-]+$').hasMatch(orz)) {
      throw const SiteApiChangedError('fc2live getControlServer: not a control socket of the channel');
    }
    return (
      endpoint: socket.replace(queryParameters: {'control_token': token}),
      headers: {'origin': origin, 'user-agent': headers['user-agent']!, 'cookie': 'l_ortkn=$orz'},
    );
  }

  static bool _isControlHost(String host) => host == 'live.fc2.com' || host.endsWith('.live.fc2.com');

  static String? _image(Object? value) {
    final url = value?.toString() ?? '';
    return url.isEmpty ? null : url;
  }
}
