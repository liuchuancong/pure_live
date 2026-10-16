import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_macos/live_uikit_macos.dart';
import 'package:macos_ui/macos_ui.dart' as macos;

import 'stub_router.dart';

/// §16 widget tests for `live_uikit_macos`, driven through the real runtime path
/// so `Live*` controls dispatch to the native `macos_ui` widgets.
void main() {
  const config = UiConfig(language: LiveDesignLanguage.macos, brightness: UiBrightnessMode.light);

  Widget harness(Widget child) => LiveConfigProvider(
    config: config,
    registry: const LanguageRegistry(
      adapters: {LiveDesignLanguage.macos: macosUiAdapter},
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

  testWidgets('an unoverridden control still renders via the shared fallback', (tester) async {
    await tester.pumpWidget(harness(LiveSwitch(value: false, onChanged: (_) {})));
    expect(find.byType(LiveSwitch), findsOneWidget);
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

    testWidgets('a disabled slider takes the documented shared fallback', (tester) async {
      // `MacosSlider.onChanged` is required, so the fork cannot draw a dead
      // slider; the token renderer stands in instead of a swallow-the-value
      // closure (§9/§15).
      await tester.pumpWidget(harness(const SizedBox(width: 300, child: LiveSlider(value: 0.5, onChanged: null))));
      expect(find.byType(macos.MacosSlider), findsNothing);
      expect(find.byType(LiveSlider), findsOneWidget);
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
    // The frame and the bar are asserted at the resolver (§16.3) rather than
    // by pumping them here: macos_ui's wallpaper-tinting layer keeps a periodic
    // timer alive behind `MacosScaffold`/`ToolBar`, which the test binding counts
    // as a leaked timer at teardown. In a running window that timer is simply the
    // library tracking the desktop picture.
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

  group('the app host (§9)', () {
    // `MacosApp` is the one piece of this language that can be pumped: the
    // wallpaper-tinting timer the frame and the bar start belongs to
    // `MacosScaffold`, and the host does not mount one — so the tree below is
    // asserted here rather than only at the resolver, unlike the frame.
    Widget hostHarness(Widget child) => LiveConfigProvider(
      config: config,
      registry: const LanguageRegistry(
        adapters: {LiveDesignLanguage.macos: macosUiAdapter},
        fallback: SharedLanguageAdapter(),
      ),
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
      expect(find.byType(TokenApp), findsNothing);
      expect(find.text('page'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Unmount before teardown: the library's accent and window-state listeners
      // outlive their subtree otherwise.
      await tester.pumpWidget(hostHarness(const SizedBox.shrink()));
      await tester.pump();
    });
  });
}
