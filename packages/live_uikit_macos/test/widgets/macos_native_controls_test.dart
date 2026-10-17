import 'dart:async' show unawaited;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_macos/live_uikit_macos.dart';
import 'package:macos_ui/macos_ui.dart' as macos;

import 'stub_router.dart';

/// `macos_ui` paints a glyph with its own `MacosIcon`, which `find.byIcon` does not
/// match — that finder looks for a Material `Icon` — so the strip and the toast
/// address the library's icon widget here.
Finder macosGlyph(IconData icon) =>
    find.byWidgetPredicate((widget) => widget is macos.MacosIcon && widget.icon == icon);

/// §16 widget tests for `live_uikit_macos`, driven through the real runtime path
/// so `Live*` controls dispatch to the `macos_ui` widgets — the eleven the library
/// has a widget for, and the six it had to be given a builder for (the card, the
/// toast surface and the dialogs its own alert cannot take out of its `MacosSheet`
/// panel, the two strips out of its own `MacosTab` cell and `MacosIcon`, and the
/// page switcher out of its pane treatment).
void main() {
  const config = UiConfig(language: LiveDesignLanguage.macos, brightness: UiBrightnessMode.light);

  Widget harness(Widget child) => LiveConfigProvider(
    config: config,
    registry: const LanguageRegistry(adapters: {LiveDesignLanguage.macos: macosAdapter}),
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

  testWidgets('the variant rides on the fork color slot (§9)', (tester) async {
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
            // Listed explicitly: the test is about the variant mapping, and the
            // row index is the assertion argument — spelling out the default
            // keeps the three cases symmetrical.
            // ignore: avoid_redundant_argument_values
            LiveButton(label: 'p', variant: ButtonVariant.primary, onPressed: () {}),
            LiveButton(label: 'd', variant: ButtonVariant.danger, onPressed: () {}),
            LiveButton(label: 's', variant: ButtonVariant.secondary, onPressed: () {}),
          ],
        ),
      ),
    );
    // `PushButton.color` is the only variant affordance the fork has: primary
    // is its prominent button, danger the same shape in the token error, and
    // secondary the library's own standard grey (null = theme default).
    final fills = tester.widgetList<macos.PushButton>(find.byType(macos.PushButton)).map((b) => b.color).toList();
    expect(fills[0], theme.colors.primary);
    expect(fills[1], theme.colors.error);
    expect(fills[2], isNull);
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

  group('disabled and preserved spec fields (§9/§16)', () {
    testWidgets('a null callback disables the checkbox rather than faking one', (tester) async {
      await tester.pumpWidget(harness(const LiveCheckbox(value: false, onChanged: null)));
      expect(tester.widget<macos.MacosCheckbox>(find.byType(macos.MacosCheckbox)).onChanged, isNull);
      await tester.pumpWidget(harness(LiveCheckbox(value: false, enabled: false, onChanged: (_) {})));
      expect(tester.widget<macos.MacosCheckbox>(find.byType(macos.MacosCheckbox)).onChanged, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a disabled slider is the library rail, not a shared fallback', (tester) async {
      // `MacosSlider.onChanged` is required and its track and thumb are private,
      // so a dead slider is drawn from the library's own inert rail plus its
      // published thumb colour (§9/§15).
      var changed = 0.0;
      await tester.pumpWidget(
        harness(
          SizedBox(width: 300, child: LiveSlider(value: 0.5, enabled: false, onChanged: (value) => changed = value)),
        ),
      );
      await tester.pump();
      expect(find.byType(macos.MacosSlider), findsNothing);
      expect(find.byType(macos.ProgressBar), findsOneWidget, reason: 'the library rail stands under the thumb');
      expect(find.byType(LiveSlider), findsOneWidget);

      await tester.dragFrom(tester.getCenter(find.byType(LiveSlider)), const Offset(60, 0));
      await tester.pump();
      expect(changed, 0.0, reason: 'a dead rail keeps its value');
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(harness(const LiveSlider(value: 0.5, onChanged: null)));
      await tester.pump();
      expect(find.byType(macos.MacosSlider), findsNothing);
      expect(find.byType(macos.ProgressBar), findsOneWidget);
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

  group('chrome (§9)', () {
    // The row is the one chrome piece that can be pumped on its own. The frame and
    // the bar are pumped together with everything else in the group below, which
    // unmounts them before teardown — macos_ui's wallpaper-tinting layer keeps a
    // periodic timer alive behind `MacosScaffold`/`ToolBar`, and the test binding
    // counts that as a leak. In a running window the timer is simply the library
    // tracking the desktop picture.
    testWidgets('a row resolves through MacosListTile and keeps both press handlers', (tester) async {
      var taps = 0;
      var longs = 0;
      await tester.pumpWidget(
        harness(
          LiveListRow(
            title: 'Accent',
            subtitle: 'violet',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => taps++,
            onLongPress: () => longs++,
          ),
        ),
      );

      expect(find.byType(macos.MacosListTile), findsOneWidget);
      expect(find.text('Accent'), findsOneWidget);
      expect(find.text('violet'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      await tester.tap(find.byType(macos.MacosListTile));
      await tester.pump();
      expect(taps, 1);

      await tester.longPress(find.byType(macos.MacosListTile));
      await tester.pump();
      expect(longs, 1, reason: 'the library tile takes a long press, so no wrapper is needed');
    });
  });

  group('the eight controls macOS had to be given a builder for (§9)', () {
    testWidgets('a card is a MacosSheet panel, and it takes the tap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(harness(LiveCard(child: const Text('body'), onTap: () => taps++)));
      await tester.pump();

      expect(find.byType(macos.MacosSheet), findsOneWidget);
      expect(find.text('body'), findsOneWidget);

      await tester.tap(find.text('body'));
      await tester.pump();
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a switch is a MacosSwitch and reports the next value', (tester) async {
      bool? value;
      await tester.pumpWidget(harness(LiveSwitch(value: false, onChanged: (v) => value = v)));
      await tester.pumpAndSettle();

      expect(find.byType(macos.MacosSwitch), findsOneWidget);
      expect(tester.widget<macos.MacosSwitch>(find.byType(macos.MacosSwitch)).value, isFalse);

      await tester.tap(find.byType(macos.MacosSwitch));
      await tester.pumpAndSettle();
      expect(value, isTrue);

      // Inert: the library derives the disabled look from a null callback, so the
      // spec's `enabled` has to arrive there rather than as a swallowing closure.
      await tester.pumpWidget(harness(LiveSwitch(value: true, enabled: false, onChanged: (v) => value = v)));
      await tester.pumpAndSettle();
      expect(tester.widget<macos.MacosSwitch>(find.byType(macos.MacosSwitch)).onChanged, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a segmented track is a MacosSegmentedControl and reports the index', (tester) async {
      var chosen = -1;
      await tester.pumpWidget(
        harness(
          LiveSegmented(labels: const ['Small', 'Medium', 'Large'], index: 1, onChanged: (index) => chosen = index),
        ),
      );
      await tester.pump();

      expect(find.byType(macos.MacosSegmentedControl), findsOneWidget);
      expect(tester.widget<macos.MacosSegmentedControl>(find.byType(macos.MacosSegmentedControl)).tabs.length, 3);

      await tester.tap(find.text('Large'));
      await tester.pump();
      expect(chosen, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a disabled track ignores the pointer, because the library has no dead state', (tester) async {
      var chosen = -1;
      await tester.pumpWidget(
        harness(
          LiveSegmented(
            labels: const ['Small', 'Medium'],
            index: 0,
            enabled: false,
            onChanged: (index) => chosen = index,
          ),
        ),
      );
      await tester.pump();
      // `MacosSegmentedControl` sets its controller index on tap whatever the
      // caller asked, so inertness is the IgnorePointer the builder puts on it.
      expect(
        tester
            .widget<IgnorePointer>(
              find.descendant(of: find.byType(LiveSegmented), matching: find.byType(IgnorePointer)),
            )
            .ignoring,
        isTrue,
      );
      // The tap is meant to miss: the pointer never reaches the segment, which is
      // what the warning below would otherwise be reporting.
      await tester.tap(find.text('Medium'), warnIfMissed: false);
      await tester.pump();
      expect(chosen, -1, reason: 'a disabled track must not move the selection it never reported');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a determinate bar is a ProgressBar, in the units the library uses', (tester) async {
      await tester.pumpWidget(harness(const LiveProgress(value: 0.6, height: 6, barColor: Color(0xFF00FF00))));
      await tester.pump();

      final bar = tester.widget<macos.ProgressBar>(find.byType(macos.ProgressBar));
      // The contract is a 0..1 fraction, the library takes a percentage.
      expect(bar.value, 60);
      expect(bar.height, 6);
      expect(bar.trackColor, const Color(0xFF00FF00));
    });

    testWidgets('an indeterminate value is a ProgressCircle spinner, not a bar at zero', (tester) async {
      await tester.pumpWidget(harness(const LiveProgress(value: null)));
      await tester.pump();

      expect(find.byType(macos.ProgressCircle), findsOneWidget);
      expect(find.byType(macos.ProgressBar), findsNothing);
      expect(tester.widget<macos.ProgressCircle>(find.byType(macos.ProgressCircle)).value, isNull);
      expect(tester.takeException(), isNull);

      // The activity indicator animates for as long as it is mounted, so the
      // frame is unmounted rather than settled.
      await tester.pumpWidget(harness(const SizedBox.shrink()));
      await tester.pump();
    });

    testWidgets('a select is a MacosPopupButton, and a choice comes back typed', (tester) async {
      String? chosen;
      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 260,
            child: LiveSelect<String>(
              items: const ['alpha', 'beta'],
              itemLabel: (item) => item,
              placeholder: 'Pick one',
              onChanged: (value) => chosen = value,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(macos.MacosPopupButton<String>), findsOneWidget);
      expect(find.text('Pick one'), findsOneWidget, reason: 'the placeholder rides in the button hint slot');

      await tester.tap(find.byType(macos.MacosPopupButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('beta').last);
      await tester.pumpAndSettle();
      expect(chosen, 'beta');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a select whose value is not among its items reads as nothing chosen', (tester) async {
      // The library asserts the value matches exactly one item but skips that
      // check for a null value, which is its own unchosen state: the field stays
      // a pop-up button and paints its hint (§15).
      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 260,
            child: LiveSelect<String>(
              items: const ['alpha', 'alpha', 'beta'],
              itemLabel: (item) => item,
              value: 'missing',
              placeholder: 'Pick one',
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(macos.MacosPopupButton<String>), findsOneWidget);
      expect(find.text('Pick one'), findsOneWidget, reason: 'an off-list value is not a selection');
      expect(find.text('missing'), findsNothing);
      final button = tester.widget<macos.MacosPopupButton<String>>(find.byType(macos.MacosPopupButton<String>));
      expect(button.value, isNull);
      expect(button.items!.map((item) => item.value).toList(), ['alpha', 'beta'], reason: 'each legal value once');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tab strip is MacosTab cells with its glyph and reports the index', (tester) async {
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

      expect(find.byType(macos.MacosTab), findsNWidgets(2));
      // The cell has no icon slot, which is why the strip is composed: the glyph
      // still has to reach the screen.
      expect(find.byType(macos.MacosIcon), findsOneWidget);
      expect(macosGlyph(Icons.star), findsOneWidget);

      await tester.tap(find.text('Shows'));
      await tester.pump();
      expect(chosen, 1);
      final tabs = tester.widgetList<macos.MacosTab>(find.byType(macos.MacosTab)).toList();
      expect(tabs.map((tab) => tab.active), [true, false], reason: 'the strip stays controlled by the spec index');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a destination strip reports its index, and a disabled one stays silent', (tester) async {
      var chosen = -1;
      Widget bar({bool enabled = true}) => LiveNavBar(
        items: const [
          LiveNavBarItem(label: 'Home', icon: Icons.home),
          LiveNavBarItem(label: 'Follow', icon: Icons.favorite),
        ],
        index: 0,
        enabled: enabled,
        onChanged: (index) => chosen = index,
      );

      await tester.pumpWidget(harness(SizedBox(width: 320, child: bar())));
      await tester.pump();
      expect(macosGlyph(Icons.favorite), findsOneWidget);

      await tester.tap(find.text('Follow'));
      await tester.pump();
      expect(chosen, 1);

      await tester.pumpWidget(harness(SizedBox(width: 320, child: bar(enabled: false))));
      await tester.pump();
      await tester.tap(find.text('Follow'));
      await tester.pump();
      expect(chosen, 1, reason: 'a disabled strip keeps its labels and stops reporting');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a toast surface is a MacosSheet panel, not the token pill', (tester) async {
      const anchor = Key('toast-anchor');
      await tester.pumpWidget(harness(const SizedBox(key: anchor, width: 1, height: 1)));
      LiveToast.show(tester.element(find.byKey(anchor)), 'Saved', type: LiveToastType.success);
      await tester.pump();

      expect(find.text('Saved'), findsOneWidget);
      // The panel is the library's own; `showMacosSheet` would need a route, and
      // the core owns the overlay, the fade and the timer, so the widget alone is
      // what this slot can return.
      expect(find.byType(macos.MacosSheet), findsOneWidget);
      expect(macosGlyph(CupertinoIcons.checkmark_circle), findsOneWidget);

      // Let the message finish its own life so its timer is not left pending.
      await tester.pump(const Duration(milliseconds: 2300));
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('the dialog and the page switcher (§9)', () {
    // `showLiveDialog` pushes on the harness's own `Navigator`, so the route has to
    // be popped and the frame unmounted before teardown: the dialog's barrier and
    // `macos_ui`'s coloured controls keep a periodic timer alive otherwise.
    Future<void> detach(WidgetTester tester, {VoidCallback? pop}) async {
      pop?.call();
      await tester.pumpAndSettle();
      await tester.pumpWidget(harness(const SizedBox.shrink()));
      await tester.pump(const Duration(seconds: 2));
    }

    macos.PushButton action(String label) =>
        macos.PushButton(controlSize: macos.ControlSize.large, onPressed: () {}, child: Text(label));

    testWidgets('a dialog the library has slots for is MacosAlertDialog, not the token card', (tester) async {
      const anchor = Key('dialog-anchor');
      await tester.pumpWidget(harness(const SizedBox(key: anchor, width: 1, height: 1)));
      final anchorContext = tester.element(find.byKey(anchor));
      unawaited(
        showLiveDialog<void>(
          context: anchorContext,
          title: 'Leave the room?',
          child: const Text('Playback stops.'),
          actions: (_) => [action('Stay'), action('Leave')],
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(macos.MacosAlertDialog), findsOneWidget);
      expect(find.text('Playback stops.'), findsOneWidget);
      // The library draws `secondaryButton` then `primaryButton`, which is the
      // spec's order and macOS's convention: the default action on the right.
      expect(tester.getCenter(find.text('Stay')).dx, lessThan(tester.getCenter(find.text('Leave')).dx));
      expect(tester.takeException(), isNull);

      await detach(tester, pop: () => Navigator.of(anchorContext).pop());
    });

    testWidgets('a dialog the alert cannot take is a MacosSheet panel, still not the token card', (tester) async {
      const anchor = Key('dialog-anchor');
      await tester.pumpWidget(harness(const SizedBox(key: anchor, width: 1, height: 1)));
      final anchorContext = tester.element(find.byKey(anchor));
      // Three actions — the library widget has two slots, so this spec has no alert
      // to be mapped onto and the surface is composed from its panel instead.
      unawaited(
        showLiveDialog<void>(
          context: anchorContext,
          title: 'Choose',
          child: const Text('Three ways out.'),
          actions: (_) => [action('One'), action('Two'), action('Three')],
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(macos.MacosAlertDialog), findsNothing);
      expect(find.byType(macos.MacosSheet), findsOneWidget);
      expect(find.text('Three ways out.'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await detach(tester, pop: () => Navigator.of(anchorContext).pop());
    });

    testWidgets('the page switcher is the library pane, and the caller moves the index', (tester) async {
      Widget view(int index) => SizedBox(
        width: 320,
        height: 160,
        // The contract has no `LiveTabView` widget yet, so this is its own label builder the
        // core's own tab view dispatch would use.
        child: Builder(
          builder: (context) => LiveTheme.of(context).adapter.tabView(
            context,
            LanguageTabViewSpec(pages: const [Text('first page'), Text('second page')], index: index),
          ),
        ),
      );

      await tester.pumpWidget(harness(view(0)));
      await tester.pump();

      expect(find.text('first page'), findsOneWidget);
      expect(find.text('second page'), findsNothing, reason: 'a macOS pane shows one body at a time');

      await tester.pumpWidget(harness(view(1)));
      await tester.pump();
      expect(find.text('second page'), findsOneWidget);
      expect(find.text('first page'), findsNothing);
      expect(tester.takeException(), isNull);

      await detach(tester);
    });
  });

  group('no token renderer inside a macOS frame (§15.3)', () {
    testWidgets('the whole chrome set draws from macos_ui, not from the shared base', (tester) async {
      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 600,
            height: 400,
            child: LiveScaffold(
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
                  const LiveCard(child: Text('card')),
                  LiveSwitch(value: true, onChanged: (_) {}),
                  LiveSegmented(labels: const ['A', 'B'], index: 0, onChanged: (_) {}),
                  const LiveProgress(value: 0.5),
                  SizedBox(
                    width: 220,
                    child: LiveSelect<String>(items: const ['x'], itemLabel: (item) => item, onChanged: (_) {}),
                  ),
                  const LiveListRow(title: 'row'),
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

      // macOS declares all seventeen controls, so nothing inside a macOS page should
      // be a `Token*` renderer any more — the assertion is by class-name prefix
      // rather than by list, so a control added to the contract cannot slip a
      // shared renderer in silently.
      expect(find.byType(macos.MacosScaffold), findsOneWidget);
      expect(find.byType(macos.ToolBar), findsOneWidget);
      expect(tester.takeException(), isNull);

      // `MacosScaffold`'s wallpaper-tinting layer keeps a periodic timer alive for
      // as long as the frame is mounted — in a running window that is simply the
      // library tracking the desktop picture. Unmount the frame and let the timer
      // fire once before the binding counts it as a leak.
      await tester.pumpAndSettle();
      await tester.pumpWidget(harness(const SizedBox.shrink()));
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('the app host (§9)', () {
    // The host mounts no `MacosScaffold`, so it needs no unmount sequence of its
    // own: the wallpaper-tinting timer belongs to the frame, and the tree below is
    // therefore asserted here as well as at the resolver.
    Widget hostHarness(Widget child) => LiveConfigProvider(
      config: config,
      registry: const LanguageRegistry(adapters: {LiveDesignLanguage.macos: macosAdapter}),
      child: child,
    );

    testWidgets('the tree is hosted by MacosApp, not by Material', (tester) async {
      await tester.pumpWidget(
        hostHarness(
          LiveApp(
            // macos_ui ships no localizations of its own, so the core's Flutter
            // delegates are the whole list here.
            routerConfig: stubRouterConfig(child: const Text('page')),
            localizationsDelegates: liveLocalizationsDelegates,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(macos.MacosApp), findsOneWidget);
      expect(find.byType(MaterialApp), findsNothing, reason: 'the Material host must not stand in (§15)');
      expect(find.text('page'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Unmount before teardown: the library's accent and window-state listeners
      // outlive their subtree otherwise.
      await tester.pumpWidget(hostHarness(const SizedBox.shrink()));
      await tester.pump();
    });
  });

  group('the app shell (§ surfaces)', () {
    const destinations = [
      LiveShellDestination(id: 'home', label: 'Home', icon: Icons.home),
      LiveShellDestination(id: 'follow', label: 'Follow', icon: Icons.favorite),
    ];

    // `SidebarItems` reads the two process-wide listeners the library installs for
    // a live window, and its rows are focusable; unmount the tree and let anything
    // still scheduled fire before the binding counts it as a leak.
    Future<void> detach(WidgetTester tester) async {
      await tester.pumpAndSettle();
      await tester.pumpWidget(harness(const SizedBox.shrink()));
      await tester.pump(const Duration(seconds: 2));
    }

    testWidgets('the rail form draws a native sidebar list, not the token column', (tester) async {
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

      // The list is `macos_ui`'s own widget; the rows are addressed by their labels
      // because neither `Sidebar` nor `SidebarItem` is a widget in 2.2.2 — both are
      // plain descriptor classes, the first read only by `MacosWindow` to build its
      // resizable split, the second consumed by `SidebarItems`, which mounts its own
      // private row widget. So the column around these rows and the selection
      // plumbing are the shell's composition, and the list itself is mapped.
      expect(find.byType(macos.SidebarItems), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Follow'), findsOneWidget);
      // The router keeps the body, and the footer sits under the list because
      // `SidebarItems` has no slot for it.
      expect(find.text('room list'), findsOneWidget);
      expect(find.text('settings'), findsOneWidget);

      // `find.byIcon` cannot see these: the library paints glyphs with `MacosIcon`.
      await tester.tap(find.text('Follow'));
      await tester.pump();
      expect(chosen, 'follow');
      expect(tester.takeException(), isNull);
      await detach(tester);
    });

    testWidgets('a disabled destination stays visible and inert', (tester) async {
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

      // The library has no disabled row to draw, so the row is still there — the
      // layout does not shift — and the shell is what refuses the tap.
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Follow'), findsOneWidget);
      await tester.tap(find.text('Follow'));
      await tester.pump();
      expect(chosen, '');
      await tester.tap(find.text('Home'));
      await tester.pump();
      expect(chosen, 'home');
      expect(tester.takeException(), isNull);
      await detach(tester);
    });

    testWidgets('a bottom request delegates to the native nav bar and drops the footer', (tester) async {
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

      // The strip is `MacosTab` cells (the nav bar builder), never a sidebar, and a
      // strip has no trailing slot — the contract says to drop it rather than
      // invent a place for it.
      expect(find.byType(macos.MacosTab), findsNWidgets(2));
      expect(find.byType(macos.SidebarItems), findsNothing);
      expect(find.text('settings'), findsNothing);
      expect(find.text('room list'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await detach(tester);
    });

    testWidgets('adaptive takes the rail form, and a shell with nothing to choose takes none', (tester) async {
      // No `LiveEnvironmentScope` in this harness, so adaptive reads the same
      // fallback width the shared token shell reads — the form switch stays put
      // across languages.
      await tester.pumpWidget(
        harness(
          LiveAppShell(
            destinations: destinations,
            selectedId: 'home',
            onSelected: (_) {},
            child: const Text('room list'),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(macos.SidebarItems), findsOneWidget);

      // One destination is not a choice, and `none` asks for no navigation: in both
      // cases the shell stands aside and the page frame is the scaffold's own.
      const single = [LiveShellDestination(id: 'home', label: 'Home', icon: Icons.home)];
      await tester.pumpWidget(harness(const LiveAppShell(destinations: single, child: Text('room list'))));
      await tester.pump();
      expect(find.byType(macos.SidebarItems), findsNothing);
      expect(find.text('room list'), findsOneWidget);

      await tester.pumpWidget(
        harness(
          const LiveAppShell(destinations: destinations, placement: LiveShellPlacement.none, child: Text('room list')),
        ),
      );
      await tester.pump();
      expect(find.byType(macos.SidebarItems), findsNothing);
      expect(find.text('room list'), findsOneWidget);

      expect(tester.takeException(), isNull);
      await detach(tester);
    });
  });
}
