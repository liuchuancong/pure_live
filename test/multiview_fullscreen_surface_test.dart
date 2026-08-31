import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/multiview/widgets/multiview_fullscreen_surface.dart';

void main() {
  testWidgets('fullscreen always exposes a safe-area exit without stealing grid taps', (tester) async {
    var exitCount = 0;
    var gridTapCount = 0;
    EdgeInsets? contentPadding;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(800, 450), padding: EdgeInsets.fromLTRB(30, 20, 40, 10)),
          child: Scaffold(
            body: MultiviewFullscreenSurface(
              exitTooltip: 'Exit fullscreen',
              onExit: () => exitCount++,
              child: Builder(
                builder: (context) {
                  contentPadding = MediaQuery.paddingOf(context);
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => gridTapCount++,
                    child: const SizedBox.expand(key: ValueKey('multiview-grid')),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(MultiviewFullscreenSurface.exitButtonKey), findsOneWidget);
    expect(find.bySemanticsLabel('Exit fullscreen'), findsOneWidget);
    expect(contentPadding, const EdgeInsets.fromLTRB(30, 0, 40, 0));

    final exitRect = tester.getRect(find.byKey(MultiviewFullscreenSurface.exitButtonKey));
    expect(exitRect.left, greaterThanOrEqualTo(42));
    expect(exitRect.top, greaterThanOrEqualTo(32));

    await tester.tap(find.byKey(MultiviewFullscreenSurface.exitButtonKey));
    await tester.pump();
    expect(exitCount, 1);
    expect(gridTapCount, 0);

    await tester.tapAt(const Offset(400, 225));
    await tester.pump();
    expect(gridTapCount, 1);
    expect(exitCount, 1);
  });
}
