import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/common/request_scope.dart';
import 'package:pure_live/core/site/zhanqi/zhanqi_player_layout.dart';

enum ZhanqiFailure {
  transport,
  access,
  missing,
  rateLimited,
  service,
  api,
  schema,
  identity,
  cancelled,
  notLive,
  mediaUnavailable,
}

class ZhanqiException implements Exception {
  const ZhanqiException(this.kind);
  final ZhanqiFailure kind;
  @override
  String toString() => 'Zhanqi ${kind.name}';
}

/// Public numeric code, room identity and owner identity are different fields.
/// The platform's status=4 and nonempty streamUrl are not playable-media proof:
/// two observed status=4 snapshots returned HTTP 404 from their declared HLS.
class ZhanqiRoomSnapshot {
  const ZhanqiRoomSnapshot({
    required this.code,
    required this.roomId,
    required this.ownerId,
    required this.title,
    required this.nickname,
    required this.avatar,
    required this.cover,
    required this.reportedStatus,
    required this.reportedOnline,
    this.declaredStream,
    this.playerLayout,
  });
  final String code;
  final String roomId;
  final String ownerId;
  final String title;
  final String? nickname;
  final String? avatar;
  final String? cover;
  final String reportedStatus;
  // Preserve the raw field's numeric value; concurrency has not been verified.
  final int? reportedOnline;
  final Uri? declaredStream;
  final ZhanqiPlayerLayout? playerLayout;
  bool? get reportedLive => switch (reportedStatus) {
    '4' => true,
    '0' => false,
    _ => null,
  };
}

class ZhanqiDirectoryPage {
  ZhanqiDirectoryPage({
    required this.page,
    required this.pageSize,
    required this.reportedTotal,
    required Iterable<ZhanqiRoomSnapshot> rooms,
  }) : rooms = List.unmodifiable(rooms);
  final int page;
  final int pageSize;
  final int reportedTotal;
  final List<ZhanqiRoomSnapshot> rooms;
  // Official gameRoomList.js uses ceil(cnt / size). An empty page still ends
  // traversal if the snapshot changed; do not loop on a stale total.
  bool get hasMore => rooms.isNotEmpty && page * pageSize < reportedTotal;
}

typedef ZhanqiRequest = Future<({int status, String body})> Function(Uri uri, CancelToken cancel);

/// Bounded metadata API; not registered as a LiveSite until media and consumer
/// contracts are verified. No HTML/topic-path guessing or stream fabrication.
class ZhanqiApi {
  ZhanqiApi({ZhanqiRequest? request, this.deadline = const Duration(seconds: 20)})
    : _request = request ?? _defaultRequest;
  static const origin = 'https://www.zhanqi.tv';
  static const headers = {'Referer': '$origin/', 'User-Agent': 'Mozilla/5.0'};
  static const responseLimit = 1024 * 1024;
  final ZhanqiRequest _request;
  final Duration deadline;

