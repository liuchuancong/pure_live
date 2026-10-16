import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/styling.dart';

import 'stub_router.dart';

/// The shared token renderer is the floor every adapter has to meet: an
/// unregistered language, and every control a registered language does not
/// override, is drawn here (§3.1). So its spec-field fidelity is tested the same
/// way the adapters' is — a field a caller sets either reaches the screen or the
/// suite says so.
void main() {
  Widget harness(Widget child) => LiveConfigProvider(
    config: const UiConfig(),
    child: MaterialApp(home: Scaffold(body: child)),
  );

  /// The field's painted box — scoped to the renderer, because the app shell is
  /// allowed to animate containers of its own.
  Finder fieldSurface(WidgetTester tester) =>
      find.descendant(of: find.byType(TokenTextField), matching: find.byType(AnimatedContainer));

  group('the base renders and reports', () {
    testWidgets('every leaf control of the contract draws from one config, with no adapter registered', (tester) async {
      late LiveTheme theme;
      await tester.pumpWidget(
        harness(
          Builder(
            builder: (context) {
              theme = LiveTheme.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(theme.adapter, isA<SharedLanguageAdapter>());
      expect(theme.implementationKind, LiveImplementationKind.shared);
      for (final control in LiveUiControl.values) {
        expect(theme.supports(control), isFalse, reason: '$control is not native to the token base');
      }

      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  LiveButton(label: 'Go', onPressed: () {}),
                  LiveIconButton(icon: Icons.star, tooltip: 'Star', onPressed: () {}),
                  const LiveCard(child: Text('card')),
                  const LiveTextField(placeholder: 'name'),
                  LiveSwitch(value: true, onChanged: (_) {}),
                  LiveCheckbox(value: false, label: 'check', onChanged: (_) {}),
                  LiveSlider(value: 0.4, onChanged: (_) {}),
                  LiveSegmented(labels: const ['a', 'b'], index: 0, onChanged: (_) {}),
                  const LiveProgress(value: 0.5),
                  LiveSelect<String>(items: const ['x'], itemLabel: (v) => v, onChanged: (_) {}),
                  LiveTabs(
                    tabs: const [
                      LiveTab(label: 't1'),
                      LiveTab(label: 't2'),
                    ],
                    index: 0,
                    onChanged: (_) {},
                  ),
                  LiveNavBar(
                    items: const [LiveNavBarItem(label: 'Home', icon: Icons.home)],
                    index: 0,
                    onChanged: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('card'), findsOneWidget);
      expect(find.byType(TokenCard), findsOneWidget);
      expect(find.byType(TokenTabs), findsOneWidget);
      expect(find.byType(TokenNavBar), findsOneWidget);
    });

    testWidgets('the chrome renders the frame, the bar and the row', (tester) async {
      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 420,
            height: 600,
            child: LiveScaffold(
              appBar: LiveAppBar(
                title: 'Rooms',
                actions: [LiveButton(label: 'Add', onPressed: () {})],
              ),
              bottomBar: const LiveListRow(title: 'row', subtitle: 'under it'),
              floatingActionButton: LiveButton(label: 'Go', onPressed: () {}),
              body: const Center(child: Text('content')),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(TokenScaffold), findsOneWidget);
      expect(find.byType(TokenAppBar), findsOneWidget);
      expect(find.byType(TokenListRow), findsOneWidget);
      expect(find.text('content'), findsOneWidget);
      // The bar titles itself as a header, so a screen reader still hears it
      // after the language changes and the font no longer does the work.
      expect(find.bySemanticsLabel('Rooms'), findsOneWidget);
    });

    testWidgets('the base hosts the app in Material, seeded from the token', (tester) async {
      await tester.pumpWidget(
        LiveConfigProvider(
          config: const UiConfig(),
          child: LiveApp(routerConfig: stubRouterConfig()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TokenApp), findsOneWidget);
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('button', () {
    testWidgets('a tap reaches the caller and a null callback does not', (tester) async {
      var taps = 0;
      await tester.pumpWidget(harness(LiveButton(key: const Key('b'), label: 'Go', onPressed: () => taps++)));
      await tester.tap(find.byType(LiveBox));
      expect(taps, 1);

      await tester.pumpWidget(harness(const LiveButton(label: 'Go')));
      await tester.tap(find.byType(LiveBox));
      expect(taps, 1, reason: 'no callback means no press, not a swallowed one');
      expect(tester.widget<LiveBox>(find.byType(LiveBox)).enabled, isFalse);
    });

    testWidgets('loading swaps the label for a spinner and rejects input', (tester) async {
      var taps = 0;
      await tester.pumpWidget(harness(LiveButton(label: 'Go', loading: true, onPressed: () => taps++)));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Go'), findsNothing);
      await tester.tap(find.byType(LiveBox));
      expect(taps, 0);
    });

    testWidgets('expand claims the parent width and tooltip wraps the control', (tester) async {
      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 300,
            child: LiveButton(label: 'Go', expand: true, tooltip: 'go hint', onPressed: () {}),
          ),
        ),
      );
      expect(tester.getSize(find.byType(LiveButton)).width, 300);
      expect(find.byType(Tooltip), findsOneWidget);
      expect(tester.widget<Tooltip>(find.byType(Tooltip)).message, 'go hint');
    });

    testWidgets('an inline style is the top layer of the recipe', (tester) async {
      await tester.pumpWidget(
        harness(
          LiveButton(
            label: 'Go',
            style: const Style(background: Color(0xFF123456)),
            onPressed: () {},
          ),
        ),
      );
      final painted = tester.widget<AnimatedContainer>(
        find.descendant(of: find.byType(LiveBox), matching: find.byType(AnimatedContainer)),
      );
      expect((painted.decoration! as BoxDecoration).color, const Color(0xFF123456));
      final sized = tester.widget<ConstrainedBox>(
        find.descendant(of: find.byType(LiveBox), matching: find.byType(ConstrainedBox)),
      );
      expect(sized.constraints.minHeight, 32, reason: 'the override names only the fill; the recipe keeps the height');
    });

    testWidgets('an icon with a leading glyph keeps its label', (tester) async {
      await tester.pumpWidget(harness(LiveButton(label: 'Star', icon: Icons.star, onPressed: () {})));
      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.text('Star'), findsOneWidget);
    });
  });

  group('card', () {
    testWidgets('tapping an interactive card reaches the caller', (tester) async {
      var taps = 0;
      await tester.pumpWidget(harness(LiveCard(onTap: () => taps++, child: const Text('body'))));
      await tester.tap(find.text('body'));
      expect(taps, 1);
    });

    testWidgets('the spec fields drive the painted surface', (tester) async {
      Style styleOf() => tester.widget<LiveBox>(find.byType(LiveBox)).style(InteractionState.normal);
      await tester.pumpWidget(harness(const LiveCard(bordered: true, child: Text('body'))));
      expect(styleOf().borderColor, isNotNull, reason: 'bordered asks for the hairline');

      await tester.pumpWidget(harness(const LiveCard(selected: true, child: Text('body'))));
      expect(styleOf().borderColor, LiveTheme.of(tester.element(find.byType(LiveBox))).colors.primary);
      expect(styleOf().shadow, isNotNull);

      await tester.pumpWidget(harness(const LiveCard(dense: true, child: Text('body'))));
      final theme = LiveTheme.of(tester.element(find.byType(LiveBox)));
      expect(styleOf().padding, EdgeInsets.all(theme.card.padding * 0.66));

      await tester.pumpWidget(
        harness(
          const LiveCard(
            padding: EdgeInsets.all(3),
            style: Style(background: Color(0xFF123456)),
            child: Text('body'),
          ),
        ),
      );
      expect(styleOf().padding, const EdgeInsets.all(3), reason: 'an explicit padding outranks the token density step');
      expect(
        tester.widget<LiveBox>(find.byType(LiveBox)).inlineStyle?.background,
        const Color(0xFF123456),
        reason: 'the caller override is carried and applied last',
      );
    });

    testWidgets('a non-interactive card stays quiet under the cursor', (tester) async {
      await tester.pumpWidget(harness(const LiveCard(child: Text('body'))));
      final box = tester.widget<LiveBox>(find.byType(LiveBox));
      expect(box.onTap, isNull);
      expect(box.enabled, isTrue);
    });
  });

  group('text field', () {
    testWidgets('the caller-owned controller and callbacks pass through', (tester) async {
      final controller = TextEditingController(text: 'seed');
      String? changed;
      await tester.pumpWidget(harness(LiveTextField(controller: controller, onChanged: (v) => changed = v)));
      await tester.enterText(find.byType(TextField), 'typed');
      expect(changed, 'typed');
      expect(controller.text, 'typed', reason: 'a field handed a controller must not keep its own');
      controller.dispose();
    });

    testWidgets('an owned controller appears when the caller brings none', (tester) async {
      await tester.pumpWidget(harness(const LiveTextField(placeholder: 'name')));
      expect(tester.widget<TextField>(find.byType(TextField)).decoration!.hintText, 'name');
      await tester.enterText(find.byType(TextField), 'free');
      expect(find.text('free'), findsOneWidget, reason: 'the renderer had to invent a working controller');
    });

    testWidgets('enabled, readOnly and obscure all reach the widget', (tester) async {
      await tester.pumpWidget(harness(const LiveTextField(enabled: false)));
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      final fieldIgnore = find.descendant(of: find.byType(TokenTextField), matching: find.byType(IgnorePointer));
      expect(tester.widget<IgnorePointer>(fieldIgnore.first).ignoring, isTrue);

      await tester.pumpWidget(harness(const LiveTextField(readOnly: true)));
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);

      await tester.pumpWidget(harness(const LiveTextField(obscure: true, maxLines: 4)));
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.obscureText, isTrue);
      expect(field.maxLines, 1, reason: 'an obscured field is single-line whatever was asked');
    });

    testWidgets('the focus node belongs to the caller', (tester) async {
      final focus = FocusNode();
      await tester.pumpWidget(harness(LiveTextField(focusNode: focus)));
      focus.requestFocus();
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      focus.dispose();
    });

    testWidgets('an error message is drawn and recolours the border', (tester) async {
      await tester.pumpWidget(harness(const LiveTextField(errorText: 'required')));
      expect(find.text('required'), findsOneWidget);
      final decoration = tester.widget<AnimatedContainer>(fieldSurface(tester)).decoration! as BoxDecoration;
      expect(
        (decoration.border! as Border).top.color,
        LiveTheme.of(tester.element(find.byType(TokenTextField))).input.errorBorderColor,
      );
    });

    testWidgets('the inline style overrides the field surface', (tester) async {
      await tester.pumpWidget(
        harness(
          const LiveTextField(
            style: Style(background: Color(0xFF123456), padding: EdgeInsets.all(7), minWidth: 200),
          ),
        ),
      );
      final container = tester.widget<AnimatedContainer>(fieldSurface(tester));
      expect((container.decoration! as BoxDecoration).color, const Color(0xFF123456));
      expect(container.padding, const EdgeInsets.all(7));
      expect(container.constraints!.minWidth, 200);
    });
  });

  group('switch and checkbox', () {
    testWidgets('the switch is fully controlled — it reports, it does not mutate', (tester) async {
      bool? next;
      await tester.pumpWidget(harness(LiveSwitch(value: false, onChanged: (v) => next = v)));
      await tester.tap(find.byType(TokenSwitch));
      expect(next, isTrue);
      await tester.pump();
      expect(tester.widget<LiveSwitch>(find.byType(LiveSwitch)).value, isFalse, reason: 'the caller owns the state');
    });

    testWidgets('a null callback disables the switch', (tester) async {
      await tester.pumpWidget(harness(const LiveSwitch(value: true, onChanged: null)));
      final handle = tester.ensureSemantics();
      expect(tester.getSemantics(find.byType(TokenSwitch)).getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      handle.dispose();
    });

    testWidgets('a disabled switch dims its track instead of hiding it', (tester) async {
      await tester.pumpWidget(harness(LiveSwitch(value: true, enabled: false, onChanged: (_) {})));
      final theme = LiveTheme.of(tester.element(find.byType(TokenSwitch)));
      final track =
          tester
                  .widget<AnimatedContainer>(
                    find.descendant(of: find.byType(TokenSwitch), matching: find.byType(AnimatedContainer)).last,
                  )
                  .decoration!
              as BoxDecoration;
      expect(track.color!.a, closeTo(theme.switchToken.disabledOpacity, 0.001));
      expect(find.byType(TokenSwitch), findsOneWidget);
    });

    testWidgets('the checkbox paints its label and reports the next value', (tester) async {
      bool? next;
      await tester.pumpWidget(harness(LiveCheckbox(value: false, label: 'remember me', onChanged: (v) => next = v)));
      expect(find.text('remember me'), findsOneWidget);
      await tester.tap(find.text('remember me'));
      expect(next, isTrue, reason: 'the label is part of the hit area');
      expect(find.byIcon(Icons.check), findsNothing);

      await tester.pumpWidget(harness(LiveCheckbox(value: true, onChanged: (_) {})));
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('a null callback disables the checkbox', (tester) async {
      var calls = 0;
      await tester.pumpWidget(harness(LiveCheckbox(value: true, label: 'nope', onChanged: (_) => calls++)));
      await tester.pumpWidget(harness(const LiveCheckbox(value: true, label: 'nope', onChanged: null)));
      await tester.tap(find.text('nope'));
      expect(calls, 0);
    });
  });

  group('slider', () {
    testWidgets('a press positions the value inside the bounds', (tester) async {
      double? value;
      await tester.pumpWidget(harness(SizedBox(width: 200, child: LiveSlider(value: 0, onChanged: (v) => value = v))));
      final origin = tester.getTopLeft(find.byType(TokenSlider));
      await tester.tapAt(origin.translate(80, 8));
      expect(value, closeTo(0.39, 0.03));
    });

    testWidgets('min and max clamp the reported value', (tester) async {
      double? value;
      await tester.pumpWidget(
        harness(SizedBox(width: 200, child: LiveSlider(value: 20, min: 20, max: 40, onChanged: (v) => value = v))),
      );
      final origin = tester.getTopLeft(find.byType(TokenSlider));
      await tester.tapAt(origin.translate(199, 8));
      expect(value, closeTo(40, 0.5));
      await tester.tapAt(origin.translate(1, 8));
      expect(value, closeTo(20, 0.5));
    });

    testWidgets('arrow keys step by a twentieth of the range', (tester) async {
      final focus = FocusNode();
      double? value;
      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 200,
            child: LiveSlider(value: 0.5, focusNode: focus, onChanged: (v) => value = v),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(value, closeTo(0.55, 0.0001));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(value, closeTo(0.45, 0.0001));
      focus.dispose();
    });

    testWidgets('a null callback rejects drags and keys', (tester) async {
      final focus = FocusNode();
      await tester.pumpWidget(
        harness(SizedBox(width: 200, child: LiveSlider(value: 0.5, focusNode: focus, onChanged: null))),
      );
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.drag(find.byType(TokenSlider), const Offset(60, 0));
      await tester.pump();
      expect(find.byType(TokenSlider), findsOneWidget, reason: 'disabled renders, it does not vanish');
    });
  });

  group('segmented', () {
    testWidgets('expand false hugs the labels, expand true shares the width', (tester) async {
      // Align, not a bare SizedBox: a SizedBox of 300 hands the control a *tight*
      // 300, and then neither branch could ever be smaller.
      Widget row(Widget segmented) => SizedBox(
        width: 300,
        child: Align(alignment: Alignment.topLeft, child: segmented),
      );

      await tester.pumpWidget(harness(row(LiveSegmented(labels: const ['a', 'bb'], index: 0, onChanged: (_) {}))));
      final hug = tester.getSize(find.byType(LiveSegmented)).width;
      expect(hug, lessThan(300), reason: 'a content-sized segmented control must not claim the row');

      await tester.pumpWidget(
        harness(row(LiveSegmented(labels: const ['a', 'bb'], index: 0, expand: true, onChanged: (_) {}))),
      );
      expect(tester.getSize(find.byType(LiveSegmented)).width, 300);
    });

    testWidgets('a segment reports its own index', (tester) async {
      int? index;
      await tester.pumpWidget(
        harness(LiveSegmented(labels: const ['first', 'second'], index: 0, onChanged: (i) => index = i)),
      );
      await tester.tap(find.text('second'));
      expect(index, 1);
    });

    testWidgets('a null callback or enabled: false rejects the tap', (tester) async {
      int? index;
      await tester.pumpWidget(harness(const LiveSegmented(labels: ['first', 'second'], index: 0, onChanged: null)));
      await tester.tap(find.text('second'));
      expect(index, isNull);

      await tester.pumpWidget(
        harness(
          LiveSegmented(labels: const ['first', 'second'], index: 0, enabled: false, onChanged: (i) => index = i),
        ),
      );
      await tester.tap(find.text('second'));
      expect(index, isNull);
    });
  });

  group('progress', () {
    testWidgets('a determinate value fills its fraction and labels itself', (tester) async {
      await tester.pumpWidget(harness(const LiveProgress(value: 0.4, showLabel: true)));
      final fill = tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox));
      expect(fill.widthFactor, 0.4);
      expect(find.text('40%'), findsOneWidget);
    });

    testWidgets('null is indeterminate: a marquee, and no percentage to claim', (tester) async {
      await tester.pumpWidget(harness(const LiveProgress(value: null, showLabel: true)));
      expect(find.byType(LinearIndeterminate), findsOneWidget);
      expect(find.byType(FractionallySizedBox), findsNothing);
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('height and barColor reach the painted track', (tester) async {
      await tester.pumpWidget(harness(const LiveProgress(value: 0.5, height: 12, barColor: Color(0xFF123456))));
      final containers = tester.widgetList<Container>(
        find.descendant(of: find.byType(TokenProgress), matching: find.byType(Container)),
      );
      expect(containers.any((c) => c.constraints?.maxHeight == 12), isTrue, reason: 'the track is `height` thick');
      expect(
        containers.any((c) => (c.decoration as BoxDecoration?)?.color == const Color(0xFF123456)),
        isTrue,
        reason: 'barColor replaces the primary fill',
      );
    });
  });

  group('select', () {
    testWidgets('the field shows the value, or the placeholder', (tester) async {
      await tester.pumpWidget(
        harness(LiveSelect<String>(items: const ['a', 'b'], itemLabel: (v) => v, value: 'b', onChanged: (_) {})),
      );
      expect(find.text('b'), findsOneWidget);

      await tester.pumpWidget(
        harness(
          LiveSelect<String>(items: const ['a', 'b'], itemLabel: (v) => v, placeholder: 'pick one', onChanged: (_) {}),
        ),
      );
      expect(find.text('pick one'), findsOneWidget);
    });

    testWidgets('opening the menu and choosing reports the typed value and closes', (tester) async {
      String? chosen;
      await tester.pumpWidget(
        harness(
          SizedBox(
            width: 200,
            child: LiveSelect<String>(items: const ['a', 'b'], itemLabel: (v) => v, onChanged: (v) => chosen = v),
          ),
        ),
      );
      await tester.tap(find.byType(TokenSelect<String>));
      await tester.pumpAndSettle();
      expect(find.text('a'), findsOneWidget);

      await tester.tap(find.text('b'));
      await tester.pumpAndSettle();
      expect(chosen, 'b');
      expect(find.text('b'), findsNothing, reason: 'the popup has to go away after a choice');
    });

    testWidgets('a disabled select never opens', (tester) async {
      await tester.pumpWidget(
        harness(LiveSelect<String>(items: const ['a', 'b'], itemLabel: (v) => v, enabled: false, onChanged: (_) {})),
      );
      await tester.tap(find.byType(TokenSelect<String>));
      await tester.pumpAndSettle();
      expect(find.text('a'), findsNothing);
    });

    testWidgets('a null callback never opens', (tester) async {
      await tester.pumpWidget(harness(LiveSelect<String>(items: const ['a'], itemLabel: (v) => v, onChanged: null)));
      await tester.tap(find.byType(TokenSelect<String>));
      await tester.pumpAndSettle();
      expect(find.text('a'), findsNothing);
    });
  });

  group('tabs', () {
    testWidgets('a tab reports its own index', (tester) async {
      int? index;
      await tester.pumpWidget(
        harness(
          LiveTabs(
            tabs: const [
              LiveTab(label: 'one'),
              LiveTab(label: 'two', icon: Icons.star),
            ],
            index: 0,
            onChanged: (i) => index = i,
          ),
        ),
      );
      expect(find.byIcon(Icons.star), findsOneWidget);
      await tester.tap(find.text('two'));
      expect(index, 1);
    });

    testWidgets('enabled: false and a null callback both refuse the tap', (tester) async {
      int? index;
      await tester.pumpWidget(
        harness(
          LiveTabs(
            tabs: const [
              LiveTab(label: 'one'),
              LiveTab(label: 'two'),
            ],
            index: 0,
            enabled: false,
            onChanged: (i) => index = i,
          ),
        ),
      );
      await tester.tap(find.text('two'));
      expect(index, isNull, reason: 'the spec says enabled is a contract, not a hint');

      await tester.pumpWidget(
        harness(
          const LiveTabs(
            tabs: [
              LiveTab(label: 'one'),
              LiveTab(label: 'two'),
            ],
            index: 0,
            onChanged: null,
          ),
        ),
      );
      await tester.tap(find.text('two'));
      expect(index, isNull);
    });

    testWidgets('spacing sits between tabs only', (tester) async {
      await tester.pumpWidget(
        harness(
          LiveTabs(
            tabs: const [
              LiveTab(label: 'one'),
              LiveTab(label: 'two'),
            ],
            index: 0,
            spacing: 12,
            onChanged: (_) {},
          ),
        ),
      );
      final paddings = tester
          .widgetList<Padding>(find.descendant(of: find.byType(TokenTabs), matching: find.byType(Padding)))
          .map((p) => p.padding)
          .toList();
      expect(paddings.first, const EdgeInsets.only(right: 12));
      expect(paddings.last, EdgeInsets.zero);
    });
  });
}
