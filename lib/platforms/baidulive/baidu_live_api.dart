import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/common/request_scope.dart';

import 'baidu_live_link.dart';

enum BaiduLiveFailure {
  transport,
  access,
  missing,
  rateLimited,
  service,
  schema,
  identity,
  cancelled,
  mediaUnavailable,
}

final class BaiduLiveException implements Exception {
  const BaiduLiveException(this.kind);

  final BaiduLiveFailure kind;

  @override
  String toString() => 'Baidu Live ${kind.name}';
}

enum BaiduLiveState { live, preview, offline, replay, restricted, unknown }

final class BaiduLiveCategory {
  const BaiduLiveCategory({required this.id, required this.name, required this.channelId});

  final String id;
  final String name;
  final int channelId;
}

final class BaiduLiveVariant {
  BaiduLiveVariant({
    required this.id,
    required this.protocol,
    required this.resolution,
    required this.codec,
    required Iterable<Uri> urls,
  }) : urls = List.unmodifiable(urls);

  final String id;
  final String protocol;
  final int resolution;
  final String codec;
  final List<Uri> urls;
}

final class BaiduLiveRoom {
  BaiduLiveRoom({
    required this.roomId,
    required this.userId,
    required this.nick,
    required this.title,
    required this.avatar,
    required this.cover,
    required this.category,
    required this.currentViewers,
    required this.followers,
    required this.state,
    required Iterable<BaiduLiveVariant> variants,
  }) : variants = List.unmodifiable(variants);

  final String roomId;
  final String userId;
  final String nick;
  final String title;
  final String avatar;
  final String cover;
  final String category;
  final int? currentViewers;
  final int? followers;
  final BaiduLiveState state;
  final List<BaiduLiveVariant> variants;

  BaiduLiveRoom enrich(BaiduLiveRoom known) => BaiduLiveRoom(
    roomId: roomId,
    userId: userId.isEmpty ? known.userId : userId,
    nick: nick == 'Baidu Live' ? known.nick : nick,
    title: title == 'Baidu Live' ? known.title : title,
    avatar: avatar.isEmpty ? known.avatar : avatar,
    cover: cover.isEmpty ? known.cover : cover,
    category: category.isEmpty ? known.category : category,
    currentViewers: currentViewers ?? known.currentViewers,
    followers: followers ?? known.followers,
    state: state,
    variants: variants,
  );
}

final class BaiduLivePage {
  BaiduLivePage({
    required Iterable<BaiduLiveRoom> rooms,
    required Iterable<BaiduLiveCategory> categories,
    required this.sessionId,
    required this.refreshIndex,
    required this.hasMore,
  }) : rooms = List.unmodifiable(rooms),
       categories = List.unmodifiable(categories);

  final List<BaiduLiveRoom> rooms;
  final List<BaiduLiveCategory> categories;
  final String sessionId;
  final int refreshIndex;
  final bool hasMore;
}

typedef BaiduLiveRequest = Future<({int status, String body})> Function(
  Uri uri,
  Map<String, String> headers,
  Map<String, String>? form,
  CancelToken cancel,
);

class BaiduLiveApi {
  BaiduLiveApi({BaiduLiveRequest? request, this.deadline = const Duration(seconds: 20)})
    : _request = request ?? _defaultRequest;

  static const String webOrigin = 'https://live.baidu.com';
  static const String detailOrigin = 'https://mbd.baidu.com';
  static const String directoryOrigin = 'https://tiebac.baidu.com';
  static const int responseLimit = 4 * 1024 * 1024;
  static const String _feedSecret = 'CtmXzYPtdE58nCCcvqM0ectyqW3N5rfY';
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';
  static const Map<String, String> apiHeaders = {
    'User-Agent': userAgent,
    'Accept': 'application/json, text/plain, */*',
    'Origin': webOrigin,
    'Referer': '$webOrigin/',
  };
  static const List<BaiduLiveCategory> fallbackCategories = [
    BaiduLiveCategory(id: 'rec', name: '推荐', channelId: 570),
    BaiduLiveCategory(id: 'shopping', name: '购物', channelId: 574),
    BaiduLiveCategory(id: 'finance', name: '财经', channelId: 611),
    BaiduLiveCategory(id: 'health', name: '健康', channelId: 612),
    BaiduLiveCategory(id: 'education', name: '教育', channelId: 613),
    BaiduLiveCategory(id: 'news', name: '新闻', channelId: 575),
    BaiduLiveCategory(id: 'leisure', name: '休闲', channelId: 616),
  ];

