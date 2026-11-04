import 'package:flutter/foundation.dart' show BindingBase, kDebugMode;
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How many of the room's messages the viewer's own shield hid: a blocked
/// name, a blocked word (its pattern included), 「屏蔽只有表情的弹幕」 and
/// 「屏蔽超长弹幕」 — the room's 「本场已屏蔽 N 条」.
///
/// Counted, never stored: a new room starts at zero, because the number answers
/// a question about this visit and not about the rule set.
///
/// A message the pipeline dropped as a duplicate, a collapsed repeat or a close
/// match is not in it. Those are the room's own traffic; the four rules above
/// are things the viewer asked never to see, and mixing the two would make the
/// line measure how busy the room was rather than whether the shield works.
final class RoomShieldCountController extends Notifier<int> {
  int _awaiting = 0;
  bool _scheduled = false;

  @override
  int build() => 0;

  /// One more message the shield hid.
  ///
  /// The count moves at once; the listeners hear of it at the end of the frame.
  /// A busy room speaks two hundred lines a second and the panel would rebuild
  /// with every one, to show a figure no eye follows faster than it is refreshed.
  void add() {
    _awaiting++;
    if (_scheduled) return;
    // No binding (a test's plain Dart run) has no frame to wait for.
    if (kDebugMode && BindingBase.debugBindingType() == null) {
      _flush();
      return;
    }
    _scheduled = true;
    SchedulerBinding.instance
      ..scheduleFrameCallback((_) => _flush())
      ..scheduleFrame();
  }

  /// Starts a new room's count.
  void reset() {
    _awaiting = 0;
    _scheduled = false;
    state = 0;
  }

  void _flush() {
    _scheduled = false;
    if (_awaiting == 0) return;
    state = state + _awaiting;
    _awaiting = 0;
  }
}

/// The open room's blocked-message count.
final roomShieldCountProvider = NotifierProvider<RoomShieldCountController, int>(RoomShieldCountController.new);
