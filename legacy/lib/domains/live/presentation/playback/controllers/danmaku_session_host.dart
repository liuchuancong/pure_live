import 'package:pure_live/get/get.dart';
import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/domains/live/presentation/playback/states/live_play_state.dart';

/// Minimal room surface required by [DanmakuController].
///
/// Separating the transport lifecycle from the full page controller makes the
/// timeout, room-isolation and teardown behaviour independently testable.
abstract interface class DanmakuSessionHost {
  Rx<LivePlayState> get state;

  void addDanmakuMessage(LiveMessage message, {bool immediate = false});

  void updateRuntimeAudience(dynamic value);

  void addSystemMessage(String text);

  void updateDanmakuRoomId(String? roomId);

  void clearRenderedDanmaku();

  void addAddSuperChat(LiveMessage msg) {}

  void removeRetractedMessages(LiveRetraction target) {}

  /// Whether this room's danmaku session has to outlive its route because the
  /// in-app small window is taking the video over.
  ///
  /// GetX deletes the controllers a route registered when that route is
  /// removed, so leaving a room with the small window on deleted the danmaku
  /// controller while the video kept playing; stopping the engine in
  /// [DanmakuController.onClose] then left the small window with a picture and
  /// no danmaku. The host answers "keep it" here, and the floating window stops
  /// the session when it is closed for real.
  bool get keepsDanmakuForFloating;
}
