import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/common/request_scope.dart';

import 'dailymotion_link.dart';

enum DailymotionFailure {
  transport,
  access,
  missing,
  rateLimited,
  service,
  schema,
  identity,
  cancelled,
  notLive,
  mediaUnavailable,
}

final class DailymotionException implements Exception {
  const DailymotionException(this.kind);

  final DailymotionFailure kind;

  @override
  String toString() => 'Dailymotion ${kind.name}';
}

enum DailymotionState { live, offline }

final class DailymotionQuality {
  const DailymotionQuality({required this.id, required this.label, required this.sort, required this.url});

  final String id;
  final String label;
  final int sort;
  final Uri url;
}

final class DailymotionRoom {
  DailymotionRoom({
    required this.videoId,
    required this.ownerId,
    required this.username,
    required this.screenName,
    required this.title,
    required this.description,
    required this.thumbnail,
    required this.state,
    required Iterable<DailymotionQuality> qualities,
  }) : qualities = List.unmodifiable(qualities);

  final String videoId;
  final String ownerId;
  final String username;
  final String screenName;
  final String title;
  final String description;
  final String thumbnail;
  final DailymotionState state;
  final List<DailymotionQuality> qualities;

  DailymotionRoom withQualities(Iterable<DailymotionQuality> values) => DailymotionRoom(
    videoId: videoId,
    ownerId: ownerId,
    username: username,
    screenName: screenName,
    title: title,
    description: description,
    thumbnail: thumbnail,
    state: state,
    qualities: values,
  );
}

final class DailymotionPage {
  DailymotionPage({required Iterable<DailymotionRoom> items, required this.hasMore}) : items = List.unmodifiable(items);

  final List<DailymotionRoom> items;
  final bool hasMore;
}

typedef DailymotionRequest = Future<({int status, String body})> Function(
  Uri uri,
  Map<String, String> headers,
  CancelToken cancel,
);

final class DailymotionApi {
  DailymotionApi({DailymotionRequest? request, this.deadline = const Duration(seconds: 25)})
    : _request = request ?? _defaultRequest;

  static const String apiOrigin = 'https://api.dailymotion.com';
  static const int responseLimit = 2 * 1024 * 1024;
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';
  static const Map<String, String> headers = {
    'User-Agent': userAgent,
    'Accept': 'application/json, text/plain, */*',
    'Referer': 'https://www.dailymotion.com/',
  };
  static const Map<String, String> mediaHeaders = {'User-Agent': userAgent, 'Referer': 'https://geo.dailymotion.com/'};
  static const String _listFields = 'id,title,onair,mode,owner.id,owner.username,owner.screenname,thumbnail_720_url';
  static const String _detailFields = '$_listFields,description,created_time';

