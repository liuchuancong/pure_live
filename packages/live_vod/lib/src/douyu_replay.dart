import 'dart:convert';
import 'dart:math';

import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest, LiveResponse;
import 'package:live_vod/src/archive.dart' show ArchiveQuality, ArchiveVideo;
import 'package:live_vod/src/douyu_sign.dart' show DouyuVodSigner;
import 'package:live_vod/src/vod_models.dart' show VodFailure, VodVideo;

final RegExp _videoId = RegExp(r'^[A-Za-z0-9]{8,64}$');
final RegExp _authorId = RegExp(r'^[A-Za-z0-9]{1,64}$');

/// Public metadata of an official Douyu video or a replay segment; no
/// expiring stream URL or login credential rides in it.
final class DouyuVodVideo implements ArchiveVideo {
  /// Creates metadata.
  const new({
    required this.id,
    required this.title,
    this.authorId = '',
    this.authorName = '',
    this.cover = '',
    this.duration = Duration.zero,
    this.pointId = '',
    this.replay = false,
    this.publishedAt,
  });

  /// Reads the current web author-list and video-page field shapes.
  factory fromJson(Map<String, Object?> json, {bool replay = false}) => DouyuVodVideo(
    id: _text(json['hashId'] ?? json['hash_id'] ?? json['vid']),
    title: decodeHtmlEntities(_text(json['title'] ?? json['name'])),
    authorId: _text(json['upId'] ?? json['up_id']),
    authorName: decodeHtmlEntities(_text(json['owner'] ?? json['nickname'] ?? json['author'] ?? json['author_name'])),
    cover: normalizeImageUrl(json['cover'] ?? json['video_pic'] ?? json['pic']),
    duration: _durationOf(json),
    pointId: _text(json['point_id']),
    publishedAt: _publishedAt(json['start_time'] ?? json['create_time'] ?? json['ctime'] ?? json['publish_time']),
    replay: replay || _int(json['is_replay']) == 1 || json['is_replay'] == true,
  );

  /// The hash id `/show/{id}` reads, distinct from the numeric point id.
  @override
  final String id;

  @override
  final String title;

  /// The public encoded author id the author-list endpoints read.
  final String authorId;

  /// The display name.
  final String authorName;

  /// The public cover.
  final String cover;

  /// The duration, or zero until the engine supplies it.
  @override
  final Duration duration;

  /// The numeric signing point id, supplied by the video detail.
  final String pointId;

  /// Explicit replay mode from the list or the platform field, never a
  /// title guess.
  final bool replay;

  /// The public publication time when the platform supplies it.
  final DateTime? publishedAt;

  /// The recording as the shared video model, for the row and card widgets
  /// a video list already renders with.
  VodVideo asVideo() => VodVideo(
    id: id,
    title: title,
    coverUrl: cover.isEmpty ? null : cover,
    duration: duration == Duration.zero ? null : duration,
    uploader: authorName.isEmpty ? null : authorName,
  );
}

/// One daily-signed video detail; the signer executes no remote code.
final class DouyuVodDetail {
  /// Creates a detail.
  const new({required this.video, required this.signer});

  /// The current public metadata and numeric signing point id.
  final DouyuVodVideo video;

  /// The data-only daily descriptor parser.
  final DouyuVodSigner signer;
}

/// A platform-offered rendition, including an unavailable paid or login
/// tier.
final class DouyuVodQuality implements ArchiveQuality {
  /// Creates a rendition; only [playable] entries can be opened.
  const new({
    required this.id,
    required this.label,
    required this.level,
    required this.url,
    required this.playableFlag,
  });

  /// The platform's stream type id.
  @override
  final String id;

  @override
  final String label;

  /// The ordering level, highest first.
  final int level;

  /// The expiring media address; never persisted into history.
  final String url;

  /// Whether the server gives an address and lets this client play it.
  @override
  bool get playable => url.isNotEmpty && playableFlag;

  /// The server's own permission answer.
  final bool playableFlag;
}

/// A position-based danmaku batch, with a strictly advancing server cursor.
final class DouyuVodDanmakuChunk {
  /// Creates a chunk.
  const new({required this.messages, required this.next, this.blocked = false});

  /// The timeline-ordered comments.
  final List<VodDanmaku> messages;

  /// The next millisecond cursor; null after the last batch or on data that
  /// does not advance.
  final Duration? next;

