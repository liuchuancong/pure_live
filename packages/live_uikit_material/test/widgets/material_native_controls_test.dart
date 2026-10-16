import 'package:flutter/foundation.dart' show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_material/live_uikit_material.dart';
import 'package:material_ui/material_ui.dart' as mu;

import 'stub_router.dart';

/// §16 widget tests for `live_uikit_material`.
///
/// Every control is driven through the real runtime path — a [LiveConfigProvider]
/// with the Material UI adapter registered, so `LiveButton`, `LiveSwitch`, …
/// dispatch to the native `material_ui` widgets rather than the shared renderer.
/// Assertions cover the contract rules in §9 (callback preservation, disabled /
/// loading gating, controlled value, controller passthrough) plus a render smoke
/// for the controls and the fallback path, so a break in the adapter→library
/// wiring fails here instead of in the app.
void main() {
  const config = UiConfig(language: LiveDesignLanguage.material, brightness: UiBrightnessMode.light);

  Widget harness(Widget child) => LiveConfigProvider(
    config: config,
    registry: const LanguageRegistry(
      adapters: {LiveDesignLanguage.material: materialAdapter},
      fallback: SharedLanguageAdapter(),
    ),
    child: MaterialApp(
      localizationsDelegates: const [...liveLocalizationsDelegates, ...materialLocalizationsDelegates],
      supportedLocales: const [Locale('en')],
      // No `mu.Material` here on purpose: the adapter's own theme scope installs
      // the fork ink surface (§8.2). A host should not have to know that.
      home: Scaffold(body: Center(child: child)),
    ),
  );

  // The fork picks `InkSparkle` — a fragment shader that `flutter test` does
  // not bundle — when the theme's platform is Android, which the test binding
  // reports by default. A pointer press on an enabled fork button then throws
  // while painting the ink. Driving the tap under a desktop platform makes the
  // fork choose `InkRipple` (no shader) instead; the binding's invariant check
  // runs before `tearDown`, so the override is restored here, not there.
  Future<void> withInkPlatform(Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  group('button (§9)', () {
    testWidgets('fires onPressed when enabled', (tester) async {
      var fired = false;
      await withInkPlatform(() async {
        await tester.pumpWidget(harness(LiveButton(label: 'Save', onPressed: () => fired = true)));
        await tester.tap(find.byType(LiveButton));
      });
      expect(fired, isTrue);
    });

    testWidgets('rejects input while loading', (tester) async {
      var fired = false;
      await tester.pumpWidget(harness(LiveButton(label: 'Save', loading: true, onPressed: () => fired = true)));
      await tester.tap(find.byType(LiveButton));
      expect(fired, isFalse);
    });
  });

  group('text field (§9)', () {
    testWidgets('preserves the caller controller and fires onChanged', (tester) async {
      final controller = TextEditingController(text: 'hi');
      String? changed;
      await tester.pumpWidget(harness(LiveTextField(controller: controller, onChanged: (v) => changed = v)));
      await tester.enterText(find.byType(EditableText), 'yo');
      await tester.pump();
      expect(controller.text, 'yo');
      expect(changed, 'yo');
    });
  });

  group('switch (§9)', () {
    testWidgets('reports the next value through onChanged', (tester) async {
      bool? value;
      await withInkPlatform(() async {
        await tester.pumpWidget(harness(LiveSwitch(value: false, onChanged: (v) => value = v)));
        await tester.tap(find.byType(LiveSwitch));
        await tester.pump();
      });
      expect(value, isTrue);
    });
  });

  group('checkbox (§9)', () {
    testWidgets('reports the next value through onChanged', (tester) async {
      bool? value;
      await withInkPlatform(() async {
        await tester.pumpWidget(harness(LiveCheckbox(value: false, onChanged: (v) => value = v)));
        await tester.tap(find.byType(LiveCheckbox));
        await tester.pump();
      });
      expect(value, isTrue);
    });
  });

  group('card (§9)', () {
    testWidgets('fires onTap when interactive', (tester) async {
      var tapped = false;
      await withInkPlatform(() async {
        await tester.pumpWidget(harness(LiveCard(onTap: () => tapped = true, child: const Text('body'))));
        await tester.tap(find.byType(LiveCard));
        await tester.pump();
      });
      expect(tapped, isTrue);
    });
  });

  group('native controls render through the Material UI adapter', () {
    testWidgets('slider, segmented and progress build without error', (tester) async {
      await tester.pumpWidget(
        harness(
          Column(
            children: [
              LiveSlider(value: 0.5, onChanged: (_) {}),
              LiveSegmented(labels: const ['A', 'B'], index: 0, onChanged: (_) {}),
              const LiveProgress(value: 0.5),
            ],
          ),
        ),
      );
      expect(find.byType(LiveSlider), findsOneWidget);
      expect(find.byType(LiveSegmented), findsOneWidget);
      expect(find.byType(LiveProgress), findsOneWidget);
    });
  });

  group('shared fallback (§15.3)', () {
    testWidgets('a control the adapter does not override still renders', (tester) async {
      // Material UI declares neither select nor tabs; they resolve through the
      // shared token renderer the adapter extends, so nothing disappears.
      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 400,
            child: LiveSelect<String>(items: const ['a', 'b'], itemLabel: (s) => s, onChanged: (_) {}),
          ),
        ),
      );
      expect(find.byType(LiveSelect<String>), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('button variants and preserved spec fields (§9/§16)', () {
    testWidgets('each variant selects its own Material class', (tester) async {
      await tester.pumpWidget(
        harness(
          Column(
            children: [
              LiveButton(label: 'p', onPressed: () {}),
              LiveButton(label: 's', variant: ButtonVariant.secondary, onPressed: () {}),
              LiveButton(label: 'g', variant: ButtonVariant.ghost, onPressed: () {}),
              LiveButton(label: 'd', variant: ButtonVariant.danger, onPressed: () {}),
            ],
          ),
        ),
      );
      // Primary and danger share the filled class; danger only differs by style.
      expect(find.byType(mu.FilledButton), findsNWidgets(2));
      expect(find.byType(mu.ElevatedButton), findsOneWidget);
      expect(find.byType(mu.TextButton), findsOneWidget);
    });

    testWidgets('danger carries the token error fill, not the generated scheme', (tester) async {
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
              LiveButton(label: 'Delete', variant: ButtonVariant.danger, onPressed: () {}),
            ],
          ),
        ),
      );
      final danger = tester.widget<mu.FilledButton>(
        find.byWidgetPredicate((widget) => widget is mu.FilledButton && widget.style != null),
      );
      // §8.1: where the token is authoritative the builder supplies the colour
      // explicitly instead of trusting the seed-derived palette.
      expect(danger.style?.backgroundColor?.resolve(const <WidgetState>{}), theme.colors.error);
      expect(danger.style?.foregroundColor?.resolve(const <WidgetState>{}), theme.colors.onPrimary);
    });

    testWidgets('a spec the seam calls non-interactive yields a dead button', (tester) async {
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
      final buttons = tester.widgetList<mu.FilledButton>(find.byType(mu.FilledButton)).toList();
      expect(buttons.map((button) => button.onPressed).every((pressed) => pressed == null), isTrue);
      await tester.tap(find.byType(LiveButton).last, warnIfMissed: false);
      expect(fired, isFalse);
    });

    testWidgets('focusNode, autofocus, expand and tooltip are preserved', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 320,
            child: LiveButton(
              label: 'Wide',
              focusNode: node,
              autofocus: true,
              expand: true,
              tooltip: 'Save it',
              onPressed: () {},
            ),
          ),
        ),
      );
      final button = tester.widget<mu.FilledButton>(find.byType(mu.FilledButton));
      expect(button.focusNode, same(node));
      expect(button.autofocus, isTrue);
      final wrappers = tester
          .widgetList<SizedBox>(find.ancestor(of: find.byType(mu.FilledButton), matching: find.byType(SizedBox)))
          .toList();
      expect(wrappers.any((box) => box.width == double.infinity), isTrue, reason: 'expand must claim the full width');
      final tip = tester.widget<mu.Tooltip>(find.byType(mu.Tooltip));
      expect(tip.message, 'Save it');
    });
  });

  group('card density, style override and focus (§9/§16)', () {
    testWidgets('dense tightens the padding and an explicit padding wins', (tester) async {
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
              const LiveCard(child: Text('c')),
            ],
          ),
        ),
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Padding && widget.padding == EdgeInsets.all(theme.card.padding * 0.66),
        ),
        findsOneWidget,
        reason: 'the dense step must be tighter than the token padding',
      );
      expect(
        find.byWidgetPredicate((widget) => widget is Padding && widget.padding == const EdgeInsets.all(21)),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((widget) => widget is Padding && widget.padding == EdgeInsets.all(theme.card.padding)),
        findsOneWidget,
      );
    });

    testWidgets('selected tints the surface and bordered keeps a side', (tester) async {
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
              const LiveCard(selected: true, bordered: true, child: Text('a')),
              const LiveCard(child: Text('b')),
            ],
          ),
        ),
      );
      final selectedCard = tester.widget<mu.Card>(
        find.byWidgetPredicate((widget) => widget is mu.Card && widget.color != null),
      );
      expect(selectedCard.color, theme.colors.primaryBg);
      final shape = selectedCard.shape! as mu.RoundedRectangleBorder;
      expect(shape.side.color, theme.colors.border);
      expect(shape.side.style, isNot(BorderStyle.none));
    });

    testWidgets('focus belongs to an interactive card only (§9)', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(harness(LiveCard(focusNode: node, child: const Text('quiet'))));
      expect(tester.widget<mu.InkWell>(find.byType(mu.InkWell)).focusNode, isNull);

      await tester.pumpWidget(harness(LiveCard(focusNode: node, onTap: () {}, child: const Text('tap'))));
      expect(tester.widget<mu.InkWell>(find.byType(mu.InkWell)).focusNode, same(node));
    });

    testWidgets('long press reaches the caller', (tester) async {
      var pressed = false;
      await withInkPlatform(() async {
        await tester.pumpWidget(harness(LiveCard(onLongPress: () => pressed = true, child: const Text('body'))));
        await tester.longPress(find.byType(LiveCard));
        await tester.pump();
      });
      expect(pressed, isTrue);
    });
  });

  group('progress, slider and segmented spec fields (§9/§16)', () {
    testWidgets('a null value stays indeterminate and the tint follows the spec', (tester) async {
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
              const LiveProgress(value: null, height: 12),
              const LiveProgress(value: 0.5, barColor: Color(0xFF00FF00)),
            ],
          ),
        ),
      );
      final bars = tester.widgetList<mu.LinearProgressIndicator>(find.byType(mu.LinearProgressIndicator)).toList();
      expect(bars.first.value, isNull, reason: 'null must stay the fork animation, not a determinate 0');
      expect(bars.first.minHeight, 12);
      expect(bars.last.color, const Color(0xFF00FF00));
      expect(bars.last.backgroundColor, theme.colors.fillSecondary);
    });

    testWidgets('showLabel degrades to no label, as documented (§15)', (tester) async {
      await tester.pumpWidget(harness(const LiveProgress(value: 0.5, showLabel: true)));
      expect(find.byType(mu.LinearProgressIndicator), findsOneWidget);
      expect(find.descendant(of: find.byType(mu.LinearProgressIndicator), matching: find.byType(Text)), findsNothing);
    });

    testWidgets('slider keeps its focus node; a disabled one takes the documented fallback', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(harness(LiveSlider(value: 0.5, onChanged: (_) {}, focusNode: node)));
      expect(tester.widget<mu.Slider>(find.byType(mu.Slider)).focusNode, same(node));

      // §15: `material_ui` 1.6.0 cannot build a disabled slider, so the shared
      // token renderer stands in — on-theme, still reading its value, no crash.
      await tester.pumpWidget(harness(LiveSlider(value: 0.5, enabled: false, onChanged: (_) {})));
      expect(find.byType(mu.Slider), findsNothing);
      expect(find.byType(LiveSlider), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(harness(const LiveSlider(value: 0.5, onChanged: null)));
      expect(find.byType(mu.Slider), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('expand uses the fork own expandedInsets', (tester) async {
      await tester.pumpWidget(
        harness(LiveSegmented(labels: const ['A', 'B'], index: 0, expand: true, onChanged: (_) {})),
      );
      expect(
        tester.widget<mu.SegmentedButton<int>>(find.byType(mu.SegmentedButton<int>)).expandedInsets,
        EdgeInsets.zero,
      );

      await tester.pumpWidget(harness(LiveSegmented(labels: const ['A', 'B'], index: 0, onChanged: (_) {})));
      expect(tester.widget<mu.SegmentedButton<int>>(find.byType(mu.SegmentedButton<int>)).expandedInsets, isNull);
    });
  });

  group('text field style override (§9)', () {
    testWidgets('an inline style overrides the token body text', (tester) async {
      await tester.pumpWidget(
        harness(
          const LiveTextField(
            placeholder: 'Name',
            style: Style(fontSize: 22, foreground: Color(0xFF0000FF), fontFamily: 'Monospace'),
          ),
        ),
      );
      final style = tester.widget<mu.TextField>(find.byType(mu.TextField)).style;
      expect(style?.fontSize, 22);
      expect(style?.color, const Color(0xFF0000FF));
      expect(style?.fontFamily, 'Monospace');
    });

    testWidgets('the caller controller identity survives a rebuild', (tester) async {
      final controller = TextEditingController(text: 'kept');
      addTearDown(controller.dispose);
      await tester.pumpWidget(harness(LiveTextField(controller: controller)));
      await tester.pumpWidget(harness(LiveTextField(controller: controller, placeholder: 'again')));
      expect(tester.widget<mu.TextField>(find.byType(mu.TextField)).controller, same(controller));
      expect(find.text('kept'), findsOneWidget);
    });
  });

  group('SDK Material never stands in (§15/§16)', () {
    testWidgets('every declared control renders through the fork', (tester) async {
      await tester.pumpWidget(
        harness(
          Column(
            children: [
              LiveButton(label: 'b', onPressed: () {}),
              const LiveCard(child: Text('c')),
              const LiveTextField(placeholder: 't'),
              LiveSwitch(value: true, onChanged: (_) {}),
              LiveCheckbox(value: false, label: 'ck', onChanged: (_) {}),
              LiveSlider(value: 0.5, onChanged: (_) {}),
              LiveSegmented(labels: const ['A', 'B'], index: 0, onChanged: (_) {}),
              const LiveProgress(value: 0.5),
            ],
          ),
        ),
      );
      // The fork deliberately shadows these SDK names, and `find.byType` matches
      // the exact runtime type, so an SDK class appearing here means the `mu`
      // prefix convention slipped and the SDK rendered the control instead.
      for (final sdkType in <Type>[
        FilledButton,
        ElevatedButton,
        TextButton,
        Card,
        TextField,
        Switch,
        Checkbox,
        Slider,
        SegmentedButton,
        LinearProgressIndicator,
        Tooltip,
      ]) {
        expect(find.byType(sdkType), findsNothing, reason: 'the SDK $sdkType must not render this control');
      }
      expect(find.byType(mu.Theme), findsWidgets, reason: 'the fork theme scope is installed');
      expect(tester.takeException(), isNull);
    });
  });

  group('a dead control stays dead (§9 disabled semantics)', () {
    testWidgets('switch, checkbox, segmented and text field all survive being disabled', (tester) async {
      await tester.pumpWidget(
        harness(
          Column(
            children: [
              LiveSwitch(value: true, enabled: false, onChanged: (_) {}),
              LiveCheckbox(value: true, enabled: false, onChanged: (_) {}),
              LiveSegmented(labels: const ['A', 'B'], index: 0, enabled: false, onChanged: (_) {}),
              const LiveTextField(enabled: false, placeholder: 'locked'),
              const LiveButton(label: 'off'),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(mu.Switch), findsOneWidget);
      expect(find.byType(mu.Checkbox), findsOneWidget);
      expect(find.byType(mu.SegmentedButton<int>), findsOneWidget);
      expect(tester.widget<mu.TextField>(find.byType(mu.TextField)).enabled, isFalse);
      expect(tester.widget<mu.FilledButton>(find.byType(mu.FilledButton)).onPressed, isNull);
    });

    testWidgets('a null callback disables just as hard as enabled: false', (tester) async {
      await tester.pumpWidget(
        harness(
          const Column(
            children: [
              LiveSwitch(value: false, onChanged: null),
              LiveCheckbox(value: false, onChanged: null),
              LiveSegmented(labels: ['A', 'B'], index: 0, onChanged: null),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.widget<mu.Switch>(find.byType(mu.Switch)).onChanged, isNull);
      expect(tester.widget<mu.Checkbox>(find.byType(mu.Checkbox)).onChanged, isNull);
      expect(tester.widget<mu.SegmentedButton<int>>(find.byType(mu.SegmentedButton<int>)).onSelectionChanged, isNull);
    });
  });

  group('localisation and layout (§14/§16)', () {
    testWidgets('RTL layout keeps controls readable at a narrow width', (tester) async {
      await tester.pumpWidget(
        harness(
          Directionality(
            textDirection: TextDirection.rtl,
            child: SizedBox(
              width: 320,
              child: Column(
                children: [
                  LiveButton(label: 'حفظ الإعدادات', tooltip: 'حفظ', expand: true, onPressed: () {}),
                  LiveSegmented(labels: const ['أول', 'ثانٍ', 'ثالث'], index: 1, expand: true, onChanged: (_) {}),
                  LiveCheckbox(value: true, label: 'تفعيل الوضع الليلي', onChanged: (_) {}),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('ثانٍ'), findsOneWidget);
      expect(find.text('تفعيل الوضع الليلي'), findsOneWidget);
    });

    testWidgets('the core localizer still resolves with the fork delegate appended (§14)', (tester) async {
      MaterialLocalizations? core;
      mu.MaterialLocalizations? fork;
      await tester.pumpWidget(
        harness(
          Builder(
            builder: (context) {
              core = MaterialLocalizations.of(context);
              fork = mu.MaterialLocalizations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      // Ordering matters (§14): the fork's delegate is appended after the core's,
      // so both resolve and neither shadows the other's strings.
      expect(core?.cancelButtonLabel, isNotEmpty);
      expect(fork?.cancelButtonLabel, isNotEmpty);
    });
  });

  group('chrome (§9)', () {
    testWidgets('the frame, bar, row and bottom strip render through the fork', (tester) async {
      var taps = 0;
      var picked = -1;
      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 640,
            height: 480,
            child: LiveScaffold(
              appBar: const LiveAppBar(title: 'Rooms'),
              body: LiveListRow(title: 'Accent', subtitle: 'violet', onTap: () => taps++),
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
        ),
      );

      expect(find.byType(mu.Scaffold), findsOneWidget);
      expect(find.byType(mu.AppBar), findsOneWidget);
      expect(find.byType(mu.ListTile), findsOneWidget);
      expect(find.byType(mu.NavigationBar), findsOneWidget);
      for (final tokenType in <Type>[TokenScaffold, TokenAppBar, TokenListRow, TokenNavBar]) {
        expect(find.byType(tokenType), findsNothing, reason: 'the token $tokenType must not render a declared control');
      }
      expect(tester.takeException(), isNull);

      await withInkPlatform(() async {
        await tester.tap(find.byType(mu.ListTile));
        await tester.pump();
        expect(taps, 1);

        await tester.tap(find.text('More'));
        await tester.pump();
        expect(picked, 1, reason: 'the bar reports a destination index, not a route');
      });
    });

    testWidgets('a disabled bottom strip keeps its destinations and stops reporting', (tester) async {
      var picked = -1;
      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 640,
            child: LiveNavBar(
              items: const [
                LiveNavBarItem(label: 'Home', icon: Icons.home),
                LiveNavBarItem(label: 'More', icon: Icons.more_horiz),
              ],
              index: 0,
              enabled: false,
              onChanged: (i) => picked = i,
            ),
          ),
        ),
      );
      final bar = tester.widget<mu.NavigationBar>(find.byType(mu.NavigationBar));
      expect(bar.onDestinationSelected, isNull);
      await withInkPlatform(() async {
        await tester.tap(find.text('Home'));
        await tester.pump();
      });
      expect(picked, -1);
    });

    testWidgets('a strip the library cannot assert for falls to the shared renderer', (tester) async {
      // The fork requires two destinations and an in-range selection; a shell whose
      // list shrank under a saved index would otherwise crash the page.
      await tester.pumpWidget(
        harness(
          const SizedBox(
            width: 640,
            child: LiveNavBar(
              items: [LiveNavBarItem(label: 'Home', icon: Icons.home)],
              index: 3,
            ),
          ),
        ),
      );
      expect(find.byType(mu.NavigationBar), findsNothing);
      expect(find.byType(TokenNavBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the app host (§9)', () {
    // No outer `MaterialApp` here: the host under test is the app widget, and a
    // fork host pumped inside the SDK one would pass while no real page looks
    // like that.
    Widget hostHarness(Widget child) => LiveConfigProvider(
      config: config,
      registry: const LanguageRegistry(
        adapters: {LiveDesignLanguage.material: materialAdapter},
        fallback: SharedLanguageAdapter(),
      ),
      child: child,
    );

    testWidgets('the tree is hosted by the fork, not by the SDK Material app', (tester) async {
      await tester.pumpWidget(
        hostHarness(
          LiveApp(
            routerConfig: stubRouterConfig(child: const Text('page')),
            localizationsDelegates: liveLocalizationsDelegates,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(mu.MaterialApp), findsOneWidget);
      expect(find.byType(MaterialApp), findsNothing, reason: 'the SDK host must not stand in (§15)');
      expect(find.byType(TokenApp), findsNothing);
      expect(find.text('page'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the fork host carries the theme the token resolved, not the platform one', (tester) async {
      // The test binding reports a light platform; the appearance says dark, so
      // the host has to follow the token rather than re-pick by brightness.
      late mu.ThemeData hosted;
      await tester.pumpWidget(
        LiveConfigProvider(
          config: const UiConfig(language: LiveDesignLanguage.material, brightness: UiBrightnessMode.dark),
          registry: const LanguageRegistry(
            adapters: {LiveDesignLanguage.material: materialAdapter},
            fallback: SharedLanguageAdapter(),
          ),
          child: LiveApp(
            routerConfig: stubRouterConfig(
              child: Builder(
                builder: (context) {
                  hosted = mu.Theme.of(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
            localizationsDelegates: liveLocalizationsDelegates,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(hosted.brightness, Brightness.dark);
      expect(hosted.scaffoldBackgroundColor, isNot(const Color(0xFFFFFFFF)));
    });
  });
}
