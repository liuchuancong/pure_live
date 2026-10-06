import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/core/network/request_scope.dart';
import 'package:pure_live/shared/platforms/niconico/niconico_watch.dart';

typedef NiconicoRequest = Future<({int status, String body})> Function(Uri uri, CancelToken cancel);

/// Public watch-page metadata and session bootstrap; no login or external CLI.
/// No media URL is returned without a separate owned websocket session.
class NiconicoApi {
  NiconicoApi({NiconicoRequest? request, this.deadline = const Duration(seconds: 20)})
    : _request = request ?? _defaultRequest;
  static const origin = 'https://live.nicovideo.jp';
  static const headers = {'Referer': '$origin/', 'User-Agent': 'Mozilla/5.0'};
  final NiconicoRequest _request;
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
    if (body == null) throw const NiconicoException(NiconicoFailure.schema);
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
        if (remaining <= Duration.zero) throw TimeoutException('Niconico response deadline');
        if (!await iterator.moveNext().timeout(remaining)) break;
        if (bytes.length + iterator.current.length > NiconicoWatch.responseLimit) {
          throw const NiconicoException(NiconicoFailure.schema);
        }
        bytes.add(iterator.current);
      }
      return utf8.decode(bytes.takeBytes());
    } on FormatException {
      throw const NiconicoException(NiconicoFailure.schema);
    } finally {
      clock.stop();
      await iterator.cancel();
    }
  }

  Future<NiconicoWatch> room(String roomId, {CancelToken? cancel}) => _load((transport) async {
    final programId = isProgramId(roomId)
        ? roomId
        : await _programOfBroadcaster(roomId, transport);
    NiconicoWatch.validateProgramId(programId);
    final body = await _requestBody(Uri.parse('$origin/watch/$programId'), transport);
    return NiconicoWatch.parsePage(body, programId: programId);
  }, cancel);

  Future<String> resolveBroadcasterProgram(String broadcaster, {CancelToken? cancel}) =>
      _load((transport) => _programOfBroadcaster(broadcaster, transport), cancel);

  Future<String> _programOfBroadcaster(String broadcaster, CancelToken transport) async {
    if (!isBroadcasterRoomId(broadcaster)) {
      throw const NiconicoException(NiconicoFailure.identity);
    }
    final body = await _requestBody(Uri.parse('$origin/watch/$broadcaster'), transport);
    final canonical = RegExp(
      r'''<link[^>]+rel=["']canonical["'][^>]+href=["'][^"']*?/watch/(lv[1-9][0-9]{0,17})["']''',
      caseSensitive: false,
    ).firstMatch(body)?.group(1);
    final programId = canonical ?? RegExp(r'lv[1-9][0-9]{0,17}').firstMatch(body)?.group(0);
    if (programId == null) throw const NiconicoException(NiconicoFailure.identity);
    return NiconicoWatch.validateProgramId(programId);
  }

  static bool isProgramId(String value) => RegExp(r'^lv[1-9][0-9]{0,17}$').hasMatch(value);

  static bool isBroadcasterRoomId(String value) =>
      RegExp(r'^(?:user/[1-9][0-9]{0,17}|ch[1-9][0-9]{0,17})$').hasMatch(value);

  /// Bounded public listing transport. The two observed endpoints use different
  /// envelopes and fixed page sizes; their parsers live in NiconicoDirectory.
  Future<String> listing({required String path, required Map<String, String> query, CancelToken? cancel}) =>
      _load((transport) {
        if (!const {'/front/api/pages/recent/v1/programs', '/front/api/pages/search/v1/programs'}.contains(path)) {
          throw const NiconicoException(NiconicoFailure.schema);
        }
        return _requestBody(Uri.parse('$origin$path').replace(queryParameters: query), transport);
      }, cancel);

  Future<T> _load<T>(Future<T> Function(CancelToken) work, CancelToken? cancel) =>
      withRequestCancellation(cancel, (transport) async {
        if (transport.isCancelled) throw const NiconicoException(NiconicoFailure.cancelled);
        try {
          return await Future.any<T>([
            work(transport),
            transport.whenCancel.then<T>((_) => throw const NiconicoException(NiconicoFailure.cancelled)),
          ]).timeout(deadline);
        } on TimeoutException {
          throw const NiconicoException(NiconicoFailure.transport);
        } catch (error) {
          if (cancel?.isCancelled == true) throw const NiconicoException(NiconicoFailure.cancelled);
          if (error is NiconicoException) rethrow;
          throw const NiconicoException(NiconicoFailure.transport);
        }
      });

  Future<String> _requestBody(Uri uri, CancelToken transport) async {
    final response = await _request(uri, transport);
    if (transport.isCancelled) throw const NiconicoException(NiconicoFailure.cancelled);
    final failure = switch (response.status) {
      200 => null,
      401 || 403 || 406 => NiconicoFailure.access,
      404 => NiconicoFailure.missing,
      429 => NiconicoFailure.rateLimited,
      >= 500 => NiconicoFailure.service,
      _ => NiconicoFailure.transport,
    };
    if (failure != null) throw NiconicoException(failure);
    return response.body;
  }
}
