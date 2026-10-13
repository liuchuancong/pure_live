import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_neumorphic/live_uikit_neumorphic.dart';

/// §16 widget tests for `live_uikit_neumorphic`, driving the `Live*` controls
/// through the real runtime so they render with the native
/// `flutter_neumorphic_ui_kit` widgets.
void main() {
  const config = UiConfig(language: LiveDesignLanguage.neumorphic, brightness: UiBrightnessMode.light);

  Widget harness(Widget child) => LiveConfigProvider(
    config: config,
    registry: const LanguageRegistry(
      adapters: {LiveDesignLanguage.neumorphic: neumorphicUiAdapter},
      fallback: SharedLanguageAdapter(),
    ),
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

  testWidgets('text field preserves the caller controller (§9)', (tester) async {
    final controller = TextEditingController(text: 'hi');
    await tester.pumpWidget(harness(SizedBox(width: 260, child: LiveTextField(controller: controller))));
    await tester.enterText(find.byType(EditableText), 'yo');
    await tester.pump();
    expect(controller.text, 'yo');
    // The Neumorphic field forwards only controller/focus, not onChanged, so the
    // change callback is intentionally not asserted here (§9 limitation).
  });

  testWidgets('switch reports the next value (§9)', (tester) async {
    bool? value;
    await tester.pumpWidget(harness(LiveSwitch(value: false, onChanged: (v) => value = v)));
    await tester.tap(find.byType(LiveSwitch));
    await tester.pump();
    expect(value, isTrue);
  });

  testWidgets('checkbox reports the next value (§9)', (tester) async {
    bool? value;
    await tester.pumpWidget(harness(LiveCheckbox(value: false, onChanged: (v) => value = v)));
    await tester.tap(find.byType(LiveCheckbox));
    await tester.pump();
    expect(value, isTrue);
  });

  testWidgets('card and slider render through the Neumorphic adapter', (tester) async {
    await tester.pumpWidget(
      harness(
        SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LiveCard(onTap: () {}, child: const Text('b')),
              LiveSlider(value: 0.5, onChanged: (_) {}),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(LiveCard), findsOneWidget);
    expect(find.byType(LiveSlider), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unoverridden control still renders via the shared fallback', (tester) async {
    await tester.pumpWidget(
      harness(SizedBox(width: 300, child: LiveSelect<String>(items: const ['a'], itemLabel: (s) => s, onChanged: (_) {}))),
    );
    expect(find.byType(LiveSelect<String>), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
