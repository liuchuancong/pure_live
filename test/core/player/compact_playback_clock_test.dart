import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/player/presentation/compact_playback_clock.dart';

void main() {
  testWidgets('时长还没报回来时什么都不画，而不是 0:00 / 0:00', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CompactPlaybackClock(position: Duration.zero, duration: Duration.zero),
        ),
      ),
    );

    expect(find.byType(Text), findsNothing);
  });

  testWidgets('小窗里读到的是 位置 / 时长', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CompactPlaybackClock(
            position: Duration(minutes: 3, seconds: 7),
            duration: Duration(minutes: 15, seconds: 40),
          ),
        ),
      ),
    );

    expect(find.text('3:07 / 15:40'), findsOneWidget);
  });

  test('一小时以内 m:ss，超过一小时补上小时位', () {
    expect(formatPlaybackTime(const Duration(seconds: 9)), '0:09');
    expect(formatPlaybackTime(const Duration(minutes: 12, seconds: 5)), '12:05');
    expect(formatPlaybackTime(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
    // 负数只会被读成"还没开始"，不该画成 -0:05。
    expect(formatPlaybackTime(const Duration(seconds: -5)), '0:00');
  });
}
