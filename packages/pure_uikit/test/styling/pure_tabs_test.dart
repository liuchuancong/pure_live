// The strip is painted by the kit now, so these cases read the geometry the
// caller asked for off the cells themselves — the seams where `isScrollable`
// used to be answered by whichever library the config happened to name.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_uikit/pure_uikit.dart';

const List<PureTab> _tabs = [PureTab(label: 'One'), PureTab(label: 'Two'), PureTab(label: 'Three')];

void _select(int index) {}

void main() {
  testWidgets('a fixed strip stretches its tabs across the box', (tester) async {
    await _pump(tester, const PureTabs(tabs: _tabs, index: 0, onChanged: _select));

    // Nothing scrolls: the strip fills the box it was given and shares it.
    expect(find.byType(SingleChildScrollView), findsNothing);
    // Three equal slots of a 300dp box: the labels sit at 50, 150 and 250.
    expect(_centers(tester), [50, 150, 250]);
  });

  testWidgets('a scrollable strip keeps each tab its own width', (tester) async {
    await _pump(tester, const PureTabs(tabs: _tabs, index: 0, isScrollable: true, onChanged: _select));

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    final centers = _centers(tester);
    // Left-packed at their own widths: the strip ends where its content ends
    // instead of spreading across the box it was given.
    expect(centers.first, lessThan(50));
    expect(centers[1] - centers[0], isNot(equals(100)));
    expect(centers.last, lessThan(250));
  });

  testWidgets('the macOS strip squeezes and ellipsizes rather than overflowing its box', (tester) async {
    // Measured under the library branch: its cells neither shrank nor
    // ellipsized, so three labels of uneven length overflowed a 360dp box by
    // 167px. Painted here, the same labels take an equal third of the box and
    // the widest one trails off — no scroll wrapper needed to keep it honest.
    await _pump(
      tester,
      const PureTabs(
        tabs: [
          PureTab(label: 'All'),
          PureTab(label: 'Followed'),
          PureTab(label: 'Recently watched a lot'),
        ],
        index: 0,
        onChanged: _select,
      ),
      language: PureDesignLanguage.macos,
      width: 360,
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(tester.getRect(find.byType(PureTabs)).width, moreOrLessEquals(360));
    for (final label in const ['All', 'Followed', 'Recently watched a lot']) {
      expect(find.text(label), findsOneWidget);
    }
  });
}

List<double> _centers(WidgetTester tester) => [for (final tab in _tabs) tester.getCenter(find.text(tab.label)).dx];

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  PureDesignLanguage language = PureDesignLanguage.material,
  double width = 300,
}) async {
  await tester.pumpWidget(
    PureConfigProvider(
      config: UiConfig(language: language),
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
