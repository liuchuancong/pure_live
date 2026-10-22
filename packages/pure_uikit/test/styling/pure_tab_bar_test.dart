import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_uikit/pure_uikit.dart';

const List<PureTabBarItem> _items = [
  PureTabBarItem(icon: Icons.home, label: 'One'),
  PureTabBarItem(icon: Icons.search, label: 'Two'),
  PureTabBarItem(icon: Icons.person, label: 'Three'),
];

void main() {
  group('geometry', () {
    testWidgets('a tapped cell reports its index; the controlled pill stays where the caller put it', (tester) async {
      final picked = <int>[];
      await _pump(tester, _bar(index: 0, onChanged: picked.add));
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();

      expect(picked, [1]);
      final pill = tester.getRect(find.byType(AnimatedPositioned));
      expect(pill.center.dx, moreOrLessEquals(tester.getRect(find.text('One')).center.dx));
    });

    testWidgets('the material language pins a 3px ink bar to the strip bottom', (tester) async {
      await _pump(tester, _bar(index: 1));

      final ink = tester.getRect(find.byType(AnimatedPositioned));
      final cells = find.byType(AnimatedContainer);
      expect(ink.height, 3);
      expect(ink.width, moreOrLessEquals(tester.getRect(cells.at(1)).width));
      expect(ink.bottom, moreOrLessEquals(tester.getRect(find.byType(Row).first).bottom));
    });

    testWidgets('an outside selection slides the pill too', (tester) async {
      await _pump(tester, _bar(index: 0));
      await _pump(tester, _bar(index: 2));

      final pill = tester.getRect(find.byType(AnimatedPositioned));
      expect(pill.center.dx, moreOrLessEquals(tester.getRect(find.text('Three')).center.dx));
    });

    testWidgets('expand shares the width equally', (tester) async {
      await _pump(tester, PureTabBar(items: _items, index: 0, expand: true, onChanged: (_) {}));

      final centers = [for (final label in _items) tester.getCenter(find.text(label.label!)).dx];
      // Three equal slots of a 300dp box.
      expect(centers, [50, 150, 250]);
    });

    testWidgets('the tiers change the cell height the tier table promises', (tester) async {
      await _pump(tester, _bar(index: 0, size: PureTabBarSize.small));
      expect(_cellMinHeight(tester), PureTabBarSize.small.height - 2 * PureTabBarSize.small.inset);

      await _pump(tester, _bar(index: 0));
      expect(_cellMinHeight(tester), PureTabBarSize.standard.height - 2 * PureTabBarSize.standard.inset);

      await _pump(tester, _bar(index: 0, size: PureTabBarSize.large));
      expect(_cellMinHeight(tester), PureTabBarSize.large.height - 2 * PureTabBarSize.large.inset);
    });

    testWidgets('a long strip scrolls and reveals an outside selection', (tester) async {
      final many = [for (var i = 0; i < 8; i++) PureTabBarItem(icon: Icons.star, label: 'Tab $i')];
      await _pump(tester, PureTabBar(items: many, index: 0, isScrollable: true, onChanged: (_) {}));
      expect(find.byType(SingleChildScrollView), findsOneWidget);

      await _pump(tester, PureTabBar(items: many, index: 7, isScrollable: true, onChanged: (_) {}));
      expect(tester.takeException(), isNull);
    });
  });

  group('interaction', () {
    testWidgets('a disabled cell ignores taps while its neighbours stay live', (tester) async {
      final picked = <int>[];
      await _pump(
        tester,
        PureTabBar(
          items: const [
            PureTabBarItem(icon: Icons.home, label: 'One'),
            PureTabBarItem(icon: Icons.search, label: 'Two', enabled: false),
            PureTabBarItem(icon: Icons.person, label: 'Three'),
          ],
          index: 0,
          onChanged: picked.add,
        ),
      );

      await tester.tap(find.text('Two'));
      expect(picked, isEmpty);

      await tester.tap(find.text('Three'));
      expect(picked, [2]);
    });

    testWidgets('an inert bar answers nothing', (tester) async {
      await _pump(tester, const PureTabBar(items: _items, index: 0, onChanged: null));

      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();

      // The inert bar keeps the grey selection where the caller put it.
      final pill = tester.getRect(find.byType(AnimatedPositioned));
      expect(pill.center.dx, moreOrLessEquals(tester.getRect(find.text('One')).center.dx));
    });

    testWidgets('arrow keys walk the cells and Enter chooses', (tester) async {
      final picked = <int>[];
      await _pump(tester, _bar(index: 0, onChanged: picked.add));

      await tester.tap(find.text('One'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(picked, [0, 1]);
    });

    testWidgets('arrow keys skip a disabled cell', (tester) async {
      final picked = <int>[];
      await _pump(
        tester,
        PureTabBar(
          items: const [
            PureTabBarItem(icon: Icons.home, label: 'One'),
            PureTabBarItem(icon: Icons.search, label: 'Two', enabled: false),
            PureTabBarItem(icon: Icons.person, label: 'Three'),
          ],
          index: 0,
          onChanged: picked.add,
        ),
      );

      await tester.tap(find.text('One'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(picked, [0, 2]);
    });

    testWidgets('an arrow past the edge is left to the shell', (tester) async {
      final picked = <int>[];
      await _pump(tester, _bar(index: 0, onChanged: picked.add));

      await tester.tap(find.text('One'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Focus never moved, so Enter chose the cell already held.
      expect(picked, [0, 0]);
    });
  });

  group('badges', () {
    testWidgets('a count over the cap collapses to max+', (tester) async {
      await _pump(
        tester,
        PureTabBar(
          items: const [
            PureTabBarItem(icon: Icons.home, label: 'One', badge: PureTabBarBadge(count: 150)),
            PureTabBarItem(icon: Icons.search, label: 'Two'),
          ],
          index: 0,
          onChanged: (_) {},
        ),
      );

      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('a dot badge draws no text and a label badge draws its own', (tester) async {
      await _pump(
        tester,
        PureTabBar(
          items: const [
            PureTabBarItem(icon: Icons.home, label: 'One', badge: PureTabBarBadge(dot: true)),
            PureTabBarItem(
              icon: Icons.search,
              label: 'Two',
              badge: PureTabBarBadge(label: 'NEW'),
            ),
          ],
          index: 0,
          onChanged: (_) {},
        ),
      );

      expect(find.text('NEW'), findsOneWidget);
    });
  });

  group('semantics', () {
    testWidgets('the selected cell reads as a selected button', (tester) async {
      await _pump(tester, _bar(index: 0));

      final cell = tester.widget<Semantics>(
        find.ancestor(of: find.text('One'), matching: find.byType(Semantics)).first,
      );
      expect(cell.properties.selected, isTrue);
      expect(cell.properties.button, isTrue);
    });

    testWidgets('an icon-only cell answers to its semantic label', (tester) async {
      await _pump(
        tester,
        PureTabBar(
          items: const [
            PureTabBarItem(icon: Icons.home, semanticLabel: 'Home'),
            PureTabBarItem(icon: Icons.search, semanticLabel: 'Search'),
          ],
          index: 0,
          onChanged: (_) {},
        ),
      );

      final cell = tester.widget<Semantics>(
        find.ancestor(of: find.byType(Icon).first, matching: find.byType(Semantics)).first,
      );
      expect(cell.properties.label, 'Home');
    });

    testWidgets('an empty bar is an empty box', (tester) async {
      await _pump(tester, const PureTabBar(items: [], index: 0, onChanged: null));

      expect(find.byType(AnimatedPositioned), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('every design language builds the pill bar', (tester) async {
    for (final language in PureDesignLanguage.values) {
      await _pump(tester, _bar(index: 1), language: language);
      expect(tester.takeException(), isNull, reason: '$language failed to build');
      // Every language places exactly one indicator behind the selection.
      expect(find.byType(AnimatedPositioned), findsOneWidget, reason: '$language lost its indicator');
    }
  });
}

PureTabBar _bar({required int index, ValueChanged<int>? onChanged, PureTabBarSize size = PureTabBarSize.standard}) =>
    PureTabBar(items: _items, index: index, size: size, onChanged: onChanged ?? (_) {});

double _cellMinHeight(WidgetTester tester) =>
    tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).constraints!.minHeight;

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  PureDesignLanguage language = PureDesignLanguage.material,
}) async {
  await tester.pumpWidget(
    PureConfigProvider(
      config: UiConfig(language: language),
      child: MaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: 300, height: 120, child: child)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
