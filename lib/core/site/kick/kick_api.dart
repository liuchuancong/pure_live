import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pure_live/common/services/settings/proxy_settings_controller.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/core/common/android_native_http.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/common/request_scope.dart';

import 'kick_link.dart';

enum KickFailure { transport, access, rateLimited, service, missing, schema, cancelled, identity, mediaUnavailable }

class KickException implements Exception {
  const KickException(this.kind);
  final KickFailure kind;

  @override
  String toString() => 'Kick ${kind.name}';
}

typedef KickRequest = Future<({int status, String body})> Function(Uri uri, CancelToken? cancel);

class KickChannel {
  const KickChannel({
    required this.id,
    required this.slug,
    required this.name,
    required this.avatar,
    required this.bio,
    required this.followers,
    required this.isLive,
    required this.isBanned,
  });

  final int id;
  final String slug;
  final String name;
  final String avatar;
  final String bio;
  final int? followers;
  final bool isLive;
  final bool isBanned;
}

class KickLive {
  const KickLive({
    required this.id,
    required this.channel,
    required this.title,
    required this.cover,
    required this.category,
    required this.viewers,
    required this.mature,
    required this.playbackUrl,
  });

  final int id;
  final KickChannel channel;
  final String title;
  final String cover;
  final String category;
  final int? viewers;
  final bool mature;
  final String playbackUrl;
}

class KickRoom {
  const KickRoom(this.channel, this.live);
  final KickChannel channel;
  final KickLive? live;
}

class KickDirectoryPage {
  KickDirectoryPage({required Iterable<KickLive> lives, required this.hasMore}) : lives = List.unmodifiable(lives);
  final List<KickLive> lives;
  final bool hasMore;
}

class KickApi {
  KickApi({KickRequest? request}) : _request = request ?? _defaultRequest;

  static const origin = 'https://kick.com';
  static const responseLimit = 4 * 1024 * 1024;
  static const userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';
  static const headers = {
    'User-Agent': userAgent,
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'en-US,en;q=0.9',
    'Origin': origin,
    'Referer': '$origin/',
  };

  static Map<String, String> mediaHeaders(String slug) => {
    'User-Agent': userAgent,
    'Origin': origin,
    'Referer': '${KickLink.url(slug)}/',
  };

  final KickRequest _request;

  static Future<({int status, String body})> _defaultRequest(Uri uri, CancelToken? cancel) =>
      usesPlatformTls(uri, native: AndroidNativeHttp.supportsKick)
      ? _nativeRequest(uri, cancel)
      : _dioRequest(uri, cancel);

  /// Only kick.com is behind the Cloudflare TLS check; the IVS playlists the
  /// room detail also fetches through this request stay on dio (the native
  /// channel refuses every other host).
  static bool usesPlatformTls(Uri uri, {required bool native}) =>
      native && uri.scheme == 'https' && uri.host.toLowerCase() == 'kick.com';

  /// Cloudflare answers every kick.com API request made with dart:io's TLS
  /// stack with 403, so the whole Kick catalog, search and rooms failed.
  /// Android's platform TLS stack and Windows WinHTTP (Schannel) are accepted.
  static Future<({int status, String body})> _nativeRequest(Uri uri, CancelToken? cancel) async {
    if (cancel?.isCancelled == true) throw const KickException(KickFailure.cancelled);
    ProxySettingsController? proxy;
    try {
      proxy = SettingsService.to.proxy;
    } catch (_) {}
    final enabled = proxy?.enableAppProxy.value == true;
    final response = await AndroidNativeHttp.getKickJson(
      url: uri.toString(),
      headers: headers,
      proxyHost: enabled ? proxy!.appProxyHost.value : null,
      proxyPort: enabled ? proxy!.appProxyPort.value : null,
    );
    if (cancel?.isCancelled == true) throw const KickException(KickFailure.cancelled);
    if (response.status != 200) return (status: response.status, body: '');
    if (response.body.length > responseLimit) throw const KickException(KickFailure.schema);
    return response;
  }

