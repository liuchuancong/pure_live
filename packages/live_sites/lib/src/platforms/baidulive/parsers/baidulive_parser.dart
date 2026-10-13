import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:live_sites/live_sites.dart';

/// A channel of the PC feed: the feed's `tab` (its id) and its `channel_id`.
typedef BaiduLiveChannel = ({String id, String name, int channelId});

/// Static parsers for the Baidu Live room command (searchbox 371).
abstract final class BaiduLiveParser {
  /// API request headers.
  static const Map<String, String> apiHeaders = {
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'referer': 'https://live.baidu.com/',
  };

  /// The PC feed endpoint (a signed form POST).
  static final Uri feedUrl = Uri.https('tiebac.baidu.com', '/livefeed/feed');

  /// The headers of a feed POST: [apiHeaders] and the form's content type
  /// without a charset.
  static const Map<String, String> feedHeaders = {...apiHeaders, 'content-type': 'application/x-www-form-urlencoded'};

  /// The web constant of the feed signature.
  static const String _feedSecret = 'CtmXzYPtdE58nCCcvqM0ectyqW3N5rfY';

  /// The largest feed answer read.
  static const int _responseLimit = 4 * 1024 * 1024;

  /// The last feed page asked for.
  static const int maxPage = 10000;

  /// Items of a full feed page (fewer ends the directory).
  static const int fullPage = 10;

  /// The site's channels until the first feed page brings the platform's list.
  static const List<BaiduLiveChannel> fallbackChannels = [
    (id: 'rec', name: '推荐', channelId: 570),
    (id: 'shopping', name: '购物', channelId: 574),
    (id: 'finance', name: '财经', channelId: 611),
    (id: 'health', name: '健康', channelId: 612),
    (id: 'education', name: '教育', channelId: 613),
    (id: 'news', name: '新闻', channelId: 575),
    (id: 'leisure', name: '休闲', channelId: 616),
  ];

  /// A feed signature: md5 of the fields other than `sign`, sorted by name and
  /// joined as `k=v&k=v`, followed by `&` and the web constant.
  static String signFeed(Map<String, String> fields) {
    final keys = fields.keys.where((key) => key != 'sign').toList(growable: false)..sort();
    final canonical = keys.map((key) => '$key=${fields[key]}').join('&');
    return md5.convert(utf8.encode('$canonical&$_feedSecret')).toString();
  }

  /// The signed feed form of [channel]: the first page ([first]) asks for the
  /// banner, the tabs and the feed with a new session and `refresh_index` 1; a
  /// later page continues [sessionId] at [refreshIndex].
  static Map<String, String> feedForm({
    required BaiduLiveChannel channel,
    required bool first,
    required String deviceId,
    required DateTime now,
    required String sessionId,
    required int refreshIndex,
  }) {
    final form = <String, String>{
      'appname': 'pclive',
      'sid': '',
      'ua': '320_480_pc_1.0_0',
      'uid': deviceId,
      'timestamp': '${now.millisecondsSinceEpoch ~/ 1000}',
      'source': 'pclive',
      'resource': first ? 'banner,tab,feed' : 'feed',
      'scene': 'pc_channel',
      'session_id': first ? '' : sessionId,
      'refresh_type': first ? '0' : '1',
      'refresh_index': '$refreshIndex',
      'tab': channel.id,
      'channel_id': '${channel.channelId}',
    };
    form['sign'] = signFeed(form);
    return form;
  }

  /// The feed form encoded as a body (empty fields bare, `sid&`).
  static String feedBody(Map<String, String> form) => Uri(queryParameters: form).query;

  /// One feed page: `errno` and the feed's `inner_errno` must be 0 and the
  /// session and refresh index given (`SiteApiChangedError` otherwise); the
  /// cards are each room once; the channels are the `tab` block's (empty when
  /// that block failed, keeping the site's list); a page of [fullPage] items or
  /// more has more.
  static ({List<LiveRoom> rooms, List<BaiduLiveChannel> channels, String sessionId, int refreshIndex, bool hasMore})
  page(String body, {int status = 200}) {
    const what = 'feed';
    final data = SiteJson.object(_answer(body, what: what, status: status)['data']);
    final feed = SiteJson.object(data['feed']);
    if (SiteCounts.integer(feed['inner_errno']) != 0) {
      throw SiteApiChangedError('baidulive $what: inner_errno ${feed['inner_errno']}');
    }
    final items = SiteJson.list(feed['items']);
    final seen = <String>{};
    final rooms = <LiveRoom>[];
    for (final item in items) {
      final room = feedCard(item);
      if (room != null && seen.add(room.roomId)) {
        rooms.add(room);
      }
    }
    final sessionId = SiteText.trimmed(feed['session_id']);
    final refreshIndex = SiteCounts.integer(feed['refresh_index']);
    if (sessionId.isEmpty || refreshIndex == null) {
      throw SiteApiChangedError(
        'baidulive $what: session ${feed['session_id']}, refresh_index ${feed['refresh_index']}',
      );
    }
    return (
      rooms: rooms,
      channels: pageChannels(data['tab']),
      sessionId: sessionId,
      refreshIndex: refreshIndex,
      hasMore: items.length >= fullPage,
    );
  }

