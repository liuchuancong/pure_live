import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/common/request_scope.dart';

import 'youtube_link.dart';

enum YouTubeFailure {
  transport,
  access,
  rateLimited,
  service,
  missing,
  notLive,
  schema,
  cancelled,
  identity,
  unknownState,
  mediaUnavailable,
}

class YouTubeException implements Exception {
  const YouTubeException(this.kind);

  final YouTubeFailure kind;

  @override
  String toString() => 'YouTube ${kind.name}';
}

enum YouTubeState { live, offline, restricted, unknown }

class YouTubeStream {
  const YouTubeStream({
    required this.id,
    required this.label,
    required this.protocol,
    required this.codec,
    required this.height,
    required this.frameRate,
    required this.bitrate,
    required this.urls,
  });

  final String id;
  final String label;
  final String protocol;
  final String codec;
  final int? height;
  final double? frameRate;
  final int? bitrate;
  final List<Uri> urls;
}

class YouTubeRoom {
  const YouTubeRoom({
    required this.videoId,
    required this.channelId,
    required this.author,
    required this.title,
    required this.description,
    required this.thumbnail,
    required this.category,
    required this.currentViewers,
    required this.state,
    required this.streams,
  });

  final String videoId;
  final String channelId;
  final String author;
  final String title;
  final String description;
  final String thumbnail;
  final String category;
  final int? currentViewers;
  final YouTubeState state;
  final List<YouTubeStream> streams;
}

typedef YouTubeRequest = Future<({int status, String body, Uri finalUri})> Function({
  required Uri uri,
  required Map<String, String> headers,
  Object? data,
  CancelToken? cancel,
});

class YouTubeApi {
  YouTubeApi({YouTubeRequest? request}) : _request = request ?? _defaultRequest;

  static const origin = 'https://www.youtube.com';
  static const responseLimit = 16 * 1024 * 1024;
  static const userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';
  static const _fallbackApiKey = 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8';

  final YouTubeRequest _request;

  static Map<String, String> pageHeaders(String videoId) => {
    'User-Agent': userAgent,
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'Cookie': 'SOCS=CAI',
    'Referer': videoId.isEmpty ? '$origin/' : YouTubeLink.videoUrl(videoId),
  };

  static Map<String, String> mediaHeaders(String videoId) => {
    'User-Agent': userAgent,
    'Referer': YouTubeLink.videoUrl(videoId),
    'Origin': origin,
  };

  static Future<({int status, String body, Uri finalUri})> _defaultRequest({
    required Uri uri,
    required Map<String, String> headers,
    Object? data,
    CancelToken? cancel,
  }) => withRequestCancellation(cancel, (transport) async {
    final response = await HttpClient.instance.dio.request<ResponseBody>(
      uri.toString(),
      data: data,
      cancelToken: transport,
      options: Options(
        method: data == null ? 'GET' : 'POST',
        responseType: ResponseType.stream,
        followRedirects: true,
        maxRedirects: 5,
        headers: headers,
        contentType: data == null ? null : Headers.jsonContentType,
        receiveTimeout: const Duration(seconds: 25),
        validateStatus: (_) => true,
      ),
    );
    final body = response.data;
    if (body == null) throw const YouTubeException(YouTubeFailure.schema);
    final status = response.statusCode ?? 0;
    if (status != 200) {
      await body.stream.listen((_) {}).cancel();
      return (status: status, body: '', finalUri: response.realUri);
    }
    return (status: status, body: await readBody(body.stream), finalUri: response.realUri);
  });

  static Future<String> readBody(Stream<List<int>> stream, {Duration timeout = const Duration(seconds: 25)}) async {
    final iterator = StreamIterator(stream);
    final bytes = BytesBuilder(copy: false);
    final watch = Stopwatch()..start();
    try {
      while (true) {
        final remaining = timeout - watch.elapsed;
        if (remaining <= Duration.zero) throw TimeoutException('YouTube response deadline');
        if (!await iterator.moveNext().timeout(remaining)) break;
        final chunk = iterator.current;
        if (bytes.length + chunk.length > responseLimit) {
          throw const YouTubeException(YouTubeFailure.schema);
        }
        bytes.add(chunk);
      }
      return utf8.decode(bytes.takeBytes());
    } on FormatException {
      throw const YouTubeException(YouTubeFailure.schema);
    } finally {
      watch.stop();
      await iterator.cancel();
    }
  }

