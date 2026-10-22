import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_uikit/pure_uikit.dart';

const List<String> _labels = ['One', 'Two', 'Three'];

void main() {
  group('branches', () {
    testWidgets('every design language builds the segmented bar with one sliding selection', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pump(tester, _bar(index: 1), language: language);
        expect(tester.takeException(), isNull, reason: '$language failed to build');
        // Every language seats exactly one animated selection behind the cell.
        expect(find.byType(AnimatedPositioned), findsOneWidget, reason: '$language lost its selection');
        expect(find.text('Two'), findsOneWidget, reason: '$language lost its labels');
      }
    });

    testWidgets('an empty bar is an empty box', (tester) async {
      await _pump(tester, const PureSegmented(labels: [], index: 0, onChanged: null));
      expect(find.byType(AnimatedPositioned), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('selection', () {
    testWidgets('a tap on a segment reports its index', (tester) async {
      final picked = <int>[];
      await _pump(tester, _bar(index: 0, onChanged: picked.add));

      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();

      expect(picked, [1]);
    });

    testWidgets('the selection slides to an outside choice', (tester) async {
      await _pump(tester, _bar(index: 0));
      final start = tester.getRect(find.byType(AnimatedPositioned));
      // The selection covers the chosen cell exactly.
      expect(start.center.dx, moreOrLessEquals(_cellCenter(tester, 0)));

      await _pump(tester, _bar(index: 2));
      final end = tester.getRect(find.byType(AnimatedPositioned));
      expect(end.center.dx, moreOrLessEquals(_cellCenter(tester, 2)));
      expect(end.center.dx, greaterThan(start.center.dx));
    });

    testWidgets('expand gives every segment the same width', (tester) async {
      await _pump(tester, PureSegmented(labels: _labels, index: 0, expand: true, onChanged: (_) {}));

      final widths = [
        for (var i = 0; i < _labels.length; i++) tester.getRect(find.byType(AnimatedContainer).at(i)).width,
      ];
      expect(widths[0], moreOrLessEquals(widths[1]));
      expect(widths[1], moreOrLessEquals(widths[2]));
    });
  });

  group('disabled', () {
    testWidgets('a disabled bar ignores taps', (tester) async {
      final picked = <int>[];
      await _pump(tester, _bar(index: 0, onChanged: picked.add, enabled: false));

      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();
      expect(picked, isEmpty);
    });

    testWidgets('an inert bar (null callback) answers nothing', (tester) async {
      await _pump(tester, const PureSegmented(labels: _labels, index: 0, onChanged: null));

      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();

      // The grey selection stays where the caller put it.
      final pill = tester.getRect(find.byType(AnimatedPositioned));
      expect(pill.center.dx, moreOrLessEquals(_cellCenter(tester, 0)));
    });

    testWidgets('a disabled segment ignores taps while its neighbours stay live', (tester) async {
      final picked = <int>[];
      await _pump(tester, PureSegmented(labels: _labels, index: 0, disabledIndexes: const {1}, onChanged: picked.add));

      await tester.tap(find.text('Two'));
      await tester.pumpAndSettle();
      expect(picked, isEmpty);

      await tester.tap(find.text('Three'));
      expect(picked, [2]);
    });
  });

  group('keyboard', () {
    testWidgets('arrow keys walk the segments and Enter chooses', (tester) async {
      final picked = <int>[];
      await _pump(tester, _bar(index: 0, onChanged: picked.add));

      await tester.tap(find.text('One'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // The tap chose segment 0; Enter on the focused segment chose 1.
      expect(picked, [0, 1]);
    });

    testWidgets('arrow keys skip a disabled segment', (tester) async {
      final picked = <int>[];
      await _pump(tester, PureSegmented(labels: _labels, index: 0, disabledIndexes: const {1}, onChanged: picked.add));

      await tester.tap(find.text('One'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Focus jumped past the disabled middle segment to the last one.
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

      // Focus never moved, so Enter chose the segment already held.
      expect(picked, [0, 0]);
    });
  });

  group('semantics', () {
    testWidgets('the chosen segment reads as a selected button', (tester) async {
      await _pump(tester, _bar(index: 1));

      final cell = tester.widget<Semantics>(
        find.ancestor(of: find.text('Two'), matching: find.byType(Semantics)).first,
      );
      expect(cell.properties.selected, isTrue);
      expect(cell.properties.button, isTrue);

      final neighbour = tester.widget<Semantics>(
        find.ancestor(of: find.text('One'), matching: find.byType(Semantics)).first,
      );
      expect(neighbour.properties.selected, isFalse);
    });

    testWidgets('the bar is a semantics container', (tester) async {
      await _pump(tester, _bar(index: 0));
      final containers = find.byWidgetPredicate((w) => w is Semantics && w.container == true);
      expect(containers, findsWidgets);
    });
  });

  group('app contract', () {
    // Mirrors how apps/pure_live uses it: labels + index + onChanged, nothing
    // else — the constructor every caller already builds against.
    testWidgets('the labels/index/onChanged constructor selects and animates', (tester) async {
      int? current = 0;
      final chosen = <int>[];
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => _wrap(
            PureSegmented(
              labels: const ['Platform', 'Viewers'],
              index: current!,
              onChanged: (i) {
                chosen.add(i);
                setState(() => current = i);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Viewers'));
      await tester.pumpAndSettle();

      expect(chosen, [1]);
      final pill = tester.getRect(find.byType(AnimatedPositioned));
      expect(pill.center.dx, moreOrLessEquals(_cellCenter(tester, 1)));
    });
  });
}

/// The centre-x of segment [i]'s cell box — the sliding selection is measured
/// against the cell, not its glyph, so the Material check icon cannot mislead.
double _cellCenter(WidgetTester tester, int i) => tester.getRect(find.byType(AnimatedContainer).at(i)).center.dx;

PureSegmented _bar({required int index, ValueChanged<int>? onChanged, bool enabled = true}) =>
    PureSegmented(labels: _labels, index: index, enabled: enabled, onChanged: onChanged ?? (_) {});

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  PureDesignLanguage language = PureDesignLanguage.material,
}) async {
  await tester.pumpWidget(_wrap(child, language: language));
  await tester.pumpAndSettle();
}

Widget _wrap(Widget child, {PureDesignLanguage language = PureDesignLanguage.material}) => PureConfigProvider(
  config: UiConfig(language: language),
  child: MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox(width: 360, child: child)),
    ),
  ),
);
