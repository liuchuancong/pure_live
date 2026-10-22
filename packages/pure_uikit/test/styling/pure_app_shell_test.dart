// The shell: nine self-painted panes, the body's placement beside them, the
// strip form's delegation, the overlay drawer's slide, and the keyboard,
// disabled-row and semantics contracts every interactive chrome in the kit
// keeps. Every assertion is against `pure_app_shell.dart`'s own implementation
// (row keys, the drawer's AnimatedSlide, the pane's own width floor); nothing
// here is copied from the tab bar's geometry tests. The nine-language builds
// double as the proof that the shell paints its appearance without the
// language's host: a bare `PureConfigProvider` + `MaterialApp` binding has no
// FluentApp, MacosApp or forui ancestor, and the shell must not care.
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsData;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The row the shell paints for a destination — the address its tests tap,
/// read semantics from, and count.
Finder _row(String id) => find.byKey(ValueKey('PureAppShell.row.$id'));

/// The body, under a key so its placement is addressable.
const Key _bodyKey = ValueKey('BODY');

const List<PureShellDestination> _destinations = [
  PureShellDestination(id: 'a', label: 'First', icon: Icons.home),
  PureShellDestination(id: 'b', label: 'Second', icon: Icons.live_tv),
  PureShellDestination(id: 'c', label: 'Third', icon: Icons.person),
];

