import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/common/request_scope.dart';

import 'tiktok_link.dart';

enum TikTokFailure {
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

class TikTokException implements Exception {
  const TikTokException(this.kind);

  final TikTokFailure kind;

  @override
  String toString() => 'TikTok ${kind.name}';
}

enum TikTokState { live, offline, restricted, unknown }

class TikTokStream {
  TikTokStream({
    required this.id,
    required this.qualityId,
    required this.protocol,
    required this.codec,
    required this.resolution,
    required this.bitrate,
    required Iterable<Uri> urls,
  }) : urls = List.unmodifiable(urls);

  final String id;
  final String qualityId;
  final String protocol;
  final String codec;
  final String resolution;
  final int? bitrate;
  final List<Uri> urls;
}

class TikTokRoom {
  TikTokRoom({
    required this.username,
    required this.userId,
    required this.secUid,
    required this.roomId,
    required this.streamId,
    required this.nickname,
    required this.title,
    required this.avatar,
    required this.cover,
    required this.bio,
    required this.followers,
    required this.currentViewers,
    required this.totalViewers,
    required this.verified,
    required this.state,
    required Iterable<TikTokStream> streams,
  }) : streams = List.unmodifiable(streams);

  final String username;
  final String userId;
  final String secUid;
  final String roomId;
  final String streamId;
  final String nickname;
  final String title;
  final String avatar;
  final String cover;
  final String bio;
  final int? followers;
  final int? currentViewers;
  final int? totalViewers;
  final bool verified;
  final TikTokState state;
  final List<TikTokStream> streams;
}

typedef TikTokRequest = Future<({int status, String body})> Function({
  required Uri uri,
  required Map<String, String> headers,
  CancelToken? cancel,
});

class TikTokApi {
  TikTokApi({TikTokRequest? request}) : _request = request ?? _defaultRequest;

  static const origin = 'https://www.tiktok.com';
  static const webcastOrigin = 'https://webcast.tiktok.com';
  static const responseLimit = 12 * 1024 * 1024;
  static const userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';

  final TikTokRequest _request;

  static Map<String, String> requestHeaders({String? username}) => {
    'User-Agent': userAgent,
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'en-US,en;q=0.9',
    'Origin': origin,
    'Referer': username == null ? '$origin/live' : TikTokLink.url(username),
  };

  static Map<String, String> mediaHeaders(String username) => {
    'User-Agent': userAgent,
    'Origin': origin,
    'Referer': TikTokLink.url(username),
  };

