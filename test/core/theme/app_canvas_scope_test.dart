import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/theme/app_canvas_scope.dart';

Future<bool> _readUnder(WidgetTester tester, {required bool ownedByBackground}) async {
  late bool seen;
  await tester.pumpWidget(
    AppCanvasScope(
      ownedByBackground: ownedByBackground,
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            seen = AppCanvasScope.ownedByBackgroundOf(context);
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    ),
  );
  return seen;
}

void main() {
  testWidgets('the scope reports whether a background owns the canvas', (tester) async {
    expect(await _readUnder(tester, ownedByBackground: true), isTrue);
    expect(await _readUnder(tester, ownedByBackground: false), isFalse);
  });

  testWidgets('without the scope a page keeps painting its own backdrop', (tester) async {
    late bool seen;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            seen = AppCanvasScope.ownedByBackgroundOf(context);
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    );
    expect(seen, isFalse);
  });
}
