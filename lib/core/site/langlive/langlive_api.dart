import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/common/request_scope.dart';

import 'langlive_link.dart';

enum LangLiveFailure {
  transport,
  access,
  missing,
  rateLimited,
  service,
  api,
  schema,
  identity,
  cancelled,
  unknownState,
  mediaUnavailable,
}

class LangLiveException implements Exception {
  const LangLiveException(this.kind);
  final LangLiveFailure kind;

  @override
  String toString() => 'Lang Live ${kind.name}';
}

enum LangLiveState { live, offline, unknown }

enum LangLiveMediaKind { flv, hls }

final class LangLiveMedia {
  const LangLiveMedia({required this.kind, required this.uri});
  final LangLiveMediaKind kind;
  final Uri uri;
}

final class LangLiveRoom {
  LangLiveRoom({
    required this.roomId,
    required this.nickname,
    required this.state,
    required Iterable<LangLiveMedia> media,
  }) : media = List.unmodifiable(media);

  final String roomId;
  final String nickname;
  final LangLiveState state;
  final List<LangLiveMedia> media;
}

typedef LangLiveRequest = Future<({int status, String body})> Function(Uri uri, CancelToken cancel);

/// Bounded implementation of the public Lang Web room contract. Application
/// registration remains gated until a current production response and its
/// returned media pass the external byte-prefix probe.
class LangLiveApi {
  LangLiveApi({LangLiveRequest? request, this.deadline = const Duration(seconds: 20)})
    : _request = request ?? _defaultRequest;

  static const origin = 'https://www.lang.live';
  static const apiOrigin = 'https://api.lang.live';
  static const responseLimit = 1024 * 1024;
  static const userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';

  static Map<String, String> requestHeaders(String roomId) => {
    'User-Agent': userAgent,
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'zh-TW,zh;q=0.9,en;q=0.8',
    'Origin': origin,
    'Referer': LangLiveLink.url(roomId),
  };

  static Map<String, String> mediaHeaders(String roomId) => {
    'User-Agent': userAgent,
    'Origin': origin,
    'Referer': LangLiveLink.url(roomId),
  };

  final LangLiveRequest _request;
  final Duration deadline;

