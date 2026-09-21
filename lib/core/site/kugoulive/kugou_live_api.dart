import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/common/request_scope.dart';

import 'kugou_live_link.dart';

enum KugouLiveFailure {
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

final class KugouLiveException implements Exception {
  const KugouLiveException(this.kind);

  final KugouLiveFailure kind;

  @override
  String toString() => 'Kugou Live ${kind.name}';
}

enum KugouLiveState { live, offline, restricted, unknown }

final class KugouLiveCategory {
  const KugouLiveCategory({required this.id, required this.name});

  final String id;
  final String name;
}

final class KugouLiveVariant {
  KugouLiveVariant({
    required this.id,
    required this.protocol,
    required this.rate,
    required this.codec,
    required this.layout,
    required Iterable<Uri> urls,
  }) : urls = List.unmodifiable(urls);

  final String id;
  final String protocol;
  final int rate;
  final int codec;
  final int layout;
  final List<Uri> urls;
}

final class KugouLiveRoom {
  KugouLiveRoom({
    required this.roomId,
    required this.userId,
    required this.kugouId,
    required this.nick,
    required this.title,
    required this.avatar,
    required this.cover,
    required this.currentViewers,
    required this.followers,
    required this.popularity,
    required this.state,
    required Iterable<KugouLiveVariant> variants,
  }) : variants = List.unmodifiable(variants);

  final String roomId;
  final String userId;
  final String kugouId;
  final String nick;
  final String title;
  final String avatar;
  final String cover;
  final int? currentViewers;
  final int? followers;
  final int? popularity;
  final KugouLiveState state;
  final List<KugouLiveVariant> variants;

  KugouLiveRoom enrich(KugouLiveRoom known) => KugouLiveRoom(
    roomId: roomId,
    userId: userId.isEmpty ? known.userId : userId,
    kugouId: kugouId.isEmpty ? known.kugouId : kugouId,
    nick: nick == 'Kugou Live' ? known.nick : nick,
    title: title == 'Kugou Live' ? known.title : title,
    avatar: avatar.isEmpty ? known.avatar : avatar,
    cover: cover.isEmpty ? known.cover : cover,
    currentViewers: currentViewers ?? known.currentViewers,
    followers: followers ?? known.followers,
    popularity: popularity ?? known.popularity,
    state: state,
    variants: variants,
  );
}

final class KugouLivePage {
  KugouLivePage({required Iterable<KugouLiveRoom> rooms, required this.hasMore}) : rooms = List.unmodifiable(rooms);

  final List<KugouLiveRoom> rooms;
  final bool hasMore;
}

typedef KugouLiveRequest = Future<({int status, String body})> Function(
  Uri uri,
  Map<String, String> headers,
  CancelToken cancel,
);

class KugouLiveApi {
  KugouLiveApi({KugouLiveRequest? request, this.deadline = const Duration(seconds: 20)})
    : _request = request ?? _defaultRequest;

  static const String webOrigin = 'https://fanxing.kugou.com';
  static const String apiOrigin = 'https://fx1.service.kugou.com';
  static const int responseLimit = 4 * 1024 * 1024;
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';
  static const Map<String, String> apiHeaders = {
    'User-Agent': userAgent,
    'Accept': 'application/json, text/plain, */*',
    'Origin': webOrigin,
    'Referer': '$webOrigin/',
  };
  static const List<KugouLiveCategory> fallbackCategories = [
    KugouLiveCategory(id: '8000', name: '推荐'),
    KugouLiveCategory(id: '100001', name: '一起玩'),
    KugouLiveCategory(id: '100002', name: '音乐'),
    KugouLiveCategory(id: '31050', name: '高清'),
    KugouLiveCategory(id: '7024', name: '舞蹈'),
    KugouLiveCategory(id: '1009', name: '颜值'),
    KugouLiveCategory(id: '1001', name: '新秀'),
    KugouLiveCategory(id: '3007', name: '酷次元'),
    KugouLiveCategory(id: '7041', name: '搞笑'),
    KugouLiveCategory(id: '31', name: '国风'),
    KugouLiveCategory(id: '6201', name: '游戏女神'),
    KugouLiveCategory(id: '6007', name: '王者荣耀'),
    KugouLiveCategory(id: '6004', name: '和平精英'),
    KugouLiveCategory(id: '6003', name: '网游竞技'),
  ];

  static Map<String, String> mediaHeaders(String roomId) => {
    'User-Agent': userAgent,
    'Origin': webOrigin,
    'Referer': KugouLiveLink.watchUrl(roomId),
  };

