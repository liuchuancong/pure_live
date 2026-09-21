import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/common/request_scope.dart';

import 'pandalive_link.dart';

enum PandaLiveFailure {
  transport,
  access,
  missing,
  rateLimited,
  service,
  api,
  schema,
  identity,
  restricted,
  cancelled,
  unknownState,
  mediaUnavailable,
}

class PandaLiveException implements Exception {
  const PandaLiveException(this.kind);
  final PandaLiveFailure kind;

  @override
  String toString() => 'PandaTV ${kind.name}';
}

enum PandaLiveState { live, offline, unknown }

enum PandaLiveAccess { public, password, adult, restricted }

final class PandaLiveCard {
  const PandaLiveCard({
    required this.userId,
    required this.userIndex,
    required this.nickname,
    required this.title,
    required this.avatar,
    required this.cover,
    required this.category,
    required this.onlineViewers,
    required this.followers,
    required this.isAdult,
    required this.isPassword,
  });

  final String userId;
  final int userIndex;
  final String nickname;
  final String title;
  final String avatar;
  final String cover;
  final String category;
  final int? onlineViewers;
  final int? followers;
  final bool isAdult;
  final bool isPassword;
}

final class PandaLiveDirectoryPage {
  PandaLiveDirectoryPage({required Iterable<PandaLiveCard> rooms, required this.page, required this.hasMore})
    : rooms = List.unmodifiable(rooms);

  final List<PandaLiveCard> rooms;
  final int page;
  final bool hasMore;
}

final class PandaLiveStream {
  const PandaLiveStream({
    required this.id,
    required this.label,
    required this.height,
    required this.frameRate,
    required this.bandwidth,
    required this.uri,
  });

  final String id;
  final String label;
  final int height;
  final double frameRate;
  final int bandwidth;
  final Uri uri;
}

final class PandaLiveRoom {
  PandaLiveRoom({
    required this.userId,
    required this.userIndex,
    required this.nickname,
    required this.title,
    required this.avatar,
    required this.cover,
    required this.introduction,
    required this.category,
    required this.followers,
    required this.onlineViewers,
    required this.state,
    required this.access,
    required Iterable<PandaLiveStream> streams,
  }) : streams = List.unmodifiable(streams);

  final String userId;
  final int userIndex;
  final String nickname;
  final String title;
  final String avatar;
  final String cover;
  final String introduction;
  final String category;
  final int? followers;
  final int? onlineViewers;
  final PandaLiveState state;
  final PandaLiveAccess access;
  final List<PandaLiveStream> streams;
}

typedef PandaLiveRequest = Future<({int status, String body})> Function(
  String method,
  Uri uri,
  Map<String, String>? form,
  String referer,
  CancelToken cancel,
);

/// Public PandaTV Web contract. Media tokens are scoped to the official
/// Origin, so every metadata, manifest, playback and recording path shares
/// the same request fields.
class PandaLiveApi {
  PandaLiveApi({PandaLiveRequest? request, this.deadline = const Duration(seconds: 20)})
    : _request = request ?? _defaultRequest;

  static const origin = 'https://www.pandalive.co.kr';
  static const apiOrigin = 'https://api.pandalive.co.kr';
  static const responseLimit = 4 * 1024 * 1024;
  static const manifestLimit = 1024 * 1024;
  static const userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';

  static Map<String, String> requestHeaders(String referer) => {
    'User-Agent': userAgent,
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'ko-KR,ko;q=0.9,en;q=0.8',
    'Origin': origin,
    'Referer': referer,
  };

  static Map<String, String> mediaHeaders(String userId) => {
    'User-Agent': userAgent,
    'Origin': origin,
    'Referer': PandaLiveLink.url(userId),
  };

  final PandaLiveRequest _request;
  final Duration deadline;

  static Future<({int status, String body})> _defaultRequest(
    String method,
    Uri uri,
    Map<String, String>? form,
    String referer,
    CancelToken cancel,
  ) async {
    final response = await HttpClient.instance.dio.request<ResponseBody>(
      uri.toString(),
      data: form,
      cancelToken: cancel,
      options: Options(
        method: method,
        responseType: ResponseType.stream,
        followRedirects: false,
        headers: requestHeaders(referer),
        contentType: form == null ? null : Headers.formUrlEncodedContentType,
        receiveTimeout: const Duration(seconds: 20),
        validateStatus: (_) => true,
      ),
    );
    final body = response.data;
    if (body == null) throw const PandaLiveException(PandaLiveFailure.schema);
    if (response.statusCode != 200) {
      await body.stream.listen((_) {}).cancel();
      return (status: response.statusCode ?? 0, body: '');
    }
    return (status: 200, body: await readBody(body.stream, limit: method == 'GET' ? manifestLimit : responseLimit));
  }

