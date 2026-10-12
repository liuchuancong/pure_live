import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the SOOP (formerly AfreecaTV) APIs.
abstract final class SoopParser {
  /// Live API host.
  static const String liveHost = 'live.sooplive.co.kr';

  /// Station API host.
  static const String stationHost = 'chapi.sooplive.co.kr';

  /// Web play origin.
  static const String origin = 'https://play.sooplive.co.kr';

  /// Request headers.
  static const Map<String, String> headers = {
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'origin': origin,
    'referer': '$origin/',
  };

  /// The search host: the catalogue and the area listings live on it, not on
  /// the live host.
  static const String searchHost = 'sch.sooplive.co.kr';

  /// Areas one catalogue page asks for (the endpoint's own size).
  static const int categoryPageSize = 120;

  /// Rooms one area or recommendation page carries.
  static const int listingPageSize = 60;

  /// The catalogue pages a browse will walk before stopping.
  static const int maxCategoryPages = 20;

  /// The one category every area is listed under, with 3.x's id and name.
  static const ({String id, String name}) listingCategory = (id: '1', name: '热门');

  /// The URL of catalogue page [page].
  static Uri categoryListUrl(int page) => Uri.https(searchHost, '/api.php', {
    'm': 'categoryList',
    'szKeyword': '',
    'szOrder': 'view_cnt',
    'nPageNo': '$page',
    'nListCnt': '$categoryPageSize',
    'nOffset': '0',
    'szPlatform': 'pc',
  });

  /// The URL of area [categoryNo]'s live listing, page [page].
  static Uri areaListUrl(String categoryNo, int page) => Uri.https(searchHost, '/api.php', {
    'm': 'categoryContentsList',
    'szType': 'live',
    'szCateNo': categoryNo,
    'nPageNo': '$page',
    'nListCnt': '$listingPageSize',
    'szPlatform': 'pc',
  });

  /// The URL of the site's recommendations, page [page] (sixty rooms by
  /// viewers; the list ends with an empty page).
  static Uri recommendUrl(int page) => Uri.https(liveHost, '/api/main_broad_list_api.php', {
    'selectType': 'action',
    'selectValue': 'all',
    'orderType': 'view_cnt',
    'pageNo': '$page',
    'lang': 'ko_KR',
  });

  /// A `categoryList` page: the areas of the one category, in platform order
  /// (most viewers first), and whether another page follows.
  ///
  /// `is_more` says so; without the flag, a full page is the only signal,
  /// which is the rule the previous generation read the endpoint by.
  static ({List<LiveArea> areas, bool hasMore}) categoryPage(String body, {int status = 200}) {
    final data = envelope(body, what: 'categoryList', status: status);
    final rows = listField(data['list'], what: 'categoryList');
    final areas = <LiveArea>[];
    for (final row in SiteJson.objects(rows)) {
      final no = SiteText.trimmed(row['category_no']);
      if (no.isEmpty) {
        continue;
      }
      areas.add(
        LiveArea(id: no, name: SiteText.title(SiteText.text(row['category_name'])), parentId: listingCategory.id),
      );
    }
    final flag = data['is_more'];
    final more = flag == null ? rows.length >= categoryPageSize : truthy(flag);
    return (areas: areas, hasMore: areas.isNotEmpty && more);
  }

  /// A `categoryContentsList` page: the live rooms of one area, each carrying
  /// its start time and restriction, and whether another page follows. The
  /// area's own name labels every card.
  static LivePage<LiveRoom> areaPage(String body, {required String areaName, int status = 200}) {
    final data = envelope(body, what: 'categoryContentsList', status: status);
    final rows = listField(data['list'], what: 'categoryContentsList');
    final items = [
      for (final row in SiteJson.objects(rows))
        ?card(row, cover: row['thumbnail'], avatar: image(row['user_profile_img']), area: areaName),
    ];
    final hasMore = truthy(data['is_more']);
    return LivePage<LiveRoom>(items: items, hasMore: hasMore);
  }