  static Future<({int status, String body})> _defaultRequest(Uri uri, CancelToken cancel) async {
    final response = await HttpClient.instance.dio.get<ResponseBody>(
      uri.toString(),
      cancelToken: cancel,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: false,
        headers: headers,
        validateStatus: (_) => true,
      ),
    );
    final body = response.data;
    if (body == null) throw const ZhanqiException(ZhanqiFailure.schema);
    if (response.statusCode != 200) {
      await body.stream.listen((_) {}).cancel();
      return (status: response.statusCode ?? 0, body: '');
    }
    return (status: 200, body: await readBody(body.stream));
  }

  static Future<String> readBody(Stream<List<int>> source, {Duration timeout = const Duration(seconds: 20)}) async {
    final iterator = StreamIterator(source);
    final bytes = BytesBuilder(copy: false);
    final clock = Stopwatch()..start();
    try {
      while (true) {
        final remaining = timeout - clock.elapsed;
        if (remaining <= Duration.zero) throw TimeoutException('Zhanqi body deadline');
        if (!await iterator.moveNext().timeout(remaining)) break;
        if (bytes.length + iterator.current.length > responseLimit) throw const ZhanqiException(ZhanqiFailure.schema);
        bytes.add(iterator.current);
      }
      return utf8.decode(bytes.takeBytes());
    } on FormatException {
      throw const ZhanqiException(ZhanqiFailure.schema);
    } finally {
      clock.stop();
      await iterator.cancel();
    }
  }

  Future<T> _scope<T>(CancelToken? caller, Future<T> Function(CancelToken) work) =>
      withRequestCancellation(caller, (transport) async {
        if (transport.isCancelled) throw const ZhanqiException(ZhanqiFailure.cancelled);
        try {
          return await Future.any<T>([
            work(transport),
            transport.whenCancel.then<T>((_) => throw const ZhanqiException(ZhanqiFailure.cancelled)),
          ]).timeout(deadline);
        } on TimeoutException {
          throw const ZhanqiException(ZhanqiFailure.transport);
        } catch (error) {
          if (caller?.isCancelled == true) throw const ZhanqiException(ZhanqiFailure.cancelled);
          if (error is ZhanqiException) rethrow;
          throw const ZhanqiException(ZhanqiFailure.transport);
        }
      });

  Future<Map<String, dynamic>> _read(String path, CancelToken cancel) async {
    if (cancel.isCancelled) throw const ZhanqiException(ZhanqiFailure.cancelled);
    final result = await _request(Uri.parse('$origin$path'), cancel);
    if (cancel.isCancelled) throw const ZhanqiException(ZhanqiFailure.cancelled);
    final failure = switch (result.status) {
      200 => null,
      401 || 403 => ZhanqiFailure.access,
      404 => ZhanqiFailure.missing,
      429 => ZhanqiFailure.rateLimited,
      >= 500 => ZhanqiFailure.service,
      _ => ZhanqiFailure.transport,
    };
    if (failure != null) throw ZhanqiException(failure);
    if (result.body.length > responseLimit || utf8.encode(result.body).length > responseLimit) {
      throw const ZhanqiException(ZhanqiFailure.schema);
    }
    try {
      return _object(jsonDecode(result.body));
    } on FormatException {
      throw const ZhanqiException(ZhanqiFailure.schema);
    }
  }

  Future<ZhanqiDirectoryPage> directory({int page = 1, int pageSize = 20, CancelToken? cancel}) =>
      _scope(cancel, (token) async {
        _validatePage(page, pageSize);
        return parseDirectory(
          await _read('/api/static/v2.1/live/list/$pageSize/$page.json', token),
          page: page,
          pageSize: pageSize,
        );
      });

  Future<ZhanqiRoomSnapshot> room({
    required String code,
    String? expectedRoomId,
    String? expectedOwnerId,
    CancelToken? cancel,
  }) => _scope(cancel, (token) async {
    _id(code);
    if (expectedRoomId != null) _id(expectedRoomId);
    if (expectedOwnerId != null) _id(expectedOwnerId);
    return parseRoom(
      await _read('/api/static/v2.1/room/domain/$code.json', token),
      code: code,
      expectedRoomId: expectedRoomId,
      expectedOwnerId: expectedOwnerId,
    );
  });

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map<String, dynamic>) throw const ZhanqiException(ZhanqiFailure.schema);
    return value;
  }

  static Map<String, dynamic> _success(Map<String, dynamic> json) {
    if (json['code'] is! int) throw const ZhanqiException(ZhanqiFailure.schema);
    if (json['code'] != 0) throw const ZhanqiException(ZhanqiFailure.api);
    return _object(json['data']);
  }

  static String _id(Object? value) {
    if (value is! String || !RegExp(r'^[1-9][0-9]{0,19}$').hasMatch(value)) {
      throw const ZhanqiException(ZhanqiFailure.identity);
    }
    return value;
  }

  static String _text(Object? value) {
    if (value is! String) throw const ZhanqiException(ZhanqiFailure.schema);
    return value;
  }

  static String? _optionalText(Object? value) => value == null ? null : _text(value);
  static void _validatePage(int page, int size) {
    if (page < 1 || page > 10000 || size < 1 || size > 100) throw const ZhanqiException(ZhanqiFailure.schema);
  }

  static ZhanqiRoomSnapshot _snapshot(Map<String, dynamic> data, {Uri? stream, ZhanqiPlayerLayout? layout}) {
    final status = _text(data['status']);
    if (!RegExp(r'^[0-9]{1,3}$').hasMatch(status)) throw const ZhanqiException(ZhanqiFailure.schema);
    final online = data['online'];
    int? count;
    if (online != null) {
      if (online is! String || !RegExp(r'^(0|[1-9][0-9]{0,15})$').hasMatch(online)) {
        throw const ZhanqiException(ZhanqiFailure.schema);
      }
      count = int.tryParse(online);
      if (count == null || count > 9007199254740991) throw const ZhanqiException(ZhanqiFailure.schema);
    }
    return ZhanqiRoomSnapshot(
      code: _id(data['code']),
      roomId: _id(data['id']),
      ownerId: _id(data['uid']),
      title: _text(data['title']),
      nickname: _optionalText(data['nickname']),
      avatar: _optionalText(data['avatar']),
      cover: _optionalText(data['spic']),
      reportedStatus: status,
      reportedOnline: count,
      declaredStream: stream,
      playerLayout: layout,
    );
  }

  static ZhanqiDirectoryPage parseDirectory(Map<String, dynamic> json, {required int page, required int pageSize}) {
    _validatePage(page, pageSize);
    final data = _success(json);
    final total = data['cnt'];
    final rows = data['rooms'];
    if (total is! int || total < 0 || total > 100000000 || rows is! List || rows.length > 100) {
      throw const ZhanqiException(ZhanqiFailure.schema);
    }
    final result = <ZhanqiRoomSnapshot>[];
    final codes = <String>{}, roomIds = <String>{};
    for (final raw in rows) {
      final row = _snapshot(_object(raw));
      if (!codes.add(row.code) || !roomIds.add(row.roomId)) throw const ZhanqiException(ZhanqiFailure.identity);
      result.add(row);
    }
    return ZhanqiDirectoryPage(page: page, pageSize: pageSize, reportedTotal: total, rooms: result);
  }

  static ZhanqiRoomSnapshot parseRoom(
    Map<String, dynamic> json, {
    required String code,
    String? expectedRoomId,
    String? expectedOwnerId,
  }) {
    _id(code);
    if (expectedRoomId != null) _id(expectedRoomId);
    if (expectedOwnerId != null) _id(expectedOwnerId);
    final data = _success(json);
    final snapshot = _snapshot(data);
    if (snapshot.code != code ||
        (expectedRoomId != null && snapshot.roomId != expectedRoomId) ||
        (expectedOwnerId != null && snapshot.ownerId != expectedOwnerId)) {
      throw const ZhanqiException(ZhanqiFailure.identity);
    }
    // Offline/unknown snapshots may keep stale or malformed flashvars. Never
    // expose those as current media, and don't erase the metadata observation.
    if (snapshot.reportedLive != true) return snapshot;
    final flash = _object(data['flashvars']);
    if (flash['RoomId'] is! int || flash['RoomId'].toString() != snapshot.roomId) {
      throw const ZhanqiException(ZhanqiFailure.identity);
    }
    if (flash['Status'] is! int || flash['Status'] != 4) throw const ZhanqiException(ZhanqiFailure.schema);
    // The current H5 player uses nonempty h5Cdns before cdns and does not use
    // VideoLevels in that path. Malformed current config must not silently fall
    // back to a stale HLS declaration from the legacy reference adapter.
    final h5 = _optionalText(flash['h5Cdns']);
    final current = h5?.isNotEmpty == true ? h5 : _optionalText(flash['cdns']);
    if (current != null && current.isNotEmpty) {
      try {
        final layout = ZhanqiPlayerLayout.parseEncoded(
          current,
          expectedRoomId: snapshot.roomId,
          expectedVideoId: _idVideo(data['videoId']),
        );
        return _snapshot(data, layout: layout);
      } on ZhanqiLayoutException catch (error) {
        throw ZhanqiException(
          error.kind == ZhanqiLayoutFailure.identity ? ZhanqiFailure.identity : ZhanqiFailure.schema,
        );
      }
    }
    final encoded = _text(flash['VideoLevels']);
    if (encoded.length > 16384) throw const ZhanqiException(ZhanqiFailure.schema);
    try {
      final info = _object(jsonDecode(utf8.decode(base64.decode(encoded))));
      final text = _text(info['streamUrl']);
      if (text.isEmpty) return snapshot;
      final uri = Uri.parse(text);
      if (uri.scheme != 'https' ||
          uri.host != 'alhls-cdn.zhanqi.tv' ||
          uri.userInfo.isNotEmpty ||
          uri.hasFragment ||
          uri.hasPort ||
          !RegExp('^/zqlive/${snapshot.roomId}_[A-Za-z0-9_-]+\\.m3u8\$').hasMatch(uri.path)) {
        throw const ZhanqiException(ZhanqiFailure.schema);
      }
      return _snapshot(data, stream: uri);
    } on FormatException {
      throw const ZhanqiException(ZhanqiFailure.schema);
    }
  }

  static String _idVideo(Object? value) {
    if (value is! String) throw const ZhanqiException(ZhanqiFailure.identity);
    return value;
  }
}