  /// The channels of a feed's `tab` block: `type` (a lower-case id), `name` and
  /// a positive `channel_id`, each id once. Empty without the block or when it
  /// failed.
  static List<BaiduLiveChannel> pageChannels(Object? value) {
    if (value is! Map<String, Object?> || value.isEmpty) {
      return const [];
    }
    if (SiteCounts.integer(value['inner_errno']) != 0) {
      return const [];
    }
    final seen = <String>{};
    final channels = <BaiduLiveChannel>[];
    for (final entry in SiteJson.objects(value['items'])) {
      final id = SiteText.trimmed(entry['type']).toLowerCase();
      final name = SiteText.trimmed(entry['name']);
      final channelId = SiteCounts.integer(entry['channel_id']);
      if (_tab.hasMatch(id) && name.isNotEmpty && channelId != null && channelId > 0 && seen.add(id)) {
        channels.add((id: id, name: name, channelId: channelId));
      }
    }
    return channels;
  }

  /// The channels as the flat selectable areas `getCategoryRooms` accepts (the
  /// channel id is the area id).
  static List<LiveArea> channelAreas(List<BaiduLiveChannel> channels) => [
    for (final channel in channels) LiveArea(id: channel.id, name: channel.name),
  ];

  /// A feed card: `room_id`, the anchor `host.uk`/`name`/`avatar`, `title`,
  /// `cover`, `live_tag` (else `left_label.text`) and, while live,
  /// `audience_count`; `live_status` 1 live, 0 preview or 2 offline, 3 ended (a
  /// replay), else unknown. The restriction: paid by `has_pay_service`; an
  /// ended card without a recording in its `play_url` is `unplayable`; a live
  /// card without `has_pay_service` does not tell. Null without a room id.
  static LiveRoom? feedCard(Object? value) {
    if (value is! Map<String, Object?>) {
      return null;
    }
    final item = value;
    final roomId = parseRoomId(SiteText.trimmed(item['room_id']));
    if (roomId == null) {
      return null;
    }
    final host = SiteJson.object(item['host']);
    final nick = SiteText.trimmed(host['name']);
    final state = switch (SiteCounts.integer(item['live_status'])) {
      1 => LiveStatus.live,
      0 || 2 => LiveStatus.offline,
      3 => LiveStatus.replay,
      _ => LiveStatus.unknown,
    };
    final payFlag = SiteCounts.integer(item['has_pay_service']);
    final paid = (payFlag ?? 0) > 0;
    return LiveRoom(
      platform: SiteIds.baiduLive,
      roomId: roomId,
      title: _firstText([item['title'], nick]),
      nick: nick,
      avatar: _hostImage(host['avatar']),
      cover: _hostImage(item['cover']),
      areaName: _firstText([item['live_tag'], SiteJson.object(item['left_label'])['text']]),
      watching: state == LiveStatus.live ? SiteCounts.integer(item['audience_count']) : null,
      status: state,
      restriction: switch (state) {
        LiveStatus.live || LiveStatus.replay when paid => LiveRestriction.paid,
        LiveStatus.live => payFlag == null ? null : LiveRestriction.none,
        LiveStatus.replay =>
          _replayUrl(item['play_url'], roomId) == null ? LiveRestriction.unplayable : LiveRestriction.none,
        _ => null,
      },
    );
  }

