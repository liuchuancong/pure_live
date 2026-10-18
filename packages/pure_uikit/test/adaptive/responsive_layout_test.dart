import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_uikit/pure_uikit.dart';

void main() {
  group('resolveAdaptiveColumns', () {
    test('follows the class column ladder', () {
      int columnsFor(double width) => resolveAdaptiveColumns(
        width: width,
        childCount: 100,
        compact: 2,
        medium: 3,
        expanded: 5,
        large: 6,
      );

      expect(columnsFor(390), 2);
      expect(columnsFor(900), 3);
      expect(columnsFor(1280), 5);
      expect(columnsFor(1600), 6);
    });

    test('shrinks to the child count so rows never finish empty', () {
      expect(
        resolveAdaptiveColumns(width: 1600, childCount: 3, compact: 2, medium: 3, expanded: 5, large: 6),
        3,
      );
      expect(
        resolveAdaptiveColumns(width: 390, childCount: 0, compact: 2, medium: 3, expanded: 5, large: 6),
        1,
      );
    });
  });

  testWidgets('ResponsiveContent applies the class gutter', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ResponsiveContent(child: Builder(builder: (context) {
          // The gutter is the first horizontal padding above the probe.
          var gutter = EdgeInsets.zero;
          context.visitAncestorElements((element) {
            final widget = element.widget;
            if (widget is Padding && widget.padding is EdgeInsets) {
              final value = widget.padding as EdgeInsets;
              if (value.left == value.right && value.left > 0) {
                gutter = value;
                return false;
              }
            }
            return true;
          });
          expect(gutter.horizontal, 64);
          return const SizedBox.expand();
        })),
      ),
    );
    await tester.pump();
  });

  testWidgets('AdaptiveContentLayout stacks below the breakpoint', (tester) async {
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdaptiveContentLayout(
            primary: ColoredBox(color: Colors.red, key: Key('primary')),
            secondary: ColoredBox(color: Colors.blue, key: Key('secondary')),
          ),
        ),
      ),
    );
    await tester.pump();

    final primaryTop = tester.getTopLeft(find.byKey(const Key('primary'))).dy;
    final secondaryTop = tester.getTopLeft(find.byKey(const Key('secondary'))).dy;
    expect(secondaryTop, greaterThan(primaryTop));

    tester.view.physicalSize = const Size(1280, 800);
    await tester.pump();

    final primaryLeft = tester.getTopLeft(find.byKey(const Key('primary'))).dx;
    final secondaryLeft = tester.getTopLeft(find.byKey(const Key('secondary'))).dx;
    expect(secondaryLeft, greaterThan(primaryLeft));
  });
}
