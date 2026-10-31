// What the recorded danmaku takes: the chat always, a gift only when the viewer
// asked, and nothing else — the rule the chat writer and the engine share.

import 'package:flutter_test/flutter_test.dart';
import 'package:live_sites/live_sites.dart' show LiveMessageType;

import 'package:pure_live/modules/live/recorder/engine/recording_chat_writer.dart' show recordableDanmaku;

void main() {
  test('the chat is always kept, a gift only when asked', () {
    expect(recordableDanmaku(LiveMessageType.chat, includeGifts: false), isTrue);
    expect(recordableDanmaku(LiveMessageType.chat, includeGifts: true), isTrue);
    expect(recordableDanmaku(LiveMessageType.gift, includeGifts: false), isFalse);
    expect(recordableDanmaku(LiveMessageType.gift, includeGifts: true), isTrue);
  });

  test('room traffic never enters the chat file', () {
    // Every other kind on the stream describes the room — counts, notices,
    // entries, retractions — and belongs in the player, not in a sidecar read
    // back days later. Asserting over the whole enum makes a new kind a
    // deliberate decision rather than a silent line in someone's file.
    for (final type in LiveMessageType.values) {
      if (type == LiveMessageType.chat || type == LiveMessageType.gift) continue;
      expect(recordableDanmaku(type, includeGifts: true), isFalse, reason: '$type');
    }
  });
}