  /// The platform explicitly disabled comments for this recording.
  final bool blocked;
}

/// One timeline comment, at its position in the recording.
final class VodDanmaku {
  /// Creates one comment.
  const new({required this.progress, required this.text, required this.id, required this.color});

  /// The position in the recording.
  final Duration progress;

  /// The comment text.
  final String text;

  /// The platform's comment id.
  final String id;

  /// The comment's color, as an opaque 0xAARRGGBB value.
  final int color;
}

/// Official Douyu replay catalogs and playback, with the shared proxied
/// transport and the viewer's existing Douyu login. No JS runtime: the
/// daily signing descriptor parses as data.
final class DouyuVodApi {
  /// Builds the API; the anonymous device id is random per instance.
  new(this.http, {this.cookie = '', DateTime Function()? now, String? did})
    : _now = now ?? _defaultNow,
      _did = did ?? List.generate(16, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join();

  /// The shared transport; this wrapper never closes it.
  final LiveHttp http;

  /// The viewer's Douyu login (`''` reads a guest's catalog and renditions;
  /// some tiers answer with their permission instead of an address).
  final String cookie;

  final DateTime Function() _now;
  final String _did;

  /// The same browser string across the video page and the signing request.
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36';

  static DateTime _defaultNow() => DateTime.now();

  Map<String, String> get _headers => {
    'user-agent': userAgent,
    'referer': 'https://v.douyu.com/',
    if (cookie.isNotEmpty) 'cookie': cookie.replaceAll(RegExp(r'[\r\n\u0000]'), ''),
  };

  /// The author's replay sessions, newest first, with the server's real
  /// paging: a session's segments flatten into the rows, and the session
  /// count is what `total` names.
  Future<({List<DouyuVodVideo> videos, bool hasMore, int total})> replays(
    String authorId, {
    int page = 1,
    int limit = 10,
  }) async {
    if (!_authorId.hasMatch(authorId) || page < 1 || limit < 1 || limit > 50) {
      throw const VodFailure('the replay page asked for is not a page');
    }
    final response = await _get(
      Uri.https('v.douyu.com', '/wgapi/vod/center/authorShowVideoList', {
        'up_id': authorId,
        'page': '$page',
        'limit': '$limit',
      }),
    );
    return parseReplays(response.text, page: page, limit: limit, authorId: authorId);
  }

  /// The recording's full metadata and the current day's signing data from
  /// the official page.
  Future<DouyuVodDetail> detail(String id) async {
    if (!_videoId.hasMatch(id)) {
      throw const VodFailure('the recording id is not one the station gives out');
    }
    return parseDetail((await _get(Uri.https('v.douyu.com', '/show/$id'))).text, id: id);
  }

  /// Fresh signed media addresses; an expired one is renewed by signing
  /// again.
  Future<List<DouyuVodQuality>> qualities(DouyuVodDetail detail) async {
    final fields = detail.signer.form(
      pointId: detail.video.pointId,
      videoId: detail.video.id,
      did: _did,
      seconds: _now().millisecondsSinceEpoch ~/ 1000,
    );
    final response = await _send(
      LiveRequest.form(
        Uri.https('v.douyu.com', '/wgapi/vodnc/front/stream/getStreamUrlWeb'),
        site: 'douyu',
        fields: fields,
        headers: _headers,
      ),
    );
    return parseQualities(response.text);
  }

  /// Every official segment of the recording's replay session, in the
  /// platform's order.
  Future<List<DouyuVodVideo>> replaySegments(DouyuVodVideo video) async {
    if (!_videoId.hasMatch(video.id) || !_authorId.hasMatch(video.authorId)) return const [];
    final response = await _get(
      Uri.https('v.douyu.com', '/wgapi/vod/center/getShowReplayList', {'vid': video.id, 'up_id': video.authorId}),
    );
    final data = _data(response.text);
    return _videos(_list(data['list']), replay: true, authorId: video.authorId);
  }

  /// A bounded batch of timeline comments beginning at [start].
  Future<DouyuVodDanmakuChunk> danmaku(String id, Duration start) async {
    if (!_videoId.hasMatch(id) || start < Duration.zero) {
      throw const VodFailure('the danmaku cursor the walk carries is not a cursor');
    }
    final response = await _get(
      Uri.https('v.douyu.com', '/wgapi/vod/center/getBarrageList', {
        'vid': id,
        'start_time': '${start.inMilliseconds}',
        'end_time': '-1',
      }),
    );
    return parseDanmaku(response.text, start: start);
  }

  /// The presenter's encoded author id behind a room number: the live room
  /// only ever names its rid, while the replay catalog reads `up_id`. A
  /// room number is never taken for a presenter id.
  Future<String> authorIdFromRoom(String room) async {
    if (!RegExp(r'^[1-9][0-9]{0,18}$').hasMatch(room)) {
      throw const VodFailure('the replay room asked for is not a room');
    }
    final response = await http.send(
      LiveRequest.get(
        Uri.https('www.douyu.com', '/betard/$room'),
        headers: {'user-agent': userAgent, 'referer': 'https://www.douyu.com/'},
        site: 'douyu',
      ),
    );
    return authorIdFromBetard(response.text, status: response.statusCode);
  }

  /// Reads `room.up_id` out of a `betard` answer, which may arrive wrapped
  /// as a JSON-encoded string.
  static String authorIdFromBetard(String body, {int status = 200}) {
    if (status != 200) throw VodFailure('HTTP $status', statusCode: status);
    if (body.length > 8388608) throw const VodFailure('the room answer broke its bounds');
    Object? decoded;
    try {
      decoded = jsonDecode(body);
      if (decoded is String) decoded = jsonDecode(decoded);
    } on FormatException {
      throw const VodFailure('the room answer is not JSON the station sends');
    }
    final room = decoded is Map ? decoded['room'] : null;
    final id = room is Map ? _text(room['up_id']) : '';
    if (!RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(id) || id == '0') {
      throw const VodFailure('the room answer names no replay presenter');
    }
    return id;
  }

  Future<LiveResponse> _get(Uri uri) => _send(LiveRequest.get(uri, headers: _headers, site: 'douyu'));

  Future<LiveResponse> _send(LiveRequest request) async {
    final response = await http.send(request);
    if (response.statusCode == 404) {
      throw const VodFailure('the station keeps no such recording');
    }
    if (response.statusCode == 401) {
      throw const VodFailure('the station asks a login for this recording');
    }
    if (response.statusCode == 403 || response.statusCode == 429) {
      throw const VodFailure('the station refused the recording request');
    }
    if (response.statusCode != 200) {
      throw VodFailure('HTTP ${response.statusCode}', statusCode: response.statusCode);
    }
    return response;
  }

  /// Parses the author's session groups: a session's segments flatten into
  /// the rows, deduplicated by hash id.
  static ({List<DouyuVodVideo> videos, bool hasMore, int total}) parseReplays(
    String body, {
    required int page,
    required int limit,
    required String authorId,
  }) {
    final data = _data(body);
    final raw = data['list'];
    if (raw is! List) {
      throw const VodFailure('the replay list changed its shape');
    }
    final sessions = _list(raw);
    final rows = [for (final session in sessions) ..._list(session['video_list'])];
    final total = _int(data['count']) ?? 0;
    return (
      videos: _videos(rows, replay: true, authorId: authorId),
      hasMore: sessions.isNotEmpty && (total > 0 ? page * limit < total : sessions.length >= limit),
      total: total,
    );
  }

  /// Reads the ROOM object and the allowed signing data from a video page;
  /// the signing script extracts by its markers, never by running it.
  static DouyuVodDetail parseDetail(String html, {required String id}) {
    final marker = html.indexOf(r'window.$DATA');
    if (marker < 0) {
      throw const VodFailure('the recording page lost its metadata');
    }
    final roomMarker = RegExp(r'\bROOM\s*:\s*').firstMatch(html.substring(marker));
    if (roomMarker == null || roomMarker.start > 1024) {
      throw const VodFailure('the recording page lost its ROOM object');
    }
    final room = _embeddedObject(html, marker + roomMarker.end);
    if (room['vid'] != id || _int(room['point_id']) == null) {
      throw const VodFailure('the recording page is not about this recording');
    }
    final source = _scriptWith(html, 'function ub98484234');
    if (source == null) {
      throw const VodFailure('the recording page lost its signing data');
    }
    return DouyuVodDetail(video: DouyuVodVideo.fromJson(room), signer: DouyuVodSigner.fromScript(source));
  }

  /// The text of the script tag carrying [marker], found by its own
  /// boundaries rather than a DOM.
  static String? _scriptWith(String html, String marker) {
    var at = html.indexOf(marker);
    while (at >= 0) {
      final open = html.lastIndexOf('<script', at);
      final close = html.indexOf('</script>', at);
      if (open >= 0 && close > at) {
        final body = html.substring(html.indexOf('>', open) + 1, close);
        if (body.contains(marker)) return body;
      }
      at = html.indexOf(marker, at + marker.length);
    }
    return null;
  }

  /// Parses permissions and quality labels without substituting paid
  /// tiers.
  static List<DouyuVodQuality> parseQualities(String body) {
    final values = _data(body)['thumb_video'];
    if (values is! Map) {
      throw const VodFailure('the recording answer lost its renditions');
    }
    final result = <DouyuVodQuality>[];
    for (final entry in values.entries) {
      final raw = entry.value;
      if (raw is! Map) continue;
      final url = _text(raw['url']);
      final uri = Uri.tryParse(url);
      final valid =
          uri != null && uri.userInfo.isEmpty && uri.host.isNotEmpty && {'http', 'https'}.contains(uri.scheme);
      result.add(
        DouyuVodQuality(
          id: '${entry.key}',
          label: _text(raw['name']).isEmpty ? '${entry.key}' : _text(raw['name']),
          level: _int(raw['level']) ?? 0,
          url: valid ? url : '',
          playableFlag: _int(raw['has_pms']) == 1 || _int(raw['now_free']) == 1,
        ),
      );
    }
    result.sort((a, b) => b.level.compareTo(a.level));
    return List<DouyuVodQuality>.unmodifiable(result);
  }

  /// Parses real millisecond timestamps, text colors and the explicit
  /// server cursor.
  static DouyuVodDanmakuChunk parseDanmaku(String body, {required Duration start}) {
    final data = _data(body);
    final next = _int(data['end_time']) ?? -1;
    final messages = <VodDanmaku>[];
    for (final item in _list(data['list']).take(1000)) {
      final position = _int(item['tl']);
      final text = _text(item['ctt']).trim();
      if (position == null || position < 0 || text.isEmpty || text.length > 8192) continue;
      final color = switch (_int(item['ct'])) {
        1 => 0xff0000,
        2 => 0x1e87f0,
        3 => 0x7ac84b,
        4 => 0xff7f00,
        5 => 0x9b39f4,
        6 => 0xff69b4,
        _ => 0xffffff,
      };
      messages.add(
        VodDanmaku(
          progress: Duration(milliseconds: position),
          text: text,
          id: _text(item['mid']),
          color: color,
        ),
      );
    }
    messages.sort((a, b) => a.progress.compareTo(b.progress));
    return DouyuVodDanmakuChunk(
      messages: List<VodDanmaku>.unmodifiable(messages),
      next: next > start.inMilliseconds ? Duration(milliseconds: next) : null,
      blocked: (_int(data['forbidden_type']) ?? 0) != 0,
    );
  }

  static Map<String, Object?> _data(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const VodFailure('the recording answer is not JSON the station sends');
    }
    if (decoded is! Map<String, Object?>) {
      throw const VodFailure('the recording answer is not an object');
    }
    final code = _int(decoded['error'] ?? decoded['code']);
    if (code == 401 || code == -401) {
      throw const VodFailure('the station asks a login for this recording');
    }
    if (code != 0) {
      throw VodFailure('the recording endpoint answered an error ($code)');
    }
    final data = decoded['data'];
    if (data is! Map<String, Object?>) {
      throw const VodFailure('the recording answer lost its body');
    }
    return data;
  }

