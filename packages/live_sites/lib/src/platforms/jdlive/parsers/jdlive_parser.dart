import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the JD Live h5 APIs.
abstract final class JdLiveParser {
  /// API host.
  static const String apiHost = 'api.m.jd.com';

  /// App id used by the h5 client.
  static const String appid = 'h5-live';

  /// Web origin of the site.
  static const String webOrigin = 'https://m.jd.com';

  /// The headers a JSON request sends (the site serves its API to the mobile
  /// page's own requests).
  static const Map<String, String> apiHeaders = {
    'accept': 'application/json, text/plain, */*',
    'origin': webOrigin,
    'referer': '$webOrigin/',
    'user-agent':
        'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36',
  };

  /// The one area's id: the featured list (`tabId` 1).
  static const String areaId = 'featured';

  /// The one area's name (3.x's zh.json `jdlive_category_featured`).
  static const String areaName = '精选直播购物';

  /// The last page the site's sequence serves.
  static const int maxPage = 10000;

  /// The one area's tab id, the only list this site has.
  static const int tabId = 1;

  /// The catalogue: one area, and it is constant — the featured list — so no
  /// request is spent finding it out.
  static List<LiveArea> areas() => const [LiveArea(id: areaId, name: areaName)];

  /// Whether [area] is the one area this site has.
  static bool isArea(LiveArea area) => area.id.trim() == areaId;

  /// The `liveListWithTabToM` URL: page [page] after [count] entries, in the
  /// sequence started at [timestamp].
  static Uri listUrl({required int page, required int count, required int timestamp, required DateTime now}) =>
      Uri.https(apiHost, '/api', {
        'appid': appid,
        'functionId': 'liveListWithTabToM',
        'v': '${now.millisecondsSinceEpoch}',
        'body': jsonEncode({'tabId': tabId, 'currentCount': '$count', 'page': page, 'timestamp': timestamp}),
      });

  /// A page of the featured list at [page], asked [after] entries.
  ///
  /// The entries the list carries are broadcasts (`templateType` 1); the
  /// others — promotions, official replays — are skipped, as are entries
  /// without a valid id, whose `liveId` differs from their `id`, that repeat
  /// one, or that cannot be read (the unified fault-tolerance rule; 3.x
  /// failed the page). A page none of whose entries can be read is a changed
  /// endpoint rather than an empty page. `currentCount` must be a count, and
  /// there is another page while this one carried broadcasts and the count
  /// moved past [after].
  static ({List<({LiveRoom room, Map<String, Object?> card})> entries, int nextCount, bool hasMore}) directory(
    String body, {
    required int page,
    required int after,
    int status = 200,
  }) {
    const what = 'liveListWithTabToM';
    final data = JdLiveParser.data(body, status: status, what: what);
    final rows = data['list'];
    if (rows is! List || rows.length > 1000) {
      throw SiteApiChangedError('jdlive $what: list is ${rows is List ? '${rows.length} entries' : 'not a list'}');
    }
    final seen = <String>{};
    final entries = <({LiveRoom room, Map<String, Object?> card})>[];
    var unreadable = 0;
    for (final row in rows) {
      final entry = card(row);
      if (entry == null) {
        unreadable++;
        continue;
      }
      if (seen.add(entry.room.roomId)) {
        entries.add(entry);
      }
    }
    if (unreadable > 0 && entries.isEmpty) {
      throw SiteApiChangedError('jdlive $what page $page: $unreadable unreadable entries, no broadcast');
    }
    final next = SiteCounts.integer(data['currentCount']);
    if (next == null) {
      throw SiteApiChangedError('jdlive $what page $page: currentCount is ${data['currentCount']}');
    }
    return (entries: entries, nextCount: next, hasMore: entries.isNotEmpty && next > after);
  }

  /// One list entry as the room it shows and the card the play answers are
  /// completed from (they carry no title, shop name, picture or viewers).
  ///
  /// Null for an entry that is not a broadcast, names no broadcast, repeats
  /// the id in two fields or names a broadcast the site does not; null too
  /// when a name or picture is present but not text, which costs that entry
  /// rather than the page.
  static ({LiveRoom room, Map<String, Object?> card})? card(Object? raw) {
    final entry = SiteJson.object(raw);
    if (SiteCounts.integer(entry['templateType']) != 1) {
      return null;
    }
    final item = SiteJson.object(entry['data']);
    if (item.isEmpty) {
      return null;
    }
    final id = liveIdOf(SiteText.text(item['liveId'] ?? item['id']));
    if (id == null || liveIdOf(SiteText.text(item['id'])) != id) {
      return null;
    }
    final title = text(item['title']);
    final nick = text(item['userName']);
    if (title == null || nick == null) {
      return null;
    }
    final card = <String, Object?>{
      'title': title.isEmpty ? nick : title,
      'userName': nick,
      'userPic': _image(item['userPic']),
      'indexImage': _image(item['indexImage']),
      'pv': SiteCounts.integer(item['pv']),
    };
    return (
      room: LiveRoom(
        platform: SiteIds.jdLive,
        roomId: id,
        title: card['title']! as String,
        nick: nick,
        avatar: card['userPic'] as String?,
        cover: card['indexImage'] as String?,
        status: statusOf(item['status']),
        watching: card['pv'] as int?,
      ),
      card: card,
    );
  }

