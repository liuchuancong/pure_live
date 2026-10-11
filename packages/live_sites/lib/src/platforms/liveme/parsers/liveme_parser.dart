import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:live_sites/live_sites.dart';

/// The LiveMe request signer: `lm_s_id`/`lm_s_ts`/`lm_s_str`/`lm_s_ver`
/// form fields plus the `lm-s-sign` header.
final class LiveMeSigner {
  /// Creates a signer; [random] (the `vali` characters) is injectable.
  new({Random? random}) : _random = random ?? Random.secure();

  /// `lm_s_id`.
  static const String clientId = 'LM6000101139961122666757';
  static const String _secret = 'dd46dbb442b6e4ba817d6347d2ddf493';
  static const String _valiAlphabet = 'ABCDEFGHJKMNPQRSTWXYZabcdefhijkmnprstwxyz2345678';

  final Random _random;
  var _counter = 0;

  /// Signs [form] for `now`: the timestamp is the milliseconds plus one
  /// rotating counter digit, `lm_s_str` its md5, and the signature the
  /// md5 over the sorted query+fields, the client id, the timestamp and
  /// the secret.
  ({Map<String, String> fields, String signature}) sign({
    required Map<String, String> query,
    required Map<String, String> form,
    required DateTime now,
  }) {
    final timestamp = '${now.millisecondsSinceEpoch}$_counter';
    _counter = (_counter + 1) % 10;
    final fields = <String, String>{
      ...form,
      'lm_s_id': clientId,
      'lm_s_ts': timestamp,
      'lm_s_str': md5.convert(utf8.encode(timestamp)).toString(),
      'lm_s_ver': '1',
      'h5': '1',
    };
    final all = {...query, ...fields};
    final input = StringBuffer();
    for (final key in all.keys.toList()..sort()) {
      input
        ..write(key)
        ..write(all[key]);
    }
    input
      ..write(clientId)
      ..write(timestamp)
      ..write(_secret);
    return (fields: Map.unmodifiable(fields), signature: md5.convert(utf8.encode(input.toString())).toString());
  }

  /// The `vali` form value: 4 + `l` + 4 + `m` + 5 alphabet characters.
  String vali() => '${_part(4)}l${_part(4)}m${_part(5)}';

  String _part(int length) =>
      List.generate(length, (_) => _valiAlphabet[_random.nextInt(_valiAlphabet.length)], growable: false).join();
}

/// Static parsers for the LiveMe APIs.
abstract final class LiveMeParser {
  /// API host.
  static const String apiHost = 'live.liveme.com';

  /// The guest parameters of the API GETs at [now].
  static Map<String, String> guestQuery(DateTime now) => {
    'alias': 'liveme',
    'tongdun_black_box': '1',
    'os': 'web',
    '_time': '${now.millisecondsSinceEpoch}',
    'h5': '1',
    'thirdchannel': '6',
  };

  /// Request headers for a room [shortId].
  static Map<String, String> headers({String? shortId}) => {
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'referer': shortId == null ? 'https://www.liveme.com/' : 'https://www.liveme.com/live.html?uid=$shortId',
  };

  /// The directory host: the featured list is the web page's own API, and it
  /// is not signed.
  static const String directoryHost = 'lvapi.liveme.com';

  /// Rooms one directory page asks for (the web page's own size).
  static const int directoryPageSize = 20;

  /// The `featurelist` URL of directory page [page].
  static Uri featuredUrl({required int page, int pageSize = directoryPageSize}) => Uri.https(
    directoryHost,
    '/live/featurelist',
    {'countryCode': 'GLOBAL', 'page_index': '$page', 'page_size': '$pageSize', 'pid': '3', 'posid': '3002', 'h5': '1'},
  );

