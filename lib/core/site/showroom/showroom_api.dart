import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/common/request_scope.dart';

enum ShowroomFailure {
  transport,
  access,
  rateLimited,
  service,
  missing,
  schema,
  cancelled,
  identity,
  notLive,
  mediaUnavailable,
}

class ShowroomException implements Exception {
  const ShowroomException(this.kind);

  final ShowroomFailure kind;

  @override
  String toString() => 'Showroom ${kind.name}';
}

typedef ShowroomRequest = Future<({int status, String body})> Function(Uri uri, CancelToken? cancel);

class ShowroomStream {
  const ShowroomStream({
    required this.id,
    required this.type,
    required this.label,
    required this.quality,
    required this.url,
    required this.isDefault,
  });

  final int id;
  final String type;
  final String label;
  final int quality;
  final String url;
  final bool isDefault;
}

class ShowroomLive {
  ShowroomLive({
    required this.roomId,
    required this.roomUrlKey,
    required this.name,
    required this.cover,
    required this.genreId,
    required this.genreName,
    required this.followers,
    required this.totalViewers,
    required this.telop,
    required Iterable<ShowroomStream> streams,
  }) : streams = List.unmodifiable(streams);

  final int roomId;
  final String roomUrlKey;
  final String name;
  final String cover;
  final int genreId;
  final String genreName;
  final int? followers;
  final int? totalViewers;
  final String telop;
  final List<ShowroomStream> streams;
}

class ShowroomGenre {
  ShowroomGenre({required this.id, required this.name, required Iterable<ShowroomLive> lives})
    : lives = List.unmodifiable(lives);

  final int id;
  final String name;
  final List<ShowroomLive> lives;
}

class ShowroomCatalog {
  ShowroomCatalog(Iterable<ShowroomGenre> genres) : genres = List.unmodifiable(genres);

  final List<ShowroomGenre> genres;

  Iterable<ShowroomLive> get uniqueLives sync* {
    final seen = <int>{};
    for (final genre in genres) {
      for (final live in genre.lives) {
        if (seen.add(live.roomId)) yield live;
      }
    }
  }
}

class ShowroomProfile {
  const ShowroomProfile({
    required this.roomId,
    required this.roomUrlKey,
    required this.name,
    required this.cover,
    required this.genreId,
    required this.genreName,
    required this.followers,
    required this.totalViewers,
    required this.description,
    required this.isLive,
  });

  final int roomId;
  final String roomUrlKey;
  final String name;
  final String cover;
  final int genreId;
  final String genreName;
  final int? followers;
  final int? totalViewers;
  final String description;
  final bool isLive;

  ShowroomProfile withLiveStatus(bool value) => ShowroomProfile(
    roomId: roomId,
    roomUrlKey: roomUrlKey,
    name: name,
    cover: cover,
    genreId: genreId,
    genreName: genreName,
    followers: followers,
    totalViewers: totalViewers,
    description: description,
    isLive: value,
  );
}

class ShowroomRoom {
  ShowroomRoom(this.profile, Iterable<ShowroomStream> streams) : streams = List.unmodifiable(streams);

  final ShowroomProfile profile;
  final List<ShowroomStream> streams;
}

/// Public SHOWROOM web contracts. The directory is a complete snapshot rather
/// than a server-paged endpoint; adapters page the immutable snapshot locally.
class ShowroomApi {
  ShowroomApi({ShowroomRequest? request}) : _request = request ?? _defaultRequest;

  static const origin = 'https://www.showroom-live.com';
  static const responseLimit = 3 * 1024 * 1024;
  static const userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';
  static const headers = {
    'User-Agent': userAgent,
    'Accept': 'application/json, text/plain, */*',
    'Referer': '$origin/',
  };
  static const mediaHeaders = {'User-Agent': userAgent, 'Referer': '$origin/'};