  static Future<({int status, String body})> _defaultRequest(Uri uri, CancelToken cancel) async {
    final roomId = LangLiveLink.normalizeRoomId(uri.queryParameters['room_id']);
    if (roomId == null) throw const LangLiveException(LangLiveFailure.identity);
    final response = await HttpClient.instance.dio.get<ResponseBody>(
      uri.toString(),
      cancelToken: cancel,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: false,
        headers: requestHeaders(roomId),
        receiveTimeout: const Duration(seconds: 20),
        validateStatus: (_) => true,
      ),
    );
    final body = response.data;
    if (body == null) throw const LangLiveException(LangLiveFailure.schema);
    if (response.statusCode != 200) {
      await body.stream.listen((_) {}).cancel();
      return (status: response.statusCode ?? 0, body: '');
    }
    return (status: 200, body: await readBody(body.stream));
  }

  static Future<String> readBody(Stream<List<int>> source, {Duration timeout = const Duration(seconds: 20)}) async {
    final iterator = StreamIterator(source);
    final bytes = BytesBuilder(copy: false);
    final watch = Stopwatch()..start();
    try {
      while (true) {
        final remaining = timeout - watch.elapsed;
        if (remaining <= Duration.zero) throw TimeoutException('Lang Live response deadline');
        if (!await iterator.moveNext().timeout(remaining)) break;
        if (bytes.length + iterator.current.length > responseLimit) {
          throw const LangLiveException(LangLiveFailure.schema);
        }
        bytes.add(iterator.current);
      }
      return utf8.decode(bytes.takeBytes());
    } on FormatException {
      throw const LangLiveException(LangLiveFailure.schema);
    } finally {
      watch.stop();
      await iterator.cancel();
    }
  }

  Future<T> _scope<T>(CancelToken? caller, Future<T> Function(CancelToken) work) =>
      withRequestCancellation(caller, (transport) async {
        if (transport.isCancelled) throw const LangLiveException(LangLiveFailure.cancelled);
        try {
          return await Future.any<T>([
            work(transport),
            transport.whenCancel.then<T>((_) => throw const LangLiveException(LangLiveFailure.cancelled)),
          ]).timeout(deadline);
        } on TimeoutException {
          throw const LangLiveException(LangLiveFailure.transport);
        } catch (error) {
          if (caller?.isCancelled == true) throw const LangLiveException(LangLiveFailure.cancelled);
          if (error is LangLiveException) rethrow;
          throw const LangLiveException(LangLiveFailure.transport);
        }
      });

  Future<LangLiveRoom> room(String rawRoomId, {CancelToken? cancel}) => _scope(cancel, (token) async {
    final roomId = LangLiveLink.normalizeRoomId(rawRoomId);
    if (roomId == null) throw const LangLiveException(LangLiveFailure.identity);
    final uri = Uri.parse('$apiOrigin/langweb/v1/room/liveinfo').replace(queryParameters: {'room_id': roomId});
    final response = await _request(uri, token);
    final failure = switch (response.status) {
      200 => null,
      401 || 403 => LangLiveFailure.access,
      404 => LangLiveFailure.missing,
      429 => LangLiveFailure.rateLimited,
      >= 500 => LangLiveFailure.service,
      _ => LangLiveFailure.transport,
    };
    if (failure != null) throw LangLiveException(failure);
    if (response.body.length > responseLimit || utf8.encode(response.body).length > responseLimit) {
      throw const LangLiveException(LangLiveFailure.schema);
    }
    try {
      return parseRoom(_object(jsonDecode(response.body)), requestedRoomId: roomId);
    } on FormatException {
      throw const LangLiveException(LangLiveFailure.schema);
    }
  });

  static LangLiveRoom parseRoom(Map<String, dynamic> json, {required String requestedRoomId}) {
    final roomId = LangLiveLink.normalizeRoomId(requestedRoomId);
    if (roomId == null) throw const LangLiveException(LangLiveFailure.identity);
    final code = _integer(json['ret_code']);
    if (code == null) throw const LangLiveException(LangLiveFailure.schema);
    if (code != 0) throw const LangLiveException(LangLiveFailure.api);
    final data = _object(json['data']);
    final info = _object(data['live_info']);
    final responseRoomId = LangLiveLink.normalizeRoomId(info['pretty_id']);
    if (responseRoomId == null || responseRoomId != roomId) {
      throw const LangLiveException(LangLiveFailure.identity);
    }
    final nickname = _text(info['nickname']);
    final status = _integer(info['live_status']);
    if (status == null) throw const LangLiveException(LangLiveFailure.schema);
    final state = switch (status) {
      1 => LangLiveState.live,
      0 => LangLiveState.offline,
      _ => LangLiveState.unknown,
    };
    final media = <LangLiveMedia>[];
    if (state == LangLiveState.live) {
      final seen = <Uri>{};
      void add(Object? value, LangLiveMediaKind kind) {
        if (value == null || value == '') return;
        if (value is! String) throw const LangLiveException(LangLiveFailure.schema);
        final uri = _mediaUri(value, kind);
        if (uri == null || !seen.add(uri)) return;
        media.add(LangLiveMedia(kind: kind, uri: uri));
      }

      add(info['liveurl'], LangLiveMediaKind.flv);
      add(info['liveurl_hls'], LangLiveMediaKind.hls);
    }
    return LangLiveRoom(roomId: roomId, nickname: nickname, state: state, media: media);
  }

  static Uri? _mediaUri(String raw, LangLiveMediaKind kind) {
    if (raw.isEmpty || raw.length > 65536 || RegExp(r'[\s\x00-\x1f]').hasMatch(raw)) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.host.isEmpty) {
      return null;
    }
    final host = uri.host.toLowerCase();
    if (host != 'lv-play.com' && !host.endsWith('.lv-play.com')) return null;
    final path = uri.path.toLowerCase();
    final matchesKind = switch (kind) {
      LangLiveMediaKind.flv => path.endsWith('.flv'),
      LangLiveMediaKind.hls => path.endsWith('.m3u8'),
    };
    return matchesKind ? uri : null;
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map) throw const LangLiveException(LangLiveFailure.schema);
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static int? _integer(Object? value) => switch (value) {
    int number => number,
    String text when RegExp(r'^-?[0-9]{1,10}$').hasMatch(text) => int.tryParse(text),
    _ => null,
  };

  static String _text(Object? value) {
    if (value is! String || value.trim().isEmpty || value.length > 8192) {
      throw const LangLiveException(LangLiveFailure.schema);
    }
    return value.trim();
  }
}
