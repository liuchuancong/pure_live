import 'package:pure_live/core/models/live_room.dart';

abstract final class InitialRoomHandoff {
  static LiveRoom? _pending;

  static void offer(LiveRoom? room) => _pending = room;

  static LiveRoom? take() {
    final room = _pending;
    _pending = null;
    return room;
  }
}
