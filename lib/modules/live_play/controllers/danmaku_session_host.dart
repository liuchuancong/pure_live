import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/modules/live_play/states/live_play_state.dart';

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
}