  /// An answer as a JSON object whose `errno` is 0 (else
  /// [SiteApiChangedError]); its status failure is thrown first.
  static Map<String, Object?> _answer(String body, {required String what, required int status}) {
    if (status < 200 || status >= 300) {
      throw switch (status) {
        400 || 422 => SiteApiChangedError('baidulive $what: HTTP $status'),
        401 || 403 => SiteRiskControlError('baidulive $what: HTTP $status'),
        451 => SiteRegionBlockedError('baidulive $what: HTTP $status'),
        404 || 410 => SiteNotFoundError('baidulive $what: HTTP $status'),
        429 => SiteRateLimitedError('baidulive $what: HTTP $status'),
        _ => SiteApiChangedError('baidulive $what: HTTP $status'),
      };
    }
    if (body.length > _responseLimit) {
      throw SiteApiChangedError('baidulive $what: answer over $_responseLimit characters');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw SiteApiChangedError('baidulive $what: not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw SiteApiChangedError('baidulive $what: not a JSON object');
    }
    if (SiteCounts.integer(decoded['errno']) != 0) {
      throw SiteApiChangedError('baidulive $what: errno ${decoded['errno']} ${SiteText.trimmed(decoded['errmsg'])}');
    }
    return decoded;
  }

  static final RegExp _tab = RegExp(r'^[a-z][a-z0-9_]{0,31}$');

  /// An image as the feed accepts it: https on `bdstatic.com`, `bdimg.com` or
  /// `bcebos.com` (or a subdomain), without user info or fragment; else null.
  static String? _hostImage(Object? value) {
    final uri = Uri.tryParse(SiteText.trimmed(value));
    if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty || uri.hasFragment) {
      return null;
    }
    const roots = ['bdstatic.com', 'bdimg.com', 'bcebos.com'];
    final host = uri.host.toLowerCase();
    return roots.any((root) => host == root || host.endsWith('.$root')) ? uri.toString() : null;
  }

  /// A recording URL of room [roomId]: an https `.m3u8` on a `bdstatic.com`
  /// host (http made https), on the default port, without user info or
  /// fragment, under the room's stream directory (`_<id>/`); else null.
  static Uri? _replayUrl(Object? value, String roomId) {
    var uri = Uri.tryParse(SiteText.trimmed(value));
    if (uri == null || !uri.host.toLowerCase().endsWith('.bdstatic.com')) {
      return null;
    }
    if (uri.scheme == 'http' && !uri.hasPort) {
      uri = uri.replace(scheme: 'https');
    }
    if (uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.hasPort ||
        !uri.path.toLowerCase().endsWith('.m3u8') ||
        !uri.path.contains('_$roomId/')) {
      return null;
    }
    return uri;
  }

