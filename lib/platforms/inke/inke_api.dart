import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pure_live/common/models/live_area.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/common/request_scope.dart';
import 'package:pure_live/core/interface/live_directory.dart';
import 'package:pure_live/model/live_play_quality.dart';

enum InkeFailure { transport, access, rateLimited, service, notFound, schema, cancelled, mediaUnavailable }

class InkeException implements Exception {
  const InkeException(this.kind, {this.message});
  final InkeFailure kind;
  final String? message;
  @override
  String toString() => message ?? 'Inke ${kind.name}';
}

typedef InkeRequest = Future<({int status, String body})> Function(Uri uri, CancelToken? cancel);

class _NoCurrentBroadcast implements Exception {
  const _NoCurrentBroadcast();
}

/// Anonymous website contracts, verified separately from navigation/native
/// acceptance. The homepage exposes finite showcases, NOT a full live index.
/// Room UID is durable; broadcast ID and media leases must be reacquired.
class InkeApi {
  InkeApi({InkeRequest? request}) : _request = request ?? _defaultRequest;
  static const origin = 'https://www.inke.cn';
  static const apiOrigin = 'https://webapi.busi.inke.cn';
  static const responseLimit = 1024 * 1024;
  static const playHeaders = {'Referer': '$origin/', 'Origin': origin, 'User-Agent': 'Mozilla/5.0'};
  final InkeRequest _request;

