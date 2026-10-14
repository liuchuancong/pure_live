import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/styling.dart';

/// §12's blur rule, asserted where it is applied: `LiveBackground` reads the one
/// environment fact it owns (`LiveTheme.canBlur`) and degrades the frosted
/// treatment instead of paying for an effect the user's accessibility setting or the
/// device ruled out. The same flag gates the image blur layer in the same `build`.
void main() {
  const surface = Color(0x80102030);

  Widget harness(UiConfig? config, Widget child) {
    const style = LiveBackgroundStyle.glass(color: surface);
    final background = LiveBackground(style: style, child: child);
    if (config == null) {
      return Directionality(textDirection: TextDirection.ltr, child: background);
    }
    return LiveConfigProvider(
      config: config,
      child: Directionality(textDirection: TextDirection.ltr, child: background),
    );
  }

  testWidgets('a frosted surface blurs while the theme allows it (§12)', (tester) async {
    await tester.pumpWidget(harness(const UiConfig(), const Text('content')));
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('reduceTransparency drops the filter and keeps the fill (§12)', (tester) async {
    await tester.pumpWidget(harness(const UiConfig(reduceTransparency: true), const Text('content')));
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text('content'), findsOneWidget);
    final decorated = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
    expect((decorated.decoration as BoxDecoration).color, surface);
  });

  testWidgets('an unaffordable host is enough on its own', (tester) async {
    await tester.pumpWidget(
      const LiveConfigProvider(
        config: UiConfig(),
        hardwareBlur: false,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: LiveBackground(
            style: LiveBackgroundStyle.glass(color: surface),
            child: Text('content'),
          ),
        ),
      ),
    );
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('outside a provider the style is honoured as written (§12)', (tester) async {
    await tester.pumpWidget(harness(null, const Text('content')));
    expect(find.byType(BackdropFilter), findsOneWidget);
  });
}
