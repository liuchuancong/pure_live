import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/common/request_scope.dart';

import 'liveme_link.dart';
import 'liveme_signer.dart';

enum LiveMeFailure {
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

class LiveMeException implements Exception {
  const LiveMeException(this.kind);

  final LiveMeFailure kind;

  @override
  String toString() => 'LiveMe ${kind.name}';
}

enum LiveMeState { live, offline, restricted, unknown }

class LiveMeStream {
  LiveMeStream({required this.qualityId, required this.protocol, required Iterable<Uri> urls})
    : urls = List.unmodifiable(urls);

  final String qualityId;
  final String protocol;
  final List<Uri> urls;
}

class LiveMeRoom {
  LiveMeRoom({
    required this.shortId,
    required this.userId,
    required this.videoId,
    required this.nickname,
    required this.title,
    required this.avatar,
    required this.cover,
    required this.bio,
    required this.countryCode,
    required this.followers,
    required this.currentViewers,
    required this.totalViewers,
    required this.heat,
    required this.likes,
    required this.state,
    required Iterable<LiveMeStream> streams,
  }) : streams = List.unmodifiable(streams);

  final String shortId;
  final String userId;
  final String videoId;
  final String nickname;
  final String title;
  final String avatar;
  final String cover;
  final String bio;
  final String countryCode;
  final int? followers;
  final int? currentViewers;
  final int? totalViewers;
  final int? heat;
  final int? likes;
  final LiveMeState state;
  final List<LiveMeStream> streams;
}

class LiveMeDirectoryPage {
  LiveMeDirectoryPage({required Iterable<LiveMeRoom> rooms, required this.hasMore}) : rooms = List.unmodifiable(rooms);

  final List<LiveMeRoom> rooms;
  final bool hasMore;
}

class LiveMeSearchPage {
  LiveMeSearchPage({required Iterable<LiveMeRoom> rooms, required this.hasMore}) : rooms = List.unmodifiable(rooms);

  final List<LiveMeRoom> rooms;
  final bool hasMore;
}

typedef LiveMeRequest = Future<({int status, String body})> Function({
  required String method,
  required Uri uri,
  required Map<String, String> headers,
  Map<String, String>? form,
  CancelToken? cancel,
});

class LiveMeApi {
  LiveMeApi({LiveMeRequest? request, LiveMeSigner? signer})
    : _request = request ?? _defaultRequest,
      _signer = signer ?? LiveMeSigner();

  static const origin = 'https://www.liveme.com';
  static const apiOrigin = 'https://live.liveme.com';
  static const directoryOrigin = 'https://lvapi.liveme.com';
  static const responseLimit = 8 * 1024 * 1024;
  static const userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';

  final LiveMeRequest _request;
  final LiveMeSigner _signer;

  static Map<String, String> requestHeaders({String? shortId}) => {
    'User-Agent': userAgent,
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'en-US,en;q=0.9',
    'Origin': origin,
    'Referer': shortId == null ? '$origin/livehot' : LiveMeLink.url(shortId),
  };

  static Map<String, String> mediaHeaders(String shortId) => {
    'User-Agent': userAgent,
    'Origin': origin,
    'Referer': LiveMeLink.url(shortId),
  };

  static Future<({int status, String body})> _defaultRequest({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    Map<String, String>? form,
    CancelToken? cancel,
  }) => withRequestCancellation(cancel, (transport) async {
    final response = await HttpClient.instance.dio.request<ResponseBody>(
      uri.toString(),
      data: form,
      cancelToken: transport,
      options: Options(
        method: method,
        responseType: ResponseType.stream,
        followRedirects: false,
        contentType: form == null ? null : Headers.formUrlEncodedContentType,
        headers: headers,
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        validateStatus: (_) => true,
      ),
    );
    final body = response.data;
    if (body == null) throw const LiveMeException(LiveMeFailure.schema);
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
        if (remaining <= Duration.zero) throw TimeoutException('LiveMe response deadline');
        if (!await iterator.moveNext().timeout(remaining)) break;
        final chunk = iterator.current;
        if (bytes.length + chunk.length > responseLimit) {
          throw const LiveMeException(LiveMeFailure.schema);
        }
        bytes.add(chunk);
      }
      return utf8.decode(bytes.takeBytes());
    } on FormatException {
      throw const LiveMeException(LiveMeFailure.schema);
    } finally {
      watch.stop();
      await iterator.cancel();
    }
  }

