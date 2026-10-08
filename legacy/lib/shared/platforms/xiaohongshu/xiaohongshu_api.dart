import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/core/network/request_scope.dart';
import 'package:pure_live/shared/platforms/xiaohongshu/xiaohongshu_share.dart';

typedef XiaohongshuRequest = Future<({int status, String body})> Function(Uri uri, CancelToken cancel);

/// Current public SSR share page. No dependency on the old login-only share API,
/// no directory discovery or automatic substitution with recommended rooms.
class XiaohongshuApi {
  XiaohongshuApi({XiaohongshuRequest? request, this.deadline = const Duration(seconds: 20)})
    : _request = request ?? _defaultRequest;
  static const origin = 'https://www.xiaohongshu.com';
  static const headers = {
    'Referer': '$origin/',
    'User-Agent': 'Mozilla/5.0 (Linux; Android 11) AppleWebKit/537.36 Chrome/87.0.4280.141 Mobile Safari/537.36',
  };
  final XiaohongshuRequest _request;
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
    if (body == null) throw const XiaohongshuException(XiaohongshuFailure.schema);
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
        if (remaining <= Duration.zero) throw TimeoutException('Xiaohongshu response deadline');
        if (!await iterator.moveNext().timeout(remaining)) break;
        if (bytes.length + iterator.current.length > XiaohongshuShare.responseLimit) {
          throw const XiaohongshuException(XiaohongshuFailure.schema);
        }
        bytes.add(iterator.current);
      }
      return utf8.decode(bytes.takeBytes());
    } on FormatException {
      throw const XiaohongshuException(XiaohongshuFailure.schema);
    } finally {
      clock.stop();
      await iterator.cancel();
    }
  }

  Future<XiaohongshuShare> room(String roomId, {CancelToken? cancel}) =>
      withRequestCancellation(cancel, (transport) async {
        if (transport.isCancelled) throw const XiaohongshuException(XiaohongshuFailure.cancelled);
        XiaohongshuShare.validateRoomId(roomId);
        try {
          return await Future.any<XiaohongshuShare>([
            _room(roomId, transport),
            transport.whenCancel.then<XiaohongshuShare>(
              (_) => throw const XiaohongshuException(XiaohongshuFailure.cancelled),
            ),
          ]).timeout(deadline);
        } on TimeoutException {
          throw const XiaohongshuException(XiaohongshuFailure.transport);
        } catch (error) {
          if (cancel?.isCancelled == true) throw const XiaohongshuException(XiaohongshuFailure.cancelled);
          if (error is XiaohongshuException) rethrow;
          throw const XiaohongshuException(XiaohongshuFailure.transport);
        }
      });

  Future<XiaohongshuShare> _room(String roomId, CancelToken transport) async {
    final response = await _request(Uri.parse('$origin/livestream/$roomId'), transport);
    if (transport.isCancelled) throw const XiaohongshuException(XiaohongshuFailure.cancelled);
    final failure = switch (response.status) {
      200 => null,
      401 || 403 || 406 => XiaohongshuFailure.access,
      404 => XiaohongshuFailure.missing,
      429 => XiaohongshuFailure.rateLimited,
      >= 500 => XiaohongshuFailure.service,
      _ => XiaohongshuFailure.transport,
    };
    if (failure != null) throw XiaohongshuException(failure);
    return XiaohongshuShare.parsePage(response.body, roomId: roomId);
  }
}