  final KugouLiveRequest _request;
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
    if (body == null) throw const KugouLiveException(KugouLiveFailure.schema);
    return (status: response.statusCode ?? 0, body: await _readBody(body.stream));
  }

  static Future<String> _readBody(Stream<List<int>> source) async {
    final iterator = StreamIterator(source);
    final bytes = BytesBuilder(copy: false);
    try {
      while (await iterator.moveNext()) {
        if (bytes.length + iterator.current.length > responseLimit) {
          throw const KugouLiveException(KugouLiveFailure.schema);
        }
        bytes.add(iterator.current);
      }
      return utf8.decode(bytes.takeBytes());
    } on FormatException {
      throw const KugouLiveException(KugouLiveFailure.schema);
    } finally {
      await iterator.cancel();
    }
  }

  Future<T> _scope<T>(CancelToken? caller, Future<T> Function(CancelToken) work) =>
      withRequestCancellation(caller, (transport) async {
        if (transport.isCancelled) throw const KugouLiveException(KugouLiveFailure.cancelled);
        try {
          return await Future.any<T>([
            work(transport),
            transport.whenCancel.then<T>((_) => throw const KugouLiveException(KugouLiveFailure.cancelled)),
          ]).timeout(deadline);
        } on TimeoutException {
          throw const KugouLiveException(KugouLiveFailure.transport);
        } catch (error) {
          if (caller?.isCancelled == true || transport.isCancelled) {
            throw const KugouLiveException(KugouLiveFailure.cancelled);
          }
          if (error is KugouLiveException) rethrow;
          throw const KugouLiveException(KugouLiveFailure.transport);
        }
      });

  Future<String> _get(Uri uri, Map<String, String> headers, CancelToken cancel) async {
    if (uri.scheme != 'https' || uri.userInfo.isNotEmpty || uri.hasFragment) {
      throw const KugouLiveException(KugouLiveFailure.identity);
    }
    final response = await _request(uri, headers, cancel);
    _throwStatus(response.status);
    if (response.body.length > responseLimit) throw const KugouLiveException(KugouLiveFailure.schema);
    return response.body;
  }

  Future<List<KugouLiveCategory>> categories({CancelToken? cancel}) => _scope(cancel, (token) async {
    final body = await _get(Uri.parse('$webOrigin/'), apiHeaders, token);
    return parseCategoriesHtml(body);
  });

  Future<KugouLivePage> directory({required int page, String categoryId = '8000', CancelToken? cancel}) =>
      _scope(cancel, (token) async {
        if (page < 1 || page > 10000 || !RegExp(r'^\d{1,8}$').hasMatch(categoryId)) {
          throw const KugouLiveException(KugouLiveFailure.schema);
        }
        final recommend = categoryId == '8000';
        final query = <String, String>{
          'pid': '0',
          'kugouId': '0',
          'doubleLiveFirst': '1',
          'sysVersion': '0',
          'platform': '7',
          'device': 'PureLive-Web',
          'channel': '0',
          'version': '99999',
          'longitude': '0',
          'latitude': '0',
          'appid': '1010',
          'liveTypeFilter': '0',
          'isNew': '0',
          'entranceType': '0',
          'uiMode': '0',
          'page': '$page',
          if (!recommend) 'cid': categoryId,
        };
        final path = recommend ? '/mfanxing-home/h5/cdn/room/index/list' : '/mfanxing-home/h5/cdn/room/index/list_v4';
        final value = _decode(
          await _get(Uri.parse('$apiOrigin$path').replace(queryParameters: query), apiHeaders, token),
        );
        return parseDirectoryJson(value);
      });

  Future<List<KugouLiveRoom>> search(String keyword, {CancelToken? cancel}) => _scope(cancel, (token) async {
    final query = keyword.trim();
    if (query.isEmpty || query.length > 100) throw const KugouLiveException(KugouLiveFailure.identity);
    final callback = 'pureLive${DateTime.now().microsecondsSinceEpoch}';
    final uri = Uri.parse('$apiOrigin/pt_search/pcsearch/v1/type_all.jsonp')
        .replace(queryParameters: {'keywords': query, 'nums': '200,0,0,0', 'callback': callback});
    final body = await _get(uri, apiHeaders, token);
    return parseSearchJsonp(body, callback: callback);
  });