  Future<Map<String, dynamic>> _json({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    Map<String, String>? form,
    CancelToken? cancel,
  }) async {
    if (cancel?.isCancelled == true) throw const LiveMeException(LiveMeFailure.cancelled);
    late final ({int status, String body}) response;
    try {
      response = await _request(method: method, uri: uri, headers: headers, form: form, cancel: cancel);
    } catch (error) {
      if (cancel?.isCancelled == true || (error is DioException && CancelToken.isCancel(error))) {
        throw const LiveMeException(LiveMeFailure.cancelled);
      }
      if (error is LiveMeException) rethrow;
      throw const LiveMeException(LiveMeFailure.transport);
    }
    if (cancel?.isCancelled == true) throw const LiveMeException(LiveMeFailure.cancelled);
    final failure = switch (response.status) {
      200 => null,
      400 => LiveMeFailure.schema,
      401 || 403 => LiveMeFailure.access,
      404 => LiveMeFailure.missing,
      420 || 429 => LiveMeFailure.rateLimited,
      >= 500 => LiveMeFailure.service,
      _ => LiveMeFailure.transport,
    };
    if (failure != null) throw LiveMeException(failure);
    if (response.body.length > responseLimit) throw const LiveMeException(LiveMeFailure.schema);
    try {
      final root = _object(jsonDecode(response.body));
      final apiStatus = _integer(root['status']);
      if (apiStatus == null) throw const LiveMeException(LiveMeFailure.schema);
      if (apiStatus == 200) return root;
      throw LiveMeException(switch (apiStatus) {
        400 || 404 => LiveMeFailure.missing,
        401 || 403 => LiveMeFailure.access,
        420 || 429 => LiveMeFailure.rateLimited,
        >= 500 => LiveMeFailure.service,
        _ => LiveMeFailure.schema,
      });
    } on FormatException {
      throw const LiveMeException(LiveMeFailure.schema);
    }
  }

  Map<String, String> _guestQuery({bool includeTime = true}) => {
    'alias': 'liveme',
    'tongdun_black_box': '1',
    'os': 'web',
    if (includeTime) '_time': '${DateTime.now().millisecondsSinceEpoch}',
    'h5': '1',
    'thirdchannel': '6',
  };

  Future<LiveMeDirectoryPage> directory({int page = 1, int pageSize = 20, CancelToken? cancel}) async {
    if (page < 1 || pageSize < 1 || pageSize > 50) {
      throw const LiveMeException(LiveMeFailure.schema);
    }
    final root = await _json(
      method: 'GET',
      uri: Uri.parse('$directoryOrigin/live/featurelist').replace(
        queryParameters: {
          'countryCode': 'GLOBAL',
          'page_index': '$page',
          'page_size': '$pageSize',
          'pid': '3',
          'posid': '3002',
          'h5': '1',
        },
      ),
      headers: requestHeaders(),
      cancel: cancel,
    );
    final data = _object(root['data']);
    final rooms = <LiveMeRoom>[];
    final seen = <String>{};
    for (final raw in _list(data['video_info'], max: 100)) {
      final room = _videoRoom(_object(raw), includeMedia: false);
      if (room.state != LiveMeState.restricted && seen.add(room.shortId)) rooms.add(room);
    }
    return LiveMeDirectoryPage(rooms: rooms, hasMore: _integer(data['next_page']) == 1);
  }

