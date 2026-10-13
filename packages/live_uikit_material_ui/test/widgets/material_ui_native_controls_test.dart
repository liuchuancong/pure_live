import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_material_ui/live_uikit_material_ui.dart';
import 'package:material_ui/material_ui.dart' as mu;

/// §16 widget tests for `live_uikit_material_ui`.
///
/// Every control is driven through the real runtime path — a [LiveConfigProvider]
/// with the Material UI adapter registered, so `LiveButton`, `LiveSwitch`, …
/// dispatch to the native `material_ui` widgets rather than the shared renderer.
/// Assertions cover the contract rules in §9 (callback preservation, disabled /
/// loading gating, controlled value, controller passthrough) plus a render smoke
/// for the controls and the fallback path, so a break in the adapter→library
/// wiring fails here instead of in the app.
void main() {
  const config = UiConfig(language: LiveDesignLanguage.materialUi, brightness: UiBrightnessMode.light);

  Widget harness(Widget child) => LiveConfigProvider(
    config: config,
    registry: const LanguageRegistry(
      adapters: {LiveDesignLanguage.materialUi: materialUiAdapter},
      fallback: SharedLanguageAdapter(),
    ),
    child: MaterialApp(
      localizationsDelegates: const [...liveLocalizationsDelegates, ...materialUiLocalizationsDelegates],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        // `material_ui` form controls need a `material_ui` Material ancestor for
        // their ink feedback; the shared-renderer controls get Flutter's via the
        // Scaffold. Nesting both keeps either rendering path valid.
        body: Center(child: mu.Material(child: child)),
      ),
    ),
  );

  group('button (§9)', () {
    testWidgets('fires onPressed when enabled', (tester) async {
      var fired = false;
      await tester.pumpWidget(harness(LiveButton(label: 'Save', onPressed: () => fired = true)));
      await tester.tap(find.byType(LiveButton));
      expect(fired, isTrue);
    });

    testWidgets('rejects input while loading', (tester) async {
      var fired = false;
      await tester.pumpWidget(harness(LiveButton(label: 'Save', loading: true, onPressed: () => fired = true)));
      await tester.tap(find.byType(LiveButton));
      expect(fired, isFalse);
    });
  });

  group('text field (§9)', () {
    testWidgets('preserves the caller controller and fires onChanged', (tester) async {
      final controller = TextEditingController(text: 'hi');
      String? changed;
      await tester.pumpWidget(harness(LiveTextField(controller: controller, onChanged: (v) => changed = v)));
      await tester.enterText(find.byType(EditableText), 'yo');
      await tester.pump();
      expect(controller.text, 'yo');
      expect(changed, 'yo');
    });
  });

  group('switch (§9)', () {
    testWidgets('reports the next value through onChanged', (tester) async {
      bool? value;
      await tester.pumpWidget(harness(LiveSwitch(value: false, onChanged: (v) => value = v)));
      await tester.tap(find.byType(LiveSwitch));
      await tester.pump();
      expect(value, isTrue);
    });
  });

  group('checkbox (§9)', () {
    testWidgets('reports the next value through onChanged', (tester) async {
      bool? value;
      await tester.pumpWidget(harness(LiveCheckbox(value: false, onChanged: (v) => value = v)));
      await tester.tap(find.byType(LiveCheckbox));
      await tester.pump();
      expect(value, isTrue);
    });
  });

  group('card (§9)', () {
    testWidgets('fires onTap when interactive', (tester) async {
      var tapped = false;
      await tester.pumpWidget(harness(LiveCard(onTap: () => tapped = true, child: const Text('body'))));
      await tester.tap(find.byType(LiveCard));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });

  group('native controls render through the Material UI adapter', () {
    testWidgets('slider, segmented and progress build without error', (tester) async {
      await tester.pumpWidget(
        harness(
          Column(
            children: [
              LiveSlider(value: 0.5, onChanged: (_) {}),
              LiveSegmented(labels: const ['A', 'B'], index: 0, onChanged: (_) {}),
              const LiveProgress(value: 0.5),
            ],
          ),
        ),
      );
      expect(find.byType(LiveSlider), findsOneWidget);
      expect(find.byType(LiveSegmented), findsOneWidget);
      expect(find.byType(LiveProgress), findsOneWidget);
    });
  });

  group('shared fallback (§15.3)', () {
    testWidgets('a control the adapter does not override still renders', (tester) async {
      // Material UI declares neither select nor tabs; they resolve through the
      // shared token renderer the adapter extends, so nothing disappears.
      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 400,
            child: LiveSelect<String>(items: const ['a', 'b'], itemLabel: (s) => s, onChanged: (_) {}),
          ),
        ),
      );
      expect(find.byType(LiveSelect<String>), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
