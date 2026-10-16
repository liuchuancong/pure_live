import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart' as forui;
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_forui/live_uikit_forui.dart';

/// §16 widget tests for `live_uikit_forui`, driven through the real runtime path so
/// `Live*` controls dispatch to the native forui `F*` widgets and the assertions are
/// about the spec fields reaching them (§9), not about a builder in isolation.
void main() {
  const config = UiConfig(language: LiveDesignLanguage.forui, brightness: UiBrightnessMode.light);

  Widget harness(Widget child) => LiveConfigProvider(
    config: config,
    registry: const LanguageRegistry(
      adapters: {LiveDesignLanguage.forui: foruiAdapter},
      fallback: SharedLanguageAdapter(),
    ),
    child: MaterialApp(
      localizationsDelegates: const [...liveLocalizationsDelegates, ...foruiLocalizationsDelegates],
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: Center(child: child)),
    ),
  );

  group('button (§9)', () {
    testWidgets('a callback is what makes the button pressable', (tester) async {
      var fired = 0;
      await tester.pumpWidget(harness(LiveButton(label: 'Save', onPressed: () => fired++)));
      expect(tester.widget<forui.FButton>(find.byType(forui.FButton)).onPress, isNotNull);
      await tester.tap(find.byType(forui.FButton));
      // forui's tappable starts a press timer; let it fire before the test ends.
      await tester.pump(const Duration(milliseconds: 150));
      expect(fired, 1);

      await tester.pumpWidget(harness(const LiveButton(label: 'Save')));
      // forui's disabled state *is* a null `onPress`, so no callback is invented.
      expect(tester.widget<forui.FButton>(find.byType(forui.FButton)).onPress, isNull);
    });

    testWidgets('loading rejects input like a disabled button', (tester) async {
      var fired = 0;
      await tester.pumpWidget(harness(LiveButton(label: 'Save', loading: true, onPressed: () => fired++)));
      expect(tester.widget<forui.FButton>(find.byType(forui.FButton)).onPress, isNull);
      await tester.tap(find.byType(forui.FButton));
      // forui's tappable starts a press timer; let it fire before the test ends.
      await tester.pump(const Duration(milliseconds: 150));
      expect(fired, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget, reason: 'the seam swaps the label for a spinner');
    });

    testWidgets("variant and size map onto forui's own kinds", (tester) async {
      await tester.pumpWidget(
        harness(LiveButton(label: 'Delete', variant: ButtonVariant.danger, size: ControlSize.lg, onPressed: () {})),
      );
      final button = tester.widget<forui.FButton>(find.byType(forui.FButton));
      expect(button.variant, forui.FButtonVariant.destructive);
      expect(button.size, forui.FButtonSizeVariant.lg);

      await tester.pumpWidget(harness(LiveButton(label: 'More', variant: ButtonVariant.secondary, onPressed: () {})));
      expect(
        tester.widget<forui.FButton>(find.byType(forui.FButton)).variant,
        forui.FButtonVariant.outline,
        reason: 'the token secondary is a bordered supporting action (§9)',
      );

      await tester.pumpWidget(
        harness(LiveButton(label: 'Quiet', variant: ButtonVariant.ghost, size: ControlSize.sm, onPressed: () {})),
      );
      final quiet = tester.widget<forui.FButton>(find.byType(forui.FButton));
      expect(quiet.variant, forui.FButtonVariant.ghost);
      expect(quiet.size, forui.FButtonSizeVariant.sm);
    });

    testWidgets('selected is mapped onto forui’s own toggled affordance, not painted over (§9/ADR 0004)', (
      tester,
    ) async {
      // `LiveButton` carries no `selected` parameter (only `LiveIconButton` does, §9), so
      // the mapping is driven through the control that can express it.
      await tester.pumpWidget(
        harness(LiveIconButton(icon: Icons.star, tooltip: 'Pin', selected: true, onPressed: () {})),
      );
      expect(tester.widget<forui.FButton>(find.byType(forui.FButton)).selected, isTrue);

      await tester.pumpWidget(harness(LiveIconButton(icon: Icons.star, tooltip: 'Pin', onPressed: () {})));
      expect(tester.widget<forui.FButton>(find.byType(forui.FButton)).selected, isFalse);
    });

    testWidgets('the caller owns focus, and a textless button is named', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(harness(LiveButton(label: 'Save', focusNode: node, autofocus: true, onPressed: () {})));
      final button = tester.widget<forui.FButton>(find.byType(forui.FButton));
      expect(button.focusNode, same(node));
      expect(button.autofocus, isTrue);

      await tester.pumpWidget(
        harness(LiveIconButton(key: const Key('icon'), icon: Icons.star, tooltip: 'Star', onPressed: () {})),
      );
      // The seam names the glyph, so the accessible name lives on the icon the button
      // carries, not on a second `FButton.semanticsLabel` — naming both would announce
      // twice (§9).
      expect(tester.widget<Icon>(find.byIcon(Icons.star)).semanticLabel, 'Star');
      expect(find.byType(forui.FTooltip), findsOneWidget);
    });

    testWidgets("a tooltip wraps the control in forui's own tooltip", (tester) async {
      await tester.pumpWidget(harness(LiveButton(label: 'Save', tooltip: 'Save it', onPressed: () {})));
      expect(tester.widget<forui.FTooltip>(find.byType(forui.FTooltip)).tipBuilder, isNotNull);
      expect(find.byType(forui.FTooltip), findsOneWidget);
    });
  });

  group('card (§9)', () {
    testWidgets('gestures reach an interactive card only', (tester) async {
      var taps = 0;
      await tester.pumpWidget(harness(LiveCard(onTap: () => taps++, child: const Text('body'))));
      expect(find.descendant(of: find.byType(LiveCard), matching: find.byType(GestureDetector)), findsOneWidget);
      await tester.tap(find.text('body'));
      expect(taps, 1);

      await tester.pumpWidget(harness(const LiveCard(child: Text('body'))));
      expect(
        find.descendant(of: find.byType(LiveCard), matching: find.byType(GestureDetector)),
        findsNothing,
        reason: 'a surface that does nothing should not absorb taps (§9)',
      );
    });

    testWidgets("the inside space is the token padding, the density step, or the caller's", (tester) async {
      // The same card token the shared renderer resolves, derived directly so the
      // assertion does not depend on the widget tree it is checking.
      final card = CardComponentToken.of(DesignToken.derive(const SeedToken(), dark: false));

      await tester.pumpWidget(harness(const LiveCard(child: Text('body'))));
      expect(_cardPadding(tester), EdgeInsets.all(card.padding));

      await tester.pumpWidget(harness(const LiveCard(dense: true, child: Text('body'))));
      expect(_cardPadding(tester), EdgeInsets.all(card.padding * 0.66));

      await tester.pumpWidget(
        harness(const LiveCard(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('body'))),
      );
      expect(_cardPadding(tester), const EdgeInsets.symmetric(horizontal: 4));
    });
  });

  group('text field (§9)', () {
    testWidgets('the caller controller is carried and changes are bridged', (tester) async {
      final controller = TextEditingController(text: 'kept');
      addTearDown(controller.dispose);
      String? changed;
      await tester.pumpWidget(harness(LiveTextField(controller: controller, onChanged: (value) => changed = value)));

      final control =
          tester.widget<forui.FTextField>(find.byType(forui.FTextField)).control as forui.FTextFieldManagedControl;
      expect(control.controller, same(controller), reason: 'the adapter must not mint a competing controller');
      control.onChange!(const TextEditingValue(text: 'typed'));
      expect(changed, 'typed');
    });

    testWidgets('a null callback stays null', (tester) async {
      await tester.pumpWidget(harness(const LiveTextField()));
      final control =
          tester.widget<forui.FTextField>(find.byType(forui.FTextField)).control as forui.FTextFieldManagedControl;
      expect(control.onChange, isNull);
      expect(control.controller, isNull, reason: 'forui owns one when the caller brings none');
    });

    testWidgets('hint, error, obscuring and the line count reach the fork', (tester) async {
      await tester.pumpWidget(harness(const LiveTextField(placeholder: 'Name', errorText: 'Required')));
      final field = tester.widget<forui.FTextField>(find.byType(forui.FTextField));
      expect(field.hint, 'Name');
      // The fork has an error slot, so the message is handed to it rather than invented
      // as a caption beside the field; forui paints that slot inside its form layout, so
      // a bare field carries the state without drawing the string (§9).
      expect((field.error! as Text).data, 'Required');

      await tester.pumpWidget(harness(const LiveTextField(obscure: true, maxLines: 4)));
      final secret = tester.widget<forui.FTextField>(find.byType(forui.FTextField));
      expect(secret.obscureText, isTrue);
      expect(secret.maxLines, 1, reason: 'an obscured field is single-line whatever was asked');

      await tester.pumpWidget(harness(const LiveTextField(maxLines: 3)));
      expect(tester.widget<forui.FTextField>(find.byType(forui.FTextField)).maxLines, 3);
    });

    testWidgets('enabled, readOnly and the icon slots pass through', (tester) async {
      await tester.pumpWidget(harness(const LiveTextField(enabled: false)));
      expect(tester.widget<forui.FTextField>(find.byType(forui.FTextField)).enabled, isFalse);

      await tester.pumpWidget(harness(const LiveTextField(readOnly: true)));
      expect(tester.widget<forui.FTextField>(find.byType(forui.FTextField)).readOnly, isTrue);

      await tester.pumpWidget(harness(const LiveTextField(prefix: Icon(Icons.person), suffix: Icon(Icons.close))));
      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });

  group('switch and checkbox (§9)', () {
    testWidgets('the switch is fully controlled and reports the next value', (tester) async {
      bool? next;
      await tester.pumpWidget(harness(LiveSwitch(value: false, onChanged: (value) => next = value)));
      final toggle = tester.widget<forui.FSwitch>(find.byType(forui.FSwitch));
      expect(toggle.value, isFalse);
      expect(toggle.onChange, isNotNull);
      toggle.onChange!(true);
      expect(next, isTrue);
    });

    testWidgets('a disabled switch reports no handler, and a null callback stays null', (tester) async {
      await tester.pumpWidget(harness(LiveSwitch(value: true, enabled: false, onChanged: (_) {})));
      expect(tester.widget<forui.FSwitch>(find.byType(forui.FSwitch)).onChange, isNull);

      await tester.pumpWidget(harness(const LiveSwitch(value: true, onChanged: null)));
      final quiet = tester.widget<forui.FSwitch>(find.byType(forui.FSwitch));
      expect(quiet.onChange, isNull);
      expect(quiet.enabled, isTrue, reason: "the callback gap is forui's to express, not a fake flag");
    });

    testWidgets("the checkbox label becomes the fork's own label row", (tester) async {
      bool? next;
      await tester.pumpWidget(
        harness(LiveCheckbox(value: false, label: 'remember me', onChanged: (value) => next = value)),
      );
      final box = tester.widget<forui.FCheckbox>(find.byType(forui.FCheckbox));
      expect(box.label, isNotNull);
      expect(find.text('remember me'), findsOneWidget);
      box.onChange!(true);
      expect(next, isTrue);
    });

    testWidgets("focus is the caller's on both controls", (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(harness(LiveSwitch(value: false, focusNode: node, autofocus: true, onChanged: (_) {})));
      final toggle = tester.widget<forui.FSwitch>(find.byType(forui.FSwitch));
      expect(toggle.focusNode, same(node));
      expect(toggle.autofocus, isTrue);

      await tester.pumpWidget(harness(LiveCheckbox(value: false, focusNode: node, onChanged: (_) {})));
      expect(tester.widget<forui.FCheckbox>(find.byType(forui.FCheckbox)).focusNode, same(node));
    });
  });

  testWidgets('a control this adapter does not override still renders (§15.3)', (tester) async {
    await tester.pumpWidget(harness(LiveSlider(value: 0.4, onChanged: (_) {})));
    expect(find.byType(forui.FSlider), findsNothing);
    expect(find.byType(TokenSlider), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

EdgeInsetsGeometry _cardPadding(WidgetTester tester) =>
    tester.widget<Padding>(find.descendant(of: find.byType(forui.FCard), matching: find.byType(Padding))).padding;