  static Future<({int status, String body})> _dioRequest(Uri uri, CancelToken? cancel) =>
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
        if (body == null) throw const KickException(KickFailure.schema);
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
        if (remaining <= Duration.zero) throw TimeoutException('Kick response deadline');
        if (!await iterator.moveNext().timeout(remaining)) break;
        final chunk = iterator.current;
        if (bytes.length + chunk.length > responseLimit) throw const KickException(KickFailure.schema);
        bytes.add(chunk);
      }
      return utf8.decode(bytes.takeBytes());
    } on FormatException {
      throw const KickException(KickFailure.schema);
    } finally {
      watch.stop();
      await iterator.cancel();
    }
  }

  Future<String> _read(Uri uri, CancelToken? cancel) async {
    if (cancel?.isCancelled == true) throw const KickException(KickFailure.cancelled);
    late final ({int status, String body}) response;
    try {
      response = await _request(uri, cancel);
    } catch (error) {
      if (cancel?.isCancelled == true || (error is DioException && CancelToken.isCancel(error))) {
        throw const KickException(KickFailure.cancelled);
      }
      if (error is KickException) rethrow;
      throw const KickException(KickFailure.transport);
    }
    final failure = switch (response.status) {
      200 => null,
      400 => KickFailure.schema,
      401 || 403 => KickFailure.access,
      404 => KickFailure.missing,
      429 => KickFailure.rateLimited,
      >= 500 => KickFailure.service,
      _ => KickFailure.transport,
    };
    if (failure != null) throw KickException(failure);
    if (response.body.length > responseLimit) throw const KickException(KickFailure.schema);
    return response.body;
  }

  Future<Map<String, dynamic>> _json(String path, Map<String, String> query, CancelToken? cancel) async {
    final body = await _read(Uri.parse('$origin$path').replace(queryParameters: query.isEmpty ? null : query), cancel);
    try {
      return _object(jsonDecode(body));
    } on FormatException {
      throw const KickException(KickFailure.schema);
    }
  }

  Future<String> manifest(String url, {CancelToken? cancel}) => _read(_mediaUri(url), cancel);

  Future<KickDirectoryPage> directory({int page = 1, int size = 30, CancelToken? cancel}) async {
    if (page < 1 || page > 1000 || size < 1 || size > 30) throw const KickException(KickFailure.schema);
    final root = await _json('/stream/livestreams/en', {'page': '$page', 'limit': '$size'}, cancel);
    if (_positiveInt(root['current_page']) != page) throw const KickException(KickFailure.identity);
    final lives = _list(root['data'], max: 64).map((value) => _live(_object(value))).toList(growable: false);
    final next = root['next_page_url'];
    if (next != null && (next is! String || !_nextPage(next, page + 1))) throw const KickException(KickFailure.schema);
    return KickDirectoryPage(lives: lives, hasMore: next != null && lives.isNotEmpty);
  }

  Future<List<KickRoom>> search(String keyword, {CancelToken? cancel}) async {
    final query = keyword.trim();
    if (query.isEmpty || query.length > 50) throw const KickException(KickFailure.schema);
    final root = await _json('/api/search', {'searched_word': query}, cancel);
    final results = <String, KickRoom>{};
    final liveRoot = root['livestreams'];
    if (liveRoot is Map) {
      for (final value in _list(_object(liveRoot)['tags'], max: 64)) {
        final live = _live(_object(value));
        results[live.channel.slug] = KickRoom(live.channel, live);
      }
    }
    for (final value in _list(root['channels'], max: 64)) {
      final channel = _channel(_object(value), searchShape: true);
      results.putIfAbsent(channel.slug, () => KickRoom(channel, null));
    }
    return List.unmodifiable(results.values);
  }

  Future<KickRoom> room(String rawSlug, {CancelToken? cancel}) async {
    final slug = KickLink.normalize(rawSlug);
    if (slug == null) throw const KickException(KickFailure.identity);
    final root = await _json('/api/v2/channels/$slug', const {}, cancel);
    final liveValue = root['livestream'];
    final channel = _channel(root, isLive: liveValue is Map, searchShape: false);
    if (channel.slug != slug) throw const KickException(KickFailure.identity);
    if (liveValue == null) return KickRoom(channel, null);
    if (liveValue is! Map) throw const KickException(KickFailure.schema);
    final liveData = _object(liveValue);
    if (_bool(liveData['is_live']) != true || channel.isBanned) return KickRoom(channel, null);
    final live = _live(liveData, owner: channel, playbackUrl: root['playback_url']);
    return KickRoom(channel, live);
  }

  /// Chatroom ID is distinct from the channel/user ID. Do not subscribe to a
  /// guessed channel when the public channel response omits this field.
  Future<int> chatroomId(String rawSlug, {CancelToken? cancel}) async {
    final slug = KickLink.normalize(rawSlug);
    if (slug == null) throw const KickException(KickFailure.identity);
    final root = await _json('/api/v2/channels/$slug', const {}, cancel);
    if (KickLink.normalize(_text(root['slug'])) != slug) throw const KickException(KickFailure.identity);
    return _positiveInt(_object(root['chatroom'])['id']);
  }

  static KickLive _live(Map<String, dynamic> data, {KickChannel? owner, Object? playbackUrl}) {
    final channel = owner ?? _channel(_object(data['channel']), isLive: true, searchShape: false);
    final channelId = _positiveInt(data['channel_id']);
    final embeddedId = data['channel'] is Map ? _positiveInt(_object(data['channel'])['id']) : channel.id;
    if (channelId != embeddedId || channelId != channel.id) throw const KickException(KickFailure.identity);
    final categories = _list(data['categories'], max: 16);
    final category = categories.isEmpty ? '' : _optionalText(_object(categories.first)['name']);
    final showViewCount = data['show_view_count'];
    if (showViewCount != null && showViewCount is! bool) throw const KickException(KickFailure.schema);
    final play = _mediaUri(_text(playbackUrl ?? _object(data['channel'])['playback_url'])).toString();
    return KickLive(
      id: _positiveInt(data['id']),
      channel: KickChannel(
        id: channel.id,
        slug: channel.slug,
        name: channel.name,
        avatar: channel.avatar,
        bio: channel.bio,
        followers: channel.followers,
        isLive: true,
        isBanned: channel.isBanned,
      ),
      title: _text(data['session_title']),
      cover: _thumbnail(data['thumbnail']),
      category: category,
      viewers: showViewCount == false ? null : _optionalNonNegativeInt(data['viewer_count'] ?? data['viewers']),
      mature: _bool(data['is_mature']) ?? false,
      playbackUrl: play,
    );
  }

  static KickChannel _channel(Map<String, dynamic> data, {bool? isLive, required bool searchShape}) {
    final user = _object(data['user']);
    final slug = KickLink.normalize(_text(data['slug']));
    if (slug == null) throw const KickException(KickFailure.identity);
    final avatar = user[searchShape ? 'profilePic' : 'profile_pic'] ?? user['profilePic'] ?? user['profilepic'];
    final live = isLive ?? (data[searchShape ? 'isLive' : 'is_live'] == true);
    return KickChannel(
      id: _positiveInt(data['id']),
      slug: slug,
      name: _text(user['username']),
      avatar: _image(avatar),
      bio: _optionalText(user['bio']),
      followers: _optionalNonNegativeInt(data['followers_count'] ?? data['followersCount']),
      isLive: live,
      isBanned: _bool(data['is_banned']) ?? false,
    );
  }

  static String _thumbnail(Object? value) {
    if (value is! Map) return '';
    final data = _object(value);
    return _image(data['url'] ?? data['src']);
  }

  static bool _nextPage(String raw, int expected) {
    final uri = Uri.tryParse(raw);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host == 'kick.com' &&
        uri.path == '/stream/livestreams/en' &&
        int.tryParse(uri.queryParameters['page'] ?? '') == expected;
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map) throw const KickException(KickFailure.schema);
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static List<dynamic> _list(Object? value, {required int max}) {
    if (value is! List || value.length > max) throw const KickException(KickFailure.schema);
    return value;
  }

  static int? _integer(Object? value) => value is int ? value : int.tryParse(value?.toString() ?? '');

  static int _positiveInt(Object? value) {
    final result = _integer(value);
    if (result == null || result <= 0) throw const KickException(KickFailure.schema);
    return result;
  }

  static int? _optionalNonNegativeInt(Object? value) {
    if (value == null || value == '') return null;
    final result = _integer(value);
    if (result == null || result < 0) throw const KickException(KickFailure.schema);
    return result;
  }

  static bool? _bool(Object? value) {
    if (value == null) return null;
    if (value is! bool) throw const KickException(KickFailure.schema);
    return value;
  }

  static String _text(Object? value) {
    if (value is! String || value.trim().isEmpty || value.length > 8192) {
      throw const KickException(KickFailure.schema);
    }
    return value.trim();
  }

  static String _optionalText(Object? value) {
    if (value == null || value == '') return '';
    if (value is! String || value.length > 131072) throw const KickException(KickFailure.schema);
    return value.trim();
  }

  static String _image(Object? value) {
    if (value is! String || value.length > 8192) return '';
    final uri = Uri.tryParse(value);
    final host = uri?.host.toLowerCase() ?? '';
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !const {'files.kick.com', 'images.kick.com', 'static.kick.com'}.contains(host)) {
      return '';
    }
    return value;
  }

  static Uri _mediaUri(String raw) {
    if (raw.length > 65536 || raw.contains(RegExp(r'[\s\x00-\x1f]'))) {
      throw const KickException(KickFailure.schema);
    }
    final uri = Uri.tryParse(raw);
    final host = uri?.host.toLowerCase() ?? '';
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !(host == 'live-video.net' || host.endsWith('.live-video.net'))) {
      throw const KickException(KickFailure.schema);
    }
    return uri;
  }
}