  static String _firstText(Iterable<Object?> values) {
    for (final value in values) {
      final text = SiteText.trimmed(value);
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }

  /// The `cmd 371` query for [roomId].
  static Map<String, String> roomQuery(String roomId, {required String deviceId}) => {
    'cmd': '371',
    'action': 'star',
    'service': 'bdbox',
    'osname': 'pc',
    'data': jsonEncode({
      'data': {'room_id': roomId, 'device_id': deviceId, 'source_type': 0},
      'replay_slice': 0,
      'nid': '',
    }),
  };

  /// A room id: 6–20 digits, not starting with zero.
  static final RegExp _roomId = RegExp(r'^[1-9]\d{5,19}$');

  /// A share page's code segment.
  static final RegExp _shareCode = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  /// [raw] trimmed as a room id (6–20 digits, not starting with zero), or
  /// null.
  static String? normalizeRoomId(String raw) {
    final value = raw.trim();
    return _roomId.hasMatch(value) ? value : null;
  }

  /// A room id or a room link (3.x's `BaiduLiveLink.parseRoomId`), or null
  /// for anything else.
  static String? parseRoomId(String raw) => normalizeRoomId(raw) ?? roomIdFromUrl(raw);

  /// The room of a Baidu Live room link, or null: https or http on
  /// `live.baidu.com` with the scheme's default port, no user info or
  /// fragment, and either `/m/room/<id>` or a `room_id=<id>` on the PC player
  /// or a share page.
  static String? roomIdFromUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) {
      return null;
    }
    final scheme = uri.scheme.toLowerCase();
    final defaultPort = switch (scheme) {
      'https' => 443,
      'http' => 80,
      _ => null,
    };
    if (defaultPort == null ||
        uri.userInfo.isNotEmpty ||
        uri.host.toLowerCase() != 'live.baidu.com' ||
        (uri.hasPort && uri.port != defaultPort) ||
        uri.fragment.isNotEmpty) {
      return null;
    }
    try {
      final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList(growable: false);
      if (segments.length == 3 && segments[0] == 'm' && segments[1] == 'room' && _roomId.hasMatch(segments[2])) {
        return segments[2];
      }
      final roomId = uri.queryParameters['room_id']?.trim();
      if (roomId == null || !_roomId.hasMatch(roomId)) {
        return null;
      }
      if ('/${segments.join('/')}' == '/m/media/pclive/pchome/live.html') {
        return roomId;
      }
      if (segments.length == 6 &&
          segments.take(5).join('/') == 'm/media/multipage/liveshow/index' &&
          _shareCode.hasMatch(segments.last)) {
        return roomId;
      }
      return null;
    } on FormatException {
      return null;
    }
  }

  /// The `data.371` command of a searchbox answer; "not found" when the
  /// command is missing or its error codes say so.
  static Map<String, Object?> commandOf(String body, {int status = 200}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('baidulive searchbox: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const SiteApiChangedError('baidulive searchbox: body is not JSON');
    }
    final data = decoded is Map<String, Object?> ? decoded['data'] : null;
    final raw = data is Map<String, Object?> ? data['371'] : null;
    if (raw is! Map<String, Object?>) {
      throw const SiteNotFoundError('baidulive: no room command');
    }
    final error = SiteCounts.integer(raw['error_code']);
    if (error == 1 || error == 4) {
      throw SiteNotFoundError('baidulive: error_code $error');
    }
    if (error != 0 && error != null) {
      throw SiteApiChangedError('baidulive searchbox: error_code $error');
    }
    return raw;
  }

  /// The room state from the command.
  static LiveRoom room(String body, {required String roomId, int status = 200}) {
    final cmd = commandOf(body, status: status);
    final host = cmd['host'];
    final video = cmd['video'];
    if (host is! Map<String, Object?> && video is! Map<String, Object?>) {
      throw const SiteNotFoundError('baidulive: no host or video');
    }
    final hostMap = host is Map<String, Object?> ? host : const <String, Object?>{};
    final videoMap = video is Map<String, Object?> ? video : const <String, Object?>{};
    final stateCode = SiteCounts.integer(cmd['status']);
    final live = stateCode == 0;
    final replay = stateCode == 3;
    final nick = hostMap['nick_name']?.toString() ?? hostMap['name']?.toString() ?? '';
    final cover = videoMap['cover'];
    final coverMap = cover is Map<String, Object?> ? cover : const <String, Object?>{};
    return LiveRoom(
      platform: SiteIds.baiduLive,
      roomId: roomId,
      title: videoMap['title']?.toString() ?? nick,
      nick: nick,
      avatar: _image(
        hostMap['image'] is Map<String, Object?> ? (hostMap['image']! as Map<String, Object?>)['image_33'] : null,
      ),
      cover: _image(coverMap['cover_100'] ?? coverMap['vertical_cover']),
      areaName: cmd['category']?.toString(),
      watching: SiteCounts.integer(cmd['online_users']),
      status: replay
          ? LiveStatus.replay
          : live
          ? LiveStatus.live
          : LiveStatus.offline,
    );
  }

  /// The playable URLs of the room command's video (url_clarity_list and
  /// url_list), de-duplicated.
  static List<LivePlayLine> playLines(String body, {required String roomId, int status = 200}) {
    final cmd = commandOf(body, status: status);
    final video = cmd['video'];
    if (video is! Map<String, Object?>) {
      return const [];
    }
    final lines = <LivePlayLine>[];
    final seen = <String>{};
    void add(Object? raw, String protocol, String? codec, int? height) {
      final url = raw?.toString() ?? '';
      if (!(url.startsWith('http://') || url.startsWith('https://')) || !seen.add(url)) {
        return;
      }
      lines.add(
        LivePlayLine(
          url: url,
          headers: apiHeaders,
          format: protocol == 'hls' ? StreamFormat.hls : StreamFormat.flv,
          codec: codec,
          lineId: height == null ? null : 'h$height',
          height: height,
        ),
      );
    }

    final clarity = video['url_clarity_list'];
    if (clarity is List) {
      for (final item in clarity) {
        if (item is! Map<String, Object?>) {
          continue;
        }
        final height = SiteCounts.integer(item['resolution']);
        final urls = item['urls'];
        if (urls is! Map<String, Object?>) {
          continue;
        }
        add(urls['avc_flv'], 'flv', 'avc', height);
        add(urls['hls'], 'hls', 'avc', height);
        add(urls['hevc_flv'], 'flv', 'hevc', height);
      }
    }
    final list = video['url_list'];
    if (list is List) {
      for (final item in list) {
        if (item is! Map<String, Object?>) {
          continue;
        }
        final height = SiteCounts.integer(item['resolution']);
        final pairs = item['urls'];
        if (pairs is! List) {
          continue;
        }
        for (final pair in pairs) {
          if (pair is! Map<String, Object?>) {
            continue;
          }
          add(pair['flv'], 'flv', 'avc', height);
          add(pair['hls'], 'hls', 'avc', height);
        }
      }
    }
    return lines;
  }

  static String? _image(Object? value) {
    final url = value?.toString() ?? '';
    return url.isEmpty ? null : url;
  }
}
