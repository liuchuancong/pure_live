import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pure_live/common/models/live_area.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/common/request_scope.dart';
import 'package:pure_live/model/live_play_quality.dart';

enum MissevanFailure { transport, access, rateLimited, service, notFound, schema, cancelled, qualityUnavailable }

class MissevanException implements Exception {
  const MissevanException(this.kind);
  final MissevanFailure kind;
  @override
  String toString() => 'Missevan ${kind.name}';
}

typedef MissevanRequest = Future<({int status, String body})> Function(Uri uri, CancelToken? cancel);

/// Anonymous public website contracts. No login, push URL, account mutation,
/// shared page cursor or downloader dependency. Native acceptance is recorded
/// independently from API and application integration evidence.
class MissevanApi {
  MissevanApi({MissevanRequest? request}) : _request = request ?? _defaultRequest;
  static const origin = 'https://fm.missevan.com';
  static const responseLimit = 1024 * 1024;
  static const serverPageSize = 20;
  static const playHeaders = <String, String>{'Referer': '$origin/', 'Origin': origin, 'User-Agent': 'Mozilla/5.0'};
  final MissevanRequest _request;

  static Future<({int status, String body})> _defaultRequest(Uri uri, CancelToken? cancel) =>
      withRequestCancellation(cancel, (transport) async {
        final response = await HttpClient.instance.dio.get<ResponseBody>(
          uri.toString(),
          options: Options(
            responseType: ResponseType.stream,
            headers: playHeaders,
            followRedirects: false,
            validateStatus: (_) => true,
          ),
          cancelToken: transport,
        );
        final body = response.data;
        if (body == null) throw const MissevanException(MissevanFailure.schema);
        if (response.statusCode != 200) {
          await body.stream.listen((_) {}).cancel();
          return (status: response.statusCode ?? 0, body: '');
        }
        return (status: 200, body: await readBody(body.stream));
      });

  /// Both a byte ceiling and a total body deadline; a slow trickle of chunks
  /// cannot restart the timeout indefinitely. Always relinquishes the stream.
  static Future<String> readBody(Stream<List<int>> stream, {Duration timeout = const Duration(seconds: 20)}) async {
    final iterator = StreamIterator(stream);
    final bytes = BytesBuilder(copy: false);
    final watch = Stopwatch()..start();
    try {
      while (true) {
        final remaining = timeout - watch.elapsed;
        if (remaining <= Duration.zero) throw TimeoutException('Missevan response deadline');
        if (!await iterator.moveNext().timeout(remaining)) break;
        final chunk = iterator.current;
        if (bytes.length + chunk.length > responseLimit) throw const MissevanException(MissevanFailure.schema);
        bytes.add(chunk);
      }
      return utf8.decode(bytes.takeBytes());
    } on FormatException {
      throw const MissevanException(MissevanFailure.schema);
    } finally {
      watch.stop();
      await iterator.cancel();
    }
  }