  static List<Map<String, Object?>> _list(Object? value) => value is List
      ? [
          for (final item in value)
            if (item is Map<String, Object?>) item,
        ]
      : const [];

  static List<DouyuVodVideo> _videos(List<Map<String, Object?>> items, {required bool replay, String authorId = ''}) {
    final unique = <String, DouyuVodVideo>{};
    for (final item in items.take(500)) {
      final video = DouyuVodVideo.fromJson({
        ...item,
        if ((_text(item['up_id']).isEmpty && _text(item['upId']).isEmpty) && authorId.isNotEmpty) 'up_id': authorId,
      }, replay: replay);
      if (_videoId.hasMatch(video.id)) unique[video.id] = video;
    }
    return List<DouyuVodVideo>.unmodifiable(unique.values);
  }

  /// The balanced JSON object an inline assignment opens with, quotes and
  /// escapes respected.
  static Map<String, Object?> _embeddedObject(String html, int start) {
    var from = start;
    while (from < html.length && html[from].trim().isEmpty) {
      from++;
    }
    if (from >= html.length || html[from] != '{') {
      throw const VodFailure('the recording metadata object is missing');
    }
    var quoted = false;
    var escaped = false;
    var depth = 0;
    for (var at = from; at < html.length && at - from < 2097152; at++) {
      final char = html[at];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (quoted && char == r'\') {
        escaped = true;
        continue;
      }
      if (char == '"') {
        quoted = !quoted;
        continue;
      }
      if (quoted) continue;
      if (char == '{') depth++;
      if (char == '}' && --depth == 0) {
        try {
          final value = jsonDecode(html.substring(from, at + 1));
          if (value is Map<String, Object?>) return value;
        } on FormatException {
          break;
        }
        break;
      }
    }
    throw const VodFailure('the recording metadata is not JSON the station sends');
  }
}

