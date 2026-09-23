import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/common/request_scope.dart';

enum HuajiaoFailure {
  transport,
  access,
  rateLimited,
  service,
  notFound,
  schema,
  cancelled,
  restricted,
  mediaUnavailable,
  identity,
}

class HuajiaoException implements Exception {
  const HuajiaoException(this.kind);
  final HuajiaoFailure kind;
  @override
  String toString() => 'Huajiao ${kind.name}';
}

typedef HuajiaoRequest = Future<({int status, String body})> Function(Uri uri, CancelToken? cancel);

class HuajiaoOwner {
  const HuajiaoOwner({required this.userId, required this.name, required this.avatar, required this.liveId});
  final String userId;
  final String name;
  final String avatar;
  // The API's living field is a broadcast ID, not a boolean or viewer count.
  final String? liveId;
  bool get isLive => liveId != null;
}

class HuajiaoFeed {
  const HuajiaoFeed({
    required this.userId,
    required this.liveId,
    required this.sn,
    required this.name,
    required this.title,
    required this.cover,
    required this.avatar,
    required this.heat,
  });
  final String userId;
  final String liveId;
  final String sn;
  final String name;
  final String title;
  final String cover;
  final String avatar;
  // current_heat is retained as heat; watches/praises are not concurrent users.
  final int? heat;
}

class HuajiaoDirectory {
  HuajiaoDirectory({required Iterable<HuajiaoFeed> feeds, required this.nextOffset, required this.hasMore})
    : feeds = List.unmodifiable(feeds);
  final List<HuajiaoFeed> feeds;
  final int nextOffset;
  final bool hasMore;
}

class HuajiaoMedia {
  const HuajiaoMedia({required this.url, required this.format});
  final String url;
  // Format comes from the returned URL, not the name of the main/h264_url key.
  // Codec is deliberately not exposed: captured encode/path hints disagreed
  // with the video packet headers, even when encode=h264 was requested.
  final String format;
}

class HuajiaoBroadcast {
  HuajiaoBroadcast({required this.feed, required Iterable<HuajiaoMedia> media}) : media = List.unmodifiable(media);
  final HuajiaoFeed feed;
  final List<HuajiaoMedia> media;
}

class HuajiaoRoom {
  const HuajiaoRoom(this.owner, this.broadcast);
  final HuajiaoOwner owner;
  final HuajiaoBroadcast? broadcast;
}