  /// A `main_broad_list_api.php` page: the site's recommendations, sixty
  /// rooms by viewers. The list ends with an empty page.
  ///
  /// This answer is *flat* — `broad` at the top level, no `result` wrapper —
  /// unlike the category endpoints', so it is decoded on its own path.
  static LivePage<LiveRoom> recommendPage(String body, {int status = 200}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('soop main_broad_list: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const SiteApiChangedError('soop main_broad_list: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const SiteApiChangedError('soop main_broad_list: body is not an object');
    }
    final rows = listField(decoded['broad'], what: 'main_broad_list');
    final items = [
      for (final row in SiteJson.objects(rows))
        ?card(row, cover: row['broad_thumb'], area: SiteText.trimmed(row['category_name'])),
    ];
    return LivePage<LiveRoom>(items: items);
  }

  /// One list row as a room, or null when it names no streamer.
  ///
  /// Every list of this site — an area's, the recommendations — carries the
  /// same row shape, differing only in which fields name the cover, the
  /// avatar and the area. The start is a Korean wall clock ([koreanTime]),
  /// the audience the site's own sum ([onlineViewers]), and the restriction
  /// the row's flags ([restrictionOf]).
  static LiveRoom? card(Map<String, Object?> row, {Object? cover, String? avatar, String? area}) {
    final id = SiteText.trimmed(row['user_id']);
    if (id.isEmpty) {
      return null;
    }
    final areaName = SiteText.trimmed(area);
    return LiveRoom(
      platform: SiteIds.soop,
      roomId: id,
      title: display(row['broad_title']),
      nick: display(row['user_nick']),
      avatar: avatar ?? defaultAvatar(id),
      cover: image(cover),
      areaName: areaName.isEmpty ? null : areaName,
      watching: onlineViewers(row),
      status: LiveStatus.live,
      startedAt: koreanTime(row['broad_start']),
      restriction: restrictionOf(
        password: row['is_password'],
        subscribers: row['subscription_only'],
        grade: row['broad_grade'] ?? row['grade'],
      ),
    );
  }

  /// The default avatar URL of streamer [roomId], from the id alone —
  /// some lists name no picture.
  static String? defaultAvatar(String roomId) {
    final id = roomId.trim();
    if (id.length < 2) {
      return null;
    }
    return 'https://stimg.sooplive.co.kr/LOGO/${id.substring(0, 2)}/$id/m/$id.webp';
  }

  /// Concurrent viewers of a list row, by the site's own arithmetic: the
  /// first positive of `total_view_cnt`, `view_cnt` and `VIEW_CNT` (the
  /// totals already count PC and mobile); else a positive `pc_view_cnt` +
  /// `mobile_view_cnt`, then `current_view_cnt` + `m_current_view_cnt`;
  /// else zero when any of them said zero; else null.
  static int? onlineViewers(Map<String, Object?> row) {
    int? zero;
    for (final key in const ['total_view_cnt', 'view_cnt', 'VIEW_CNT']) {
      final value = SiteCounts.integer(row[key]);
      if (value == null) {
        continue;
      }
      if (value > 0) {
        return value;
      }
      zero = 0;
    }
    for (final pair in const [('pc_view_cnt', 'mobile_view_cnt'), ('current_view_cnt', 'm_current_view_cnt')]) {
      final pc = SiteCounts.integer(row[pair.$1]);
      final mobile = SiteCounts.integer(row[pair.$2]);
      if (pc == null || mobile == null) {
        continue;
      }
      final sum = pc + mobile;
      if (sum > 0) {
        return sum;
      }
      zero = 0;
    }
    return zero;
  }

  /// The restriction a row's flags state: a password (`is_password` truthy),
  /// else subscribers only (`subscription_only` above 0), else adult
  /// (`broad_grade`/`grade` 19), else none. A row without the flags says
  /// nothing (null).
  static LiveRestriction? restrictionOf({Object? password, Object? subscribers, Object? grade}) {
    if (password == null && subscribers == null && grade == null) {
      return null;
    }
    if (truthy(password)) {
      return LiveRestriction.password;
    }
    if ((SiteCounts.integer(subscribers) ?? 0) > 0) {
      return LiveRestriction.subscribersOnly;
    }
    if (SiteCounts.integer(grade) == 19) {
      return LiveRestriction.adult;
    }
    return LiveRestriction.none;
  }