  final DailymotionRequest _request;
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
    if (body == null) throw const DailymotionException(DailymotionFailure.schema);
    return (status: response.statusCode ?? 0, body: await _readBody(body.stream));
  }

  static Future<String> _readBody(Stream<List<int>> source) async {
    final iterator = StreamIterator(source);
    final bytes = BytesBuilder(copy: false);
    try {
      while (await iterator.moveNext()) {
        if (bytes.length + iterator.current.length > responseLimit) {
          throw const DailymotionException(DailymotionFailure.schema);
        }
        bytes.add(iterator.current);
      }
      return utf8.decode(bytes.takeBytes());
    } on FormatException {
      throw const DailymotionException(DailymotionFailure.schema);
    } finally {
      await iterator.cancel();
    }
  }

  Future<T> _scope<T>(CancelToken? caller, Future<T> Function(CancelToken) work) =>
      withRequestCancellation(caller, (transport) async {
        if (transport.isCancelled) throw const DailymotionException(DailymotionFailure.cancelled);
        try {
          return await Future.any<T>([
            work(transport),
            transport.whenCancel.then<T>((_) => throw const DailymotionException(DailymotionFailure.cancelled)),
          ]).timeout(deadline);
        } on TimeoutException {
          throw const DailymotionException(DailymotionFailure.transport);
        } catch (error) {
          if (caller?.isCancelled == true || transport.isCancelled) {
            throw const DailymotionException(DailymotionFailure.cancelled);
          }
          if (error is DailymotionException) rethrow;
          throw const DailymotionException(DailymotionFailure.transport);
        }
      });

  Future<Map<String, dynamic>> _get(String path, Map<String, String> query, CancelToken token) async {
    final uri = Uri.parse('$apiOrigin$path').replace(queryParameters: query.isEmpty ? null : query);
    final response = await _request(uri, headers, token);
    _throwStatus(response.status);
    if (response.body.length > responseLimit) throw const DailymotionException(DailymotionFailure.schema);
    try {
      return _object(jsonDecode(response.body));
    } on FormatException {
      throw const DailymotionException(DailymotionFailure.schema);
    }
  }

  Future<DailymotionPage> directory({int page = 1, int limit = 30, CancelToken? cancel}) =>
      _scope(cancel, (token) async {
        _pageArguments(page, limit);
        final root = await _get('/videos', {
          'fields': _listFields,
          'mode': 'live',
          'sort': 'live-audience',
          'limit': '$limit',
          'page': '$page',
        }, token);
        return parsePage(root, liveOnly: true);
      });

  Future<DailymotionPage> search(String keyword, {int page = 1, int limit = 30, CancelToken? cancel}) =>
      _scope(cancel, (token) async {
        _pageArguments(page, limit);
        final query = keyword.trim();
        if (query.isEmpty || query.length > 100) throw const DailymotionException(DailymotionFailure.schema);
        final root = await _get('/videos', {
          'fields': _listFields,
          'mode': 'live',
          'search': query,
          'sort': 'relevance',
          'limit': '$limit',
          'page': '$page',
        }, token);
        return parsePage(root);
      });

  Future<DailymotionPage> userLive(String username, {int page = 1, int limit = 30, CancelToken? cancel}) =>
      _scope(cancel, (token) async {
        _pageArguments(page, limit);
        final user = DailymotionLink.parseUsername(username);
        if (user == null) throw const DailymotionException(DailymotionFailure.identity);
        final root = await _get('/user/${Uri.encodeComponent(user)}/videos', {
          'fields': _listFields,
          'flags': 'live_onair',
          'family_filter': 'false',
          'limit': '$limit',
          'page': '$page',
        }, token);
        return parsePage(root, liveOnly: true);
      });

  Future<DailymotionRoom> room(String rawVideoId, {CancelToken? cancel}) => _scope(cancel, (token) async {
    final videoId = DailymotionLink.parseVideoId(rawVideoId);
    if (videoId == null) throw const DailymotionException(DailymotionFailure.identity);
    final root = await _get('/video/$videoId', {'fields': _detailFields}, token);
    final room = parseRoom(root);
    if (room.videoId != videoId) throw const DailymotionException(DailymotionFailure.identity);
    return room;
  });

  static DailymotionPage parsePage(Map<String, dynamic> root, {bool liveOnly = false}) {
    final rows = _list(root['list'], max: 100);
    final seen = <String>{};
    final rooms = <DailymotionRoom>[];
    for (final value in rows) {
      final room = parseRoom(_object(value));
      if (liveOnly && room.state != DailymotionState.live) continue;
      if (seen.add(room.videoId)) rooms.add(room);
    }
    return DailymotionPage(items: rooms, hasMore: _bool(root['has_more']));
  }

  static DailymotionRoom parseRoom(Map<String, dynamic> data) {
    final mode = _text(data['mode']).toLowerCase();
    if (mode != 'live') throw const DailymotionException(DailymotionFailure.notLive);
    final onair = _bool(data['onair']);
    final videoId = DailymotionLink.parseVideoId(_text(data['id']));
    if (videoId == null) throw const DailymotionException(DailymotionFailure.schema);
    final username = _optionalText(data['owner.username']);
    final screenName = _firstText([data['owner.screenname'], username]);
    return DailymotionRoom(
      videoId: videoId,
      ownerId: _optionalText(data['owner.id']),
      username: username,
      screenName: screenName,
      title: _firstText([data['title'], screenName]),
      description: _optionalText(data['description']),
      thumbnail: _image(data['thumbnail_720_url']),
      state: onair ? DailymotionState.live : DailymotionState.offline,
      qualities: const [],
    );
  }

  static void _pageArguments(int page, int limit) {
    if (page < 1 || page > 1000000 || limit < 1 || limit > 100) {
      throw const DailymotionException(DailymotionFailure.schema);
    }
  }

  static String _text(Object? value) {
    final text = _optionalText(value);
    if (text.isEmpty) throw const DailymotionException(DailymotionFailure.schema);
    return text;
  }

  static String _firstText(Iterable<Object?> values) {
    for (final value in values) {
      final text = _optionalText(value);
      if (text.isNotEmpty) return text;
    }
    throw const DailymotionException(DailymotionFailure.schema);
  }

  static String _optionalText(Object? value) {
    if (value == null) return '';
    if (value is! String) throw const DailymotionException(DailymotionFailure.schema);
    final text = value.trim();
    if (text.length > 65536) throw const DailymotionException(DailymotionFailure.schema);
    return text;
  }

  static String _image(Object? value) {
    final text = _optionalText(value);
    if (text.isEmpty) return '';
    final uri = Uri.tryParse(text);
    if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty || uri.hasFragment) {
      throw const DailymotionException(DailymotionFailure.schema);
    }
    final host = uri.host.toLowerCase();
    if (host != 'dmcdn.net' && !host.endsWith('.dmcdn.net')) {
      throw const DailymotionException(DailymotionFailure.schema);
    }
    return uri.toString();
  }

  static bool _bool(Object? value) {
    if (value is bool) return value;
    throw const DailymotionException(DailymotionFailure.schema);
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map) throw const DailymotionException(DailymotionFailure.schema);
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static List<Object?> _list(Object? value, {required int max}) {
    if (value is! List || value.length > max) throw const DailymotionException(DailymotionFailure.schema);
    return value;
  }

  static void _throwStatus(int status) {
    final failure = switch (status) {
      200 => null,
      400 || 422 => DailymotionFailure.schema,
      401 || 403 => DailymotionFailure.access,
      404 => DailymotionFailure.missing,
      429 => DailymotionFailure.rateLimited,
      >= 500 => DailymotionFailure.service,
      _ => DailymotionFailure.transport,
    };
    if (failure != null) throw DailymotionException(failure);
  }
}