  Future<LiveMeSearchPage> search(String keyword, {int page = 1, int pageSize = 30, CancelToken? cancel}) async {
    final query = keyword.trim();
    if (query.isEmpty || query.length > 256 || page < 1 || pageSize < 1 || pageSize > 40) {
      throw const LiveMeException(LiveMeFailure.schema);
    }
    final root = await _json(
      method: 'GET',
      uri: Uri.parse('$apiOrigin/search/searchKeyword').replace(
        queryParameters: {
          ..._guestQuery(),
          'type': '1',
          'page': '$page',
          'pageSize': '$pageSize',
          'keyword': query,
          'tuid': '',
          'uid': '',
          'token': '',
          'androidid': '',
        },
      ),
      headers: requestHeaders(),
      cancel: cancel,
    );
    final data = _object(root['data']);
    final rows = _list(data['data_info'], max: 100);
    final rooms = <LiveMeRoom>[];
    final seen = <String>{};
    for (final raw in rows) {
      final row = _object(raw);
      final shortId = _shortId(row['short_id']);
      if (!seen.add(shortId)) continue;
      final nickname = _firstText([row['nickname'], row['uname']]);
      final project = _optionalText(row['project']).toLowerCase();
      final isLive = _integer(row['is_live']);
      rooms.add(
        LiveMeRoom(
          shortId: shortId,
          userId: _longId(row['user_id']),
          videoId: '',
          nickname: nickname,
          title: nickname,
          avatar: _image(row['face']),
          cover: '',
          bio: '',
          countryCode: _country(row['countryCode']),
          followers: _optionalNonNegativeInt(row['fans_num'] ?? row['follower_count']),
          currentViewers: null,
          totalViewers: null,
          heat: null,
          likes: null,
          // The federated emolm/alive/highlive projects may report is_live=0
          // while their public LiveMe room is active. Keep those rows pending
          // until room lookup; the primary liveme project has reliable zeros.
          state: isLive == 1
              ? LiveMeState.live
              : isLive == 0 && project == 'liveme'
              ? LiveMeState.offline
              : LiveMeState.unknown,
          streams: const [],
        ),
      );
    }
    return LiveMeSearchPage(rooms: rooms, hasMore: rows.length >= pageSize);
  }

  Future<String> resolveReference(LiveMeLink reference, {CancelToken? cancel}) async {
    switch (reference.kind) {
      case LiveMeLinkKind.shortId:
        return _shortId(reference.id);
      case LiveMeLinkKind.userId:
        return (await _profile(reference.id, cancel: cancel)).shortId;
      case LiveMeLinkKind.videoId:
        return (await _video(reference.id, includeMedia: false, cancel: cancel)).shortId;
    }
  }

  Future<LiveMeRoom> room(String rawShortId, {required bool includeMedia, CancelToken? cancel}) async {
    final shortId = LiveMeLink.normalizeShortId(rawShortId);
    if (shortId == null) throw const LiveMeException(LiveMeFailure.identity);
    final mapping = await _mapping(shortId, cancel: cancel);
    final profileFuture = _profile(mapping.userId, cancel: cancel);
    if (mapping.videoId.isEmpty) {
      return _offlineRoom(await profileFuture, expectedShortId: shortId);
    }
    final results = await Future.wait<Object>([
      profileFuture,
      _video(mapping.videoId, expectedShortId: shortId, includeMedia: includeMedia, cancel: cancel),
    ]);
    final profile = results[0] as _LiveMeProfile;
    final video = results[1] as LiveMeRoom;
    if (profile.shortId != shortId || profile.userId != mapping.userId || video.userId != mapping.userId) {
      throw const LiveMeException(LiveMeFailure.identity);
    }
    return _mergeProfile(video, profile);
  }

  Future<({String userId, String videoId})> _mapping(String shortId, {CancelToken? cancel}) async {
    final root = await _json(
      method: 'GET',
      uri: Uri.parse('$apiOrigin/liveme_ent/v1/user/uid_vid_by_short_id')
          .replace(queryParameters: {..._guestQuery(), 'short_id': shortId}),
      headers: requestHeaders(shortId: shortId),
      cancel: cancel,
    );
    final data = _object(root['data']);
    final userId = _longId(data['uid']);
    final rawVideoId = _optionalText(data['vid']);
    final videoId = rawVideoId.isEmpty ? '' : _longId(rawVideoId);
    return (userId: userId, videoId: videoId);
  }

