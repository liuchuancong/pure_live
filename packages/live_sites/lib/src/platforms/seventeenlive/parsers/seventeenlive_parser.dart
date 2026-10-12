import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// A 17LIVE room's playback, kept in [LiveRoom.data] at room entry: the
/// broadcaster's UUID (which names the pull streams) and the offered
/// qualities, each with its CDN lines, or why there is nothing to play.
final class SeventeenLivePlayback {
  /// The playback of one room.
  const new({required this.roomId, required this.userId, required this.qualities, this.unavailable});

  /// `liveStreamID` — the room this playback belongs to.
  final String roomId;

  /// `userID` — the broadcaster's UUID.
  final String userId;

  /// The offered qualities, best first; empty when [unavailable] explains why.
  final List<SeventeenLiveOffered> qualities;

  /// A human reason there is nothing to play (offline, locked, no pull URL).
  final String? unavailable;

  /// Reads the [LiveRoom.data] cache back, or null when it is not this room's
  /// playback map.
  static SeventeenLivePlayback? from(Object? data, String roomId) {
    if (data is! Map<String, Object?> || data['roomId'] != roomId) return null;
    return SeventeenLivePlayback(
      roomId: roomId,
      userId: data['userId']?.toString() ?? '',
      qualities: [
        for (final quality in _asList(data['qualities']))
          if (quality is Map<String, Object?>) SeventeenLiveOffered.from(quality),
      ],
      unavailable: data['unavailable']?.toString(),
    );
  }

  /// The cache map this writes back into [LiveRoom.data].
  Map<String, Object?> toMap() => {
    'roomId': roomId,
    'userId': userId,
    'qualities': [for (final quality in qualities) quality.toMap()],
    if (unavailable != null) 'unavailable': unavailable,
  };

  static List<Object?> _asList(Object? value) => value is List ? value : const [];
}

/// One offered quality and its lines, in [SeventeenLivePlayback].
final class SeventeenLiveOffered {
  /// One quality.
  const new({required this.id, required this.label, required this.sort, required this.lines, this.codec});

  /// Reads one quality map. A static, not a factory, so it can build the line
  /// list before the final fields are fixed.
  // ignore: prefer_constructors_over_static_methods
  static SeventeenLiveOffered from(Map<String, Object?> map) => SeventeenLiveOffered(
    id: map['id']?.toString() ?? '',
    label: map['label']?.toString() ?? '',
    sort: map['sort'] is num ? (map['sort']! as num).toInt() : 0,
    lines: [
      for (final line in _asList(map['lines']))
        if (line is Map<String, Object?>)
          SeventeenLiveLine(url: line['url']?.toString() ?? '', cdn: line['cdn']?.toString()),
    ],
    codec: map['codec']?.toString(),
  );

  /// The quality id (`source`, `enhanced`, `hd`, `h264`).
  final String id;

  /// The display label (`原画 · FLV`).
  final String label;

  /// The sort value (higher first).
  final int sort;

  /// The pull lines (one per CDN), as (url, cdn) pairs.
  final List<SeventeenLiveLine> lines;

  /// `avc` for the H.264 transcode; null otherwise.
  final String? codec;

  /// The cache map for this quality.
  Map<String, Object?> toMap() => {
    'id': id,
    'label': label,
    'sort': sort,
    if (codec != null) 'codec': codec,
    'lines': [
      for (final line in lines) {'url': line.url, if (line.cdn != null) 'cdn': line.cdn},
    ],
  };

  static List<Object?> _asList(Object? value) => value is List ? value : const [];
}

/// One pull line (a CDN's FLV URL).
final class SeventeenLiveLine {
  /// A pull line.
  const new({required this.url, this.cdn});

  /// The https pull URL.
  final String url;

  /// The CDN host prefix (`tencent`, `wansu`).
  final String? cdn;
}

/// Static parsers for the 17LIVE (イチナナ) anonymous web API.
abstract final class SeventeenLiveParser {
  /// The API host.
  static const String apiHost = 'api-dsa.17app.co';

  /// The website origin.
  static const String origin = 'https://17.live';

  /// 3.x's desktop Chrome user agent, sent with every request.
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';

  /// Display name.
  static const String displayName = '17LIVE';

  /// The notice on every room.
  static const String ageNotice = '17LIVE 要求观看者年满 18 周岁。';

