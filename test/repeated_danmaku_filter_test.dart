import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/modules/live_play/controllers/repeated_danmaku_filter.dart';

void main() {
  LiveMessage message(String text, {String user = 'u1', bool local = false}) => LiveMessage(
    type: LiveMessageType.chat,
    userName: user,
    userId: user,
    message: text,
    color: LiveMessageColor.white,
    isLocal: local,
  );

  test('collapses identical audience text across users only inside the configured window', () {
    final filter = RepeatedDanmakuFilter();
    final start = DateTime(2026, 8, 19, 12);

    expect(filter.accepts(message('  加油  '), enabled: true, window: const Duration(seconds: 5), now: start), isTrue);
    expect(
      filter.accepts(
        message('加油', user: 'u2'),
        enabled: true,
        window: const Duration(seconds: 5),
        now: start.add(const Duration(seconds: 2)),
      ),
      isFalse,
    );
    expect(
      filter.accepts(
        message('加油', user: 'u3'),
        enabled: true,
        window: const Duration(seconds: 5),
        now: start.add(const Duration(seconds: 8)),
      ),
      isTrue,
    );
  });

  test('local messages bypass repeated-text filtering and disabling clears stale entries', () {
    final filter = RepeatedDanmakuFilter();
    final start = DateTime(2026, 8, 19, 12);

    expect(filter.accepts(message('hello'), enabled: true, window: const Duration(seconds: 5), now: start), isTrue);
    expect(
      filter.accepts(
        message('hello', user: 'local', local: true),
        enabled: true,
        window: const Duration(seconds: 5),
        now: start.add(const Duration(seconds: 1)),
      ),
      isTrue,
    );
    expect(
      filter.accepts(
        message('hello', user: 'u2'),
        enabled: false,
        window: const Duration(seconds: 5),
        now: start.add(const Duration(seconds: 2)),
      ),
      isTrue,
    );
    expect(
      filter.accepts(
        message('hello', user: 'u3'),
        enabled: true,
        window: const Duration(seconds: 5),
        now: start.add(const Duration(seconds: 3)),
      ),
      isTrue,
    );
  });
}
