import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_wind/live_uikit_wind.dart';

/// §16 widget tests for `live_uikit_wind`, driving the `Live*` controls through
/// the real runtime so they render with the native `fluttersdk_wind` widgets.
void main() {
  const config = UiConfig(language: LiveDesignLanguage.wind, brightness: UiBrightnessMode.light);

  Widget harness(Widget child) => LiveConfigProvider(
    config: config,
    registry: const LanguageRegistry(
      adapters: {LiveDesignLanguage.wind: windUiAdapter},
      fallback: SharedLanguageAdapter(),
    ),
    child: MaterialApp(
      localizationsDelegates: liveLocalizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: Center(child: child)),
    ),
  );

  group('button (§9/§16)', () {
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

    testWidgets('the seam verdict is also the visual state', (tester) async {
      var fired = false;
      await tester.pumpWidget(
        harness(
          Column(
            children: [
              const LiveButton(label: 'no callback'),
              LiveButton(label: 'loading', loading: true, onPressed: () => fired = true),
            ],
          ),
        ),
      );
      // `disabled` comes from the same `interactive(spec)` verdict that nulls the
      // callback, so a Wind button cannot look live while being dead (§2.3).
      final buttons = tester.widgetList<wind.WButton>(find.byType(wind.WButton)).toList();
      expect(buttons.map((button) => button.onTap).every((tap) => tap == null), isTrue);
      expect(buttons.map((button) => button.disabled).every((disabled) => disabled), isTrue);
      await tester.tap(find.byType(LiveButton).last, warnIfMissed: false);
      expect(fired, isFalse);
    });

    testWidgets('expand and tooltip are preserved; focus is not expressible', (tester) async {
      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 320,
            child: LiveButton(
              label: 'Wide',
              expand: true,
              tooltip: 'Save it',
              focusNode: FocusNode(),
              autofocus: true,
              onPressed: () {},
            ),
          ),
        ),
      );
      final button = tester.widget<wind.WButton>(find.byType(wind.WButton));
      expect(button.className, contains('w-full'));
      expect(tester.widget<Tooltip>(find.byType(Tooltip)).message, 'Save it');
      expect(button.semanticLabel, 'Save it');
      // `WAnchor` creates and tracks its own focus node, so a caller node has no
      // slot: §9 records focusNode/autofocus as unexpressible rather than letting
      // the adapter bolt on a second node that would steal activation (§15).
      expect(find.byType(Focus), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a null callback disables as hard as enabled: false', (tester) async {
      await tester.pumpWidget(
        harness(
          const Column(
            children: [LiveSwitch(value: false, onChanged: null), LiveCheckbox(value: false, onChanged: null)],
          ),
        ),
      );
      expect(tester.widget<wind.WSwitch>(find.byType(wind.WSwitch)).onChanged, isNull);
      expect(tester.widget<wind.WSwitch>(find.byType(wind.WSwitch)).disabled, isTrue);
      expect(tester.widget<wind.WCheckbox>(find.byType(wind.WCheckbox)).onChanged, isNull);
      expect(tester.takeException(), isNull);
    });
  });

  group('card (§9/§16)', () {
    testWidgets('fires onTap and onLongPress when interactive', (tester) async {
      var tapped = false;
      var held = false;
      await tester.pumpWidget(
        harness(LiveCard(onTap: () => tapped = true, onLongPress: () => held = true, child: const Text('body'))),
      );
      expect(find.byType(wind.WCard), findsOneWidget);
      await tester.tap(find.byType(LiveCard));
      await tester.pump();
      expect(tapped, isTrue);
      await tester.longPress(find.byType(LiveCard));
      await tester.pump();
      expect(held, isTrue);
    });

    testWidgets('a plain card gets no gesture layer, dense tightens padding', (tester) async {
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
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Padding && widget.padding == EdgeInsets.all(theme.card.padding * 0.66),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((widget) => widget is Padding && widget.padding == EdgeInsets.all(theme.card.padding)),
        findsOneWidget,
      );
    });

    testWidgets('selected tints and explicit padding wins', (tester) async {
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
              const LiveCard(selected: true, child: Text('a')),
              const LiveCard(padding: EdgeInsets.all(21), child: Text('b')),
            ],
          ),
        ),
      );
      final decorated = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).toList();
      expect(
        decorated.any((box) => (box.decoration as BoxDecoration).color == theme.colors.primaryBg),
        isTrue,
        reason: 'a selected card must read as selected',
      );
      expect(
        find.byWidgetPredicate((widget) => widget is Padding && widget.padding == const EdgeInsets.all(21)),
        findsOneWidget,
      );
    });
  });

  group('text field (§9/§16)', () {
    testWidgets('the caller controller is passed through and reports changes', (tester) async {
      final controller = TextEditingController(text: 'hi');
      addTearDown(controller.dispose);
      String? changed;
      await tester.pumpWidget(harness(LiveTextField(controller: controller, onChanged: (v) => changed = v)));
      final field = tester.widget<wind.WInput>(find.byType(wind.WInput));
      expect(field.controller, same(controller));
      await tester.enterText(find.byType(LiveTextField), 'yo');
      await tester.pump();
      expect(controller.text, 'yo');
      expect(changed, 'yo');
    });

    testWidgets('obscure and the line count pick the fork input type', (tester) async {
      await tester.pumpWidget(harness(const LiveTextField(obscure: true)));
      expect(tester.widget<wind.WInput>(find.byType(wind.WInput)).type, wind.InputType.password);

      await tester.pumpWidget(harness(const LiveTextField(keyboardType: TextInputType.emailAddress)));
      expect(tester.widget<wind.WInput>(find.byType(wind.WInput)).type, wind.InputType.email);

      await tester.pumpWidget(harness(const LiveTextField(maxLines: 4)));
      expect(tester.widget<wind.WInput>(find.byType(wind.WInput)).type, wind.InputType.multiline);
    });

    testWidgets('errorText marks the fork error state and shows the message', (tester) async {
      await tester.pumpWidget(harness(const LiveTextField(errorText: 'Required')));
      expect(tester.widget<wind.WInput>(find.byType(wind.WInput)).states, contains('error'));
      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('enabled: false reaches the fork', (tester) async {
      await tester.pumpWidget(harness(const LiveTextField(enabled: false)));
      expect(tester.widget<wind.WInput>(find.byType(wind.WInput)).enabled, isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  group('switch and checkbox (§9)', () {
    testWidgets('switch renders through the Wind adapter', (tester) async {
      await tester.pumpWidget(harness(LiveSwitch(value: true, onChanged: (_) {})));
      final switchWidget = tester.widget<wind.WSwitch>(find.byType(wind.WSwitch));
      expect(switchWidget.value, isTrue);
      expect(switchWidget.disabled, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('checkbox reports the next value', (tester) async {
      bool? value;
      await tester.pumpWidget(harness(LiveCheckbox(value: false, label: 'Remember', onChanged: (v) => value = v)));
      // The label is rendered beside the box, so the row's centre is not a hit
      // target; the box itself is what carries the tap.
      await tester.tap(find.byType(wind.WCheckbox));
      await tester.pump();
      expect(value, isTrue);
      expect(find.text('Remember'), findsOneWidget);
    });
  });

  group('shared fallback (§15.3)', () {
    testWidgets('a control the adapter does not override still renders', (tester) async {
      await tester.pumpWidget(harness(LiveSlider(value: 0.5, onChanged: (_) {})));
      expect(find.byType(wind.WInput), findsNothing);
      expect(find.byType(LiveSlider), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
