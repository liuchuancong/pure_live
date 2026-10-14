import 'package:live_websocket/src/message/websocket_message.dart';

/// Converts between raw WebSocket frames and typed messages.
///
/// Business modules implement this to plug their own wire formats into
/// transport-agnostic pipelines; the client itself stays codec-free.
abstract interface class WebSocketMessageCodec {
  /// Decodes a raw incoming frame.
  WebSocketMessage decode(Object? frame);

  /// Encodes a message into a frame the channel can send.
  Object? encode(WebSocketMessage message);
}