  Future<_LiveMeProfile> _profile(String rawUserId, {CancelToken? cancel}) async {
    final userId = _longId(rawUserId);
    final root = await _json(
      method: 'GET',
      uri: Uri.parse('$apiOrigin/user/getinfo').replace(queryParameters: {..._guestQuery(), 'userid': userId}),
      headers: requestHeaders(),
      cancel: cancel,
    );
    final user = _object(_object(root['data'])['user']);
    final info = _object(user['user_info']);
    final actualUserId = _longId(info['uid'] ?? info['userid'] ?? info['cm_openid']);
    if (actualUserId != userId) throw const LiveMeException(LiveMeFailure.identity);
    final counts = _object(user['count_info']);
    return _LiveMeProfile(
      shortId: _shortId(info['short_id']),
      userId: actualUserId,
      nickname: _firstText([info['nickname'], info['uname']]),
      avatar: _image(info['big_face'] ?? info['face']),
      cover: _image(info['big_cover'] ?? info['cover']),
      bio: _optionalText(info['usign']),
      countryCode: _country(info['countryCode']),
      followers: _optionalNonNegativeInt(counts['follower_count']),
    );
  }

  Future<LiveMeRoom> _video(
    String rawVideoId, {
    String? expectedShortId,
    required bool includeMedia,
    CancelToken? cancel,
  }) async {
    final videoId = _longId(rawVideoId);
    final query = <String, String>{'alias': 'liveme', 'tongdun_black_box': '1', 'os': 'web'};
    final signed = _signer.sign(
      query: query,
      body: {
        '_time': '${DateTime.now().millisecondsSinceEpoch}',
        'thirdchannel': '6',
        'videoid': videoId,
        'area': 'en',
        'vali': _signer.vali(),
      },
    );
    final root = await _json(
      method: 'POST',
      uri: Uri.parse('$apiOrigin/live/queryinfosimple').replace(queryParameters: query),
      headers: {
        ...requestHeaders(shortId: expectedShortId),
        'lm-s-sign': signed.signature,
      },
      form: signed.fields,
      cancel: cancel,
    );
    final data = _object(root['data']);
    final room = _videoRoom(
      _object(data['video_info']),
      user: data['user_info'] is Map ? _object(data['user_info']) : const {},
      includeMedia: includeMedia,
      expectedShortId: expectedShortId,
      expectedVideoId: videoId,
    );
    return room;
  }

