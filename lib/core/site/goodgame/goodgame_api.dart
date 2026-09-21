import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/common/request_scope.dart';

import 'goodgame_link.dart';

enum GoodGameFailure { transport, access, missing, rateLimited, service, schema, identity, cancelled, mediaUnavailable }

final class GoodGameException implements Exception {
  const GoodGameException(this.kind);

  final GoodGameFailure kind;

  @override
  String toString() => 'GoodGame ${kind.name}';
}

enum GoodGameState { live, offline, banned }

final class GoodGameQuality {
  const GoodGameQuality({required this.id, required this.label, required this.sort, required this.url});

  final String id;
  final String label;
  final int sort;
  final Uri url;
}

final class GoodGameRoom {
  GoodGameRoom({
    required this.streamId,
    required this.channel,
    required this.channelName,
    required this.title,
    required this.avatar,
    required this.cover,
    required this.category,
    required this.viewers,
    required this.followers,
    required this.state,
    required this.adult,
    required Iterable<GoodGameQuality> qualities,
  }) : qualities = List.unmodifiable(qualities);

  final int streamId;
  final String channel;
  final String channelName;
  final String title;
  final String avatar;
  final String cover;
  final String category;
  final int? viewers;
  final int? followers;
  final GoodGameState state;
  final bool adult;
  final List<GoodGameQuality> qualities;
}

final class GoodGamePage {
  GoodGamePage({required Iterable<GoodGameRoom> items, required this.hasMore}) : items = List.unmodifiable(items);

  final List<GoodGameRoom> items;
  final bool hasMore;
}

typedef GoodGameRequest = Future<({int status, String body})> Function(
  Uri uri,
  Map<String, String> headers,
  CancelToken cancel,
);

final class GoodGameApi {
  GoodGameApi({GoodGameRequest? request, this.deadline = const Duration(seconds: 25)})
    : _request = request ?? _defaultRequest;

  static const String origin = 'https://goodgame.ru';
  static const int responseLimit = 4 * 1024 * 1024;
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';
  static const Map<String, String> headers = {
    'User-Agent': userAgent,
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'en-US,en;q=0.9',
    'Referer': '$origin/',
  };

  static Map<String, String> mediaHeaders(String channel) => {
    'User-Agent': userAgent,
    'Origin': origin,
    'Referer': GoodGameLink.channelUrl(channel),
  };

  final GoodGameRequest _request;
  final Duration deadline;