Future<void> _pump(
  WidgetTester tester, {
  PureDesignLanguage language = PureDesignLanguage.material,
  bool animations = true,
  List<PureShellDestination> destinations = _destinations,
  String? selectedId = 'a',
  PureShellPlacement placement = PureShellPlacement.rail,
  ValueChanged<String>? onSelected,
  Widget? leading,
  Widget? trailing,
  double? viewWidth,
}) async {
  if (viewWidth case final double width) {
    // The window's own width, for the forms that qualify through the shared
    // breakpoints (the fluent narrow drawer); the shell itself is only ever
    // constrained by width, never by a fixed tight height.
    tester.view.physicalSize = Size(width, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  await tester.pumpWidget(
    PureConfigProvider(
      config: UiConfig(language: language, animations: animations),
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: viewWidth ?? 700,
            child: PureAppShell(
              destinations: destinations,
              selectedId: selectedId,
              onSelected: onSelected,
              placement: placement,
              leading: leading,
              trailing: trailing,
              child: const SizedBox(key: _bodyKey, child: Text('BODY')),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The drawer's slide — the only AnimatedSlide the shell ever paints.
AnimatedSlide _drawer(WidgetTester tester) =>
    tester.widget<AnimatedSlide>(find.descendant(of: find.byType(PureAppShell), matching: find.byType(AnimatedSlide)));

/// The row's own semantics data: the shell names it with the exact `Semantics`
/// widget it installs (an `ExcludeSemantics` shares that type, hence the
/// predicate). The row's node is the outermost one — a labelled `Icon` inside
/// installs a node of its own further down the depth-first walk — so `.first`
/// is the row, and `getSemantics` aggregates everything painted under it.
SemanticsData _rowSemantics(WidgetTester tester, String id) {
  final node = tester.getSemantics(
    find
        .descendant(
          of: _row(id),
          matching: find.byWidgetPredicate((widget) => widget is Semantics && widget.runtimeType == Semantics),
        )
        .first,
  );
  return node.getSemanticsData();
}

void main() {
  for (final language in PureDesignLanguage.values) {
    testWidgets('the ${language.name} pane paints its rows, head and foot with no host ancestor', (tester) async {
      await _pump(
        tester,
        language: language,
        leading: const Text('HEAD'),
        trailing: const Text('FOOT'),
      );

      // The plain MaterialApp binding must not throw for any language — the
      // shell borrows no library appearance widget, so it needs no library
      // theme, and the host chain stays the app's business.
      expect(tester.takeException(), isNull);
      for (final destination in _destinations) {
        expect(find.descendant(of: _row(destination.id), matching: find.text(destination.label)), findsOneWidget);
      }
      expect(find.text('BODY'), findsOneWidget);
      expect(find.text('HEAD'), findsOneWidget);
      expect(find.text('FOOT'), findsOneWidget);
    });
  }

  testWidgets('the rail stands beside the body at the pane width the language chose', (tester) async {
    // Material's rail takes the token metric (88): its rows are stacked, so
    // the language floor (72) never raises it. The body begins where the
    // pane ends — the shell's own contract about placement, not geometry.
    await _pump(tester);
    expect(tester.getTopLeft(find.byKey(_bodyKey)).dx, 88);

    // A row-form language floors wider than the metric: a source list
    // squeezed to 88 stops being a source list.
    await _pump(tester, language: PureDesignLanguage.macos);
    expect(tester.getTopLeft(find.byKey(_bodyKey)).dx, 154);
  });

  testWidgets('the bottom form delegates to PureNavBar and keeps neither slot', (tester) async {
    await _pump(
      tester,
      placement: PureShellPlacement.bottom,
      leading: const Text('HEAD'),
      trailing: const Text('FOOT'),
    );
    // The same dispatched control a page names — the strip is not a second
    // painting of the rows.
    expect(find.byType(PureNavBar), findsOneWidget);
    expect(_row('a'), findsNothing);
    // The contract documents it: a strip has no head and no foot.
    expect(find.text('HEAD'), findsNothing);
    expect(find.text('FOOT'), findsNothing);
    expect(find.text('BODY'), findsOneWidget);
  });

  testWidgets('a shell with no choice to make stands aside', (tester) async {
    await _pump(tester, destinations: const [PureShellDestination(id: 'a', label: 'First', icon: Icons.home)]);
    expect(_row('a'), findsNothing);
    expect(find.text('BODY'), findsOneWidget);

    await _pump(tester, placement: PureShellPlacement.none);
    expect(_row('a'), findsNothing);
    expect(find.byType(PureNavBar), findsNothing);
  });

  testWidgets('a row answers with its id, not its index', (tester) async {
    final chosen = <String>[];
    await _pump(tester, language: PureDesignLanguage.forui, onSelected: chosen.add);

    await tester.tap(_row('b'));
    await tester.pumpAndSettle();
    expect(chosen, ['b']);
  });

  testWidgets('a disabled destination keeps its row and refuses the tap', (tester) async {
    final chosen = <String>[];
    await _pump(
      tester,
      language: PureDesignLanguage.cupertino,
      destinations: const [
        PureShellDestination(id: 'a', label: 'First', icon: Icons.home),
        PureShellDestination(id: 'b', label: 'Second', icon: Icons.live_tv, enabled: false),
      ],
      onSelected: chosen.add,
    );

    // The row stays so the column does not shift when it opens.
    expect(find.descendant(of: _row('b'), matching: find.text('Second')), findsOneWidget);
    await tester.tap(_row('b'));
    await tester.pumpAndSettle();
    expect(chosen, isEmpty);

    final data = _rowSemantics(tester, 'b');
    expect(data.flagsCollection.isEnabled != Tristate.none, isTrue);
    expect(data.flagsCollection.isEnabled, Tristate.isFalse);
  });

  testWidgets('rows carry button, selection and name to a screen reader', (tester) async {
    // A live shell: an inert one (no callback) greys its rows and withdraws
    // selection, which the disabled case below already pins.
    await _pump(tester, language: PureDesignLanguage.fluent, onSelected: (_) {});
    final selected = _rowSemantics(tester, 'a').flagsCollection;
    expect(selected.isButton, isTrue);
    expect(selected.isSelected, Tristate.isTrue);
    expect(selected.isEnabled, Tristate.isTrue);
    expect(_rowSemantics(tester, 'a').label, 'First');

    final unselected = _rowSemantics(tester, 'c').flagsCollection;
    expect(unselected.isSelected, isNot(Tristate.isTrue));
    expect(_rowSemantics(tester, 'c').label, 'Third');
  });

  testWidgets('the arrow keys walk the pane and Enter chooses', (tester) async {
    final chosen = <String>[];
    await _pump(tester, language: PureDesignLanguage.yaru, onSelected: chosen.add);

    // A tap seats focus (the kit's contract: pointer and keyboard agree about
    // what is focused); from there the remote's up/down traverse rows.
    await tester.tap(_row('a'));
    await tester.pumpAndSettle();
    expect(chosen, ['a']);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(chosen, ['a', 'b']);
  });

  testWidgets('the fluent narrow form summons the painted overlay drawer', (tester) async {
    final chosen = <String>[];
    await _pump(tester, language: PureDesignLanguage.fluent, viewWidth: 360, onSelected: chosen.add);

    // Below the breakpoint the pane is gone — the hamburger strip stands in
    // and the nav comes back over the page.
    expect(find.byKey(const ValueKey('PureAppShell.drawer-toggle')), findsOneWidget);
    expect(_drawer(tester).offset, const Offset(-1, 0));

    await tester.tap(find.byKey(const ValueKey('PureAppShell.drawer-toggle')));
    await tester.pumpAndSettle();
    expect(_drawer(tester).offset, Offset.zero);

    await tester.tap(_row('b'));
    await tester.pumpAndSettle();
    expect(chosen, ['b']);

    // The scrim dismisses: a tap right of the 240-wide drawer hits it.
    await tester.tapAt(const Offset(300, 320));
    await tester.pumpAndSettle();
    expect(_drawer(tester).offset, const Offset(-1, 0));
  });

  testWidgets('animations off collapses the drawer tween to zero', (tester) async {
    await _pump(tester, language: PureDesignLanguage.fluent, viewWidth: 360, animations: false);
    expect(_drawer(tester).duration, Duration.zero);

    await tester.tap(find.byKey(const ValueKey('PureAppShell.drawer-toggle')));
    await tester.pump();
    // One frame, and the drawer is already home — no settling needed.
    expect(_drawer(tester).offset, Offset.zero);
    expect(_drawer(tester).duration, Duration.zero);
  });

  testWidgets('animations on give the drawer a real slide', (tester) async {
    await _pump(tester, language: PureDesignLanguage.fluent, viewWidth: 360);
    expect(_drawer(tester).duration, isNot(Duration.zero));
  });
}