  Future<String> resolveReference(YouTubeLink reference, {CancelToken? cancel}) async {
    if (reference.kind == YouTubeLinkKind.video) return reference.id;
    final response = await _send(Uri.parse(reference.url), headers: pageHeaders(''), cancel: cancel);
    final redirected = YouTubeLink.parse(response.finalUri.toString());
    if (redirected?.kind == YouTubeLinkKind.video) return redirected!.id;
    final canonical = RegExp(
      r'''<link[^>]+rel=["']canonical["'][^>]+href=["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(response.body);
    final canonicalLink = canonical == null ? null : YouTubeLink.parse(canonical.group(1)!);
    if (canonicalLink?.kind == YouTubeLinkKind.video) return canonicalLink!.id;
    final initialPlayer = _embeddedObject(response.body, 'ytInitialPlayerResponse');
    final playerDetails = _optionalObject(initialPlayer['videoDetails']);
    final playerId = YouTubeLink.normalizeVideoId(_text(playerDetails['videoId']));
    final playerLive = _bool(playerDetails['isLive']) == true;
    if (playerId != null && playerLive) return playerId;
    final initialData = _embeddedObject(response.body, 'ytInitialData');
    final liveId = _findLiveVideoId(initialData);
    if (liveId != null) return liveId;
    throw const YouTubeException(YouTubeFailure.notLive);
  }

  Future<YouTubeRoom> room(String rawVideoId, {required bool includeMedia, CancelToken? cancel}) async {
    final videoId = YouTubeLink.normalizeVideoId(rawVideoId);
    if (videoId == null) throw const YouTubeException(YouTubeFailure.identity);
    final page = await _send(Uri.parse(YouTubeLink.videoUrl(videoId)), headers: pageHeaders(videoId), cancel: cancel);
    final initialPlayer = _embeddedObject(page.body, 'ytInitialPlayerResponse');
    final initialData = _embeddedObject(page.body, 'ytInitialData');
    final apiKey = RegExp(r'"INNERTUBE_API_KEY"\s*:\s*"([^"]+)"').firstMatch(page.body)?.group(1) ?? _fallbackApiKey;
    final api = await _json(
      Uri.parse('$origin/youtubei/v1/player').replace(queryParameters: {'key': apiKey}),
      headers: {
        ...pageHeaders(videoId),
        'Accept': 'application/json',
        'Content-Type': Headers.jsonContentType,
        'Origin': origin,
      },
      data: {
        'videoId': videoId,
        'contentCheckOk': true,
        'racyCheckOk': true,
        'context': {
          'client': {
            'clientName': 'ANDROID',
            'clientVersion': '21.08.266',
            'platform': 'DESKTOP',
            'clientScreen': 'EMBED',
            'clientFormFactor': 'UNKNOWN_FORM_FACTOR',
            'browserName': 'Chrome',
          },
          'user': {'lockedSafetyMode': false},
          'request': {'useSsl': true},
        },
      },
      cancel: cancel,
    );
    final apiDetails = _optionalObject(api['videoDetails']);
    final initialDetails = _optionalObject(initialPlayer['videoDetails']);
    final details = <String, dynamic>{...initialDetails, ...apiDetails};
    final actualId = YouTubeLink.normalizeVideoId(_text(details['videoId']));
    if (actualId != videoId) throw const YouTubeException(YouTubeFailure.identity);
    final apiStatus = _optionalObject(api['playabilityStatus']);
    final initialStatus = _optionalObject(initialPlayer['playabilityStatus']);
    final status = _text(apiStatus['status']).isNotEmpty ? apiStatus : initialStatus;
    final statusCode = _text(status['status']).toUpperCase();
    final reason = _text(status['reason']).toLowerCase();
    final initialMicro = _optionalObject(_optionalObject(initialPlayer['microformat'])['playerMicroformatRenderer']);
    final apiMicro = _optionalObject(_optionalObject(api['microformat'])['playerMicroformatRenderer']);
    final micro = <String, dynamic>{...initialMicro, ...apiMicro};
    final liveDetails = _optionalObject(micro['liveBroadcastDetails']);
    final isLive = _bool(details['isLive']) == true || _bool(liveDetails['isLiveNow']) == true;
    final isLiveContent =
        isLive ||
        _bool(details['isLiveContent']) == true ||
        _bool(details['isUpcoming']) == true ||
        liveDetails.isNotEmpty;
    final isPrivate = _bool(details['isPrivate']) == true;
    final restricted =
        isPrivate ||
        const {'LOGIN_REQUIRED', 'AGE_CHECK_REQUIRED', 'CONTENT_CHECK_REQUIRED'}.contains(statusCode) ||
        reason.contains('sign in') ||
        reason.contains('private');
    final state = restricted
        ? YouTubeState.restricted
        : isLive && statusCode == 'OK'
        ? YouTubeState.live
        : isLiveContent || statusCode == 'LIVE_STREAM_OFFLINE'
        ? YouTubeState.offline
        : statusCode.isEmpty
        ? YouTubeState.unknown
        : throw const YouTubeException(YouTubeFailure.notLive);
    final title = _requiredText(details['title']);
    final author = _requiredText(details['author']);
    final thumbnail = _thumbnail(details['thumbnail'] ?? micro['thumbnail']);
    final streaming = _optionalObject(api['streamingData']);
    final streams = state == YouTubeState.live && includeMedia
        ? await _streams(streaming, videoId: videoId, cancel: cancel)
        : const <YouTubeStream>[];
    return YouTubeRoom(
      videoId: videoId,
      channelId: _text(details['channelId']),
      author: author,
      title: title,
      description: _text(details['shortDescription']),
      thumbnail: thumbnail,
      category: _text(micro['category']),
      currentViewers: state == YouTubeState.live ? _currentViewers(initialData) : null,
      state: state,
      streams: streams,
    );
  }

  Future<List<YouTubeStream>> _streams(
    Map<String, dynamic> streaming, {
    required String videoId,
    CancelToken? cancel,
  }) async {
    final result = <YouTubeStream>[];
    final seen = <String>{};
    final hlsRaw = _text(streaming['hlsManifestUrl']);
    if (hlsRaw.isNotEmpty) {
      final master = _mediaUri(hlsRaw);
      try {
        final response = await _send(master, headers: mediaHeaders(videoId), cancel: cancel);
        for (final variant in _hlsVariants(master, response.body)) {
          if (!seen.add(variant.id)) continue;
          result.add(variant);
        }
      } on YouTubeException catch (error) {
        if (error.kind == YouTubeFailure.cancelled) rethrow;
      } on FormatException {
        // Keep the master as a playable automatic source when variant metadata
        // grows beyond this adapter's bounded parser.
      }
      if (!result.any((value) => value.protocol == 'hls')) {
        result.add(
          YouTubeStream(
            id: 'hls:auto',
            label: 'HLS Auto',
            protocol: 'hls',
            codec: '',
            height: null,
            frameRate: null,
            bitrate: null,
            urls: List.unmodifiable([master]),
          ),
        );
        seen.add('hls:auto');
      }
    }
    final formats = streaming['formats'];
    if (formats is List && formats.length <= 64) {
      for (final raw in formats) {
        final format = _optionalObject(raw);
        final url = _text(format['url']);
        final itag = _int(format['itag']);
        final label = _text(format['qualityLabel']);
        if (url.isEmpty || itag == null || label.isEmpty) continue;
        final id = 'http:$itag';
        if (!seen.add(id)) continue;
        final mime = _text(format['mimeType']);
        result.add(
          YouTubeStream(
            id: id,
            label: label,
            protocol: 'http',
            codec: _codec(mime),
            height: _int(format['height']),
            frameRate: _double(format['fps']),
            bitrate: _int(format['bitrate']),
            urls: List.unmodifiable([_mediaUri(url)]),
          ),
        );
      }
    }
    final dashRaw = _text(streaming['dashManifestUrl']);
    if (dashRaw.isNotEmpty && seen.add('dash:auto')) {
      result.add(
        YouTubeStream(
          id: 'dash:auto',
          label: 'DASH Auto',
          protocol: 'dash',
          codec: '',
          height: null,
          frameRate: null,
          bitrate: null,
          urls: List.unmodifiable([_mediaUri(dashRaw)]),
        ),
      );
    }
    result.sort((left, right) {
      final rank = qualitySort(right).compareTo(qualitySort(left));
      return rank != 0 ? rank : left.id.compareTo(right.id);
    });
    return List.unmodifiable(result);
  }

  static List<YouTubeStream> _hlsVariants(Uri source, String text) {
    if (text.length > 4 * 1024 * 1024 || utf8.encode(text).length > 4 * 1024 * 1024) {
      throw const FormatException('YouTube HLS master exceeds byte budget');
    }
    final lines = const LineSplitter().convert(text).map((line) => line.trim()).where((line) => line.isNotEmpty);
    final iterator = lines.iterator;
    if (!iterator.moveNext() || iterator.current != '#EXTM3U') {
      throw const FormatException('Expected YouTube HLS master');
    }
    Map<String, String>? pending;
    final result = <YouTubeStream>[];
    final seen = <String>{};
    while (iterator.moveNext()) {
      final line = iterator.current;
      if (line.startsWith('#EXT-X-STREAM-INF:')) {
        if (pending != null || result.length >= 64) throw const FormatException('Invalid YouTube HLS variant count');
        pending = _attributes(line.substring(18));
        continue;
      }
      if (line.startsWith('#')) continue;
      if (pending == null) continue;
      final resolution = RegExp(r'^[1-9][0-9]{0,4}x([1-9][0-9]{0,4})$').firstMatch(pending['RESOLUTION'] ?? '');
      final height = int.tryParse(resolution?.group(1) ?? '');
      final frameRate = double.tryParse(pending['FRAME-RATE'] ?? '');
      final bandwidth = int.tryParse(pending['BANDWIDTH'] ?? '');
      final codec = _codec(pending['CODECS'] ?? '');
      final frameId = frameRate != null && frameRate > 30 ? frameRate.round().toString() : '0';
      final id = 'hls:${height ?? 0}:$frameId:${codec.isEmpty ? 'auto' : codec}';
      final uri = _mediaUri(source.resolve(line).toString());
      if (!seen.add(id)) throw const FormatException('Ambiguous YouTube HLS quality identity');
      result.add(
        YouTubeStream(
          id: id,
          label: height == null ? 'HLS Auto' : '${height}p${frameId == '0' ? '' : frameId}',
          protocol: 'hls',
          codec: codec,
          height: height,
          frameRate: frameRate,
          bitrate: bandwidth,
          urls: List.unmodifiable([uri]),
        ),
      );
      pending = null;
    }
    if (pending != null || result.isEmpty) throw const FormatException('Incomplete YouTube HLS master');
    return List.unmodifiable(result);
  }

  static int qualitySort(YouTubeStream stream) {
    final height = stream.height ?? 0;
    final fps = (stream.frameRate ?? 0).round().clamp(0, 999).toInt();
    final protocol = switch (stream.protocol) {
      'hls' => 30,
      'http' => 20,
      'dash' => 10,
      _ => 0,
    };
    return height * 1000 + fps + protocol;
  }

  Future<({int status, String body, Uri finalUri})> _send(
    Uri uri, {
    required Map<String, String> headers,
    Object? data,
    CancelToken? cancel,
  }) async {
    if (cancel?.isCancelled == true) throw const YouTubeException(YouTubeFailure.cancelled);
    late final ({int status, String body, Uri finalUri}) response;
    try {
      response = await _request(uri: uri, headers: headers, data: data, cancel: cancel);
    } catch (error) {
      if (cancel?.isCancelled == true || (error is DioException && CancelToken.isCancel(error))) {
        throw const YouTubeException(YouTubeFailure.cancelled);
      }
      if (error is YouTubeException) rethrow;
      throw const YouTubeException(YouTubeFailure.transport);
    }
    if (cancel?.isCancelled == true) throw const YouTubeException(YouTubeFailure.cancelled);
    final failure = switch (response.status) {
      200 => null,
      400 => YouTubeFailure.schema,
      401 || 403 => YouTubeFailure.access,
      404 => YouTubeFailure.missing,
      429 => YouTubeFailure.rateLimited,
      >= 500 => YouTubeFailure.service,
      _ => YouTubeFailure.transport,
    };
    if (failure != null) throw YouTubeException(failure);
    if (response.body.isEmpty || response.body.length > responseLimit) {
      throw const YouTubeException(YouTubeFailure.schema);
    }
    return response;
  }

  Future<Map<String, dynamic>> _json(
    Uri uri, {
    required Map<String, String> headers,
    required Object data,
    CancelToken? cancel,
  }) async {
    final response = await _send(uri, headers: headers, data: data, cancel: cancel);
    try {
      return _object(jsonDecode(response.body));
    } on FormatException {
      throw const YouTubeException(YouTubeFailure.schema);
    }
  }

  static Map<String, dynamic> _embeddedObject(String text, String marker) {
    var offset = text.indexOf(marker);
    while (offset >= 0) {
      final start = text.indexOf('{', offset + marker.length);
      if (start < 0) break;
      var depth = 0;
      var quoted = false;
      var escaped = false;
      for (var index = start; index < text.length; index++) {
        final code = text.codeUnitAt(index);
        if (quoted) {
          if (escaped) {
            escaped = false;
          } else if (code == 0x5c) {
            escaped = true;
          } else if (code == 0x22) {
            quoted = false;
          }
          continue;
        }
        if (code == 0x22) {
          quoted = true;
        } else if (code == 0x7b) {
          depth++;
        } else if (code == 0x7d && --depth == 0) {
          try {
            return _object(jsonDecode(text.substring(start, index + 1)));
          } on FormatException {
            break;
          }
        }
      }
      offset = text.indexOf(marker, offset + marker.length);
    }
    return <String, dynamic>{};
  }

  static String? _findLiveVideoId(Object? root) {
    var visited = 0;
    String? walk(Object? value) {
      if (++visited > 250000) throw const YouTubeException(YouTubeFailure.schema);
      if (value is List) {
        for (final item in value) {
          final match = walk(item);
          if (match != null) return match;
        }
      } else if (value is Map) {
        final map = value.map((key, value) => MapEntry(key.toString(), value));
        final id = YouTubeLink.normalizeVideoId(_text(map['videoId']));
        if (id != null && _looksLive(map)) return id;
        for (final item in map.values) {
          final match = walk(item);
          if (match != null) return match;
        }
      }
      return null;
    }

    return walk(root);
  }

  static bool _looksLive(Map<String, dynamic> map) {
    if (_bool(map['isLive']) == true || _bool(map['isLiveNow']) == true) return true;
    final encoded = jsonEncode(map).toLowerCase();
    return encoded.contains('badge_style_type_live_now') ||
        encoded.contains('thumbnail_overlay_time_status_style_live') ||
        encoded.contains('"label":"live"');
  }

  static int? _currentViewers(Object? root) {
    var visited = 0;
    int? walk(Object? value) {
      if (++visited > 250000) return null;
      if (value is List) {
        for (final item in value) {
          final match = walk(item);
          if (match != null) return match;
        }
      } else if (value is Map) {
        final map = value.map((key, value) => MapEntry(key.toString(), value));
        final renderer = _optionalObject(map['videoViewCountRenderer']);
        if (renderer.isNotEmpty && _bool(renderer['isLive']) == true) {
          final text = _runsText(renderer['viewCount']);
          final number = int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), ''));
          if (number != null && number >= 0) return number;
        }
        for (final item in map.values) {
          final match = walk(item);
          if (match != null) return match;
        }
      }
      return null;
    }

    return walk(root);
  }

  static String _runsText(Object? value) {
    final map = _optionalObject(value);
    final simple = _text(map['simpleText']);
    if (simple.isNotEmpty) return simple;
    final runs = map['runs'];
    if (runs is! List) return '';
    return runs.map((run) => _text(_optionalObject(run)['text'])).join();
  }

  static String _thumbnail(Object? value) {
    final items = _optionalObject(value)['thumbnails'];
    if (items is! List || items.length > 64) return '';
    for (final item in items.reversed) {
      final raw = _text(_optionalObject(item)['url']);
      if (raw.isEmpty) continue;
      final uri = Uri.tryParse(raw);
      final host = uri?.host.toLowerCase() ?? '';
      if (uri != null && uri.scheme == 'https' && uri.userInfo.isEmpty && !uri.hasFragment && _imageHost(host)) {
        return uri.toString();
      }
    }
    return '';
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map) throw const YouTubeException(YouTubeFailure.schema);
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static Map<String, dynamic> _optionalObject(Object? value) {
    if (value == null) return <String, dynamic>{};
    return _object(value);
  }

  static String _requiredText(Object? value) {
    final text = _text(value);
    if (text.isEmpty || text.length > 8192) throw const YouTubeException(YouTubeFailure.schema);
    return text;
  }

  static String _text(Object? value) {
    if (value == null) return '';
    if (value is! String || value.length > 4 * 1024 * 1024) {
      throw const YouTubeException(YouTubeFailure.schema);
    }
    return value.trim();
  }

  static bool? _bool(Object? value) {
    if (value == null) return null;
    if (value is! bool) throw const YouTubeException(YouTubeFailure.schema);
    return value;
  }

  static int? _int(Object? value) {
    if (value == null || value == '') return null;
    if (value is int) return value;
    if (value is num && value.isFinite && value == value.roundToDouble()) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double? _double(Object? value) {
    if (value == null || value == '') return null;
    final result = value is num ? value.toDouble() : double.tryParse(value.toString());
    return result != null && result.isFinite && result >= 0 ? result : null;
  }

  static String _codec(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('av01')) return 'av1';
    if (lower.contains('vp09') || lower.contains('vp9')) return 'vp9';
    if (lower.contains('hev1') || lower.contains('hvc1')) return 'h265';
    if (lower.contains('avc1') || lower.contains('h264')) return 'h264';
    return '';
  }

  static Uri _mediaUri(String raw) {
    if (raw.isEmpty || raw.length > 65536 || raw.contains(RegExp(r'[\s\x00-\x1f]'))) {
      throw const YouTubeException(YouTubeFailure.schema);
    }
    final uri = Uri.tryParse(raw);
    final host = uri?.host.toLowerCase() ?? '';
    if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty || uri.hasFragment || !_mediaHost(host)) {
      throw const YouTubeException(YouTubeFailure.schema);
    }
    return uri;
  }

  static bool _mediaHost(String host) =>
      host == 'googlevideo.com' ||
      host.endsWith('.googlevideo.com') ||
      host == 'youtube.com' ||
      host.endsWith('.youtube.com') ||
      host == 'youtube-nocookie.com' ||
      host.endsWith('.youtube-nocookie.com');

  static bool _imageHost(String host) =>
      host == 'ytimg.com' || host.endsWith('.ytimg.com') || host == 'ggpht.com' || host.endsWith('.ggpht.com');

  static Map<String, String> _attributes(String text) {
    final values = <String, String>{};
    final pattern = RegExp(r'([A-Z0-9-]+)=("[^"\r\n\x00]*"|[^,\s"]+)(?:,|$)');
    var offset = 0;
    while (offset < text.length) {
      final match = pattern.matchAsPrefix(text, offset);
      if (match == null || values.containsKey(match[1])) {
        throw const FormatException('Malformed YouTube HLS attributes');
      }
      final value = match[2]!;
      values[match[1]!] = value.startsWith('"') ? value.substring(1, value.length - 1) : value;
      offset = match.end;
    }
    return values;
  }
}
