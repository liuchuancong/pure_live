import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
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
      harness(
        SizedBox(
          width: 300,
          child: LiveSelect<String>(items: const ['a'], itemLabel: (s) => s, onChanged: (_) {}),
        ),
      ),
    );
    expect(find.byType(LiveSelect<String>), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('disabled state and preserved spec fields (§9/§16)', () {
    testWidgets('a null callback disables the checkbox instead of faking one', (tester) async {
      await tester.pumpWidget(harness(const LiveCheckbox(value: false, onChanged: null)));
      expect(tester.widget<neu.NeuCheckbox>(find.byType(neu.NeuCheckbox)).onChanged, isNull);
      await tester.pumpWidget(harness(LiveCheckbox(value: false, enabled: false, onChanged: (_) {})));
      expect(tester.widget<neu.NeuCheckbox>(find.byType(neu.NeuCheckbox)).onChanged, isNull);
      await tester.pumpWidget(harness(LiveCheckbox(value: false, onChanged: (_) {})));
      expect(tester.widget<neu.NeuCheckbox>(find.byType(neu.NeuCheckbox)).onChanged, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the field passes the caller state through', (tester) async {
      final controller = TextEditingController(text: 'kept');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        harness(
          LiveTextField(
            controller: controller,
            placeholder: 'Name',
            errorText: 'Required',
            prefix: const Icon(Icons.person),
            obscure: true,
            enabled: false,
          ),
        ),
      );
      final field = tester.widget<neu.NeuTextField>(find.byType(neu.NeuTextField));
      expect(field.controller, same(controller));
      expect(field.hintText, 'Name');
      expect(field.errorText, 'Required');
      expect(field.obscureText, isTrue);
      expect(field.enabled, isFalse);
      expect(field.prefixIcon, isNotNull);
      // `maxLines` collapses to one line while obscured, the core contract (§9).
      expect(field.maxLines, 1);
    });

    testWidgets('the card keeps dense and explicit padding', (tester) async {
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
            ],
          ),
        ),
      );
      final paddings = tester.widgetList<neu.NeuCard>(find.byType(neu.NeuCard)).map((card) => card.padding).toList();
      expect(paddings, contains(EdgeInsets.all(theme.card.padding * 0.66)));
      expect(paddings, contains(const EdgeInsets.all(21)));
    });

    testWidgets('the card wires a tap, a long press, and an onLongPress-only caller', (tester) async {
      var tapped = false;
      var pressed = false;
      await tester.pumpWidget(harness(LiveCard(onTap: () => tapped = true, child: const Text('a'))));
      await tester.tap(find.byType(LiveCard));
      expect(tapped, isTrue);

      await tester.pumpWidget(harness(LiveCard(onLongPress: () => pressed = true, child: const Text('b'))));
      // §9: the gesture layer goes in for either callback; an `onTap`-only
      // check here silently dropped the long press.
      await tester.longPress(find.byType(LiveCard));
      expect(pressed, isTrue);
    });

    testWidgets('expand and tooltip wrap the button', (tester) async {
      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 300,
            child: LiveButton(label: 'Wide', expand: true, tooltip: 'Save it', onPressed: () {}),
          ),
        ),
      );
      final wrappers = tester
          .widgetList<SizedBox>(find.ancestor(of: find.byType(neu.NeuButton), matching: find.byType(SizedBox)))
          .toList();
      expect(wrappers.any((box) => box.width == double.infinity), isTrue);
      expect(find.byType(LiveTooltip), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('caller-owned focus (§9/§16)', () {
    testWidgets('the field takes the caller node into the focus tree', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(harness(LiveTextField(focusNode: node)));
      expect(tester.widget<neu.NeuTextField>(find.byType(neu.NeuTextField)).focusNode, same(node));
      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isTrue, reason: 'the node reached the focus tree, not just the widget');
    });
  });
}