  final ShowroomRequest _request;

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
        if (body == null) throw const ShowroomException(ShowroomFailure.schema);
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
        if (remaining <= Duration.zero) throw TimeoutException('Showroom response deadline');
        if (!await iterator.moveNext().timeout(remaining)) break;
        final chunk = iterator.current;
        if (bytes.length + chunk.length > responseLimit) {
          throw const ShowroomException(ShowroomFailure.schema);
        }
        bytes.add(chunk);
      }
      return utf8.decode(bytes.takeBytes());
    } on FormatException {
      throw const ShowroomException(ShowroomFailure.schema);
    } finally {
      watch.stop();
      await iterator.cancel();
    }
  }

  Future<Object?> _get(String path, Map<String, String> query, CancelToken? cancel) async {
    if (cancel?.isCancelled == true) throw const ShowroomException(ShowroomFailure.cancelled);
    late final ({int status, String body}) response;
    try {
      response = await _request(Uri.parse('$origin$path').replace(queryParameters: query), cancel);
    } catch (error) {
      if (cancel?.isCancelled == true || (error is DioException && CancelToken.isCancel(error))) {
        throw const ShowroomException(ShowroomFailure.cancelled);
      }
      if (error is ShowroomException) rethrow;
      throw const ShowroomException(ShowroomFailure.transport);
    }
    if (cancel?.isCancelled == true) throw const ShowroomException(ShowroomFailure.cancelled);
    final failure = switch (response.status) {
      200 => null,
      401 || 403 => ShowroomFailure.access,
      404 => ShowroomFailure.missing,
      429 => ShowroomFailure.rateLimited,
      >= 500 => ShowroomFailure.service,
      _ => ShowroomFailure.transport,
    };
    if (failure != null) throw ShowroomException(failure);
    if (response.body.length > responseLimit) throw const ShowroomException(ShowroomFailure.schema);
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw const ShowroomException(ShowroomFailure.schema);
    }
  }

  Future<ShowroomCatalog> catalog({CancelToken? cancel}) async {
    final root = _object(await _get('/api/live/onlives', const {}, cancel));
    final groups = _list(root['onlives'], max: 128);
    final genres = <ShowroomGenre>[];
    final seen = <int>{};
    for (final rawGroup in groups) {
      final group = _object(rawGroup);
      final id = _nonNegativeInt(group['genre_id']);
      if (!seen.add(id)) continue;
      final name = _text(group['genre_name']);
      final lives = _list(group['lives'], max: 5000)
          .map(_object)
          // A genre with nobody live carries a message cell (`cell_type: 7`,
          // no room) instead of an empty list. Skip such non-room cells; real
          // live rows keep their strict validation.
          .where((row) => row['room_id'] != null || row['cell_type'] == null)
          .map(_live)
          .toList(growable: false);
      genres.add(ShowroomGenre(id: id, name: name, lives: lives));
    }
    if (genres.isEmpty) throw const ShowroomException(ShowroomFailure.schema);
    return ShowroomCatalog(genres);
  }

  Future<int> resolveRoomId(String reference, {CancelToken? cancel}) async {
    final normalized = reference.trim();
    final numeric = int.tryParse(normalized);
    if (numeric != null && numeric > 0) return numeric;
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(normalized)) {
      throw const ShowroomException(ShowroomFailure.identity);
    }
    final data = _object(await _get('/api/room/status', {'room_url_key': normalized}, cancel));
    return _positiveInt(data['room_id']);
  }

  Future<ShowroomProfile> profile(int roomId, {CancelToken? cancel}) async {
    if (roomId <= 0) throw const ShowroomException(ShowroomFailure.identity);
    final data = _object(await _get('/api/room/profile', {'room_id': '$roomId'}, cancel));
    final actualId = _positiveInt(data['room_id']);
    if (actualId != roomId) throw const ShowroomException(ShowroomFailure.identity);
    return ShowroomProfile(
      roomId: actualId,
      roomUrlKey: _slug(data['room_url_key']),
      name: _text(data['main_name'] ?? data['room_name']),
      cover: _image(data['image_square']),
      genreId: _nonNegativeInt(data['genre_id']),
      genreName: _optionalText(data['genre_name']),
      followers: _optionalNonNegativeInt(data['follower_num']),
      // SHOWROOM calls this view_num. It is session traffic, not a proven
      // concurrent audience count, so the site exposes it as total viewers.
      totalViewers: _optionalNonNegativeInt(data['view_num']),
      description: _optionalText(data['description']),
      isLive: _bool(data['is_onlive']),
    );
  }

  Future<bool> liveStatus(int roomId, {CancelToken? cancel}) async {
    if (roomId <= 0) throw const ShowroomException(ShowroomFailure.identity);
    final data = _object(await _get('/api/live/live_info', {'room_id': '$roomId'}, cancel));
    final actualId = _positiveInt(data['room_id']);
    if (actualId != roomId) throw const ShowroomException(ShowroomFailure.identity);
    final status = _nonNegativeInt(data['live_status']);
    if (status > 2) throw const ShowroomException(ShowroomFailure.schema);
    return status == 2;
  }

  Future<List<ShowroomStream>> streams(int roomId, {CancelToken? cancel}) async {
    if (roomId <= 0) throw const ShowroomException(ShowroomFailure.identity);
    final data = _object(await _get('/api/live/streaming_url', {'room_id': '$roomId', 'abr_available': '1'}, cancel));
    final streams = <ShowroomStream>[];
    final seen = <String>{};
    for (final raw in _list(data['streaming_url_list'], max: 64)) {
      final row = _object(raw);
      final type = _optionalText(row['type']);
      if (type != 'hls' && type != 'hls_all') continue;
      final url = mediaUrl(row['url']);
      if (!seen.add(url)) continue;
      streams.add(
        ShowroomStream(
          id: _nonNegativeInt(row['id']),
          type: type,
          label: _text(row['label']),
          quality: _nonNegativeInt(row['quality']),
          url: url,
          isDefault: _bool(row['is_default']),
        ),
      );
    }
    return List.unmodifiable(streams);
  }

  Future<ShowroomRoom> room(String reference, {required bool playback, CancelToken? cancel}) async {
    final roomId = await resolveRoomId(reference, cancel: cancel);
    final results = await Future.wait<Object>([profile(roomId, cancel: cancel), liveStatus(roomId, cancel: cancel)]);
    final profileResult = (results[0] as ShowroomProfile).withLiveStatus(results[1] as bool);
    if (!playback || !profileResult.isLive) return ShowroomRoom(profileResult, const []);
    final media = await streams(roomId, cancel: cancel);
    if (media.isEmpty) throw const ShowroomException(ShowroomFailure.mediaUnavailable);
    return ShowroomRoom(profileResult, media);
  }

  static ShowroomLive _live(Map<String, dynamic> data) {
    final roomId = _positiveInt(data['room_id']);
    final streams = <ShowroomStream>[];
    final seen = <String>{};
    for (final raw in _list(data['streaming_url_list'], max: 64)) {
      final row = _object(raw);
      final type = _optionalText(row['type']);
      if (type != 'hls' && type != 'hls_all') continue;
      final url = mediaUrl(row['url']);
      if (!seen.add(url)) continue;
      streams.add(
        ShowroomStream(
          id: _nonNegativeInt(row['id']),
          type: type,
          label: _text(row['label']),
          quality: _nonNegativeInt(row['quality']),
          url: url,
          isDefault: _bool(row['is_default']),
        ),
      );
    }
    return ShowroomLive(
      roomId: roomId,
      roomUrlKey: _slug(data['room_url_key']),
      name: _text(data['main_name']),
      cover: _image(data['image_square'] ?? data['image']),
      genreId: _nonNegativeInt(data['genre_id']),
      genreName: _optionalText(data['genre_name']),
      followers: _optionalNonNegativeInt(data['follower_num']),
      totalViewers: _optionalNonNegativeInt(data['view_num']),
      telop: _optionalText(data['telop']),
      streams: streams,
    );
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map) throw const ShowroomException(ShowroomFailure.schema);
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static List<dynamic> _list(Object? value, {required int max}) {
    if (value is! List || value.length > max) throw const ShowroomException(ShowroomFailure.schema);
    return value;
  }

  static int _positiveInt(Object? value) {
    final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
    if (parsed == null || parsed <= 0) throw const ShowroomException(ShowroomFailure.schema);
    return parsed;
  }

  static int _nonNegativeInt(Object? value) {
    final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
    if (parsed == null || parsed < 0) throw const ShowroomException(ShowroomFailure.schema);
    return parsed;
  }

  static int? _optionalNonNegativeInt(Object? value) {
    if (value == null || value == '') return null;
    return _nonNegativeInt(value);
  }

  static bool _bool(Object? value) {
    if (value is! bool) throw const ShowroomException(ShowroomFailure.schema);
    return value;
  }

  static String _text(Object? value) {
    if (value is! String || value.trim().isEmpty || value.length > 8192) {
      throw const ShowroomException(ShowroomFailure.schema);
    }
    return value.trim();
  }

  static String _optionalText(Object? value) {
    if (value == null) return '';
    if (value is! String || value.length > 131072) throw const ShowroomException(ShowroomFailure.schema);
    return value.trim();
  }

  static String _slug(Object? value) {
    final result = _text(value);
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(result)) {
      throw const ShowroomException(ShowroomFailure.identity);
    }
    return result;
  }

  static bool _trustedHost(String host) =>
      host == 'showroom-live.com' ||
      host.endsWith('.showroom-live.com') ||
      host == 'showroom-txlive.com' ||
      host.endsWith('.showroom-txlive.com');

  static String _image(Object? value) {
    if (value is! String || value.length > 8192) return '';
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' && uri.userInfo.isEmpty && _trustedHost(uri.host.toLowerCase())
        ? value
        : '';
  }

  static String mediaUrl(Object? value) {
    if (value is! String || value.length > 8192 || value.contains(RegExp(r'[\s\x00-\x1f]'))) {
      throw const ShowroomException(ShowroomFailure.schema);
    }
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.host.isEmpty ||
        uri.hasFragment ||
        !_trustedHost(uri.host.toLowerCase())) {
      throw const ShowroomException(ShowroomFailure.schema);
    }
    return value;
  }
}
