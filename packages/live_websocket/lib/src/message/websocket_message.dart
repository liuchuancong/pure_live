import 'dart:typed_data';

/// A typed view of an incoming WebSocket frame.
///
/// The client surfaces raw frames; business modules can normalize them with
/// [WebSocketMessage.from] before decoding platform payloads.
sealed class WebSocketMessage {
  const new();

  /// Wraps a raw frame. Text frames become [WebSocketTextMessage], binary
  /// frames [WebSocketBinaryMessage]; anything else is rejected.
  factory from(Object? frame) {
    if (frame is String) {
      return WebSocketTextMessage(frame);
    }
    if (frame is Uint8List) {
      return WebSocketBinaryMessage(frame);
    }
    if (frame is List<int>) {
      return WebSocketBinaryMessage(Uint8List.fromList(frame));
    }
    throw ArgumentError.value(frame, 'frame', 'Unsupported frame type');
  }
}

/// A UTF-8 text frame.
final class WebSocketTextMessage extends WebSocketMessage {
  /// Creates a text frame.
  const new(this.text);

  /// The decoded text.
  final String text;
}

/// A binary frame.
final class WebSocketBinaryMessage extends WebSocketMessage {
  /// Creates a binary frame.
  const new(this.bytes);

  /// The raw bytes.
  final Uint8List bytes;
}