  /// A Korean wall clock (`broad_start`, KST — the site's own zone, without
  /// daylight saving) as a moment in time; null for anything else.
  ///
  /// Parsing it as local time would shift every start by the viewer's
  /// offset, the same way the PandaTV start would.
  static DateTime? koreanTime(Object? value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2}):(\d{2})(?:\.\d+)?$')
        .firstMatch(SiteText.trimmed(value));
    if (match == null) {
      return null;
    }
    final parts = [for (var group = 1; group <= 6; group++) int.parse(match.group(group)!)];
    return DateTime.utc(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5]).subtract(const Duration(hours: 9));
  }

  /// Whether [value] says yes the way this site writes it: `true`, 1, or
  /// `true`/`Y`/`yes`/`1` in any case.
  static bool truthy(Object? value) => switch (value) {
    true => true,
    final num number => number == 1,
    final String text => const {'true', 'y', 'yes', '1'}.contains(text.trim().toLowerCase()),
    _ => false,
  };

  /// A title or name as shown: text with HTML entities decoded.
  static String display(Object? value) => SiteText.unescape(SiteText.title(SiteText.text(value)));

  /// A full picture URL, or null.
  static String? image(Object? value) {
    final url = value?.toString() ?? '';
    if (url.isEmpty) {
      return null;
    }
    return url.startsWith('//') ? 'https:$url' : url;
  }

  /// The answer's `data` (`result` 1, else the endpoint changed).
  static Map<String, Object?> envelope(String body, {required String what, int status = 200}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('soop $what: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw SiteApiChangedError('soop $what: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw SiteApiChangedError('soop $what: body is not an object');
    }
    if (SiteCounts.integer(decoded['result']) != 1) {
      throw SiteApiChangedError('soop $what: result ${decoded['result']}');
    }
    final data = decoded['data'];
    if (data is! Map<String, Object?>) {
      throw SiteApiChangedError('soop $what: no data object');
    }
    return data;
  }

  /// A list field: missing is empty, anything else but a list is a changed
  /// endpoint.
  static List<Object?> listField(Object? value, {required String what}) {
    if (value == null) {
      return const [];
    }
    if (value is! List) {
      throw SiteApiChangedError('soop $what: the list is not a list');
    }
    return value;
  }

  /// The media request headers of streamer [roomId]'s pull URLs: the room
  /// page as referer, as the site's own player sends them.
  static Map<String, String> mediaHeaders(String roomId) => {
    'user-agent': headers['user-agent']!,
    'origin': origin,
    'referer': roomPageUrl(roomId),
  };

  /// The room page URL.
  static String roomPageUrl(String roomId) => '$origin/${Uri.encodeComponent(roomId.trim())}';

  /// The `player_live_api.php` URL for [roomId].
  static Uri playerUrl(String roomId) => Uri.https(liveHost, '/afreeca/player_live_api.php', {'bjid': roomId});

  /// The player form of [roomId]: `live` for the room, `aid` for a
  /// stream key.
  static Map<String, String> playerForm(
    String roomId, {
    required String type,
    String bno = '',
    String quality = 'HD',
  }) => {
    'bid': roomId,
    'bno': bno,
    'type': type,
    'pwd': '',
    'player_type': 'html5',
    'stream_type': 'common',
    'quality': quality,
    'mode': 'landing',
    'from_api': '0',
    'is_revive': 'false',
  };

  /// Validates the `{CHANNEL: {...}}` answer and returns `(result, fields)`.
  static ({int result, Map<String, Object?> fields}) channel(String body, {int status = 200}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('soop player_live_api: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const SiteApiChangedError('soop player_live_api: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const SiteApiChangedError('soop player_live_api: body is not an object');
    }
    final channel = decoded['CHANNEL'];
    if (channel is! Map<String, Object?>) {
      throw const SiteApiChangedError('soop player_live_api: no CHANNEL');
    }
    return (result: SiteCounts.integer(channel['RESULT']) ?? 0, fields: channel);
  }

  /// The room snapshot from a `type=live` answer. RESULT 1 is live, 0
  /// offline, -2 banned; -6/-8/-14 are live with the adult, password and
  /// subscribers-only restrictions.
  static LiveRoom room(String body, {required String roomId, int status = 200}) {
    final (:result, :fields) = channel(body, status: status);
    final id = roomId.trim();
    final title = fields['TITLE']?.toString() ?? '';
    switch (result) {
      case 0:
        return LiveRoom(platform: SiteIds.soop, roomId: id, status: LiveStatus.offline);
      case -2:
        return LiveRoom(platform: SiteIds.soop, roomId: id, status: LiveStatus.banned);
      case -6 || -8 || -14:
        return LiveRoom(
          platform: SiteIds.soop,
          roomId: id,
          title: title,
          status: LiveStatus.live,
          restriction: switch (result) {
            -6 => LiveRestriction.needsLogin,
            -8 => LiveRestriction.needsLogin,
            _ => LiveRestriction.needsLogin,
          },
          startedAt: _startedBefore(fields['BTIME']),
        );
      case 1:
        break;
      default:
        throw SiteApiChangedError('soop player_live_api: RESULT $result');
    }
    final bno = fields['BNO']?.toString() ?? '';
    final bj = fields['BJID']?.toString() ?? id;
    final live = fields['VIEWPRESET'] != null;
    final viewers = _int(fields['VIEWPRESET'] == null ? null : fields['VISITOR_COUNT'] ?? fields['VIEWER_COUNT']);
    final chat = live ? _chat(fields, id) : null;
    return LiveRoom(
      platform: SiteIds.soop,
      roomId: id,
      title: title,
      nick: fields['BJNICK']?.toString() ?? '',
      avatar: bj.length < 2 ? null : 'https://stimg.sooplive.co.kr/LOGO/${bj.substring(0, 2)}/$bj/$bj.jpg',
      cover: bno.isEmpty ? null : _cover(bno, DateTime.now()),
      areaName: _firstTag(fields['CATEGORY_TAGS']),
      watching: viewers,
      status: live ? LiveStatus.live : LiveStatus.offline,
      startedAt: live ? _startedBefore(fields['BTIME']) : null,
      data: live
          ? {
              'bno': bno,
              'rmd': fields['RMD']?.toString() ?? '',
              'cdn': fields['CDN']?.toString() ?? '',
              'presets': presets(fields['VIEWPRESET']),
              if (chat != null) 'chatNo': chat.chatNo,
              if (chat != null) 'chatHost': chat.host,
              if (chat != null) 'chatPort': chat.port,
            }
          : null,
    );
  }

  /// The chat server of a `CHANNEL` for streamer [roomId]: host `CHDOMAIN`,
  /// else `chat-<CHIP as eight hex digits>.sooplive.com`, and the plain port
  /// `CHPT` (the socket dials `CHPT + 1` for TLS). Null without `CHATNO`, a
  /// host or a usable port — as 3.x connected nothing then. This rides in
  /// `room.data`, never JSON: a reconnect re-reads it from the live answer.
  static ({String host, int port, String chatNo})? _chat(Map<String, Object?> channel, String roomId) {
    final chatNo = channel['CHATNO']?.toString().trim() ?? '';
    final domain = channel['CHDOMAIN']?.toString().trim();
    final host = domain != null && domain.isNotEmpty ? domain : _chatHost(channel['CHIP']?.toString().trim() ?? '');
    final port = _int(channel['CHPT']);
    if (roomId.isEmpty ||
        chatNo.isEmpty ||
        host == null ||
        host.isEmpty ||
        port == null ||
        port <= 0 ||
        port >= 65535) {
      return null;
    }
    return (host: host, port: port, chatNo: chatNo);
  }

  /// `chat-<IPv4 as eight hex digits>.sooplive.com`, or null for anything but
  /// a dotted quad: the fallback chat host when `CHDOMAIN` is absent.
  static String? _chatHost(String ip) {
    final parts = ip.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((part) => part == null || part < 0 || part > 255)) {
      return null;
    }
    return 'chat-${[for (final part in parts) part!.toRadixString(16).padLeft(2, '0')].join().toUpperCase()}.sooplive.com';
  }

  /// The presets of a `VIEWPRESET` list: name and codec.
  static List<({String name, String? codec})> presets(Object? value) {
    if (value is! List) {
      return const [];
    }
    final presets = <({String name, String? codec})>[];
    for (final item in value) {
      if (item is! Map<String, Object?>) {
        continue;
      }
      final name = item['name']?.toString().trim() ?? '';
      if (name.isEmpty) {
        continue;
      }
      presets.add((
        name: name,
        codec: switch (item['vcodec']?.toString().trim().toLowerCase()) {
          'h264' || 'avc' => 'avc',
          'h265' || 'hevc' => 'hevc',
          _ => null,
        },
      ));
    }
    return presets;
  }

  /// The `return_type` of the stream assignment for CDN code [cdn].
  static String returnType(String cdn) {
    if (cdn.contains('gs_cdn')) {
      return 'gs_cdn_pc_web';
    }
    if (cdn.contains('lg_cdn')) {
      return 'lg_cdn_pc_web';
    }
    return cdn;
  }

  /// The `<RMD>/broad_stream_assign.html` URL for [quality] of [bno].
  static Uri assignUrl({required String rmd, required String cdn, required String bno, required String quality}) {
    final base = Uri.tryParse('${rmd.replaceAll(RegExp(r'/$'), '')}/broad_stream_assign.html');
    if (base == null || !(base.isScheme('http') || base.isScheme('https')) || base.host.isEmpty) {
      throw SiteApiChangedError('soop player_live_api: RMD "$rmd" is not a URL');
    }
    return base.replace(queryParameters: {'return_type': returnType(cdn), 'broad_key': '$bno-common-$quality-hls'});
  }

  /// `broad_stream_assign.html` → the playlist URL (`view_url`).
  static String assignedPlaylist(String body, {int status = 200}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('soop broad_stream_assign: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const SiteApiChangedError('soop broad_stream_assign: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw const SiteApiChangedError('soop broad_stream_assign: body is not an object');
    }
    if (SiteCounts.integer(decoded['result']) != 1) {
      throw SiteNotFoundError('soop broad_stream_assign: result ${decoded['result']}');
    }
    final url = decoded['view_url']?.toString() ?? '';
    if (!url.startsWith('http')) {
      throw const SiteApiChangedError('soop broad_stream_assign: no view_url');
    }
    return url;
  }

  /// A `type=aid` answer → the stream key. RESULT -6 is age-restricted.
  static String aid(String body, {int status = 200}) {
    final (:result, :fields) = channel(body, status: status);
    if (result == -6) {
      throw const SiteNotFoundError('soop aid: RESULT -6 (age-restricted broadcast)');
    }
    final aid = fields['AID']?.toString() ?? '';
    if (result != 1 || aid.isEmpty) {
      throw SiteNotFoundError('soop aid: RESULT $result');
    }
    return aid;
  }

  /// The play line of [playlist] with stream key [aid]: `?aid=` appended,
  /// HLS, the CDN as line id.
  static LivePlayLine line({
    required String playlist,
    required String aid,
    required String roomId,
    required String cdn,
    String? codec,
  }) => LivePlayLine(
    url: '$playlist?aid=$aid',
    headers: mediaHeaders(roomId),
    format: StreamFormat.hls,
    codec: codec,
    lineId: cdn.isEmpty ? 'hls' : cdn,
  );

  /// The cover of broadcast [bno] (the platform serves it per broadcast).
  static String _cover(String bno, DateTime now) => 'https://liveimg.sooplive.co.kr/m/$bno';

  static String? _firstTag(Object? value) {
    if (value is List) {
      for (final tag in value) {
        final text = tag?.toString() ?? '';
        if (text.isNotEmpty) {
          return text;
        }
      }
    }
    return null;
  }

  /// `BTIME` (Unix seconds) as a time; null unless positive seconds.
  static DateTime? _startedBefore(Object? value) {
    final seconds = _int(value);
    if (seconds == null || seconds <= 0 || seconds > 9999999999) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  static int? _int(Object? value) => value is num ? value.toInt() : int.tryParse(value?.toString().trim() ?? '');
}
