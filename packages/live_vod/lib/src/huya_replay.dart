import 'dart:convert';

import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest, LiveResponse;
import 'package:live_vod/src/archive.dart' show ArchiveQuality, ArchiveVideo;
import 'package:live_vod/src/vod_models.dart' show VodFailure, VodVideo;

final RegExp _id = RegExp(r'^[1-9][0-9]{0,18}$');
final RegExp _assignment = RegExp(r'window\.HNF_GLOBAL_INIT\s*=');
final RegExp _responseKey = RegExp(r'"userPageLiveRecordVideoRsp"\s*:\s*');
final RegExp _metadataFunction = RegExp(
  r'"_(?:proto|write|read)"\s*:\s*function\s*\([^)]{0,128}\)\s*\{[^{}]{0,1024}\}',
);

/// Public metadata for one officially archived Huya broadcast; no media URL
/// or credential is retained.
final class HuyaArchiveVideo implements ArchiveVideo {
  /// Creates one archive row.
  const new({
    required this.id,
    required this.title,
    required this.authorId,
    this.authorName = '',
    this.cover = '',
    this.duration = Duration.zero,
    this.date = '',
  });

  @override
  final String id;

  @override
  final String title;

  /// The presenter's public uid, distinct from the room number.
  final String authorId;

  /// The presenter's display name.
  final String authorName;

  /// The public cover.
  final String cover;

  @override
  final Duration duration;

  /// The date label the official archive carries.
  final String date;

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

/// One page of archived broadcasts, in the platform's order.
typedef HuyaArchiveList = ({List<HuyaArchiveVideo> videos, bool hasMore});

/// One permitted rendition, freshly resolved for playback. The id is the
/// https playlist itself — a recording's playlist does not expire — while
/// the address behind it stays transient and is never written into local
/// progress.
final class HuyaArchiveQuality implements ArchiveQuality {
  /// Wraps a validated playlist address and its label.
  const new({required this.id, required this.label, required this.url});

  @override
  final String id;

  @override
  final String label;

  /// The validated https playlist.
  final String url;

  @override
  bool get playable => url.isNotEmpty;
}

/// The official Huya presenter archive: the video station's own SSR page
/// for the list, and `getMomentContent` for a recording's permitted
/// renditions. Only the page's official data assignment is read — the
/// scripts' prototype functions are discarded as metadata, never
/// evaluated.
final class HuyaArchiveApi {
  /// Builds the source over the shared proxied transport.
  new(this.http);

  /// The shared transport; this wrapper does not close it.
  final LiveHttp http;

  /// Media carries no application cookie and no cross-platform headers.
  static const Map<String, String> _mediaHeaders = {
    'referer': 'https://www.huya.com/',
    'user-agent': _desktopUserAgent,
  };

  /// The desktop string the archive page answers: the official desktop
  /// archive redirects mobile identities to the video home page, whose
  /// assignment carries no presenter archive response.
  static const String _desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/128.0.0.0 Safari/537.36';

  /// The replay definitions the station names, for the ones `defName` does
  /// not.
  static const Map<String, String> _definitionNames = {'yuanhua': '原画', '1300': '720P', '350': '360P'};

  /// The archive's own rank for the source recording, above every
  /// transcode.
  static const int _sourceRank = 1 << 30;

  /// The presenter's archive, paged without a login requirement.
  Future<HuyaArchiveList> list(String uid, {int page = 1}) async {
    if (!_id.hasMatch(uid) || page < 1 || page > 10000) {
      throw const VodFailure('the replay page asked for is not a page');
    }
    final response = await _get(Uri.https('www.huya.com', '/video/u/$uid', {'tabName': 'live', 'pageIndex': '$page'}));
    return parseList(response.text, uid: uid, page: page);
  }

  /// The recording's permitted renditions, source first; an empty answer
  /// refuses with its own message.
  Future<List<HuyaArchiveQuality>> qualities(String videoId) async {
    if (!_id.hasMatch(videoId)) {
      throw const VodFailure('the recording id is not one the station gives out');
    }
    final response = await _get(Uri.https('liveapi.huya.com', '/moment/getMomentContent', {'videoId': videoId}));
    final qualities = parseQualities(response.text, status: response.statusCode);
    if (qualities.isEmpty) {
      throw const VodFailure('the recording keeps no permitted rendition');
    }
    return qualities;
  }

