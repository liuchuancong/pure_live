/// A cross-platform WebSocket client foundation for the Pure Live
/// workspace.
///
/// Transport only: connection lifecycle, heartbeats and reconnection on
/// top of `web_socket_channel`. Authentication, platform protocols and
/// message semantics live in the business modules above it.
library;

export 'src/client/websocket_client.dart';
export 'src/client/websocket_config.dart';
export 'src/connection/connection_state.dart';
export 'src/connection/reconnect_policy.dart';
export 'src/exceptions/websocket_exception.dart';
export 'src/heartbeat/heartbeat_config.dart';
export 'src/message/message_codec.dart';
export 'src/message/websocket_message.dart';
export 'src/socket_channel.dart';
