/// A cross-platform WebSocket client foundation for the Pure Live
/// workspace.
///
/// Transport only: connection lifecycle, heartbeats and reconnection on
/// top of `web_socket_channel`. Authentication, platform protocols and
/// message semantics live in the business modules above it.
library;

export 'src/client/exact_web_socket.dart' show ExactWebSocket, exactWebSocketConnect;
export 'src/client/websocket_client.dart';
export 'src/client/websocket_config.dart';
export 'src/connection/connection.dart';
export 'src/exceptions/websocket_exception.dart';
export 'src/heartbeat/heartbeat_config.dart';
export 'src/message/message.dart';
export 'src/socket_channel.dart';
