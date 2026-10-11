import 'dart:convert';

import 'package:live_sites/live_sites.dart';

/// Static parsers for the JD Live h5 APIs.
abstract final class JdLiveParser {
  /// API host.
  static const String apiHost = 'api.m.jd.com';

  /// App id used by the h5 client.
  static const String appid = 'h5-live';

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
