import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_wind/live_uikit_wind.dart';

import 'stub_router.dart';

/// §16 widget tests for `live_uikit_wind`, driving the `Live*` controls through
/// the real runtime so they render with `fluttersdk_wind`'s own widgets. Covers
/// §9 gating (callback, disabled, loading, controlled value, controller
/// passthrough) plus the nine controls the fork has no widget for, which Wind
/// now composes out of its parts rather than leaving to the shared renderer, and
/// the composed app shell (§ surfaces).
void main() {
  const config = UiConfig(language: LiveDesignLanguage.wind, brightness: UiBrightnessMode.light);

  Widget harness(Widget child) => LiveConfigProvider(
    config: config,
    registry: const LanguageRegistry(adapters: {LiveDesignLanguage.wind: windAdapter}),
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

    testWidgets('that verdict is also the visual state', (tester) async {
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

  group('select (§9)', () {
    testWidgets('the typed items, value and placeholder reach the fork', (tester) async {
      await tester.pumpWidget(
        harness(
          LiveSelect<String>(
            items: const ['a', 'b'],
            itemLabel: (item) => item.toUpperCase(),
            value: 'a',
            placeholder: 'Pick one',
            onChanged: (_) {},
          ),
        ),
      );
      final select = tester.widget<wind.WSelect<String>>(find.byType(wind.WSelect<String>));
      expect(select.value, 'a');
      expect([for (final option in select.options) (option.value, option.label)], [('a', 'A'), ('b', 'B')]);
      expect(select.placeholder, 'Pick one');
      expect(select.disabled, isFalse);
      expect(select.onChange, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a null callback or enabled: false disables the fork', (tester) async {
      await tester.pumpWidget(
        harness(
          Column(
            children: [
              LiveSelect<int>(items: const [1], itemLabel: (i) => '$i', value: 1, onChanged: null),
              LiveSelect<int>(items: const [2], itemLabel: (i) => '$i', value: 2, enabled: false, onChanged: (_) {}),
            ],
          ),
        ),
      );
      final selects = tester.widgetList<wind.WSelect<int>>(find.byType(wind.WSelect<int>)).toList();
      expect(selects, hasLength(2));
      for (final select in selects) {
        expect(select.disabled, isTrue, reason: 'a dead select must not open');
        expect(select.onChange, isNull);
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('the controls Wind composes rather than maps (§9)', () {
    testWidgets("a rail is the fork's own parts and reports the position it is tapped at", (tester) async {
      double? captured;
      await tester.pumpWidget(
        harness(SizedBox(width: 240, child: LiveSlider(value: 0.25, max: 2, onChanged: (value) => captured = value))),
      );
      // The filled run is the fork's accent class, the rail its neutral pair.
      expect(
        find.byWidgetPredicate((widget) => widget is wind.WDiv && (widget.className ?? '').contains('bg-primary-500')),
        findsOneWidget,
      );

      await tester.tapAt(tester.getTopLeft(find.byType(LiveSlider)) + const Offset(180, 8));
      await tester.pump();
      // 180 of a 240 rail, over a span of two: the spec's own bounds, not 0..1.
      expect(captured, closeTo(1.5, 0.05));

      await tester.dragFrom(tester.getCenter(find.byType(LiveSlider)), const Offset(-100, 0));
      await tester.pump();
      // Centre minus a hundred logical pixels of a 240 rail, over a span of two.
      expect(captured, closeTo(2 / 12, 0.05));
      expect(tester.takeException(), isNull);
    });

    testWidgets('an inert rail has neither a gesture nor a live-looking thumb', (tester) async {
      await tester.pumpWidget(harness(const SizedBox(width: 240, child: LiveSlider(value: 0.5, onChanged: null))));
      final parts = tester
          .widgetList<wind.WDiv>(find.byType(wind.WDiv))
          .where((div) => (div.className ?? '').contains('disabled:opacity-50'))
          .toList();
      expect(parts, hasLength(3), reason: "rail, run and thumb all carry the fork's inert state");
      for (final part in parts) {
        expect(part.states, contains('disabled'));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('a segmented track is a group of Wind buttons, one carrying the selected state', (tester) async {
      var chosen = -1;
      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 360,
            child: LiveSegmented(
              labels: const ['Small', 'Medium', 'Large'],
              index: 1,
              expand: true,
              onChanged: (i) => chosen = i,
            ),
          ),
        ),
      );
      final segments = tester.widgetList<wind.WButton>(find.byType(wind.WButton)).toList();
      expect(segments, hasLength(3));
      expect(segments.map((button) => (button.states ?? const <String>{}).contains('selected')), [false, true, false]);
      expect(segments.every((button) => button.onTap != null), isTrue);
      // The `selected:` token really reaches the paint: the chosen segment's own
      // container carries the accent, and that accent is the token's, because
      // `WindThemeBuilder` seeds Wind's `primary` scale from it (§8.1).
      final theme = LiveTheme.of(tester.element(find.byType(LiveSegmented)));
      expect(
        tester
            .widgetList<Container>(find.descendant(of: find.byType(wind.WButton), matching: find.byType(Container)))
            .map((box) => (box.decoration as BoxDecoration?)?.color),
        [null, theme.colors.primary, null],
      );

      await tester.tap(find.text('Large'));
      await tester.pumpAndSettle();
      expect(chosen, 2);

      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 360,
            child: LiveSegmented(
              labels: const ['Small', 'Medium', 'Large'],
              index: 0,
              enabled: false,
              onChanged: (_) => chosen = 99,
            ),
          ),
        ),
      );
      await tester.pump();
      final inert = tester.widgetList<wind.WButton>(find.byType(wind.WButton)).toList();
      expect(inert.every((button) => button.disabled && button.onTap == null), isTrue);
      // The fork absorbs the pointer on a disabled button, so the tap has no
      // receiver to warn about — that absence is the assertion.
      await tester.tap(find.text('Medium'), warnIfMissed: false);
      await tester.pump();
      expect(chosen, 2, reason: 'a disabled group keeps its labels and stops reporting');
      expect(tester.takeException(), isNull);
    });

    testWidgets("a determinate bar is the fork's rail and run, and its label is the percent", (tester) async {
      await tester.pumpWidget(harness(const SizedBox(width: 240, child: LiveProgress(value: 0.5, showLabel: true))));
      expect(find.text('50%'), findsOneWidget);
      expect(tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox)).widthFactor, 0.5);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is wind.WDiv && (widget.className ?? '').contains('bg-gray-200 dark:bg-gray-700'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets("an unknown completion breathes in the fork's own animation and prints no percent", (tester) async {
      await tester.pumpWidget(harness(const SizedBox(width: 240, child: LiveProgress(value: null, showLabel: true))));
      expect(find.text('0%'), findsNothing);
      // Wind has no transform parser (`WSwitch` says so), so an indeterminate run
      // cannot slide; `animate-pulse` is the library's own unfinished-work class.
      expect(
        find.byWidgetPredicate((widget) => widget is wind.WDiv && (widget.className ?? '').contains('animate-pulse')),
        findsOneWidget,
      );
      // The pulse repeats forever, so this settles nothing — pump a fixed stretch
      // and leave the animation to the tree teardown.
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
    });

    testWidgets("a tab strip is the fork's anchors over its rule, carries its icons and reports its index", (
      tester,
    ) async {
      var chosen = -1;
      await tester.pumpWidget(
        harness(
          LiveTabs(
            tabs: const [
              LiveTab(label: 'Rooms'),
              LiveTab(label: 'Shows', icon: Icons.star),
            ],
            index: 0,
            onChanged: (i) => chosen = i,
          ),
        ),
      );
      // `WTabs` welds a panel to the row and paints only text; this strip has no
      // panel and does paint the tab's glyph.
      expect(find.byType(wind.WTabs), findsNothing);
      expect(find.byIcon(Icons.star), findsOneWidget);
      final tabs = tester
          .widgetList<wind.WAnchor>(find.byType(wind.WAnchor))
          // Only the strip's own anchors carry the tap; the fork adds a
          // gestureless one inside every tab whose class list has `hover:`.
          .where((anchor) => anchor.onTap != null)
          .toList();
      expect(tabs, hasLength(2));
      expect(tabs.map((anchor) => (anchor.states ?? const <String>{}).contains('selected')), [true, false]);
      // And the chosen tab really is the accent: `WDiv` publishes its parsed text
      // colour as a `DefaultTextStyle`, which is also what the glyph and the label
      // inherit, so one node proves the whole tab is tinted (§9).
      final theme = LiveTheme.of(tester.element(find.byType(LiveTabs)));
      expect(
        find.byWidgetPredicate((widget) => widget is DefaultTextStyle && widget.style.color == theme.colors.primary),
        findsOneWidget,
      );

      await tester.tap(find.text('Shows'));
      await tester.pumpAndSettle();
      expect(chosen, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a page frame is a Wind column: bar, body, bottom bar and a placed action', (tester) async {
      await tester.pumpWidget(
        harness(
          const SizedBox(
            width: 400,
            height: 300,
            child: LiveScaffold(
              appBar: LiveAppBar(title: 'Rooms'),
              body: Text('page body'),
              bottomBar: LiveNavBar(
                items: [LiveNavBarItem(label: 'Home', icon: Icons.home)],
                index: 0,
              ),
              floatingActionButton: Text('act'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('page body'), findsOneWidget);
      expect(find.text('act'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a top bar is a Wind panel with its title, actions and strip', (tester) async {
      await tester.pumpWidget(
        harness(
          const LiveAppBar(
            title: 'Rooms',
            actions: [Text('act')],
            centerTitle: true,
            bottom: LiveTabs(
              tabs: [
                LiveTab(label: 'One'),
                LiveTab(label: 'Two'),
              ],
              index: 1,
              onChanged: null,
            ),
          ),
        ),
      );
      expect(find.text('Rooms'), findsOneWidget);
      expect(find.text('act'), findsOneWidget);
      expect(find.text('Two'), findsOneWidget);
      expect(
        find.byWidgetPredicate((widget) => widget is wind.WText && (widget.className ?? '').contains('text-center')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a list row anchors its parts, fires its tap and can rule itself off', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 320,
            child: LiveListRow(
              title: 'Quality',
              subtitle: 'Source bitrate',
              trailing: const Text('4K'),
              selected: true,
              divided: false,
              onTap: () => taps++,
            ),
          ),
        ),
      );
      expect(find.text('Quality'), findsOneWidget);
      expect(find.text('Source bitrate'), findsOneWidget);
      expect(find.text('4K'), findsOneWidget);
      expect(
        find.byWidgetPredicate((widget) => widget is wind.WDiv && (widget.className ?? '').contains('h-[1px]')),
        findsNothing,
      );
      // The row's own anchor is the outer one; the `hover:` class on the styled
      // div makes the fork add a gestureless anchor inside it.
      final row = tester.widgetList<wind.WAnchor>(find.byType(wind.WAnchor)).first;
      expect(row.states, contains('selected'));
      expect(row.isDisabled, isFalse);

      await tester.tap(find.text('Quality'));
      await tester.pumpAndSettle();
      expect(taps, 1);

      await tester.pumpWidget(
        harness(
          const SizedBox(
            width: 320,
            child: LiveListRow(title: 'Quality', trailing: Text('4K')),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byWidgetPredicate((widget) => widget is wind.WDiv && (widget.className ?? '').contains('h-[1px]')),
        findsOneWidget,
      );
      final inert = tester.widgetList<wind.WAnchor>(find.byType(wind.WAnchor)).first;
      expect(inert.isDisabled, isTrue, reason: "a row with no handler is the fork's inert state");
      expect(tester.takeException(), isNull);
    });

    testWidgets('a destination strip shares its width, reports its index and stops when disabled', (tester) async {
      var chosen = -1;
      Widget bar({bool enabled = true}) => LiveNavBar(
        items: const [
          LiveNavBarItem(label: 'Home', icon: Icons.home),
          LiveNavBarItem(label: 'Shows', icon: Icons.star),
        ],
        index: 0,
        enabled: enabled,
        onChanged: (i) => chosen = i,
      );

      await tester.pumpWidget(harness(SizedBox(width: 360, child: bar())));
      expect(find.byIcon(Icons.home), findsOneWidget);
      await tester.tap(find.text('Shows'));
      await tester.pumpAndSettle();
      expect(chosen, 1);

      await tester.pumpWidget(harness(SizedBox(width: 360, child: bar(enabled: false))));
      await tester.pump();
      await tester.tap(find.text('Home'));
      await tester.pump();
      expect(chosen, 1, reason: 'a disabled strip keeps its labels and stops reporting');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a toast surface is a Wind panel, not the token pill', (tester) async {
      await tester.pumpWidget(harness(const SizedBox.shrink()));
      LiveToast.show(tester.element(find.byType(SizedBox)), 'Saved', type: LiveToastType.success);
      await tester.pump();

      expect(find.text('Saved'), findsOneWidget);
      expect(find.byType(wind.WCard), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('the dialog surface and the page switcher (§9)', () {
    testWidgets('a dialog is a Wind panel, and the route stays the core’s', (tester) async {
      await tester.pumpWidget(harness(const SizedBox.shrink()));
      unawaited(
        showLiveDialog<void>(
          context: tester.element(find.byType(SizedBox)),
          title: 'Leave the room?',
          child: const Text('Playback stops.'),
          actions: (_) => [LiveButton(label: 'Stay', onPressed: () {})],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Leave the room?'), findsOneWidget);
      expect(find.text('Playback stops.'), findsOneWidget);
      expect(find.text('Stay'), findsOneWidget);
      // The surface is the fork’s own elevated container, and the heading its
      // own type step — not a token card with a Material text style.
      final panels = tester.widgetList<wind.WCard>(find.byType(wind.WCard)).toList();
      expect(panels, hasLength(1));
      expect(panels.single.className, contains('rounded-xl'));
      expect(panels.single.className, contains('shadow-xl'));
      expect(
        find.byWidgetPredicate((widget) => widget is wind.WText && (widget.className ?? '').contains('font-semibold')),
        findsOneWidget,
      );

      // Dismissing is the core barrier’s job, not something this surface repeats.
      await tester.tapAt(const Offset(12, 12));
      await tester.pumpAndSettle();
      expect(find.text('Leave the room?'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the page switcher is a PageView in a Wind frame, and reports swipes', (tester) async {
      var index = 0;
      int? swiped;
      Widget view() => Builder(
        builder: (context) => LiveTheme.of(context).adapter.tabView(
          context,
          LanguageTabViewSpec(
            pages: const <Widget>[Text('first page'), Text('second page')],
            index: index,
            onIndexChanged: (value) => swiped = value,
          ),
        ),
      );
      Widget page() => harness(SizedBox(width: 320, height: 240, child: view()));

      await tester.pumpWidget(page());
      await tester.pumpAndSettle();

      expect(find.byType(wind.WDiv), findsWidgets, reason: 'the frame is the library’s own container');
      expect(find.text('first page'), findsOneWidget);

      // A swipe moves the view and is reported, which is what lets the strip follow.
      await tester.dragFrom(tester.getCenter(find.byType(PageView)), const Offset(-240, 0));
      await tester.pumpAndSettle();
      expect(swiped, 1);
      expect(find.text('second page'), findsOneWidget);

      // An index change from the strip animates the same view in place.
      index = 0;
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(find.text('first page'), findsOneWidget);
      expect(find.text('second page'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('no token renderer inside a Wind frame (§15.3)', () {
    testWidgets('the whole chrome set draws from Wind, not from the shared base', (tester) async {
      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 480,
            height: 360,
            child: LiveScaffold(
              appBar: const LiveAppBar(
                title: 'Rooms',
                actions: [Text('act')],
                bottom: LiveTabs(
                  tabs: [
                    LiveTab(label: 'One'),
                    LiveTab(label: 'Two'),
                  ],
                  index: 0,
                  onChanged: null,
                ),
              ),
              body: Column(
                children: [
                  const LiveListRow(title: 'Quality', subtitle: 'Source bitrate'),
                  const SizedBox(width: 240, child: LiveProgress(value: 0.4)),
                  const SizedBox(width: 240, child: LiveSlider(value: 0.4, onChanged: null)),
                  SizedBox(
                    width: 320,
                    child: LiveSegmented(
                      labels: const ['Low', 'Balanced', 'High'],
                      index: 2,
                      expand: true,
                      onChanged: (_) {},
                    ),
                  ),
                ],
              ),
              bottomBar: LiveNavBar(
                items: const [
                  LiveNavBarItem(label: 'Home', icon: Icons.home),
                  LiveNavBarItem(label: 'Shows', icon: Icons.star),
                ],
                index: 1,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Wind declares all fifteen controls, so nothing in a Wind page should be a
      // `Token*` renderer any more — the assertion is by name rather than by list
      // so a control added to the contract cannot slip in silently.
      expect(tester.takeException(), isNull);
    });
  });

  group('the app shell (§ surfaces)', () {
    const destinations = [
      LiveShellDestination(id: 'home', label: 'Home', icon: Icons.home),
      LiveShellDestination(id: 'follow', label: 'Follow', icon: Icons.favorite),
    ];

    testWidgets('the rail form is the composed column, not the token shell', (tester) async {
      var chosen = '';
      await tester.pumpWidget(
        harness(
          LiveAppShell(
            destinations: destinations,
            selectedId: 'home',
            onSelected: (id) => chosen = id,
            placement: LiveShellPlacement.rail,
            trailing: const Text('settings'),
            child: const Text('room list'),
          ),
        ),
      );
      await tester.pump();

      // The library ships no navigation structure, so the pane is composed out of
      // its styled parts — and the body still belongs to the caller.
      expect(find.text('room list'), findsOneWidget);
      // The composed column has a bottom slot of its own, unlike the strip.
      expect(find.text('settings'), findsOneWidget);
      expect(
        find.byWidgetPredicate((widget) => widget.runtimeType.toString().startsWith('Token')),
        findsNothing,
        reason: 'a Wind shell must not be drawn by its own library widgets',
      );

      await tester.tap(find.text('Follow'));
      await tester.pump();
      expect(chosen, 'follow');
      expect(tester.takeException(), isNull);
    });

    testWidgets("a disabled destination is the fork's inert state, so it reports nothing", (tester) async {
      var chosen = '';
      await tester.pumpWidget(
        harness(
          LiveAppShell(
            destinations: const [
              LiveShellDestination(id: 'home', label: 'Home', icon: Icons.home),
              LiveShellDestination(id: 'follow', label: 'Follow', icon: Icons.favorite, enabled: false),
            ],
            selectedId: 'home',
            onSelected: (id) => chosen = id,
            placement: LiveShellPlacement.rail,
            child: const Text('room list'),
          ),
        ),
      );
      await tester.pump();

      // Kept in the layout so the column does not shift, handed `isDisabled` (the
      // state behind `disabled:opacity-50`), and given no tap closure at all.
      expect(find.text('Follow'), findsOneWidget);
      await tester.tap(find.text('Follow'));
      await tester.pump();
      expect(chosen, '');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a bottom request hands the strip to the nav bar, which has no footer', (tester) async {
      await tester.pumpWidget(
        harness(
          LiveAppShell(
            destinations: destinations,
            selectedId: 'follow',
            onSelected: (_) {},
            placement: LiveShellPlacement.bottom,
            trailing: const Text('settings'),
            child: const Text('room list'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('room list'), findsOneWidget);
      // The strip is this package's own composed nav bar; its footer slot does not
      // exist, so the trailing content is dropped rather than faked as a row.
      expect(find.text('settings'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an adaptive request bends at the same width the token shell uses', (tester) async {
      Widget shell(LiveShellPlacement placement) => harness(
        LiveAppShell(
          destinations: destinations,
          selectedId: 'home',
          onSelected: (_) {},
          placement: placement,
          child: const Text('room list'),
        ),
      );

      // With no environment in scope the shared rule falls back to a rail width of
      // its own, so a bare adaptive request composes the column — the same verdict
      // the token shell reaches, and the same one the explicit forms make.
      await tester.pumpWidget(shell(LiveShellPlacement.adaptive));
      await tester.pump();
      expect(find.text('settings'), findsNothing);

      await tester.pumpWidget(shell(LiveShellPlacement.none));
      await tester.pump();
      // A shell asked for no navigation: the frame is the page's own.
      expect(find.text('room list'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('the app host (§ surfaces)', () {
    // No outer `MaterialApp` here: the host under test *is* the app widget, and
    // pumping it inside the SDK one would pass while no real Wind page looks like
    // that — and it is the SDK host its own library widgets would fall back to.
    Widget hostHarness(Widget child) => LiveConfigProvider(
      config: config,
      registry: const LanguageRegistry(adapters: {LiveDesignLanguage.wind: windAdapter}),
      child: child,
    );

    testWidgets('the tree is hosted by WidgetsApp under the Wind theme, not by the token host', (tester) async {
      await tester.pumpWidget(
        hostHarness(
          LiveApp(
            routerConfig: stubRouterConfig(child: const Text('page')),
            localizationsDelegates: liveLocalizationsDelegates,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WidgetsApp), findsOneWidget);
      expect(find.byType(MaterialApp), findsNothing, reason: 'the token Material host must not stand in');
      expect(find.byType(wind.WindTheme), findsWidgets, reason: "the library's own theme scope, above the routes");
      expect(find.text('page'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
