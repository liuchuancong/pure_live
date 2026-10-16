import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_glass/live_uikit_glass.dart';

import 'stub_router.dart';

/// §16 widget tests for `live_uikit_glass`, driving the `Live*` controls through
/// the real runtime so they render with `glass_morphism_plus` — the library's own
/// widgets where it has them, its frosted surfaces and theme values where it does
/// not — rather than the shared token renderer. Covers §9 gating (callback,
/// disabled, controlled value, controller passthrough) and the chrome set, which
/// Glass now renders in full.
void main() {
  const config = UiConfig(language: LiveDesignLanguage.glass, brightness: UiBrightnessMode.light);

  Widget harness(Widget child) => LiveConfigProvider(
    config: config,
    registry: const LanguageRegistry(
      adapters: {LiveDesignLanguage.glass: glassAdapter},
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

  group('the controls Glass composes from its own surfaces (§9)', () {
    testWidgets('a switch is a frosted track with a knob, and reports the value it did not have', (tester) async {
      bool? reported;
      await tester.pumpWidget(harness(LiveSwitch(value: false, onChanged: (v) => reported = v)));
      await tester.pump();

      expect(find.byType(TokenSwitch), findsNothing);
      // The track and the knob, both the library's surfaces.
      expect(find.byType(glass.GlassContainer), findsNWidgets(2));

      await tester.tap(find.byType(glass.GlassContainer).first);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(reported, isTrue);

      await tester.pumpWidget(harness(LiveSwitch(value: false, enabled: false, onChanged: (v) => reported = v)));
      await tester.pump();
      reported = null;
      await tester.tap(find.byType(glass.GlassContainer).first);
      await tester.pump();
      expect(reported, isNull, reason: 'a disabled switch keeps its sheet and stops reporting');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a checkbox ticks on a frosted box and carries its label', (tester) async {
      bool? reported;
      await tester.pumpWidget(
        harness(LiveCheckbox(value: true, onChanged: (v) => reported = v, label: 'Auto quality')),
      );
      await tester.pump();

      expect(find.byType(TokenCheckbox), findsNothing);
      expect(find.text('Auto quality'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.tap(find.byType(glass.GlassContainer));
      await tester.pump();
      expect(reported, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a slider drags along a frosted rail and reports the value', (tester) async {
      final reported = <double>[];
      await tester.pumpWidget(harness(SizedBox(width: 260, child: LiveSlider(value: 0.2, onChanged: reported.add))));
      await tester.pump();

      // The rail, the filled part of the track and the handle.
      expect(find.byType(glass.GlassContainer), findsNWidgets(3));
      expect(find.byType(TokenSlider), findsNothing);

      await tester.drag(find.byType(LiveSlider), const Offset(80, 0));
      await tester.pump();
      expect(reported, isNotEmpty);
      expect(reported.last, greaterThan(0.2));

      reported.clear();
      await tester.pumpWidget(
        harness(SizedBox(width: 260, child: LiveSlider(value: 0.2, enabled: false, onChanged: reported.add))),
      );
      await tester.pump();
      await tester.drag(find.byType(LiveSlider), const Offset(80, 0));
      await tester.pump();
      expect(reported, isEmpty, reason: 'a disabled rail keeps its shape and stops reporting');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a segmented track puts the chosen label on the brighter sheet', (tester) async {
      var chosen = -1;
      await tester.pumpWidget(
        harness(LiveSegmented(labels: const ['Small', 'Medium', 'Large'], index: 1, onChanged: (i) => chosen = i)),
      );
      await tester.pump();

      expect(find.byType(TokenSegmented), findsNothing);
      // The groove and the one selected pill; the rest are bare labels.
      expect(find.byType(glass.GlassContainer), findsNWidgets(2));
      expect(find.text('Medium'), findsOneWidget);

      await tester.tap(find.text('Large'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(chosen, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a progress bar is a frosted groove with a percentage beside it', (tester) async {
      await tester.pumpWidget(harness(const SizedBox(width: 260, child: LiveProgress(value: 0.5, showLabel: true))));
      await tester.pump();

      expect(find.text('50%'), findsOneWidget);
      expect(find.byType(TokenProgress), findsNothing);
      expect(find.byType(glass.GlassContainer), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('an indeterminate bar loops the frosted fill without a token spinner', (tester) async {
      await tester.pumpWidget(harness(const SizedBox(width: 260, child: LiveProgress(value: null))));
      await tester.pump();

      expect(find.byType(TokenProgress), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(glass.GlassContainer), findsNWidgets(2));

      // The marquee repeats forever, so the tree is torn down rather than settled.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpWidget(harness(const SizedBox.shrink()));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a select opens its options as a frosted sheet in flow, and hands back a typed value', (tester) async {
      String? chosen;
      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 260,
            child: LiveSelect<String>(
              items: const ['A', 'B', 'C'],
              itemLabel: (item) => item,
              value: 'B',
              placeholder: 'Pick one',
              onChanged: (v) => chosen = v,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(TokenSelect<String>), findsNothing);
      expect(find.text('B'), findsOneWidget, reason: 'the closed field shows the selected label');
      expect(find.text('A'), findsNothing, reason: 'the menu is a sheet the tap opens');

      await tester.tap(find.text('B'));
      await tester.pump();
      expect(find.text('A'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);

      await tester.tap(find.text('A'));
      await tester.pump();
      expect(chosen, 'A');
      expect(find.text('C'), findsNothing, reason: 'choosing closes the menu');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tab strip rules its active label and reports its index', (tester) async {
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
      expect(find.byType(glass.GlassContainer), findsOneWidget);

      await tester.tap(find.text('Shows'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(chosen, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a destination strip selects on a brighter sheet, and an inert one reports nothing', (tester) async {
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

      await tester.pumpWidget(harness(SizedBox(width: 320, child: bar())));
      await tester.pump();
      expect(find.byType(TokenNavBar), findsNothing);
      await tester.tap(find.text('Shows'));
      await tester.pump();
      expect(chosen, 1);

      chosen = -1;
      await tester.pumpWidget(harness(SizedBox(width: 320, child: bar(enabled: false))));
      await tester.pump();
      await tester.tap(find.text('Shows'));
      await tester.pump();
      expect(chosen, -1, reason: 'a disabled strip keeps its labels and refuses taps');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a toast surface is the core overlay with a frosted pill, not a token pill', (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        harness(
          Builder(
            builder: (inner) {
              context = inner;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pump();

      LiveToast.show(context, 'Room is live', type: LiveToastType.success);
      await tester.pump();

      expect(find.text('Room is live'), findsOneWidget);
      expect(find.byType(TokenToast), findsNothing);
      expect(find.byType(glass.GlassContainer), findsWidgets);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Room is live'), findsNothing, reason: 'the core owns the removal timer (§9)');
      expect(tester.takeException(), isNull);
    });
  });

  group('the chrome Glass composes rather than borrows (§9)', () {
    testWidgets('a page frame is one frosted sheet with its bars inside it', (tester) async {
      await tester.pumpWidget(
        harness(
          LiveScaffold(
            appBar: const LiveAppBar(title: 'Rooms', actions: [Text('act')]),
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

      expect(find.text('content'), findsOneWidget);
      expect(find.text('Rooms'), findsOneWidget);
      expect(find.byType(TokenScaffold), findsNothing);
      expect(find.byType(TokenAppBar), findsNothing);
      // The frame is a sheet, the header is a sheet, the strip is a sheet and the
      // one selected destination is a brighter one inside it.
      expect(find.byType(glass.GlassContainer), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a header takes its title, its actions and the strip under them', (tester) async {
      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 320,
            child: LiveAppBar(
              title: 'Rooms',
              leading: const Icon(Icons.menu),
              actions: const [Text('act')],
              bottom: LiveTabs(
                tabs: const [
                  LiveTab(label: 'One'),
                  LiveTab(label: 'Two'),
                ],
                index: 1,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Rooms'), findsOneWidget);
      expect(find.byIcon(Icons.menu), findsOneWidget);
      expect(find.text('act'), findsOneWidget);
      expect(find.text('Two'), findsOneWidget);
      expect(find.byType(TokenAppBar), findsNothing);
      expect(find.byType(TokenTabs), findsNothing);
      // Material's own bar, which the library's `GlassAppBar` is built out of, is
      // not what this frame draws (§9).
      expect(find.byType(AppBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a row resolves through glass.ListTile with both lines and its tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 300,
            child: LiveListRow(
              title: 'Room 12',
              subtitle: '3 watching',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(glass.GlassListTile), findsOneWidget);
      expect(find.byType(TokenListRow), findsNothing);
      expect(find.text('Room 12'), findsOneWidget);
      expect(find.text('3 watching'), findsOneWidget);
      // The library's own divider, because the row asks for one.
      expect(find.byType(glass.GlassDivider), findsOneWidget);

      await tester.tap(find.text('Room 12'));
      await tester.pump();
      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    });
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

    testWidgets('the selected row takes the theme tint and an unselected row the library default', (tester) async {
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
              const LiveListRow(title: 'On air', selected: true, divided: false),
              const LiveListRow(title: 'Off air', divided: false),
            ],
          ),
        ),
      );
      final tiles = tester.widgetList<glass.GlassListTile>(find.byType(glass.GlassListTile)).toList();
      expect(tiles, hasLength(2));
      expect(tiles.first.color, theme.colors.primaryBg);
      expect(tiles.last.color, isNot(theme.colors.primaryBg));
      expect(find.byType(glass.GlassDivider), findsNothing);
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

    testWidgets('a composed switch routes the caller node through the shared seam', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(harness(LiveSwitch(value: false, onChanged: (_) {}, focusNode: node)));
      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('no token renderer inside a glass frame (§15.3)', () {
    testWidgets('the whole contract draws from Glass, not from the shared base', (tester) async {
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
            body: SingleChildScrollView(
              child: Column(
                children: [
                  LiveButton(label: 'Go', onPressed: () {}),
                  const LiveCard(child: Text('card')),
                  const LiveTextField(placeholder: 'Name'),
                  LiveSwitch(value: true, onChanged: (_) {}),
                  LiveCheckbox(value: false, onChanged: (_) {}, label: 'Auto'),
                  SizedBox(width: 240, child: LiveSlider(value: 0.4, onChanged: (_) {})),
                  LiveSegmented(labels: const ['A', 'B'], index: 0, onChanged: (_) {}),
                  const LiveProgress(value: 0.25),
                  SizedBox(
                    width: 240,
                    child: LiveSelect<String>(
                      items: const ['x', 'y'],
                      itemLabel: (item) => item,
                      value: 'x',
                      onChanged: (_) {},
                    ),
                  ),
                  const LiveListRow(title: 'Room 12'),
                  LiveNavBar(
                    items: const [
                      LiveNavBarItem(label: 'Home', icon: Icons.home),
                      LiveNavBarItem(label: 'Shows', icon: Icons.star),
                    ],
                    index: 1,
                    onChanged: (_) {},
                  ),
                ],
              ),
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
      );
      await tester.pump();

      // Glass declares all fifteen controls, so nothing in a glass page should be
      // a `Token*` renderer any more — the assertion is by name rather than by
      // list so a control added to the contract cannot slip in silently.
      expect(find.byWidgetPredicate((widget) => widget.runtimeType.toString().startsWith('Token')), findsNothing);
      expect(find.text('Room 12'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the app shell (§ surfaces)', () {
    const destinations = [
      LiveShellDestination(id: 'home', label: 'Home', icon: Icons.home),
      LiveShellDestination(id: 'follow', label: 'Follow', icon: Icons.favorite),
    ];

    testWidgets('the rail is a frosted column this package composes, not the token shell', (tester) async {
      var chosen = '';
      await tester.pumpWidget(
        harness(
          LiveAppShell(
            destinations: destinations,
            selectedId: 'home',
            onSelected: (id) => chosen = id,
            trailing: const Text('settings footer'),
            placement: LiveShellPlacement.rail,
            child: const Text('room list'),
          ),
        ),
      );
      await tester.pump();

      // The library ships no navigation structure, so the column is assembled from
      // its own surface pieces: a frosted track and a brighter sheet on the
      // selected destination.
      expect(find.byType(TokenAppShell), findsNothing);
      expect(find.byType(glass.GlassContainer), findsWidgets);
      expect(find.text('room list'), findsOneWidget);
      // The composed column has a bottom slot of its own, unlike the strip.
      expect(find.text('settings footer'), findsOneWidget);

      await tester.tap(find.text('Follow'));
      await tester.pump();
      expect(chosen, 'follow');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a disabled destination keeps its row and refuses the tap', (tester) async {
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

      // Kept in the layout so the column does not shift, and given no tap.
      expect(find.text('Follow'), findsOneWidget);
      await tester.tap(find.text('Follow'));
      await tester.pump();
      expect(chosen, '', reason: 'the shell refuses a disabled destination in place');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a bottom request hands the strip to the nav bar, and drops the trailing', (tester) async {
      await tester.pumpWidget(
        harness(
          LiveAppShell(
            destinations: destinations,
            selectedId: 'home',
            onSelected: (_) {},
            trailing: const Text('settings footer'),
            placement: LiveShellPlacement.bottom,
            child: const Text('room list'),
          ),
        ),
      );
      await tester.pump();

      // The strip is the package's own frosted nav bar; that form has no trailing
      // slot, so the footer is dropped rather than faked as a third tab.
      expect(find.byType(TokenAppShell), findsNothing);
      expect(find.byType(glass.GlassContainer), findsWidgets);
      expect(find.text('room list'), findsOneWidget);
      expect(find.text('settings footer'), findsNothing);
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

      // No navigation is drawn — the shell hands the frame back to the page.
      expect(find.byType(TokenAppShell), findsNothing);
      expect(find.byType(glass.GlassContainer), findsNothing);
      expect(find.text('room list'), findsOneWidget);
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
        adapters: {LiveDesignLanguage.glass: glassAdapter},
        fallback: SharedLanguageAdapter(),
      ),
      child: child,
    );

    testWidgets('the tree is hosted by WidgetsApp under the library theme, not by the token host', (tester) async {
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
      expect(find.byType(glass.GlassTheme), findsWidgets, reason: "the library's own theme, above the routes");
      expect(find.text('page'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