  /// The area of an audio-only broadcast.
  static const String audioRoom = '音频直播';

  /// The region of the recommendations (the recommendations use Japan).
  static const String region = 'JP';

  /// The regions of the website's recommendation sections, in order.
  static const Map<String, String> regions = {'JP': '日本', 'TW': '台湾', 'HK': '香港'};

  /// The areas: one per region; [regionOf] reads the id back.
  static List<LiveArea> areas() => [
    for (final (index, entry) in regions.entries.indexed)
      LiveArea(id: entry.key, name: entry.value, parentId: 'region', sort: index),
  ];

  /// The `region` code an area selects: [region] for null (the
  /// recommendations); a caller error for an unknown area.
  static String regionOf(LiveArea? area) {
    if (area == null) return region;
    final code = area.id.trim().toUpperCase();
    if (!regions.containsKey(code)) throw ArgumentError.value(area, 'area', 'not a 17LIVE region');
    return code;
  }

  /// The quality ids, best first.
  static const List<String> qualityOrder = ['source', 'enhanced', 'hd', 'h264'];

  /// The display name of each quality id.
  static const Map<String, String> qualityNames = {'source': '原画', 'enhanced': '增强高清', 'hd': '高清', 'h264': 'H.264'};

  /// The sort value of each quality (原画 highest).
  static const Map<String, int> qualitySorts = {'source': 500, 'enhanced': 400, 'hd': 300, 'h264': 200};

  /// The pull-URL fields of each quality, best first.
  static const Map<String, List<String>> qualityFields = {
    'source': ['urlLowQuality', 'webUrlLowQuality', 'urlHighQuality'],
    'enhanced': ['urlQualityEnhancedHD'],
    'hd': ['urlLowBitrateHD', 'webUrl', 'url'],
    'h264': ['url264'],
  };

  /// CDNs that serve no working H.264 transcode.
  static const Set<String> untranscodedCdns = {'wansu'};

  /// Rows the website asks each section for.
  static const int sectionCount = 20;

  /// The last directory page a caller may ask for.
  static const int maxPage = 20;

  /// The longest cursor accepted.
  static const int maxCursorLength = 512;

  /// The longest keyword sent.
  static const int maxKeywordLength = 100;

  /// Sections without current broadcasts, skipped.
  static const Set<String> skippedSections = {'TopBanner', 'ArchiveVideo', 'Vod'};

  static final RegExp _roomId = RegExp(r'^[1-9][0-9]{0,11}$');
  static final RegExp _control = RegExp(r'[\x00-\x1f]');
  static final RegExp _url = RegExp('^[a-z][a-z0-9+.-]*://', caseSensitive: false);

  /// The web page of [roomId].
  static String roomUrl(String roomId) => '$origin/en/live/$roomId';

  /// Whether [raw] is a room id (1 to 12 digits, no leading zero); trimmed.
  static String? normalizeRoomId(String raw) {
    final id = raw.trim();
    return _roomId.hasMatch(id) ? id : null;
  }