  static Future<({int status, String body})> _defaultRequest(
    Uri uri,
    Map<String, String> requestHeaders,
    CancelToken cancel,
  ) async {
    final response = await HttpClient.instance.dio.get<ResponseBody>(
      uri.toString(),
      cancelToken: cancel,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: false,
        headers: requestHeaders,
        receiveTimeout: const Duration(seconds: 20),
        validateStatus: (_) => true,
      ),
    );
    final body = response.data;
    if (body == null) throw const GoodGameException(GoodGameFailure.schema);
    return (status: response.statusCode ?? 0, body: await _readBody(body.stream));
  }

  static Future<String> _readBody(Stream<List<int>> source) async {
    final iterator = StreamIterator(source);
    final bytes = BytesBuilder(copy: false);
    try {
      while (await iterator.moveNext()) {
        if (bytes.length + iterator.current.length > responseLimit) {
          throw const GoodGameException(GoodGameFailure.schema);
        }
        bytes.add(iterator.current);
      }
      return utf8.decode(bytes.takeBytes());
    } on FormatException {
      throw const GoodGameException(GoodGameFailure.schema);
    } finally {
      await iterator.cancel();
    }
  }

  Future<T> _scope<T>(CancelToken? caller, Future<T> Function(CancelToken) work) =>
      withRequestCancellation(caller, (transport) async {
        if (transport.isCancelled) throw const GoodGameException(GoodGameFailure.cancelled);
        try {
          return await Future.any<T>([
            work(transport),
            transport.whenCancel.then<T>((_) => throw const GoodGameException(GoodGameFailure.cancelled)),
          ]).timeout(deadline);
        } on TimeoutException {
          throw const GoodGameException(GoodGameFailure.transport);
        } catch (error) {
          if (caller?.isCancelled == true || transport.isCancelled) {
            throw const GoodGameException(GoodGameFailure.cancelled);
          }
          if (error is GoodGameException) rethrow;
          throw const GoodGameException(GoodGameFailure.transport);
        }
      });

  Future<Map<String, dynamic>> _get(String path, Map<String, String> query, CancelToken token) async {
    final uri = Uri.parse('$origin$path').replace(queryParameters: query.isEmpty ? null : query);
    final response = await _request(uri, headers, token);
    _throwStatus(response.status);
    if (response.body.length > responseLimit) throw const GoodGameException(GoodGameFailure.schema);
    try {
      return _object(jsonDecode(response.body));
    } on FormatException {
      throw const GoodGameException(GoodGameFailure.schema);
    }
  }

  Future<GoodGamePage> directory({int page = 1, CancelToken? cancel}) => _scope(cancel, (token) async {
    if (page < 1 || page > 10000) throw const GoodGameException(GoodGameFailure.schema);
    final root = await _get('/api/4/streams/2/', {'hidden': 'true', 'only_gg': 'true', 'page': '$page'}, token);
    return parseDirectory(root, expectedPage: page);
  });

  Future<GoodGameRoom> room(String rawReference, {CancelToken? cancel}) => _scope(cancel, (token) async {
    final reference = GoodGameLink.parseReference(rawReference);
    if (reference == null) throw const GoodGameException(GoodGameFailure.identity);
    if (reference.kind == GoodGameLinkKind.player) {
      final root = await _get('/api/player', {'src': reference.value}, token);
      _throwPayloadError(root);
      final room = parsePlayer(root);
      if (room.streamId.toString() != reference.value) throw const GoodGameException(GoodGameFailure.identity);
      return room;
    }
    final root = await _get('/api/4/users/${Uri.encodeComponent(reference.value)}/stream', const {}, token);
    _throwPayloadError(root);
    final room = parseRoom(root);
    if (room.channel != reference.value.toLowerCase()) throw const GoodGameException(GoodGameFailure.identity);
    return room;
  });

  static GoodGamePage parseDirectory(Map<String, dynamic> root, {required int expectedPage}) {
    final query = _object(root['queryInfo']);
    final page = _positiveInt(query['page']);
    final perPage = _positiveInt(query['onPage']);
    final total = _nonNegativeInt(query['qty']);
    if (page != expectedPage || perPage > 100 || total == null) {
      throw const GoodGameException(GoodGameFailure.schema);
    }
    final seen = <String>{};
    final items = <GoodGameRoom>[];
    for (final item in _list(root['streams'], max: 100)) {
      final room = parseDirectoryRoom(_object(item));
      if (room.state == GoodGameState.live && seen.add(room.channel)) items.add(room);
    }
    return GoodGamePage(items: items, hasMore: page * perPage < total && items.isNotEmpty);
  }

  static GoodGameRoom parseDirectoryRoom(Map<String, dynamic> data) {
    final streamer = _object(data['streamer']);
    final game = _optionalObject(data['game']);
    final streamId = _positiveInt(data['id']);
    final channel = _channel(_firstText([data['key'], streamer['username']]));
    final online = _bool(data['online']);
    final banned = streamer['banned'] == true;
    return GoodGameRoom(
      streamId: streamId,
      channel: channel,
      channelName: _firstText([streamer['nickname'], streamer['username'], channel]),
      title: _firstText([data['title'], streamer['nickname'], channel]),
      avatar: _image(streamer['avatar']),
      cover: _firstImage([data['streamPreview'], data['preview'], data['poster']]),
      category: _optionalText(game?['title']),
      viewers: _nonNegativeInt(data['viewers']),
      followers: _nonNegativeInt(data['followers']),
      state: banned
          ? GoodGameState.banned
          : online
          ? GoodGameState.live
          : GoodGameState.offline,
      adult: _truthy(data['adult']),
      qualities: online && !banned ? _qualities(data['sources'], streamId) : const [],
    );
  }

  static GoodGameRoom parseRoom(Map<String, dynamic> data) {
    final streamer = _object(data['streamer']);
    final game = _optionalObject(data['gameObj']);
    final streamId = _positiveInt(data['id']);
    final channel = _channel(_firstText([data['channelkey'], streamer['username']]));
    final online = data['online'] is bool ? data['online'] as bool : _bool(data['status']);
    final banned = data['blacklisted'] == true;
    return GoodGameRoom(
      streamId: streamId,
      channel: channel,
      channelName: _firstText([streamer['nickname'], streamer['username'], channel]),
      title: _firstText([data['stream_title'], data['title'], streamer['nickname'], channel]),
      avatar: _firstImage([streamer['avatar'], data['avatar']]),
      cover: _firstImage([data['streamPreview'], data['preview'], data['poster']]),
      category: _firstOptionalText([game?['title'], data['game']]),
      viewers: _nonNegativeInt(data['viewers']),
      followers: _nonNegativeInt(data['followers']),
      state: banned
          ? GoodGameState.banned
          : online
          ? GoodGameState.live
          : GoodGameState.offline,
      adult: _truthy(data['adult']),
      qualities: online && !banned ? _qualities(data['sources'], streamId) : const [],
    );
  }

  static GoodGameRoom parsePlayer(Map<String, dynamic> data) {
    final game = _optionalObject(data['game']);
    final streamId = _positiveInt(data['channel_id']);
    final channel = _channel(_firstText([data['channel_key'], data['streamer_name']]));
    final online = _optionalText(data['channel_status']).toLowerCase() == 'online';
    return GoodGameRoom(
      streamId: streamId,
      channel: channel,
      channelName: _firstText([data['streamer_name'], channel]),
      title: _firstText([data['channel_title'], data['streamer_name'], channel]),
      avatar: _image(data['streamer_avatar']),
      cover: _firstImage([data['channel_poster'], data['streamer_avatar']]),
      category: _optionalText(game?['title']),
      viewers: _nonNegativeInt(data['viewers']),
      followers: null,
      state: online ? GoodGameState.live : GoodGameState.offline,
      adult: _truthy(data['adult']),
      qualities: online ? _qualities(data['sources'], streamId) : const [],
    );
  }

  static List<GoodGameQuality> _qualities(Object? value, int streamId) {
    if (value is! Map || value.length > 16) throw const GoodGameException(GoodGameFailure.schema);
    final items = <GoodGameQuality>[];
    final ids = <String>{};
    for (final entry in value.entries) {
      final key = entry.key.toString().trim().toLowerCase();
      if (key != 'source' && int.tryParse(key) == null) continue;
      final url = _media(entry.value, streamId: streamId, sourceKey: key);
      final height = int.tryParse(key);
      final id = height == null ? 'source' : '${height}p';
      if (!ids.add(id)) continue;
      items.add(
        GoodGameQuality(
          id: id,
          label: height == null ? 'Source · HLS' : '${height}p · HLS',
          sort: height ?? 0x7fffffff,
          url: url,
        ),
      );
    }
    if (items.isEmpty) throw const GoodGameException(GoodGameFailure.mediaUnavailable);
    items.sort((left, right) {
      final rank = right.sort.compareTo(left.sort);
      return rank != 0 ? rank : left.id.compareTo(right.id);
    });
    return List.unmodifiable(items);
  }

  static Uri _media(Object? value, {required int streamId, required String sourceKey}) {
    final raw = _text(value);
    final uri = Uri.tryParse(raw);
    final suffix = sourceKey == 'source' ? '' : '_$sourceKey';
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.host.toLowerCase() != 'hls.goodgame.ru' ||
        uri.path != '/hls/$streamId$suffix.m3u8' ||
        uri.hasFragment) {
      throw const GoodGameException(GoodGameFailure.schema);
    }
    final expires = int.tryParse(uri.queryParameters['expires'] ?? '');
    final token = uri.queryParameters['token'] ?? '';
    if (expires == null || expires <= 0 || token.isEmpty || token.length > 512) {
      throw const GoodGameException(GoodGameFailure.schema);
    }
    return uri;
  }

  static String _channel(String raw) {
    final channel = GoodGameLink.parseChannel(raw);
    if (channel == null) throw const GoodGameException(GoodGameFailure.schema);
    return channel;
  }

  static String _image(Object? value) {
    final raw = _optionalText(value);
    if (raw.isEmpty) return '';
    late final Uri uri;
    try {
      uri = Uri.parse(origin).resolve(raw.startsWith('//') ? 'https:$raw' : raw);
    } on FormatException {
      return '';
    }
    if (uri.scheme != 'https' || uri.userInfo.isNotEmpty || uri.hasFragment) return '';
    final host = uri.host.toLowerCase();
    if (host != 'goodgame.ru' && host != 'www.goodgame.ru' && host != 'hls.goodgame.ru') return '';
    return uri.toString();
  }

  static String _firstImage(Iterable<Object?> values) {
    for (final value in values) {
      final image = _image(value);
      if (image.isNotEmpty) return image;
    }
    return '';
  }

  static bool _truthy(Object? value) => switch (value) {
    true => true,
    int number => number != 0,
    String text => const {'1', 'true', 'yes'}.contains(text.trim().toLowerCase()),
    _ => false,
  };

  static bool _bool(Object? value) {
    if (value is bool) return value;
    throw const GoodGameException(GoodGameFailure.schema);
  }

  static int _positiveInt(Object? value) {
    final result = _nonNegativeInt(value);
    if (result == null || result < 1) throw const GoodGameException(GoodGameFailure.schema);
    return result;
  }

  static int? _nonNegativeInt(Object? value) {
    final result = switch (value) {
      int number => number,
      num number when number.isFinite => number.toInt(),
      String text => int.tryParse(text.trim()),
      _ => null,
    };
    return result != null && result >= 0 && result <= 0x7fffffff ? result : null;
  }

  static String _text(Object? value) {
    final result = _optionalText(value);
    if (result.isEmpty) throw const GoodGameException(GoodGameFailure.schema);
    return result;
  }

  static String _firstText(Iterable<Object?> values) {
    final result = _firstOptionalText(values);
    if (result.isEmpty) throw const GoodGameException(GoodGameFailure.schema);
    return result;
  }

  static String _firstOptionalText(Iterable<Object?> values) {
    for (final value in values) {
      final result = _optionalText(value);
      if (result.isNotEmpty) return result;
    }
    return '';
  }

  static String _optionalText(Object? value) {
    if (value == null) return '';
    if (value is! String) throw const GoodGameException(GoodGameFailure.schema);
    final result = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (result.length > 65536) throw const GoodGameException(GoodGameFailure.schema);
    return result;
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map) throw const GoodGameException(GoodGameFailure.schema);
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static Map<String, dynamic>? _optionalObject(Object? value) => value == null ? null : _object(value);

  static void _throwPayloadError(Map<String, dynamic> root) {
    final error = root['error'];
    if (error is String && error.trim().isNotEmpty) {
      throw const GoodGameException(GoodGameFailure.missing);
    }
  }

  static List<Object?> _list(Object? value, {required int max}) {
    if (value is! List || value.length > max) throw const GoodGameException(GoodGameFailure.schema);
    return value;
  }

  static void _throwStatus(int status) {
    final failure = switch (status) {
      200 => null,
      400 || 422 => GoodGameFailure.schema,
      401 || 403 => GoodGameFailure.access,
      404 => GoodGameFailure.missing,
      429 => GoodGameFailure.rateLimited,
      >= 500 => GoodGameFailure.service,
      _ => GoodGameFailure.transport,
    };
    if (failure != null) throw GoodGameException(failure);
  }
}
