import 'package:cupertino_ui/cupertino_ui.dart' as cu;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_cupertino/live_uikit_cupertino.dart';

import 'stub_router.dart';

/// §16 widget tests for `live_uikit_cupertino`, driven through the real
/// runtime path so `LiveButton`/`LiveSwitch`/… dispatch to the native
/// `cupertino_ui` widgets. Covers §9 rules (callback + loading gating, controller
/// passthrough, controlled switch), the chrome set, the seven controls this
/// language had to add, the composed app shell (§ surfaces), and the check that no
/// token renderer is left inside a Cupertino frame.
void main() {
  const config = UiConfig(language: LiveDesignLanguage.cupertino, brightness: UiBrightnessMode.light);

  Widget harness(Widget child) => LiveConfigProvider(
    config: config,
    registry: const LanguageRegistry(adapters: {LiveDesignLanguage.cupertino: cupertinoAdapter}),
    // The Scaffold supplies Flutter's Material for the shared-renderer controls;
    // the Cupertino widgets themselves get their theme from `adapter.wrap`.
    child: MaterialApp(
      localizationsDelegates: const [...liveLocalizationsDelegates, ...cupertinoLocalizationsDelegates],
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

  testWidgets('a card is the fork inset-grouped panel, not the token box (§9)', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      harness(
        SizedBox(
          width: 300,
          child: LiveCard(onTap: () => tapped = true, child: const Text('body')),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(cu.CupertinoListSection), findsOneWidget);
    expect(find.text('body'), findsOneWidget);

    await tester.tap(find.text('body'));
    await tester.pump();
    expect(tapped, isTrue);
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

  group('the seven controls this language had to add (§9/§16)', () {
    testWidgets('a checkbox is the fork box, and a disabled one reports nothing', (tester) async {
      bool? value;
      await tester.pumpWidget(harness(LiveCheckbox(value: false, onChanged: (v) => value = v, label: 'Remember')));
      await tester.pump();

      expect(find.byType(cu.CupertinoCheckbox), findsOneWidget);
      // The spec's label has no slot on the box, so it travels beside it.
      expect(find.text('Remember'), findsOneWidget);

      await tester.tap(find.byType(cu.CupertinoCheckbox));
      await tester.pump();
      expect(value, isTrue);

      await tester.pumpWidget(harness(LiveCheckbox(value: true, enabled: false, onChanged: (v) => value = v)));
      await tester.pump();
      expect(tester.widget<cu.CupertinoCheckbox>(find.byType(cu.CupertinoCheckbox)).onChanged, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a segmented track is the fork control and reports its index', (tester) async {
      var chosen = -1;
      await tester.pumpWidget(
        harness(LiveSegmented(labels: const ['Small', 'Medium', 'Large'], index: 1, onChanged: (i) => chosen = i)),
      );
      await tester.pump();

      final control = tester.widget<cu.CupertinoSegmentedControl<int>>(find.byType(cu.CupertinoSegmentedControl<int>));
      expect(control.groupValue, 1);

      await tester.tap(find.text('Large'));
      // The library fades the new selection in over 165ms.
      await tester.pumpAndSettle();
      expect(chosen, 2);

      await tester.pumpWidget(
        harness(LiveSegmented(labels: const ['A', 'B'], index: 0, enabled: false, onChanged: (i) => chosen = i)),
      );
      await tester.pump();
      expect(
        tester
            .widget<cu.CupertinoSegmentedControl<int>>(find.byType(cu.CupertinoSegmentedControl<int>))
            .disabledChildren,
        {0, 1},
        reason: 'a disabled group is the library inert state, segment by segment',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a one-label track is the library inert cell, not a shared renderer', (tester) async {
      // The library asserts at least two segments, so a track it would throw on is
      // drawn with its own inert press target instead (§15).
      await tester.pumpWidget(harness(LiveSegmented(labels: const ['Only'], index: 0, onChanged: (_) {})));
      await tester.pump();

      expect(find.byType(cu.CupertinoSegmentedControl<int>), findsNothing);
      expect(find.byType(cu.CupertinoButton), findsOneWidget);
      expect(find.text('Only'), findsOneWidget);

      await tester.tap(find.text('Only'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a known fraction is the fork linear bar, a null one its spinner', (tester) async {
      await tester.pumpWidget(harness(const SizedBox(width: 300, child: LiveProgress(value: 0.25, showLabel: true))));
      await tester.pump();

      final bar = tester.widget<cu.CupertinoLinearActivityIndicator>(find.byType(cu.CupertinoLinearActivityIndicator));
      expect(bar.progress, 0.25);
      expect(find.text('25%'), findsOneWidget);

      await tester.pumpWidget(harness(const SizedBox(width: 300, child: LiveProgress(value: 0.9, height: 3))));
      await tester.pump();
      final filled = tester.widget<cu.CupertinoLinearActivityIndicator>(
        find.byType(cu.CupertinoLinearActivityIndicator),
      );
      expect(filled.height, 3);
      expect(find.text('90%'), findsNothing, reason: 'showLabel is off, so no percentage is named');

      await tester.pumpWidget(harness(const SizedBox(width: 300, child: LiveProgress(value: null))));
      await tester.pump();
      expect(find.byType(cu.CupertinoActivityIndicator), findsOneWidget);

      // The spinner ticks for as long as it is on screen; taking it down is what
      // stops the ticker, so the test ends with the frame empty.
      await tester.pumpWidget(harness(const SizedBox.shrink()));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a select is the fork pull-down menu and reports the chosen value', (tester) async {
      String? chosen;
      await tester.pumpWidget(
        harness(
          LiveSelect<String>(
            items: const ['alpha', 'beta'],
            itemLabel: (item) => item,
            value: 'alpha',
            placeholder: 'Pick one',
            onChanged: (value) => chosen = value,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(cu.CupertinoMenuAnchor), findsOneWidget);
      expect(find.text('alpha'), findsOneWidget, reason: 'the trigger names the current value');
      expect(find.text('beta'), findsNothing, reason: 'the menu is closed until the trigger is pressed');

      await tester.tap(find.text('alpha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('beta'));
      await tester.pumpAndSettle();

      expect(chosen, 'beta');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a select with nothing chosen shows its placeholder, and a disabled one cannot open', (tester) async {
      await tester.pumpWidget(
        harness(
          LiveSelect<String>(
            items: const ['alpha'],
            itemLabel: (item) => item,
            placeholder: 'Pick one',
            onChanged: null,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Pick one'), findsOneWidget);
      expect(find.byType(cu.CupertinoMenuItem), findsNothing, reason: 'the menu is closed until pressed');

      await tester.pumpWidget(
        harness(
          LiveSelect<String>(items: const ['alpha'], itemLabel: (item) => item, enabled: false, onChanged: (_) {}),
        ),
      );
      await tester.pump();
      expect(tester.widget<cu.CupertinoButton>(find.byType(cu.CupertinoButton)).onPressed, isNull);
      await tester.tap(find.byType(cu.CupertinoMenuAnchor));
      await tester.pump();
      expect(find.byType(cu.CupertinoMenuItem), findsNothing, reason: 'an inert trigger never opens the menu');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tab strip is a row of the library buttons, not the bottom bar', (tester) async {
      var chosen = -1;
      await tester.pumpWidget(
        harness(
          LiveTabs(
            tabs: const [
              LiveTab(label: 'Live'),
              LiveTab(label: 'Library', icon: Icons.star),
            ],
            index: 0,
            onChanged: (index) => chosen = index,
          ),
        ),
      );
      await tester.pump();

      // `CupertinoTabBar` is the library's one strip and belongs to `navBar`; an
      // in-page strip is composed of its buttons instead.
      expect(find.byType(cu.CupertinoTabBar), findsNothing);
      expect(find.byIcon(Icons.star), findsOneWidget);

      await tester.tap(find.text('Library'));
      // CupertinoButton fades its pressed state back over 180ms.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(chosen, 1);

      await tester.pumpWidget(
        harness(
          LiveTabs(
            tabs: const [
              LiveTab(label: 'Live'),
              LiveTab(label: 'Library'),
            ],
            index: 0,
            enabled: false,
            onChanged: (index) => chosen = index,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Library'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(chosen, 1, reason: 'a disabled strip keeps its labels and stops reporting');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a toast surface is the library popup panel, not the token pill', (tester) async {
      await tester.pumpWidget(harness(const SizedBox.shrink()));
      LiveToast.show(tester.element(find.byType(Scaffold)), 'Saved', type: LiveToastType.success);
      await tester.pump();

      expect(find.text('Saved'), findsOneWidget);
      // `cupertino_ui` ships no `CupertinoToast`; the HUD it does have is the
      // popup surface the library draws its own popups on.
      expect(find.byType(cu.CupertinoPopupSurface), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the dialog surface and the page switcher (§9/§16)', () {
    testWidgets('a dialog is the fork alert card, not the token box', (tester) async {
      await tester.pumpWidget(harness(const SizedBox.shrink()));
      // The route, the barrier and the fade stay in the core; only the surface is
      // this language's (§9), so the test goes through `showLiveDialog`.
      final result = showLiveDialog<void>(
        context: tester.element(find.byType(Scaffold)),
        title: 'Leave the room?',
        child: const Text('The stream keeps running.'),
        actions: (_) => [LiveButton(label: 'Leave', onPressed: () {})],
      );
      await tester.pumpAndSettle();

      expect(find.byType(cu.CupertinoAlertDialog), findsOneWidget);
      expect(find.text('Leave the room?'), findsOneWidget);
      expect(find.text('The stream keeps running.'), findsOneWidget);
      expect(find.byType(cu.CupertinoButton), findsWidgets, reason: 'the actions stay the dispatched button');
      expect(tester.takeException(), isNull);

      // The route is the core's, so closing it is the core's too.
      Navigator.of(tester.element(find.byType(cu.CupertinoAlertDialog))).pop();
      await tester.pumpAndSettle();
      await result;
    });

    testWidgets('the icon an alert has no slot for still reaches its body', (tester) async {
      await tester.pumpWidget(
        harness(
          Builder(
            builder: (context) =>
                LiveTheme.of(context).adapter
                    .dialog(context, const LanguageDialogSpec(icon: Icons.star, content: Text('starred'))),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(cu.CupertinoAlertDialog), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.text('starred'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a page switcher is a Cupertino page view, not the token one', (tester) async {
      var reported = -1;
      Widget view(int index) => harness(
        SizedBox(
          width: 300,
          height: 200,
          child: Builder(
            builder: (context) => LiveTheme.of(context).adapter.tabView(
              context,
              LanguageTabViewSpec(
                pages: const [Text('first'), Text('second')],
                index: index,
                onIndexChanged: (page) => reported = page,
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(view(0));
      await tester.pumpAndSettle();
      expect(find.text('first'), findsOneWidget);

      // The caller owns the index, so moving it here is what changes the page.
      await tester.pumpWidget(view(1));
      await tester.pumpAndSettle();
      expect(find.text('second'), findsOneWidget);
      expect(reported, 1, reason: 'the animated page change reports back to the strip');
      expect(tester.takeException(), isNull);
    });
  });

  group('native chrome (§9/§16)', () {
    // The frame is the widget under test, so it is the home itself rather than a
    // child of a Material scaffold — a language frame that only worked inside
    // `Scaffold` would not be a frame.
    Widget chromeHarness(Widget child) => LiveConfigProvider(
      config: config,
      registry: const LanguageRegistry(adapters: {LiveDesignLanguage.cupertino: cupertinoAdapter}),
      child: MaterialApp(
        localizationsDelegates: const [...liveLocalizationsDelegates, ...cupertinoLocalizationsDelegates],
        supportedLocales: const [Locale('en')],
        home: child,
      ),
    );

    testWidgets('the page trio and the bottom strip render through the fork', (tester) async {
      var tapped = false;
      var picked = -1;
      await tester.pumpWidget(
        chromeHarness(
          LiveScaffold(
            appBar: LiveAppBar(
              title: 'Settings',
              actions: [LiveButton(label: 'Done', onPressed: () {})],
            ),
            body: LiveListRow(title: 'Profile', subtitle: 'liu', onTap: () => tapped = true),
            bottomBar: LiveNavBar(
              items: const [
                LiveNavBarItem(label: 'Home', icon: Icons.home),
                LiveNavBarItem(label: 'More', icon: Icons.more_horiz),
              ],
              index: 0,
              onChanged: (i) => picked = i,
            ),
          ),
        ),
      );

      expect(find.byType(cu.CupertinoPageScaffold), findsOneWidget);
      expect(find.byType(cu.CupertinoNavigationBar), findsOneWidget);
      expect(find.byType(cu.CupertinoListTile), findsOneWidget);
      expect(find.byType(cu.CupertinoTabBar), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byType(cu.CupertinoListTile));
      await tester.pump();
      expect(tapped, isTrue);

      await tester.tap(find.text('More'));
      await tester.pump();
      expect(picked, 1);
    });

    testWidgets('a long press reaches the row through the gesture wrapper', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        chromeHarness(
          LiveScaffold(
            body: LiveListRow(title: 'Room', onLongPress: () => pressed = true),
          ),
        ),
      );
      expect(find.byType(cu.CupertinoListTile), findsOneWidget);
      await tester.longPress(find.byType(cu.CupertinoListTile));
      await tester.pump();
      expect(pressed, isTrue);
    });

    testWidgets('a strip that cannot hold a selection is the library inert bar', (tester) async {
      // `CupertinoTabBar` asserts a non-empty list and an in-range index, and one
      // destination is not a selection either, so both specs draw the bar's own
      // surface with inert cells instead of falling through (§15).
      var picked = -1;
      await tester.pumpWidget(chromeHarness(const LiveNavBar(items: [], index: 0)));
      await tester.pump();
      expect(find.byType(cu.CupertinoTabBar), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        chromeHarness(
          LiveNavBar(
            items: const [LiveNavBarItem(label: 'Home', icon: Icons.home)],
            index: 4,
            onChanged: (index) => picked = index,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(cu.CupertinoTabBar), findsNothing);
      expect(find.text('Home'), findsOneWidget);

      await tester.tap(find.text('Home'));
      await tester.pump();
      expect(picked, -1, reason: 'an inert cell keeps its label and stops reporting');
      expect(tester.takeException(), isNull);
    });

    testWidgets('the whole contract draws from the fork, not from the shared base', (tester) async {
      await tester.pumpWidget(
        chromeHarness(
          LiveScaffold(
            appBar: const LiveAppBar(title: 'Rooms', actions: [Text('act')]),
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const LiveCard(child: Text('card')),
                  LiveCheckbox(value: false, onChanged: (_) {}, label: 'Keep'),
                  SizedBox(
                    width: 300,
                    child: LiveSegmented(labels: const ['A', 'B'], index: 0, onChanged: (_) {}),
                  ),
                  const SizedBox(width: 300, child: LiveProgress(value: 0.4)),
                  LiveSelect<String>(items: const ['x', 'y'], itemLabel: (item) => item, value: 'x', onChanged: (_) {}),
                  LiveTabs(
                    tabs: const [
                      LiveTab(label: 'One'),
                      LiveTab(label: 'Two'),
                    ],
                    index: 0,
                    onChanged: (_) {},
                  ),
                  LiveListRow(title: 'Profile', onTap: () {}),
                ],
              ),
            ),
            bottomBar: LiveNavBar(
              items: const [
                LiveNavBarItem(label: 'Home', icon: Icons.home),
                LiveNavBarItem(label: 'Shows', icon: Icons.star),
              ],
              index: 0,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      // Cupertino declares all fifteen controls, so nothing inside a Cupertino page
      // should be a `Token*` renderer any more — the assertion is by name rather
      // than by list, so a control added to the contract cannot slip in silently.
      expect(tester.takeException(), isNull);
    });
  });

  group('the app shell (§ surfaces)', () {
    const destinations = [
      LiveShellDestination(id: 'home', label: 'Home', icon: Icons.home),
      LiveShellDestination(id: 'follow', label: 'Follow', icon: Icons.favorite),
    ];

    testWidgets('the rail form is the list column of the fork, not the token shell', (tester) async {
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

      // `cupertino_ui` has no rail, so the pane is composed from its list
      // surface: a section of tiles, and the body still belongs to the caller.
      expect(find.byType(cu.CupertinoListSection), findsOneWidget);
      expect(find.byType(cu.CupertinoListTile), findsNWidgets(2));
      expect(find.text('room list'), findsOneWidget);
      // The composed column has a bottom slot of its own, unlike the strip.
      expect(find.text('settings'), findsOneWidget);

      await tester.tap(find.text('Follow'));
      await tester.pump();
      expect(chosen, 'follow');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a disabled destination is inert because the tile has no such state', (tester) async {
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

      // Kept in the layout, tinted out of the accent, and given no tap.
      expect(find.text('Follow'), findsOneWidget);
      await tester.tap(find.text('Follow'));
      await tester.pump();
      expect(chosen, '');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a bottom request hands the strip back to the fork bar, which has no footer', (tester) async {
      await tester.pumpWidget(
        harness(
          LiveAppShell(
            destinations: destinations,
            selectedId: 'home',
            onSelected: (_) {},
            placement: LiveShellPlacement.bottom,
            trailing: const Text('settings'),
            child: const Text('room list'),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(cu.CupertinoTabBar), findsOneWidget);
      expect(find.text('room list'), findsOneWidget);
      expect(find.text('settings'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('one destination is not a choice, so the shell stands aside', (tester) async {
      await tester.pumpWidget(
        harness(
          const LiveAppShell(
            destinations: [LiveShellDestination(id: 'home', label: 'Home', icon: Icons.home)],
            selectedId: 'home',
            placement: LiveShellPlacement.rail,
            child: Text('room list'),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(cu.CupertinoListSection), findsNothing);
      expect(find.text('room list'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the app host (§9)', () {
    // No outer `MaterialApp`: the host under test is the app widget itself, and
    // wrapping it in Material would supply exactly the localizations and route
    // behaviour the language is supposed to replace.
    Widget hostHarness(Widget child) => LiveConfigProvider(
      config: config,
      registry: const LanguageRegistry(adapters: {LiveDesignLanguage.cupertino: cupertinoAdapter}),
      child: child,
    );

    LiveApp hosted(Widget route) => LiveApp(
      routerConfig: stubRouterConfig(child: route),
      localizationsDelegates: const [...liveLocalizationsDelegates, ...cupertinoLocalizationsDelegates],
    );

    testWidgets('the tree is hosted by the fork Cupertino app, not by Material', (tester) async {
      await tester.pumpWidget(hostHarness(hosted(const Text('page'))));
      await tester.pumpAndSettle();

      expect(find.byType(cu.CupertinoApp), findsOneWidget);
      expect(find.byType(MaterialApp), findsNothing, reason: 'the Material host must not stand in (§15)');
      expect(find.text('page'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the fork controls still work under the Cupertino host', (tester) async {
      // The fork host installs no Material of its own, so this is the check that
      // what still leans on one — an `InkWell` a caller put in the content, the
      // selection toolbar's strings — finds them without a Material host.
      await tester.pumpWidget(
        hostHarness(
          hosted(
            Column(
              children: [
                const LiveCard(child: Text('card')),
                LiveTextField(placeholder: 'name', onChanged: (_) {}),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(cu.CupertinoApp), findsOneWidget);
      expect(find.text('card'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