  /// The room of a 17LIVE page (`/live/<id>`, `/<locale>/live/<id>`,
  /// `/profile/r/<id>` or its locale form) on `17.live`/`www.17.live`, or null.
  static String? roomIdFromUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.userInfo.isNotEmpty ||
        !const {'17.live', 'www.17.live'}.contains(uri.host.toLowerCase())) {
      return null;
    }
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
    final id = switch (segments.length) {
      2 when segments[0].toLowerCase() == 'live' => segments[1],
      3 when segments[0].toLowerCase() == 'profile' && segments[1].toLowerCase() == 'r' => segments[2],
      4 when segments[1].toLowerCase() == 'profile' && segments[2].toLowerCase() == 'r' => segments[3],
      _ => null,
    };
    return id == null ? null : normalizeRoomId(id);
  }

  /// 3.x's headers of the room answer.
  static Map<String, String> requestHeaders(String roomId) => {
    'user-agent': userAgent,
    'accept': 'application/json, text/plain, */*',
    'accept-language': 'en-US,en;q=0.9',
    'origin': origin,
    'referer': roomUrl(roomId),
  };

  /// 3.x's headers of the sections and the search.
  static const Map<String, String> catalogHeaders = {
    'user-agent': userAgent,
    'accept': 'application/json, text/plain, */*',
    'accept-language': 'ja-JP,ja;q=0.9,en;q=0.8',
    'origin': origin,
    'referer': '$origin/',
  };

  /// The pull streams' headers (the hosts refuse a request without a Referer).
  static Map<String, String> mediaHeaders(String roomId) => {
    'user-agent': userAgent,
    'origin': origin,
    'referer': roomUrl(roomId),
  };

  /// The query of the sections page after [cursor] of [regionCode].
  static Map<String, String> sectionsQuery(String? cursor, {String regionCode = region}) => {
    'count': '$sectionCount',
    'typeTab': '2',
    'region': regionCode,
    'cursor': cursor ?? '',
  };

  /// Whether [text] is a web address (not a search keyword).
  static bool isUrl(String text) => _url.hasMatch(text.trim());

  /// The keyword to send: trimmed and cut to 100 UTF-16 units, never inside a
  /// surrogate pair.
  static String searchKeyword(String keyword) {
    var text = keyword.trim();
    if (text.length > maxKeywordLength) {
      var end = maxKeywordLength;
      final last = text.codeUnitAt(end - 1);
      if (last >= 0xD800 && last <= 0xDBFF) end--;
      text = text.substring(0, end).trim();
    }
    return text;
  }

  /// The JSON root of a 200 answer, or the failure (a non-200 status maps to a
  /// [SiteError]; an unknown room is HTTP 520 `stream not found`).
  static Object? decode(String body, {int status = 200, String what = 'response'}) {
    if (status != 200) {
      final message = _errorMessage(body);
      if (message == 'stream not found') throw SiteNotFoundError('17live $what: HTTP $status stream not found');
      throw switch (status) {
        400 || 420 => SiteApiChangedError('17live $what: HTTP $status'),
        401 || 403 => SiteRiskControlError('17live $what: HTTP $status'),
        404 => SiteNotFoundError('17live $what: HTTP 404'),
        429 => SiteRateLimitedError('17live $what: HTTP 429'),
        _ => SiteApiChangedError('17live $what: HTTP $status'),
      };
    }
    if (body.length > 4 * 1024 * 1024) throw SiteApiChangedError('17live $what: answer too large');
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw SiteApiChangedError('17live $what: not JSON');
    }
    return decoded;
  }

  static String? _errorMessage(String body) {
    if (body.length > 65536) return null;
    try {
      final data = jsonDecode(body);
      final message = data is Map ? data['errorMessage'] : null;
      return message is String ? message.trim() : null;
    } on FormatException {
      return null;
    }
  }

  /// One page of the recommendation sections: live cards and the next cursor.
  static ({List<LiveRoom> rooms, String? nextCursor}) sectionsPage(String body, {String? cursor, int status = 200}) {
    final data = decode(body, status: status, what: 'sections');
    if (data is! Map<String, Object?>) throw const SiteApiChangedError('17live sections: not an object');
    final sections = data['sections'];
    if (sections is! List) throw const SiteApiChangedError('17live sections: no sections list');
    final seen = <String>{};
    final rooms = <LiveRoom>[];
    for (final item in sections) {
      if (item is! Map<String, Object?> || skippedSections.contains(item['id'])) continue;
      final grids = item['grids'];
      if (grids is! List) continue;
      for (final grid in grids) {
        final stream = grid is Map<String, Object?> ? grid['stream'] : null;
        final row = _liveRow(stream);
        if (row != null && seen.add(row.roomId)) rooms.add(row);
      }
    }
    final raw = data['cursor'];
    var next = raw is String && raw.isNotEmpty && raw != cursor ? raw : null;
    if (next != null && (next.length > maxCursorLength || next.contains(_control))) next = null;
    return (rooms: rooms, nextCursor: next);
  }

  /// `liveStreams/search` results as cards: current broadcasts only, once
  /// each; the answer is a list.
  static List<LiveRoom> searchRooms(String body, {int status = 200}) {
    final data = decode(body, status: status, what: 'liveStreams/search');
    if (data is! List) return const [];
    final seen = <String>{};
    return [
      for (final item in data)
        if (_liveRow(item, ownerRequired: true) case final row? when seen.add(row.roomId)) row,
    ];
  }

  /// `lives/<id>` → the room, without its playback (a refresh).
  static LiveRoom room(String body, {required String roomId, int status = 200}) {
    final data = decode(body, status: status, what: 'lives/$roomId');
    try {
      return _card(_stream(data, roomId), roomId);
    } on FormatException catch (error) {
      throw SiteApiChangedError('17live lives/$roomId: ${error.message}');
    }
  }

  /// `lives/<id>` → the room with its playback in [LiveRoom.data] and its
  /// danmaku channel id in [LiveRoom.danmakuData]. A room that cannot be
  /// played is still returned; its data says why.
  static LiveRoom enteredRoom(String body, {required String roomId, int status = 200}) {
    final decoded = decode(body, status: status, what: 'lives/$roomId');
    if (decoded is! Map<String, Object?>) throw const SiteApiChangedError('17live lives: not an object');
    final Map<String, Object?> data;
    final LiveRoom card;
    try {
      data = _stream(decoded, roomId);
      card = _card(data, roomId);
    } on FormatException catch (error) {
      throw SiteApiChangedError('17live lives/$roomId: ${error.message}');
    }
    final offered = card.status == LiveStatus.live ? _qualities(decoded, roomId) : const <SeventeenLiveOffered>[];
    final unavailable = switch (card.status) {
      LiveStatus.live when (card.restriction ?? LiveRestriction.none) != LiveRestriction.none => 'locked',
      LiveStatus.live when offered.isEmpty => 'no pull URL',
      LiveStatus.live => null,
      LiveStatus.offline => 'offline',
      _ => 'unknown state',
    };
    final playback = SeventeenLivePlayback(
      roomId: roomId,
      userId: decoded['userID']?.toString() ?? '',
      qualities: unavailable == null ? offered : const [],
      unavailable: unavailable,
    );
    return LiveRoom(
      platform: SiteIds.seventeenLive,
      roomId: roomId,
      title: card.title,
      nick: card.nick,
      avatar: card.avatar,
      cover: card.cover,
      areaName: card.areaName,
      status: card.status,
      restriction: card.restriction,
      watching: card.watching,
      onlineViewers: card.onlineViewers,
      startedAt: card.startedAt,
      data: playback.toMap(),
      danmakuData: roomId,
    );
  }

  /// A list row as a live card, or null when it is not a live room 17LIVE lists.
  static LiveRoom? _liveRow(Object? value, {bool ownerRequired = false}) {
    if (value is! Map<String, Object?>) return null;
    final roomId = _positiveInt(value['liveStreamID'])?.toString();
    if (roomId == null) return null;
    try {
      final card = _card(_stream(value, roomId, ownerRequired: ownerRequired), roomId);
      return card.status == LiveStatus.live ? card : null;
    } on FormatException {
      return null;
    }
  }

  /// The stream identity check: [roomId] must be the answer's `liveStreamID`
  /// (and, with [ownerRequired], the owner's `userInfo.roomID`). Returns the
  /// raw map for [room]/[_qualities] to read, or throws a [FormatException] for
  /// a mismatch.
  static Map<String, Object?> _stream(Object? value, String roomId, {bool ownerRequired = false}) {
    final data = value is Map<String, Object?> ? value : (throw const FormatException('not an object'));
    if (_positiveInt(data['liveStreamID'])?.toString() != roomId) throw const FormatException('wrong room');
    final user = data['userInfo'] is Map<String, Object?> ? data['userInfo']! as Map<String, Object?> : null;
    if (user == null) throw const FormatException('no userInfo');
    final owner = _positiveInt(user['roomID'])?.toString();
    if (ownerRequired && owner != roomId) throw const FormatException('owner mismatch');
    return data;
  }

  static LiveRoom _card(Map<String, Object?> data, String roomId) {
    final user = data['userInfo'] is Map<String, Object?>
        ? data['userInfo']! as Map<String, Object?>
        : const <String, Object?>{};
    final status = switch (_int(data['status'])) {
      2 => LiveStatus.live,
      0 => LiveStatus.offline,
      _ => LiveStatus.unknown,
    };
    final live = status == LiveStatus.live;
    var nick = _text(user['displayName']);
    if (nick.isEmpty) nick = _text(user['openID']);
    final title = _text(data['caption']);
    return LiveRoom(
      platform: SiteIds.seventeenLive,
      roomId: roomId,
      title: title.isEmpty ? nick : title,
      nick: nick,
      avatar: _image(user['picture']),
      cover: _image(data['coverPhoto'] ?? data['thumbnail']),
      areaName: _int(data['audioOnly']) == 1 ? audioRoom : null,
      status: status,
      restriction: live ? _restriction(data['premiumContent']) : null,
      onlineViewers: live ? _int(data['liveViewerCount']) : null,
      watching: live ? _int(data['viewerCount']) : null,
      startedAt: live ? _startTime(data['beginTime']) : null,
    );
  }

  /// The offered qualities (one per CDN in the answer's order), best first.
  static List<SeventeenLiveOffered> _qualities(Map<String, Object?> data, String roomId) {
    Object? providers;
    final pull = data['pullURLsInfo'];
    if (pull is Map) providers = pull['rtmpURLs'];
    providers ??= data['rtmpUrls'];
    if (providers is! List) return const [];
    final byId = <String, List<SeventeenLiveLine>>{};
    String? firstCdn;
    for (final item in providers.take(16)) {
      if (item is! Map<String, Object?>) continue;
      for (final id in qualityOrder) {
        for (final field in qualityFields[id]!) {
          final value = item[field];
          if (value is! String || value.isEmpty) continue;
          final url = _pullUrl(value);
          if (url == null) continue;
          final cdn = url.host.toLowerCase().split('-').first;
          firstCdn ??= cdn;
          if (id == 'h264' && untranscodedCdns.contains(cdn)) continue;
          final list = byId.putIfAbsent(id, () => []);
          final text = url.toString();
          if (list.any((line) => line.url == text)) continue;
          list.add(SeventeenLiveLine(url: text, cdn: cdn));
        }
      }
    }
    if (untranscodedCdns.contains(firstCdn)) byId.remove('h264');
    return [
      for (final id in qualityOrder)
        if (byId[id] case final lines? when lines.isNotEmpty)
          SeventeenLiveOffered(
            id: id,
            label: '${qualityNames[id]} · FLV',
            sort: qualitySorts[id]!,
            codec: id == 'h264' ? 'avc' : null,
            lines: lines,
          ),
    ];
  }

  static Uri? _pullUrl(String raw) {
    if (raw.isEmpty || raw.length > 65536 || raw.contains(RegExp(r'[\s\x00-\x1f]'))) return null;
    final uri = Uri.tryParse(raw);
    final host = uri?.host.toLowerCase() ?? '';
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !host.endsWith('.17app.co') ||
        !host.contains('pull-rtmp') ||
        !uri.path.toLowerCase().endsWith('.flv')) {
      return null;
    }
    if (uri.scheme == 'https' || (uri.hasPort && uri.port != 80)) return uri;
    return Uri(scheme: 'https', host: uri.host, path: uri.path, query: uri.hasQuery ? uri.query : null);
  }

  static LiveRestriction? _restriction(Object? premium) {
    if (premium == null) return LiveRestriction.none;
    if (premium is! Map<String, Object?>) return null;
    final type = _int(premium['premiumType']) ?? 0;
    final payment = premium['paymentInfo'];
    if (type == 0 || (payment is Map && payment['paid'] == true)) return LiveRestriction.none;
    return switch (type) {
      1 => LiveRestriction.paid,
      2 => LiveRestriction.subscribersOnly,
      _ => LiveRestriction.unplayable,
    };
  }

  static DateTime? _startTime(Object? value) {
    final seconds = value is int ? value : null;
    if (seconds == null || seconds < 946684800 || seconds > 4102444800) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  static String _text(Object? value) => value is String ? value.trim() : '';

  static int? _int(Object? value) => value is int ? value : int.tryParse(value?.toString() ?? '');

  static int? _positiveInt(Object? value) {
    final number = _int(value);
    return number != null && number > 0 ? number : null;
  }

  static String? _image(Object? value) {
    if (value is! String || value.isEmpty || value.length > 8192) return null;
    var uri = Uri.tryParse(value);
    if (uri != null && !uri.hasScheme) {
      if (value.contains('..') || !RegExp(r'^[a-zA-Z0-9._/?=&-]+$').hasMatch(value)) return null;
      uri = Uri.https('cdn.17app.co', value.startsWith('/') ? value : '/$value');
    }
    final host = uri?.host.toLowerCase() ?? '';
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !const {'cdn.17app.co', 'assets-17app.akamaized.net'}.contains(host)) {
      return null;
    }
    return uri.replace(scheme: 'https').toString();
  }
}