  static LiveMeRoom _videoRoom(
    Map<String, dynamic> video, {
    Map<String, dynamic> user = const {},
    bool includeMedia = false,
    String? expectedShortId,
    String? expectedVideoId,
  }) {
    final shortId = _shortId(video['ushortid'] ?? user['short_id']);
    final userId = _longId(video['userid'] ?? user['userid'] ?? user['uid']);
    final rawVideoId = _optionalText(video['vid'] ?? video['vdoid']);
    final videoId = rawVideoId.isEmpty ? '' : _longId(rawVideoId);
    if ((expectedShortId != null && shortId != expectedShortId) ||
        (expectedVideoId != null && videoId != expectedVideoId)) {
      throw const LiveMeException(LiveMeFailure.identity);
    }
    final restricted =
        _integer(video['ispvt']) == 1 ||
        _integer(video['livebptype']) == 7 ||
        _optionalText(video['hot_label_v2'] is Map ? _object(video['hot_label_v2'])['text'] : null).toLowerCase() ==
            'paid broadcast';
    final online = _integer(video['online']);
    final status = _integer(video['status']);
    final roomState = _integer(video['roomstate']);
    final state = restricted
        ? LiveMeState.restricted
        : online == 1 && status == 0 && roomState == 0
        ? LiveMeState.live
        : online == 0 || (status != null && status != 0) || (roomState != null && roomState != 0)
        ? LiveMeState.offline
        : LiveMeState.unknown;
    final nickname = _firstText([video['uname'], user['uname'], user['nickname']]);
    final title = _optionalText(video['title']);
    return LiveMeRoom(
      shortId: shortId,
      userId: userId,
      videoId: videoId,
      nickname: nickname,
      title: title.isEmpty ? nickname : title,
      avatar: _image(video['uface'] ?? user['face']),
      cover: _image(video['videocapture'] ?? video['smallcover']),
      bio: _optionalText(user['desc'] ?? user['usign']),
      countryCode: _country(video['countryCode'] ?? video['country_code'] ?? user['countryCode']),
      followers: null,
      currentViewers: state == LiveMeState.live ? _optionalNonNegativeInt(video['playnumber']) : null,
      totalViewers: state == LiveMeState.live ? _optionalNonNegativeInt(video['watchnumber']) : null,
      heat: state == LiveMeState.live ? _optionalNonNegativeInt(video['heat']) : null,
      likes: _optionalNonNegativeInt(video['likenum']),
      state: state,
      streams: state == LiveMeState.live && includeMedia ? _streams(video) : const [],
    );
  }

  static LiveMeRoom _offlineRoom(_LiveMeProfile profile, {required String expectedShortId}) {
    if (profile.shortId != expectedShortId) throw const LiveMeException(LiveMeFailure.identity);
    return LiveMeRoom(
      shortId: profile.shortId,
      userId: profile.userId,
      videoId: '',
      nickname: profile.nickname,
      title: profile.nickname,
      avatar: profile.avatar,
      cover: profile.cover,
      bio: profile.bio,
      countryCode: profile.countryCode,
      followers: profile.followers,
      currentViewers: null,
      totalViewers: null,
      heat: null,
      likes: null,
      state: LiveMeState.offline,
      streams: const [],
    );
  }

  static LiveMeRoom _mergeProfile(LiveMeRoom room, _LiveMeProfile profile) => LiveMeRoom(
    shortId: room.shortId,
    userId: room.userId,
    videoId: room.videoId,
    nickname: room.nickname,
    title: room.title,
    avatar: room.avatar.isEmpty ? profile.avatar : room.avatar,
    cover: room.cover.isEmpty ? profile.cover : room.cover,
    bio: room.bio.isEmpty ? profile.bio : room.bio,
    countryCode: room.countryCode.isEmpty ? profile.countryCode : room.countryCode,
    followers: profile.followers,
    currentViewers: room.currentViewers,
    totalViewers: room.totalViewers,
    heat: room.heat,
    likes: room.likes,
    state: room.state,
    streams: room.streams,
  );

  static List<LiveMeStream> _streams(Map<String, dynamic> video) {
    final result = <LiveMeStream>[];
    void add(String qualityId, String protocol, Iterable<Object?> values) {
      final urls = <Uri>[];
      final seen = <Uri>{};
      for (final value in values) {
        for (final raw in _flattenUrls(value)) {
          final uri = _mediaUri(raw, protocol);
          if (uri != null && seen.add(uri)) urls.add(uri);
        }
      }
      if (urls.isNotEmpty) result.add(LiveMeStream(qualityId: qualityId, protocol: protocol, urls: urls));
    }

    add('source-flv', 'flv', [video['videosource'], video['videosourcemore']]);
    add('smooth-flv', 'flv', [video['smallsource'], video['smallsourcemore']]);
    add('hls', 'hls', [video['hlsvideosource']]);
    return List.unmodifiable(result);
  }

