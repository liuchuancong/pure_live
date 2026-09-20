import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/common/request_scope.dart';

import 'seventeenlive_link.dart';

enum SeventeenLiveFailure {
  transport,
  access,
  rateLimited,
  service,
  missing,
  schema,
  cancelled,
  identity,
  unknownState,
  mediaUnavailable,
}

class SeventeenLiveException implements Exception {
  const SeventeenLiveException(this.kind);
  final SeventeenLiveFailure kind;

  @override
  String toString() => '17LIVE ${kind.name}';
}

enum SeventeenLiveState { live, offline, unknown }

class SeventeenLiveStream {
  const SeventeenLiveStream({required this.qualityId, required this.urls});
  final String qualityId;
  final List<Uri> urls;
}

class SeventeenLiveRoom {
  const SeventeenLiveRoom({
    required this.roomId,
    required this.userId,
    required this.nickname,
    required this.title,
    required this.avatar,
    required this.cover,
    required this.bio,
    required this.followers,
    required this.liveViewers,
    required this.sessionViewers,
    required this.audioOnly,
    required this.state,
    required this.streams,
  });

  final String roomId;
  final String userId;
  final String nickname;
  final String title;
  final String avatar;
  final String cover;
  final String bio;
  final int? followers;
  final int? liveViewers;
  final int? sessionViewers;
  final bool audioOnly;
  final SeventeenLiveState state;
  final List<SeventeenLiveStream> streams;
}

typedef SeventeenLiveRequest = Future<({int status, String body})> Function(Uri uri, CancelToken? cancel);

class SeventeenLiveApi {
  SeventeenLiveApi({SeventeenLiveRequest? request}) : _request = request ?? _defaultRequest;

  static const origin = 'https://17.live';
  static const apiOrigin = 'https://api-dsa.17app.co';
  static const responseLimit = 4 * 1024 * 1024;
  static const userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';

  static Map<String, String> requestHeaders(String roomId) => {
    'User-Agent': userAgent,
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'en-US,en;q=0.9',
    'Origin': origin,
    'Referer': SeventeenLiveLink.url(roomId),
  };

  static Map<String, String> mediaHeaders(String roomId) => {
    'User-Agent': userAgent,
    'Origin': origin,
    'Referer': SeventeenLiveLink.url(roomId),
  };

  final SeventeenLiveRequest _request;

  static Future<({int status, String body})> _defaultRequest(Uri uri, CancelToken? cancel) =>
      withRequestCancellation(cancel, (transport) async {
        final roomId = SeventeenLiveLink.normalizeRoomId(uri.pathSegments.isEmpty ? '' : uri.pathSegments.last);
        if (roomId == null) throw const SeventeenLiveException(SeventeenLiveFailure.identity);
        final response = await HttpClient.instance.dio.get<ResponseBody>(
          uri.toString(),
          cancelToken: transport,
          options: Options(
            responseType: ResponseType.stream,
            followRedirects: false,
            headers: requestHeaders(roomId),
            receiveTimeout: const Duration(seconds: 20),
            validateStatus: (_) => true,
          ),
        );
        final body = response.data;
        if (body == null) throw const SeventeenLiveException(SeventeenLiveFailure.schema);
        if (response.statusCode != 200) {
          await body.stream.listen((_) {}).cancel();
          return (status: response.statusCode ?? 0, body: '');
        }
        return (status: 200, body: await readBody(body.stream));
      });

  static Future<String> readBody(Stream<List<int>> stream, {Duration timeout = const Duration(seconds: 20)}) async {
    final iterator = StreamIterator(stream);
    final bytes = BytesBuilder(copy: false);
    final watch = Stopwatch()..start();
    try {
      while (true) {
        final remaining = timeout - watch.elapsed;
        if (remaining <= Duration.zero) throw TimeoutException('17LIVE response deadline');
        if (!await iterator.moveNext().timeout(remaining)) break;
        final chunk = iterator.current;
        if (bytes.length + chunk.length > responseLimit) {
          throw const SeventeenLiveException(SeventeenLiveFailure.schema);
        }
        bytes.add(chunk);
      }
      return utf8.decode(bytes.takeBytes());
    } on FormatException {
      throw const SeventeenLiveException(SeventeenLiveFailure.schema);
    } finally {
      watch.stop();
      await iterator.cancel();
    }
  }

