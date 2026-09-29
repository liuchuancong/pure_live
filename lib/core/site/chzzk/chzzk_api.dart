import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/common/request_scope.dart';

enum ChzzkFailure { transport, access, rateLimited, service, missing, schema, cancelled, identity, mediaUnavailable }

class ChzzkException implements Exception {
  const ChzzkException(this.kind);

  final ChzzkFailure kind;

  @override
  String toString() => 'CHZZK ${kind.name}';
}

typedef ChzzkRequest = Future<({int status, String body})> Function(Uri uri, CancelToken? cancel);

class ChzzkChannel {
  const ChzzkChannel({
    required this.id,
    required this.name,
    required this.avatar,
    required this.description,
    required this.followers,
    required this.isLive,
  });

  final String id;
  final String name;
  final String avatar;
  final String description;
  final int? followers;
  final bool isLive;
}

class ChzzkMedia {
  const ChzzkMedia({required this.id, required this.url, required this.lowLatency});

  final String id;
  final String url;
  final bool lowLatency;
}

class ChzzkLive {
  ChzzkLive({
    required this.liveId,
    required this.channel,
    required this.title,
    required this.cover,
    required this.category,
    required this.concurrentViewers,
    required this.adult,
    required this.regionRestricted,
    required this.isLive,
    required this.timeMachineActive,
    required Iterable<ChzzkMedia> media,
  }) : media = List.unmodifiable(media);

  final int liveId;
  final ChzzkChannel channel;
  final String title;
  final String cover;
  final String category;
  final int? concurrentViewers;
  final bool adult;
  final bool regionRestricted;
  final bool isLive;
  final bool timeMachineActive;
  final List<ChzzkMedia> media;
}

class ChzzkRoom {
  const ChzzkRoom(this.channel, this.live);

  final ChzzkChannel channel;
  final ChzzkLive? live;
}

class ChzzkDirectoryPage {
  ChzzkDirectoryPage({required Iterable<ChzzkLive> lives, required this.nextCursor, required this.hasMore})
    : lives = List.unmodifiable(lives);

  final List<ChzzkLive> lives;
  final String? nextCursor;
  final bool hasMore;
}

class ChzzkApi {
  ChzzkApi({ChzzkRequest? request}) : _request = request ?? _defaultRequest;

  static const apiOrigin = 'https://api.chzzk.naver.com';
  static const webOrigin = 'https://chzzk.naver.com';
  static const responseLimit = 2 * 1024 * 1024;
  static const userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';
  static const headers = {
    'User-Agent': userAgent,
    'Accept': 'application/json, text/plain, */*',
    'Origin': webOrigin,
    'Referer': '$webOrigin/',
  };
  static const mediaHeaders = {'User-Agent': userAgent, 'Referer': '$webOrigin/'};

  final ChzzkRequest _request;