  static Map<String, String> mediaHeaders(String roomId) => {
    'User-Agent': userAgent,
    'Origin': webOrigin,
    'Referer': BaiduLiveLink.watchUrl(roomId),
  };

  final BaiduLiveRequest _request;
  final Duration deadline;

  static Future<({int status, String body})> _defaultRequest(
    Uri uri,
    Map<String, String> headers,
    Map<String, String>? form,
    CancelToken cancel,
  ) async {
    final response = await HttpClient.instance.dio.request<ResponseBody>(
      uri.toString(),
      data: form == null ? null : Uri(queryParameters: form).query,
      cancelToken: cancel,
      options: Options(
        method: form == null ? 'GET' : 'POST',
        contentType: form == null ? null : Headers.formUrlEncodedContentType,
        responseType: ResponseType.stream,
        followRedirects: false,
        headers: headers,
        receiveTimeout: const Duration(seconds: 15),
        validateStatus: (_) => true,
      ),
    );
    final body = response.data;
    if (body == null) throw const BaiduLiveException(BaiduLiveFailure.schema);
    return (status: response.statusCode ?? 0, body: await _readBody(body.stream));
  }

  static Future<String> _readBody(Stream<List<int>> source) async {
    final iterator = StreamIterator(source);
    final bytes = BytesBuilder(copy: false);
    try {
      while (await iterator.moveNext()) {
        if (bytes.length + iterator.current.length > responseLimit) {
          throw const BaiduLiveException(BaiduLiveFailure.schema);
        }
        bytes.add(iterator.current);
      }
      return utf8.decode(bytes.takeBytes());
    } on FormatException {
      throw const BaiduLiveException(BaiduLiveFailure.schema);
    } finally {
      await iterator.cancel();
    }
  }

  Future<T> _scope<T>(CancelToken? caller, Future<T> Function(CancelToken) work) =>
      withRequestCancellation(caller, (transport) async {
        if (transport.isCancelled) throw const BaiduLiveException(BaiduLiveFailure.cancelled);
        try {
          return await Future.any<T>([
            work(transport),
            transport.whenCancel.then<T>((_) => throw const BaiduLiveException(BaiduLiveFailure.cancelled)),
          ]).timeout(deadline);
        } on TimeoutException {
          throw const BaiduLiveException(BaiduLiveFailure.transport);
        } catch (error) {
          if (caller?.isCancelled == true || transport.isCancelled) {
            throw const BaiduLiveException(BaiduLiveFailure.cancelled);
          }
          if (error is BaiduLiveException) rethrow;
          throw const BaiduLiveException(BaiduLiveFailure.transport);
        }
      });

  Future<String> _send(Uri uri, Map<String, String> headers, Map<String, String>? form, CancelToken cancel) async {
    if (uri.scheme != 'https' || uri.userInfo.isNotEmpty || uri.hasFragment) {
      throw const BaiduLiveException(BaiduLiveFailure.identity);
    }
    final response = await _request(uri, headers, form, cancel);
    _throwStatus(response.status);
    if (response.body.length > responseLimit) throw const BaiduLiveException(BaiduLiveFailure.schema);
    return response.body;
  }