  static Future<({int status, String body})> _defaultRequest(Uri uri, CancelToken? cancel) =>
      withRequestCancellation(cancel, (transport) async {
        final response = await HttpClient.instance.dio.get<ResponseBody>(
          uri.toString(),
          cancelToken: transport,
          options: Options(
            responseType: ResponseType.stream,
            headers: playHeaders,
            followRedirects: false,
            validateStatus: (_) => true,
          ),
        );
        final body = response.data;
        if (body == null) throw const InkeException(InkeFailure.schema);
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
        if (remaining <= Duration.zero) throw TimeoutException('Inke response deadline');
        if (!await iterator.moveNext().timeout(remaining)) break;
        final chunk = iterator.current;
        if (bytes.length + chunk.length > responseLimit) throw const InkeException(InkeFailure.schema);
        bytes.add(chunk);
      }
      return utf8.decode(bytes.takeBytes());
    } on FormatException {
      throw const InkeException(InkeFailure.schema);
    } finally {
      watch.stop();
      await iterator.cancel();
    }
  }

  Future<Map<String, dynamic>> _get(String path, {Map<String, String>? query, CancelToken? cancel}) async {
    if (cancel?.isCancelled == true) throw const InkeException(InkeFailure.cancelled);
    late final ({int status, String body}) response;
    try {
      response = await _request(Uri.parse('$apiOrigin/web/$path').replace(queryParameters: query), cancel);
    } catch (error) {
      if (cancel?.isCancelled == true) throw const InkeException(InkeFailure.cancelled);
      if (error is InkeException) rethrow;
      throw const InkeException(InkeFailure.transport);
    }
    if (cancel?.isCancelled == true) throw const InkeException(InkeFailure.cancelled);
    final failure = switch (response.status) {
      200 => null,
      401 || 403 => InkeFailure.access,
      404 => InkeFailure.notFound,
      429 => InkeFailure.rateLimited,
      >= 500 => InkeFailure.service,
      _ => InkeFailure.transport,
    };
    if (failure != null) throw InkeException(failure);
    if (response.body.length > responseLimit || utf8.encode(response.body).length > responseLimit) {
      throw const InkeException(InkeFailure.schema);
    }
    try {
      final envelope = _object(jsonDecode(response.body));
      final code = _integer(envelope['error_code']);
      if (code == null) throw const InkeException(InkeFailure.schema);
      // Only the room endpoint's observed no-current-broadcast code is offline.
      // Unknown service codes, missing streams and HTTP errors are not offline.
      if (code == 1099999920 && path == 'live_share_pc') throw const _NoCurrentBroadcast();
      if (code != 0) throw const InkeException(InkeFailure.service);
      return _object(envelope['data']);
    } on FormatException {
      throw const InkeException(InkeFailure.schema);
    }
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map || value.keys.any((key) => key is! String)) throw const InkeException(InkeFailure.schema);
    return Map<String, dynamic>.from(value);
  }

  static String _text(Object? value) => value is String ? value.trim() : '';
  static int? _integer(Object? value) => value is int
      ? value
      : value is String
      ? int.tryParse(value)
      : null;
  static String _id(Object? value) => roomId(value is int ? '$value' : _text(value));
  static String roomId(String input) {
    final value = input.trim();
    if (!RegExp(r'^[1-9][0-9]{0,17}$').hasMatch(value)) throw const InkeException(InkeFailure.schema);
    return value;
  }

  static String? roomFromUri(Uri uri) {
    if (!{'http', 'https'}.contains(uri.scheme) ||
        !{'inke.cn', 'www.inke.cn', 'inke.com', 'www.inke.com'}.contains(uri.host) ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80)) ||
        uri.path != '/liveroom/index.html') {
      return null;
    }
    try {
      final values = uri.queryParametersAll['uid'];
      return values?.length == 1 ? roomId(values!.single) : null;
    } on FormatException {
      return null;
    } on InkeException {
      return null;
    }
  }

  static String _picture(Object? value) {
    final text = _text(value);
    final uri = Uri.tryParse(text);
    return uri != null && {'http', 'https'}.contains(uri.scheme) && uri.host.isNotEmpty && uri.userInfo.isEmpty
        ? text
        : '';
  }

  /// Keep the exact signed query. No HLS URL synthesis, encryption rewriting or
  /// inference that a different broadcast belonging to the same UID is current.
  static String? plainFlv(Object? value, {required String broadcastId}) {
    final text = _text(value);
    final uri = Uri.tryParse(text);
    if (uri == null ||
        !{'https', 'http'}.contains(uri.scheme) ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80)) ||
        uri.host != 'live-pull-ws.ikstatic.cn' ||
        uri.fragment.isNotEmpty ||
        uri.path != '/live/${roomId(broadcastId)}_t.flv') {
      return null;
    }
    return text;
  }

  static List<Map<String, dynamic>> _rows(Object? value) {
    if (value is! List || value.length > 1000) throw const InkeException(InkeFailure.schema);
    return value.map(_object).toList();
  }

  static LiveRoom _card(Map<String, dynamic> row) {
    final uid = _id(row['uid']);
    final broadcastId = _id(row['live_id']);
    final nick = _text(row['nick']);
    if (nick.isEmpty) throw const InkeException(InkeFailure.schema);
    return LiveRoom(
      platform: 'inke',
      roomId: uid,
      userId: uid,
      nick: nick,
      title: nick,
      avatar: _picture(row['portrait']),
      cover: _picture(row['portrait']),
      link: '$origin/liveroom/index.html?uid=$uid&id=$broadcastId',
      status: true,
      liveStatus: LiveStatus.live,
      isRecord: false,
      watching: '',
      audienceMetricType: AudienceMetricType.unknown,
    );
  }

  Future<List<Map<String, dynamic>>> _channels({CancelToken? cancel}) async {
    final data = await _get('Live_channel_pc', cancel: cancel);
    final groups = _rows(data['list']);
    if (groups.length > 100) throw const InkeException(InkeFailure.schema);
    final keys = <String>{};
    for (final group in groups) {
      final key = _text(group['tab_key']);
      if (!RegExp(r'^[a-zA-Z0-9]{1,64}$').hasMatch(key) || !keys.add(key) || _text(group['channel_name']).isEmpty) {
        throw const InkeException(InkeFailure.schema);
      }
      _rows(group['list']);
    }
    return groups;
  }

  Future<List<LiveArea>> categories({CancelToken? cancel}) async => [
    for (final group in await _channels(cancel: cancel))
      LiveArea(
        platform: 'inke',
        areaType: 'showcase',
        areaId: _text(group['tab_key']),
        areaName: _text(group['channel_name']),
        typeName: '映客官网精选',
      ),
  ];

  /// Filter the two finite public website showcases locally. This is not a
  /// server-side nickname index and cannot discover channels outside them.
  Future<List<LiveRoom>> searchShowcases(String keyword, {int page = 1, int pageSize = 20, CancelToken? cancel}) async {
    final query = keyword.trim().toLowerCase();
    if (page < 1 || page > 10000 || pageSize < 1 || pageSize > 60 || query.length > 100) {
      throw const InkeException(InkeFailure.schema);
    }
    if (query.isEmpty) return const [];
    final top = _rows((await _get('Live_top_pc', cancel: cancel))['list']);
    final groups = await _channels(cancel: cancel);
    final matches = <String, LiveRoom>{};
    for (final row in [...top, for (final group in groups) ..._rows(group['list'])]) {
      final room = _card(row);
      if (room.nick!.toLowerCase().contains(query)) matches.putIfAbsent(room.roomId!, () => room);
    }
    final start = (page - 1) * pageSize;
    if (start >= matches.length) return const [];
    return List.unmodifiable(matches.values.skip(start).take(pageSize));
  }

  Future<LiveDirectoryPage> directoryPage({int page = 1, LiveArea? category, CancelToken? cancel}) async {
    if (page < 1 || (category != null && (category.platform != 'inke' || category.areaType != 'showcase'))) {
      throw const InkeException(InkeFailure.schema);
    }
    if (cancel?.isCancelled == true) throw const InkeException(InkeFailure.cancelled);
    // One finite website showcase; do not invent an offset API from its size.
    if (page > 1) return LiveDirectoryPage(rooms: [], page: page, hasMore: false);
    late final List<Map<String, dynamic>> rows;
    if (category == null) {
      rows = _rows((await _get('Live_top_pc', cancel: cancel))['list']);
    } else {
      final matches = (await _channels(cancel: cancel)).where((group) => group['tab_key'] == category.areaId).toList();
      if (matches.length != 1) throw const InkeException(InkeFailure.notFound);
      rows = _rows(matches.single['list']);
    }
    final rooms = <String, LiveRoom>{};
    for (final row in rows) {
      final card = _card(row);
      rooms.putIfAbsent(card.roomId!, () => card);
    }
    return LiveDirectoryPage(rooms: rooms.values, page: page, hasMore: false);
  }

  Future<List<String>> _showcaseMedia(String uid, String broadcastId, {CancelToken? cancel}) async {
    for (final path in ['Live_top_pc', 'Live_hot_pc', 'Live_channel_pc']) {
      final data = await _get(path, cancel: cancel);
      final groups = switch (path) {
        'Live_hot_pc' => _object(data['list']).values.toList(),
        'Live_channel_pc' => _rows(data['list']).map((group) => group['list']).toList(),
        _ => [data['list']],
      };
      if (groups.length > 100) throw const InkeException(InkeFailure.schema);
      final urls = <String>{};
      for (final group in groups) {
        for (final row in _rows(group)) {
          if (_id(row['uid']) != uid || _id(row['live_id']) != broadcastId) continue;
          final url = plainFlv(row['stream_addr'], broadcastId: broadcastId);
          if (url != null) urls.add(url);
        }
      }
      if (urls.isNotEmpty) return List.unmodifiable(urls);
    }
    // This means the current anonymous website catalogue has no verified media
    // for the broadcast; it does not mean that the broadcaster went offline.
    throw const InkeException(InkeFailure.mediaUnavailable);
  }

  Future<LiveRoom> detail(String input, {bool playback = true, CancelToken? cancel}) async {
    final uid = roomId(input);
    late final Map<String, dynamic> info;
    try {
      info = await _get('live_share_pc', query: {'uid': uid}, cancel: cancel);
    } on _NoCurrentBroadcast {
      return LiveRoom(
        platform: 'inke',
        roomId: uid,
        userId: uid,
        link: '$origin/liveroom/index.html?uid=$uid',
        status: false,
        liveStatus: LiveStatus.offline,
        isRecord: false,
      );
    }
    if (_id(info['live_uid']) != uid || !{1, '1', true}.contains(info['status'])) {
      throw const InkeException(InkeFailure.schema);
    }
    final broadcastId = _id(info['liveid']);
    final owner = _object(info['media_info']);
    if (_id(owner['inke_id']) != uid || _text(owner['nick']).isEmpty) throw const InkeException(InkeFailure.schema);
    final urls = playback ? await _showcaseMedia(uid, broadcastId, cancel: cancel) : <String>[];
    return LiveRoom(
      platform: 'inke',
      roomId: uid,
      userId: uid,
      nick: _text(owner['nick']),
      title: _text(info['live_name']).isEmpty ? _text(owner['nick']) : _text(info['live_name']),
      avatar: _picture(owner['portrait']),
      cover: _picture(info['portrait']),
      link: '$origin/liveroom/index.html?uid=$uid&id=$broadcastId',
      status: true,
      liveStatus: LiveStatus.live,
      isRecord: false,
      watching: '',
      audienceMetricType: AudienceMetricType.unknown,
      data: playback ? [LivePlayQuality(id: 'flv', quality: 'FLV', data: urls)] : null,
    );
  }
}
