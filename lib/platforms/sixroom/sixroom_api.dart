import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/common/request_scope.dart';

import 'sixroom_link.dart';

enum SixRoomFailure { transport, access, missing, rateLimited, service, schema, identity, cancelled, mediaUnavailable }

final class SixRoomException implements Exception {
  const SixRoomException(this.kind);

  final SixRoomFailure kind;

  @override
  String toString() => 'Six Rooms ${kind.name}';
}

enum SixRoomState { live, offline, restricted, unknown }

final class SixRoomCategory {
  const SixRoomCategory({required this.id, required this.name, this.area});

  final String id;
  final String name;
  final String? area;
}

final class SixRoomVariant {
  SixRoomVariant({
    required this.id,
    required this.protocol,
    required this.resolution,
    required this.bitrate,
    required Iterable<Uri> urls,
  }) : urls = List.unmodifiable(urls);

  final String id;
  final String protocol;
  final String resolution;
  final int? bitrate;
  final List<Uri> urls;
}

final class SixRoomRoom {
  SixRoomRoom({
    required this.roomId,
    required this.userId,
    required this.liveId,
    required this.nick,
    required this.title,
    required this.avatar,
    required this.cover,
    required this.category,
    required this.popularity,
    required this.followers,
    required this.state,
    required Iterable<SixRoomVariant> variants,
  }) : variants = List.unmodifiable(variants);

  final String roomId;
  final String userId;
  final String liveId;
  final String nick;
  final String title;
  final String avatar;
  final String cover;
  final String category;
  final int? popularity;
  final int? followers;
  final SixRoomState state;
  final List<SixRoomVariant> variants;

  SixRoomRoom enrich(SixRoomRoom known) => SixRoomRoom(
    roomId: roomId,
    userId: userId.isEmpty ? known.userId : userId,
    liveId: liveId.isEmpty ? known.liveId : liveId,
    nick: nick == 'Six Rooms' ? known.nick : nick,
    title: title == 'Six Rooms' ? known.title : title,
    avatar: avatar.isEmpty ? known.avatar : avatar,
    cover: cover.isEmpty ? known.cover : cover,
    category: category.isEmpty ? known.category : category,
    popularity: popularity ?? known.popularity,
    followers: followers ?? known.followers,
    state: state == SixRoomState.unknown ? known.state : state,
    variants: variants,
  );
}

final class SixRoomPage {
  SixRoomPage({required Iterable<SixRoomRoom> rooms, required this.hasMore}) : rooms = List.unmodifiable(rooms);

  final List<SixRoomRoom> rooms;
  final bool hasMore;
}

typedef SixRoomRequest = Future<({int status, String body})> Function(
  Uri uri,
  Map<String, String> headers,
  Map<String, String>? form,
  CancelToken cancel,
);

class SixRoomApi {
  SixRoomApi({SixRoomRequest? request, this.deadline = const Duration(seconds: 20), DateTime Function()? clock})
    : _request = request ?? _defaultRequest,
      _clock = clock ?? DateTime.now;

  static const String webOrigin = 'https://v.6.cn';
  static const String mobileOrigin = 'https://ios.6.cn';
  static const String mediaOrigin = 'https://wlive.6rooms.com';
  static const int responseLimit = 8 * 1024 * 1024;
  static const Duration directoryCacheLifetime = Duration(seconds: 90);
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';
  static const String mobileUserAgent = 'ios/7.830 (ios 17.0; ; iPhone 15 (A2846/A3089/A3090/A3092))';
  static const List<SixRoomCategory> categories = [
    SixRoomCategory(id: 'all', name: '全部'),
    SixRoomCategory(id: 'song', name: '歌区', area: '歌区'),
    SixRoomCategory(id: 'dance', name: '舞区', area: '舞区'),
    SixRoomCategory(id: 'talk', name: '脱口秀', area: '脱口秀'),
    SixRoomCategory(id: 'face', name: '星颜', area: '星颜'),
    SixRoomCategory(id: 'party', name: '派对', area: '派对'),
  ];
  static const Map<String, String> webHeaders = {
    'User-Agent': userAgent,
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.7',
    'Referer': '$webOrigin/',
  };
  static const Map<String, String> mobileHeaders = {
    'User-Agent': mobileUserAgent,
    'Accept': 'application/json,text/plain,*/*',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.7',
    'Referer': '$mobileOrigin/?ver=8.0.3&build=4',
  };