  static Future<({int status, String body})> _defaultRequest({
    required Uri uri,
    required Map<String, String> headers,
    CancelToken? cancel,
  }) => withRequestCancellation(cancel, (transport) async {
    final response = await HttpClient.instance.dio.get<ResponseBody>(
      uri.toString(),
      cancelToken: transport,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: false,
        headers: headers,
        receiveTimeout: const Duration(seconds: 20),
        validateStatus: (_) => true,
      ),
    );
    final body = response.data;
    if (body == null) throw const TikTokException(TikTokFailure.schema);
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
        if (remaining <= Duration.zero) throw TimeoutException('TikTok response deadline');
        if (!await iterator.moveNext().timeout(remaining)) break;
        final chunk = iterator.current;
        if (bytes.length + chunk.length > responseLimit) {
          throw const TikTokException(TikTokFailure.schema);
        }
        bytes.add(chunk);
      }
      return utf8.decode(bytes.takeBytes());
    } on FormatException {
      throw const TikTokException(TikTokFailure.schema);
    } finally {
      watch.stop();
      await iterator.cancel();
    }
  }

  Future<Map<String, dynamic>> _json(Uri uri, {String? username, CancelToken? cancel}) async {
    if (cancel?.isCancelled == true) throw const TikTokException(TikTokFailure.cancelled);
    late final ({int status, String body}) response;
    try {
      response = await _request(
        uri: uri,
        headers: requestHeaders(username: username),
        cancel: cancel,
      );
    } catch (error) {
      if (cancel?.isCancelled == true || (error is DioException && CancelToken.isCancel(error))) {
        throw const TikTokException(TikTokFailure.cancelled);
      }
      if (error is TikTokException) rethrow;
      throw const TikTokException(TikTokFailure.transport);
    }
    if (cancel?.isCancelled == true) throw const TikTokException(TikTokFailure.cancelled);
    final failure = switch (response.status) {
      200 => null,
      400 => TikTokFailure.schema,
      401 || 403 => TikTokFailure.access,
      404 => TikTokFailure.missing,
      420 || 429 => TikTokFailure.rateLimited,
      >= 500 => TikTokFailure.service,
      _ => TikTokFailure.transport,
    };
    if (failure != null) throw TikTokException(failure);
    if (response.body.isEmpty) throw const TikTokException(TikTokFailure.access);
    if (response.body.length > responseLimit) throw const TikTokException(TikTokFailure.schema);
    try {
      return _object(jsonDecode(response.body));
    } on FormatException {
      throw const TikTokException(TikTokFailure.schema);
    }
  }

  Future<String> resolveReference(TikTokLink reference, {CancelToken? cancel}) async {
    switch (reference.kind) {
      case TikTokLinkKind.username:
        return _username(reference.id);
      case TikTokLinkKind.roomId:
        return _usernameFromRoomId(reference.id, cancel: cancel);
    }
  }

  Future<TikTokRoom> room(String rawUsername, {required bool includeMedia, CancelToken? cancel}) async {
    final username = TikTokLink.normalizeUsername(rawUsername);
    if (username == null) throw const TikTokException(TikTokFailure.identity);
    final root = await _json(
      Uri.parse('$origin/api-live/user/room/')
          .replace(queryParameters: {'aid': '1988', 'sourceType': '54', 'staleTime': '600000', 'uniqueId': username}),
      username: username,
      cancel: cancel,
    );
    final statusCode = _integer(root['statusCode']);
    if (statusCode != 0) {
      final message = _optionalText(root['message']).toLowerCase();
      throw TikTokException(
        statusCode == 19881007 || message.contains('not exist') || message.contains('not_found')
            ? TikTokFailure.missing
            : TikTokFailure.service,
      );
    }
    final data = _object(root['data']);
    final user = _object(data['user']);
    final stats = _optionalObject(data['stats']);
    final live = _object(data['liveRoom']);
    final actualUsername = _username(user['uniqueId']);
    if (actualUsername != username) throw const TikTokException(TikTokFailure.identity);

    final liveStatus = _integer(live['status'] ?? user['status']);
    final paidValue = live['paidEvent'];
    final paid = paidValue == null || (paidValue is List && paidValue.isEmpty)
        ? <String, dynamic>{}
        : _object(paidValue);
    final restricted =
        _optionalBool(user['secret']) == true ||
        _integer(live['liveSubOnly']) == 1 ||
        (_integer(paid['paid_type']) ?? 0) > 0;
    final state = restricted
        ? TikTokState.restricted
        : liveStatus == 2
        ? TikTokState.live
        : liveStatus == 4
        ? TikTokState.offline
        : TikTokState.unknown;
    final roomStats = _optionalObject(live['liveRoomStats']);
    final nickname = _text(user['nickname']);
    final title = _optionalText(live['title']);
    return TikTokRoom(
      username: username,
      userId: _longId(user['id']),
      secUid: _optionalText(user['secUid']),
      roomId: _optionalLongId(user['roomId']),
      streamId: _optionalLongId(live['streamId']),
      nickname: nickname,
      title: title.isEmpty ? nickname : title,
      avatar: _image(user['avatarLarger'] ?? user['avatarMedium'] ?? user['avatarThumb']),
      cover: _image(live['coverUrl'] ?? live['squareCoverImg']),
      bio: _optionalText(user['signature']),
      followers: _optionalNonNegativeInt(stats['followerCount']),
      currentViewers: state == TikTokState.live ? _optionalNonNegativeInt(roomStats['userCount']) : null,
      totalViewers: state == TikTokState.live ? _optionalNonNegativeInt(roomStats['enterCount']) : null,
      verified: _optionalBool(user['verified']) ?? false,
      state: state,
      streams: state == TikTokState.live && includeMedia ? _streams(live) : const [],
    );
  }

  Future<String> _usernameFromRoomId(String rawRoomId, {CancelToken? cancel}) async {
    final roomId = TikTokLink.normalizeRoomId(rawRoomId);
    if (roomId == null) throw const TikTokException(TikTokFailure.identity);
    final root = await _json(
      Uri.parse('$webcastOrigin/webcast/room/info/').replace(queryParameters: {'aid': '1988', 'room_id': roomId}),
      cancel: cancel,
    );
    if (_integer(root['status_code']) != 0) throw const TikTokException(TikTokFailure.missing);
    final data = _object(root['data']);
    if (_longId(data['id']) != roomId) throw const TikTokException(TikTokFailure.identity);
    return _username(_object(data['owner'])['display_id']);
  }

  static List<TikTokStream> _streams(Map<String, dynamic> room) {
    final builders = <String, _TikTokStreamBuilder>{};
    void readContainer(Object? value, String fallbackCodec) {
      if (value == null) return;
      final container = _object(value);
      final pull = _object(container['pull_data']);
      final raw = _optionalText(pull['stream_data']);
      if (raw.isEmpty || raw.length > 4 * 1024 * 1024) return;
      final decoded = _object(_decode(raw));
      final qualities = _object(decoded['data']);
      if (qualities.length > 32) throw const TikTokException(TikTokFailure.schema);
      for (final entry in qualities.entries) {
        final qualityId = _qualityId(entry.key);
        if (qualityId == 'ao') continue;
        final main = _object(_object(entry.value)['main']);
        final sdkRaw = _optionalText(main['sdk_params']);
        final sdk = sdkRaw.isEmpty ? <String, dynamic>{} : _object(_decode(sdkRaw));
        final codec = _codec(sdk['VCodec'] ?? sdk['v_codec'], fallbackCodec);
        final resolution = _resolution(sdk['resolution']);
        final bitrate = _optionalNonNegativeInt(sdk['vbitrate']);
        for (final protocol in const ['flv', 'hls']) {
          final rawUrl = _optionalText(main[protocol]);
          if (rawUrl.isEmpty) continue;
          final uri = _mediaUri(rawUrl);
          final id = '$codec:$qualityId:$protocol';
          final builder = builders.putIfAbsent(
            id,
            () => _TikTokStreamBuilder(
              id: id,
              qualityId: qualityId,
              protocol: protocol,
              codec: codec,
              resolution: resolution,
              bitrate: bitrate,
            ),
          );
          if (builder.resolution.isEmpty && resolution.isNotEmpty) builder.resolution = resolution;
          builder.bitrate ??= bitrate;
          if (!builder.urls.contains(uri)) builder.urls.add(uri);
        }
      }
    }

    readContainer(room['streamData'], 'h264');
    readContainer(room['hevcStreamData'], 'h265');
    final streams = builders.values
        .where((value) => value.urls.isNotEmpty)
        .map(
          (value) => TikTokStream(
            id: value.id,
            qualityId: value.qualityId,
            protocol: value.protocol,
            codec: value.codec,
            resolution: value.resolution,
            bitrate: value.bitrate,
            urls: value.urls,
          ),
        )
        .toList(growable: false);
    streams.sort((left, right) {
      final rank = qualitySort(right).compareTo(qualitySort(left));
      return rank != 0 ? rank : left.id.compareTo(right.id);
    });
    return List.unmodifiable(streams);
  }

  static int qualitySort(TikTokStream stream) {
    final quality = switch (stream.qualityId) {
      'origin' => 10000,
      'uhd_60' => 9000,
      'hd_60' => 8000,
      'uhd' => 7000,
      'hd' => 6000,
      'sd' => 5000,
      'ld' => 4000,
      'auto' => 3000,
      _ => 1000,
    };
    final codec = stream.codec == 'h264' ? 100 : 0;
    final protocol = stream.protocol == 'flv' ? 20 : 10;
    return quality + codec + protocol;
  }

  static Object? _decode(String value) {
    try {
      return jsonDecode(value);
    } on FormatException {
      throw const TikTokException(TikTokFailure.schema);
    }
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map) throw const TikTokException(TikTokFailure.schema);
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static Map<String, dynamic> _optionalObject(Object? value) {
    if (value == null) return <String, dynamic>{};
    return _object(value);
  }

  static int? _integer(Object? value) {
    if (value is int) return value;
    if (value is num && value.isFinite && value == value.roundToDouble()) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static int? _optionalNonNegativeInt(Object? value) {
    if (value == null || value == '') return null;
    final result = _integer(value);
    if (result == null || result < 0) throw const TikTokException(TikTokFailure.schema);
    return result;
  }

  static bool? _optionalBool(Object? value) {
    if (value == null) return null;
    if (value is! bool) throw const TikTokException(TikTokFailure.schema);
    return value;
  }

  static String _username(Object? value) {
    if (value is! String) throw const TikTokException(TikTokFailure.identity);
    final username = TikTokLink.normalizeUsername(value);
    if (username == null) throw const TikTokException(TikTokFailure.identity);
    return username;
  }

  static String _longId(Object? value) {
    final raw = value?.toString().trim() ?? '';
    if (!RegExp(r'^[1-9][0-9]{14,24}$').hasMatch(raw)) throw const TikTokException(TikTokFailure.schema);
    return raw;
  }

  static String _optionalLongId(Object? value) {
    if (value == null || value == '') return '';
    return _longId(value);
  }

  static String _text(Object? value) {
    if (value is! String || value.trim().isEmpty || value.length > 8192) {
      throw const TikTokException(TikTokFailure.schema);
    }
    return value.trim();
  }

  static String _optionalText(Object? value) {
    if (value == null || value == '') return '';
    if (value is! String || value.length > 4 * 1024 * 1024) {
      throw const TikTokException(TikTokFailure.schema);
    }
    return value.trim();
  }

  static String _qualityId(String raw) {
    final value = raw.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_]{1,24}$').hasMatch(value)) throw const TikTokException(TikTokFailure.schema);
    return value;
  }

  static String _codec(Object? value, String fallback) {
    final raw = _optionalText(value).toLowerCase();
    final codec = switch (raw) {
      '' => fallback,
      'avc' => 'h264',
      'hevc' => 'h265',
      'h264' || 'h265' => raw,
      _ => throw const TikTokException(TikTokFailure.schema),
    };
    return codec;
  }

  static String _resolution(Object? value) {
    final raw = _optionalText(value).toLowerCase();
    if (raw.isEmpty) return '';
    return RegExp(r'^(?:[1-9][0-9]{1,4}x[1-9][0-9]{1,4}|[1-9][0-9]{2,4}p)$').hasMatch(raw) ? raw : '';
  }

  static String _image(Object? value) {
    if (value is! String || value.length > 16384) return '';
    final uri = Uri.tryParse(value);
    final host = uri?.host.toLowerCase() ?? '';
    if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty || uri.hasFragment || !_trustedHost(host)) {
      return '';
    }
    return value;
  }

  static Uri _mediaUri(String raw) {
    if (raw.length > 65536 || raw.contains(RegExp(r'[\s\x00-\x1f]'))) {
      throw const TikTokException(TikTokFailure.schema);
    }
    final uri = Uri.tryParse(raw);
    final host = uri?.host.toLowerCase() ?? '';
    if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty || uri.hasFragment || !_trustedHost(host)) {
      throw const TikTokException(TikTokFailure.schema);
    }
    return uri;
  }

  static bool _trustedHost(String host) =>
      host == 'tiktokcdn.com' ||
      host.endsWith('.tiktokcdn.com') ||
      host == 'tiktokv.com' ||
      host.endsWith('.tiktokv.com') ||
      host == 'byteoversea.com' ||
      host.endsWith('.byteoversea.com');
}

class _TikTokStreamBuilder {
  _TikTokStreamBuilder({
    required this.id,
    required this.qualityId,
    required this.protocol,
    required this.codec,
    required this.resolution,
    required this.bitrate,
  });

  final String id;
  final String qualityId;
  final String protocol;
  final String codec;
  String resolution;
  int? bitrate;
  final List<Uri> urls = [];
}
