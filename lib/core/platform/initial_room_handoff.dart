import 'package:pure_live/core/models/live_room.dart';

/// 启动参数解析出的首个直播间（Windows 多实例、桌面快捷方式等）。
///
/// App 启动装配写入，首个挂载的首页取走且只取一次。放在 Core 是为了让
/// Features 直接读取这份一次性交接，而不必反向 import App 的 AppInitializer。
abstract final class InitialRoomHandoff {
  static LiveRoom? _pending;

  static void offer(LiveRoom? room) => _pending = room;

  static LiveRoom? take() {
    final room = _pending;
    _pending = null;
    return room;
  }
}