String _text(Object? value) => value is String
    ? value
    : value is int
    ? '$value'
    : '';

int? _int(Object? value) => switch (value) {
  final num n when n.isFinite && n == n.roundToDouble() => n.toInt(),
  final String s => int.tryParse(s.trim()),
  _ => null,
};

DateTime? _publishedAt(Object? value) {
  final seconds = int.tryParse(value?.toString() ?? '');
  if (seconds != null && seconds > 0 && seconds < 253402300800) {
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }
  return value is String ? DateTime.tryParse(value) : null;
}

Duration _durationOf(Map<String, Object?> json) {
  for (final key in const ['video_duration', 'duration', 'video_str_duration']) {
    final value = douyuVodDuration(json[key]);
    if (value > Duration.zero) return value;
  }
  return Duration.zero;
}

/// Seconds as a number, or the platform's `MM:SS` / `HH:MM:SS` text.
Duration douyuVodDuration(Object? value) {
  if (value is num && value.isFinite && value > 0) return Duration(milliseconds: (value * 1000).round());
  final text = _text(value).trim();
  if (text.isEmpty) return Duration.zero;
  final parts = text.split(':');
  if (parts.length > 3) return Duration.zero;
  var seconds = 0.0;
  for (final part in parts) {
    final number = double.tryParse(part);
    if (number == null || !number.isFinite || number < 0) return Duration.zero;
    seconds = seconds * 60 + number;
  }
  return seconds <= 31536000 ? Duration(milliseconds: (seconds * 1000).round()) : Duration.zero;
}

