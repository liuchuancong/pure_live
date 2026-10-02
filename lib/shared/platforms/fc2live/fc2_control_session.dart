import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'fc2_api.dart';

final class Fc2SocketLease {
  const Fc2SocketLease({required this.channel, required this.closeTransport});

  final WebSocketChannel channel;
  final FutureOr<void> Function() closeTransport;
}

typedef Fc2SocketConnector = Fc2SocketLease Function(
  Uri endpoint,
  Map<String, dynamic> headers,
  String Function(Uri) findProxy,
);

/// One FC2 media-control seat. The platform keeps HLS grants alive through the
/// WebSocket, so this object must share the native consumer's exact lifetime.
final class Fc2ControlSession {
  Fc2ControlSession._({
    required this.channelId,
    required this.master,
    required this._channel,
    required this._subscription,
    required this._closeTransport,
    required this._health,
  });

  static const int messageLimit = 2 * 1024 * 1024;

  final String channelId;
  final Uri master;
  final WebSocketChannel _channel;
  final StreamSubscription<dynamic> _subscription;
  final FutureOr<void> Function() _closeTransport;
  final _Fc2SessionHealth _health;
  bool _closed = false;
  Future<void>? _closing;

  bool get isClosed => _closed || !_health.active;

  static Future<Fc2ControlSession> open(
    String channelId, {
    Fc2Api? api,
    required String Function(Uri) findProxy,
    Fc2SocketConnector? connect,
    CancelToken? cancel,
  }) async {
    final client = api ?? Fc2Api();
    if (cancel?.isCancelled == true) throw const Fc2Exception(Fc2Failure.cancelled);
    final grant = await client.controlGrant(channelId, cancel: cancel);
    if (cancel?.isCancelled == true) throw const Fc2Exception(Fc2Failure.cancelled);
    final endpoint = grant.webSocket.replace(queryParameters: {'control_token': grant.controlToken});
    final socket = (connect ?? _connect)(endpoint, {
      'Origin': Fc2Api.origin,
      'User-Agent': Fc2Api.userAgent,
      'Cookie': 'l_ortkn=${grant.orz}',
    }, findProxy);
    final ready = Completer<void>();
    final playlist = Completer<Uri>();
    final health = _Fc2SessionHealth();
    var requested = false;
    late final StreamSubscription<dynamic> subscription;

    void fail(Object error) {
      health.active = false;
      final normalized = error is Fc2Exception ? error : const Fc2Exception(Fc2Failure.transport);
      if (!ready.isCompleted) ready.completeError(normalized);
      if (!playlist.isCompleted) playlist.completeError(normalized);
    }

    subscription = socket.channel.stream.listen(
      (message) {
        if (message is! String || message.length > messageLimit) {
          fail(const Fc2Exception(Fc2Failure.schema));
          return;
        }
        try {
          final decoded = jsonDecode(message);
          if (decoded is! Map) throw const Fc2Exception(Fc2Failure.schema);
          final data = decoded.map((key, value) => MapEntry(key.toString(), value));
          final name = data['name'];
          if (name == 'connect_complete') {
            if (!ready.isCompleted) ready.complete();
            if (!requested) {
              requested = true;
              socket.channel.sink.add('{"name":"get_hls_information","arguments":{},"id":1}');
            }
          } else if (name == '_response_' && data['id'] == 1 && !playlist.isCompleted) {
            playlist.complete(parseHlsResponse(data, expectedChannelId: grant.channelId));
          } else if (name == 'control_disconnection') {
            fail(const Fc2Exception(Fc2Failure.transport));
          }
        } on Fc2Exception catch (error) {
          fail(error);
        } on FormatException {
          fail(const Fc2Exception(Fc2Failure.schema));
        }
      },
      onError: fail,
      onDone: () => fail(const Fc2Exception(Fc2Failure.transport)),
      cancelOnError: false,
    );

    try {
      await Future.any<void>([
        socket.channel.ready,
        if (cancel != null) cancel.whenCancel.then<void>((_) => throw const Fc2Exception(Fc2Failure.cancelled)),
      ]).timeout(const Duration(seconds: 20));
      await Future.any<void>([
        ready.future,
        if (cancel != null) cancel.whenCancel.then<void>((_) => throw const Fc2Exception(Fc2Failure.cancelled)),
      ]).timeout(const Duration(seconds: 20));
      final master = await Future.any<Uri>([
        playlist.future,
        if (cancel != null) cancel.whenCancel.then<Uri>((_) => throw const Fc2Exception(Fc2Failure.cancelled)),
      ]).timeout(const Duration(seconds: 20));
      if (cancel?.isCancelled == true) throw const Fc2Exception(Fc2Failure.cancelled);
      return Fc2ControlSession._(
        channelId: grant.channelId,
        master: master,
        channel: socket.channel,
        subscription: subscription,
        closeTransport: socket.closeTransport,
        health: health,
      );
    } on TimeoutException {
      await _dispose(socket.channel, subscription, socket.closeTransport);
      throw const Fc2Exception(Fc2Failure.transport);
    } catch (error) {
      await _dispose(socket.channel, subscription, socket.closeTransport);
      if (cancel?.isCancelled == true) throw const Fc2Exception(Fc2Failure.cancelled);
      if (error is Fc2Exception) rethrow;
      throw const Fc2Exception(Fc2Failure.transport);
    }
  }

