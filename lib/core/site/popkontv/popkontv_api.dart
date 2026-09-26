import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/common/request_scope.dart';

import 'popkontv_link.dart';

enum PopkonFailure {
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

class PopkonException implements Exception {
  const PopkonException(this.kind);
  final PopkonFailure kind;

  @override
  String toString() => 'PopkonTV ${kind.name}';
}

enum PopkonState { live, offline, unknown }

enum PopkonAccess { public, password, adult, restricted }

final class PopkonCard {
  const PopkonCard({
    required this.signId,
    required this.partnerCode,
    required this.nickname,
    required this.title,
    required this.avatar,
    required this.cover,
    required this.category,
    required this.onlineViewers,
    required this.totalViewers,
    required this.followers,
    required this.isAdult,
    required this.isPrivate,
    required this.castStartCode,
    required this.castType,
  });

  final String signId;
  final String partnerCode;
  final String nickname;
  final String title;
  final String avatar;
  final String cover;
  final String category;
  final int? onlineViewers;
  final int? totalViewers;
  final int? followers;
  final bool isAdult;
  final bool isPrivate;
  final String castStartCode;
  final int castType;

  String get roomId => PopkonChannelKey(signId: signId, partnerCode: partnerCode).storageKey;
}

final class PopkonDirectoryPage {
  PopkonDirectoryPage({required Iterable<PopkonCard> rooms, required this.page, required this.hasMore})
    : rooms = List.unmodifiable(rooms);

  final List<PopkonCard> rooms;
  final int page;
  final bool hasMore;
}

final class PopkonStream {
  const PopkonStream({
    required this.id,
    required this.label,
    required this.height,
    required this.bandwidth,
    required this.uri,
  });

  final String id;
  final String label;
  final int height;
  final int bandwidth;
  final Uri uri;
}

final class PopkonRoom {
  PopkonRoom({
    required this.signId,
    required this.partnerCode,
    required this.nickname,
    required this.title,
    required this.avatar,
    required this.cover,
    required this.category,
    required this.onlineViewers,
    required this.totalViewers,
    required this.followers,
    required this.state,
    required this.access,
    required Iterable<PopkonStream> streams,
  }) : streams = List.unmodifiable(streams);

  final String signId;
  final String partnerCode;
  final String nickname;
  final String title;
  final String avatar;
  final String cover;
  final String category;
  final int? onlineViewers;
  final int? totalViewers;
  final int? followers;
  final PopkonState state;
  final PopkonAccess access;
  final List<PopkonStream> streams;

  String get roomId => PopkonChannelKey(signId: signId, partnerCode: partnerCode).storageKey;
}

typedef PopkonRequest = Future<({int status, String body})> Function(
  String method,
  Uri uri,
  Object? data,
  String referer,
  CancelToken cancel,
);

/// Current public PopkonTV Web contract. The official browser sends all API
/// requests through `/api/proxy` and obtains a short-lived HLS session before
/// reading the master playlist.
class PopkonApi {
  PopkonApi({PopkonRequest? request, this.deadline = const Duration(seconds: 20)})
    : _request = request ?? _defaultRequest;

  static const origin = 'https://www.popkontv.com';
  static const apiOrigin = '$origin/api/proxy';
  static const defaultPartnerCode = 'P-00001';
  static const responseLimit = 4 * 1024 * 1024;
  static const manifestLimit = 1024 * 1024;
  static const clientKey = 'Client FpAhe6mh8Qtz116OENBmRddbYVirNKasktdXQiuHfm88zRaFydTsFy63tzkdZY0u';
  static const userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';

  static Map<String, String> requestHeaders(String referer) => {
    'User-Agent': userAgent,
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'ko-KR,ko;q=0.9,en;q=0.8',
    'Content-Type': Headers.jsonContentType,
    'ClientKey': clientKey,
    'Origin': origin,
    'Referer': referer,
  };

  static Map<String, String> mediaHeaders(String roomId) => {
    'User-Agent': userAgent,
    'Origin': origin,
    'Referer': PopkonLink.url(roomId),
  };

  final PopkonRequest _request;
  final Duration deadline;

