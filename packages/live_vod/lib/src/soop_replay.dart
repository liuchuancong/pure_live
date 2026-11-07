import 'dart:convert';

import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest;
import 'package:live_vod/src/archive.dart' show ArchiveQuality, ArchiveVideo;
import 'package:live_vod/src/vod_models.dart' show VodFailure;

/// Public SOOP broadcast metadata, without transient media URLs.
final class SoopArchiveVideo implements ArchiveVideo {
  /// Creates one creator archive row.
  const new({
    required this.id,
    required this.title,
    required this.authorId,
    this.authorName = '',
    this.cover = '',
    this.publishedAt,
    this.duration = Duration.zero,
  });

  @override
  final String id;

  @override
  final String title;

  /// The broadcaster's public id.
  final String authorId;

  /// The platform-supplied creator name.
  final String authorName;

  /// The public thumbnail.
  final String cover;

  /// The publication instant, read in Korea Standard Time.
  final DateTime? publishedAt;

  @override
  final Duration duration;
}

/// The server's pagination, independent of how many rows survive validation.
typedef SoopArchiveList = ({List<SoopArchiveVideo> videos, bool hasMore});

/// One actual file of a recording; the qualities are as transient as the
/// addresses behind them.
final class SoopArchivePart implements ArchiveVideo {
  /// Creates a part, keeping the server's stable [order].
  const new({required this.recording, required this.order, required this.qualities, required this.duration});

  /// The parent recording's metadata.
  final SoopArchiveVideo recording;

  /// The server's stable part number.
  final int order;

  /// The qualities this part's current answer permits.
  final List<SoopArchiveQuality> qualities;

  @override
  String get id => '${recording.id}:$order';

  @override
  String get title => '${recording.title} · $order';

  @override
  final Duration duration;
}

/// One permitted HTTP rendition from a part's quality list.
final class SoopArchiveQuality implements ArchiveQuality {
  /// Creates one rendition; transient URLs are never persisted with
  /// progress.
  const new({required this.id, required this.label, required this.url});

  @override
  final String id;

  @override
  final String label;

  /// The validated CDN address, refreshed whenever playback reopens.
  final String url;

  @override
  bool get playable => true;
}

/// The current SOOP public station and video APIs, on the shared proxied
/// transport. A creator's replays are the station's own review list; a
/// recording's parts and permitted renditions come from its public video
/// answer, and only server-supplied files are ever admitted.
final class SoopArchiveApi {
  /// Builds the source over [http] and the viewer's SOOP login, if any.
  new(this.http, {this.cookie = ''});

  /// The shared transport (proxy, rate limiting and its own defaults).
  final LiveHttp http;

  /// The viewer's SOOP cookie (`''` for a guest reads; some recordings ask
  /// for a login and are refused with a message that says so).
  final String cookie;

  static final RegExp _id = RegExp(r'^[1-9][0-9]{0,18}$');
  static final RegExp _author = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  /// The API origin's web identity, the one the live site's own requests
  /// carry.
  static const String _origin = 'https://www.sooplive.co.kr';

  /// Desktop Chrome 128, the user agent the platform's API answers.
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/128.0.0.0 Safari/537.36';

  /// Desktop Chrome 140, the user agent the media CDN sees.
  static const String _mediaUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/140.0.0.0 Safari/537.36';

  /// The headers a public recording's media address must open with: the
  /// player page's own referer. Public media never forwards the account's
  /// cookies.
  static Map<String, String> mediaHeaders(String id) => {
    'referer': 'https://vod.sooplive.com/player/$id',
    'user-agent': _mediaUserAgent,
  };

  /// The creator's review list, newest first, paged.
  Future<SoopArchiveList> list(String author, {int page = 1}) async {
    if (!_author.hasMatch(author) || page < 1 || page > 100000) {
      throw const VodFailure('the replay page asked for is not a page');
    }
    final root = await _send(
      Uri.https('chapi.sooplive.com', '/api/$author/vods/review', {
        'page': '$page',
        'per_page': '20',
        'orderby': 'reg_date',
      }),
    );
    return parseList(root, author: author, page: page);
  }