  static Fc2SocketLease _connect(Uri endpoint, Map<String, dynamic> headers, String Function(Uri) findProxy) {
    final client = HttpClient()..findProxy = findProxy;
    final channel = IOWebSocketChannel.connect(
      endpoint,
      headers: headers,
      pingInterval: const Duration(seconds: 15),
      connectTimeout: const Duration(seconds: 20),
      customClient: client,
    );
    return Fc2SocketLease(channel: channel, closeTransport: () => client.close(force: true));
  }

  static Uri parseHlsResponse(Map<String, dynamic> response, {required String expectedChannelId}) {
    if (response['name'] != '_response_' || response['id'] != 1) {
      throw const Fc2Exception(Fc2Failure.schema);
    }
    final arguments = _object(response['arguments']);
    if (_integer(arguments['status']) != 0) throw const Fc2Exception(Fc2Failure.access);
    final playlists = _list(arguments['playlists'], max: 32);
    for (final value in playlists) {
      final item = _object(value);
      if (_integer(item['mode']) != 0 || _integer(item['status']) != 0) continue;
      final uri = Uri.tryParse(_string(item['url']));
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.userInfo.isNotEmpty ||
          !_isMediaHost(uri.host) ||
          uri.path != '/a/stream/$expectedChannelId/0/master_playlist' ||
          uri.hasFragment ||
          !_token(uri.queryParameters['c']) ||
          !_token(uri.queryParameters['d']) ||
          !_targets(uri.queryParameters['targets']) ||
          uri.queryParameters.keys.any((key) => !const {'targets', 'c', 'd'}.contains(key))) {
        throw const Fc2Exception(Fc2Failure.schema);
      }
      return uri;
    }
    throw const Fc2Exception(Fc2Failure.schema);
  }

  static bool _isMediaHost(String host) {
    final value = host.toLowerCase();
    return value == 'live.fc2.com' || value.endsWith('.live.fc2.com');
  }

  static bool _token(String? value) => value != null && value.isNotEmpty && value.length <= 1024;

  static bool _targets(String? value) =>
      value != null &&
      value.isNotEmpty &&
      value.length <= 128 &&
      RegExp(r'^\d{1,3}(?:,\d{1,3}){0,15}$').hasMatch(value);

  static int _integer(Object? value) {
    final result = switch (value) {
      int number => number,
      num number when number.isFinite => number.toInt(),
      String text => int.tryParse(text.trim()),
      _ => null,
    };
    if (result == null) throw const Fc2Exception(Fc2Failure.schema);
    return result;
  }

  static String _string(Object? value) {
    if (value is! String || value.isEmpty || value.length > 65536) {
      throw const Fc2Exception(Fc2Failure.schema);
    }
    return value;
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map) throw const Fc2Exception(Fc2Failure.schema);
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static List<Object?> _list(Object? value, {required int max}) {
    if (value is! List || value.length > max) throw const Fc2Exception(Fc2Failure.schema);
    return value;
  }

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    if (_closed) return;
    _closed = true;
    _health.active = false;
    await _dispose(_channel, _subscription, _closeTransport);
  }

  static Future<void> _dispose(
    WebSocketChannel channel,
    StreamSubscription<dynamic> subscription,
    FutureOr<void> Function() closeTransport,
  ) async {
    try {
      await channel.sink.close().timeout(const Duration(seconds: 2));
    } catch (_) {}
    try {
      await subscription.cancel().timeout(const Duration(seconds: 2));
    } catch (_) {}
    try {
      await Future<void>.sync(closeTransport);
    } catch (_) {}
  }
}

final class _Fc2SessionHealth {
  bool active = true;
}