  /// A `featurelist` page: the rooms it shows, each once, and whether the
  /// site has another page after it (`next_page` 1).
  ///
  /// A card without a short id is a union room — several anchors sharing one
  /// broadcast — and is left out, as the site's own discovery page leaves it
  /// out. A card that cannot be read costs itself, while a page none of whose
  /// cards can be read is a changed endpoint rather than an empty page. A
  /// private or paid broadcast is listed live and marked, because the list
  /// carries it (the discovery page hides it, but it is reachable there
  /// anyway).
  static LivePage<LiveRoom> featuredPage(String body, {required int page, int status = 200}) {
    final data = LiveMeParser.data(body, status: status, what: 'featurelist');
    final rows = SiteJson.list(data['video_info']);
    if (rows.length > 100) {
      throw SiteApiChangedError('liveme featurelist page $page: ${rows.length} cards');
    }
    final seen = <String>{};
    final rooms = <LiveRoom>[];
    var unreadable = 0;
    for (final row in rows) {
      final video = SiteJson.object(row);
      if (SiteText.trimmed(video['ushortid']).isEmpty) {
        continue;
      }
      final room = card(video);
      if (room == null) {
        unreadable++;
        continue;
      }
      if (seen.add(room.roomId)) {
        rooms.add(room);
      }
    }
    if (rooms.isEmpty && unreadable > 0) {
      throw SiteApiChangedError('liveme featurelist page $page: $unreadable unreadable cards, none listed');
    }
    final hasMore = SiteCounts.integer(data['next_page']) == 1;
    return LivePage<LiveRoom>(items: rooms, hasMore: hasMore, nextPage: hasMore ? page + 1 : null);
  }

  /// One `video_info` card as a room, or null when it names no short id.
  ///
  /// A card has the shape of the room detail's own `video_info` without the
  /// streams, so the same fields are read; `online`, `status` and `roomstate`
  /// together decide the state (the site's own rule, where `online` 1 with
  /// both counters 0 is on air), and `heat`/`playnumber` are its audience.
  static LiveRoom? card(Map<String, Object?> video) {
    final shortId = SiteText.trimmed(video['ushortid']);
    if (shortId.isEmpty) {
      return null;
    }
    final online = SiteCounts.integer(video['online']);
    final state = SiteCounts.integer(video['status']);
    final roomState = SiteCounts.integer(video['roomstate']);
    final live = online == 1 && state == 0 && roomState == 0;
    final offline = online == 0 || (state != null && state != 0) || (roomState != null && roomState != 0);
    final nick = SiteText.title(SiteText.text(video['uname']));
    final title = SiteText.title(SiteText.text(video['title']));
    return LiveRoom(
      platform: SiteIds.liveme,
      roomId: shortId,
      title: title.isEmpty || title == 'LiveMe' ? nick : title,
      nick: nick,
      avatar: _image(video['uface']),
      cover: _image(video['videocapture'] ?? video['smallcover']),
      status: live
          ? LiveStatus.live
          : offline
          ? LiveStatus.offline
          : LiveStatus.unknown,
      watching: live ? SiteCounts.integer(video['heat']) ?? SiteCounts.integer(video['playnumber']) : null,
      startedAt: live ? _startedAt(video['vtime']) : null,
      restriction: live ? restrictionOf(video) : null,
      data: live ? video : null,
    );
  }

  /// The restriction a live card carries: `ispvt` 1 is a private broadcast,
  /// `livebptype` 7 or the paid label is a paid one, anything else none.
  static LiveRestriction restrictionOf(Map<String, Object?> video) {
    if (SiteCounts.integer(video['ispvt']) == 1) {
      return LiveRestriction.private;
    }
    if (SiteCounts.integer(video['livebptype']) == 7 || _isPaidLabel(video['hot_label_v2'])) {
      return LiveRestriction.paid;
    }
    return LiveRestriction.none;
  }

  /// Whether a `hot_label_v2` — JSON text, as the web client receives it —
  /// says the broadcast is paid.
  static bool _isPaidLabel(Object? value) {
    final text = SiteText.trimmed(value).toLowerCase();
    return text.contains('paid broadcast') || text.contains('付费');
  }

  /// Validates the envelope (`business` 0) and returns `data`.
  static Map<String, Object?> data(String body, {int status = 200, String what = 'response'}) {
    if (status < 200 || status >= 300) {
      throw SiteApiChangedError('liveme $what: HTTP $status');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw SiteApiChangedError('liveme $what: body is not JSON');
    }
    if (decoded is! Map<String, Object?>) {
      throw SiteApiChangedError('liveme $what: body is not an object');
    }
    final business = SiteCounts.integer(decoded['business']);
    if (business != null && business != 0) {
      final message = decoded['message']?.toString() ?? '';
      if (business == 500 && message.toLowerCase().contains('not exist')) {
        throw SiteNotFoundError('liveme $what: $message');
      }
      throw SiteApiChangedError('liveme $what: business $business $message'.trim());
    }
    final data = decoded['data'];
    if (data is! Map<String, Object?>) {
      throw SiteApiChangedError('liveme $what: no data object');
    }
    return data;
  }

