import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The tabs every case is written against: three labels of uneven width, so a
/// stretched and a packed strip give different numbers.
const List<PureTab> _tabs = [PureTab(label: 'One'), PureTab(label: 'Two'), PureTab(label: 'Three')];

const List<PureTab> _longTabs = [
  PureTab(label: 'All the rooms'),
  PureTab(label: 'Rooms I follow a lot'),
  PureTab(label: 'Recently watched a great many'),
];

/// The branch key the public widget hangs on its body: the language whose
/// geometry a strip is drawing is addressable in tests and diagnostics.
Key _branch(PureDesignLanguage language) => ValueKey('PureTabs.${language.name}');

/// The sliding indicator — the one animated layer the strip itself owns (the
/// cells animate their decorations, not their position).
Rect _indicator(WidgetTester tester) => tester.getRect(find.byType(AnimatedPositioned));

/// The strip's own semantics for one tab: the framework's `Focus` and `Icon`
/// widgets contribute plain nodes too, so the match is by the flags the control
/// sets rather than by position.
Semantics _cellSemantics(WidgetTester tester, String label) => tester.widget<Semantics>(
  find
      .descendant(
        of: find.byType(PureTabs),
        matching: find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.button == true && widget.properties.label == label,
        ),
      )
      .first,
);

/// The scrolled strip's offset, read off the live position: the answer the
/// control gives when it reveals a tab the box cannot show at once. Scoped to
/// the strip's own scroll view, so a route's scrollable never answers for it.
double _scrollOffset(WidgetTester tester) => tester
    .state<ScrollableState>(find.descendant(of: find.byType(PureTabs), matching: find.byType(Scrollable)))
    .position
    .pixels;

/// The disabled fade a cell runs on its own content; an inert strip puts it on
/// every one of them, so `.first` reads the verdict.
double _contentOpacity(WidgetTester tester) => tester
    .widgetList<AnimatedOpacity>(find.descendant(of: find.byType(PureTabs), matching: find.byType(AnimatedOpacity)))
    .first
    .opacity;

List<double> _centers(WidgetTester tester) => [for (final tab in _tabs) tester.getCenter(find.text(tab.label)).dx];