  Future<KugouLiveRoom> room(String rawRoomId, {bool includeMedia = false, CancelToken? cancel}) =>
      _scope(cancel, (token) async {
        final roomId = KugouLiveLink.parseRoomId(rawRoomId);
        if (roomId == null) throw const KugouLiveException(KugouLiveFailure.identity);
        final uri = Uri.parse('https://service2.fanxing.kugou.com/roomcen/room/web/cdn/getEnterRoomInfo')
            .replace(queryParameters: {'roomId': roomId});
        var result = parseRoomJson(_decode(await _get(uri, apiHeaders, token)), expectedRoomId: roomId);
        if (includeMedia && result.state == KugouLiveState.live) {
          final mediaUri = Uri.parse('$apiOrigin/video/pc/live/pull/mutiline/streamaddr').replace(
            queryParameters: {
              'std_rid': roomId,
              'std_plat': '7',
              'std_kid': '0',
              'streamType': '1-2-4-5-8',
              'ua': 'fx-flash',
              'targetLiveTypes': '1-5-6',
              'version': '1000',
              'supportEncryptMode': '1',
              'appid': '1010',
              '_': '${DateTime.now().millisecondsSinceEpoch}',
            },
          );
          final variants = parseMediaJson(_decode(await _get(mediaUri, apiHeaders, token)), expectedRoomId: roomId);
          result = KugouLiveRoom(
            roomId: result.roomId,
            userId: result.userId,
            kugouId: result.kugouId,
            nick: result.nick,
            title: result.title,
            avatar: result.avatar,
            cover: result.cover,
            currentViewers: result.currentViewers,
            followers: result.followers,
            popularity: result.popularity,
            state: result.state,
            variants: variants,
          );
        }
        return result;
      });

  static List<KugouLiveCategory> parseCategoriesHtml(String body) {
    final pattern = RegExp(
      r'''href=["'](?:https://fanxing\.kugou\.com)?/pcindex/category/(\d{1,8})[^"']*["'][^>]*title=["']([^"']+)["']''',
      caseSensitive: false,
    );
    final categories = <KugouLiveCategory>[];
    final seen = <String>{};
    const personalRoutes = {'3001', '3009', '3014', '3015'};
    for (final match in pattern.allMatches(body)) {
      final id = match.group(1)!;
      final name = _htmlText(match.group(2)!);
      if (!personalRoutes.contains(id) && name.isNotEmpty && seen.add(id)) {
        categories.add(KugouLiveCategory(id: id, name: name));
      }
    }
    if (categories.isEmpty) return fallbackCategories;
    return List.unmodifiable(categories);
  }

  static KugouLivePage parseDirectoryJson(Object? value) {
    final data = _responseData(value);
    final rooms = <KugouLiveRoom>[];
    final seen = <String>{};
    for (final entry in _list(data['list'])) {
      final wrapper = _map(entry);
      final raw = wrapper['uiType'] == 'star' ? _map(wrapper['data']) : wrapper;
      final room = _card(raw);
      if (room != null && seen.add(room.roomId)) rooms.add(room);
    }
    return KugouLivePage(rooms: rooms, hasMore: _truthy(data['hasNextPage']));
  }

  static List<KugouLiveRoom> parseSearchJsonp(String body, {String? callback}) {
    final text = body.trim();
    final open = text.indexOf('(');
    final close = text.lastIndexOf(')');
    if (open <= 0 || close <= open || text.substring(close + 1).trim().replaceAll(';', '').isNotEmpty) {
      throw const KugouLiveException(KugouLiveFailure.schema);
    }
    final actual = text.substring(0, open).trim();
    if (!RegExp(r'^[A-Za-z_$][A-Za-z0-9_$.]*$').hasMatch(actual) || (callback != null && actual != callback)) {
      throw const KugouLiveException(KugouLiveFailure.schema);
    }
    final root = _map(_decode(text.substring(open + 1, close)));
    final code = _integer(root['status'] ?? root['code']);
    if (code != null && code != 0 && code != 1) {
      throw const KugouLiveException(KugouLiveFailure.service);
    }
    final anchor = _map(_map(root['data'])['anchor']);
    final rooms = <KugouLiveRoom>[];
    final seen = <String>{};
    for (final value in _list(anchor['list'])) {
      final room = _card(_map(value));
      if (room != null && seen.add(room.roomId)) rooms.add(room);
    }
    return List.unmodifiable(rooms);
  }

