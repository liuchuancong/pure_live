import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/common/request_scope.dart';

enum WeiboFailure {
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
  unknownState,
}

enum WeiboAccess { public, restricted, disabled }

enum WeiboBroadcastState { live, replay, unknown }

class WeiboException implements Exception {
  const WeiboException(this.kind);
  final WeiboFailure kind;
  @override
  String toString() => 'Weibo ${kind.name}';
}

class WeiboDirectoryCard {
  const WeiboDirectoryCard({required this.liveId, required this.ownerId, required this.nickname, required this.cover});
  final String liveId;
  final int ownerId;
  final String nickname;
  final String? cover;
}

/// Declared metadata, not a guarantee of playable media or a stable owner room.
/// A live ID identifies a broadcast; user UID remains separate.
class WeiboLiveDetail {
  const WeiboLiveDetail({
    required this.liveId,
    required this.ownerId,
    required this.title,
    required this.nickname,
    required this.cover,
    required this.avatar,
    required this.access,
    required this.state,
    required this.reportedStatus,
    required this.watchLimit,
    required this.payLiveStatus,
    required this.width,
    required this.height,
    required this.mediaUrls,
  });
  final String liveId;
  final int ownerId;
  final String title;
  final String nickname;
  final String? cover;
  final String? avatar;
  final WeiboAccess access;
  final WeiboBroadcastState state;
  final int reportedStatus;
  final int watchLimit;
  final int payLiveStatus;
  final int width;
  final int height;
  // HLS-labelled fields can contain FLV. Preserve URLs without fabricating quality.
  // No media URLs escape this metadata layer for restricted, disabled or replay states.
  final List<String> mediaUrls;
}

typedef WeiboRequest = Future<({int status, String body})> Function(
  String method,
  Uri uri,
  Map<String, String>? form,
  CancelToken cancel,
);

