import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_neumorphic/live_uikit_neumorphic.dart';

import 'stub_router.dart';

/// §16 widget tests for `live_uikit_neumorphic`, driving the `Live*` controls
/// through the real runtime so they render with the native
/// `flutter_neumorphic_ui_kit` widgets.
void main() {
  const config = UiConfig(language: LiveDesignLanguage.neumorphic, brightness: UiBrightnessMode.light);

  Widget harness(Widget child) => LiveConfigProvider(
    config: config,
    registry: const LanguageRegistry(
      adapters: {LiveDesignLanguage.neumorphic: neumorphicAdapter},
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

  testWidgets('text field preserves the caller controller (§9)', (tester) async {
    final controller = TextEditingController(text: 'hi');
    await tester.pumpWidget(harness(SizedBox(width: 260, child: LiveTextField(controller: controller))));
    await tester.enterText(find.byType(EditableText), 'yo');
    await tester.pump();
    expect(controller.text, 'yo');
    // The Neumorphic field forwards only controller/focus, not onChanged, so the
    // change callback is intentionally not asserted here (§9 limitation).
  });

  testWidgets('switch reports the next value (§9)', (tester) async {
    bool? value;
    await tester.pumpWidget(harness(LiveSwitch(value: false, onChanged: (v) => value = v)));
    await tester.tap(find.byType(LiveSwitch));
    await tester.pump();
    expect(value, isTrue);
  });

  testWidgets('checkbox reports the next value (§9)', (tester) async {
    bool? value;
    await tester.pumpWidget(harness(LiveCheckbox(value: false, onChanged: (v) => value = v)));
    await tester.tap(find.byType(LiveCheckbox));
    await tester.pump();
    expect(value, isTrue);
  });

  testWidgets('card and slider render through the Neumorphic adapter', (tester) async {
    await tester.pumpWidget(
      harness(
        SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LiveCard(onTap: () {}, child: const Text('b')),
              LiveSlider(value: 0.5, onChanged: (_) {}),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(LiveCard), findsOneWidget);
    expect(find.byType(LiveSlider), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('segmented domes the chosen cell and reports its index (§9)', (tester) async {
    var index = -1;
    await tester.pumpWidget(
      harness(
        SizedBox(
          width: 300,
          child: LiveSegmented(labels: const ['A', 'B', 'C'], index: 1, onChanged: (i) => index = i),
        ),
      ),
    );
    // The composed track is the library's own plane, never the token renderer.
    expect(find.byType(TokenSegmented), findsNothing);
    expect(tester.widgetList<neu.NeuContainer>(find.byType(neu.NeuContainer)).length, greaterThanOrEqualTo(4));
    await tester.tap(find.text('C'));
    await tester.pump();
    expect(index, 2);
  });

  testWidgets('progress maps to the library bar and carries the label (§9)', (tester) async {
    await tester.pumpWidget(harness(const SizedBox(width: 300, child: LiveProgress(value: 0.5, showLabel: true))));
    expect(find.byType(neu.NeuProgressBar), findsOneWidget);
    expect(find.byType(TokenProgress), findsNothing);
    expect(find.text('50%'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('select opens inline and reports the typed value (§9)', (tester) async {
    String? picked;
    await tester.pumpWidget(
      harness(
        SizedBox(
          width: 260,
          child: LiveSelect<String>(items: const ['a', 'b'], itemLabel: (s) => s, onChanged: (v) => picked = v),
        ),
      ),
    );
    expect(find.byType(TokenSelect<String>), findsNothing);
    expect(find.text('b'), findsNothing);

    // The dish opens in the tree: no overlay, no ScaffoldMessenger, no Navigator.
    await tester.tap(find.byType(LiveSelect<String>));
    await tester.pump();
    expect(find.text('b'), findsOneWidget);
    await tester.tap(find.text('b'));
    await tester.pump();
    expect(picked, 'b');
    // The dish closes on a choice, and the strip is controlled like every other
    // path here: the field only shows the value the caller hands back.
    expect(find.text('a'), findsNothing);
    await tester.pumpWidget(
      harness(
        SizedBox(
          width: 260,
          child: LiveSelect<String>(
            items: const ['a', 'b'],
            itemLabel: (s) => s,
            value: picked,
            onChanged: (v) => picked = v,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('b'), findsOneWidget);
    expect(find.text('a'), findsNothing);
  });

  testWidgets('tab bar is a composed strip, not the library bottom nav (§9)', (tester) async {
    var index = -1;
    await tester.pumpWidget(
      harness(
        LiveTabs(
          tabs: const [
            LiveTab(label: 'One'),
            LiveTab(label: 'Two', icon: Icons.star),
          ],
          index: 0,
          spacing: 6,
          onChanged: (i) => index = i,
        ),
      ),
    );
    expect(find.byType(TokenTabs), findsNothing);
    expect(find.byType(neu.NeuBottomNav), findsNothing);
    expect(find.byIcon(Icons.star), findsOneWidget);
    await tester.tap(find.text('Two'));
    await tester.pump();
    expect(index, 1);
  });

  testWidgets('toast draws the Neumorphic pill in the core overlay (§9)', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      harness(
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    LiveToast.show(context, 'Saved', type: LiveToastType.success);
    await tester.pump();
    expect(find.text('Saved'), findsOneWidget);
    expect(find.byType(TokenToast), findsNothing);

    // The lifetime timer and the fade belong to the core; the pill just has to
    // survive them, so the test outlives the message instead of leaving a timer.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);
  });

  group('chrome (§9)', () {
    testWidgets("a page frame is the library's plane, not the token frame", (tester) async {
      var action = 0;
      await tester.pumpWidget(
        harness(
          LiveScaffold(
            appBar: const LiveAppBar(title: 'Rooms'),
            body: const Text('content'),
            floatingActionButton: LiveButton(label: 'Go', onPressed: () => action++),
            bottomBar: LiveNavBar(
              items: const [
                LiveNavBarItem(label: 'Home', icon: Icons.home),
                LiveNavBarItem(label: 'Follow', icon: Icons.favorite),
              ],
              index: 0,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      // Nothing above this point is Material's frame: the page surface is a
      // `NeuContainer` filled by the stacked bars, and every one of them resolved
      // through this package.
      expect(find.byType(TokenScaffold), findsNothing);
      expect(find.byType(TokenAppBar), findsNothing);
      expect(find.byType(TokenNavBar), findsNothing);
      expect(find.text('content'), findsOneWidget);
      expect(find.text('Rooms'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Go'));
      await tester.pump();
      expect(action, 1, reason: 'the floating action is placed by the frame and still fires');
    });

    testWidgets('the frame extends the body behind the bar and keeps the keyboard clear', (tester) async {
      await tester.pumpWidget(
        harness(
          const LiveScaffold(
            appBar: LiveAppBar(title: 'Cover'),
            body: Text('behind'),
            extendBodyBehindAppBar: true,
            avoidKeyboard: false,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(TokenScaffold), findsNothing);
      expect(find.text('behind'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets("the bar is the library's own, and its strip stacks beneath the title", (tester) async {
      var tab = -1;
      var action = 0;
      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 420,
            child: LiveAppBar(
              title: 'Rooms',
              leading: LiveButton(label: 'Back', onPressed: () => action++),
              actions: const [Icon(Icons.share)],
              bottom: LiveTabs(
                tabs: const [
                  LiveTab(label: 'Live'),
                  LiveTab(label: 'Off'),
                ],
                index: 0,
                onChanged: (i) => tab = i,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(neu.NeuAppBar), findsOneWidget);
      expect(find.byType(TokenAppBar), findsNothing);
      expect(find.text('Rooms'), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
      // The dispatched strip has no `PreferredSizeWidget` to offer the library's
      // `bottom` slot, so the bar stacks it under the title row instead.
      expect(find.text('Off'), findsOneWidget);
      await tester.tap(find.text('Off'));
      await tester.pump();
      expect(tab, 1);
      await tester.tap(find.text('Back'));
      await tester.pump();
      expect(action, 1);
    });

    testWidgets('a row is a composed plane that dishes when selected', (tester) async {
      var taps = 0;
      var pressed = 0;
      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 320,
            child: LiveListRow(
              title: 'Accent',
              subtitle: 'violet',
              leading: const Icon(Icons.circle),
              trailing: const Icon(Icons.chevron_right),
              selected: true,
              divided: false,
              onTap: () => taps++,
              onLongPress: () => pressed++,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(TokenListRow), findsNothing);
      expect(find.text('Accent'), findsOneWidget);
      expect(find.text('violet'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      // A selected row states itself with depth, so the plane is a pressed dish.
      final dishes = tester
          .widgetList<neu.NeuContainer>(find.byType(neu.NeuContainer))
          .where((container) => container.shape == neu.NeuShape.pressed);
      expect(dishes, hasLength(1));

      await tester.tap(find.text('Accent'));
      await tester.pump();
      expect(taps, 1);
      await tester.longPress(find.text('Accent'));
      await tester.pump();
      expect(pressed, 1);

      // The hairline is the row's own: the library has no divider to borrow, so the
      // branch that draws one is taken with the widget's default `divided`.
      await tester.pumpWidget(
        harness(
          const SizedBox(
            width: 320,
            child: LiveListRow(title: 'Accent', subtitle: 'violet'),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('violet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a row hands its focus node to the focus tree and activates from it', (tester) async {
      var taps = 0;
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(harness(LiveListRow(title: 'Focused', focusNode: node, onTap: () => taps++)));
      expect(tester.widget<neu.NeuContainer>(find.byType(neu.NeuContainer)).depth, 0, reason: 'an idle row is flat');
      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(taps, 1, reason: 'the row answers activation, not just a tap');
    });

    testWidgets('a destination bar is composed, never the library bottom nav', (tester) async {
      var chosen = -1;
      Widget bar(ValueChanged<int>? onChanged) => LiveNavBar(
        items: const [
          LiveNavBarItem(label: 'Home', icon: Icons.home),
          LiveNavBarItem(label: 'Follow', icon: Icons.favorite),
        ],
        index: 0,
        onChanged: onChanged,
      );

      await tester.pumpWidget(harness(SizedBox(width: 360, child: bar((i) => chosen = i))));
      await tester.pump();
      expect(find.byType(neu.NeuBottomNav), findsNothing);
      expect(find.byType(TokenNavBar), findsNothing);
      await tester.tap(find.text('Follow'));
      await tester.pump();
      expect(chosen, 1);

      // Disabled: the destinations keep their labels and stop reporting.
      await tester.pumpWidget(harness(SizedBox(width: 360, child: bar(null))));
      await tester.pump();
      await tester.tap(find.text('Follow'));
      await tester.pump();
      expect(chosen, 1, reason: 'a disabled bar keeps its destinations and loses its callbacks');

      // One destination is a legal bar here, and `NeuBottomNav` asserts it away.
      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 360,
            child: LiveNavBar(
              items: const [LiveNavBarItem(label: 'Home', icon: Icons.home)],
              index: 0,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a Neumorphic page holds no token renderer at all (§15.3)', (tester) async {
      await tester.pumpWidget(
        harness(
          LiveScaffold(
            appBar: LiveAppBar(
              title: 'Rooms',
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
                const LiveListRow(title: 'Row'),
                LiveSegmented(labels: const ['A', 'B'], index: 0, onChanged: (_) {}),
                LiveNavBar(
                  items: const [
                    LiveNavBarItem(label: 'Home', icon: Icons.home),
                    LiveNavBarItem(label: 'Follow', icon: Icons.favorite),
                  ],
                  index: 1,
                  onChanged: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      // This language declares all fifteen controls, so nothing inside a Neumorphic
      // page may be a `Token*` renderer any more — asserted by name rather than by
      // list, so a control added to the contract cannot slip in silently.
      expect(find.byWidgetPredicate((widget) => widget.runtimeType.toString().startsWith('Token')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('disabled state and preserved spec fields (§9/§16)', () {
    testWidgets('a null callback disables the checkbox instead of faking one', (tester) async {
      await tester.pumpWidget(harness(const LiveCheckbox(value: false, onChanged: null)));
      expect(tester.widget<neu.NeuCheckbox>(find.byType(neu.NeuCheckbox)).onChanged, isNull);
      await tester.pumpWidget(harness(LiveCheckbox(value: false, enabled: false, onChanged: (_) {})));
      expect(tester.widget<neu.NeuCheckbox>(find.byType(neu.NeuCheckbox)).onChanged, isNull);
      await tester.pumpWidget(harness(LiveCheckbox(value: false, onChanged: (_) {})));
      expect(tester.widget<neu.NeuCheckbox>(find.byType(neu.NeuCheckbox)).onChanged, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the field passes the caller state through', (tester) async {
      final controller = TextEditingController(text: 'kept');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        harness(
          LiveTextField(
            controller: controller,
            placeholder: 'Name',
            errorText: 'Required',
            prefix: const Icon(Icons.person),
            obscure: true,
            enabled: false,
          ),
        ),
      );
      final field = tester.widget<neu.NeuTextField>(find.byType(neu.NeuTextField));
      expect(field.controller, same(controller));
      expect(field.hintText, 'Name');
      expect(field.errorText, 'Required');
      expect(field.obscureText, isTrue);
      expect(field.enabled, isFalse);
      expect(field.prefixIcon, isNotNull);
      // `maxLines` collapses to one line while obscured, the core contract (§9).
      expect(field.maxLines, 1);
    });

    testWidgets('the card keeps dense and explicit padding', (tester) async {
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
            ],
          ),
        ),
      );
      final paddings = tester.widgetList<neu.NeuCard>(find.byType(neu.NeuCard)).map((card) => card.padding).toList();
      expect(paddings, contains(EdgeInsets.all(theme.card.padding * 0.66)));
      expect(paddings, contains(const EdgeInsets.all(21)));
    });

    testWidgets('the card wires a tap, a long press, and an onLongPress-only caller', (tester) async {
      var tapped = false;
      var pressed = false;
      await tester.pumpWidget(harness(LiveCard(onTap: () => tapped = true, child: const Text('a'))));
      await tester.tap(find.byType(LiveCard));
      expect(tapped, isTrue);

      await tester.pumpWidget(harness(LiveCard(onLongPress: () => pressed = true, child: const Text('b'))));
      // §9: the gesture layer goes in for either callback; an `onTap`-only
      // check here silently dropped the long press.
      await tester.longPress(find.byType(LiveCard));
      expect(pressed, isTrue);
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
          .widgetList<SizedBox>(find.ancestor(of: find.byType(neu.NeuButton), matching: find.byType(SizedBox)))
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
      expect(tester.widget<neu.NeuTextField>(find.byType(neu.NeuTextField)).focusNode, same(node));
      node.requestFocus();
      await tester.pump();
      expect(node.hasFocus, isTrue, reason: 'the node reached the focus tree, not just the widget');
    });
  });

  group('the app host (§ surfaces)', () {
    // No outer `MaterialApp` here: the host under test *is* the app widget, and
    // pumping it inside the SDK one would pass while no real page looks like
    // that — and it is the SDK host the token base would fall back to.
    Widget hostHarness(Widget child) => LiveConfigProvider(
      config: config,
      registry: const LanguageRegistry(
        adapters: {LiveDesignLanguage.neumorphic: neumorphicAdapter},
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
      expect(find.byType(neu.NeuTheme), findsWidgets);
      expect(find.text('page'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
