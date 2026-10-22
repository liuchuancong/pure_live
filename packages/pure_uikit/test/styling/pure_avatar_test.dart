// The seams where PureAvatar used to accept `shape: rounded` and draw a circle.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_uikit/pure_uikit.dart';

void main() {
  testWidgets('the circle is a self-painted disc, not the SDK widget', (tester) async {
    await _pump(tester, const PureAvatar(name: 'AB', size: 40, key: ValueKey('av')));

    // Nothing from the SDK's avatar is left to lean on, and no rectangle clip is
    // used for a disc: the plate and its oval are painted here.
    expect(find.byType(CircleAvatar), findsNothing);
    expect(find.byKey(const ValueKey('PureAvatar.material')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('av')), matching: find.byType(ClipRRect)), findsNothing);
    expect(find.byKey(const ValueKey('PureAvatar.plate')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('av')), matching: find.byType(ClipOval)), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('av'))), const Size(40, 40));
  });

  testWidgets('the rounded shape is drawn, not just accepted', (tester) async {
    await _pump(tester, const PureAvatar(name: 'AB', size: 40, shape: PureAvatarShape.rounded, key: ValueKey('av')));

    final clips = find.descendant(of: find.byKey(const ValueKey('av')), matching: find.byType(ClipRRect));
    final clip = tester.widget<ClipRRect>(clips);
    final radius = (clip.borderRadius as BorderRadius).topLeft.x;
    expect(radius, greaterThan(0));
    // A quarter of the edge is the cap: a small avatar must keep straight sides.
    expect(radius, lessThanOrEqualTo(10));
    expect(tester.getSize(find.byKey(const ValueKey('av'))), const Size(40, 40));
  });
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    PureConfigProvider(
      config: const UiConfig(language: PureDesignLanguage.material),
      child: MaterialApp(
        home: Scaffold(body: Center(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