  Future<BaiduLivePage> directory({
    required int page,
    required String tab,
    required int channelId,
    required String sessionId,
    required int refreshIndex,
    required String deviceId,
    CancelToken? cancel,
  }) => _scope(cancel, (token) async {
    if (page < 1 ||
        page > 10000 ||
        !RegExp(r'^[a-z][a-z0-9_]{0,31}$').hasMatch(tab) ||
        channelId < 1 ||
        channelId > 100000 ||
        refreshIndex < 1 ||
        deviceId.length > 96 ||
        !RegExp(r'^pc-[A-Za-z0-9_-]{8,64}$').hasMatch(deviceId)) {
      throw const BaiduLiveException(BaiduLiveFailure.identity);
    }
    final first = page == 1;
    if ((!first && sessionId.isEmpty) || sessionId.length > 128) {
      throw const BaiduLiveException(BaiduLiveFailure.identity);
    }
    final form = <String, String>{
      'appname': 'pclive',
      'sid': '',
      'ua': '320_480_pc_1.0_0',
      'uid': deviceId,
      'timestamp': '${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
      'source': 'pclive',
      'resource': first ? 'banner,tab,feed' : 'feed',
      'scene': 'pc_channel',
      'session_id': first ? '' : sessionId,
      'refresh_type': first ? '0' : '1',
      'refresh_index': '$refreshIndex',
      'tab': tab,
      'channel_id': '$channelId',
    };
    form['sign'] = signFeedParameters(form);
    final body = await _send(Uri.parse('$directoryOrigin/livefeed/feed'), apiHeaders, form, token);
    return parseDirectoryJson(_decode(body));
  });

  Future<BaiduLiveRoom> room(String rawRoomId, {bool includeMedia = false, CancelToken? cancel}) =>
      _scope(cancel, (token) async {
        final roomId = BaiduLiveLink.parseRoomId(rawRoomId);
        if (roomId == null) throw const BaiduLiveException(BaiduLiveFailure.identity);
        final deviceId = 'pc-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}baidulive';
        final data = jsonEncode({
          'data': {'room_id': roomId, 'device_id': deviceId, 'source_type': 0},
          'replay_slice': 0,
          'nid': '',
          'schemeParams': {
            'src_pre': 'pc',
            'src_suf': 'other',
            'bd_vid': '',
            'share_uid': '',
            'share_cuk': '',
            'share_ecid': '',
            'zb_tag': '',
            'shareTaskInfo': jsonEncode({'room_id': roomId}),
            'share_from': '',
            'ext_params': '',
            'nid': '',
          },
        });
        final uri = Uri.parse('$detailOrigin/searchbox').replace(
          queryParameters: {
            'cmd': '371',
            'action': 'star',
            'service': 'bdbox',
            'osname': 'pc',
            'data': data,
            'ua': '360_740_ANDROID_0',
            'bd_vid': '',
            'uid': deviceId,
            '_': '${DateTime.now().millisecondsSinceEpoch}',
          },
        );
        final result = parseRoomJson(_decode(await _send(uri, apiHeaders, null, token)), expectedRoomId: roomId);
        if (includeMedia && result.state == BaiduLiveState.live && result.variants.isEmpty) {
          throw const BaiduLiveException(BaiduLiveFailure.mediaUnavailable);
        }
        return result;
      });

  static String signFeedParameters(Map<String, String> parameters) {
    final keys = parameters.keys.where((key) => key != 'sign').toList(growable: false)..sort();
    final canonical = keys.map((key) => '$key=${parameters[key]}').join('&');
    return md5.convert(utf8.encode('$canonical&$_feedSecret')).toString();
  }

