import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/common/request_scope.dart';

import 'jd_live_link.dart';

enum JdLiveFailure { transport, access, missing, rateLimited, service, schema, identity, cancelled, mediaUnavailable }

final class JdLiveException implements Exception {
  const JdLiveException(this.kind);

  final JdLiveFailure kind;

  @override
  String toString() => 'JD Live ${kind.name}';
}

enum JdLiveState { live, preview, offline, replay, paused, restricted, unknown }

final class JdLiveRoom {
  const JdLiveRoom({
    required this.liveId,
    required this.authorId,
    required this.nick,
    required this.title,
    required this.avatar,
    required this.cover,
    required this.totalViews,
    required this.state,
    required this.hls,
    required this.flv,
  });

  final String liveId;
  final String authorId;
  final String nick;
  final String title;
  final String avatar;
  final String cover;
  final int? totalViews;
  final JdLiveState state;
  final Uri? hls;
  final Uri? flv;

  JdLiveRoom enrich(JdLiveRoom known) => JdLiveRoom(
    liveId: liveId,
    authorId: authorId.isEmpty ? known.authorId : authorId,
    nick: nick == 'JD Live' ? known.nick : nick,
    title: title == 'JD Live' ? known.title : title,
    avatar: avatar.isEmpty ? known.avatar : avatar,
    cover: cover.isEmpty ? known.cover : cover,
    totalViews: totalViews ?? known.totalViews,
    state: state,
    hls: hls,
    flv: flv,
  );
}

final class JdLivePage {
  JdLivePage({required Iterable<JdLiveRoom> rooms, required this.nextCount, required this.hasMore})
    : rooms = List.unmodifiable(rooms);

  final List<JdLiveRoom> rooms;
  final int nextCount;
  final bool hasMore;
}

typedef JdLiveRequest = Future<({int status, String body})> Function(
  Uri uri,
  Map<String, String> headers,
  CancelToken cancel,
);

class JdLiveApi {
  JdLiveApi({JdLiveRequest? request, this.deadline = const Duration(seconds: 20)})
    : _request = request ?? _defaultRequest;

  static const String apiOrigin = 'https://api.m.jd.com';
  static const String webOrigin = 'https://lives.jd.com';
  static const int responseLimit = 4 * 1024 * 1024;
  static const String userAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148';
  static const Map<String, String> apiHeaders = {
    'User-Agent': userAgent,
    'Accept': 'application/json, text/plain, */*',
    'Origin': webOrigin,
    'Referer': '$webOrigin/',
  };

  static Map<String, String> mediaHeaders(String liveId) => {
    'User-Agent': userAgent,
    'Origin': webOrigin,
    'Referer': JdLiveLink.watchUrl(liveId),
  };

  final JdLiveRequest _request;
  final Duration deadline;

