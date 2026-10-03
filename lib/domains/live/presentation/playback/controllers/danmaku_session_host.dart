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

  /// 平台撤回了弹幕（上游 4.x 的 `LiveRetraction`）：把命中的消息从聊天列表撤下去。
  /// 默认什么都不做，宿主按自己的能力实现。
  void removeRetractedMessages(LiveRetraction target) {}
}
