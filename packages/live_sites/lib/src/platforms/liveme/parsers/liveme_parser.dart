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
    final business = (decoded['business'] as num?)?.toInt();
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
    final online = (video['online'] as num?)?.toInt();
    final state = (video['status'] as num?)?.toInt();
    final roomState = (video['roomstate'] as num?)?.toInt();
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
      watching: live ? (video['heat'] as num?)?.toInt() ?? (video['playnumber'] as num?)?.toInt() : null,
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