  static Future<({int status, String body})> _defaultRequest(Uri uri, CancelToken? cancel) =>
      withRequestCancellation(cancel, (transport) async {
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
        if (body == null) throw const ChzzkException(ChzzkFailure.schema);
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
        if (remaining <= Duration.zero) throw TimeoutException('CHZZK response deadline');
        if (!await iterator.moveNext().timeout(remaining)) break;
        final chunk = iterator.current;
        if (bytes.length + chunk.length > responseLimit) throw const ChzzkException(ChzzkFailure.schema);
        bytes.add(chunk);
      }
      return utf8.decode(bytes.takeBytes());
    } on FormatException {
      throw const ChzzkException(ChzzkFailure.schema);
    } finally {
      watch.stop();
      await iterator.cancel();
    }
  }

  Future<String> _read(Uri uri, CancelToken? cancel) async {
    if (cancel?.isCancelled == true) throw const ChzzkException(ChzzkFailure.cancelled);
    late final ({int status, String body}) response;
    try {
      response = await _request(uri, cancel);
    } catch (error) {
      if (cancel?.isCancelled == true || (error is DioException && CancelToken.isCancel(error))) {
        throw const ChzzkException(ChzzkFailure.cancelled);
      }
      if (error is ChzzkException) rethrow;
      throw const ChzzkException(ChzzkFailure.transport);
    }
    if (cancel?.isCancelled == true) throw const ChzzkException(ChzzkFailure.cancelled);
    final failure = switch (response.status) {
      200 => null,
      400 => ChzzkFailure.schema,
      401 || 403 => ChzzkFailure.access,
      404 => ChzzkFailure.missing,
      429 => ChzzkFailure.rateLimited,
      >= 500 => ChzzkFailure.service,
      _ => ChzzkFailure.transport,
    };
    if (failure != null) throw ChzzkException(failure);
    if (response.body.length > responseLimit) throw const ChzzkException(ChzzkFailure.schema);
    return response.body;
  }

  Future<Object?> _get(String path, Map<String, String> query, CancelToken? cancel) async {
    final body = await _read(
      Uri.parse('$apiOrigin$path').replace(queryParameters: query.isEmpty ? null : query),
      cancel,
    );
    try {
      final root = _object(jsonDecode(body));
      if (_integer(root['code']) != 200) throw const ChzzkException(ChzzkFailure.service);
      return root['content'];
    } on FormatException {
      throw const ChzzkException(ChzzkFailure.schema);
    }
  }

  Future<String> manifest(String url, {CancelToken? cancel}) => _read(_mediaUri(url), cancel);

  Future<ChzzkDirectoryPage> directory({int size = 30, String? cursor, CancelToken? cancel}) async {
    if (size < 1 || size > 30) throw const ChzzkException(ChzzkFailure.schema);
    final decodedCursor = cursor == null ? null : _decodeDirectoryCursor(cursor);
    final query = <String, String>{
      // The server cursor is inclusive, so one extra row preserves a full
      // logical page after removing the repeated boundary item.
      'size': '${decodedCursor == null ? size : size + 1}',
      if (decodedCursor != null) 'concurrentUserCount': '${decodedCursor.$1}',
      if (decodedCursor != null) 'liveId': '${decodedCursor.$2}',
    };
    final content = _object(await _get('/service/v1/lives', query, cancel));
    final rows = _list(content['data'], max: 64).map((value) => _live(_object(value))).toList(growable: true);
    if (decodedCursor != null && rows.isNotEmpty && rows.first.liveId == decodedCursor.$2) rows.removeAt(0);
    if (rows.length > size) rows.removeRange(size, rows.length);

    final page = content['page'];
    String? nextCursor;
    if (page is Map && page['next'] is Map) {
      final next = _object(page['next']);
      nextCursor = _encodeDirectoryCursor(_nonNegativeInt(next['concurrentUserCount']), _positiveInt(next['liveId']));
    }
    if (nextCursor == cursor) nextCursor = null;
    return ChzzkDirectoryPage(lives: rows, nextCursor: nextCursor, hasMore: nextCursor != null && rows.isNotEmpty);
  }

  Future<List<ChzzkChannel>> searchChannels(
    String keyword, {
    int offset = 0,
    int size = 30,
    CancelToken? cancel,
  }) async {
    final query = keyword.trim();
    if (query.isEmpty || query.length > 100 || offset < 0 || offset > 1000000 || size < 1 || size > 30) {
      throw const ChzzkException(ChzzkFailure.schema);
    }
    final content = _object(
      await _get('/service/v1/search/channels', {'keyword': query, 'offset': '$offset', 'size': '$size'}, cancel),
    );
    return _list(
      content['data'],
      max: 64,
    ).map((value) => _channel(_object(_object(value)['channel']))).toList(growable: false);
  }

  Future<ChzzkChannel> channel(String channelId, {CancelToken? cancel}) async {
    final id = _channelId(channelId);
    final content = await _get('/service/v1/channels/$id', const {}, cancel);
    if (content == null) throw const ChzzkException(ChzzkFailure.missing);
    final result = _channel(_object(content));
    if (result.id != id) throw const ChzzkException(ChzzkFailure.identity);
    return result;
  }

  Future<ChzzkLive?> liveDetail(String channelId, ChzzkChannel owner, {CancelToken? cancel}) async {
    final id = _channelId(channelId);
    if (owner.id != id) throw const ChzzkException(ChzzkFailure.identity);
    // v2 now answers overseas-restricted lives with HTTP 500 / code 9004 and
    // no detail at all; v3.1 (the web player's version) returns the same
    // fields with krOnlyViewing set and no playback, which the room card
    // already presents as a region notice.
    final content = await _get('/service/v3.1/channels/$id/live-detail', const {}, cancel);
    if (content == null) return null;
    final detail = _object(content);
    final status = _text(detail['status']);
    final liveOwner = _channel(_object(detail['channel']), description: owner.description, followers: owner.followers);
    if (liveOwner.id != id) throw const ChzzkException(ChzzkFailure.identity);
    final isLive = status == 'OPEN';
    if (!isLive && status != 'CLOSE' && status != 'CLOSED') throw const ChzzkException(ChzzkFailure.schema);
    final adult = _bool(detail['adult']);
    final regionRestricted = _bool(detail['krOnlyViewing']);
    final media = isLive ? _playbackMedia(detail['livePlaybackJson']) : const <ChzzkMedia>[];
    return ChzzkLive(
      liveId: _positiveInt(detail['liveId']),
      channel: ChzzkChannel(
        id: liveOwner.id,
        name: liveOwner.name,
        avatar: liveOwner.avatar,
        description: liveOwner.description,
        followers: liveOwner.followers,
        isLive: isLive,
      ),
      title: _optionalText(detail['liveTitle'], fallback: owner.name),
      cover: _cover(detail['liveImageUrl'], detail['defaultThumbnailImageUrl']),
      category: _optionalText(detail['liveCategoryValue'] ?? detail['liveCategory']),
      concurrentViewers: _visibleViewers(detail),
      adult: adult,
      regionRestricted: regionRestricted,
      isLive: isLive,
      timeMachineActive: _bool(detail['timeMachineActive']),
      media: media,
    );
  }

  Future<ChzzkRoom> room(String channelId, {CancelToken? cancel}) async {
    final owner = await channel(channelId, cancel: cancel);
    final live = await liveDetail(owner.id, owner, cancel: cancel);
    return ChzzkRoom(owner, live);
  }

  static ChzzkLive _live(Map<String, dynamic> data) {
    final channel = _channel(_object(data['channel']), isLive: true);
    return ChzzkLive(
      liveId: _positiveInt(data['liveId']),
      channel: channel,
      title: _text(data['liveTitle']),
      cover: _cover(data['liveImageUrl'], data['defaultThumbnailImageUrl']),
      category: _optionalText(data['liveCategoryValue'] ?? data['liveCategory']),
      concurrentViewers: _visibleViewers(data),
      adult: _bool(data['adult']),
      regionRestricted: false,
      isLive: true,
      timeMachineActive: false,
      media: const [],
    );
  }

  static ChzzkChannel _channel(Map<String, dynamic> data, {String description = '', int? followers, bool? isLive}) =>
      ChzzkChannel(
        id: _channelId(data['channelId']),
        name: _text(data['channelName']),
        avatar: _image(data['channelImageUrl']),
        description: data.containsKey('channelDescription') ? _optionalText(data['channelDescription']) : description,
        followers: data.containsKey('followerCount') ? _optionalNonNegativeInt(data['followerCount']) : followers,
        isLive: isLive ?? (data['openLive'] is bool ? data['openLive'] as bool : false),
      );

  static List<ChzzkMedia> _playbackMedia(Object? raw) {
    if (raw == null || raw == '') return const [];
    if (raw is! String || raw.length > responseLimit) throw const ChzzkException(ChzzkFailure.schema);
    late final Map<String, dynamic> playback;
    try {
      playback = _object(jsonDecode(raw));
    } on FormatException {
      throw const ChzzkException(ChzzkFailure.schema);
    }
    final result = <ChzzkMedia>[];
    final seen = <String>{};
    for (final value in _list(playback['media'], max: 16)) {
      final media = _object(value);
      if (_text(media['protocol']) != 'HLS') continue;
      final mediaId = _text(media['mediaId']);
      if (mediaId != 'HLS' && mediaId != 'LLHLS') continue;
      final url = _mediaUri(_text(media['path'])).toString();
      if (seen.add(url)) result.add(ChzzkMedia(id: mediaId, url: url, lowLatency: mediaId == 'LLHLS'));
    }
    return List.unmodifiable(result);
  }

  static int? _visibleViewers(Map<String, dynamic> data) {
    if (data['cvExposure'] != true) return null;
    return _optionalNonNegativeInt(data['concurrentUserCount']);
  }

  static String _cover(Object? primary, Object? fallback) {
    for (final value in [primary, fallback]) {
      if (value is! String || value.isEmpty) continue;
      final expanded = value.replaceAll('{type}', '480');
      final result = _image(expanded);
      if (result.isNotEmpty) return result;
    }
    return '';
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map) throw const ChzzkException(ChzzkFailure.schema);
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static List<dynamic> _list(Object? value, {required int max}) {
    if (value is! List || value.length > max) throw const ChzzkException(ChzzkFailure.schema);
    return value;
  }

  static int? _integer(Object? value) => value is int ? value : int.tryParse(value?.toString() ?? '');

  static int _positiveInt(Object? value) {
    final parsed = _integer(value);
    if (parsed == null || parsed <= 0) throw const ChzzkException(ChzzkFailure.schema);
    return parsed;
  }

  static int _nonNegativeInt(Object? value) {
    final parsed = _integer(value);
    if (parsed == null || parsed < 0) throw const ChzzkException(ChzzkFailure.schema);
    return parsed;
  }

  static int? _optionalNonNegativeInt(Object? value) {
    if (value == null || value == '') return null;
    return _nonNegativeInt(value);
  }

  static bool _bool(Object? value) {
    if (value is! bool) throw const ChzzkException(ChzzkFailure.schema);
    return value;
  }

  static String _text(Object? value) {
    if (value is! String || value.trim().isEmpty || value.length > 8192) {
      throw const ChzzkException(ChzzkFailure.schema);
    }
    return value.trim();
  }

  static String _optionalText(Object? value, {String fallback = ''}) {
    if (value == null || value == '') return fallback;
    if (value is! String || value.length > 131072) throw const ChzzkException(ChzzkFailure.schema);
    final result = value.trim();
    return result.isEmpty ? fallback : result;
  }

  static String _channelId(Object? value) {
    final result = value?.toString().trim() ?? '';
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(result)) throw const ChzzkException(ChzzkFailure.identity);
    return result;
  }

  static String _image(Object? value) {
    if (value is! String || value.length > 8192) return '';
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty || uri.hasFragment) return '';
    final host = uri.host.toLowerCase();
    return host == 'pstatic.net' ||
            host.endsWith('.pstatic.net') ||
            host == 'akamaized.net' ||
            host.endsWith('.akamaized.net')
        ? value
        : '';
  }

  static Uri _mediaUri(String value) {
    if (value.length > 16384 || value.contains(RegExp(r'[\s\x00-\x1f]'))) {
      throw const ChzzkException(ChzzkFailure.schema);
    }
    final uri = Uri.tryParse(value);
    final host = uri?.host.toLowerCase() ?? '';
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !(host == 'akamaized.net' || host.endsWith('.akamaized.net'))) {
      throw const ChzzkException(ChzzkFailure.schema);
    }
    return uri;
  }

  static String _encodeDirectoryCursor(int viewers, int liveId) => jsonEncode({'v': viewers, 'l': liveId});

  static (int, int) _decodeDirectoryCursor(String cursor) {
    if (cursor.length > 128) throw const ChzzkException(ChzzkFailure.schema);
    try {
      final data = _object(jsonDecode(cursor));
      if (data.length != 2 || !data.containsKey('v') || !data.containsKey('l')) {
        throw const ChzzkException(ChzzkFailure.schema);
      }
      return (_nonNegativeInt(data['v']), _positiveInt(data['l']));
    } on FormatException {
      throw const ChzzkException(ChzzkFailure.schema);
    }
  }
}