  /// The recording's parts, each with the renditions it permits now; a
  /// restriction never produces a guessed address.
  Future<List<SoopArchivePart>> detail(String id) async {
    if (!_id.hasMatch(id)) {
      throw const VodFailure('the recording id is not one the station gives out');
    }
    return parseDetail(
      await _send(
        Uri.https('api.m.sooplive.com', '/station/video/a/view'),
        fields: {'nTitleNo': id, 'nApiLevel': '10'},
      ),
      id: id,
    );
  }

  Future<Map<String, Object?>> _send(Uri url, {Map<String, String>? fields}) async {
    final headers = <String, String>{
      'accept': '*/*',
      'origin': _origin,
      'referer': '$_origin/',
      'sec-fetch-dest': 'empty',
      'sec-fetch-mode': 'cors',
      'sec-fetch-site': 'same-site',
      'user-agent': _userAgent,
      if (cookie.isNotEmpty) 'cookie': cookie,
    };
    final request = fields == null
        ? LiveRequest.get(url, headers: headers, site: 'soop')
        : LiveRequest.form(url, fields: fields, headers: headers, site: 'soop');
    final response = await http.send(request);
    if (response.statusCode == 401) {
      throw const VodFailure('the station asks a login for this replay');
    }
    if (response.statusCode == 404) {
      throw const VodFailure('the station keeps no such replay');
    }
    if (response.statusCode == 403 || response.statusCode == 429) {
      throw const VodFailure('the station refused the replay request');
    }
    if (response.statusCode != 200) {
      throw VodFailure('HTTP ${response.statusCode}', statusCode: response.statusCode);
    }
    return _root(response.text);
  }