/// Anonymous H5 contracts. This is the data layer, not application registration.
/// Every room refresh reacquires the owner's current broadcast and its media;
/// a failure or missing feed is never promoted to an offline owner snapshot.
class HuajiaoApi {
  HuajiaoApi({HuajiaoRequest? request}) : _request = request ?? _defaultRequest;
  static const apiOrigin = 'https://live.huajiao.com';
  static const h5Origin = 'https://h.huajiao.com';
  static const responseLimit = 2 * 1024 * 1024;
  static const headers = {'User-Agent': 'Mozilla/5.0', 'Referer': '$h5Origin/', 'Origin': h5Origin};
  final HuajiaoRequest _request;

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
        if (body == null) throw const HuajiaoException(HuajiaoFailure.schema);
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
        if (remaining <= Duration.zero) throw TimeoutException('Huajiao response deadline');
        if (!await iterator.moveNext().timeout(remaining)) break;
        final chunk = iterator.current;
        if (bytes.length + chunk.length > responseLimit) throw const HuajiaoException(HuajiaoFailure.schema);
        bytes.add(chunk);
      }
      return utf8.decode(bytes.takeBytes());
    } on FormatException {
      throw const HuajiaoException(HuajiaoFailure.schema);
    } finally {
      watch.stop();
      await iterator.cancel();
    }
  }

  Future<Map<String, dynamic>> _get(String origin, String path, Map<String, String> query, CancelToken? cancel) async {
    void checkCancelled() {
      if (cancel?.isCancelled == true) throw const HuajiaoException(HuajiaoFailure.cancelled);
    }

    checkCancelled();
    late final ({int status, String body}) response;
    try {
      response = await _request(Uri.parse('$origin/$path').replace(queryParameters: query), cancel);
    } catch (error) {
      checkCancelled();
      if (error is HuajiaoException) rethrow;
      throw const HuajiaoException(HuajiaoFailure.transport);
    }
    checkCancelled();
    final failure = switch (response.status) {
      200 => null,
      401 || 403 => HuajiaoFailure.access,
      429 => HuajiaoFailure.rateLimited,
      >= 500 => HuajiaoFailure.service,
      _ => HuajiaoFailure.transport,
    };
    if (failure != null) throw HuajiaoException(failure);
    if (response.body.length > responseLimit || utf8.encode(response.body).length > responseLimit) {
      throw const HuajiaoException(HuajiaoFailure.schema);
    }
    try {
      final envelope = _object(jsonDecode(response.body));
      final code = _integer(envelope['errno']);
      if (code == null) throw const HuajiaoException(HuajiaoFailure.schema);
      if (code == 111) throw const HuajiaoException(HuajiaoFailure.access);
      if (code != 0) throw const HuajiaoException(HuajiaoFailure.service);
      return _object(envelope['data']);
    } on FormatException {
      throw const HuajiaoException(HuajiaoFailure.schema);
    }
  }

  Future<HuajiaoOwner> owner(String userId, {CancelToken? cancel}) async {
    final uid = _id(userId);
    final data = await _get(apiOrigin, 'Web/UserInfo/full', {
      'uid': uid,
      'with_living': '1',
      'with_counter': '1',
    }, cancel);
    // The anonymous endpoint returns an empty base list (rather than an
    // error code) for an unknown UID. Keep malformed non-empty shapes strict.
    if (data['base'] is List && (data['base'] as List).isEmpty && _integer(data['living']) == 0) {
      throw const HuajiaoException(HuajiaoFailure.notFound);
    }
    final base = _object(data['base']);
    if (_id(base['uid']) != uid) throw const HuajiaoException(HuajiaoFailure.identity);
    final living = _integer(data['living']);
    if (living == null || living < 0) throw const HuajiaoException(HuajiaoFailure.schema);
    return HuajiaoOwner(
      userId: uid,
      name: _required(base['nickname']),
      avatar: _image(base['avatar_l'] ?? base['avatar']),
      liveId: living == 0 ? null : _id(living),
    );
  }

  Future<HuajiaoDirectory> directory({int offset = 0, int limit = 30, CancelToken? cancel}) async {
    if (offset < 0 || offset > 1000000 || limit < 1 || limit > 30) throw const HuajiaoException(HuajiaoFailure.schema);
    final data = await _get(apiOrigin, 'feed/getLives4H5', {
      'name': 'live5',
      'num': '$limit',
      'offset': '$offset',
    }, cancel);
    final next = _integer(data['offset']);
    final more = data['more'];
    if (more is! bool || next == null || next < 0 || next > 1000000 || (more && next <= offset)) {
      throw const HuajiaoException(HuajiaoFailure.schema);
    }
    final rows = <dynamic>[];
    if (data['sections'] is! List || data['feeds'] is! List) throw const HuajiaoException(HuajiaoFailure.schema);
    for (final section in data['sections'] as List) {
      final entries = _object(section)['feeds'];
      if (entries is! List) throw const HuajiaoException(HuajiaoFailure.schema);
      rows.addAll(entries);
    }
    rows.addAll(data['feeds'] as List);
    final feeds = <String, HuajiaoFeed>{};
    for (final row in rows) {
      final entry = _object(row);
      if (_integer(entry['type']) != 1) continue;
      final feed = _object(entry['feed']);
      // Closed/restricted and unknown modes are not promoted to playable cards.
      if (!_publicLive(feed)) continue;
      final parsed = _parseFeed(entry);
      final previous = feeds[parsed.liveId];
      if (previous != null && previous.userId != parsed.userId) throw const HuajiaoException(HuajiaoFailure.identity);
      feeds.putIfAbsent(parsed.liveId, () => parsed);
    }
    return HuajiaoDirectory(feeds: feeds.values, nextOffset: next, hasMore: more);
  }

  Future<Map<String, dynamic>> _broadcastData(String bid, CancelToken? cancel) => _get(h5Origin, 'api/getFeedInfo', {
    'liveid': bid,
    '_rate': 'xd',
    'stype': 'm3u8',
    'sid': '${DateTime.now().millisecondsSinceEpoch}',
  }, cancel);

  /// Share-link identity resolution is separate from permission to play media.
  /// Never treat a broadcast ID itself as the durable owner ID.
  Future<String> broadcastOwnerId(String liveId, {CancelToken? cancel}) async {
    final bid = _id(liveId);
    final data = await _broadcastData(bid, cancel);
    final entry = _object(data['feed']);
    final feed = _object(entry['feed']);
    if (feed['relateid'] == null || entry['author'] == null) {
      throw const HuajiaoException(HuajiaoFailure.mediaUnavailable);
    }
    if (_id(feed['relateid']) != bid) throw const HuajiaoException(HuajiaoFailure.identity);
    return _id(_object(entry['author'])['uid']);
  }

  Future<HuajiaoBroadcast> broadcast(String liveId, {String? expectedUserId, CancelToken? cancel}) async {
    final bid = _id(liveId);
    final uid = expectedUserId == null ? null : _id(expectedUserId);
    final data = await _broadcastData(bid, cancel);
    final entry = _object(data['feed']);
    final rawFeed = _object(entry['feed']);
    // Observed missing-broadcast response contains only {point: ""}, not {}.
    // Recognize that narrow sentinel without accepting a malformed real feed.
    if (rawFeed.isEmpty ||
        (rawFeed.length == 1 &&
            rawFeed['point'] == '' &&
            entry['type'] == null &&
            entry['author'] == null &&
            data['live'] == null)) {
      throw const HuajiaoException(HuajiaoFailure.mediaUnavailable);
    }
    final feed = _parseFeed(entry);
    if (feed.liveId != bid || (uid != null && feed.userId != uid)) {
      throw const HuajiaoException(HuajiaoFailure.identity);
    }
    if (!_publicLive(rawFeed)) throw const HuajiaoException(HuajiaoFailure.restricted);
    if (data['live'] == null || data['live'] == false) throw const HuajiaoException(HuajiaoFailure.mediaUnavailable);
    final live = _object(data['live']);
    if (_integer(live['errcode']) != 0) throw const HuajiaoException(HuajiaoFailure.mediaUnavailable);
    if (_required(live['sn']) != feed.sn) throw const HuajiaoException(HuajiaoFailure.identity);
    final media = <String, HuajiaoMedia>{};
    for (final key in ['pull_m3u8', 'main', 'h264_url']) {
      final url = _mediaUrl(live[key]);
      if (url == null) continue;
      final path = Uri.parse(url).path.toLowerCase();
      final format = path.endsWith('.m3u8')
          ? 'hls'
          : path.endsWith('.flv')
          ? 'flv'
          : 'unknown';
      media.putIfAbsent(url, () => HuajiaoMedia(url: url, format: format));
    }
    if (media.isEmpty) throw const HuajiaoException(HuajiaoFailure.mediaUnavailable);
    return HuajiaoBroadcast(feed: feed, media: media.values);
  }

  Future<HuajiaoRoom> room(String userId, {CancelToken? cancel}) async {
    final info = await owner(userId, cancel: cancel);
    if (!info.isLive) return HuajiaoRoom(info, null);
    final current = await broadcast(info.liveId!, expectedUserId: info.userId, cancel: cancel);
    return HuajiaoRoom(info, current);
  }

  static HuajiaoFeed _parseFeed(Map<String, dynamic> entry) {
    if (_integer(entry['type']) != 1) throw const HuajiaoException(HuajiaoFailure.schema);
    final feed = _object(entry['feed']);
    final author = _object(entry['author']);
    final heat = _integer(feed['current_heat']);
    final name = _required(author['nickname']);
    final title = feed['title'];
    if (title is! String) throw const HuajiaoException(HuajiaoFailure.schema);
    return HuajiaoFeed(
      userId: _id(author['uid']),
      liveId: _id(feed['relateid']),
      sn: _required(feed['sn']),
      name: name,
      title: title.trim().isEmpty ? name : title.trim(),
      cover: _image(feed['image']),
      avatar: _image(author['avatar_l'] ?? author['avatar']),
      heat: heat != null && heat >= 0 ? heat : null,
    );
  }

  static bool _publicLive(Map<String, dynamic> feed) =>
      _integer(feed['origin_status']) == 1 &&
      feed['is_privacy'] == 'N' &&
      _integer(feed['special_room']) == 0 &&
      // point is location data (empty text or latitude/longitude), not access.
      feed['mode'] == 'video';

  static Map<String, dynamic> _object(dynamic value) {
    if (value is! Map<String, dynamic>) throw const HuajiaoException(HuajiaoFailure.schema);
    return value;
  }

  static int? _integer(dynamic value) => value is int
      ? value
      : value is String && RegExp(r'^\d{1,16}$').hasMatch(value)
      ? int.tryParse(value)
      : null;
  static String _id(dynamic value) {
    final text = value is String
        ? value.trim()
        : value is int
        ? '$value'
        : '';
    if (!RegExp(r'^[1-9]\d{0,15}$').hasMatch(text)) throw const HuajiaoException(HuajiaoFailure.schema);
    return text;
  }

  static String _required(dynamic value) {
    if (value is! String || value.trim().isEmpty) throw const HuajiaoException(HuajiaoFailure.schema);
    return value.trim();
  }

  static String _image(dynamic value) => _url(value) ?? '';
  static String? _url(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !{'http', 'https'}.contains(uri.scheme) || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri.toString();
  }

  static String? _mediaUrl(dynamic value) {
    final url = _url(value);
    if (url == null) return null;
    final host = Uri.parse(url).host.toLowerCase();
    return host == 'huajiao.com' || host.endsWith('.huajiao.com') ? url : null;
  }
}
