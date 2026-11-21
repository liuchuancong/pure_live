import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_danmaku.dart';
import 'package:pure_live/modules/hongguo/widgets/hongguo_danmaku_layer.dart';

/// The comment layer over an episode: the words fly in as playback reaches
/// them and move right-to-left, a pause freezes them where they are, a seek
/// empties the sky and reads the moment it landed on, one row holds one
/// runner until the one ahead has cleared its own length, and a blank never
/// flies. The flights are read off the layer's own painter.
void main() {
  testWidgets('the words fly in as playback reaches them and move', (tester) async {
    final stage = _Stage(tester);
    await stage.mount([(100, '甲'), (1000, '乙'), (2000, '丙')]);

    await stage.advance(200);
    expect(stage.flights, hasLength(1)); // only the word the moment reached

    await stage.advance(900);
    expect(stage.flights, hasLength(2));

    await stage.advance(1000);
    expect(stage.flights, hasLength(3));

    // Every flight enters at the right edge and drifts left.
    final before = stage.xOf(stage.flights.first);
    expect(before, lessThan(400.0));
    expect(before, greaterThan(300.0)); // freshly entered
    await stage.advance(1000);
    final after = stage.xOf(stage.flights.first);
    expect(after, lessThan(before)); // the drift, one frame on
  });

  testWidgets('a pause freezes the sky where it stands', (tester) async {
    final stage = _Stage(tester);
    await stage.mount([(100, '甲'), (1000, '乙')]);
    await stage.advance(200);
    await stage.advance(900);
    final frozenAt = [for (final flight in stage.flights) stage.xOf(flight)];

    stage.playing = false;
    await stage.advance(1000);
    await stage.advance(1000);

    expect(stage.flights, hasLength(2)); // nothing spawned, nothing dropped
    final now = [for (final flight in stage.flights) stage.xOf(flight)];
    expect(now[0], frozenAt[0]); // the picture holds its breath
    expect(now[1], frozenAt[1]);
  });

  testWidgets('a seek empties the sky and reads the moment it landed on', (tester) async {
    final stage = _Stage(tester);
    await stage.mount([(100, '甲'), (1000, '乙'), (20200, '丁'), (21000, '戊')]);
    await stage.advance(200);
    await stage.advance(900);
    expect(stage.flights, hasLength(2));

    stage.position = 20100; // the player jumped far past the two in flight
    await stage.advance(100);

    expect(stage.flights, hasLength(1)); // the jumped-to moment's own word
    expect(stage.xOf(stage.flights.single), greaterThan(390.0)); // freshly entered

    await stage.advance(2000);
    expect(stage.flights, hasLength(2)); // the walk continues from the landing
  });

  testWidgets('one row holds one runner until the one ahead has cleared itself', (tester) async {
    final stage = _Stage(tester, height: 40); // one row fits
    await stage.mount([(100, 'AAAA'), (800, 'BBBB')]);

    await stage.advance(200);
    await stage.advance(700);
    expect(stage.flights, hasLength(1)); // the planner opened the row, the chase closed it

    final stage2 = _Stage(tester, height: 40);
    await stage2.mount([(100, 'AAAA'), (2500, 'BBBB')]);
    await stage2.advance(200);
    await stage2.advance(2400);
    expect(stage2.flights, hasLength(2)); // the runner ahead has cleared its own length
  });

  testWidgets('a blank never flies', (tester) async {
    final stage = _Stage(tester);
    await stage.mount([(100, '   '), (200, '实')]);
    await stage.advance(300);

    expect(stage.flights, hasLength(1)); // the spoken one, not the blank
  });
}

/// One playback: the player's clock the layer samples, and the ways to read
/// what its painter is drawing.
final class _Stage {
  _Stage(this.tester, {this.height = 200});

  final WidgetTester tester;
  final double height;

  int position = 0;
  bool playing = true;

  static const layerKey = ValueKey<String>('danmaku-layer');

  Finder get paint => find.descendant(of: find.byKey(layerKey), matching: find.byType(CustomPaint));

  Future<void> mount(List<(int, String)> items) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              height: height,
              child: HongguoDanmakuLayer(
                key: layerKey,
                items: items,
                positionMs: () => position,
                playing: () => playing,
                settings: HongguoDanmakuSettings.standard,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// A stretch of playback, drawn at a display's frame rate: each frame the
  /// position moves on a little and the layer samples it — a one-shot pump
  /// of a whole second would be a single frame jumping 1000 ms, and the
  /// layer would rightly call that a seek. A paused player's clock stands
  /// still while the frames keep coming.
  Future<void> advance(int ms) async {
    var left = ms;
    while (left > 0) {
      final step = left > 16 ? 16 : left;
      left -= step;
      if (playing) position += step;
      await tester.pump(Duration(milliseconds: step));
    }
  }

  List<dynamic> get flights {
    final custom = tester.widget<CustomPaint>(paint);
    return (custom.painter! as dynamic).flights as List;
  }

  double xOf(dynamic flight) {
    final custom = tester.widget<CustomPaint>(paint);
    return ((custom.painter! as dynamic).xOf(flight) as num).toDouble();
  }
}