/// The picture address as the station returns it, made absolute where the
/// form allows.
String normalizeImageUrl(Object? source) {
  final value = source is String ? source.trim() : '';
  if (value.isEmpty || value.toLowerCase() == 'null') return '';
  if (value.startsWith('//')) return 'https:$value';
  final uri = Uri.tryParse(value);
  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty) return value;
  return '';
}

/// The station escapes titles for HTML; the viewer reads them unescaped.
String decodeHtmlEntities(String text) {
  if (!text.contains('&')) return text;
  return text.replaceAllMapped(_entity, (match) {
    final named = _names[match.group(1)];
    if (named != null) return named;
    final numeric = match.group(2);
    if (numeric != null) {
      final code = numeric.startsWith('x') || numeric.startsWith('X')
          ? int.tryParse(numeric.substring(1), radix: 16)
          : int.tryParse(numeric);
      final scalar = code != null && code >= 0 && code <= 0x10FFFF ? String.fromCharCode(code) : null;
      if (scalar != null) return scalar;
    }
    return match.group(0)!;
  });
}

final RegExp _entity = RegExp('&([a-zA-Z][a-zA-Z0-9]{1,31});|&#([xX][0-9a-fA-F]+|[0-9]+);');

const Map<String, String> _names = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': '\u00a0',
  'copy': '\u00a9',
  'middot': '\u00b7',
  'hellip': '\u2026',
  'mdash': '\u2014',
  'ndash': '\u2013',
  'laquo': '\u00ab',
  'raquo': '\u00bb',
  'times': '\u00d7',
};
