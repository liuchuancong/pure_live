import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The spinner is a name for `PureProgress`'s ring, so the contract these
/// tests hold is the delegation itself: every language builds, the requested
/// diameter reaches the painted ring, and the colour override travels.
final Finder _ringCanvas = find.descendant(of: find.byType(PureProgress), matching: find.byType(CustomPaint));

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  PureDesignLanguage language = PureDesignLanguage.material,
}) async {
  await tester.pumpWidget(
    PureConfigProvider(
      config: UiConfig(language: language),
      child: MaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: 240, child: child)),
        ),
      ),
    ),
  );
  // One frame, never a settle — a spinner repeats forever.
  await tester.pump();
}

void main() {
  testWidgets('every design language builds the spinner ring', (tester) async {
    for (final language in PureDesignLanguage.values) {
      await _pump(tester, const PureSpinner(size: 28), language: language);
      expect(tester.takeException(), isNull, reason: '$language failed to build');
      expect(find.descendant(of: find.byType(PureSpinner), matching: find.byType(PureProgress)), findsOneWidget);
    }
  });

  testWidgets("the asked diameter reaches the ring in every language's shape", (tester) async {
    for (final language in PureDesignLanguage.values) {
      await _pump(tester, const PureSpinner(size: 20), language: language);
      final painted = tester.getRect(_ringCanvas.first);
      expect(painted.shortestSide, 20, reason: '$language ignored the diameter it was handed');
    }
  });

  testWidgets('a colour override reaches the ring', (tester) async {
    const tint = Color(0xFF00AA11);
    await _pump(tester, const PureSpinner(color: tint));
    final progress = tester.widget<PureProgress>(
      find.descendant(of: find.byType(PureSpinner), matching: find.byType(PureProgress)),
    );
    expect(progress.barColor, tint);
    expect(progress.value, isNull, reason: 'a spinner has no fraction to name');
    expect(progress.shape, PureProgressShape.circular);
  });
}