  static Future<String> readBody(
    Stream<List<int>> source, {
    int limit = responseLimit,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final iterator = StreamIterator(source);
    final bytes = BytesBuilder(copy: false);
    final watch = Stopwatch()..start();
    try {
      while (true) {
        final remaining = timeout - watch.elapsed;
        if (remaining <= Duration.zero) throw TimeoutException('PandaTV response deadline');
        if (!await iterator.moveNext().timeout(remaining)) break;
        if (bytes.length + iterator.current.length > limit) {
          throw const PandaLiveException(PandaLiveFailure.schema);
        }
        bytes.add(iterator.current);
      }
      return utf8.decode(bytes.takeBytes());
    } on FormatException {
      throw const PandaLiveException(PandaLiveFailure.schema);
    } finally {
      watch.stop();
      await iterator.cancel();
    }
  }

  Future<T> _scope<T>(CancelToken? caller, Future<T> Function(CancelToken) work) =>
      withRequestCancellation(caller, (transport) async {
        if (transport.isCancelled) throw const PandaLiveException(PandaLiveFailure.cancelled);
        try {
          return await Future.any<T>([
            work(transport),
            transport.whenCancel.then<T>((_) => throw const PandaLiveException(PandaLiveFailure.cancelled)),
          ]).timeout(deadline);
        } on TimeoutException {
          throw const PandaLiveException(PandaLiveFailure.transport);
        } catch (error) {
          if (caller?.isCancelled == true) throw const PandaLiveException(PandaLiveFailure.cancelled);
          if (error is PandaLiveException) rethrow;
          throw const PandaLiveException(PandaLiveFailure.transport);
        }
      });

  Future<String> _read(
    String method,
    Uri uri,
    Map<String, String>? form,
    String referer,
    CancelToken cancel, {
    bool manifest = false,
  }) async {
    if (cancel.isCancelled) throw const PandaLiveException(PandaLiveFailure.cancelled);
    final response = await _request(method, uri, form, referer, cancel);
    if (cancel.isCancelled) throw const PandaLiveException(PandaLiveFailure.cancelled);
    final failure = switch (response.status) {
      200 => null,
      400 => PandaLiveFailure.schema,
      401 || 403 => PandaLiveFailure.access,
      404 => PandaLiveFailure.missing,
      429 => PandaLiveFailure.rateLimited,
      >= 500 => PandaLiveFailure.service,
      _ => PandaLiveFailure.transport,
    };
    if (failure != null) throw PandaLiveException(failure);
    final limit = manifest ? manifestLimit : responseLimit;
    if (response.body.length > limit || utf8.encode(response.body).length > limit) {
      throw const PandaLiveException(PandaLiveFailure.schema);
    }
    return response.body;
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, String> form, String referer, CancelToken cancel) async {
    final body = await _read('POST', Uri.parse('$apiOrigin$path'), form, referer, cancel);
    try {
      return _object(jsonDecode(body));
    } on FormatException {
      throw const PandaLiveException(PandaLiveFailure.schema);
    }
  }

  Future<PandaLiveDirectoryPage> directory({int page = 1, int size = 30, CancelToken? cancel}) =>
      _scope(cancel, (token) async {
        if (page < 1 || page > 1000 || size < 1 || size > 50) {
          throw const PandaLiveException(PandaLiveFailure.schema);
        }
        final offset = (page - 1) * size;
        final root = await _post(
          '/v1/live/index',
          {'offset': '$offset', 'limit': '$size', 'orderBy': 'hot'},
          '$origin/live',
          token,
        );
        _requireSuccess(root);
        final paging = _object(root['page']);
        if (_nonNegativeInt(paging['offset']) != offset || _positiveInt(paging['limit']) != size) {
          throw const PandaLiveException(PandaLiveFailure.identity);
        }
        final total = _nonNegativeInt(paging['total']);
        final responsePage = _positiveInt(paging['page']);
        if (responsePage != page) throw const PandaLiveException(PandaLiveFailure.identity);
        final rooms = _list(root['list'], max: 64).map((value) => parseCard(_object(value))).toList(growable: false);
        return PandaLiveDirectoryPage(rooms: rooms, page: page, hasMore: offset + rooms.length < total);
      });

  Future<PandaLiveRoom> room(String rawUserId, {bool resolveMedia = true, CancelToken? cancel}) =>
      _scope(cancel, (token) async {
        final userId = PandaLiveLink.normalizeUserId(rawUserId);
        if (userId == null) throw const PandaLiveException(PandaLiveFailure.identity);
        final referer = PandaLiveLink.url(userId);
        final member = await _post('/v1/member/bj', {'userId': userId, 'info': 'media fanGrade'}, referer, token);
        if (member['result'] != true) {
          final message = _optionalText(member['message']);
          if (message.contains('유저 정보가 없습니다')) throw const PandaLiveException(PandaLiveFailure.missing);
          throw const PandaLiveException(PandaLiveFailure.api);
        }
        final profile = _object(member['bjInfo']);
        final profileId = PandaLiveLink.normalizeUserId(profile['id']);
        if (profileId == null || profileId.toLowerCase() != userId.toLowerCase()) {
          throw const PandaLiveException(PandaLiveFailure.identity);
        }
        final profileIndex = _positiveInt(profile['idx']);
        final mediaValue = member['media'];
        if (mediaValue == null) {
          return _profileRoom(userId, profileIndex, profile);
        }
        final memberMedia = _object(mediaValue);
        _validateMediaIdentity(memberMedia, userId, profileIndex);
        if (!resolveMedia) {
          return _restrictedRoom(userId, profileIndex, profile, memberMedia, PandaLiveAccess.public);
        }
        final play = await _post(
          '/v1/live/play',
          {'action': 'watch', 'userId': userId, 'password': '', 'shareLinkType': ''},
          referer,
          token,
        );
        if (play['result'] != true) {
          final errorData = play['errorData'];
          final code = errorData is Map ? _optionalText(_object(errorData)['code']) : '';
          if (code == 'castEnd') return _profileRoom(userId, profileIndex, profile);
          final access = switch (code) {
            'needAdult' => PandaLiveAccess.adult,
            'needPassword' || 'password' => PandaLiveAccess.password,
            _ => PandaLiveAccess.restricted,
          };
          return _restrictedRoom(userId, profileIndex, profile, memberMedia, access);
        }
        final playMedia = _object(play['media']);
        _validateMediaIdentity(playMedia, userId, profileIndex);
        if (_bool(playMedia['isLive']) != true) return _profileRoom(userId, profileIndex, profile);
        final playlist = _object(play['PlayList']);
        final master = _firstMaster(playlist);
        final manifest = await _read('GET', master, null, referer, token, manifest: true);
        final streams = parseManifest(master, manifest);
        if (streams.isEmpty) throw const PandaLiveException(PandaLiveFailure.mediaUnavailable);
        return _liveRoom(userId, profileIndex, profile, playMedia, streams);
      });

  static PandaLiveCard parseCard(Map<String, dynamic> data) {
    final userId = _userId(data['userId']);
    final live = _bool(data['isLive']);
    if (live != true) throw const PandaLiveException(PandaLiveFailure.schema);
    final userIndex = _positiveInt(data['userIdx']);
    return PandaLiveCard(
      userId: userId,
      userIndex: userIndex,
      nickname: _text(data['userNick']),
      title: _text(data['title']),
      avatar: _image(data['userImg']),
      cover: _image(data['thumbUrl'] ?? data['ivsThumbnail']),
      category: _optionalText(data['category']),
      onlineViewers: _optionalNonNegativeInt(data['user']),
      followers: _optionalNonNegativeInt(data['fanCnt']),
      isAdult: _bool(data['isAdult']) ?? false,
      isPassword: _bool(data['isPw']) ?? false,
    );
  }

  static List<PandaLiveStream> parseManifest(Uri master, String source) {
    _mediaUri(master.toString());
    if (source.length > manifestLimit || !source.trimLeft().startsWith('#EXTM3U')) {
      throw const PandaLiveException(PandaLiveFailure.schema);
    }
    final lines = const LineSplitter().convert(source);
    final streams = <PandaLiveStream>[];
    final ids = <String>{};
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index].trim();
      if (!line.startsWith('#EXT-X-STREAM-INF:')) continue;
      final attributes = _attributes(line.substring('#EXT-X-STREAM-INF:'.length));
      var next = index + 1;
      while (next < lines.length && lines[next].trim().isEmpty) {
        next++;
      }
      if (next >= lines.length || lines[next].trim().startsWith('#')) {
        throw const PandaLiveException(PandaLiveFailure.schema);
      }
      final resolution = attributes['RESOLUTION'];
      final match = resolution == null ? null : RegExp(r'^[1-9][0-9]{1,4}x([1-9][0-9]{1,4})$').firstMatch(resolution);
      if (match == null) throw const PandaLiveException(PandaLiveFailure.schema);
      final height = int.parse(match.group(1)!);
      final frameRate = double.tryParse(attributes['FRAME-RATE'] ?? '') ?? 0;
      final bandwidth = int.tryParse(attributes['BANDWIDTH'] ?? '') ?? 0;
      if (frameRate < 0 || frameRate > 240 || bandwidth < 0) {
        throw const PandaLiveException(PandaLiveFailure.schema);
      }
      final uri = _mediaUri(master.resolve(lines[next].trim()).toString());
      final fps = frameRate >= 50
          ? '60'
          : frameRate >= 25
          ? '30'
          : '';
      final baseId = '${height}p$fps';
      final id = ids.add(baseId) ? baseId : '${baseId}_${streams.length + 1}';
      streams.add(
        PandaLiveStream(id: id, label: baseId, height: height, frameRate: frameRate, bandwidth: bandwidth, uri: uri),
      );
      index = next;
    }
    streams.sort((left, right) {
      final resolution = right.height.compareTo(left.height);
      if (resolution != 0) return resolution;
      final fps = right.frameRate.compareTo(left.frameRate);
      return fps != 0 ? fps : right.bandwidth.compareTo(left.bandwidth);
    });
    return List.unmodifiable(streams);
  }

  static PandaLiveRoom _profileRoom(String userId, int userIndex, Map<String, dynamic> profile) => PandaLiveRoom(
    userId: userId,
    userIndex: userIndex,
    nickname: _text(profile['nick']),
    title: _firstText([profile['channelTitle'], profile['nick']]),
    avatar: _image(profile['thumbUrl']),
    cover: _image(profile['channelBannerUrl']),
    introduction: _optionalText(profile['channelDesc']),
    category: '',
    followers: _optionalNonNegativeInt(profile['fanCnt']),
    onlineViewers: null,
    state: PandaLiveState.offline,
    access: PandaLiveAccess.public,
    streams: const [],
  );

  static PandaLiveRoom _restrictedRoom(
    String userId,
    int userIndex,
    Map<String, dynamic> profile,
    Map<String, dynamic> media,
    PandaLiveAccess access,
  ) => PandaLiveRoom(
    userId: userId,
    userIndex: userIndex,
    nickname: _text(media['userNick'] ?? profile['nick']),
    title: _firstText([media['title'], profile['channelTitle'], profile['nick']]),
    avatar: _image(media['userImg'] ?? profile['thumbUrl']),
    cover: _image(media['thumbUrl'] ?? profile['channelBannerUrl']),
    introduction: _optionalText(profile['channelDesc']),
    category: _optionalText(media['category']),
    followers: _optionalNonNegativeInt(media['fanCnt'] ?? profile['fanCnt']),
    onlineViewers: _optionalNonNegativeInt(media['user']),
    state: PandaLiveState.live,
    access: access,
    streams: const [],
  );

  static PandaLiveRoom _liveRoom(
    String userId,
    int userIndex,
    Map<String, dynamic> profile,
    Map<String, dynamic> media,
    List<PandaLiveStream> streams,
  ) => PandaLiveRoom(
    userId: userId,
    userIndex: userIndex,
    nickname: _text(media['userNick'] ?? profile['nick']),
    title: _firstText([media['title'], profile['channelTitle'], profile['nick']]),
    avatar: _image(media['userImg'] ?? profile['thumbUrl']),
    cover: _image(media['thumbUrl'] ?? media['ivsThumbnail'] ?? profile['channelBannerUrl']),
    introduction: _optionalText(profile['channelDesc']),
    category: _optionalText(media['category']),
    followers: _optionalNonNegativeInt(media['fanCnt'] ?? profile['fanCnt']),
    onlineViewers: _optionalNonNegativeInt(media['user']),
    state: PandaLiveState.live,
    access: PandaLiveAccess.public,
    streams: streams,
  );

  static void _validateMediaIdentity(Map<String, dynamic> media, String userId, int userIndex) {
    final responseId = _userId(media['userId']);
    if (responseId.toLowerCase() != userId.toLowerCase() || _positiveInt(media['userIdx']) != userIndex) {
      throw const PandaLiveException(PandaLiveFailure.identity);
    }
  }

  static Uri _firstMaster(Map<String, dynamic> playlist) {
    for (final key in const ['hls3', 'hls2', 'hls']) {
      final value = playlist[key];
      if (value == null) continue;
      for (final item in _list(value, max: 16)) {
        final url = _object(item)['url'];
        if (url is String && url.isNotEmpty) return _mediaUri(url);
      }
    }
    throw const PandaLiveException(PandaLiveFailure.mediaUnavailable);
  }

  static Uri _mediaUri(String raw) {
    if (raw.isEmpty || raw.length > 65536 || RegExp(r'[\s\x00-\x1f]').hasMatch(raw)) {
      throw const PandaLiveException(PandaLiveFailure.schema);
    }
    final uri = Uri.tryParse(raw);
    final host = uri?.host.toLowerCase() ?? '';
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !host.endsWith('.live-video.net') ||
        !uri.path.toLowerCase().endsWith('.m3u8')) {
      throw const PandaLiveException(PandaLiveFailure.schema);
    }
    return uri;
  }

  static Map<String, String> _attributes(String raw) {
    final result = <String, String>{};
    for (final match in RegExp(r'([A-Z0-9-]+)=("[^"]*"|[^,]*)').allMatches(raw)) {
      var value = match.group(2)!;
      if (value.startsWith('"') && value.endsWith('"')) value = value.substring(1, value.length - 1);
      result[match.group(1)!] = value;
    }
    return result;
  }

  static void _requireSuccess(Map<String, dynamic> root) {
    if (root['result'] is! bool) throw const PandaLiveException(PandaLiveFailure.schema);
    if (root['result'] != true) throw const PandaLiveException(PandaLiveFailure.api);
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map) throw const PandaLiveException(PandaLiveFailure.schema);
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static List<Object?> _list(Object? value, {required int max}) {
    if (value is! List || value.length > max) throw const PandaLiveException(PandaLiveFailure.schema);
    return value;
  }

  static String _userId(Object? value) {
    final userId = PandaLiveLink.normalizeUserId(value);
    if (userId == null) throw const PandaLiveException(PandaLiveFailure.identity);
    return userId;
  }

  static String _text(Object? value) {
    if (value is! String || value.trim().isEmpty || value.length > 8192) {
      throw const PandaLiveException(PandaLiveFailure.schema);
    }
    return value.trim();
  }

  static String _firstText(Iterable<Object?> values) {
    for (final value in values) {
      final text = _optionalText(value);
      if (text.isNotEmpty) return text;
    }
    throw const PandaLiveException(PandaLiveFailure.schema);
  }

  static String _optionalText(Object? value) {
    if (value == null) return '';
    if (value is! String || value.length > 8192) throw const PandaLiveException(PandaLiveFailure.schema);
    return value.trim();
  }

  static String _image(Object? value) {
    final raw = _optionalText(value);
    if (raw.isEmpty) return '';
    final uri = Uri.tryParse(raw);
    final host = uri?.host.toLowerCase() ?? '';
    if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty || !host.endsWith('.pandalive.co.kr')) {
      throw const PandaLiveException(PandaLiveFailure.schema);
    }
    return uri.toString();
  }

  static bool? _bool(Object? value) => switch (value) {
    bool boolean => boolean,
    'Y' || 'y' || 1 => true,
    'N' || 'n' || 0 => false,
    null => null,
    _ => throw const PandaLiveException(PandaLiveFailure.schema),
  };

  static int _positiveInt(Object? value) {
    final number = switch (value) {
      int integer => integer,
      String text when RegExp(r'^[1-9][0-9]{0,15}$').hasMatch(text) => int.parse(text),
      _ => 0,
    };
    if (number <= 0) throw const PandaLiveException(PandaLiveFailure.schema);
    return number;
  }

  static int _nonNegativeInt(Object? value) {
    final number = switch (value) {
      int integer => integer,
      String text when RegExp(r'^[0-9]{1,16}$').hasMatch(text) => int.parse(text),
      _ => -1,
    };
    if (number < 0) throw const PandaLiveException(PandaLiveFailure.schema);
    return number;
  }

  static int? _optionalNonNegativeInt(Object? value) => value == null ? null : _nonNegativeInt(value);
}