  static KugouLiveRoom parseRoomJson(Object? value, {required String expectedRoomId}) {
    final roomId = KugouLiveLink.parseRoomId(expectedRoomId);
    if (roomId == null) throw const KugouLiveException(KugouLiveFailure.identity);
    final data = _responseData(value);
    final normal = _map(data['normalRoomInfo']);
    if (normal.isEmpty || (_string(normal['nickName']).isEmpty && _string(normal['kugouId']).isEmpty)) {
      throw const KugouLiveException(KugouLiveFailure.missing);
    }
    final limit = _integer(normal['limitType']) ?? 0;
    final liveType = _integer(data['liveType']);
    final session = _string(data['liveSessionId']);
    final state = limit > 0
        ? KugouLiveState.restricted
        : liveType == -1
        ? KugouLiveState.offline
        : session.isNotEmpty
        ? KugouLiveState.live
        : KugouLiveState.unknown;
    final nick = _string(normal['nickName']);
    return KugouLiveRoom(
      roomId: roomId,
      userId: _string(normal['userId']),
      kugouId: _string(normal['kugouId']),
      nick: nick.isEmpty ? 'Kugou Live' : nick,
      title: _firstText([normal['publicMesg'], normal['privateMesg'], nick], fallback: 'Kugou Live'),
      avatar: _image(_string(normal['userLogo'])),
      cover: _image(_string(normal['imgPath'])),
      currentViewers: null,
      followers: _integer(normal['fansCount']),
      popularity: null,
      state: state,
      variants: const [],
    );
  }

  static List<KugouLiveVariant> parseMediaJson(Object? value, {required String expectedRoomId}) {
    final roomId = KugouLiveLink.parseRoomId(expectedRoomId);
    if (roomId == null) throw const KugouLiveException(KugouLiveFailure.identity);
    final data = _responseData(value);
    if (_string(data['roomId']) != roomId || _integer(data['status']) != 1) {
      throw const KugouLiveException(KugouLiveFailure.mediaUnavailable);
    }
    final grouped = <String, ({String protocol, int rate, int codec, int layout, List<Uri> urls})>{};
    for (final lineValue in _list(data['lines'])) {
      final line = _map(lineValue);
      for (final profileValue in _list(line['streamProfiles'])) {
        final profile = _map(profileValue);
        final rate = _integer(profile['rate']) ?? 0;
        final codec = _integer(profile['codec']) ?? 0;
        final layout = _integer(profile['layout']) ?? 0;
        for (final source in const [('httpsFlv', 'flv'), ('httpsHls', 'hls')]) {
          final protocol = source.$2;
          final id = '$protocol:$rate:$codec:$layout';
          final bucket = grouped.putIfAbsent(
            id,
            () => (protocol: protocol, rate: rate, codec: codec, layout: layout, urls: <Uri>[]),
          );
          for (final raw in _list(profile[source.$1])) {
            final uri = validateMediaUri(_string(raw), expectedRoomId: roomId, protocol: protocol);
            if (uri != null && !bucket.urls.contains(uri)) bucket.urls.add(uri);
          }
        }
      }
    }
    final variants =
        grouped.entries
            .where((entry) => entry.value.urls.isNotEmpty)
            .map(
              (entry) => KugouLiveVariant(
                id: entry.key,
                protocol: entry.value.protocol,
                rate: entry.value.rate,
                codec: entry.value.codec,
                layout: entry.value.layout,
                urls: entry.value.urls,
              ),
            )
            .toList(growable: false)
          ..sort((left, right) => right.rate.compareTo(left.rate));
    if (variants.isEmpty) throw const KugouLiveException(KugouLiveFailure.mediaUnavailable);
    return List.unmodifiable(variants);
  }