  /// `uid_vid_by_short_id` → the broadcast's user and video ids.
  static ({String userId, String videoId}) mapping(String body, {int status = 200}) {
    final data = LiveMeParser.data(body, status: status, what: 'uid_vid_by_short_id');
    final userId = data['uid']?.toString() ?? '';
    final videoId = data['vid']?.toString() ?? '';
    if (userId.isEmpty) {
      throw const SiteApiChangedError('liveme uid_vid_by_short_id: no uid');
    }
    return (userId: userId, videoId: videoId);
  }

  /// `queryinfosimple` → the room with its display facts.
  static LiveRoom room(String body, {required String shortId, int status = 200}) {
    final data = LiveMeParser.data(body, status: status, what: 'queryinfosimple');
    final video = data['video_info'];
    final user = data['user_info'];
    if (video is! Map<String, Object?>) {
      throw const SiteApiChangedError('liveme queryinfosimple: no video_info');
    }
    final userMap = user is Map<String, Object?> ? user : const <String, Object?>{};
    final online = SiteCounts.integer(video['online']);
    final state = SiteCounts.integer(video['status']);
    final roomState = SiteCounts.integer(video['roomstate']);
    final live = online == 1 && state == 0 && roomState == 0;
    final offline = online == 0 || (state != null && state != 0) || (roomState != null && roomState != 0);
    final nick = video['uname']?.toString() ?? userMap['uname']?.toString() ?? userMap['nickname']?.toString() ?? '';
    final title = video['title']?.toString() ?? '';
    return LiveRoom(
      platform: SiteIds.liveme,
      roomId: shortId,
      title: title.isEmpty || title == 'LiveMe' ? nick : title,
      nick: nick,
      avatar: _image(video['uface'] ?? userMap['face'] ?? userMap['icon']),
      cover: _image(video['videocapture'] ?? video['smallcover']),
      status: live
          ? LiveStatus.live
          : offline
          ? LiveStatus.offline
          : LiveStatus.unknown,
      watching: live ? SiteCounts.integer(video['heat']) ?? SiteCounts.integer(video['playnumber']) : null,
      startedAt: live ? _startedAt(video['vtime']) : null,
      data: live ? video : null,
    );
  }

  /// The play lines of a live `video_info`: `videosource`/`videosourcemore`
  /// as FLV and `hlsvideosource` as HLS, `smallsource` as the smooth FLV.
  static List<LivePlayLine> playLines(Object? video, String shortId) {
    if (video is! Map<String, Object?>) {
      return const [];
    }
    final headers = LiveMeParser.headers(shortId: shortId);
    final lines = <LivePlayLine>[];
    final seen = <String>{};
    String? first(List<String> fields, StreamFormat format, String label) {
      for (final field in fields) {
        for (final raw in _flatten(video[field])) {
          final url = raw.startsWith('http') ? raw : '';
          if (url.isNotEmpty && seen.add(url)) {
            lines.add(LivePlayLine(url: url, headers: headers, format: format, lineId: label));
            return url;
          }
        }
      }
      return null;
    }

    first(['videosource', 'videosourcemore'], StreamFormat.flv, '原画');
    first(['hlsvideosource'], StreamFormat.hls, '原画-HLS');
    first(['smallsource', 'smallsourcemore'], StreamFormat.flv, '流畅');
    return lines;
  }

  static List<String> _flatten(Object? value) {
    final out = <String>[];
    if (value is String) {
      out.add(value);
    } else if (value is List) {
      for (final item in value) {
        out.addAll(_flatten(item));
      }
    } else if (value is Map<String, Object?>) {
      for (final item in value.values) {
        out.addAll(_flatten(item));
      }
    }
    return out;
  }

  static DateTime? _startedAt(Object? value) {
    final seconds = value is int ? value : (value is String ? int.tryParse(value.trim()) : null);
    if (seconds == null || seconds <= 0 || seconds > 9999999999) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  static String? _image(Object? value) {
    final url = value?.toString() ?? '';
    return url.isEmpty ? null : url;
  }
}
