// The seams where PureTabs used to accept `isScrollable` and never read it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macos_ui/macos_ui.dart' show MacosTheme, MacosThemeData;
import 'package:pure_uikit/pure_uikit.dart';

const List<PureTab> _tabs = [PureTab(label: 'One'), PureTab(label: 'Two'), PureTab(label: 'Three')];

void _select(int index) {}

void main() {
  testWidgets('a fixed strip stretches its tabs across the box', (tester) async {
    await _pump(tester, const PureTabs(tabs: _tabs, index: 0, onChanged: _select));

    final bar = tester.widget<TabBar>(find.byType(TabBar));
    expect(bar.isScrollable, isFalse);
    expect(bar.tabAlignment, TabAlignment.fill);
    // Three equal slots of a 300dp box: the labels sit at 50, 150 and 250.
    expect(_centers(tester), [50, 150, 250]);
  });

  testWidgets('a scrollable strip keeps each tab its own width', (tester) async {
    await _pump(tester, const PureTabs(tabs: _tabs, index: 0, isScrollable: true, onChanged: _select));

    final bar = tester.widget<TabBar>(find.byType(TabBar));
    expect(bar.isScrollable, isTrue);
    expect(bar.tabAlignment, TabAlignment.start);
    final centers = _centers(tester);
    // Left-packed at their own widths: the strip ends where its content ends
    // instead of spreading across the box it was given.
    expect(centers.first, lessThan(50));
    expect(centers[1] - centers[0], isNot(equals(100)));
    expect(centers.last, lessThan(250));
  });

  testWidgets('the macOS strip scrolls rather than overflowing its box', (tester) async {
    // Measured: its cells neither shrink nor ellipsize, so three labels of
    // uneven length overflowed a 360dp box by 167px with the flag left false.
    await tester.pumpWidget(
      PureConfigProvider(
        config: const UiConfig(language: PureDesignLanguage.macos),
        child: MacosTheme(
          data: MacosThemeData.light(),
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 360,
                child: PureTabs(
                  tabs: [PureTab(label: 'All'), PureTab(label: 'Followed'), PureTab(label: 'Recently watched a lot')],
                  index: 0,
                  onChanged: _select,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });
}

List<double> _centers(WidgetTester tester) => [
  for (var tab = 0; tab < _tabs.length; tab++) tester.getCenter(find.byType(Tab).at(tab)).dx,
];

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    PureConfigProvider(
      config: const UiConfig(language: PureDesignLanguage.material),
      child: MaterialApp(
        home: Scaffold(body: SizedBox(width: 300, child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
