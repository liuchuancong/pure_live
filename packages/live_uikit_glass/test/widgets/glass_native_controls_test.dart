import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_glass/live_uikit_glass.dart';

/// §16 widget tests for `live_uikit_glass`, driving the `Live*` controls through
/// the real runtime so they render with the native `glass_morphism_plus` widgets.
void main() {
  const config = UiConfig(language: LiveDesignLanguage.glass, brightness: UiBrightnessMode.light);

  Widget harness(Widget child) => LiveConfigProvider(
    config: config,
    registry: const LanguageRegistry(adapters: {LiveDesignLanguage.glass: glassUiAdapter}, fallback: SharedLanguageAdapter()),
    child: MaterialApp(
      localizationsDelegates: liveLocalizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: Center(child: child)),
    ),
  );

  testWidgets('button fires onPressed when enabled (§9)', (tester) async {
    var fired = false;
    await tester.pumpWidget(harness(LiveButton(label: 'Save', onPressed: () => fired = true)));
    await tester.tap(find.byType(LiveButton));
    expect(fired, isTrue);
  });

  testWidgets('button rejects input while loading (§9)', (tester) async {
    var fired = false;
    await tester.pumpWidget(harness(LiveButton(label: 'Save', loading: true, onPressed: () => fired = true)));
    await tester.tap(find.byType(LiveButton));
    expect(fired, isFalse);
  });

  testWidgets('card reports tap (§9)', (tester) async {
    var tapped = false;
    await tester.pumpWidget(harness(SizedBox(width: 260, child: LiveCard(onTap: () => tapped = true, child: const Text('b')))));
    await tester.tap(find.byType(LiveCard));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('text field preserves controller and fires onChanged (§9)', (tester) async {
    final controller = TextEditingController(text: 'hi');
    String? changed;
    await tester.pumpWidget(harness(SizedBox(width: 260, child: LiveTextField(controller: controller, onChanged: (v) => changed = v))));
    await tester.enterText(find.byType(EditableText), 'yo');
    await tester.pump();
    expect(controller.text, 'yo');
    expect(changed, 'yo');
  });

  testWidgets('an unoverridden control still renders via the shared fallback', (tester) async {
    await tester.pumpWidget(harness(LiveSwitch(value: false, onChanged: (_) {})));
    expect(find.byType(LiveSwitch), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