  static Iterable<String> _flattenUrls(Object? value, [int depth = 0]) sync* {
    if (depth > 3 || value == null) return;
    if (value is String) {
      final text = value.trim();
      if (text.startsWith('http://') || text.startsWith('https://')) {
        yield text;
        return;
      }
      if (text.length <= 131072 && (text.startsWith('[') || text.startsWith('{'))) {
        try {
          yield* _flattenUrls(jsonDecode(text), depth + 1);
        } on FormatException {
          return;
        }
      }
      return;
    }
    if (value is List && value.length <= 32) {
      for (final item in value) {
        yield* _flattenUrls(item, depth + 1);
      }
      return;
    }
    if (value is Map && value.length <= 32) {
      for (final item in value.values) {
        yield* _flattenUrls(item, depth + 1);
      }
    }
  }

  static Uri? _mediaUri(String raw, String protocol) {
    if (raw.isEmpty || raw.length > 65536 || raw.contains(RegExp(r'[\s\x00-\x1f]'))) return null;
    final uri = Uri.tryParse(raw);
    final host = uri?.host.toLowerCase() ?? '';
    final path = uri?.path.toLowerCase() ?? '';
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !_trustedMediaHost(host) ||
        (protocol == 'flv' ? !path.endsWith('.flv') : !path.endsWith('.m3u8'))) {
      return null;
    }
    return uri.replace(scheme: 'https');
  }

  static bool _trustedMediaHost(String host) =>
      host == 'linkv.fun' ||
      host.endsWith('.linkv.fun') ||
      host == 'emolm.com' ||
      host.endsWith('.emolm.com') ||
      host == 'liveme.com' ||
      host.endsWith('.liveme.com');

  static String _image(Object? value) {
    if (value is! String || value.isEmpty || value.length > 8192) return '';
    final uri = Uri.tryParse(value);
    final host = uri?.host.toLowerCase() ?? '';
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !(host == 'esxscloud.com' ||
            host.endsWith('.esxscloud.com') ||
            host == 'liveme.com' ||
            host.endsWith('.liveme.com') ||
            host == 'linkv.fun' ||
            host.endsWith('.linkv.fun'))) {
      return '';
    }
    return uri.replace(scheme: 'https').toString();
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map) throw const LiveMeException(LiveMeFailure.schema);
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static List<dynamic> _list(Object? value, {required int max}) {
    if (value is! List || value.length > max) throw const LiveMeException(LiveMeFailure.schema);
    return value;
  }

  static int? _integer(Object? value) => value is int ? value : int.tryParse(value?.toString() ?? '');

  static int? _optionalNonNegativeInt(Object? value) {
    if (value == null || value == '') return null;
    final parsed = _integer(value);
    if (parsed == null || parsed < 0) throw const LiveMeException(LiveMeFailure.schema);
    return parsed;
  }

  static String _shortId(Object? value) {
    final result = LiveMeLink.normalizeShortId(value?.toString() ?? '');
    if (result == null) throw const LiveMeException(LiveMeFailure.identity);
    return result;
  }

  static String _longId(Object? value) {
    final result = LiveMeLink.normalizeLongId(value?.toString() ?? '');
    if (result == null) throw const LiveMeException(LiveMeFailure.identity);
    return result;
  }

  static String _firstText(Iterable<Object?> values) {
    for (final value in values) {
      final text = _optionalText(value);
      if (text.isNotEmpty) return text;
    }
    throw const LiveMeException(LiveMeFailure.schema);
  }

  static String _optionalText(Object? value) {
    if (value == null) return '';
    if (value is! String || value.length > 131072) throw const LiveMeException(LiveMeFailure.schema);
    return value.trim();
  }

  static String _country(Object? value) {
    final text = _optionalText(value).toUpperCase();
    return RegExp(r'^[A-Z]{2}$').hasMatch(text) ? text : '';
  }
}

class _LiveMeProfile {
  const _LiveMeProfile({
    required this.shortId,
    required this.userId,
    required this.nickname,
    required this.avatar,
    required this.cover,
    required this.bio,
    required this.countryCode,
    required this.followers,
  });

  final String shortId;
  final String userId;
  final String nickname;
  final String avatar;
  final String cover;
  final String bio;
  final String countryCode;
  final int? followers;
}