  static BaiduLivePage parseDirectoryJson(Object? value) {
    final root = _map(value);
    if (_integer(root['errno']) != 0) throw const BaiduLiveException(BaiduLiveFailure.service);
    final data = _map(root['data']);
    final feed = _map(data['feed']);
    if (_integer(feed['inner_errno']) != 0) throw const BaiduLiveException(BaiduLiveFailure.service);
    final rawItems = _list(feed['items']);
    final seen = <String>{};
    final rooms = <BaiduLiveRoom>[];
    for (final value in rawItems) {
      final room = _directoryCard(_map(value));
      if (room != null && seen.add(room.roomId)) rooms.add(room);
    }
    final sessionId = _text(feed['session_id']);
    final refreshIndex = _nonNegative(feed['refresh_index']);
    if (sessionId.isEmpty || refreshIndex == null) throw const BaiduLiveException(BaiduLiveFailure.schema);
    final categories = parseCategoriesJson(data['tab']);
    return BaiduLivePage(
      rooms: rooms,
      categories: categories,
      sessionId: sessionId,
      refreshIndex: refreshIndex,
      hasMore: rawItems.length >= 10,
    );
  }

  static List<BaiduLiveCategory> parseCategoriesJson(Object? value) {
    final tab = _map(value);
    if (tab.isEmpty) return const [];
    if (_integer(tab['inner_errno']) != 0) throw const BaiduLiveException(BaiduLiveFailure.service);
    final categories = <BaiduLiveCategory>[];
    final seen = <String>{};
    for (final value in _list(tab['items'])) {
      final item = _map(value);
      final id = _text(item['type']).toLowerCase();
      final name = _text(item['name']);
      final channelId = _positive(item['channel_id']);
      if (RegExp(r'^[a-z][a-z0-9_]{0,31}$').hasMatch(id) && name.isNotEmpty && channelId != null && seen.add(id)) {
        categories.add(BaiduLiveCategory(id: id, name: name, channelId: channelId));
      }
    }
    return List.unmodifiable(categories);
  }

  static BaiduLiveRoom parseRoomJson(Object? value, {required String expectedRoomId}) {
    final roomId = BaiduLiveLink.parseRoomId(expectedRoomId);
    if (roomId == null) throw const BaiduLiveException(BaiduLiveFailure.identity);
    final root = _map(value);
    if (_integer(root['errno']) != 0) throw const BaiduLiveException(BaiduLiveFailure.service);
    final command = _map(_map(root['data'])['371']);
    if (command.isEmpty) throw const BaiduLiveException(BaiduLiveFailure.missing);
    final error = _integer(command['error_code']);
    if (error != 0) {
      throw BaiduLiveException(error == 1 || error == 4 ? BaiduLiveFailure.missing : BaiduLiveFailure.service);
    }
    final shareUrl = _text(command['share_url']);
    final sharedRoomId = shareUrl.isEmpty ? null : BaiduLiveLink.parseRoomId(shareUrl);
    if (sharedRoomId != null && sharedRoomId != roomId) {
      throw const BaiduLiveException(BaiduLiveFailure.identity);
    }
    final host = _map(command['host']);
    final video = _map(command['video']);
    if (host.isEmpty && video.isEmpty) throw const BaiduLiveException(BaiduLiveFailure.missing);
    final state = _detailState(command);
    final nick = _firstText([host['nick_name'], host['name']], fallback: 'Baidu Live');
    final cover = _map(video['cover']);
    final variants = state == BaiduLiveState.live ? _detailVariants(video, roomId) : const <BaiduLiveVariant>[];
    return BaiduLiveRoom(
      roomId: roomId,
      userId: _text(host['uk']),
      nick: nick,
      title: _firstText([video['title'], nick], fallback: 'Baidu Live'),
      avatar: _image(_map(host['image'])['image_33']),
      cover: _firstImage([cover['cover_100'], cover['vertical_cover']]),
      category: _text(command['category']),
      currentViewers: state == BaiduLiveState.live ? _nonNegative(command['online_users']) : null,
      followers: _nonNegative(command['real_fans_num'] ?? host['fans']),
      state: state,
      variants: variants,
    );
  }

