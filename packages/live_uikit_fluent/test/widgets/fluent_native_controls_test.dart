import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_fluent/live_uikit_fluent.dart';

/// §16 widget tests for `live_uikit_fluent`, driving the `Live*` controls through
/// the real runtime so they dispatch to the native `fluent_ui` widgets rather
/// than the shared token renderer. Covers §9 gating (callback, disabled, loading,
/// controlled value, controller passthrough) plus the shared fallback.
void main() {
  const config = UiConfig(language: LiveDesignLanguage.fluent, brightness: UiBrightnessMode.light);

  Widget harness(Widget child) => LiveConfigProvider(
    config: config,
    registry: const LanguageRegistry(
      adapters: {LiveDesignLanguage.fluent: fluentUiAdapter},
      fallback: SharedLanguageAdapter(),
    ),
    // The host app supplies localization and the overlay; `adapter.wrap` installs
    // the mapped Fluent theme inside this subtree (§8.2), exactly as production does.
    child: MaterialApp(
      localizationsDelegates: const [...liveLocalizationsDelegates, ...fluentLocalizationsDelegates],
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: Center(child: child)),
    ),
  );

  group('button (§9)', () {
    testWidgets('fires onPressed when enabled', (tester) async {
      var fired = false;
      await tester.pumpWidget(harness(LiveButton(label: 'Save', onPressed: () => fired = true)));
      await tester.tap(find.byType(LiveButton));
      // Fluent schedules hover-debounce timers on press; advance time so they
      // fire before the test ends, or the framework reports them as pending.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(fired, isTrue);
    });

    testWidgets('rejects input while loading', (tester) async {
      var fired = false;
      await tester.pumpWidget(harness(LiveButton(label: 'Save', loading: true, onPressed: () => fired = true)));
      await tester.tap(find.byType(LiveButton));
      // The loading spinner animates forever, so `pumpAndSettle` would never
      // settle; advance time instead to fire the hover-debounce timers Fluent
      // schedules on press.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(fired, isFalse);
    });

    testWidgets('primary is filled, secondary is the plain button', (tester) async {
      await tester.pumpWidget(
        harness(
          Column(
            children: [
              LiveButton(label: 'p', onPressed: () {}),
              LiveButton(label: 's', variant: ButtonVariant.secondary, onPressed: () {}),
            ],
          ),
        ),
      );
      expect(find.byType(fluent.FilledButton), findsOneWidget);
      expect(find.byType(fluent.Button), findsOneWidget);
    });

    testWidgets('expand, tooltip, focus node and autofocus are preserved', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 320,
            child: LiveButton(
              label: 'Wide',
              expand: true,
              tooltip: 'Save it',
              focusNode: node,
              autofocus: true,
              onPressed: () {},
            ),
          ),
        ),
      );
      final button = tester.widget<fluent.FilledButton>(find.byType(fluent.FilledButton));
      expect(button.focusNode, same(node));
      expect(button.autofocus, isTrue);
      final wrappers = tester
          .widgetList<SizedBox>(find.ancestor(of: find.byType(fluent.FilledButton), matching: find.byType(SizedBox)))
          .toList();
      expect(wrappers.any((box) => box.width == double.infinity), isTrue);
      expect(find.byType(LiveTooltip), findsOneWidget);
    });
  });

  group('card (§9)', () {
    testWidgets('tap and long-press reach the caller, and a pointer shows over it', (tester) async {
      var tapped = false;
      var held = false;
      await tester.pumpWidget(
        harness(LiveCard(onTap: () => tapped = true, onLongPress: () => held = true, child: const Text('body'))),
      );
      expect(find.byType(fluent.Card), findsOneWidget);
      expect(find.byType(MouseRegion), findsWidgets);
      await tester.tap(find.byType(LiveCard));
      await tester.pump();
      expect(tapped, isTrue);
      await tester.longPress(find.byType(LiveCard));
      await tester.pump();
      expect(held, isTrue);
    });

    testWidgets('padding, dense and selected map onto the fork surface', (tester) async {
      late LiveTheme theme;
      await tester.pumpWidget(
        harness(
          Column(
            children: [
              Builder(
                builder: (context) {
                  theme = LiveTheme.of(context);
                  return const SizedBox.shrink();
                },
              ),
              const LiveCard(dense: true, child: Text('a')),
              const LiveCard(padding: EdgeInsets.all(21), child: Text('b')),
              const LiveCard(selected: true, bordered: true, child: Text('c')),
            ],
          ),
        ),
      );
      final cards = tester.widgetList<fluent.Card>(find.byType(fluent.Card)).toList();
      expect(cards.map((card) => card.padding), contains(EdgeInsets.all(theme.card.padding * 0.66)));
      expect(cards.map((card) => card.padding), contains(const EdgeInsets.all(21)));
      expect(cards.last.backgroundColor, theme.colors.primaryBg);
      expect(cards.last.borderColor, theme.colors.border);
    });
  });

  group('text field (§9)', () {
    testWidgets('keeps the caller controller and reports changes', (tester) async {
      final controller = TextEditingController(text: 'hi');
      addTearDown(controller.dispose);
      String? changed;
      await tester.pumpWidget(harness(LiveTextField(controller: controller, onChanged: (v) => changed = v)));
      expect(tester.widget<fluent.TextBox>(find.byType(fluent.TextBox)).controller, same(controller));
      await tester.enterText(find.byType(EditableText), 'yo');
      await tester.pump();
      expect(controller.text, 'yo');
      expect(changed, 'yo');
    });

    testWidgets('error, slots and the inline style reach the fork', (tester) async {
      await tester.pumpWidget(
        harness(
          const LiveTextField(
            placeholder: 'Name',
            prefix: Icon(Icons.person),
            suffix: Icon(Icons.check),
            errorText: 'Required',
            enabled: false,
            style: Style(fontSize: 22, foreground: Color(0xFF0000FF)),
          ),
        ),
      );
      final field = tester.widget<fluent.TextBox>(find.byType(fluent.TextBox));
      expect(field.prefix, isNotNull);
      expect(field.suffix, isNotNull);
      expect(field.enabled, isFalse);
      expect(field.style?.fontSize, 22);
      expect(field.style?.color, const Color(0xFF0000FF));
      expect(find.text('Required'), findsOneWidget);
    });
  });

  group('switch, checkbox, slider, progress and select (§9)', () {
    testWidgets('switch reports the next value', (tester) async {
      bool? value;
      await tester.pumpWidget(harness(LiveSwitch(value: false, onChanged: (v) => value = v)));
      await tester.tap(find.byType(LiveSwitch));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(value, isTrue);
    });

    testWidgets('a null callback disables the checkbox instead of faking one', (tester) async {
      await tester.pumpWidget(harness(const LiveCheckbox(value: false, label: 'Remember', onChanged: null)));
      expect(tester.widget<fluent.Checkbox>(find.byType(fluent.Checkbox)).onChanged, isNull);
      expect(find.text('Remember'), findsOneWidget);

      await tester.pumpWidget(harness(LiveCheckbox(value: false, onChanged: (_) {})));
      expect(tester.widget<fluent.Checkbox>(find.byType(fluent.Checkbox)).onChanged, isNotNull);
    });

    testWidgets('slider keeps its range and drops the callback when disabled', (tester) async {
      await tester.pumpWidget(harness(SizedBox(width: 300, child: LiveSlider(value: 0.5, max: 2, onChanged: (_) {}))));
      final slider = tester.widget<fluent.Slider>(find.byType(fluent.Slider));
      expect(slider.min, 0);
      expect(slider.max, 2);

      await tester.pumpWidget(
        harness(SizedBox(width: 300, child: LiveSlider(value: 0.5, enabled: false, onChanged: (_) {}))),
      );
      expect(tester.widget<fluent.Slider>(find.byType(fluent.Slider)).onChanged, isNull);
    });

    testWidgets('progress keeps indeterminate, thickness and tint', (tester) async {
      late LiveTheme theme;
      await tester.pumpWidget(
        harness(
          Column(
            children: [
              Builder(
                builder: (context) {
                  theme = LiveTheme.of(context);
                  return const SizedBox.shrink();
                },
              ),
              const LiveProgress(value: null),
              const LiveProgress(value: 0.5, height: 12, barColor: Color(0xFF00FF00)),
            ],
          ),
        ),
      );
      final bars = tester.widgetList<fluent.ProgressBar>(find.byType(fluent.ProgressBar)).toList();
      expect(bars.first.value, isNull, reason: 'null stays the fork animation (§9)');
      expect(bars.last.value, 50, reason: 'the spec fraction scales to Fluent percent');
      expect(bars.last.strokeWidth, 12);
      expect(bars.last.activeColor, const Color(0xFF00FF00));
      expect(tester.takeException(), isNull);
      expect(theme.colors.primary, isNotNull);
    });

    testWidgets('select renders typed items through the fork', (tester) async {
      String? selected;
      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 300,
            child: LiveSelect<String>(items: const ['a', 'b'], itemLabel: (s) => s, onChanged: (v) => selected = v),
          ),
        ),
      );
      expect(find.byType(fluent.ComboBox<String>), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(selected, isNull);
    });
  });

  group('shared fallback (§15.3)', () {
    testWidgets('a control the adapter does not override still renders', (tester) async {
      await tester.pumpWidget(harness(LiveSegmented(labels: const ['A', 'B'], index: 0, onChanged: (_) {})));
      expect(find.byType(LiveSegmented), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
