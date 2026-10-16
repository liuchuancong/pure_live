import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart' as forui;
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_forui/live_uikit_forui.dart';

import 'stub_router.dart';

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

  group('the ten controls ForUI now draws itself (§9)', () {
    testWidgets('a slider is the lifted FSlider, in the caller units, and a null callback is its inert state', (
      tester,
    ) async {
      double? seen;
      await tester.pumpWidget(harness(LiveSlider(value: 50, max: 100, onChanged: (value) => seen = value)));
      await tester.pump();

      final slider = find.byType(forui.FSlider);
      expect(slider, findsOneWidget);
      expect(find.byType(TokenSlider), findsNothing);
      expect(tester.widget<forui.FSlider>(slider).enabled, isTrue);

      // The thumb is dragged, not the spec's number, so whatever comes back has to be
      // denormalised out of the library's track percentage into the caller's range.
      await tester.drag(slider, const Offset(40, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(seen, isNotNull, reason: 'the slider reports the value the caller owns');
      expect(seen! > 50 && seen! <= 100, isTrue, reason: 'a rightward drag raises $seen from 50 of 0..100');

      await tester.pumpWidget(harness(const LiveSlider(value: 0.4, onChanged: null)));
      await tester.pump();
      expect(
        tester.widget<forui.FSlider>(find.byType(forui.FSlider)).enabled,
        isFalse,
        reason: 'the spec documents a null callback as disabling the control (§9)',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a segmented track is a group of FButtons with one selected', (tester) async {
      var chosen = -1;
      await tester.pumpWidget(
        harness(LiveSegmented(labels: const ['Small', 'Medium', 'Large'], index: 1, onChanged: (i) => chosen = i)),
      );
      await tester.pump();

      expect(find.byType(forui.FButton), findsNWidgets(3));
      expect(find.byType(TokenSegmented), findsNothing);
      final buttons = tester.widgetList<forui.FButton>(find.byType(forui.FButton)).toList();
      expect(buttons.map((button) => button.selected), [false, true, false]);

      await tester.tap(find.text('Large'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(chosen, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a disabled segmented track keeps its labels and reports nothing', (tester) async {
      var chosen = -1;
      await tester.pumpWidget(
        harness(LiveSegmented(labels: const ['A', 'B'], index: 0, enabled: false, onChanged: (i) => chosen = i)),
      );
      await tester.pump();
      final buttons = tester.widgetList<forui.FButton>(find.byType(forui.FButton)).toList();
      expect(buttons.map((button) => button.onPress), [isNull, isNull]);

      await tester.tap(find.text('B'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(chosen, -1);
    });

    testWidgets('a determinate progress is FDeterminateProgress with the spec height', (tester) async {
      await tester.pumpWidget(harness(const LiveProgress(value: 0.5, height: 12)));
      await tester.pump();

      expect(find.byType(forui.FDeterminateProgress), findsOneWidget);
      expect(find.byType(TokenProgress), findsNothing);
      expect(tester.widget<forui.FDeterminateProgress>(find.byType(forui.FDeterminateProgress)).value, 0.5);
      expect(tester.getSize(find.byType(forui.FDeterminateProgress)).height, 12);
    });

    testWidgets("a null value is the library's own indeterminate FProgress", (tester) async {
      await tester.pumpWidget(harness(const LiveProgress(value: null)));
      await tester.pump();

      expect(find.byType(forui.FProgress), findsOneWidget);
      expect(find.byType(forui.FDeterminateProgress), findsNothing);
      expect(find.byType(TokenProgress), findsNothing);
      // Let the library's own loop stop before the test ends.
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('a select is FSelect and it carries the value and the placeholder', (tester) async {
      // `FSelect` is abstract — the library builds `_BasicSelect` under it — so the
      // finder asks for the type rather than naming a concrete class.
      final select = find.byWidgetPredicate((widget) => widget is forui.FSelect<String>);
      String? chosen;
      await tester.pumpWidget(
        harness(
          LiveSelect<String>(
            items: const ['alpha', 'beta'],
            itemLabel: (item) => item,
            value: 'beta',
            placeholder: 'pick one',
            onChanged: (value) => chosen = value,
          ),
        ),
      );
      await tester.pump();

      expect(select, findsOneWidget);
      expect(find.byType(TokenSelect<String>), findsNothing);
      // The selected value is what the field shows, through the library's own formatter.
      expect(find.text('beta'), findsOneWidget);
      expect(tester.widget<forui.FSelect<String>>(select).hint, 'pick one');

      await tester.pumpWidget(
        harness(LiveSelect<String>(items: const ['alpha'], itemLabel: (i) => i, onChanged: (v) => chosen = v)),
      );
      await tester.pump();
      // No placeholder: the field falls back to the library's own localized hint.
      expect(tester.widget<forui.FSelect<String>>(select).hint, isNull);

      await tester.pumpWidget(
        harness(LiveSelect<String>(items: const ['alpha'], itemLabel: (i) => i, enabled: false, onChanged: (_) {})),
      );
      await tester.pump();
      expect(tester.widget<forui.FSelect<String>>(select).enabled, isFalse);
      expect(chosen, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tab strip is FTabs and reports the tapped index', (tester) async {
      var chosen = -1;
      await tester.pumpWidget(
        harness(
          LiveTabs(
            tabs: const [
              LiveTab(label: 'Rooms'),
              LiveTab(label: 'Shows', icon: Icons.star),
            ],
            index: 0,
            onChanged: (index) => chosen = index,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(forui.FTabs), findsOneWidget);
      expect(find.byType(TokenTabs), findsNothing);
      expect(find.byIcon(Icons.star), findsOneWidget);

      await tester.tap(find.text('Shows'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(chosen, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets("a page frame is FScaffold, and its bars are ForUI's too", (tester) async {
      await tester.pumpWidget(
        harness(
          LiveScaffold(
            appBar: const LiveAppBar(title: 'Rooms', actions: [Icon(Icons.search)]),
            body: const LiveCard(child: Text('body')),
            bottomBar: LiveNavBar(
              items: const [
                LiveNavBarItem(label: 'Home', icon: Icons.home),
                LiveNavBarItem(label: 'Shows', icon: Icons.tv),
              ],
              index: 0,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(forui.FScaffold), findsOneWidget);
      expect(find.byType(TokenScaffold), findsNothing);
      expect(find.byType(TokenAppBar), findsNothing);
      expect(find.byType(TokenNavBar), findsNothing);
      expect(find.text('Rooms'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an app bar keeps its leading, its actions and its bottom strip', (tester) async {
      await tester.pumpWidget(
        harness(
          LiveAppBar(
            title: 'Rooms',
            leading: const Icon(Icons.menu),
            actions: const [Icon(Icons.search), Icon(Icons.more_horiz)],
            background: const Color(0xFF102030),
            bottom: LiveTabs(
              tabs: const [
                LiveTab(label: 'One'),
                LiveTab(label: 'Two'),
              ],
              index: 0,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byWidgetPredicate((widget) => widget is forui.FHeader), findsOneWidget);
      expect(find.byType(TokenAppBar), findsNothing);
      expect(find.byIcon(Icons.menu), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz), findsOneWidget);
      expect(find.byType(forui.FTabs), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a row is FTile with both lines, its divider and its tap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        harness(
          LiveListRow(
            title: 'Room',
            subtitle: '3 watching',
            leading: const Icon(Icons.live_tv),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => taps++,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(forui.FTile), findsOneWidget);
      expect(find.byType(TokenListRow), findsNothing);
      expect(find.text('3 watching'), findsOneWidget);
      expect(
        find.byType(forui.FDivider),
        findsOneWidget,
        reason: "the library's own separator, not an invented hairline",
      );

      await tester.tap(find.text('Room'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(taps, 1);

      await tester.pumpWidget(harness(const LiveListRow(title: 'Room', divided: false)));
      await tester.pump();
      expect(find.byType(forui.FDivider), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a destination strip is FBottomNavigationBar and reports its index', (tester) async {
      var chosen = -1;
      await tester.pumpWidget(
        harness(
          LiveNavBar(
            items: const [
              LiveNavBarItem(label: 'Home', icon: Icons.home),
              LiveNavBarItem(label: 'Shows', icon: Icons.tv),
            ],
            index: 1,
            onChanged: (index) => chosen = index,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(forui.FBottomNavigationBar), findsOneWidget);
      expect(find.byType(forui.FBottomNavigationBarItem), findsNWidgets(2));
      expect(find.byType(TokenNavBar), findsNothing);
      expect(tester.widget<forui.FBottomNavigationBar>(find.byType(forui.FBottomNavigationBar)).index, 1);

      await tester.tap(find.text('Home'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(chosen, 0);

      await tester.pumpWidget(
        harness(
          LiveNavBar(
            items: const [
              LiveNavBarItem(label: 'Home', icon: Icons.home),
              LiveNavBarItem(label: 'Shows', icon: Icons.tv),
            ],
            index: 1,
            enabled: false,
            onChanged: (index) => chosen = index,
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.widget<forui.FBottomNavigationBar>(find.byType(forui.FBottomNavigationBar)).onChange,
        isNull,
        reason: "the library's own inert state, not a swallowed callback",
      );
      expect(chosen, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets("a toast surface is the library's FToast, not the token pill", (tester) async {
      await tester.pumpWidget(harness(const SizedBox.shrink()));
      LiveToast.show(tester.element(find.byType(SizedBox)), 'Saved', type: LiveToastType.success);
      await tester.pump();

      expect(find.byType(forui.FToast), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
      expect(find.byType(TokenToast), findsNothing);
      // The toaster around it (`FToaster`, `showFToast`) is what needs an overlay; the
      // core owns that overlay and the timer, so the surface the adapter returns does not.
      expect(find.byType(forui.FToaster), findsNothing);
    });
  });

  group('dialog and tab view (§9)', () {
    testWidgets("a dialog surface is the library's FDialog, framed by the core", (tester) async {
      await tester.pumpWidget(harness(const SizedBox.shrink()));
      // The route, the barrier, the fade-and-scale and the dismissal are the core's:
      // the test goes through `showLiveDialog`, so what is asserted is only the
      // surface the adapter returns inside that frame.
      unawaited(
        showLiveDialog<void>(
          context: tester.element(find.byType(SizedBox)),
          title: 'Leave the room?',
          child: const Text('Unsaved changes'),
          actions: (_) => [LiveButton(label: 'Stay', onPressed: () {})],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(forui.FDialog), findsOneWidget);
      expect(find.byType(TokenDialog), findsNothing);
      expect(find.text('Leave the room?'), findsOneWidget);
      expect(find.text('Unsaved changes'), findsOneWidget);
      // The action is the caller's already-dispatched control, so it arrives as the
      // library's button rather than being re-picked by the frame.
      expect(find.byType(forui.FButton), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('a page switcher is the widgets-layer PageView over the caller pages', (tester) async {
      // No `Live*` widget drives this one: the contract's tab view is dispatched
      // straight from the adapter, which is how a page under a strip uses it (§9).
      Widget view(int index) => harness(
        Builder(
          builder: (context) => SizedBox(
            height: 200,
            child: LiveTheme.of(context).adapter.tabView(
              context,
              LanguageTabViewSpec(
                pages: [
                  const Center(child: Text('first page')),
                  const Center(child: Text('second page')),
                ],
                index: index,
                onIndexChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(view(0));
      await tester.pumpAndSettle();

      expect(find.byType(TokenTabView), findsNothing);
      expect(
        find.byType(forui.FTabs),
        findsNothing,
        reason: "the library's only page switcher is its tabs, which pair a strip with its own panels (§9)",
      );
      expect(find.text('first page'), findsOneWidget);

      await tester.pumpWidget(view(1));
      await tester.pumpAndSettle();
      expect(find.text('second page'), findsOneWidget, reason: 'the view follows the index the caller holds');
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('no token renderer inside a ForUI frame (§15.3)', () {
    testWidgets('every control of the contract dispatches native', (tester) async {
      await tester.pumpWidget(
        harness(
          Column(
            children: [
              LiveSlider(value: 0.4, onChanged: (_) {}),
              LiveSegmented(labels: const ['A', 'B'], index: 0, onChanged: (_) {}),
              const LiveProgress(value: 0.5),
              LiveSelect<String>(items: const ['x'], itemLabel: (item) => item, onChanged: (_) {}),
              LiveTabs(
                tabs: const [
                  LiveTab(label: 'One'),
                  LiveTab(label: 'Two'),
                ],
                index: 0,
                onChanged: (_) {},
              ),
              LiveListRow(title: 'Room', onTap: () {}),
              LiveNavBar(
                items: const [LiveNavBarItem(label: 'Home', icon: Icons.home)],
                index: 0,
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      // ForUI declares all seventeen controls, so nothing in a ForUI page should be a
      // `Token*` renderer any more — the assertion is by name rather than by list so a
      // control added to the contract cannot slip in silently.
      expect(find.byWidgetPredicate((widget) => widget.runtimeType.toString().startsWith('Token')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('the app host (§ surfaces)', () {
    // No outer `MaterialApp` here: the host under test *is* the app widget, and
    // pumping it inside the SDK one would pass while no real page looks like
    // that — and it is the SDK host the token base would fall back to.
    Widget hostHarness(Widget child) => LiveConfigProvider(
      config: config,
      registry: const LanguageRegistry(
        adapters: {LiveDesignLanguage.forui: foruiAdapter},
        fallback: SharedLanguageAdapter(),
      ),
      child: child,
    );

    testWidgets('the tree is hosted by WidgetsApp under the library theme, not by the token host', (tester) async {
      await tester.pumpWidget(
        hostHarness(
          LiveApp(
            routerConfig: stubRouterConfig(child: const Text('page')),
            localizationsDelegates: const [...liveLocalizationsDelegates, ...foruiLocalizationsDelegates],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WidgetsApp), findsOneWidget);
      expect(find.byType(MaterialApp), findsNothing, reason: 'the token Material host must not stand in');
      expect(find.byType(forui.FTheme), findsWidgets);
      expect(find.text('page'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the app shell (§ surfaces)', () {
    const shellDestinations = [
      LiveShellDestination(id: 'home', label: 'Home', icon: Icons.home),
      LiveShellDestination(id: 'follow', label: 'Follow', icon: Icons.favorite),
      LiveShellDestination(id: 'archive', label: 'Archive', icon: Icons.archive, enabled: false),
    ];

    testWidgets("the rail draws the library's own FSidebar, not the token column", (tester) async {
      var chosen = '';
      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 720,
            height: 480,
            child: LiveAppShell(
              destinations: shellDestinations,
              selectedId: 'home',
              onSelected: (id) => chosen = id,
              trailing: const Text('settings footer'),
              placement: LiveShellPlacement.rail,
              child: const Text('room list'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(forui.FSidebar), findsOneWidget);
      expect(find.byType(TokenAppShell), findsNothing);
      // The sidebar paints only the column: the body the shell was handed is
      // what shows, beside it.
      expect(find.text('room list'), findsOneWidget);
      // `trailing` has a real slot here — the sidebar's sticky footer.
      expect(find.text('settings footer'), findsOneWidget);

      await tester.tap(find.text('Follow'));
      await tester.pump();
      expect(chosen, 'follow');

      // A disabled destination stays visible so the column does not shift, but
      // the shell refuses it: `FSidebarItem` has no disabled state to map onto,
      // so the item is simply inert and the id never arrives.
      await tester.tap(find.text('Archive'));
      await tester.pump();
      expect(chosen, 'follow');

      expect(tester.takeException(), isNull);

      // Unmount before teardown and let the library's pending timers lapse:
      // the tappable inside a sidebar item arms a press timer that outlives its
      // subtree by a moment, which the test binding counts as a leak. In a real
      // window that timer is the gesture recognizer settling.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets("a bottom request delegates to the library's own strip, and drops trailing", (tester) async {
      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 420,
            height: 640,
            child: LiveAppShell(
              destinations: const [
                LiveShellDestination(id: 'home', label: 'Home', icon: Icons.home),
                LiveShellDestination(id: 'follow', label: 'Follow', icon: Icons.favorite),
              ],
              selectedId: 'home',
              onSelected: (_) {},
              trailing: const Text('settings footer'),
              placement: LiveShellPlacement.bottom,
              child: const Text('room list'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(forui.FBottomNavigationBar), findsOneWidget);
      expect(find.byType(forui.FSidebar), findsNothing);
      expect(find.byType(TokenAppShell), findsNothing);
      expect(find.text('room list'), findsOneWidget);
      // The strip has no trailing slot; the form drops it rather than inventing
      // a place for it — the same rule the token shell states.
      expect(find.text('settings footer'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets("none is the page's own frame: the shell stands aside", (tester) async {
      await tester.pumpWidget(
        harness(
          LiveAppShell(
            destinations: shellDestinations,
            selectedId: 'home',
            onSelected: (_) {},
            placement: LiveShellPlacement.none,
            child: const Text('room list'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('room list'), findsOneWidget);
      expect(find.byType(forui.FSidebar), findsNothing);
      expect(find.byType(forui.FBottomNavigationBar), findsNothing);
      expect(find.byType(TokenAppShell), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

EdgeInsetsGeometry _cardPadding(WidgetTester tester) =>
    tester.widget<Padding>(find.descendant(of: find.byType(forui.FCard), matching: find.byType(Padding))).padding;