  /// [value] as text, or null when it is present but not text (an object or
  /// a list where a name belongs is a changed payload, not an empty name).
  static String? text(Object? value) => value == null || value is String ? SiteText.trimmed(value) : null;

  /// Parses a broadcast id out of a room id or room link.

  /// Media request headers for [liveId] (the stream plays without them,
  /// but the CDN prefers them).
  static Map<String, String> mediaHeaders(String liveId) => {
    'origin': 'https://m.jd.com',
    'referer': 'https://m.jd.com/live/$liveId',
    'user-agent':
        'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36',
  };

  /// The `getImmediatePlayToM` URL for [liveId].
  static Uri playUrl(String liveId, {required DateTime now}) => Uri.https(apiHost, '/api', {
    'appid': appid,
    'functionId': 'getImmediatePlayToM',
    't': '${now.millisecondsSinceEpoch}',
    'body': jsonEncode({'liveId': liveId}),
  });

  /// Parses a broadcast id out of a room id or room link.
  static String? liveIdOf(String roomId) {
    final match = RegExp(r'^/?([1-9]\d{4,17})(?:/(?:live|notice|closed|replay))?(?:\?.*)?$').firstMatch(roomId.trim());
    return match?.group(1);
  }

  /// Validates the envelope and returns `data`.
  static Map<String, Object?> data(String body, {int status = 200, String what = 'response'}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('jdlive $what: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw SiteApiChangedError('jdlive $what: body is not JSON');
    }
    final data = decoded is Map<String, Object?> ? decoded['data'] : null;
    if (data is! Map<String, Object?>) {
      throw SiteApiChangedError('jdlive $what: no data object');
    }
    return data;
  }

  /// The room state from the play answer's `status`.
  static LiveStatus statusOf(Object? status) => switch ((status as num?)?.toInt()) {
    1 => LiveStatus.live,
    3 => LiveStatus.replay,
    0 || 2 => LiveStatus.offline,
    _ => LiveStatus.unknown,
  };

  /// A room's core snapshot from the play answer. A message set is
  /// required: the answer echoes the liveId and carries the state.
  static LiveRoom room(Map<String, Object?> data, {required String liveId, required Map<String, Object?>? known}) {
    final answered = data['liveId']?.toString() ?? '';
    if (answered.isNotEmpty && answered != liveId) {
      throw SiteApiChangedError('jdlive: asked $liveId, got $answered');
    }
    final status = statusOf(data['status']);
    String pick(Object? fresh, Object? fallback) {
      final value = fresh?.toString() ?? '';
      return value.isNotEmpty ? value : (fallback?.toString() ?? '');
    }

    return LiveRoom(
      platform: SiteIds.jdLive,
      roomId: liveId,
      title: pick(data['title'] ?? data['anchorTitle'] ?? data['name'], known?['title']),
      nick: pick(data['userName'] ?? data['authorName'], known?['userName']),
      avatar: _image(data['userPic'] ?? data['authorPic']) ?? known?['userPic']?.toString(),
      cover: _image(data['indexImage'] ?? data['coverImg']) ?? known?['indexImage']?.toString(),
      status: status,
      watching: (data['pv'] as num?)?.toInt(),
    );
  }

  /// The play lines of a play answer: HLS (`h5VideoUrl`) and FLV
  /// (`videoUrl`/`pcVideoUrl`), live only; a replay plays its
  /// recording.
  static List<LivePlayLine> playLines(Map<String, Object?> data, String liveId, {required LiveStatus status}) {
    final headers = mediaHeaders(liveId);
    final lines = <LivePlayLine>[];
    final hls = _media(data['h5VideoUrl'], '.m3u8');
    final flv = _media(data['videoUrl'], '.flv') ?? _media(data['pcVideoUrl'], '.flv');
    if (status == LiveStatus.live) {
      if (hls != null) {
        lines.add(LivePlayLine(url: hls, headers: headers, format: StreamFormat.hls, lineId: 'hls'));
      }
      if (flv != null) {
        lines.add(LivePlayLine(url: flv, headers: headers, format: StreamFormat.flv, lineId: 'flv'));
      }
    } else if (status == LiveStatus.replay) {
      for (final field in ['h5VideoUrl', 'videoUrl', 'pcVideoUrl']) {
        final url = _media(data[field], null);
        if (url != null) {
          lines.add(
            LivePlayLine(
              url: url,
              headers: headers,
              format: url.contains('.m3u8') ? StreamFormat.hls : StreamFormat.flv,
              lineId: 'replay',
            ),
          );
          break;
        }
      }
    }
    if (lines.isEmpty && (status == LiveStatus.live || status == LiveStatus.replay)) {
      throw SiteNotFoundError('jdlive $liveId: nothing playable');
    }
    return lines;
  }

  static String? _media(Object? value, String? suffix) {
    final url = value?.toString() ?? '';
    if (!(url.startsWith('http://') || url.startsWith('https://'))) {
      return null;
    }
    if (suffix != null && !url.contains(suffix)) {
      return null;
    }
    return url;
  }

  static String? _image(Object? value) {
    final url = value?.toString() ?? '';
    if (url.isEmpty) {
      return null;
    }
    return url.startsWith('//') ? 'https:$url' : url;
  }
}
