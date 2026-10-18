import 'dart:async';

import 'package:live_sites/live_sites.dart' show LiveMessage, LiveMessageColor, LiveMessageType, MessageSender;

/// One room's local-message bus — the reference's local interaction delivery
/// queue, trimmed to the one channel this build backs.
///
/// The reference injects a typed line into the room's own danmaku list and the
/// video barrage through a per-room queue that guards against delivering into
/// a room the user already left. The bus is family-keyed by the room identity
/// here, so that guard is structural: what listens is what owns it.
final class RoomLocalMessageBus {
  final StreamController<LiveMessage> _controller = StreamController<LiveMessage>.broadcast();

  /// Local messages as they are sent. The pane and the barrage each listen;
  /// neither polls.
  Stream<LiveMessage> get messages => _controller.stream;

  /// Composes and delivers a local chat line, the reference's
  /// `emitLocalMessage`: marked local, carrying the viewer's own name and
  /// colour, and fanning out to every surface on this room. An empty text
  /// never reaches the stream.
  void sendChat({required String text, required String userName, required int colorArgb}) {
    if (_controller.isClosed) {
      return;
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _controller.add(
      LiveMessage(
        type: LiveMessageType.chat,
        text: trimmed,
        sender: MessageSender(userId: 'local', userName: userName.trim()),
        color: LiveMessageColor((colorArgb >> 16) & 0xFF, (colorArgb >> 8) & 0xFF, colorArgb & 0xFF),
        isLocal: true,
        sentAt: DateTime.now(),
      ),
    );
  }

  /// Closes the bus; late sends are dropped rather than throwing into a UI
  /// callback that is already tearing down.
  Future<void> dispose() => _controller.close();
}