void main() {
  group('languages', () {
    testWidgets('every design language builds its own strip, with one indicator', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pump(
          tester,
          const PureTabs(tabs: _tabs, index: 0, onChanged: _discard),
          language: language,
        );
        expect(tester.takeException(), isNull, reason: '$language failed to build');
        expect(find.byKey(_branch(language)), findsOneWidget, reason: '$language lost its branch');
        // Self-painted means the strip is never a library's control: nine
        // languages, one sliding indicator, and no borrowed tab widget at all.
        expect(find.byType(AnimatedPositioned), findsOneWidget, reason: '$language lost its indicator');
        expect(find.byType(TabBar), findsNothing, reason: '$language delegated to Material');
        for (final tab in _tabs) {
          expect(find.text(tab.label), findsOneWidget, reason: '$language dropped ${tab.label}');
        }
      }
    });

    testWidgets('the chosen cell answers in the indicator, and the strip never overflows', (tester) async {
      // The overflow the macOS branch used to hit came from cells that could
      // neither shrink nor ellipsize; every language here packs its own labels,
      // so an uneven three-tab strip in a phone-wide box is silent.
      for (final language in PureDesignLanguage.values) {
        await _pump(
          tester,
          const PureTabs(tabs: _longTabs, index: 0, onChanged: _discard),
          language: language,
          width: 360,
        );
        expect(tester.takeException(), isNull, reason: '$language overflowed its box');
        expect(tester.getRect(find.byType(PureTabs)).width, lessThanOrEqualTo(360 + 0.5));
      }
    });

    testWidgets('a tab with an icon draws it, whatever the library would have allowed', (tester) async {
      // The old macOS and Cupertino branches had nowhere for the glyph to go;
      // painted here, every language has a slot for it.
      const iconTabs = [
        PureTab(label: 'Home', icon: Icons.home_outlined),
        PureTab(label: 'Settings', icon: Icons.settings_outlined),
      ];
      for (final language in PureDesignLanguage.values) {
        await _pump(
          tester,
          const PureTabs(tabs: iconTabs, index: 1, onChanged: _discard),
          language: language,
        );
        expect(find.byIcon(Icons.home_outlined), findsOneWidget, reason: '$language lost the icon');
        expect(find.byIcon(Icons.settings_outlined), findsOneWidget, reason: '$language lost the icon');
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('selection', () {
    testWidgets('every language reports the tapped tab to onChanged', (tester) async {
      for (final language in PureDesignLanguage.values) {
        final seen = <int>[];
        await _pump(
          tester,
          PureTabs(tabs: _tabs, index: 0, onChanged: seen.add),
          language: language,
        );

        await tester.tap(find.text('Three'));
        await tester.pumpAndSettle();
        expect(seen, [2], reason: '$language lost the tap');

        await tester.tap(find.text('One'));
        await tester.pumpAndSettle();
        expect(seen, [2, 0], reason: '$language lost the second tap');
      }
    });

    testWidgets('the index drives where the indicator sits', (tester) async {
      await _pump(tester, const PureTabs(tabs: _tabs, index: 0, onChanged: _discard));
      final first = _indicator(tester);
      expect(first.center.dx, closeTo(tester.getCenter(find.text('One')).dx, 1));

      // The controlled answer: the caller's new index moves the indicator, it
      // never rides a tap of its own.
      await _pump(tester, const PureTabs(tabs: _tabs, index: 2, onChanged: _discard));
      final last = _indicator(tester);
      expect(last.left, greaterThan(first.left));
      expect(last.center.dx, closeTo(tester.getCenter(find.text('Three')).dx, 1));

      // And it slides rather than teleporting: a mid-animation frame is
      // somewhere between the two placements.
      await _host(tester, const PureTabs(tabs: _tabs, index: 0, onChanged: _discard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final mid = _indicator(tester).center.dx;
      expect(mid, greaterThan(first.center.dx - 1));
      expect(mid, lessThan(last.center.dx));
    });

    testWidgets('the pill languages fill the cell, the ink-bar languages rule under it', (tester) async {
      // Two indicator geometries, both driven by the same measurement.
      await _pump(tester, const PureTabs(tabs: _tabs, index: 1, onChanged: _discard));
      final bar = _indicator(tester);
      expect(bar.height, 3);
      expect(bar.bottom, closeTo(tester.getRect(find.byType(PureTabs)).bottom, 0.5));

      await _pump(
        tester,
        const PureTabs(tabs: _tabs, index: 1, onChanged: _discard),
        language: PureDesignLanguage.yaru,
      );
      final pill = _indicator(tester);
      expect(pill.height, greaterThan(20));
      expect(pill.center.dx, closeTo(tester.getCenter(find.text('Two')).dx, 1));
    });
  });

  group('layout', () {
    testWidgets('a fixed strip divides its width, a scrollable one packs at its own', (tester) async {
      await _pump(tester, const PureTabs(tabs: _tabs, index: 0, onChanged: _discard), width: 360);
      expect(find.byType(SingleChildScrollView), findsNothing);
      // Three equal slots of a 360dp box.
      final stretched = _centers(tester);
      expect(stretched, [60, 180, 300]);

      await _pump(tester, const PureTabs(tabs: _tabs, index: 0, isScrollable: true, onChanged: _discard), width: 360);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      final packed = _centers(tester);
      // Left-packed at their own widths: the gaps follow the labels, not the box.
      expect(packed.first, lessThan(stretched.first));
      expect(packed[1] - packed[0], isNot(closeTo(120, 1)));
      expect(packed.last, lessThan(stretched.last));
      expect(tester.takeException(), isNull);
    });

    testWidgets('spacing draws the gap it asks for', (tester) async {
      final seen = <int>[];
      await _pump(
        tester,
        PureTabs(tabs: _tabs, index: 0, spacing: 20, isScrollable: true, onChanged: seen.add),
        width: 360,
      );
      final centers = _centers(tester);
      await _pump(tester, PureTabs(tabs: _tabs, index: 0, isScrollable: true, onChanged: seen.add), width: 360);
      final tight = _centers(tester);
      expect(centers[1] - centers[0], greaterThan(tight[1] - tight[0] + 10));
    });
  });

  group('disabled', () {
    testWidgets('a null callback renders the strip inert', (tester) async {
      await _pump(tester, const PureTabs(tabs: _tabs, index: 1, onChanged: null));
      expect(tester.takeException(), isNull);
      // The strip's own answer to being inert: pointers pass straight through
      // it, whatever else on the page happens to ignore them too.
      expect(
        find.descendant(of: find.byKey(_branch(PureDesignLanguage.material)), matching: find.byType(IgnorePointer)),
        findsOneWidget,
      );
      await tester.tap(find.text('Three'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(_contentOpacity(tester), lessThan(1));
      expect(_cellSemantics(tester, 'Three').properties.enabled, false);
    });

    testWidgets('enabled false folds into the same inert verdict', (tester) async {
      final seen = <int>[];
      await _pump(tester, PureTabs(tabs: _tabs, index: 0, enabled: false, onChanged: seen.add));

      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();
      expect(seen, isEmpty);
      expect(_contentOpacity(tester), lessThan(1));

      // A keyboard gets the same answer as a finger: nothing is chosen and
      // focus does not move.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(seen, isEmpty);
    });

    testWidgets('a disabled tab is skipped by the keyboard and unanswerable by a tap', (tester) async {
      const tabs = [PureTab(label: 'One'), PureTab(label: 'Two', enabled: false), PureTab(label: 'Three')];
      final seen = <int>[];
      await _pump(tester, PureTabs(tabs: tabs, index: 0, onChanged: seen.add));

      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();
      expect(seen, isEmpty);
      expect(_cellSemantics(tester, 'Two').properties.enabled, false);

      await tester.tap(find.text('One'));
      await tester.pumpAndSettle();
      expect(seen, [0]);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      // The inert cell is stepped over: focus lands on 'Three' and chooses it.
      expect(seen, [0, 2]);
    });
  });

  group('semantics', () {
    testWidgets('every tab names itself and marks the chosen one selected', (tester) async {
      await _pump(tester, const PureTabs(tabs: _tabs, index: 1, onChanged: _discard));

      for (final tab in _tabs) {
        expect(_cellSemantics(tester, tab.label).properties.button, true);
        expect(_cellSemantics(tester, tab.label).properties.enabled, true);
      }
      expect(_cellSemantics(tester, 'Two').properties.selected, true);
      expect(_cellSemantics(tester, 'One').properties.selected, false);
    });
  });

  group('keyboard', () {
    testWidgets('arrows move focus and enter or space chooses', (tester) async {
      final seen = <int>[];
      await _pump(tester, PureTabs(tabs: _tabs, index: 0, onChanged: seen.add));

      // A tap puts the focus on the cell it hit — the keyboard starts from
      // wherever the pointer left off.
      await tester.tap(find.text('One'));
      await tester.pumpAndSettle();
      expect(seen, [0]);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(seen, [0, 1]);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(seen, [0, 1, 2]);

      // At the leading edge a Left arrow has nowhere to go and the shell keeps
      // the key.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(seen, [0, 1, 2, 0]);
    });

    testWidgets('the remote select keys choose the focused tab', (tester) async {
      final seen = <int>[];
      await _pump(tester, PureTabs(tabs: _tabs, index: 0, onChanged: seen.add));
      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();
      expect(seen, [1]);

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(seen, [1, 1]);
    });

    testWidgets('a scrolled strip keeps the chosen tab in view', (tester) async {
      final seen = <int>[];
      await _pump(tester, PureTabs(tabs: _longTabs, index: 0, isScrollable: true, onChanged: seen.add), width: 200);
      // Content wider than the box it was given, so the last tab starts off
      // the right edge — the case the pages hit with one tab per platform.
      expect(_scrollOffset(tester), 0);

      // The caller's index change reveals the chosen tab: the strip scrolls it
      // into view instead of sliding the indicator somewhere the user cannot
      // see it.
      await _pump(tester, PureTabs(tabs: _longTabs, index: 2, isScrollable: true, onChanged: seen.add), width: 200);
      expect(_scrollOffset(tester), greaterThan(0));
      expect(_indicator(tester).center.dx, closeTo(tester.getCenter(find.text(_longTabs[2].label)).dx, 1));

      // And the tab now in view answers a tap.
      await tester.tap(find.text(_longTabs[2].label));
      await tester.pumpAndSettle();
      expect(seen, [2]);
    });
  });
}

void _discard(int index) {}

/// Mounts a strip under a provider without settling, so a test can watch the
/// indicator travel instead of skipping past it.
Future<void> _host(
  WidgetTester tester,
  Widget child, {
  PureDesignLanguage language = PureDesignLanguage.material,
  double width = 300,
}) async {
  await tester.pumpWidget(
    PureConfigProvider(
      config: UiConfig(language: language, brightness: UiBrightnessMode.light),
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  PureDesignLanguage language = PureDesignLanguage.material,
  double width = 300,
}) async {
  await _host(tester, child, language: language, width: width);
  await tester.pumpAndSettle();
}