  static Future<({int status, String body})> _defaultRequest(
    Uri uri,
    Map<String, String> headers,
    CancelToken cancel,
  ) async {
    final response = await HttpClient.instance.dio.get<ResponseBody>(
      uri.toString(),
      cancelToken: cancel,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: false,
        headers: headers,
        receiveTimeout: const Duration(seconds: 15),
        validateStatus: (_) => true,
      ),
    );
    final body = response.data;
    if (body == null) throw const JdLiveException(JdLiveFailure.schema);
    return (status: response.statusCode ?? 0, body: await _readBody(body.stream));
  }

  static Future<String> _readBody(Stream<List<int>> source) async {
    final iterator = StreamIterator(source);
    final bytes = BytesBuilder(copy: false);
    try {
      while (await iterator.moveNext()) {
        if (bytes.length + iterator.current.length > responseLimit) {
          throw const JdLiveException(JdLiveFailure.schema);
        }
        bytes.add(iterator.current);
      }
      return utf8.decode(bytes.takeBytes());
    } on FormatException {
      throw const JdLiveException(JdLiveFailure.schema);
    } finally {
      await iterator.cancel();
    }
  }

  Future<T> _scope<T>(CancelToken? caller, Future<T> Function(CancelToken) work) =>
      withRequestCancellation(caller, (transport) async {
        if (transport.isCancelled) throw const JdLiveException(JdLiveFailure.cancelled);
        try {
          return await Future.any<T>([
            work(transport),
            transport.whenCancel.then<T>((_) => throw const JdLiveException(JdLiveFailure.cancelled)),
          ]).timeout(deadline);
        } on TimeoutException {
          throw const JdLiveException(JdLiveFailure.transport);
        } catch (error) {
          if (caller?.isCancelled == true || transport.isCancelled) {
            throw const JdLiveException(JdLiveFailure.cancelled);
          }
          if (error is JdLiveException) rethrow;
          throw const JdLiveException(JdLiveFailure.transport);
        }
      });

  Future<String> _get(Uri uri, Map<String, String> headers, CancelToken cancel) async {
    if (uri.scheme != 'https' || uri.userInfo.isNotEmpty || uri.hasFragment) {
      throw const JdLiveException(JdLiveFailure.identity);
    }
    final response = await _request(uri, headers, cancel);
    _throwStatus(response.status);
    if (response.body.length > responseLimit) throw const JdLiveException(JdLiveFailure.schema);
    return response.body;
  }

  Future<JdLivePage> directory({
    required int page,
    required int currentCount,
    required int timestamp,
    CancelToken? cancel,
  }) => _scope(cancel, (token) async {
    if (page < 1 || page > 10000 || currentCount < 0 || timestamp < 1) {
      throw const JdLiveException(JdLiveFailure.schema);
    }
    final body = jsonEncode({'tabId': 1, 'currentCount': '$currentCount', 'page': page, 'timestamp': timestamp});
    final uri = Uri.parse('$apiOrigin/api').replace(
      queryParameters: {
        'appid': 'h5-live',
        'functionId': 'liveListWithTabToM',
        'v': '${DateTime.now().millisecondsSinceEpoch}',
        'body': body,
      },
    );
    return parseDirectoryJson(_decode(await _get(uri, apiHeaders, token)), page: page);
  });

  Future<JdLiveRoom> room(String rawLiveId, {bool includeMedia = false, CancelToken? cancel}) =>
      _scope(cancel, (token) async {
        final liveId = JdLiveLink.parseLiveId(rawLiveId);
        if (liveId == null) throw const JdLiveException(JdLiveFailure.identity);
        final uri = Uri.parse('$apiOrigin/api').replace(
          queryParameters: {
            'appid': 'h5-live',
            'functionId': 'getImmediatePlayToM',
            't': '${DateTime.now().millisecondsSinceEpoch}',
            'body': jsonEncode({'liveId': liveId}),
          },
        );
        final room = parseRoomJson(_decode(await _get(uri, apiHeaders, token)), expectedLiveId: liveId);
        if (includeMedia && room.state == JdLiveState.live) {
          final hls = room.hls;
          if (hls == null) throw const JdLiveException(JdLiveFailure.mediaUnavailable);
          validatePlaylist(await _get(hls, mediaHeaders(liveId), token), expected: hls);
        }
        return room;
      });

  static JdLivePage parseDirectoryJson(Object? value, {required int page}) {
    if (page < 1) throw const JdLiveException(JdLiveFailure.schema);
    final data = _responseData(value);
    final list = _list(data['list']);
    final seen = <String>{};
    final rooms = <JdLiveRoom>[];
    for (final value in list) {
      final card = _object(value);
      if (_int(card['templateType']) != 1) continue;
      final item = _object(card['data']);
      final liveId = _id(item['liveId'] ?? item['id']);
      if (liveId == null || _id(item['id']) != liveId || !seen.add(liveId)) continue;
      final status = _int(item['status']);
      rooms.add(
        JdLiveRoom(
          liveId: liveId,
          authorId: _id(item['authorId']) ?? '',
          nick: _optionalText(item['userName'], fallback: 'JD Live'),
          title: _optionalText(item['title'], fallback: 'JD Live'),
          avatar: _image(item['userPic']),
          cover: _image(item['indexImage']),
          totalViews: _nonNegativeInt(item['pv']),
          state: _state(status, secret: 0),
          hls: null,
          flv: null,
        ),
      );
    }
    final nextCount = _nonNegativeInt(data['currentCount']);
    if (nextCount == null) throw const JdLiveException(JdLiveFailure.schema);
    return JdLivePage(rooms: rooms, nextCount: nextCount, hasMore: rooms.length >= 30);
  }

  static JdLiveRoom parseRoomJson(Object? value, {required String expectedLiveId}) {
    final liveId = JdLiveLink.parseLiveId(expectedLiveId);
    if (liveId == null) throw const JdLiveException(JdLiveFailure.identity);
    final data = _responseData(value);
    if (_id(data['liveId']) != liveId) throw const JdLiveException(JdLiveFailure.identity);
    final state = _state(_int(data['status']), secret: _int(data['secret']) ?? 0);
    final hls = _mediaUri(data['h5VideoUrl'], extension: '.m3u8');
    final flv = _mediaUri(data['videoUrl'], extension: '.flv');
    if (state == JdLiveState.live && (hls == null || flv == null || _streamKey(hls) != _streamKey(flv))) {
      throw const JdLiveException(JdLiveFailure.schema);
    }
    return JdLiveRoom(
      liveId: liveId,
      authorId: '',
      nick: 'JD Live',
      title: 'JD Live',
      avatar: '',
      cover: _image(data['blurredImg']),
      totalViews: null,
      state: state,
      hls: hls,
      flv: flv,
    );
  }

  static void validatePlaylist(String source, {required Uri expected}) {
    if (source.length > 1024 * 1024 || !source.trimLeft().startsWith('#EXTM3U')) {
      throw const JdLiveException(JdLiveFailure.schema);
    }
    final stem = _streamKey(expected);
    var mediaReferences = 0;
    for (final rawLine in const LineSplitter().convert(source)) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#')) {
        for (final match in RegExp(r'URI="([^"]+)"').allMatches(line)) {
          if (!_validChild(expected, match.group(1)!, stem)) {
            throw const JdLiveException(JdLiveFailure.schema);
          }
          mediaReferences++;
        }
        continue;
      }
      if (!_validChild(expected, line, stem)) throw const JdLiveException(JdLiveFailure.schema);
      mediaReferences++;
      if (mediaReferences > 1000) throw const JdLiveException(JdLiveFailure.schema);
    }
    if (mediaReferences < 1) throw const JdLiveException(JdLiveFailure.schema);
  }

  static Object? _decode(String source) {
    try {
      return jsonDecode(source);
    } on FormatException {
      throw const JdLiveException(JdLiveFailure.schema);
    }
  }

  static Map<String, dynamic> _responseData(Object? value) {
    final root = _object(value);
    if (_text(root['code']) != '0') throw const JdLiveException(JdLiveFailure.service);
    if (_text(root['subCode']) != '0') throw const JdLiveException(JdLiveFailure.missing);
    return _object(root['data']);
  }

  static JdLiveState _state(int? status, {required int secret}) {
    if (secret == 1) return JdLiveState.restricted;
    return switch (status) {
      1 => JdLiveState.live,
      0 => JdLiveState.preview,
      2 => JdLiveState.offline,
      3 => JdLiveState.replay,
      10 || 11 => JdLiveState.paused,
      _ => JdLiveState.unknown,
    };
  }

  static Uri? _mediaUri(Object? value, {required String extension}) {
    final raw = _optionalText(value);
    if (raw.isEmpty || raw.length > 8192 || RegExp(r'[\s\x00-\x1f]').hasMatch(raw)) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !_hostIs(uri.host, 'jdcloud.com') ||
        (uri.hasPort && uri.port != 443) ||
        !uri.path.startsWith('/live/') ||
        !uri.path.toLowerCase().endsWith(extension)) {
      return null;
    }
    return uri;
  }

  static bool _validChild(Uri expected, String raw, String stem) {
    final child = expected.resolve(raw);
    return child.scheme == 'https' &&
        child.userInfo.isEmpty &&
        !child.hasFragment &&
        child.host.toLowerCase() == expected.host.toLowerCase() &&
        (!child.hasPort || child.port == 443) &&
        child.path.startsWith('/live/') &&
        child.pathSegments.isNotEmpty &&
        child.pathSegments.last.startsWith(stem);
  }

  static String _streamKey(Uri uri) {
    final name = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    return name.replaceFirst(RegExp(r'\.(?:m3u8|flv)$', caseSensitive: false), '');
  }

  static String _image(Object? value) {
    final raw = _optionalText(value);
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !_hostIs(uri.host, '360buyimg.com')) {
      return '';
    }
    return uri.toString();
  }

  static bool _hostIs(String host, String root) {
    final value = host.toLowerCase();
    return value == root || value.endsWith('.$root');
  }

  static String? _id(Object? value) {
    final result = switch (value) {
      int number => '$number',
      String text => text.trim(),
      _ => '',
    };
    return RegExp(r'^[1-9]\d{4,17}$').hasMatch(result) ? result : null;
  }

  static int? _int(Object? value) => switch (value) {
    int number => number,
    num number when number.isFinite && number == number.toInt() => number.toInt(),
    String text => int.tryParse(text.trim()),
    _ => null,
  };

  static int? _nonNegativeInt(Object? value) {
    final result = _int(value);
    return result != null && result >= 0 ? result : null;
  }

  static String _text(Object? value) => value is String ? value.trim() : value?.toString().trim() ?? '';

  static String _optionalText(Object? value, {String fallback = ''}) {
    if (value == null) return fallback;
    if (value is! String || value.length > 65536) throw const JdLiveException(JdLiveFailure.schema);
    final result = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    return result.isEmpty ? fallback : result;
  }

  static List<dynamic> _list(Object? value) {
    if (value is! List || value.length > 1000) throw const JdLiveException(JdLiveFailure.schema);
    return value;
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map) throw const JdLiveException(JdLiveFailure.schema);
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static void _throwStatus(int status) {
    final failure = switch (status) {
      200 => null,
      400 || 422 => JdLiveFailure.schema,
      401 || 403 => JdLiveFailure.access,
      404 => JdLiveFailure.missing,
      429 => JdLiveFailure.rateLimited,
      >= 500 => JdLiveFailure.service,
      _ => JdLiveFailure.transport,
    };
    if (failure != null) throw JdLiveException(failure);
  }
}
