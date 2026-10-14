import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_glass/live_uikit_glass.dart';

/// §16 widget tests for `live_uikit_glass`, driving the `Live*` controls through
/// the real runtime so they render with the native `glass_morphism_plus` widgets.
void main() {
  const config = UiConfig(language: LiveDesignLanguage.glass, brightness: UiBrightnessMode.light);

  Widget harness(Widget child) => LiveConfigProvider(
    config: config,
    registry: const LanguageRegistry(
      adapters: {LiveDesignLanguage.glass: glassUiAdapter},
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

  testWidgets('card reports tap (§9)', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      harness(
        SizedBox(
          width: 260,
          child: LiveCard(onTap: () => tapped = true, child: const Text('b')),
        ),
      ),
    );
    await tester.tap(find.byType(LiveCard));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('text field preserves controller and fires onChanged (§9)', (tester) async {
    final controller = TextEditingController(text: 'hi');
    String? changed;
    await tester.pumpWidget(
      harness(
        SizedBox(
          width: 260,
          child: LiveTextField(controller: controller, onChanged: (v) => changed = v),
        ),
      ),
    );
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

  group('spec fields the frosted widgets carry (§9/§16)', () {
    testWidgets('card keeps the token padding, the dense step, and no dead gesture layer', (tester) async {
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
              const LiveCard(child: Text('b')),
            ],
          ),
        ),
      );
      expect(find.byType(GestureDetector), findsNothing);
      // The fork applies `padding` inside its own surface, so the assertion reads
      // the property rather than hunting for a Padding widget.
      final paddings = tester
          .widgetList<glass.GlassCard>(find.byType(glass.GlassCard))
          .map((card) => card.padding)
          .toList();
      expect(paddings, contains(EdgeInsets.all(theme.card.padding * 0.66)));
      expect(paddings, contains(EdgeInsets.all(theme.card.padding)));
    });

    testWidgets('text field passes the caller state through and shows the error caption', (tester) async {
      final controller = TextEditingController(text: 'kept');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        harness(
          LiveTextField(
            controller: controller,
            placeholder: 'Name',
            errorText: 'Required',
            prefix: const Icon(Icons.person),
            enabled: false,
          ),
        ),
      );
      final field = tester.widget<glass.GlassTextField>(find.byType(glass.GlassTextField));
      expect(field.controller, same(controller));
      expect(field.hintText, 'Name');
      expect(field.enabled, isFalse);
      expect(field.prefixIcon, isNotNull);
      expect(find.text('Required'), findsOneWidget);
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
          .widgetList<SizedBox>(find.ancestor(of: find.byType(glass.GlassButton), matching: find.byType(SizedBox)))
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
      expect(tester.widget<glass.GlassTextField>(find.byType(glass.GlassTextField)).focusNode, same(node));
      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isTrue, reason: 'the node reached the focus tree, not just the widget');
    });
  });
}