  Future<SeventeenLiveRoom> room(String rawRoomId, {CancelToken? cancel}) async {
    final roomId = SeventeenLiveLink.normalizeRoomId(rawRoomId);
    if (roomId == null) throw const SeventeenLiveException(SeventeenLiveFailure.identity);
    if (cancel?.isCancelled == true) throw const SeventeenLiveException(SeventeenLiveFailure.cancelled);
    late final ({int status, String body}) response;
    try {
      response = await _request(Uri.parse('$apiOrigin/api/v1/lives/$roomId'), cancel);
    } catch (error) {
      if (cancel?.isCancelled == true || (error is DioException && CancelToken.isCancel(error))) {
        throw const SeventeenLiveException(SeventeenLiveFailure.cancelled);
      }
      if (error is SeventeenLiveException) rethrow;
      throw const SeventeenLiveException(SeventeenLiveFailure.transport);
    }
    final failure = switch (response.status) {
      200 => null,
      400 => SeventeenLiveFailure.schema,
      401 || 403 => SeventeenLiveFailure.access,
      404 => SeventeenLiveFailure.missing,
      420 || 429 => SeventeenLiveFailure.rateLimited,
      >= 500 => SeventeenLiveFailure.service,
      _ => SeventeenLiveFailure.transport,
    };
    if (failure != null) throw SeventeenLiveException(failure);
    if (response.body.length > responseLimit) throw const SeventeenLiveException(SeventeenLiveFailure.schema);
    try {
      return _room(roomId, _object(jsonDecode(response.body)));
    } on FormatException {
      throw const SeventeenLiveException(SeventeenLiveFailure.schema);
    }
  }

  static SeventeenLiveRoom _room(String requestedRoomId, Map<String, dynamic> data) {
    final responseRoomId = _positiveInt(data['liveStreamID']).toString();
    final user = _object(data['userInfo']);
    final ownerRoomId = _positiveInt(user['roomID']).toString();
    if (responseRoomId != requestedRoomId || ownerRoomId != requestedRoomId) {
      throw const SeventeenLiveException(SeventeenLiveFailure.identity);
    }
    final userId = _text(data['userID']);
    if (_text(user['userID']) != userId) throw const SeventeenLiveException(SeventeenLiveFailure.identity);
    final status = _integer(data['status']);
    final state = switch (status) {
      2 => SeventeenLiveState.live,
      0 => SeventeenLiveState.offline,
      _ => SeventeenLiveState.unknown,
    };
    final nickname = _firstText([user['displayName'], user['openID']]);
    final title = _optionalText(data['caption']);
    final streams = state == SeventeenLiveState.live ? _streams(data) : const <SeventeenLiveStream>[];
    return SeventeenLiveRoom(
      roomId: requestedRoomId,
      userId: userId,
      nickname: nickname,
      title: title.isEmpty ? nickname : title,
      avatar: _image(user['picture']),
      cover: _image(data['coverPhoto'] ?? data['thumbnail']),
      bio: _optionalText(user['bio']),
      followers: _optionalNonNegativeInt(user['followerCount']),
      liveViewers: state == SeventeenLiveState.live ? _optionalNonNegativeInt(data['liveViewerCount']) : null,
      sessionViewers: state == SeventeenLiveState.live ? _optionalNonNegativeInt(data['viewerCount']) : null,
      audioOnly: _integer(data['audioOnly']) == 1,
      state: state,
      streams: streams,
    );
  }

