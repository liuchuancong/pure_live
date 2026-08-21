import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';

void main() {
  LiveSuperChatMessage message(DateTime endTime, {String text = 'message'}) {
    return LiveSuperChatMessage(
      backgroundBottomColor: '#FFFFFF',
      backgroundColor: '#FFFFFF',
      endTime: endTime,
      face: '',
      message: text,
      price: 1,
      startTime: endTime.subtract(const Duration(minutes: 1)),
      userName: 'user',
    );
  }

  test('empty super-chat state schedules no periodic wake-up', () {
    final delay = LivePlayController.nextSuperChatExpiryDelay(const <LiveSuperChatMessage>[], DateTime(2026));

    expect(delay, isNull);
  });

  test('super-chat expiry schedules only the earliest pending deadline', () {
    final now = DateTime(2026);
    final delay = LivePlayController.nextSuperChatExpiryDelay([
      message(now.add(const Duration(seconds: 30)), text: 'later'),
      message(now.add(const Duration(seconds: 5)), text: 'earlier'),
    ], now);

    expect(delay, const Duration(seconds: 5));
  });

  test('an expired super-chat is pruned on the next event-loop turn', () {
    final now = DateTime(2026);
    final delay = LivePlayController.nextSuperChatExpiryDelay([
      message(now.subtract(const Duration(seconds: 1))),
    ], now);

    expect(delay, const Duration(milliseconds: 1));
  });
}
