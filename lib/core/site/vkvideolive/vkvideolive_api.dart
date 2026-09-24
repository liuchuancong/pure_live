import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/common/request_scope.dart';

import 'vkvideolive_link.dart';

enum VkVideoLiveFailure {
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

class VkVideoLiveException implements Exception {
  const VkVideoLiveException(this.kind);

  final VkVideoLiveFailure kind;

  @override
  String toString() => 'VK Video Live ${kind.name}';
}

enum VkVideoLiveState { live, offline, unknown }

final class VkVideoLiveCategory {
  const VkVideoLiveCategory({
    required this.id,
    required this.type,
    required this.title,
    required this.cover,
    required this.viewerCount,
  });

  final String id;
  final String type;
  final String title;
  final String cover;
  final int? viewerCount;
}

final class VkVideoLiveQuality {
  VkVideoLiveQuality({
    required this.id,
    required this.label,
    required this.width,
    required this.height,
    required this.bandwidth,
    required Iterable<Uri> urls,
  }) : urls = List.unmodifiable(urls);

  final String id;
  final String label;
  final int width;
  final int height;
  final int bandwidth;
  final List<Uri> urls;
}

final class VkVideoLiveRoom {
  VkVideoLiveRoom({
    required this.channel,
    required this.streamId,
    required this.userId,
    required this.nickname,
    required this.avatar,
    required this.cover,
    required this.title,
    required this.category,
    required this.viewerCount,
    required this.totalViews,
    required this.followers,
    required this.state,
    required this.hasAccess,
    required Iterable<VkVideoLiveQuality> qualities,
  }) : qualities = List.unmodifiable(qualities);

  final String channel;
  final String streamId;
  final String userId;
  final String nickname;
  final String avatar;
  final String cover;
  final String title;
  final String category;
  final int? viewerCount;
  final int? totalViews;
  final int? followers;
  final VkVideoLiveState state;
  final bool hasAccess;
  final List<VkVideoLiveQuality> qualities;
}

final class VkVideoLivePage<T> {
  VkVideoLivePage({required Iterable<T> items, required this.hasMore, this.nextOffset, this.nextCursor})
    : items = List.unmodifiable(items);

  final List<T> items;
  final bool hasMore;
  final int? nextOffset;
  final String? nextCursor;
}

typedef VkVideoLiveRequest = Future<({int status, String body})> Function(
  Uri uri,
  Map<String, String> headers,
  CancelToken cancel,
);

class VkVideoLiveApi {
  VkVideoLiveApi({VkVideoLiveRequest? request, this.deadline = const Duration(seconds: 35)})
    : _request = request ?? _defaultRequest;

  static const String origin = 'https://live.vkvideo.ru';
  static const String apiOrigin = 'https://api.live.vkvideo.ru';
  static const int responseLimit = 4 * 1024 * 1024;
  static const int manifestLimit = 1024 * 1024;
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';

  final VkVideoLiveRequest _request;
  final Duration deadline;

  static Map<String, String> requestHeaders([String? channel]) => {
    'User-Agent': userAgent,
    'Accept': 'application/json, text/plain, */*',
    'Origin': origin,
    'Referer': channel == null ? '$origin/' : VkVideoLiveLink.url(channel),
  };