  Future<LiveResponse> _get(Uri url, {Map<String, String> headers = _mediaHeaders}) async {
    final response = await http.send(LiveRequest.get(url, headers: headers, site: 'huya'));
    if (response.statusCode == 404) {
      throw const VodFailure('the station keeps no such replay');
    }
    if (response.statusCode == 401) {
      throw const VodFailure('the station asks a login for this replay');
    }
    if (response.statusCode == 403 || response.statusCode == 429) {
      throw const VodFailure('the station refused the replay request');
    }
    if (response.statusCode != 200) {
      throw VodFailure('HTTP ${response.statusCode}', statusCode: response.statusCode);
    }
    return response;
  }

  /// Parses only the official data assignment out of the video page; a
  /// presenter's video never lands under another uid's name.
  static HuyaArchiveList parseList(String html, {required String uid, required int page}) {
    if (html.length > 8388608 || !_id.hasMatch(uid) || page < 1) {
      throw const VodFailure('the replay list answer broke its bounds');
    }
    final assignment = _assignment.firstMatch(html);
    if (assignment == null) {
      throw const VodFailure('the replay list assignment is missing');
    }
    final key = _responseKey.firstMatch(html.substring(assignment.end));
    if (key == null) {
      throw const VodFailure('the replay list answer lost its key');
    }
    final literal = _object(html.substring(assignment.end + key.end));
    Object? decoded;
    try {
      decoded = jsonDecode(literal.replaceAll(_metadataFunction, '"_proto":null'));
    } on FormatException {
      throw const VodFailure('the replay list carries metadata the station does not send');
    }
    if (decoded is! Map || decoded['respHeader'] is! Map || (decoded['respHeader'] as Map)['code'] != 0) {
      throw const VodFailure('the replay list refused the request');
    }
    final vector = decoded['videoDataList'];
    final rows = vector is Map ? vector['value'] : null;
    if (rows is! List || rows.length > 100) {
      throw const VodFailure('the replay list changed its shape');
    }
    final seen = <String>{};
    final videos = <HuyaArchiveVideo>[];
    for (final row in rows) {
      if (row is! Map || row['videoData'] is! Map) continue;
      final data = row['videoData'] as Map;
      final id = _text(data['vid']);
      final title = _text(data['videoTitle']);
      final user = data['userInfo'];
      if (!_id.hasMatch(id) || title.isEmpty || !seen.add(id)) continue;
      // The requested uid names the archive; a row another presenter owns
      // stays out.
      final actual = user is Map ? _text(user['uid']) : '';
      if (actual.isNotEmpty && actual != uid) continue;
      final covers = data['covers'];
      videos.add(
        HuyaArchiveVideo(
          id: id,
          title: decodeHtmlEntities(title),
          authorId: uid,
          authorName: user is Map ? _text(user['userNick']) : '',
          cover: normalizeImageUrl(covers is Map ? covers['cover320'] ?? covers['cover'] : null),
          duration: _duration(data['duration']),
          date: _text(row['date']),
        ),
      );
    }
    final total = _int(decoded['total']);
    return (
      videos: List<HuyaArchiveVideo>.unmodifiable(videos),
      hasMore: rows.isNotEmpty && total != null && page * 10 < total,
    );
  }

  /// The renditions of one recording: `data.moment.videoInfo.definitions`,
  /// the source first and transcodes by height, deduplicated by playlist.
  static List<HuyaArchiveQuality> parseQualities(String body, {int status = 200}) {
    if (status != 200) {
      throw VodFailure('HTTP $status', statusCode: status);
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const VodFailure('the recording answer is not JSON the station sends');
    }
    if (decoded is! Map) {
      throw const VodFailure('the recording answer is not an object');
    }
    final moment = _map(_map(decoded['data'])?['moment']);
    final info = _map(moment?['videoInfo']);
    final rows = info?['definitions'];
    if (rows is! List) return const [];
    final seen = <String>{};
    final ranked = <({HuyaArchiveQuality quality, int rank})>[];
    for (final raw in rows) {
      final item = _map(raw);
      if (item == null) continue;
      final url = replayUrl(item['m3u8']) ?? replayUrl(item['url']);
      if (url == null || !seen.add(url)) continue;
      final definition = Uri.tryParse(url)?.queryParameters['definition'] ?? '';
      final source = definition == 'yuanhua';
      final name = _text(item['defName']);
      final height = _int(item['height']) ?? 0;
      ranked.add((
        quality: HuyaArchiveQuality(
          id: url,
          label: source || name.isEmpty ? (_definitionNames[definition] ?? '默认') : name,
          url: url,
        ),
        rank: source ? _sourceRank : (height > 0 ? height : 0),
      ));
    }
    ranked.sort((a, b) => b.rank.compareTo(a.rank));
    return [for (final entry in ranked) entry.quality];
  }

