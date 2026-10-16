import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_fluent/live_uikit_fluent.dart';

import 'stub_router.dart';

/// §16 widget tests for `live_uikit_fluent`, driving the `Live*` controls through
/// the real runtime so they dispatch to the native `fluent_ui` widgets rather
/// than the shared token renderer. Covers §9 gating (callback, disabled, loading,
/// controlled value, controller passthrough) plus the chrome set, which Fluent now renders in full.
void main() {
  const config = UiConfig(language: LiveDesignLanguage.fluent, brightness: UiBrightnessMode.light);

  Widget harness(Widget child) => LiveConfigProvider(
    config: config,
    registry: const LanguageRegistry(
      adapters: {LiveDesignLanguage.fluent: fluentAdapter},
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

  group('chrome (§9)', () {
    testWidgets('the page frame resolves through fluent.ScaffoldPage', (tester) async {
      await tester.pumpWidget(
        harness(
          LiveScaffold(
            appBar: const LiveAppBar(title: 'Rooms'),
            body: const Text('content'),
            bottomBar: LiveNavBar(
              items: const [LiveNavBarItem(label: 'Home', icon: Icons.home)],
              index: 0,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(fluent.ScaffoldPage), findsOneWidget);
      expect(find.text('content'), findsOneWidget);
      // Both chrome controls are Fluent's own now: the header is a `PageHeader`
      // and the bottom strip a row of `ToggleButton`s, so nothing inside a
      // Fluent frame draws from the token base any more.
      expect(find.byType(fluent.PageHeader), findsOneWidget);
      expect(find.text('Rooms'), findsOneWidget);
      expect(find.byType(TokenNavBar), findsNothing);
      expect(find.byType(TokenAppBar), findsNothing);
    });

    testWidgets('a row resolves through fluent.ListTile with both lines and its tap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        harness(LiveListRow(title: 'Accent', subtitle: 'violet', selected: true, onTap: () => taps++)),
      );

      expect(find.byType(fluent.ListTile), findsOneWidget);
      expect(find.text('Accent'), findsOneWidget);
      expect(find.text('violet'), findsOneWidget);

      await tester.tap(find.byType(fluent.ListTile));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(taps, 1);
    });

    testWidgets('a toast surface is the Fluent InfoBar, not the token pill', (tester) async {
      await tester.pumpWidget(harness(const SizedBox.shrink()));
      LiveToast.show(tester.element(find.byType(SizedBox)), 'Saved', type: LiveToastType.success);
      await tester.pump();

      expect(find.byType(fluent.InfoBar), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
      expect(find.byType(TokenToast), findsNothing);
    });
  });

  group('dialog and tab view (§9)', () {
    testWidgets('the dialog surface is the library ContentDialog, not the token card', (tester) async {
      await tester.pumpWidget(harness(const SizedBox.shrink()));
      late BuildContext routeContext;
      final result = showLiveDialog<void>(
        context: tester.element(find.byType(SizedBox)),
        title: 'Confirm',
        child: Builder(
          builder: (context) {
            routeContext = context;
            return const Text('Discard the draft?');
          },
        ),
        actions: [LiveButton(label: 'Keep', onPressed: () {})],
      );
      await tester.pumpAndSettle();

      // The library widget is the whole surface; the route, the barrier and the
      // fade-and-scale stay the core's — showLiveDialog frames it.
      expect(find.byType(fluent.ContentDialog), findsOneWidget);
      expect(find.byType(TokenDialog), findsNothing);
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Discard the draft?'), findsOneWidget);
      expect(find.text('Keep'), findsOneWidget);
      expect(tester.takeException(), isNull);

      Navigator.of(routeContext).pop();
      await tester.pumpAndSettle();
      await result;
    });

    testWidgets('the tab view replaces the page in place, never the token pager', (tester) async {
      Widget view(int index) => Builder(
        builder: (context) => LiveTheme.of(context).adapter.tabView(
          context,
          LanguageTabViewSpec(
            pages: const [Text('Rooms'), Text('Shows')],
            index: index,
            onIndexChanged: (_) {},
          ),
        ),
      );

      await tester.pumpWidget(harness(view(0)));
      await tester.pumpAndSettle();
      expect(find.byType(TokenTabView), findsNothing);
      expect(find.text('Rooms'), findsOneWidget);
      expect(find.text('Shows'), findsNothing);

      // Windows semantics: the second pump replaces the body in place; a Fluent
      // view has no slide and the strip keeps owning the index.
      await tester.pumpWidget(harness(view(1)));
      await tester.pumpAndSettle();
      expect(find.text('Shows'), findsOneWidget);
      expect(find.text('Rooms'), findsNothing);
      expect(find.byType(TokenTabView), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('the app host (§9)', () {
    // No outer `MaterialApp` in these: an app widget inside another app widget is
    // not a shape any real page has, and Material's localizations would stand in
    // for Fluent's and hide the point.
    Widget hostHarness(Widget child) => LiveConfigProvider(
      config: config,
      registry: const LanguageRegistry(
        adapters: {LiveDesignLanguage.fluent: fluentAdapter},
        fallback: SharedLanguageAdapter(),
      ),
      child: child,
    );

    LiveApp hosted(Widget route) => LiveApp(
      routerConfig: stubRouterConfig(child: route),
      localizationsDelegates: liveLocalizationsDelegates,
    );

    testWidgets('the tree is hosted by FluentApp, not by Material', (tester) async {
      await tester.pumpWidget(hostHarness(hosted(const Text('page'))));
      await tester.pumpAndSettle();

      expect(find.byType(fluent.FluentApp), findsOneWidget);
      expect(find.byType(MaterialApp), findsNothing);
      expect(find.byType(TokenApp), findsNothing);
      expect(find.text('page'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a control the language does not claim still works under the Fluent host', (tester) async {
      // The host no longer installs Material, so this is the check that the shared
      // renderers do not lean on it: a card needs an ink host and a field needs
      // selection-toolbar localizations, and neither may require `MaterialApp`.
      await tester.pumpWidget(
        hostHarness(
          hosted(
            Column(
              children: [
                const LiveCard(child: Text('card')),
                LiveTextField(placeholder: 'name', onChanged: (_) {}),
                InkWell(onTap: () {}, child: const Text('ink')),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(fluent.FluentApp), findsOneWidget);
      expect(find.text('card'), findsOneWidget);
      await tester.tap(find.text('ink'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('the controls Fluent composes rather than maps (§9)', () {
    testWidgets('a segmented track is a group of ToggleButtons, one checked', (tester) async {
      var chosen = -1;
      await tester.pumpWidget(
        harness(LiveSegmented(labels: const ['Small', 'Medium', 'Large'], index: 1, onChanged: (i) => chosen = i)),
      );
      await tester.pump();

      expect(find.byType(fluent.ToggleButton), findsNWidgets(3));
      expect(find.byType(TokenSegmented), findsNothing);
      final buttons = tester.widgetList<fluent.ToggleButton>(find.byType(fluent.ToggleButton)).toList();
      expect(buttons.map((button) => button.checked), [false, true, false]);

      await tester.tap(find.text('Large'));
      // Fluent's HoverButton keeps a 100ms press timer alive after a
      // tap; settle it or the binding reports a leak.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(chosen, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tab strip reports its index and never draws the token tabs', (tester) async {
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
      await tester.pump();

      expect(find.byType(TokenTabs), findsNothing);
      expect(find.byIcon(Icons.star), findsOneWidget);
      await tester.tap(find.text('Shows'));
      // Fluent's HoverButton keeps a 100ms press timer alive after a
      // tap; settle it or the binding reports a leak.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(chosen, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a destination strip reports its index, and a disabled one reports nothing', (tester) async {
      var chosen = -1;
      await tester.pumpWidget(
        harness(
          LiveNavBar(
            items: const [
              LiveNavBarItem(label: 'Home', icon: Icons.home),
              LiveNavBarItem(label: 'Follow', icon: Icons.favorite),
            ],
            index: 0,
            onChanged: (i) => chosen = i,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(TokenNavBar), findsNothing);
      await tester.tap(find.text('Follow'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(chosen, 1);

      await tester.pumpWidget(
        harness(
          LiveNavBar(
            items: const [
              LiveNavBarItem(label: 'Home', icon: Icons.home),
              LiveNavBarItem(label: 'Follow', icon: Icons.favorite),
            ],
            index: 0,
            enabled: false,
            onChanged: (i) => chosen = i,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Follow'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(chosen, 1, reason: 'a disabled strip keeps its labels and stops reporting');
      expect(tester.takeException(), isNull);
    });
  });

  group('the app shell (§ surfaces)', () {
    const destinations = [
      LiveShellDestination(id: 'home', label: 'Home', icon: fluent.FluentIcons.home),
      LiveShellDestination(id: 'follow', label: 'Follow', icon: fluent.FluentIcons.heart),
    ];

    testWidgets('the shell draws NavigationView, not the token column', (tester) async {
      var chosen = '';
      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 720,
            height: 480,
            child: LiveAppShell(
              destinations: destinations,
              selectedId: 'home',
              onSelected: (id) => chosen = id,
              // A rail: the pane is vertical, and the test follows a destination by
              // its glyph because the compact pane hides the label text.
              placement: LiveShellPlacement.rail,
              child: const Text('room list'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(fluent.NavigationView), findsOneWidget);
      expect(find.byType(TokenAppShell), findsNothing);
      // The router owns the body: the pane's own per-item bodies are not what is
      // on screen, so the page the shell was handed is what shows.
      expect(find.text('room list'), findsOneWidget);
      expect(find.byIcon(fluent.FluentIcons.heart), findsOneWidget);

      await tester.tap(find.byIcon(fluent.FluentIcons.heart));
      await tester.pump();
      expect(chosen, 'follow');
      expect(tester.takeException(), isNull);

      // Unmount before teardown: the pane runs a display-mode transition timer
      // that outlives its subtree, which the test binding counts as a leak. In a
      // real window that timer is the pane settling into its mode.
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('a bottom request takes the top pane, the horizontal navigation Fluent has', (tester) async {
      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 720,
            height: 480,
            child: LiveAppShell(
              destinations: destinations,
              selectedId: 'home',
              onSelected: (_) {},
              placement: LiveShellPlacement.bottom,
              child: const Text('room list'),
            ),
          ),
        ),
      );
      await tester.pump();

      // `NavigationPane` is the view's configuration object, not a widget, so the
      // mode is read back off the view.
      final view = tester.widget<fluent.NavigationView>(find.byType(fluent.NavigationView));
      expect(view.pane?.displayMode, fluent.PaneDisplayMode.top);
      expect(tester.takeException(), isNull);
    });
  });

  group('no token renderer inside a Fluent frame (§15.3)', () {
    testWidgets('the whole chrome set draws from Fluent, not from the shared base', (tester) async {
      await tester.pumpWidget(
        harness(
          LiveScaffold(
            appBar: LiveAppBar(
              title: 'Rooms',
              actions: const [Text('act')],
              bottom: LiveTabs(
                tabs: const [
                  LiveTab(label: 'One'),
                  LiveTab(label: 'Two'),
                ],
                index: 0,
                onChanged: (_) {},
              ),
            ),
            body: Column(
              children: [
                LiveSegmented(labels: const ['A', 'B'], index: 0, onChanged: (_) {}),
                LiveNavBar(
                  items: const [LiveNavBarItem(label: 'Home', icon: fluent.FluentIcons.home)],
                  index: 0,
                  onChanged: (_) {},
                ),
              ],
            ),
            bottomBar: LiveNavBar(
              items: const [
                LiveNavBarItem(label: 'Home', icon: fluent.FluentIcons.home),
                LiveNavBarItem(label: 'Shows', icon: Icons.star),
              ],
              index: 1,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      // Fluent declares all seventeen controls, so nothing in a Fluent page should
      // be a `Token*` renderer any more — the assertion is by name rather than by
      // list so a control added to the contract cannot slip in silently.
      expect(find.byWidgetPredicate((widget) => widget.runtimeType.toString().startsWith('Token')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