  static Map<String, String> mediaHeaders(String channel) => {
    'User-Agent': userAgent,
    'Origin': origin,
    'Referer': VkVideoLiveLink.url(channel),
  };

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
        receiveTimeout: const Duration(seconds: 25),
        validateStatus: (_) => true,
      ),
    );
    final body = response.data;
    if (body == null) throw const VkVideoLiveException(VkVideoLiveFailure.schema);
    final content = await _readBody(body.stream, limit: responseLimit);
    return (status: response.statusCode ?? 0, body: content);
  }

  static Future<String> _readBody(Stream<List<int>> source, {required int limit}) async {
    final iterator = StreamIterator(source);
    final bytes = BytesBuilder(copy: false);
    try {
      while (await iterator.moveNext()) {
        if (bytes.length + iterator.current.length > limit) {
          throw const VkVideoLiveException(VkVideoLiveFailure.schema);
        }
        bytes.add(iterator.current);
      }
      return utf8.decode(bytes.takeBytes());
    } on FormatException {
      throw const VkVideoLiveException(VkVideoLiveFailure.schema);
    } finally {
      await iterator.cancel();
    }
  }

  Future<T> _scope<T>(CancelToken? caller, Future<T> Function(CancelToken) work) =>
      withRequestCancellation(caller, (transport) async {
        if (transport.isCancelled) throw const VkVideoLiveException(VkVideoLiveFailure.cancelled);
        try {
          return await Future.any<T>([
            work(transport),
            transport.whenCancel.then<T>((_) => throw const VkVideoLiveException(VkVideoLiveFailure.cancelled)),
          ]).timeout(deadline);
        } on TimeoutException {
          throw const VkVideoLiveException(VkVideoLiveFailure.transport);
        } catch (error) {
          if (caller?.isCancelled == true || transport.isCancelled) {
            throw const VkVideoLiveException(VkVideoLiveFailure.cancelled);
          }
          if (error is VkVideoLiveException) rethrow;
          throw const VkVideoLiveException(VkVideoLiveFailure.transport);
        }
      });

  Future<Map<String, dynamic>> _json(Uri uri, CancelToken cancel, {String? channel}) async {
    final response = await _request(uri, requestHeaders(channel), cancel);
    _throwStatus(response.status);
    return _decodeObject(response.body);
  }

  Future<VkVideoLivePage<VkVideoLiveCategory>> categories({int offset = 0, int limit = 40, CancelToken? cancel}) =>
      _scope(cancel, (token) async {
        _validateWindow(offset, limit, max: 100);
        final uri = Uri.parse('$apiOrigin/v1/catalog/public_video_streams/category/')
            .replace(queryParameters: {'limit': '$limit', if (offset > 0) 'offset': '$offset'});
        final root = await _json(uri, token);
        final data = _object(root['data']);
        final extra = _object(root['extra']);
        final items = _list(data['categories'], max: 100).map((item) => parseCategory(_object(item)));
        return VkVideoLivePage(
          items: items,
          hasMore: !_bool(extra['isLast']),
          nextOffset: _optionalNonNegativeInt(extra['offset']),
        );
      });

  Future<VkVideoLivePage<VkVideoLiveRoom>> directory({
    String? categoryId,
    int offset = 0,
    int limit = 30,
    CancelToken? cancel,
  }) => _scope(cancel, (token) async {
    _validateWindow(offset, limit, max: 100);
    if (categoryId != null && !_uuid.hasMatch(categoryId)) {
      throw const VkVideoLiveException(VkVideoLiveFailure.identity);
    }
    final path = categoryId == null
        ? '/v1/catalog/public_video_streams/'
        : '/v1/catalog/public_video_streams/category/$categoryId/stream/';
    final uri = Uri.parse('$apiOrigin$path')
        .replace(queryParameters: {'limit': '$limit', if (offset > 0) 'offset': '$offset'});
    final root = await _json(uri, token);
    final data = _object(root['data']);
    final extra = _object(root['extra']);
    final rooms = _list(data['streamBlogs'], max: 100).map((item) => parseDirectoryRoom(_object(item)));
    return VkVideoLivePage(
      items: rooms,
      hasMore: !_bool(extra['isLast']),
      nextOffset: _optionalNonNegativeInt(extra['offset']),
    );
  });

  Future<VkVideoLivePage<VkVideoLiveRoom>> search(
    String rawKeyword, {
    String? after,
    int limit = 30,
    CancelToken? cancel,
  }) => _scope(cancel, (token) async {
    final keyword = _keyword(rawKeyword);
    if (limit < 1 || limit > 100 || (after != null && (after.isEmpty || after.length > 512))) {
      throw const VkVideoLiveException(VkVideoLiveFailure.schema);
    }
    final uri = Uri.parse('$apiOrigin/v8/search/channel')
        .replace(queryParameters: {'searchQuery': keyword, 'limit': '$limit', 'after': ?after});
    final root = await _json(uri, token);
    final data = _object(root['data']);
    final refs = _object(root['refs']);
    final streams = _objectOrEmpty(refs['streams']);
    final categories = _objectOrEmpty(refs['categories']);
    final rooms = _list(
      data['channels'],
      max: 100,
    ).map((item) => parseSearchRoom(_object(item), streams: streams, categories: categories));
    final extra = _object(root['extra']);
    final cursor = _optionalText(extra['after']);
    return VkVideoLivePage(
      items: rooms,
      hasMore: !_bool(extra['isLast']) && cursor.isNotEmpty,
      nextCursor: cursor.isEmpty ? null : cursor,
    );
  });

  Future<VkVideoLiveRoom> room(String rawChannel, {bool resolveMedia = true, CancelToken? cancel}) =>
      _scope(cancel, (token) async {
        final key = VkVideoLiveLink.parseKey(rawChannel);
        if (key == null) throw const VkVideoLiveException(VkVideoLiveFailure.identity);
        final uri = Uri.parse('$apiOrigin/v1/blog/${Uri.encodeComponent(key.channel)}/public_video_stream');
        final response = await _request(uri, requestHeaders(key.channel), token);
        if (response.status == 404) return _offlineChannel(key.channel, token);
        _throwStatus(response.status);
        final root = _decodeObject(response.body);
        var parsed = parseRoom(root, channel: key.channel);
        if (resolveMedia && parsed.state == VkVideoLiveState.live && parsed.hasAccess) {
          final masters = _masterUrls(root);
          final qualities = await _qualities(masters, key.channel, token);
          parsed = VkVideoLiveRoom(
            channel: parsed.channel,
            streamId: parsed.streamId,
            userId: parsed.userId,
            nickname: parsed.nickname,
            avatar: parsed.avatar,
            cover: parsed.cover,
            title: parsed.title,
            category: parsed.category,
            viewerCount: parsed.viewerCount,
            totalViews: parsed.totalViews,
            followers: parsed.followers,
            state: parsed.state,
            hasAccess: parsed.hasAccess,
            qualities: qualities,
          );
        }
        return parsed;
      });

  Future<VkVideoLiveRoom> _offlineChannel(String channel, CancelToken cancel) async {
    final uri = Uri.parse('$apiOrigin/v8/channel/${Uri.encodeComponent(channel)}');
    final root = await _json(uri, cancel, channel: channel);
    final data = _object(root['data']);
    final profile = _object(data['channel']);
    final actual = _channel(profile['url']);
    if (actual != channel) throw const VkVideoLiveException(VkVideoLiveFailure.identity);
    return VkVideoLiveRoom(
      channel: actual,
      streamId: '',
      userId: _id(profile['id']),
      nickname: _text(profile['nick']),
      avatar: _image(profile['avatarUrl']),
      cover: _image(profile['coverUrl']),
      title: _text(profile['nick']),
      category: '',
      viewerCount: null,
      totalViews: null,
      followers: _optionalNonNegativeInt(_objectOrEmpty(profile['counters'])['subscribers']),
      state: _state(profile['channelStatus']),
      hasAccess: true,
      qualities: const [],
    );
  }

  Future<List<VkVideoLiveQuality>> _qualities(List<Uri> masters, String channel, CancelToken cancel) async {
    final grouped = <String, _VariantGroup>{};
    // Primary and shared masters are mirrors. One mirror refusing this client
    // (seen: shared 403, primary 200) must not fail the room; only fail when
    // no mirror answered. Malformed manifests still fail.
    Object? firstFailure;
    StackTrace? firstStack;
    var served = 0;
    for (final master in masters.take(4)) {
      final ({int status, String body}) response;
      try {
        response = await _request(master, mediaHeaders(channel), cancel);
        _throwStatus(response.status);
      } catch (error, stack) {
        if (cancel.isCancelled || (error is VkVideoLiveException && error.kind == VkVideoLiveFailure.cancelled)) {
          rethrow;
        }
        firstFailure ??= error;
        firstStack ??= stack;
        continue;
      }
      served++;
      if (response.body.length > manifestLimit) throw const VkVideoLiveException(VkVideoLiveFailure.schema);
      for (final variant in parseMaster(master, response.body)) {
        final current = grouped.putIfAbsent(
          variant.id,
          () => _VariantGroup(
            id: variant.id,
            label: variant.label,
            width: variant.width,
            height: variant.height,
            bandwidth: variant.bandwidth,
          ),
        );
        if (!current.urls.contains(variant.urls.single)) current.urls.add(variant.urls.single);
      }
    }
    if (served == 0 && firstFailure != null) Error.throwWithStackTrace(firstFailure, firstStack!);
    final result =
        grouped.values
            .map(
              (item) => VkVideoLiveQuality(
                id: item.id,
                label: item.label,
                width: item.width,
                height: item.height,
                bandwidth: item.bandwidth,
                urls: item.urls,
              ),
            )
            .toList(growable: false)
          ..sort((left, right) {
            final height = right.height.compareTo(left.height);
            return height == 0 ? right.bandwidth.compareTo(left.bandwidth) : height;
          });
    return List.unmodifiable(result);
  }

  static VkVideoLiveCategory parseCategory(Map<String, dynamic> data) => VkVideoLiveCategory(
    id: _uuidText(data['id']),
    type: _text(data['type']),
    title: _text(data['title']),
    cover: _image(data['coverUrl']),
    viewerCount: _optionalNonNegativeInt(_objectOrEmpty(data['count'])['viewers']),
  );

  static VkVideoLiveRoom parseDirectoryRoom(Map<String, dynamic> data) {
    final blog = _object(data['blog']);
    final stream = _object(data['stream']);
    final owner = _object(blog['owner']);
    final channel = _channel(blog['blogUrl']);
    final online = _bool(stream['isOnline']);
    final ended = _bool(stream['isEnded']);
    final access = _accessAllowed(stream);
    return VkVideoLiveRoom(
      channel: channel,
      streamId: _uuidText(stream['id']),
      userId: _id(owner['id']),
      nickname: _firstText([owner['displayName'], owner['nick'], owner['name']]),
      avatar: _image(owner['avatarUrl']),
      cover: _image(stream['previewUrl']),
      title: _text(stream['title']),
      category: _optionalText(_objectOrEmpty(stream['category'])['title']),
      viewerCount: _optionalNonNegativeInt(_objectOrEmpty(stream['count'])['viewers']),
      totalViews: _optionalNonNegativeInt(_objectOrEmpty(stream['count'])['views']),
      followers: null,
      state: ended
          ? VkVideoLiveState.offline
          : online
          ? VkVideoLiveState.live
          : VkVideoLiveState.unknown,
      hasAccess: access && !_bool(stream['isPlaybackDisabled']),
      qualities: const [],
    );
  }

  static VkVideoLiveRoom parseSearchRoom(
    Map<String, dynamic> channel, {
    required Map<String, dynamic> streams,
    required Map<String, dynamic> categories,
  }) {
    final key = _channel(channel['url']);
    final streamId = _optionalUuid(channel['streamId']);
    final stream = streamId.isEmpty ? const <String, dynamic>{} : _objectOrEmpty(streams[streamId]);
    final categoryId = _optionalUuid(stream['categoryId']);
    final category = categoryId.isEmpty ? const <String, dynamic>{} : _objectOrEmpty(categories[categoryId]);
    final state = _state(channel['channelStatus']);
    return VkVideoLiveRoom(
      channel: key,
      streamId: streamId,
      userId: _id(channel['id']),
      nickname: _text(channel['nick']),
      avatar: _image(channel['avatarUrl']),
      cover: _firstImage([stream['previewUrl'], channel['coverUrl']]),
      title: _firstText([stream['title'], channel['nick']]),
      category: _optionalText(category['title']),
      viewerCount: state == VkVideoLiveState.live
          ? _optionalNonNegativeInt(_objectOrEmpty(stream['counters'])['viewers'])
          : null,
      totalViews: _optionalNonNegativeInt(_objectOrEmpty(stream['counters'])['views']),
      followers: _optionalNonNegativeInt(_objectOrEmpty(channel['counters'])['subscribers']),
      state: state,
      hasAccess: !_bool(_objectOrEmpty(stream['flags'])['isPlaybackDisabled']),
      qualities: const [],
    );
  }

  static VkVideoLiveRoom parseRoom(Map<String, dynamic> data, {required String channel}) {
    final user = _object(data['user']);
    final online = _bool(data['isOnline']);
    final ended = _bool(data['isEnded']);
    final count = _objectOrEmpty(data['count']);
    return VkVideoLiveRoom(
      channel: channel,
      streamId: _uuidText(data['id']),
      userId: _id(user['id']),
      nickname: _firstText([user['displayName'], user['nick'], user['name']]),
      avatar: _image(user['avatarUrl']),
      cover: _firstImage([data['previewUrl'], data['channelCoverImageUrl']]),
      title: _firstText([data['title'], user['displayName'], user['nick']]),
      category: _optionalText(_objectOrEmpty(data['category'])['title']),
      viewerCount: online ? _optionalNonNegativeInt(count['viewers']) : null,
      totalViews: _optionalNonNegativeInt(count['views']),
      followers: null,
      state: ended
          ? VkVideoLiveState.offline
          : online
          ? VkVideoLiveState.live
          : VkVideoLiveState.offline,
      hasAccess: _accessAllowed(data) && !_bool(data['isPlaybackDisabled']),
      qualities: const [],
    );
  }

  static List<Uri> _masterUrls(Map<String, dynamic> room) {
    final seen = <String>{};
    final urls = <Uri>[];
    for (final source in _nullableList(room['data'], max: 8)) {
      final item = _object(source);
      for (final key in ['playerUrls', 'sharedPlayerUrls']) {
        for (final value in _nullableList(item[key], max: 40)) {
          final entry = _object(value);
          if (entry['type'] != 'live_hls') continue;
          final uri = _media(entry['url']);
          if (uri != null && seen.add(uri.toString())) urls.add(uri);
        }
      }
    }
    return List.unmodifiable(urls);
  }

  static List<VkVideoLiveQuality> parseMaster(Uri master, String manifest) {
    if (manifest.length > manifestLimit || !manifest.trimLeft().startsWith('#EXTM3U')) {
      throw const VkVideoLiveException(VkVideoLiveFailure.schema);
    }
    final lines = const LineSplitter().convert(manifest);
    final result = <VkVideoLiveQuality>[];
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index].trim();
      if (!line.startsWith('#EXT-X-STREAM-INF:')) continue;
      final attributes = _attributes(line.substring('#EXT-X-STREAM-INF:'.length));
      var next = index + 1;
      while (next < lines.length && (lines[next].trim().isEmpty || lines[next].trim().startsWith('#'))) {
        next++;
      }
      if (next >= lines.length) throw const VkVideoLiveException(VkVideoLiveFailure.schema);
      final resolved = _media(master.resolve(lines[next].trim()).toString());
      if (resolved == null) throw const VkVideoLiveException(VkVideoLiveFailure.schema);
      final dimensions = RegExp(r'^(\d{2,5})x(\d{2,5})$').firstMatch(attributes['RESOLUTION'] ?? '');
      final width = int.tryParse(dimensions?.group(1) ?? '') ?? 0;
      final height = int.tryParse(dimensions?.group(2) ?? '') ?? 0;
      final bandwidth = _optionalNonNegativeInt(attributes['BANDWIDTH']) ?? 0;
      if (width == 0 || height == 0) throw const VkVideoLiveException(VkVideoLiveFailure.schema);
      final id = '${width}x$height';
      result.add(
        VkVideoLiveQuality(
          id: id,
          label: '${height}p · HLS',
          width: width,
          height: height,
          bandwidth: bandwidth,
          urls: [resolved],
        ),
      );
      index = next;
    }
    if (result.isEmpty) throw const VkVideoLiveException(VkVideoLiveFailure.schema);
    return List.unmodifiable(result);
  }

  static DateTime? mediaInvalidAt(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return null;
    final segments = uri.pathSegments;
    final index = segments.indexOf('expires');
    if (index < 0 || index + 1 >= segments.length) return null;
    final raw = int.tryParse(segments[index + 1]);
    if (raw == null || raw <= 0) return null;
    final milliseconds = raw > 100000000000 ? raw : raw * 1000;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true).subtract(const Duration(seconds: 10));
  }

  static DateTime? mediaRefreshAt(String rawUrl) => mediaInvalidAt(rawUrl)?.subtract(const Duration(minutes: 2));

  static final RegExp _uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

  static void _validateWindow(int offset, int limit, {required int max}) {
    if (offset < 0 || offset > 1000000 || limit < 1 || limit > max) {
      throw const VkVideoLiveException(VkVideoLiveFailure.schema);
    }
  }

  static bool _accessAllowed(Map<String, dynamic> data) {
    final restrictions = _objectOrEmpty(data['accessRestrictions']);
    final view = _objectOrEmpty(restrictions['view']);
    final allowed = view['allowed'] ?? view['allow'];
    return allowed == null ? true : _bool(allowed);
  }

  static VkVideoLiveState _state(Object? value) => switch (_optionalText(value).toLowerCase()) {
    'online' => VkVideoLiveState.live,
    'offline' => VkVideoLiveState.offline,
    _ => VkVideoLiveState.unknown,
  };

  static String _keyword(String raw) {
    final value = raw.trim();
    if (value.length < 3 || value.length > 120 || RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
      throw const VkVideoLiveException(VkVideoLiveFailure.schema);
    }
    return value;
  }

  static String _channel(Object? value) {
    final channel = VkVideoLiveLink.normalizeChannel(value);
    if (channel == null) throw const VkVideoLiveException(VkVideoLiveFailure.schema);
    return channel;
  }

  static String _uuidText(Object? value) {
    final text = _optionalUuid(value);
    if (text.isEmpty) throw const VkVideoLiveException(VkVideoLiveFailure.schema);
    return text;
  }

  static String _optionalUuid(Object? value) {
    final text = value is String ? value.trim().toLowerCase() : '';
    if (text.isEmpty) return '';
    if (!_uuid.hasMatch(text)) throw const VkVideoLiveException(VkVideoLiveFailure.schema);
    return text;
  }

  static String _id(Object? value) {
    final id = value is int
        ? value.toString()
        : value is String
        ? value.trim()
        : '';
    if (!RegExp(r'^[1-9][0-9]{0,19}$').hasMatch(id)) {
      throw const VkVideoLiveException(VkVideoLiveFailure.schema);
    }
    return id;
  }

  static String _text(Object? value) {
    final text = _optionalText(value);
    if (text.isEmpty) throw const VkVideoLiveException(VkVideoLiveFailure.schema);
    return text;
  }

  static String _optionalText(Object? value) {
    if (value == null) return '';
    if (value is! String) throw const VkVideoLiveException(VkVideoLiveFailure.schema);
    final text = value.trim();
    if (text.length > 8192) throw const VkVideoLiveException(VkVideoLiveFailure.schema);
    return text;
  }

  static String _firstText(Iterable<Object?> values) {
    for (final value in values) {
      final text = _optionalText(value);
      if (text.isNotEmpty) return text;
    }
    throw const VkVideoLiveException(VkVideoLiveFailure.schema);
  }

  static String _firstImage(Iterable<Object?> values) {
    for (final value in values) {
      final image = _image(value);
      if (image.isNotEmpty) return image;
    }
    return '';
  }

  static String _image(Object? value) {
    final text = _optionalText(value);
    if (text.isEmpty) return '';
    final uri = Uri.tryParse(text);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.host.toLowerCase() != 'images.live.vkvideo.ru') {
      throw const VkVideoLiveException(VkVideoLiveFailure.schema);
    }
    return uri.toString();
  }

  static bool _mediaHost(String host) => host.endsWith('.okcdn.ru') || host.endsWith('.vkuser.net');

  static Uri? _media(Object? value) {
    final text = value is String ? value.trim() : '';
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        // VK serves live HLS from okcdn.ru and, since 2026-09, vkuser.net.
        !_mediaHost(uri.host.toLowerCase()) ||
        !uri.path.toLowerCase().contains('.m3u8')) {
      throw const VkVideoLiveException(VkVideoLiveFailure.schema);
    }
    return uri;
  }

  static Map<String, String> _attributes(String raw) {
    final result = <String, String>{};
    for (final match in RegExp(r'(?:^|,)([A-Z0-9-]+)=("[^"]*"|[^,]*)').allMatches(raw)) {
      var value = match.group(2) ?? '';
      if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
        value = value.substring(1, value.length - 1);
      }
      result[match.group(1)!] = value;
    }
    return result;
  }

  static int? _optionalNonNegativeInt(Object? value) {
    if (value == null) return null;
    final result = value is int ? value : int.tryParse(value.toString());
    if (result == null || result < 0) throw const VkVideoLiveException(VkVideoLiveFailure.schema);
    return result;
  }

  static bool _bool(Object? value) {
    if (value is bool) return value;
    if (value == 0) return false;
    if (value == 1) return true;
    if (value == null) return false;
    throw const VkVideoLiveException(VkVideoLiveFailure.schema);
  }

  static Map<String, dynamic> _decodeObject(String body) {
    if (body.length > responseLimit) throw const VkVideoLiveException(VkVideoLiveFailure.schema);
    try {
      return _object(jsonDecode(body));
    } on FormatException {
      throw const VkVideoLiveException(VkVideoLiveFailure.schema);
    }
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map) throw const VkVideoLiveException(VkVideoLiveFailure.schema);
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static Map<String, dynamic> _objectOrEmpty(Object? value) {
    if (value == null) return const {};
    return _object(value);
  }

  static List<Object?> _list(Object? value, {required int max}) {
    if (value is! List || value.length > max) throw const VkVideoLiveException(VkVideoLiveFailure.schema);
    return value;
  }

  static List<Object?> _nullableList(Object? value, {required int max}) {
    if (value == null) return const [];
    return _list(value, max: max);
  }

  static void _throwStatus(int status) {
    final failure = switch (status) {
      200 => null,
      400 || 422 => VkVideoLiveFailure.schema,
      401 || 403 => VkVideoLiveFailure.access,
      404 => VkVideoLiveFailure.missing,
      429 => VkVideoLiveFailure.rateLimited,
      >= 500 => VkVideoLiveFailure.service,
      _ => VkVideoLiveFailure.transport,
    };
    if (failure != null) throw VkVideoLiveException(failure);
  }
}

final class _VariantGroup {
  _VariantGroup({
    required this.id,
    required this.label,
    required this.width,
    required this.height,
    required this.bandwidth,
  });

  final String id;
  final String label;
  final int width;
  final int height;
  final int bandwidth;
  final List<Uri> urls = [];
}
