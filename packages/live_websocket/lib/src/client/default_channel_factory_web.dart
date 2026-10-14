import 'package:live_websocket/src/client/websocket_config.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Creates a channel over the browser WebSocket API.
///
/// Browsers control handshake headers and protocol pings themselves, so
/// only `protocols` applies here; the client enforces
/// `WebSocketConfig.connectTimeout` on the `ready` future on its own.
WebSocketChannel createDefaultChannel(Uri uri, WebSocketConfig config) {
  return WebSocketChannel.connect(uri, protocols: config.protocols);
}