  static Map<String, Object?> _root(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, Object?>) return decoded;
    } on FormatException {
      // The fixed diagnostics below name this failure.
    }
    throw const VodFailure('the replay answer is not JSON the station sends');
  }

  /// The list parser, with its pagination and creator identity checked
  /// independently of the rows.
  static SoopArchiveList parseList(Map<String, Object?> root, {required String author, required int page}) {
    final rows = root['data'];
    final meta = root['meta'];
    final lastPage = meta is Map ? _jsonInt(_pick(meta, 'last_page')) : null;
    if (rows is! List ||
        rows.length > 100 ||
        meta is! Map ||
        _jsonInt(_pick(meta, 'current_page')) != page ||
        lastPage == null) {
      throw const VodFailure('the replay list answer changed its pagination shape');
    }
    final seen = <String>{};
    final videos = <SoopArchiveVideo>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final ucc = row['ucc'];
      if (_text(_pick(row, 'user_id')) != author || ucc is! Map) continue;
      final id = _text(_pick(row, 'title_no'));
      final title = _text(_pick(row, 'title_name'));
      if (!_id.hasMatch(id) || title.isEmpty || title.length > 4096 || !seen.add(id)) continue;
      videos.add(
        SoopArchiveVideo(
          id: id,
          title: decodeHtmlEntities(title),
          authorId: author,
          authorName: _text(_pick(row, 'user_nick')),
          cover: normalizeImageUrl(_pick(ucc, 'thumb')),
          publishedAt: _date(_pick(row, 'reg_date')),
          duration: _duration(_pick(ucc, 'total_file_duration')),
        ),
      );
    }
    return (videos: List<SoopArchiveVideo>.unmodifiable(videos), hasMore: page < lastPage);
  }

  /// The detail parser: identity first, then the restrictions that mean
  /// what they say, then only the server's own files and renditions.
  static List<SoopArchivePart> parseDetail(Map<String, Object?> root, {required String id}) {
    final data = root['data'];
    if (data is! Map) {
      throw const VodFailure('the recording answer lost its body');
    }
    if (_jsonInt(_pick(data, 'code')) == -6221) {
      throw const VodFailure('the recording has been removed');
    }
    if (_jsonInt(_pick(data, 'code')) == -6205) {
      throw const VodFailure('the recording is private');
    }
    if (_pick(data, 'adult_status') == 'notLogin') {
      throw const VodFailure('the recording asks an age-verified login');
    }
    if (_pick(data, 'is_paid') == true || _pick(data, 'is_ppv') == true) {
      throw const VodFailure('paid recordings are not supported');
    }
    if (_jsonInt(_pick(root, 'result')) != 1 || _text(_pick(data, 'title_no')) != id) {
      throw const VodFailure('the recording answer is not about this recording');
    }
    final rows = _pick(data, 'files');
    if (rows is! List || rows.length > 500) {
      throw const VodFailure('the recording answer changed its file list');
    }
    final video = SoopArchiveVideo(
      id: id,
      title: _text(_pick(data, 'title')),
      authorId: _text(_pick(data, 'bj_id')),
      authorName: _text(_pick(data, 'writer_nick')),
      cover: normalizeImageUrl(_pick(data, 'thumb')),
      publishedAt: _date(_pick(data, 'write_tm')),
      duration: _duration(_pick(data, 'total_file_duration')),
    );
    final parts = <SoopArchivePart>[];
    final seen = <int>{};
    for (final row in rows) {
      if (row is! Map || _pick(row, 'hide') == 'Y') continue;
      final order = _jsonInt(_pick(row, 'file_order'));
      if (order == null || order < 1 || order > 100000 || !seen.add(order)) continue;
      final qualities = <SoopArchiveQuality>[];
      final ids = <String>{};
      final qualityInfo = _pick(row, 'quality_info');
      if (qualityInfo is List && qualityInfo.length <= 32) {
        for (final quality in qualityInfo) {
          if (quality is! Map) continue;
          final key = _text(_pick(quality, 'name'));
          final url = _url(_pick(quality, 'file'));
          final label = _text(_pick(quality, 'label'));
          if (key.isEmpty || key.length > 64 || label.isEmpty || label.length > 64 || url.isEmpty || !ids.add(key)) {
            continue;
          }
          qualities.add(SoopArchiveQuality(id: key, label: label, url: url));
        }
      }
      final file = _url(_pick(row, 'file'));
      if (qualities.isEmpty && file.isNotEmpty) {
        qualities.add(SoopArchiveQuality(id: 'source', label: '原画', url: file));
      }
      if (qualities.isNotEmpty) {
        parts.add(
          SoopArchivePart(
            recording: video,
            order: order,
            qualities: List<SoopArchiveQuality>.unmodifiable(qualities),
            duration: _duration(_pick(row, 'duration')),
          ),
        );
      }
    }
    parts.sort((a, b) => a.order.compareTo(b.order));
    if (parts.isEmpty) {
      throw const VodFailure('no public recording file answers; a login or the region may be why');
    }
    return List<SoopArchivePart>.unmodifiable(parts);
  }

  static Object? _pick(Map<dynamic, dynamic> owner, String key) => owner[key];

  static String _text(Object? value) => value is String
      ? value
      : value is int
      ? '$value'
      : '';

  static int? _jsonInt(Object? value) => switch (value) {
    final num n when n.isFinite && n == n.roundToDouble() => n.toInt(),
    final String s => int.tryParse(s.trim()),
    _ => null,
  };

  static Duration _duration(Object? value) {
    final n = _jsonInt(value);
    return n != null && n >= 0 && n <= 31536000000 ? Duration(milliseconds: n) : Duration.zero;
  }

  static DateTime? _date(Object? value) {
    final s = _text(value);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$').hasMatch(s)) return null;
    return DateTime.tryParse('${s.replaceFirst(' ', 'T')}+09:00')?.toUtc();
  }

  /// Only the station's own media hosts answer; anything else is dropped
  /// before it can become a playback address.
  static String _url(Object? value) {
    final raw = _text(value);
    final uri = Uri.tryParse(raw);
    final allowed = ['sooplive.com', 'sooplive.co.kr', 'afreecatv.com'];
    final ok =
        uri != null &&
        uri.scheme == 'https' &&
        uri.userInfo.isEmpty &&
        !uri.hasPort &&
        allowed.any((host) => uri.host == host || uri.host.endsWith('.$host'));
    return ok ? raw : '';
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
