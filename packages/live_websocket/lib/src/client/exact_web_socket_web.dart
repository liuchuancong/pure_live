import 'dart:async';
import 'dart:math';

import 'package:live_websocket/src/socket_channel.dart';

/// Not available on the web: the browser owns the WebSocket handshake, so a
/// connection that needs the headers spelled exactly cannot be made here.
Future<SocketChannel> exactWebSocketConnect(
  Uri endpoint, {
  required Map<String, String> headers,
  required Iterable<String>? protocols,
  required Duration connectTimeout,
  Duration? pingInterval,
}) async => throw UnsupportedError('The exact WebSocket handshake is not available on the web');

/// The web stub of the exact-handshake client; [connect] always fails with an
/// [UnsupportedError], for the same reason as [exactWebSocketConnect].
final class ExactWebSocket implements SocketChannel {
  /// Always throws [UnsupportedError]: the handshake cannot be spelled from
  /// a browser.
  static Future<ExactWebSocket> connect(
    Uri endpoint, {
    Map<String, String> headers = const {},
    Iterable<String>? protocols,
    Duration connectTimeout = const Duration(seconds: 10),
    Random? random,
  }) async => throw UnsupportedError('The exact WebSocket handshake is not available on the web');

  /// The `Sec-WebSocket-Accept` value for [nonce]; pure arithmetic, so it is
  /// the same on every platform.
  static String acceptKey(String nonce) => throw UnsupportedError('Not available on the web');

  /// The subprotocol the server selected, if any.
  String? get protocol => null;

  @override
  Stream<Object?> get stream => const Stream<Object?>.empty();

  @override
  void add(Object data) => throw StateError('WebSocket is not open');

  @override
  Future<void> close([int? code, String? reason]) => Future<void>.value();

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;
}
