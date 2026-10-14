import 'package:cupertino_ui/cupertino_ui.dart' as cu;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_cupertino_ui/live_uikit_cupertino_ui.dart';

/// §16 widget tests for `live_uikit_cupertino_ui`, driven through the real
/// runtime path so `LiveButton`/`LiveSwitch`/… dispatch to the native
/// `cupertino_ui` widgets. Covers §9 rules (callback + loading gating, controller
/// passthrough, controlled switch) plus a render smoke and the shared fallback.
void main() {
  const config = UiConfig(language: LiveDesignLanguage.cupertinoUi, brightness: UiBrightnessMode.light);

  Widget harness(Widget child) => LiveConfigProvider(
    config: config,
    registry: const LanguageRegistry(
      adapters: {LiveDesignLanguage.cupertinoUi: cupertinoUiAdapter},
      fallback: SharedLanguageAdapter(),
    ),
    // The Scaffold supplies Flutter's Material for the shared-renderer controls;
    // the Cupertino widgets themselves get their theme from `adapter.wrap`.
    child: MaterialApp(
      localizationsDelegates: const [...liveLocalizationsDelegates, ...cupertinoUiLocalizationsDelegates],
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

  testWidgets('switch reports the next value (§9)', (tester) async {
    bool? value;
    await tester.pumpWidget(harness(LiveSwitch(value: false, onChanged: (v) => value = v)));
    await tester.tap(find.byType(LiveSwitch));
    await tester.pump();
    expect(value, isTrue);
  });

  testWidgets('slider renders through the Cupertino UI adapter', (tester) async {
    await tester.pumpWidget(harness(SizedBox(width: 300, child: LiveSlider(value: 0.5, onChanged: (_) {}))));
    expect(find.byType(LiveSlider), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unoverridden control still renders via the shared fallback', (tester) async {
    await tester.pumpWidget(
      harness(
        SizedBox(
          width: 300,
          child: LiveCard(onTap: () {}, child: const Text('body')),
        ),
      ),
    );
    expect(find.byType(LiveCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('spec fields the fork can carry (§9/§16)', () {
    testWidgets('a null callback reaches the slider as null, not as a no-op', (tester) async {
      await tester.pumpWidget(harness(const SizedBox(width: 300, child: LiveSlider(value: 0.5, onChanged: null))));
      expect(tester.widget<cu.CupertinoSlider>(find.byType(cu.CupertinoSlider)).onChanged, isNull);
      await tester.pumpWidget(
        harness(SizedBox(width: 300, child: LiveSlider(value: 0.5, enabled: false, onChanged: (_) {}))),
      );
      expect(tester.widget<cu.CupertinoSlider>(find.byType(cu.CupertinoSlider)).onChanged, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('expand and tooltip wrap the button', (tester) async {
      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 320,
            child: LiveButton(label: 'Wide', expand: true, tooltip: 'Save it', onPressed: () {}),
          ),
        ),
      );
      final wrappers = tester
          .widgetList<SizedBox>(find.ancestor(of: find.byType(cu.CupertinoButton), matching: find.byType(SizedBox)))
          .toList();
      expect(wrappers.any((box) => box.width == double.infinity), isTrue);
      expect(find.byType(LiveTooltip), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('text field keeps prefix, suffix and the error message', (tester) async {
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
      final field = tester.widget<cu.CupertinoTextField>(find.byType(cu.CupertinoTextField));
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
      final style = tester.widget<cu.CupertinoTextField>(find.byType(cu.CupertinoTextField)).style;
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
      expect(tester.widget<cu.CupertinoTextField>(find.byType(cu.CupertinoTextField)).focusNode, same(node));
      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isTrue, reason: 'the node reached the focus tree, not just the widget');
    });
    testWidgets('the button takes the caller node and its autofocus flag', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(harness(LiveButton(label: 'Save', focusNode: node, autofocus: true, onPressed: () {})));
      final button = tester.widget<cu.CupertinoButton>(find.byType(cu.CupertinoButton));
      expect(button.focusNode, same(node));
      expect(button.autofocus, isTrue);
    });
  });
}