  static Uri? validateMediaUri(String raw, {required String expectedRoomId, required String protocol}) {
    var uri = Uri.tryParse(raw.trim());
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    if (uri.scheme == 'http' && _allowedMediaHost(host)) uri = uri.replace(scheme: 'https');
    final extension = protocol == 'hls' ? '.m3u8' : '.flv';
    if (uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        (uri.hasPort && uri.port != 443) ||
        !_allowedMediaHost(host) ||
        !uri.path.startsWith('/live/') ||
        !uri.path.toLowerCase().endsWith(extension) ||
        !RegExp('(?:^|_)${RegExp.escape(expectedRoomId)}(?:[-./]|\$)').hasMatch(uri.path)) {
      return null;
    }
    return uri;
  }

  static List<BaiduLiveVariant> _detailVariants(Map<String, Object?> video, String roomId) {
    final grouped = <String, ({String protocol, int resolution, String codec, List<Uri> urls})>{};

    void add(String raw, String protocol, int resolution, String codec) {
      final uri = validateMediaUri(raw, expectedRoomId: roomId, protocol: protocol);
      if (uri == null) return;
      final id = '$protocol:$resolution:$codec';
      final bucket = grouped.putIfAbsent(
        id,
        () => (protocol: protocol, resolution: resolution, codec: codec, urls: <Uri>[]),
      );
      if (!bucket.urls.contains(uri)) bucket.urls.add(uri);
    }

    final clarity = _list(video['url_clarity_list']);
    for (final value in clarity) {
      final item = _map(value);
      final resolution = _positive(item['resolution']) ?? 0;
      final urls = _map(item['urls']);
      add(_text(urls['avc_flv']), 'flv', resolution, 'avc');
      add(_text(urls['flv']), 'flv', resolution, 'avc');
      add(_text(urls['hls']), 'hls', resolution, 'avc');
    }

    final urlList = _list(video['url_list']);
    for (final value in urlList) {
      final item = _map(value);
      final resolution = _positive(item['resolution']) ?? 0;
      for (final rawUrls in _list(item['urls'])) {
        final urls = _map(rawUrls);
        add(_text(urls['flv']), 'flv', resolution, 'avc');
        add(_text(urls['hls']), 'hls', resolution, 'avc');
      }
    }

    final hls = _text(video['live_hls_url']);
    add(hls, 'hls', _resolutionFor(hls, urlList), 'avc');
    if (clarity.isEmpty) {
      add(_text(video['live_flv_url']), 'flv', 0, 'avc');
      add(_text(video['live_flv_url_origin']), 'flv', 0, 'avc');
    }

    final variants =
        grouped.entries
            .where((entry) => entry.value.urls.isNotEmpty)
            .map(
              (entry) => BaiduLiveVariant(
                id: entry.key,
                protocol: entry.value.protocol,
                resolution: entry.value.resolution,
                codec: entry.value.codec,
                urls: entry.value.urls,
              ),
            )
            .toList(growable: false)
          ..sort((left, right) {
            final resolution = right.resolution.compareTo(left.resolution);
            return resolution != 0 ? resolution : left.protocol.compareTo(right.protocol);
          });
    return List.unmodifiable(variants);
  }

  static int _resolutionFor(String raw, List<Object?> urlList) {
    final candidate = Uri.tryParse(raw);
    if (candidate == null) return 0;
    final name = candidate.pathSegments.isEmpty ? '' : candidate.pathSegments.last;
    for (final value in urlList) {
      final item = _map(value);
      final resolution = _positive(item['resolution']);
      if (resolution == null) continue;
      for (final rawUrls in _list(item['urls'])) {
        final hls = Uri.tryParse(_text(_map(rawUrls)['hls']));
        final other = hls == null || hls.pathSegments.isEmpty ? '' : hls.pathSegments.last;
        if (name.isNotEmpty && other == name) return resolution;
      }
    }
    return 0;
  }

