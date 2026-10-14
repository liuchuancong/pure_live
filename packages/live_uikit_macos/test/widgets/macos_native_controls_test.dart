import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_macos/live_uikit_macos.dart';
import 'package:macos_ui/macos_ui.dart' as macos;

/// §16 widget tests for `live_uikit_macos`, driven through the real runtime path
/// so `Live*` controls dispatch to the native `macos_ui` widgets.
void main() {
  const config = UiConfig(language: LiveDesignLanguage.macos, brightness: UiBrightnessMode.light);

  Widget harness(Widget child) => LiveConfigProvider(
    config: config,
    registry: const LanguageRegistry(
      adapters: {LiveDesignLanguage.macos: macosUiAdapter},
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

  testWidgets('text field preserves controller and fires onChanged (§9)', (tester) async {
    final controller = TextEditingController(text: 'hi');
    String? changed;
    await tester.pumpWidget(harness(LiveTextField(controller: controller, onChanged: (v) => changed = v)));
    await tester.enterText(find.byType(EditableText), 'yo');
    await tester.pump();
    expect(controller.text, 'yo');
    expect(changed, 'yo');
  });

  testWidgets('checkbox reports the next value (§9)', (tester) async {
    bool? value;
    await tester.pumpWidget(harness(LiveCheckbox(value: false, onChanged: (v) => value = v)));
    await tester.tap(find.byType(LiveCheckbox));
    await tester.pump();
    expect(value, isTrue);
  });

  testWidgets('slider renders through the macOS adapter', (tester) async {
    await tester.pumpWidget(harness(SizedBox(width: 300, child: LiveSlider(value: 0.5, onChanged: (_) {}))));
    expect(find.byType(LiveSlider), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unoverridden control still renders via the shared fallback', (tester) async {
    await tester.pumpWidget(harness(LiveSwitch(value: false, onChanged: (_) {})));
    expect(find.byType(LiveSwitch), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('disabled and preserved spec fields (§9/§16)', () {
    testWidgets('a null callback disables the checkbox rather than faking one', (tester) async {
      await tester.pumpWidget(harness(const LiveCheckbox(value: false, onChanged: null)));
      expect(tester.widget<macos.MacosCheckbox>(find.byType(macos.MacosCheckbox)).onChanged, isNull);
      await tester.pumpWidget(harness(LiveCheckbox(value: false, enabled: false, onChanged: (_) {})));
      expect(tester.widget<macos.MacosCheckbox>(find.byType(macos.MacosCheckbox)).onChanged, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a disabled slider takes the documented shared fallback', (tester) async {
      // `MacosSlider.onChanged` is required, so the fork cannot draw a dead
      // slider; the token renderer stands in instead of a swallow-the-value
      // closure (§9/§15).
      await tester.pumpWidget(harness(const SizedBox(width: 300, child: LiveSlider(value: 0.5, onChanged: null))));
      expect(find.byType(macos.MacosSlider), findsNothing);
      expect(find.byType(LiveSlider), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(harness(SizedBox(width: 300, child: LiveSlider(value: 0.5, onChanged: (_) {}))));
      final slider = tester.widget<macos.MacosSlider>(find.byType(macos.MacosSlider));
      expect(slider.min, 0);
      expect(slider.max, 1);
      expect(slider.onChanged, isNotNull);
    });

    testWidgets('expand, tooltip and the accessible label reach the button', (tester) async {
      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 320,
            child: LiveButton(label: 'Wide', icon: Icons.save, expand: true, tooltip: 'Save it', onPressed: () {}),
          ),
        ),
      );
      final button = tester.widget<macos.PushButton>(find.byType(macos.PushButton));
      expect(button.semanticLabel, 'Save it');
      final wrappers = tester
          .widgetList<SizedBox>(find.ancestor(of: find.byType(macos.PushButton), matching: find.byType(SizedBox)))
          .toList();
      expect(wrappers.any((box) => box.width == double.infinity), isTrue);
      expect(find.byType(LiveTooltip), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('text field keeps prefix, suffix, and the error message', (tester) async {
      await tester.pumpWidget(
        harness(
          const LiveTextField(
            placeholder: 'Name',
            prefix: Icon(Icons.person),
            suffix: Icon(Icons.check),
            errorText: 'Required',
          ),
        ),
      );
      final field = tester.widget<macos.MacosTextField>(find.byType(macos.MacosTextField));
      expect(field.prefix, isNotNull);
      expect(field.suffix, isNotNull);
      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('an inline style overrides the token body text', (tester) async {
      await tester.pumpWidget(
        harness(
          const LiveTextField(
            style: Style(fontSize: 22, foreground: Color(0xFF0000FF), fontFamily: 'Monospace'),
          ),
        ),
      );
      final style = tester.widget<macos.MacosTextField>(find.byType(macos.MacosTextField)).style;
      expect(style?.fontSize, 22);
      expect(style?.color, const Color(0xFF0000FF));
      expect(style?.fontFamily, 'Monospace');
    });
  });

  group('caller-owned focus (§9/§16)', () {
    testWidgets('the field takes the caller node into the focus tree', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(harness(LiveTextField(focusNode: node)));
      expect(tester.widget<macos.MacosTextField>(find.byType(macos.MacosTextField)).focusNode, same(node));
      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isTrue, reason: 'the node reached the focus tree, not just the widget');
    });
  });
}
