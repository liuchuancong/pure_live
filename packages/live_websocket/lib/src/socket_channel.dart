import 'dart:async';

import 'package:live_websocket/src/client/default_channel_factory.dart';
import 'package:live_websocket/src/client/websocket_client.dart';
import 'package:live_websocket/src/client/websocket_config.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// One opened WebSocket, seen only as the frames it carries and the way it
/// closes — the narrow seam a single-use protocol (a seat that must not
/// reconnect on an expired bootstrap, a control socket good for one grant)
/// drives directly.
///
/// The reconnect-and-retry client ([LiveWebSocketClient]) owns its channel and
/// never hands one of these out; this is the opposite tool: the caller opens a
/// channel, listens to [stream], sends with [add] and closes it, and reads the
/// peer's [closeCode]/[closeReason] after it ends. Keeping it this small is
/// what lets a test drive a socket by hand.
abstract interface class SocketChannel {
  /// Incoming messages: `String` for a text frame, `List<int>` for a binary one.
  Stream<Object?> get stream;

  /// Sends one text or binary message.
  void add(Object data);

  /// Starts the closing handshake; the peer's close code and reason follow.
  Future<void> close([int? code, String? reason]);

  /// The close code the peer sent, once closed; null while open or if it named
  /// none.
  int? get closeCode;

  /// The close reason the peer sent, once closed; null while open or if it named
  /// none.
  String? get closeReason;
}

/// Opens a [SocketChannel] to [endpoint]: the handshake [headers] and
/// [protocols], the opening bounded by [connectTimeout], and — with
/// [pingInterval] — a protocol-level ping that keeps a session alive only while
/// the socket is provably live. [webSocketConnect] is the default; a caller may
/// pass another (a test's own).
typedef SocketConnector = Future<SocketChannel> Function(
  Uri endpoint, {
  required Map<String, String> headers,
  required Iterable<String>? protocols,
  required Duration connectTimeout,
  Duration? pingInterval,
});

/// The default [SocketConnector]: a platform-adaptive `web_socket_channel`
/// (native sockets or the browser's) with the handshake applied, wrapped as a
/// [SocketChannel].
Future<SocketChannel> webSocketConnect(
  Uri endpoint, {
  required Map<String, String> headers,
  required Iterable<String>? protocols,
  required Duration connectTimeout,
  Duration? pingInterval,
}) async {
  final channel = createDefaultChannel(
    endpoint,
    WebSocketConfig(headers: headers, protocols: protocols, connectTimeout: connectTimeout, pingInterval: pingInterval),
  );
  await channel.ready.timeout(connectTimeout);
  return _WebSocketSocketChannel(channel);
}

final class _WebSocketSocketChannel implements SocketChannel {
  new(this._channel);

  final WebSocketChannel _channel;

  @override
  Stream<Object?> get stream => _channel.stream;

  @override
  void add(Object data) => _channel.sink.add(data);

  @override
  Future<void> close([int? code, String? reason]) => _channel.sink.close(code, reason);

  @override
  int? get closeCode => _channel.closeCode;

  @override
  String? get closeReason => _channel.closeReason;
}
