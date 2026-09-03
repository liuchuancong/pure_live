import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/modules/live_play/controllers/danmaku_message_gate.dart';

LiveMessage _message({
  String text = 'hello',
  String userId = '1',
  String messageId = '',
  DateTime? sentAt,
}) {
  return LiveMessage(
    type: LiveMessageType.chat,
    userName: 'viewer',
    userId: userId,
    message: text,
    messageId: messageId,
    sentAt: sentAt,
    color: LiveMessageColor.white,
  );
}

void main() {
  group('DanmakuMessageGate', () {
    final now = DateTime(2026, 8, 17, 12);

    test('rejects a replayed stable platform message id', () {
      final gate = DanmakuMessageGate();
      final message = _message(messageId: 'platform:123', sentAt: now);

      expect(gate.accepts(message, now: now), isTrue);
      expect(gate.accepts(message, now: now.add(const Duration(seconds: 20))), isFalse);
    });

    test('keeps genuine repeated text after the short fallback window', () {
      final gate = DanmakuMessageGate();
      final message = _message();

      expect(gate.accepts(message, now: now), isTrue);
      expect(gate.accepts(message, now: now.add(const Duration(seconds: 1))), isFalse);
      expect(gate.accepts(message, now: now.add(const Duration(seconds: 3))), isTrue);
    });

    test('rejects platform backlog older than the live freshness window', () {
      final gate = DanmakuMessageGate();
      expect(
        gate.accepts(_message(sentAt: now.subtract(const Duration(minutes: 2))), now: now),
        isFalse,
      );
    });

    test('bounds retained fingerprints', () {
      final gate = DanmakuMessageGate(maxEntries: 2);
      for (var index = 0; index < 3; index++) {
        expect(gate.accepts(_message(messageId: 'id:$index'), now: now), isTrue);
      }
      expect(gate.accepts(_message(messageId: 'id:0'), now: now), isTrue);
    });
  });
}