  static BaiduLiveRoom? _directoryCard(Map<String, Object?> item) {
    final roomId = BaiduLiveLink.parseRoomId(_text(item['room_id']));
    if (roomId == null) return null;
    final host = _map(item['host']);
    final state = switch (_integer(item['live_status'])) {
      1 => BaiduLiveState.live,
      0 => BaiduLiveState.preview,
      2 => BaiduLiveState.offline,
      3 => BaiduLiveState.replay,
      _ => BaiduLiveState.unknown,
    };
    final nick = _firstText([host['name']], fallback: 'Baidu Live');
    return BaiduLiveRoom(
      roomId: roomId,
      userId: _text(host['uk']),
      nick: nick,
      title: _firstText([item['title'], nick], fallback: 'Baidu Live'),
      avatar: _image(host['avatar']),
      cover: _image(item['cover']),
      category: _firstText([item['live_tag'], _map(item['left_label'])['text']]),
      currentViewers: state == BaiduLiveState.live ? _nonNegative(item['audience_count']) : null,
      followers: null,
      state: state,
      variants: const [],
    );
  }

  static BaiduLiveState _detailState(Map<String, Object?> command) {
    if ((_integer(command['has_pay_service']) ?? 0) > 0 ||
        (_integer(command['is_forbidden_url']) ?? 0) > 0 ||
        (_integer(command['ban_status']) ?? 0) > 0) {
      return BaiduLiveState.restricted;
    }
    return switch (_integer(command['status'])) {
      0 => BaiduLiveState.live,
      -1 || 1 => BaiduLiveState.preview,
      2 || 20 => BaiduLiveState.offline,
      3 => BaiduLiveState.replay,
      _ => BaiduLiveState.unknown,
    };
  }

  static bool _allowedMediaHost(String host) =>
      host == 'hls-live.bdstatic.com' || host == 'flv-live.bdstatic.com' || host.endsWith('.liveshow.bdstatic.com');

  static String _image(Object? value) {
    final raw = _text(value);
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !_allowedImageHost(uri.host.toLowerCase())) {
      return '';
    }
    return uri.toString();
  }

  static bool _allowedImageHost(String host) =>
      host == 'bdstatic.com' ||
      host.endsWith('.bdstatic.com') ||
      host == 'bdimg.com' ||
      host.endsWith('.bdimg.com') ||
      host == 'bcebos.com' ||
      host.endsWith('.bcebos.com');

  static String _firstImage(Iterable<Object?> values) {
    for (final value in values) {
      final image = _image(value);
      if (image.isNotEmpty) return image;
    }
    return '';
  }

  static Object? _decode(String source) {
    try {
      return jsonDecode(source);
    } on FormatException {
      throw const BaiduLiveException(BaiduLiveFailure.schema);
    }
  }

  static Map<String, Object?> _map(Object? value) {
    if (value is! Map) return const {};
    return value.map((key, entry) => MapEntry('$key', entry));
  }

  static List<Object?> _list(Object? value) => value is List ? value.cast<Object?>() : const [];

  static String _text(Object? value) => value?.toString().trim() ?? '';

  static String _firstText(Iterable<Object?> values, {String fallback = ''}) {
    for (final value in values) {
      final text = _text(value);
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  static int? _integer(Object? value) => switch (value) {
    int number => number,
    num number when number.isFinite && number == number.roundToDouble() => number.toInt(),
    String text => int.tryParse(text.trim()),
    _ => null,
  };

  static int? _nonNegative(Object? value) {
    final number = _integer(value);
    return number != null && number >= 0 ? number : null;
  }

  static int? _positive(Object? value) {
    final number = _integer(value);
    return number != null && number > 0 ? number : null;
  }

  static void _throwStatus(int status) {
    if (status >= 200 && status < 300) return;
    final failure = switch (status) {
      400 || 422 => BaiduLiveFailure.schema,
      401 || 403 || 451 => BaiduLiveFailure.access,
      404 || 410 => BaiduLiveFailure.missing,
      429 => BaiduLiveFailure.rateLimited,
      >= 500 => BaiduLiveFailure.service,
      _ => BaiduLiveFailure.transport,
    };
    throw BaiduLiveException(failure);
  }
}