  Future<Map<String, dynamic>> _get(String path, {Map<String, String>? query, CancelToken? cancel}) async {
    if (cancel?.isCancelled == true) throw const MissevanException(MissevanFailure.cancelled);
    late final ({int status, String body}) response;
    try {
      response = await _request(Uri.parse('$origin/api/v2/$path').replace(queryParameters: query), cancel);
    } catch (error) {
      if (cancel?.isCancelled == true) throw const MissevanException(MissevanFailure.cancelled);
      if (error is MissevanException) rethrow;
      throw const MissevanException(MissevanFailure.transport);
    }
    if (cancel?.isCancelled == true) throw const MissevanException(MissevanFailure.cancelled);
    final failure = switch (response.status) {
      200 => null,
      401 || 403 => MissevanFailure.access,
      404 => MissevanFailure.notFound,
      429 => MissevanFailure.rateLimited,
      >= 500 => MissevanFailure.service,
      _ => MissevanFailure.transport,
    };
    if (failure != null) throw MissevanException(failure);
    if (response.body.length > responseLimit || utf8.encode(response.body).length > responseLimit) {
      throw const MissevanException(MissevanFailure.schema);
    }
    late final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw const MissevanException(MissevanFailure.schema);
    }
    final data = _object(decoded);
    final code = _integer(data['code']);
    if (code == null) throw const MissevanException(MissevanFailure.schema);
    // Only this explicit code was observed for a nonexistent room (HTTP 404).
    // Unknown API failures are not proof that a broadcast has ended.
    if (code == 500030004) throw const MissevanException(MissevanFailure.notFound);
    if (code != 0) throw const MissevanException(MissevanFailure.service);
    return _object(data['info']);
  }

  static Map<String, dynamic> _object(Object? raw) {
    if (raw is! Map || raw.keys.any((key) => key is! String)) throw const MissevanException(MissevanFailure.schema);
    return Map<String, dynamic>.from(raw);
  }

  static String _text(Object? raw) => raw is String ? raw.trim() : '';
  static int? _integer(Object? raw) => raw is int ? raw : (raw is String ? int.tryParse(raw) : null);
  static String roomId(String input) {
    final id = input.trim();
    if (!RegExp(r'^[1-9][0-9]{0,17}$').hasMatch(id)) throw const MissevanException(MissevanFailure.schema);
    return id;
  }

  static String? roomFromUri(Uri uri) {
    if (!{'http', 'https'}.contains(uri.scheme) ||
        uri.host != 'fm.missevan.com' ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80))) {
      return null;
    }
    try {
      final parts = uri.pathSegments.toList();
      if (parts.isNotEmpty && parts.last.isEmpty) parts.removeLast();
      return parts.length == 2 && parts.first == 'live' ? roomId(parts.last) : null;
    } on FormatException {
      return null;
    } on MissevanException {
      return null;
    }
  }

  static String _picture(Object? raw) {
    var value = _text(raw);
    if (value.startsWith('//')) value = 'https:$value';
    final uri = Uri.tryParse(value);
    return uri != null && {'http', 'https'}.contains(uri.scheme) && uri.host.isNotEmpty && uri.userInfo.isEmpty
        ? value
        : '';
  }

  Future<List<LiveArea>> categories({CancelToken? cancel}) async {
    final info = await _get('meta/data', cancel: cancel);
    final tabs = info['tabs'];
    if (tabs is! List || tabs.isEmpty || tabs.length > 100) throw const MissevanException(MissevanFailure.schema);
    final result = <String, LiveArea>{};
    for (final raw in tabs) {
      final tab = _object(raw);
      final type = _text(tab['type']);
      final id = _integer(tab['${type}_id']);
      final name = _text(tab['name']);
      if (!{'catalog', 'tag'}.contains(type) || id == null || id <= 0 || name.isEmpty) {
        throw const MissevanException(MissevanFailure.schema);
      }
      final key = '$type:$id';
      if (result.containsKey(key)) throw const MissevanException(MissevanFailure.schema);
      result[key] = LiveArea(
        platform: 'missevan',
        areaType: type,
        areaId: '$id',
        areaName: name,
        typeName: '猫耳 FM',
        areaPic: _picture(tab['icon_url']),
      );
    }
    return List.unmodifiable(result.values);
  }

  /// Compatibility wrapper for the staged LiveSite. Page numbers are native
  /// server pages, not offsets computed from the caller's preferred UI size.
  /// Integration must consume [directoryPage] metadata before enabling UI.
  Future<List<LiveRoom>> directory({int page = 1, int pageSize = 30, LiveArea? category, CancelToken? cancel}) async {
    if (pageSize < 1 || pageSize > 100) throw const MissevanException(MissevanFailure.schema);
    return (await directoryPage(page: page, category: category, cancel: cancel)).rooms;
  }

  Future<MissevanDirectoryPage> directoryPage({int page = 1, LiveArea? category, CancelToken? cancel}) async {
    if (page < 1 || page > 10000) throw const MissevanException(MissevanFailure.schema);
    final query = <String, String>{'p': '$page'};
    if (category != null) {
      if (category.platform != 'missevan' || !{'catalog', 'tag'}.contains(category.areaType)) {
        throw const MissevanException(MissevanFailure.schema);
      }
      query['${category.areaType}_id'] = roomId(category.areaId ?? '');
    }
    final info = await _get('chatroom/open/list', query: query, cancel: cancel);
    final pagination = _object(info['pagination']);
    final maxPage = _integer(pagination['maxpage']);
    final count = _integer(pagination['count']);
    final rows = info['Datas'];
    if (_integer(pagination['p']) != page ||
        _integer(pagination['pagesize']) != serverPageSize ||
        maxPage == null ||
        maxPage < 0 ||
        count == null ||
        count < 0 ||
        rows is! List ||
        rows.length > 100) {
      throw const MissevanException(MissevanFailure.schema);
    }
    if (page > maxPage && rows.isNotEmpty) throw const MissevanException(MissevanFailure.schema);
    final result = <String, LiveRoom>{};
    // Observed: pagesize=20 but Datas has 22 entries. The official reducer
    // keeps every entry and advances pagination.p, not a synthetic row offset.
    // Preserve that contract; do not classify/filter recommendations by trace.
    for (final raw in rows) {
      final room = _room(_object(raw));
      if (room.isLiveNow) result.putIfAbsent(room.roomId!, () => room);
    }
    return MissevanDirectoryPage(rooms: List.unmodifiable(result.values), page: page, maxPage: maxPage, count: count);
  }

  /// Official /v2/chatroom/search returns room metadata, including offline
  /// creators. Search never resolves stale playback URLs from these cards.
  Future<List<LiveRoom>> searchPage(
    String keyword, {
    int page = 1,
    int pageSize = serverPageSize,
    CancelToken? cancel,
  }) async {
    final term = keyword.trim();
    if (term.isEmpty ||
        term.length > 100 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(term) ||
        page < 1 ||
        page > 10000 ||
        pageSize < 1 ||
        pageSize > 100) {
      throw const MissevanException(MissevanFailure.schema);
    }
    final info = await _get(
      'chatroom/search',
      query: {'s': term, 'p': '$page', 'page_size': '$pageSize'},
      cancel: cancel,
    );
    final pagination = _object(info['pagination']);
    final rows = info['data'];
    final maxPage = _integer(pagination['maxpage']);
    final count = _integer(pagination['count']);
    if (_integer(pagination['p']) != page ||
        _integer(pagination['pagesize']) != pageSize ||
        maxPage == null ||
        maxPage < 0 ||
        count == null ||
        count < 0 ||
        rows is! List ||
        rows.length > 100 ||
        (page > maxPage && rows.isNotEmpty)) {
      throw const MissevanException(MissevanFailure.schema);
    }
    final rooms = <String, LiveRoom>{};
    for (final raw in rows) {
      final room = _room(_object(raw));
      rooms.putIfAbsent(room.roomId!, () => room);
    }
    return List.unmodifiable(rooms.values);
  }

  static LiveRoom _room(Map<String, dynamic> row) {
    final id = roomId('${row['room_id']}');
    final open = _integer(_object(row['status'])['open']);
    if (open != 0 && open != 1) throw const MissevanException(MissevanFailure.schema);
    final stats = _object(row['statistics']);
    final score = _integer(stats['score']);
    if (score != null && score < 0) throw const MissevanException(MissevanFailure.schema);
    return LiveRoom(
      platform: 'missevan',
      roomId: id,
      userId: roomId('${row['creator_id']}'),
      link: '$origin/live/$id',
      title: _text(row['name']),
      nick: _text(row['creator_username']),
      cover: _picture(row['cover_url']),
      avatar: _picture(row['creator_iconurl']),
      introduction: _text(row['creator_introduction']),
      notice: _text(row['announcement']),
      area: _text(row['catalog_name']),
      watching: score?.toString() ?? '',
      popularity: score?.toString() ?? '',
      audienceMetricType: AudienceMetricType.popularity,
      // Official UI calls score 热度. online=0 and accumulation are not
      // evidence of concurrent viewers; attention_count is followers only.
      status: open == 1,
      liveStatus: open == 1 ? LiveStatus.live : LiveStatus.offline,
    );
  }

  Future<LiveRoom> detail(String input, {bool includeMedia = true, CancelToken? cancel}) async {
    final id = roomId(input);
    final info = await _get('live/$id', cancel: cancel);
    final row = _object(info['room']);
    final room = _room(row);
    if (room.roomId != id) throw const MissevanException(MissevanFailure.schema);
    if (info['creator'] != null) {
      final creator = _object(info['creator']);
      if (roomId('${creator['user_id']}') != room.userId) throw const MissevanException(MissevanFailure.schema);
      room.avatar = _picture(creator['iconurl']);
      room.introduction = _text(creator['introduction']);
    }
    final followers = _integer(_object(row['statistics'])['attention_count']);
    if (followers != null && followers >= 0) room.followers = '$followers';
    if (!room.isLiveNow || !includeMedia) {
      room.data = const <LivePlayQuality>[];
      return room; // Search metadata and offline rooms never inspect stale channel URLs.
    }
    final channel = _object(row['channel']);
    final qualities = <LivePlayQuality>[];
    for (final kind in ['hls', 'flv']) {
      final raw = channel['${kind}_pull_url'];
      if (raw == null || raw == '') continue;
      final url = mediaUrl(_text(raw), kind: kind);
      qualities.add(
        LivePlayQuality(
          id: kind,
          quality: kind.toUpperCase(),
          sort: 2 - qualities.length,
          data: List<String>.unmodifiable([url]),
        ),
      );
    }
    if (qualities.isEmpty) throw const MissevanException(MissevanFailure.schema);
    // Do not infer audio-only from the platform: sampled broadcasts contain
    // AAC plus 16x16 H.264. Let actual media track evidence drive the player.
    room.data = List<LivePlayQuality>.unmodifiable(qualities);
    return room;
  }

  static String mediaUrl(String input, {required String kind}) {
    try {
      final uri = Uri.parse(input);
      if (!{'hls', 'flv'}.contains(kind) ||
          !{'http', 'https'}.contains(uri.scheme) ||
          uri.userInfo.isNotEmpty ||
          uri.hasFragment ||
          (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80)) ||
          !uri.host.endsWith('.bilivideo.com') ||
          !uri.path.endsWith(kind == 'hls' ? '.m3u8' : '.flv')) {
        throw const MissevanException(MissevanFailure.schema);
      }
      final expires = uri.queryParametersAll['expires'];
      if (expires != null && (expires.length != 1 || !RegExp(r'^[0-9]{10}$').hasMatch(expires.single))) {
        throw const MissevanException(MissevanFailure.schema);
      }
      // Matches the official client's HTTPS normalization; both sampled CDN
      // endpoints were independently checked over HTTPS. Preserve signed query.
      return uri.replace(scheme: 'https', port: 443).toString();
    } on FormatException {
      throw const MissevanException(MissevanFailure.schema);
    }
  }
}

/// Native pagination evidence remains valid even when promotion entries make
/// the actual row count larger than nominal pagesize or filtering shrinks it.
class MissevanDirectoryPage {
  const MissevanDirectoryPage({required this.rooms, required this.page, required this.maxPage, required this.count});
  final List<LiveRoom> rooms;
  final int page;
  final int maxPage;
  final int count;
  bool get hasMore => page < maxPage;
}
