import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/live/room/page/room_bottom_panel.dart';
import 'package:pure_live/modules/live/room/page/room_glass_card.dart';

/// The window the panel is measured in. The test surface is 800 × 600 by
/// default, which is not the shape any phone gives this layout.
Future<void> _show(WidgetTester tester, Size window, RoomBottomPanel panel) async {
  await tester.binding.setSurfaceSize(window);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SizedBox.fromSize(size: window, child: panel)),
    ),
  );
  await tester.pumpAndSettle();
}

/// The sheet's own height, read off the frosted card that is its surface.
double _sheetHeight(WidgetTester tester) => tester.getSize(find.byType(RoomGlassCard)).height;

RoomBottomPanel _panel(RoomPanelStop stop, {ValueChanged<double>? onCover}) => RoomBottomPanel(
  picture: const Placeholder(),
  panel: const Placeholder(),
  preferred: stop,
  onCoverChanged: onCover,
);

void main() {
  testWidgets('the balanced panel opens at the reading height of the window', (tester) async {
    final covered = <double>[];
    await _show(tester, const Size(400, 800), _panel(RoomPanelStop.middle, onCover: covered.add));

    // 44 % of an 800 px window, and the same figure reported to the host so the
    // bars over the picture can stand above it.
    expect(_sheetHeight(tester), 352);
    expect(covered, [352]);
  });

  testWidgets('the immersive panel opens on the fixed floor, not a fraction', (tester) async {
    await _show(tester, const Size(400, 800), _panel(RoomPanelStop.minimum));

    expect(_sheetHeight(tester), 250);
  });

  testWidgets('the highest stop leaves a strip of picture free', (tester) async {
    await _show(tester, const Size(400, 800), _panel(RoomPanelStop.maximum));

    // 68 % of 800, which leaves 256 px of picture above it — more than the 120
    // the rule insists on, so the rule does not bind here.
    expect(_sheetHeight(tester), 544);
  });

  testWidgets('a window too short for both rules keeps its floor', (tester) async {
    await _show(tester, const Size(400, 300), _panel(RoomPanelStop.maximum));

    // 68 % would be 204 and the free picture 96, both under the 250 px floor:
    // the floor wins, because a sheet that cannot show a line of chat is not a
    // sheet. The crossed limits must not throw on the way there.
    expect(_sheetHeight(tester), 250);
  });

  testWidgets('a flick upward carries the panel to the next stop', (tester) async {
    final covered = <double>[];
    await _show(tester, const Size(400, 800), _panel(RoomPanelStop.middle, onCover: covered.add));

    // The throw decides the stop, not the pixel the finger happened to leave at.
    await tester.fling(find.byType(GestureDetector), const Offset(0, -300), 1200);
    await tester.pumpAndSettle();

    expect(covered.last, 544);
  });

  testWidgets('a small drag falls back to the stop it left from', (tester) async {
    await _show(tester, const Size(400, 800), _panel(RoomPanelStop.middle));

    await tester.drag(find.byType(GestureDetector), const Offset(0, -20));
    await tester.pumpAndSettle();

    expect(_sheetHeight(tester), 352);
  });
}