class WeiboApi {
  WeiboApi({WeiboRequest? request, this.deadline = const Duration(seconds: 20)})
    : _request = request ?? _defaultRequest;
  static const origin = 'https://weibo.com';
  static const headers = {'Referer': 'https://weibo.com/l/wblive/', 'User-Agent': 'Mozilla/5.0'};
  static const responseLimit = 1024 * 1024;
  final WeiboRequest _request;
  final Duration deadline;
  static Future<({int status, String body})> _defaultRequest(
    String method,
    Uri uri,
    Map<String, String>? form,
    CancelToken cancel,
  ) async {
    final response = await HttpClient.instance.dio.request<ResponseBody>(
      uri.toString(),
      data: form,
      cancelToken: cancel,
      options: Options(
        method: method,
        responseType: ResponseType.stream,
        followRedirects: false,
        headers: headers,
        contentType: form == null ? null : Headers.formUrlEncodedContentType,
        validateStatus: (_) => true,
      ),
    );
    final body = response.data;
    if (body == null) throw const WeiboException(WeiboFailure.schema);
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
        if (remaining <= Duration.zero) throw TimeoutException('Weibo response deadline');
        if (!await iterator.moveNext().timeout(remaining)) break;
        if (bytes.length + iterator.current.length > responseLimit) throw const WeiboException(WeiboFailure.schema);
        bytes.add(iterator.current);
      }
      return utf8.decode(bytes.takeBytes());
    } on FormatException {
      throw const WeiboException(WeiboFailure.schema);
    } finally {
      clock.stop();
      await iterator.cancel();
    }
  }

  Future<T> _scope<T>(CancelToken? caller, Future<T> Function(CancelToken) work) =>
      withRequestCancellation(caller, (transport) async {
        if (transport.isCancelled) throw const WeiboException(WeiboFailure.cancelled);
        try {
          return await Future.any<T>([
            work(transport),
            transport.whenCancel.then<T>((_) => throw const WeiboException(WeiboFailure.cancelled)),
          ]).timeout(deadline);
        } on TimeoutException {
          throw const WeiboException(WeiboFailure.transport);
        } catch (error) {
          if (caller?.isCancelled == true) throw const WeiboException(WeiboFailure.cancelled);
          if (error is WeiboException) rethrow;
          throw const WeiboException(WeiboFailure.transport);
        }
      });

  Future<Map<String, dynamic>> _read(String path, CancelToken cancel, {Map<String, String>? form}) async {
    if (cancel.isCancelled) throw const WeiboException(WeiboFailure.cancelled);
    final response = await _request(form == null ? 'GET' : 'POST', Uri.parse('$origin$path'), form, cancel);
    if (cancel.isCancelled) throw const WeiboException(WeiboFailure.cancelled);
    final failure = switch (response.status) {
      200 => null,
      401 || 403 => WeiboFailure.access,
      404 => WeiboFailure.missing,
      429 => WeiboFailure.rateLimited,
      >= 500 => WeiboFailure.service,
      _ => WeiboFailure.transport,
    };
    if (failure != null) throw WeiboException(failure);
    if (response.body.length > responseLimit || utf8.encode(response.body).length > responseLimit) {
      throw const WeiboException(WeiboFailure.schema);
    }
    try {
      return _object(jsonDecode(response.body));
    } on FormatException {
      throw const WeiboException(WeiboFailure.schema);
    }
  }

  /// Finite anonymous recommendation snapshot, not search or a pagination API.
  Future<List<WeiboDirectoryCard>> directory({CancelToken? cancel}) => _scope(
    cancel,
    (token) async => parseDirectory(await _read('/l/!/2/wblive/pc_recommend/list.json?count=10&uid=', token)),
  );

  Future<WeiboLiveDetail> detail(String liveId, {int? expectedOwnerId, CancelToken? cancel}) {
    validateLiveId(liveId);
    if (expectedOwnerId != null) _owner(expectedOwnerId);
    return _scope(
      cancel,
      (token) async => parseDetail(
        await _read('/l/!/2/wblive/room/show_pc_live.json?live_id=${Uri.encodeQueryComponent(liveId)}', token),
        expectedLiveId: liveId,
        expectedOwnerId: expectedOwnerId,
      ),
    );
  }

  static String validateLiveId(String value) {
    // Both identifiers occur on official indexed watch pages. Neither is a UID.
    if (!RegExp(r'^(?:1022:232132[0-9]{16}|1042152:[0-9a-f]{32})$').hasMatch(value)) {
      throw const WeiboException(WeiboFailure.identity);
    }
    return value;
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map<String, dynamic>) throw const WeiboException(WeiboFailure.schema);
    return value;
  }

  static String _text(Object? value) {
    if (value is! String) throw const WeiboException(WeiboFailure.schema);
    return value;
  }

  static int _number(Object? value) {
    if (value is! int || value < 0) throw const WeiboException(WeiboFailure.schema);
    return value;
  }

  static int _owner(Object? value) {
    if (value is! int || value < 1 || value > 9007199254740991) throw const WeiboException(WeiboFailure.identity);
    return value;
  }

  static int _binary(Object? value) {
    final result = _number(value);
    if (result > 1) throw const WeiboException(WeiboFailure.schema);
    return result;
  }

  static String? _image(Object? value) {
    if (value == null || value == '') return null;
    return _url(value);
  }

  static String _url(Object? value) {
    final text = _text(value);
    final uri = Uri.tryParse(text);
    if (text.trim() != text ||
        RegExp(r'[\\\s]').hasMatch(text) ||
        uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      throw const WeiboException(WeiboFailure.schema);
    }
    return text;
  }

  static Map<String, dynamic> _success(Map<String, dynamic> json) {
    final code = _number(json['code']);
    final error = _number(json['error_code']);
    if (code != 100000 || error != 0) throw const WeiboException(WeiboFailure.api);
    return _object(json['data']);
  }

  static List<WeiboDirectoryCard> parseDirectory(Map<String, dynamic> json) {
    final rows = _success(json)['data'];
    if (rows is! List || rows.length > 500) throw const WeiboException(WeiboFailure.schema);
    final seen = <String>{};
    final result = <WeiboDirectoryCard>[];
    for (final row in rows) {
      final item = _object(row);
      final id = validateLiveId(_text(item['liveid']));
      if (!seen.add(id)) throw const WeiboException(WeiboFailure.identity);
      result.add(
        WeiboDirectoryCard(
          liveId: id,
          ownerId: _owner(item['uid']),
          nickname: _text(item['nickname']),
          cover: _image(item['cover']),
        ),
      );
    }
    return List.unmodifiable(result);
  }

  static WeiboLiveDetail parseDetail(
    Map<String, dynamic> json, {
    required String expectedLiveId,
    int? expectedOwnerId,
  }) {
    validateLiveId(expectedLiveId);
    if (expectedOwnerId != null) _owner(expectedOwnerId);
    final item = _success(json);
    final id = validateLiveId(_text(item['liveId']));
    final user = _object(item['user']);
    final owner = _owner(user['uid']);
    if (id != expectedLiveId || (expectedOwnerId != null && owner != expectedOwnerId)) {
      throw const WeiboException(WeiboFailure.identity);
    }
    final status = _number(item['status']);
    final limit = _number(item['watch_limit']);
    final paid = _binary(item['pay_live_status']);
    final enabled = _binary(item['play_switch']);
    // Normal account/session handling is a separate future contract. Do not expose
    // trial media merely because pay_live_status or a URL is present.
    final access = enabled == 0
        ? WeiboAccess.disabled
        : limit != 0
        ? WeiboAccess.restricted
        : WeiboAccess.public;
    final state = access != WeiboAccess.public
        ? WeiboBroadcastState.unknown
        : switch (status) {
            1 => WeiboBroadcastState.live,
            3 => WeiboBroadcastState.replay,
            _ => WeiboBroadcastState.unknown,
          };
    final urls = <String>{};
    if (state == WeiboBroadcastState.live) {
      for (final key in ['live_origin_flv_url', 'live_origin_hls_url']) {
        final text = _text(item[key]);
        if (text.isNotEmpty) urls.add(_url(text));
      }
    }
    return WeiboLiveDetail(
      liveId: id,
      ownerId: owner,
      title: _text(item['title']),
      nickname: _text(user['screenName']),
      cover: _image(item['cover']),
      avatar: _image(user['profileImageUrl']),
      access: access,
      state: state,
      reportedStatus: status,
      watchLimit: limit,
      payLiveStatus: paid,
      width: _number(item['width']),
      height: _number(item['height']),
      mediaUrls: List.unmodifiable(urls),
    );
  }
}