  static Uri? validateMediaUri(String raw, {required String expectedRoomId, required String protocol}) {
    final uri = Uri.tryParse(raw);
    final expectedExtension = protocol == 'hls' ? '.m3u8' : '.flv';
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        (uri.hasPort && uri.port != 443) ||
        !(uri.host == 'liveplay.live.kugou.com' || uri.host.endsWith('.liveplay.live.kugou.com')) ||
        !uri.path.startsWith('/live/') ||
        !uri.path.toLowerCase().endsWith(expectedExtension) ||
        _string(uri.queryParameters['txSecret']).isEmpty ||
        !RegExp(r'^[0-9A-Fa-f]{8,16}$').hasMatch(_string(uri.queryParameters['txTime']))) {
      return null;
    }
    final token = uri.queryParameters['token'] ?? '';
    return token.startsWith('0-$expectedRoomId-') ? uri : null;
  }

  static DateTime? mediaInvalidAt(String raw) {
    final uri = Uri.tryParse(raw);
    final value = uri?.queryParameters['txTime'];
    if (value == null || !RegExp(r'^[0-9A-Fa-f]{8,16}$').hasMatch(value)) return null;
    final seconds = int.tryParse(value, radix: 16);
    return seconds == null ? null : DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }

  static DateTime? mediaRefreshAt(String raw, {DateTime? now}) {
    final invalid = mediaInvalidAt(raw);
    if (invalid == null) return null;
    final current = now ?? DateTime.now();
    final refresh = invalid.subtract(const Duration(minutes: 5));
    return refresh.isAfter(current) ? refresh : current;
  }

  static KugouLiveRoom? _card(Map<String, Object?> raw) {
    final roomId = KugouLiveLink.parseRoomId(_string(raw['roomId']));
    if (roomId == null) return null;
    final live = _integer(raw['liveStatus'] ?? raw['status'] ?? raw['liveType']);
    final state = live == 1
        ? KugouLiveState.live
        : live == 0 || live == -1
        ? KugouLiveState.offline
        : KugouLiveState.unknown;
    final nick = _string(raw['nickName']);
    return KugouLiveRoom(
      roomId: roomId,
      userId: _string(raw['userId']),
      kugouId: _string(raw['kugouId']),
      nick: nick.isEmpty ? 'Kugou Live' : nick,
      title: _firstText([raw['label'], raw['topicContent'], raw['performContent'], nick], fallback: 'Kugou Live'),
      avatar: _image(_string(raw['userLogo'] ?? raw['logo'])),
      cover: _image(_string(raw['imgPath'] ?? raw['imagePath'])),
      currentViewers: _integer(raw['viewerNum'] ?? raw['getViewerNum']),
      followers: _integer(raw['fansCount']),
      popularity: _integer(raw['hot']),
      state: state,
      variants: const [],
    );
  }

  static Map<String, Object?> _responseData(Object? value) {
    final root = _map(value);
    final code = _integer(root['code']);
    if (code != 0) throw const KugouLiveException(KugouLiveFailure.service);
    final data = _map(root['data']);
    if (data.isEmpty) throw const KugouLiveException(KugouLiveFailure.schema);
    return data;
  }

  static Object? _decode(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      throw const KugouLiveException(KugouLiveFailure.schema);
    }
  }

  static Map<String, Object?> _map(Object? value) {
    if (value is! Map) return const {};
    return value.map((key, value) => MapEntry('$key', value));
  }

  static List<Object?> _list(Object? value) => value is List ? value.cast<Object?>() : const [];

  static String _string(Object? value) => value == null ? '' : '$value'.trim();

  static int? _integer(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(_string(value));
  }

  static bool _truthy(Object? value) => value == true || _integer(value) == 1;

  static String _firstText(List<Object?> values, {required String fallback}) {
    for (final value in values) {
      final text = _string(value);
      if (text.isNotEmpty && text != 'null') return text;
    }
    return fallback;
  }

  static String _image(String raw) {
    var value = raw.trim();
    if (value.isEmpty || value == 'null') return '';
    value = value.replaceFirst('/v2/fxuserlogo//v2/fxuserlogo/', '/v2/fxuserlogo/');
    if (value.startsWith('//')) value = 'https:$value';
    if (value.startsWith('/')) value = 'https://p3.fx.kgimg.com$value';
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != 80 && uri.port != 443) ||
        !(uri.host == 'kgimg.com' ||
            uri.host.endsWith('.kgimg.com') ||
            uri.host == 'kugou.com' ||
            uri.host.endsWith('.kugou.com'))) {
      return '';
    }
    if (uri.scheme == 'http') value = uri.replace(scheme: 'https').toString();
    return Uri.tryParse(value)?.scheme == 'https' ? value : '';
  }

  static String _htmlText(String raw) => raw
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .trim();

  static void _throwStatus(int status) {
    if (status >= 200 && status < 300) return;
    final failure = switch (status) {
      400 || 422 => KugouLiveFailure.schema,
      401 || 403 || 451 => KugouLiveFailure.access,
      404 || 410 => KugouLiveFailure.missing,
      429 => KugouLiveFailure.rateLimited,
      >= 500 => KugouLiveFailure.service,
      _ => KugouLiveFailure.transport,
    };
    throw KugouLiveException(failure);
  }
}