  static Future<({int status, String body})> _defaultRequest(
    String method,
    Uri uri,
    Object? data,
    String referer,
    CancelToken cancel,
  ) async {
    final response = await HttpClient.instance.dio.request<ResponseBody>(
      uri.toString(),
      data: data,
      cancelToken: cancel,
      options: Options(
        method: method,
        responseType: ResponseType.stream,
        followRedirects: false,
        headers: method == 'GET' ? mediaHeadersFromReferer(referer) : requestHeaders(referer),
        contentType: data == null ? null : Headers.jsonContentType,
        receiveTimeout: const Duration(seconds: 20),
        validateStatus: (_) => true,
      ),
    );
    final body = response.data;
    if (body == null) throw const PopkonException(PopkonFailure.schema);
    if (response.statusCode != 200) {
      await body.stream.listen((_) {}).cancel();
      return (status: response.statusCode ?? 0, body: '');
    }
    return (status: 200, body: await readBody(body.stream, limit: method == 'GET' ? manifestLimit : responseLimit));
  }

  static Map<String, String> mediaHeadersFromReferer(String referer) => {
    'User-Agent': userAgent,
    'Origin': origin,
    'Referer': referer,
  };

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
        if (remaining <= Duration.zero) throw TimeoutException('PopkonTV response deadline');
        if (!await iterator.moveNext().timeout(remaining)) break;
        if (bytes.length + iterator.current.length > limit) throw const PopkonException(PopkonFailure.schema);
        bytes.add(iterator.current);
      }
      return utf8.decode(bytes.takeBytes());
    } on FormatException {
      throw const PopkonException(PopkonFailure.schema);
    } finally {
      watch.stop();
      await iterator.cancel();
    }
  }

  Future<T> _scope<T>(CancelToken? caller, Future<T> Function(CancelToken) work) =>
      withRequestCancellation(caller, (transport) async {
        if (transport.isCancelled) throw const PopkonException(PopkonFailure.cancelled);
        try {
          return await Future.any<T>([
            work(transport),
            transport.whenCancel.then<T>((_) => throw const PopkonException(PopkonFailure.cancelled)),
          ]).timeout(deadline);
        } on TimeoutException {
          throw const PopkonException(PopkonFailure.transport);
        } catch (error) {
          if (caller?.isCancelled == true) throw const PopkonException(PopkonFailure.cancelled);
          if (error is PopkonException) rethrow;
          throw const PopkonException(PopkonFailure.transport);
        }
      });

  Future<String> _read(
    String method,
    Uri uri,
    Object? data,
    String referer,
    CancelToken cancel, {
    bool manifest = false,
  }) async {
    if (cancel.isCancelled) throw const PopkonException(PopkonFailure.cancelled);
    final response = await _request(method, uri, data, referer, cancel);
    if (cancel.isCancelled) throw const PopkonException(PopkonFailure.cancelled);
    final failure = switch (response.status) {
      200 => null,
      400 => PopkonFailure.schema,
      401 || 403 => PopkonFailure.access,
      404 => PopkonFailure.missing,
      429 => PopkonFailure.rateLimited,
      >= 500 => PopkonFailure.service,
      _ => PopkonFailure.transport,
    };
    if (failure != null) throw PopkonException(failure);
    final limit = manifest ? manifestLimit : responseLimit;
    if (response.body.length > limit || utf8.encode(response.body).length > limit) {
      throw const PopkonException(PopkonFailure.schema);
    }
    return response.body;
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> data, String referer, CancelToken cancel) async {
    final body = await _read('POST', Uri.parse('$apiOrigin$path'), data, referer, cancel);
    try {
      return _object(jsonDecode(body));
    } on FormatException {
      throw const PopkonException(PopkonFailure.schema);
    }
  }

  Future<PopkonDirectoryPage> directory({int page = 1, int size = 30, int sortType = 2, CancelToken? cancel}) =>
      _scope(cancel, (token) async {
        if (page < 1 || page > 1000 || size < 1 || size > 50 || !const {0, 2, 3, 4}.contains(sortType)) {
          throw const PopkonException(PopkonFailure.schema);
        }
        final root = await _post(
          '/broadcast/v3.1/livelist',
          {
            'castListTarget': 0,
            'main': false,
            'pageNum': page,
            'pageSize': size,
            'partnerCode': defaultPartnerCode,
            'signId': '',
            'sortType': sortType,
            'chrFanPchrgBrdcExpyn': true,
          },
          '$origin/live-more',
          token,
        );
        _requireStatus(root, 'S2000');
        final data = _object(root['data']);
        final responsePage = _positiveInt(data['pageNum']);
        final totalPage = _nonNegativeInt(data['totalPage']);
        if (responsePage != page) throw const PopkonException(PopkonFailure.identity);
        final rooms = _list(
          data['list'],
          max: 80,
        ).map((value) => parseDirectoryCard(_object(value))).toList(growable: false);
        return PopkonDirectoryPage(rooms: rooms, page: page, hasMore: page < totalPage);
      });

  Future<List<PopkonRoom>> search(String rawKeyword, {CancelToken? cancel}) => _scope(cancel, (token) async {
    final keyword = _keyword(rawKeyword);
    final root = await _post(
      '/broadcast/v1.1/search/all',
      {'partnerCode': defaultPartnerCode, 'searchKeyword': keyword, 'signId': ''},
      origin,
      token,
    );
    _requireStatus(root, 'S2000');
    final data = _object(root['data']);
    final profiles = <String, Map<String, dynamic>>{};
    for (final item in _nullableList(data['broadCastList'], max: 100)) {
      final profile = _object(item);
      final signId = _signId(profile['mcSignId']);
      final partner = _partner(profile['mcPartnerCode']);
      profiles['${signId.toLowerCase()}@$partner'] = profile;
    }
    final rooms = <PopkonRoom>[];
    final liveKeys = <String>{};
    for (final item in _nullableList(data['liveList'], max: 100)) {
      final live = _object(item);
      final card = parseSearchLive(live);
      final key = '${card.signId.toLowerCase()}@${card.partnerCode}';
      liveKeys.add(key);
      rooms.add(_roomFromCard(card, access: _cardAccess(card)));
    }
    for (final entry in profiles.entries) {
      if (liveKeys.contains(entry.key)) continue;
      rooms.add(parseProfile(entry.value));
    }
    return List.unmodifiable(rooms);
  });

  Future<PopkonRoom> room(String rawRoomId, {bool resolveMedia = true, CancelToken? cancel}) =>
      _scope(cancel, (token) async {
        final key = PopkonLink.parseKey(rawRoomId);
        if (key == null) throw const PopkonException(PopkonFailure.identity);
        final root = await _post(
          '/broadcast/v1.1/search/all',
          {'partnerCode': defaultPartnerCode, 'searchKeyword': key.signId, 'signId': ''},
          origin,
          token,
        );
        _requireStatus(root, 'S2000');
        final data = _object(root['data']);
        Map<String, dynamic>? profile;
        for (final item in _nullableList(data['broadCastList'], max: 100)) {
          final candidate = _object(item);
          if (_matchesKey(candidate['mcSignId'], candidate['mcPartnerCode'], key)) {
            profile = candidate;
            break;
          }
        }
        PopkonCard? card;
        for (final item in _nullableList(data['liveList'], max: 100)) {
          final candidate = parseSearchLive(_object(item));
          if (_matches(candidate.signId, candidate.partnerCode, key)) {
            card = candidate;
            break;
          }
        }
        if (card == null) {
          if (profile == null) throw const PopkonException(PopkonFailure.missing);
          card = await _findLiveInDirectory(key, token);
          if (card == null) return parseProfile(profile);
        }
        final access = _cardAccess(card);
        if (!resolveMedia || access != PopkonAccess.public) return _roomFromCard(card, access: access);
        final session = await _watch(card, token);
        if (session == null) return _roomFromCard(card, access: PopkonAccess.restricted);
        final referer = PopkonLink.url(card.roomId);
        final source = await _read('GET', session, null, referer, token, manifest: true);
        final streams = parseManifest(session, source);
        if (streams.isEmpty) throw const PopkonException(PopkonFailure.mediaUnavailable);
        return _roomFromCard(card, access: PopkonAccess.public, streams: streams);
      });

  // Guest search/all omits adult broadcasts from `liveList` (it still returns
  // the profile), while the public livelist keeps them. Without this lookup
  // every adult room opened from the directory was reported offline.
  static const _directoryLookupPages = 3;
  static const _directorySnapshotTtl = Duration(seconds: 60);
  ({DateTime at, List<PopkonCard> cards})? _directorySnapshot;

  Future<PopkonCard?> _findLiveInDirectory(PopkonChannelKey key, CancelToken token) async {
    final cached = _directorySnapshot;
    var cards = cached?.cards;
    if (cached == null || DateTime.now().difference(cached.at) >= _directorySnapshotTtl) {
      final collected = <PopkonCard>[];
      for (var page = 1; page <= _directoryLookupPages; page++) {
        final result = await directory(page: page, size: 50, cancel: token);
        collected.addAll(result.rooms);
        if (!result.hasMore) break;
      }
      cards = List<PopkonCard>.unmodifiable(collected);
      _directorySnapshot = (at: DateTime.now(), cards: cards);
    }
    for (final card in cards!) {
      if (_matches(card.signId, card.partnerCode, key)) return card;
    }
    return null;
  }

  Future<Uri?> _watch(PopkonCard card, CancelToken cancel) async {
    Future<Map<String, dynamic>> request(String startCode) => _post(
      '/broadcast/v1/castwatchonoffguest',
      {
        'androidStore': 0,
        'castCode': '${card.signId}-$startCode',
        'castPartnerCode': card.partnerCode,
        'castSignId': card.signId,
        'castType': card.castType,
        'commandType': 0,
        'exePath': 5,
        'isSecret': card.isPrivate ? 1 : 0,
        'partnerCode': defaultPartnerCode,
        'password': '',
        'signId': '',
        'version': '4.6.2',
      },
      PopkonLink.url(card.roomId),
      cancel,
    );

    var root = await request(card.castStartCode);
    var status = _optionalText(root['statusCd']);
    if (status == 'L0001') {
      final start = int.tryParse(card.castStartCode);
      if (start == null || start <= 0) throw const PopkonException(PopkonFailure.schema);
      root = await request('${start - 1}');
      status = _optionalText(root['statusCd']);
    }
    if (status == 'L000A' || status.startsWith('E')) return null;
    if (status != 'L0000') throw const PopkonException(PopkonFailure.api);
    final data = _object(root['data']);
    return _mediaUri(_text(data['castHlsUrl']));
  }

  static PopkonCard parseDirectoryCard(Map<String, dynamic> data) => PopkonCard(
    signId: _signId(data['signId']),
    partnerCode: _partner(data['partnerCode']),
    nickname: _text(data['nickName']),
    title: _firstText([data['castTitle'], data['nickName']]),
    avatar: _image(data['pfileName']),
    cover: _firstImage([data['imgUrl'], data['pfileName'], data['onErrorImg']]),
    category: _category(data['category']),
    onlineViewers: _optionalNonNegativeInt(data['watchCnt']),
    totalViewers: _optionalNonNegativeInt(data['totalWatchCnt']),
    followers: _optionalNonNegativeInt(data['bookmarkCnt']),
    isAdult: _flag(data['isAdult']),
    isPrivate: _flag(data['isPrivate']),
    castStartCode: _startCode(data['castStartDateCode']),
    castType: _nonNegativeInt(data['castType']),
  );

  static PopkonCard parseSearchLive(Map<String, dynamic> data) => PopkonCard(
    signId: _signId(data['mcSignId']),
    partnerCode: _partner(data['mcPartnerCode']),
    nickname: _text(data['mcNickName']),
    title: _firstText([data['castTitle'], data['mcNickName']]),
    avatar: _image(data['mcPFileName']),
    cover: _firstImage([data['imgUrl'], data['mcPFileName'], data['onErrorImg']]),
    category: _category(data['mcCategory']),
    onlineViewers: _optionalNonNegativeInt(data['watchCnt']),
    totalViewers: _optionalNonNegativeInt(data['totalWatchCnt']),
    followers: _optionalNonNegativeInt(data['bookmark']),
    isAdult: _flag(data['isAdult']),
    isPrivate: _flag(data['isPrivate']),
    castStartCode: _startCode(data['castStartDateCode']),
    castType: _nonNegativeInt(data['castType']),
  );

  static PopkonRoom parseProfile(Map<String, dynamic> data) {
    final signId = _signId(data['mcSignId']);
    final partner = _partner(data['mcPartnerCode']);
    final nickname = _text(data['nickName']);
    return PopkonRoom(
      signId: signId,
      partnerCode: partner,
      nickname: nickname,
      title: nickname,
      avatar: _image(data['mcPFileName']),
      cover: '',
      category: '',
      onlineViewers: null,
      totalViewers: null,
      followers: null,
      state: PopkonState.offline,
      access: PopkonAccess.public,
      streams: const [],
    );
  }

  static List<PopkonStream> parseManifest(Uri master, String source) {
    _mediaUri(master.toString());
    if (source.length > manifestLimit || !source.trimLeft().startsWith('#EXTM3U')) {
      throw const PopkonException(PopkonFailure.schema);
    }
    final lines = const LineSplitter().convert(source);
    final streams = <PopkonStream>[];
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
        throw const PopkonException(PopkonFailure.schema);
      }
      final match = RegExp(r'^[1-9][0-9]{1,4}x([1-9][0-9]{1,4})$').firstMatch(attributes['RESOLUTION'] ?? '');
      if (match == null) throw const PopkonException(PopkonFailure.schema);
      final height = int.parse(match.group(1)!);
      final bandwidth = int.tryParse(attributes['BANDWIDTH'] ?? '') ?? 0;
      if (bandwidth < 0) throw const PopkonException(PopkonFailure.schema);
      final uri = _mediaUri(master.resolve(lines[next].trim()).toString());
      final baseId = '${height}p';
      final id = ids.add(baseId) ? baseId : '${baseId}_${streams.length + 1}';
      streams.add(PopkonStream(id: id, label: baseId, height: height, bandwidth: bandwidth, uri: uri));
      index = next;
    }
    if (streams.isEmpty) {
      streams.add(PopkonStream(id: 'source', label: 'Source', height: 0, bandwidth: 0, uri: master));
    } else {
      streams.sort((left, right) {
        final resolution = right.height.compareTo(left.height);
        return resolution != 0 ? resolution : right.bandwidth.compareTo(left.bandwidth);
      });
    }
    return List.unmodifiable(streams);
  }

  static PopkonRoom _roomFromCard(
    PopkonCard card, {
    required PopkonAccess access,
    List<PopkonStream> streams = const [],
  }) => PopkonRoom(
    signId: card.signId,
    partnerCode: card.partnerCode,
    nickname: card.nickname,
    title: card.title,
    avatar: card.avatar,
    cover: card.cover,
    category: card.category,
    onlineViewers: card.onlineViewers,
    totalViewers: card.totalViewers,
    followers: card.followers,
    state: PopkonState.live,
    access: access,
    streams: streams,
  );

  static PopkonAccess _cardAccess(PopkonCard card) => card.isPrivate
      ? PopkonAccess.password
      : card.isAdult
      ? PopkonAccess.adult
      : PopkonAccess.public;

  static bool _matchesKey(Object? signId, Object? partnerCode, PopkonChannelKey key) {
    final sign = PopkonLink.normalizeSignId(signId);
    final partner = PopkonLink.normalizePartnerCode(partnerCode);
    return sign != null && partner != null && _matches(sign, partner, key);
  }

  static bool _matches(String signId, String partnerCode, PopkonChannelKey key) =>
      signId.toLowerCase() == key.signId.toLowerCase() && (key.partnerCode == null || partnerCode == key.partnerCode);

  static Uri _mediaUri(String raw) {
    if (raw.isEmpty || raw.length > 65536 || RegExp(r'[\s\x00-\x1f]').hasMatch(raw)) {
      throw const PopkonException(PopkonFailure.schema);
    }
    final uri = Uri.tryParse(raw);
    final host = uri?.host.toLowerCase() ?? '';
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !(host == 'hscdn.com' || host.endsWith('.hscdn.com')) ||
        !uri.path.toLowerCase().endsWith('.m3u8')) {
      throw const PopkonException(PopkonFailure.schema);
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

  static void _requireStatus(Map<String, dynamic> root, String expected) {
    if (_optionalText(root['statusCd']) != expected) throw const PopkonException(PopkonFailure.api);
  }

  static String _keyword(String raw) {
    final value = raw.trim();
    if (value.isEmpty || value.length > 100 || RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
      throw const PopkonException(PopkonFailure.schema);
    }
    return value;
  }

  static String _signId(Object? value) {
    final result = PopkonLink.normalizeSignId(value);
    if (result == null) throw const PopkonException(PopkonFailure.schema);
    return result;
  }

  static String _partner(Object? value) {
    final result = PopkonLink.normalizePartnerCode(value);
    if (result == null) throw const PopkonException(PopkonFailure.schema);
    return result;
  }

  static String _startCode(Object? value) {
    final text = value is String ? value.trim() : '$value';
    if (!RegExp(r'^[0-9]{12,20}$').hasMatch(text)) throw const PopkonException(PopkonFailure.schema);
    return text;
  }

  static String _category(Object? value) {
    final category = _nonNegativeInt(value);
    return category == 0 ? '' : 'Category $category';
  }

  static bool _flag(Object? value) {
    if (value == true || value == 1 || value == '1') return true;
    if (value == false || value == 0 || value == '0' || value == null) return false;
    throw const PopkonException(PopkonFailure.schema);
  }

  static String _image(Object? value) {
    final raw = _optionalText(value);
    if (raw.isEmpty) return '';
    final uri = Uri.tryParse(raw);
    final host = uri?.host.toLowerCase() ?? '';
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !(host == 'popkontv.com' ||
            host.endsWith('.popkontv.com') ||
            host == 'popcast.co.kr' ||
            host.endsWith('.popcast.co.kr'))) {
      throw const PopkonException(PopkonFailure.schema);
    }
    return uri.toString();
  }

  static String _firstImage(List<Object?> values) {
    for (final value in values) {
      final image = _image(value);
      if (image.isNotEmpty) return image;
    }
    return '';
  }

  static String _firstText(List<Object?> values) {
    for (final value in values) {
      final text = _optionalText(value);
      if (text.isNotEmpty) return text;
    }
    throw const PopkonException(PopkonFailure.schema);
  }

  static String _text(Object? value) {
    final text = _optionalText(value);
    if (text.isEmpty) throw const PopkonException(PopkonFailure.schema);
    return text;
  }

  static String _optionalText(Object? value) {
    if (value == null) return '';
    if (value is! String) throw const PopkonException(PopkonFailure.schema);
    final text = value.trim();
    if (text.length > 65536 || RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]').hasMatch(text)) {
      throw const PopkonException(PopkonFailure.schema);
    }
    return text;
  }

  static int _positiveInt(Object? value) {
    final result = _int(value);
    if (result <= 0) throw const PopkonException(PopkonFailure.schema);
    return result;
  }

  static int _nonNegativeInt(Object? value) {
    final result = _int(value);
    if (result < 0) throw const PopkonException(PopkonFailure.schema);
    return result;
  }

  static int? _optionalNonNegativeInt(Object? value) {
    if (value == null || value == '') return null;
    return _nonNegativeInt(value);
  }

  static int _int(Object? value) {
    if (value is int) return value;
    if (value is String && RegExp(r'^[0-9]+$').hasMatch(value)) return int.parse(value);
    throw const PopkonException(PopkonFailure.schema);
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((key, value) => MapEntry('$key', value));
    throw const PopkonException(PopkonFailure.schema);
  }

  static List<dynamic> _list(Object? value, {required int max}) {
    if (value is! List || value.length > max) throw const PopkonException(PopkonFailure.schema);
    return value;
  }

  static List<dynamic> _nullableList(Object? value, {required int max}) =>
      value == null ? const [] : _list(value, max: max);
}
