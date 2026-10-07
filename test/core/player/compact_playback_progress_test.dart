import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/player/presentation/compact_playback_progress.dart';

const _sixteenMinutes = Duration(minutes: 16);

Future<void> _pump(
  WidgetTester tester, {
  required Duration position,
  required Duration duration,
  ValueChanged<Duration>? onSeek,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            child: CompactPlaybackProgress(position: position, duration: duration, onSeek: onSeek),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('时长还没报回来时什么都不画，而不是 0:00 / 0:00', (tester) async {
    await _pump(tester, position: Duration.zero, duration: Duration.zero);

    expect(find.byType(Slider), findsNothing);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('两端是时间，中间是能拖的进度条', (tester) async {
    await _pump(tester, position: const Duration(minutes: 3, seconds: 7), duration: _sixteenMinutes, onSeek: (_) {});

    expect(find.text('3:07'), findsOneWidget);
    expect(find.text('16:00'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('不能拖的时候退化成只读进度线', (tester) async {
    await _pump(tester, position: const Duration(minutes: 8), duration: _sixteenMinutes);

    expect(find.byType(Slider), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('松手才 seek，落在拖到的位置', (tester) async {
    final seeks = <Duration>[];
    await _pump(tester, position: Duration.zero, duration: _sixteenMinutes, onSeek: seeks.add);

    await tester.tap(find.byType(Slider), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(seeks, hasLength(1));
    // 点在条的中段：允许轨道两侧的内边距，只要求落在 6–10 分钟这一档。
    expect(seeks.single.inMinutes, greaterThanOrEqualTo(6));
    expect(seeks.single.inMinutes, lessThanOrEqualTo(10));
  });

  test('一小时以内 m:ss，超过一小时补上小时位', () {
    expect(formatPlaybackTime(const Duration(seconds: 9)), '0:09');
    expect(formatPlaybackTime(const Duration(minutes: 12, seconds: 5)), '12:05');
    expect(formatPlaybackTime(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
    // 负数只会被读成"还没开始"，不该画成 -0:05。
    expect(formatPlaybackTime(const Duration(seconds: -5)), '0:00');
  });
}
