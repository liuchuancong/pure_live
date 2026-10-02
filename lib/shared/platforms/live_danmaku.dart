import 'package:meta/meta.dart';
import 'package:pure_live/core/models/live_message.dart';

abstract class LiveDanmaku {
  Function(LiveMessage msg)? onMessage;

  /// Reports a transient transport interruption while the engine still owns
  /// the room and is scheduling recovery.
  Function(String msg)? onReconnect;

  /// Reports a terminal transport failure after automatic recovery ends.
  Function(String msg)? onClose;
  Function()? onReady;

  int heartbeatTime = 0;

  bool _connected = false;

  bool get isConnected => _connected;

  @protected
  void markConnected() {
    _connected = true;
  }

  @protected
  void markDisconnected() {
    _connected = false;
  }

  void heartbeat() {}

  Future start(dynamic args) {
    return Future.value();
  }

  Future stop() {
    markDisconnected();
    return Future.value();
  }
}