  static Map<String, String> mediaHeaders(String roomId) => {
    'User-Agent': mobileUserAgent,
    'Origin': webOrigin,
    'Referer': SixRoomLink.watchUrl(roomId),
  };

  final SixRoomRequest _request;
  final DateTime Function() _clock;
  final Duration deadline;
  List<SixRoomRoom>? _directoryCache;
  DateTime? _directoryFetchedAt;

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
    if (body == null) throw const SixRoomException(SixRoomFailure.schema);
    return (status: response.statusCode ?? 0, body: await _readBody(body.stream));
  }

  static Future<String> _readBody(Stream<List<int>> source) async {
    final iterator = StreamIterator(source);
    final bytes = BytesBuilder(copy: false);
    try {
      while (await iterator.moveNext()) {
        if (bytes.length + iterator.current.length > responseLimit) {
          throw const SixRoomException(SixRoomFailure.schema);
        }
        bytes.add(iterator.current);
      }
      return utf8.decode(bytes.takeBytes());
    } on FormatException {
      throw const SixRoomException(SixRoomFailure.schema);
    } finally {
      await iterator.cancel();
    }
  }

  Future<T> _scope<T>(CancelToken? caller, Future<T> Function(CancelToken) work) =>
      withRequestCancellation(caller, (transport) async {
        if (transport.isCancelled) throw const SixRoomException(SixRoomFailure.cancelled);
        try {
          return await Future.any<T>([
            work(transport),
            transport.whenCancel.then<T>((_) => throw const SixRoomException(SixRoomFailure.cancelled)),
          ]).timeout(deadline);
        } on TimeoutException {
          throw const SixRoomException(SixRoomFailure.transport);
        } catch (error) {
          if (caller?.isCancelled == true || transport.isCancelled) {
            throw const SixRoomException(SixRoomFailure.cancelled);
          }
          if (error is SixRoomException) rethrow;
          throw const SixRoomException(SixRoomFailure.transport);
        }
      });

  Future<String> _send(Uri uri, Map<String, String> headers, Map<String, String>? form, CancelToken cancel) async {
    if (uri.scheme != 'https' || uri.userInfo.isNotEmpty || uri.hasFragment) {
      throw const SixRoomException(SixRoomFailure.identity);
    }
    final response = await _request(uri, headers, form, cancel);
    if (response.status < 200 || response.status >= 300) _throwStatus(response.status);
    if (response.body.length > responseLimit) throw const SixRoomException(SixRoomFailure.schema);
    return response.body;
  }

  Future<SixRoomPage> directory({
    required int page,
    required int pageSize,
    String categoryId = 'all',
    CancelToken? cancel,
  }) => _scope(cancel, (token) async {
    if (page < 1 || page > 10000 || pageSize < 1 || pageSize > 100) {
      throw const SixRoomException(SixRoomFailure.schema);
    }
    final category = categories.where((item) => item.id == categoryId).firstOrNull;
    if (category == null) throw const SixRoomException(SixRoomFailure.identity);
    // The lobby document is large and already contains every category.
    // Refresh the canonical "all" first page; category switches reuse that
    // snapshot briefly instead of downloading the same document again.
    final rooms = await _directory(token, forceRefresh: page == 1 && categoryId == 'all');
    final filtered = category.area == null
        ? rooms
        : rooms.where((room) => room.category == category.area).toList(growable: false);
    final start = (page - 1) * pageSize;
    if (start >= filtered.length) return SixRoomPage(rooms: const [], hasMore: false);
    final end = (start + pageSize).clamp(0, filtered.length);
    return SixRoomPage(rooms: filtered.sublist(start, end), hasMore: end < filtered.length);
  });

  Future<List<SixRoomRoom>> _directory(CancelToken token, {required bool forceRefresh}) async {
    final cached = _directoryCache;
    final fetchedAt = _directoryFetchedAt;
    final cacheFresh =
        cached != null &&
        fetchedAt != null &&
        !_clock().isBefore(fetchedAt) &&
        _clock().difference(fetchedAt) < directoryCacheLifetime;
    if (!forceRefresh && cacheFresh) return cached;
    final body = await _send(Uri.parse('$webOrigin/'), webHeaders, null, token);
    final rooms = parseDirectoryHtml(body);
    _directoryCache = rooms;
    _directoryFetchedAt = _clock();
    return rooms;
  }

  Future<List<SixRoomRoom>> search(String keyword, {CancelToken? cancel}) => _scope(cancel, (token) async {
    final value = keyword.trim();
    if (value.isEmpty || value.length > 80) throw const SixRoomException(SixRoomFailure.schema);
    final uri = Uri.parse('$webOrigin/search.php').replace(queryParameters: {'type': 'use', 'key': value});
    final body = await _send(uri, webHeaders, null, token);
    return parseSearchHtml(body);
  });

  Future<SixRoomRoom> room(String rawRoomId, {String? knownUserId, bool includeMedia = true, CancelToken? cancel}) =>
      _scope(cancel, (token) async {
        final roomId = SixRoomLink.parseRoomId(rawRoomId);
        if (roomId == null) throw const SixRoomException(SixRoomFailure.identity);
        var userId = _validUserId(knownUserId) ? knownUserId!.trim() : '';
        if (userId.isEmpty) {
          final html = await _send(Uri.parse(SixRoomLink.watchUrl(roomId)), webHeaders, null, token);
          userId = parseRoomUserIdHtml(html, roomId);
        }
        final body = await _send(
          Uri.parse('$webOrigin/coop/mobile/index.php?padapi=coop-mobile-inroom.php'),
          mobileHeaders,
          {'av': '3.1', 'encpass': '', 'logiuid': '', 'project': 'v6iphone', 'rate': '1', 'rid': '', 'ruid': userId},
          token,
        );
        return parseRoomJson(body, expectedRoomId: roomId, expectedUserId: userId, includeMedia: includeMedia);
      });

  static List<SixRoomRoom> parseDirectoryHtml(String source) {
    final root = _decodeEmbeddedRoot(source);
    Object? rawRooms = root['typeList'];
    if (rawRooms is String) {
      try {
        rawRooms = jsonDecode(rawRooms);
      } on FormatException {
        throw const SixRoomException(SixRoomFailure.schema);
      }
    }
    if (rawRooms is! List) throw const SixRoomException(SixRoomFailure.schema);
    final seen = <String>{};
    final rooms = <SixRoomRoom>[];
    for (final value in rawRooms) {
      final row = _map(value);
      if (row == null) continue;
      final roomId = _string(row['rid']);
      final userId = _string(row['uid']);
      final liveId = _string(row['liveid'] ?? row['lid']);
      if (SixRoomLink.parseRoomId(roomId) != roomId || !_validUserId(userId) || !seen.add(roomId)) continue;
      final nick = _text(row['username'], fallback: 'Six Rooms');
      final title = _firstText([row['livetitle'], row['userMood'], nick], fallback: 'Six Rooms');
      rooms.add(
        SixRoomRoom(
          roomId: roomId,
          userId: userId,
          liveId: liveId,
          nick: nick,
          title: title,
          avatar: _image(row['picuser']),
          cover: _firstImage([row['pospic'], row['pic'], row['pospic_sp']]),
          category: _text(row['anchor_area']),
          popularity: _integer(row['count']),
          followers: null,
          state: SixRoomState.live,
          variants: const [],
        ),
      );
    }
    if (rooms.isEmpty) throw const SixRoomException(SixRoomFailure.schema);
    return List.unmodifiable(rooms);
  }

  static List<SixRoomRoom> parseSearchHtml(String source) {
    final document = html_parser.parse(source);
    final page = document.querySelector('.page-search-user');
    if (page == null) {
      if (document.querySelector('.remind') != null) throw const SixRoomException(SixRoomFailure.access);
      throw const SixRoomException(SixRoomFailure.schema);
    }
    final seen = <String>{};
    final rooms = <SixRoomRoom>[];
    for (final item in page.querySelectorAll('ul.search-user > li[data-uid]')) {
      final userId = (item.attributes['data-uid'] ?? '').trim();
      final href = item.querySelector('a.user-box')?.attributes['href'] ?? '';
      final roomId = SixRoomLink.parseRoomId(Uri.parse(webOrigin).resolve(href).toString());
      if (roomId == null || !_validUserId(userId) || !seen.add(roomId)) continue;
      final image = item.querySelector('.pic img');
      final nick = _text(item.querySelector('.alias')?.text, fallback: 'Six Rooms');
      rooms.add(
        SixRoomRoom(
          roomId: roomId,
          userId: userId,
          liveId: '',
          nick: nick,
          title: nick,
          avatar: _firstImage([image?.attributes['data-src'], image?.attributes['src']]),
          cover: '',
          category: '',
          popularity: null,
          followers: null,
          state: SixRoomState.unknown,
          variants: const [],
        ),
      );
    }
    return List.unmodifiable(rooms);
  }

  static String parseRoomUserIdHtml(String source, String expectedRoomId) {
    final roomId = SixRoomLink.parseRoomId(expectedRoomId);
    if (roomId == null) throw const SixRoomException(SixRoomFailure.identity);
    final document = html_parser.parse(source);
    final canonical = document.querySelector('link[rel="canonical"]')?.attributes['href'] ?? '';
    if (SixRoomLink.parseRoomId(canonical) != roomId) {
      if (document.querySelector('.remind') != null || source.length < 4096) {
        throw const SixRoomException(SixRoomFailure.missing);
      }
      throw const SixRoomException(SixRoomFailure.identity);
    }
    final expression = RegExp(r'''\brid\s*:\s*['"]([1-9]\d{1,12})['"]\s*,\s*roomid\s*:\s*['"]([1-9]\d{1,11})['"]''');
    for (final match in expression.allMatches(source)) {
      if (match.group(2) == roomId) return match.group(1)!;
    }
    throw const SixRoomException(SixRoomFailure.schema);
  }

  static SixRoomRoom parseRoomJson(
    String source, {
    required String expectedRoomId,
    required String expectedUserId,
    bool includeMedia = true,
  }) {
    final roomId = SixRoomLink.parseRoomId(expectedRoomId);
    if (roomId == null || !_validUserId(expectedUserId)) {
      throw const SixRoomException(SixRoomFailure.identity);
    }
    final root = _decode(source);
    if (_string(root['flag']) != '001') throw const SixRoomException(SixRoomFailure.access);
    final content = _map(root['content']);
    final roomInfo = _map(content?['roominfo']);
    final liveInfo = _map(content?['liveinfo']);
    final params = _map(content?['roomParamInfo']);
    if (content == null || roomInfo == null || liveInfo == null || params == null) {
      throw const SixRoomException(SixRoomFailure.schema);
    }
    final actualRoomId = _string(roomInfo['rid']);
    final actualUserId = _string(roomInfo['id'] ?? params['uid']);
    if (actualRoomId != roomId || actualUserId != expectedUserId) {
      throw const SixRoomException(SixRoomFailure.identity);
    }
    final liveId = _string(liveInfo['id']);
    final flvTitle = _string(liveInfo['flvtitle']);
    final privateRoom = _truthy(content['isPriveRoom']);
    final blackScreen = _text(_map(content['blackScreenInfo'])?['msg']);
    final state = privateRoom || blackScreen.isNotEmpty
        ? SixRoomState.restricted
        : liveId.isNotEmpty && flvTitle.isNotEmpty
        ? SixRoomState.live
        : SixRoomState.offline;
    final nick = _text(roomInfo['alias'], fallback: 'Six Rooms');
    final title = _firstText([liveInfo['title'], roomInfo['userMood'], nick], fallback: 'Six Rooms');
    final variants = <SixRoomVariant>[];
    if (includeMedia && state == SixRoomState.live) {
      final media = mediaUri(userId: actualUserId, liveId: liveId, flvTitle: flvTitle);
      if (media != null) {
        final metadata = _streamMetadata(liveInfo, flvTitle);
        variants.add(
          SixRoomVariant(
            id: 'flv:source',
            protocol: 'flv',
            resolution: _text(metadata?['resolution']),
            bitrate: _integer(metadata?['videoBitrate'] ?? metadata?['bitrate']),
            urls: [media],
          ),
        );
      }
    }
    return SixRoomRoom(
      roomId: roomId,
      userId: actualUserId,
      liveId: liveId,
      nick: nick,
      title: title,
      avatar: _firstImage([roomInfo['headPicUrl'], roomInfo['picuser']]),
      cover: _firstImage([liveInfo['spredPic'], liveInfo['pospic'], liveInfo['largepic'], liveInfo['pic']]),
      category: _firstText([roomInfo['anchor_area'], roomInfo['rtypename']]),
      popularity: null,
      followers: _integer(params['fans_num']),
      state: state,
      variants: variants,
    );
  }

  static Uri? mediaUri({required String userId, required String liveId, required String flvTitle}) {
    if (!_validUserId(userId) || !_validUserId(liveId)) return null;
    if (!RegExp('^v${RegExp.escape(userId)}-${RegExp.escape(liveId)}(?:-many)?\$').hasMatch(flvTitle)) return null;
    final uri = Uri.tryParse('$mediaOrigin/httpflv/$flvTitle.flv');
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'wlive.6rooms.com' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        uri.path != '/httpflv/$flvTitle.flv') {
      return null;
    }
    return uri;
  }

  static Map<String, dynamic>? _streamMetadata(Map<String, dynamic> liveInfo, String flvTitle) {
    final content = _map(liveInfo['content']);
    if (content == null) return null;
    for (final value in content.values) {
      final lane = _map(value);
      final streamInfo = _map(lane?['streamInfo']);
      final exact = _map(streamInfo?[flvTitle]);
      if (exact != null) return exact;
    }
    return null;
  }

  static Map<String, dynamic> _decodeEmbeddedRoot(String source) {
    const marker = 'window.__SMARTY_ALL_VARIABLES__ = ';
    final markerAt = source.indexOf(marker);
    if (markerAt < 0) throw const SixRoomException(SixRoomFailure.schema);
    final start = source.indexOf('{', markerAt + marker.length);
    if (start < 0) throw const SixRoomException(SixRoomFailure.schema);
    var depth = 0;
    var quoted = false;
    var escaped = false;
    for (var index = start; index < source.length; index++) {
      final code = source.codeUnitAt(index);
      if (quoted) {
        if (escaped) {
          escaped = false;
        } else if (code == 0x5c) {
          escaped = true;
        } else if (code == 0x22) {
          quoted = false;
        }
        continue;
      }
      if (code == 0x22) {
        quoted = true;
      } else if (code == 0x7b) {
        depth++;
      } else if (code == 0x7d) {
        depth--;
        if (depth == 0) return _decode(source.substring(start, index + 1));
      }
    }
    throw const SixRoomException(SixRoomFailure.schema);
  }

  static Map<String, dynamic> _decode(String source) {
    try {
      final value = jsonDecode(source);
      final map = _map(value);
      if (map == null) throw const SixRoomException(SixRoomFailure.schema);
      return map;
    } on FormatException {
      throw const SixRoomException(SixRoomFailure.schema);
    }
  }

  static Map<String, dynamic>? _map(Object? value) {
    if (value is! Map) return null;
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  static String _string(Object? value) => value?.toString().trim() ?? '';

  static String _text(Object? value, {String fallback = ''}) {
    final text = _string(value).replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.isEmpty ? fallback : text;
  }

  static String _firstText(Iterable<Object?> values, {String fallback = ''}) {
    for (final value in values) {
      final text = _text(value);
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  static int? _integer(Object? value) {
    if (value is int) return value >= 0 ? value : null;
    if (value is num) return value >= 0 ? value.toInt() : null;
    final parsed = int.tryParse(_string(value).replaceAll(',', ''));
    return parsed != null && parsed >= 0 ? parsed : null;
  }

  static bool _truthy(Object? value) => value == true || value == 1 || _string(value) == '1';

  static bool _validUserId(String? value) => value != null && RegExp(r'^[1-9]\d{1,12}$').hasMatch(value.trim());

  static String _image(Object? value) {
    var raw = _string(value);
    if (raw.startsWith('//')) raw = 'https:$raw';
    if (raw.startsWith('http://')) raw = 'https://${raw.substring(7)}';
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty || uri.hasPort || uri.fragment.isNotEmpty) {
      return '';
    }
    final host = uri.host.toLowerCase();
    if (host != '6.cn' &&
        !host.endsWith('.6.cn') &&
        host != '6rooms.com' &&
        !host.endsWith('.6rooms.com') &&
        host != 'xiu123.cn' &&
        !host.endsWith('.xiu123.cn')) {
      return '';
    }
    return uri.toString();
  }

  static String _firstImage(Iterable<Object?> values) {
    for (final value in values) {
      final image = _image(value);
      if (image.isNotEmpty) return image;
    }
    return '';
  }

  static Never _throwStatus(int status) {
    if (status >= 200 && status < 300) throw StateError('status accepted before error mapping');
    if (status == 404 || status == 410) throw const SixRoomException(SixRoomFailure.missing);
    if (status == 429) throw const SixRoomException(SixRoomFailure.rateLimited);
    if (status == 401 || status == 403 || (status >= 300 && status < 400)) {
      throw const SixRoomException(SixRoomFailure.access);
    }
    if (status >= 500) throw const SixRoomException(SixRoomFailure.service);
    throw const SixRoomException(SixRoomFailure.transport);
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
