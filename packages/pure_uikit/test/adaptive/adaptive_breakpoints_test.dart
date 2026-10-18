import 'package:flutter/material.dart';
import 'package:flutter_screenutil_plus/flutter_screenutil_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_uikit/pure_uikit.dart';

void main() {
  group('AdaptiveBreakpoints', () {
    test('maps widths to the four layout classes', () {
      expect(AdaptiveBreakpoints.fromWidth(0), AdaptiveBreakpoint.compact);
      expect(AdaptiveBreakpoints.fromWidth(390), AdaptiveBreakpoint.compact);
      expect(AdaptiveBreakpoints.fromWidth(599.9), AdaptiveBreakpoint.compact);
      expect(AdaptiveBreakpoints.fromWidth(600), AdaptiveBreakpoint.medium);
      expect(AdaptiveBreakpoints.fromWidth(900), AdaptiveBreakpoint.medium);
      expect(AdaptiveBreakpoints.fromWidth(1023.9), AdaptiveBreakpoint.medium);
      expect(AdaptiveBreakpoints.fromWidth(1024), AdaptiveBreakpoint.expanded);
      expect(AdaptiveBreakpoints.fromWidth(1280), AdaptiveBreakpoint.expanded);
      expect(AdaptiveBreakpoints.fromWidth(1439.9), AdaptiveBreakpoint.expanded);
      expect(AdaptiveBreakpoints.fromWidth(1440), AdaptiveBreakpoint.large);
      expect(AdaptiveBreakpoints.fromWidth(2560), AdaptiveBreakpoint.large);
    });

    test('handles non-finite widths safely', () {
      expect(AdaptiveBreakpoints.fromWidth(double.infinity), AdaptiveBreakpoint.compact);
    });

    test('page gutters grow with the layout classes', () {
      expect(AdaptiveBreakpoints.pageGutter(AdaptiveBreakpoint.compact), 16);
      expect(AdaptiveBreakpoints.pageGutter(AdaptiveBreakpoint.medium), 24);
      expect(AdaptiveBreakpoints.pageGutter(AdaptiveBreakpoint.expanded), 32);
      expect(AdaptiveBreakpoints.pageGutter(AdaptiveBreakpoint.large), 40);
    });
  });

  testWidgets('LayoutScope drives container-aware breakpoints', (tester) async {
    AdaptiveBreakpoint? nested;

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 700,
            height: 500,
            child: LayoutScope(
              child: Builder(
                builder: (context) {
                  nested = AdaptiveBreakpoints.of(context);
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      ),
    );

    expect(nested, AdaptiveBreakpoint.medium);
  });

  testWidgets('AdaptiveBreakpointBuilder rebuilds for a new width', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final seen = <AdaptiveBreakpoint>[];

    await tester.pumpWidget(
      MaterialApp(
        home: AdaptiveBreakpointBuilder(
          builder: (context, breakpoint) {
            seen.add(breakpoint);
            return const SizedBox.expand();
          },
        ),
      ),
    );

    expect(seen.last, AdaptiveBreakpoint.compact);

    tester.view.physicalSize = const Size(1200, 844);
    await tester.pump();

    expect(seen.last, AdaptiveBreakpoint.expanded);
  });
}