  static List<SeventeenLiveStream> _streams(Map<String, dynamic> data) {
    Object? rawProviders;
    final pull = data['pullURLsInfo'];
    if (pull is Map) rawProviders = _object(pull)['rtmpURLs'];
    rawProviders ??= data['rtmpUrls'];
    if (rawProviders == null) return const [];
    final providers = _list(rawProviders, max: 16);
    final qualities = <String, List<Uri>>{};
    final seen = <String, Set<Uri>>{};
    void add(String qualityId, Object? value) {
      if (value == null || value == '') return;
      if (value is! String) throw const SeventeenLiveException(SeventeenLiveFailure.schema);
      final uri = _mediaUri(value);
      if (uri == null || !(seen[qualityId] ??= <Uri>{}).add(uri)) return;
      (qualities[qualityId] ??= <Uri>[]).add(uri);
    }

    for (final raw in providers) {
      final provider = _object(raw);
      add('enhanced', provider['urlQualityEnhancedHD']);
      add('hd', provider['urlLowBitrateHD']);
      add('hd', provider['webUrl']);
      add('hd', provider['url']);
      add('h264', provider['url264']);
      add('standard', provider['urlLowQuality']);
      add('standard', provider['webUrlLowQuality']);
      add('standard', provider['urlHighQuality']);
    }
    const order = ['enhanced', 'hd', 'h264', 'standard'];
    return List.unmodifiable(
      order.where(qualities.containsKey).map((qualityId) {
        return SeventeenLiveStream(qualityId: qualityId, urls: List.unmodifiable(qualities[qualityId]!));
      }),
    );
  }

  static Uri? _mediaUri(String raw) {
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
    return uri;
  }

  static String _image(Object? value) {
    if (value is! String || value.isEmpty || value.length > 8192) return '';
    Uri? uri = Uri.tryParse(value);
    if (uri != null && !uri.hasScheme) {
      if (value.contains('..') || !RegExp(r'^[a-zA-Z0-9._/?=&-]+$').hasMatch(value)) return '';
      uri = Uri.https('cdn.17app.co', value.startsWith('/') ? value : '/$value');
    }
    final host = uri?.host.toLowerCase() ?? '';
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !const {'cdn.17app.co', 'assets-17app.akamaized.net'}.contains(host)) {
      return '';
    }
    return uri.replace(scheme: 'https').toString();
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map) throw const SeventeenLiveException(SeventeenLiveFailure.schema);
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static List<dynamic> _list(Object? value, {required int max}) {
    if (value is! List || value.length > max) throw const SeventeenLiveException(SeventeenLiveFailure.schema);
    return value;
  }

  static int? _integer(Object? value) => value is int ? value : int.tryParse(value?.toString() ?? '');

  static int _positiveInt(Object? value) {
    final result = _integer(value);
    if (result == null || result <= 0) throw const SeventeenLiveException(SeventeenLiveFailure.schema);
    return result;
  }

  static int? _optionalNonNegativeInt(Object? value) {
    if (value == null || value == '') return null;
    final result = _integer(value);
    if (result == null || result < 0) throw const SeventeenLiveException(SeventeenLiveFailure.schema);
    return result;
  }

  static String _text(Object? value) {
    if (value is! String || value.trim().isEmpty || value.length > 8192) {
      throw const SeventeenLiveException(SeventeenLiveFailure.schema);
    }
    return value.trim();
  }

  static String _optionalText(Object? value) {
    if (value == null || value == '') return '';
    if (value is! String || value.length > 131072) {
      throw const SeventeenLiveException(SeventeenLiveFailure.schema);
    }
    return value.trim();
  }

  static String _firstText(Iterable<Object?> values) {
    for (final value in values) {
      final text = _optionalText(value);
      if (text.isNotEmpty) return text;
    }
    throw const SeventeenLiveException(SeventeenLiveFailure.schema);
  }
}