  /// A recording playlist: an http(s) `.m3u8` address, `http://` on the
  /// station's own hosts upgraded to https (the VOD CDN serves both); null
  /// for anything else, so a live quality's bit rate is never taken for a
  /// recording.
  static String? replayUrl(Object? value) {
    if (value is! String) return null;
    final text = value.trim();
    if (!text.toLowerCase().contains('.m3u8')) return null;
    final uri = Uri.tryParse(text);
    if (uri == null || uri.userInfo.isNotEmpty || uri.hasPort) return null;
    final host = uri.host.toLowerCase();
    final onStation = host == 'huya.com' || host.endsWith('.huya.com');
    if (!onStation) return null;
    if (uri.scheme == 'https') return text;
    if (uri.scheme == 'http') {
      return uri.replace(scheme: 'https').toString();
    }
    return null;
  }

  /// The balanced JSON object a script assignment opens with, quotes and
  /// escapes respected.
  static String _object(String text) {
    final start = text.indexOf('{');
    if (start < 0 || text.substring(0, start).trim().isNotEmpty) {
      throw const VodFailure('the replay literal is missing');
    }
    var depth = 0;
    var quote = '';
    var escape = false;
    for (var i = start; i < text.length; i++) {
      final char = text[i];
      if (quote.isNotEmpty) {
        if (escape) {
          escape = false;
        } else if (char == r'\') {
          escape = true;
        } else if (char == quote) {
          quote = '';
        }
      } else if (char == '"' || char == "'") {
        quote = char;
      } else if (char == '{') {
        if (++depth > 64) {
          throw const VodFailure('the replay literal nests too deep');
        }
      } else if (char == '}' && --depth == 0) {
        return text.substring(start, i + 1);
      }
    }
    throw const VodFailure('the replay literal is truncated');
  }

  static Map<Object?, Object?>? _map(Object? value) => value is Map ? value : null;

  static String _text(Object? value) => value is String
      ? value
      : value is int
      ? '$value'
      : '';

  static int? _int(Object? value) => switch (value) {
    final num n when n.isFinite && n == n.roundToDouble() => n.toInt(),
    final String s => int.tryParse(s.trim()),
    _ => null,
  };

  static Duration _duration(Object? raw) {
    final parts = _text(raw).split(':');
    if (parts.length != 3) return Duration.zero;
    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);
    final seconds = int.tryParse(parts[2]);
    if (hours == null ||
        minutes == null ||
        seconds == null ||
        hours < 0 ||
        hours > 1000 ||
        minutes < 0 ||
        minutes > 59 ||
        seconds < 0 ||
        seconds > 59) {
      return Duration.zero;
    }
    return Duration(hours: hours, minutes: minutes, seconds: seconds);
  }

  /// The picture address as the station returns it, made absolute where the
  /// form allows.
  static String normalizeImageUrl(Object? source) {
    final value = source is String ? source.trim() : '';
    if (value.isEmpty || value.toLowerCase() == 'null') return '';
    if (value.startsWith('//')) return 'https:$value';
    final uri = Uri.tryParse(value);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty) return value;
    return '';
  }

  /// The station escapes titles for HTML; the viewer reads them unescaped.
  static String decodeHtmlEntities(String text) {
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

  static final RegExp _entity = RegExp('&([a-zA-Z][a-zA-Z0-9]{1,31});|&#([xX][0-9a-fA-F]+|[0-9]+);');

  static const Map<String, String> _names = {
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
}
