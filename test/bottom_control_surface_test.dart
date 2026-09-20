import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/live_play/widgets/layout/bottom_control_surface.dart';
import 'package:pure_live/modules/live_play/widgets/layout/portrait_fullscreen_interaction.dart';

void main() {
  Widget scene({required bool portrait, bool visible = true}) => MaterialApp(
    home: SizedBox(
      width: 368,
      height: 720,
      child: Stack(
        children: [
          BottomControlSurface(
            visible: visible,
            height: portrait ? portraitFullscreenControlsHeight : 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  if (portrait) ...[
                    const SizedBox(height: portraitFullscreenComposerHeight),
                    const SizedBox(height: 2),
                  ],
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  testWidgets('regular to portrait controls never interpolate through an undersized height', (tester) async {
    await tester.pumpWidget(scene(portrait: false));
    await tester.pumpWidget(scene(portrait: true));
    expect(tester.takeException(), isNull);
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(scene(portrait: false));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing layout while the bar is hiding preserves valid child constraints', (tester) async {
    await tester.pumpWidget(scene(portrait: false));
    await tester.pumpWidget(scene(portrait: false, visible: false));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pumpWidget(scene(portrait: true, visible: false));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(scene(portrait: true));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('hiding controls disables hit testing immediately rather than after animation', (tester) async {
    var taps = 0;
    Widget tappable(bool visible) => MaterialApp(
      home: Stack(
        children: [
          BottomControlSurface(
            visible: visible,
            height: 56,
            child: GestureDetector(
              onTap: () => taps++,
              child: const ColoredBox(key: ValueKey('control-target'), color: Colors.red),
            ),
          ),
        ],
      ),
    );
    await tester.pumpWidget(tappable(true));
    final target = tester.getCenter(find.byKey(const ValueKey('control-target')));
    await tester.tapAt(target);
    expect(taps, 1);
    await tester.pumpWidget(tappable(false));
    await tester.tapAt(target);
    expect(taps, 1);
    await tester.pumpAndSettle();
  });
}
