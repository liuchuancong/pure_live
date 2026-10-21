import 'dart:async';

import 'package:live_sites/live_sites.dart'
    show LiveGift, LiveMessage, LiveMessageColor, LiveMessageType, MessageSender;
import 'package:pure_live/features/room/local/local_catalog.dart';

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
  void sendChat({required String text, required String userName, required int colorArgb, int level = 1}) {
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
        sender: _localSender(userName, level),
        color: _localColor(colorArgb),
        isLocal: true,
        sentAt: DateTime.now(),
      ),
    );
  }

  /// Sends [gift] into the room's own feed and its barrage: a gift line with
  /// the catalogue's name and count, carrying the local sender and the
  /// level's badge — the reference's local gift message, without the shop.
  void sendGift({
    required LocalGift gift,
    required int count,
    required String userName,
    required int colorArgb,
    int level = 1,
  }) {
    if (_controller.isClosed || count <= 0) {
      return;
    }
    _controller.add(
      LiveMessage(
        type: LiveMessageType.gift,
        text: gift.name,
        sender: _localSender(userName, level),
        color: _localColor(colorArgb),
        payload: LiveGift(name: gift.name, count: count),
        isLocal: true,
        sentAt: DateTime.now(),
      ),
    );
  }

  /// The sender every local message carries: the viewer's name and the
  /// level's badge, which the chat line renders where a platform's fan badge
  /// would sit.
  static MessageSender _localSender(String userName, int level) =>
      MessageSender(userId: 'local', userName: userName.trim(), userLevel: '$level', fanBadgeName: 'Lv.$level');

  static LiveMessageColor _localColor(int colorArgb) =>
      LiveMessageColor((colorArgb >> 16) & 0xFF, (colorArgb >> 8) & 0xFF, colorArgb & 0xFF);

  /// Closes the bus; late sends are dropped rather than throwing into a UI
  /// callback that is already tearing down.
  Future<void> dispose() => _controller.close();
}
