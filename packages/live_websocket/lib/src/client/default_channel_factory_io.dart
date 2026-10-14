import 'package:live_websocket/src/client/websocket_config.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Creates a channel over `dart:io` sockets, applying the handshake
/// `headers`, `protocols`, protocol pings and connect timeout from
/// [config].
WebSocketChannel createDefaultChannel(Uri uri, WebSocketConfig config) {
  return IOWebSocketChannel.connect(
    uri,
    protocols: config.protocols?.toList(),
    headers: config.headers,
    pingInterval: config.pingInterval,
    connectTimeout: config.connectTimeout,
  );
}
