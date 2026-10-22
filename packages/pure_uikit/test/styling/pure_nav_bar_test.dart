import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The branch key the public widget hangs on its body: the language whose
/// shape a bar is drawing is addressable in tests and diagnostics.
Key _branch(PureDesignLanguage language) => ValueKey('PureNavBar.${language.name}');

/// The sliding selection mark — one per bar wherever the language draws one.
const Key _mark = ValueKey('PureNavBar.mark');

const List<PureNavBarItem> _items = [
  PureNavBarItem(label: 'Home', icon: Icons.home_outlined),
  PureNavBarItem(label: 'Pulse', icon: Icons.local_fire_department_outlined),
  PureNavBarItem(label: 'Me', icon: Icons.person_outline),
];

/// The height each language's own strip keeps, in absolute pixels.
const Map<PureDesignLanguage, double> _height = {
  PureDesignLanguage.material: 80,
  PureDesignLanguage.cupertino: 49,
  PureDesignLanguage.macos: 52,
  PureDesignLanguage.fluent: 48,
  PureDesignLanguage.yaru: 56,
  PureDesignLanguage.forui: 64,
  PureDesignLanguage.glass: 64,
  PureDesignLanguage.neumorphic: 64,
  PureDesignLanguage.wind: 56,
};

/// The canvas width the harness gives the bar. The bar carries its own height
/// (asserting against a tight height we set would only assert the harness),
/// so the box constrains width only.
const double _width = 320;

/// The centre of cell [index] in window coordinates: every language centres
/// its icon-over-label stack in the cell, and the mark on that stack — so the
/// chosen label's own centre is where the mark belongs, whatever insets or
/// track paddings the language carries.
double _cellCenter(WidgetTester tester, int index) => tester.getRect(find.text(_items[index].label)).center.dx;

/// The semantics a destination cell paints: the button role and the label
/// name it for a screen reader.
Semantics _cellSemantics(WidgetTester tester, String label) => tester.widget<Semantics>(
  find.byWidgetPredicate(
    (widget) => widget is Semantics && (widget.properties.button ?? false) && widget.properties.label == label,
  ),
);

/// True when the widget tree carries no library's own bar: every language is
/// painted here, nothing is delegated.
bool _isDelegatedBar(Widget widget) => const {
  'NavigationBar',
  'BottomNavigationBar',
  'CupertinoTabBar',
  'FBottomNavigationBar',
  'NeuBottomNav',
  'FluentTabList',
  'MacosTab',
}.contains(widget.runtimeType.toString());

Future<void> _pump(
  WidgetTester tester, {
  PureDesignLanguage language = PureDesignLanguage.material,
  List<PureNavBarItem> items = _items,
  int index = 0,
  ValueChanged<int>? onChanged,
  bool enabled = true,
  bool animations = true,
  Brightness brightness = Brightness.light,
}) async {
  final bar = PureNavBar(items: items, index: index, onChanged: onChanged, enabled: enabled);
  await tester.pumpWidget(
    PureConfigProvider(
      config: UiConfig(
        language: language,
        animations: animations,
        brightness: brightness == Brightness.dark ? UiBrightnessMode.dark : UiBrightnessMode.light,
      ),
      child: MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(width: _width, child: bar),
          ),
        ),
      ),
    ),
  );
  // Settle past the post-frame measurement that seats the mark.
  await tester.pumpAndSettle();
}

void main() {
  group('branches', () {
    testWidgets('every design language draws its own bar and nothing delegates', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pump(tester, language: language);
        expect(tester.takeException(), isNull, reason: '${language.name} failed to build');
        expect(find.byKey(_branch(language)), findsOneWidget, reason: '${language.name} lost its branch');
        expect(find.text('Home'), findsOneWidget, reason: '${language.name} lost its labels');
        expect(find.text('Pulse'), findsOneWidget);
        expect(find.text('Me'), findsOneWidget);
        // The house contract: no library's bar sits under the widget.
        expect(
          find.byWidgetPredicate(_isDelegatedBar),
          findsNothing,
          reason: '${language.name} delegated its bar to a library',
        );
      }
    });

    testWidgets('each strip keeps its own height tier at the width it is given', (tester) async {
      for (final entry in _height.entries) {
        await _pump(tester, language: entry.key);
        final size = tester.getSize(find.byKey(_branch(entry.key)));
        expect(size.height, entry.value, reason: '${entry.key.name} lost its own height');
        expect(size.width, _width, reason: '${entry.key.name} did not fill the width it was given');
      }
    });

    testWidgets('every language but iOS seats one sliding mark on the chosen cell', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pump(tester, language: language, index: 1);
        if (language == PureDesignLanguage.cupertino) {
          // iOS 18 answers selection with the tint alone — an invented pill
          // would say Android.
          expect(find.byKey(_mark), findsNothing, reason: '${language.name} drew a mark it should not');
          continue;
        }
        expect(find.byKey(_mark), findsOneWidget, reason: '${language.name} lost its mark');
        expect(
          tester.getRect(find.byKey(_mark)).center.dx,
          moreOrLessEquals(_cellCenter(tester, 1), epsilon: 0.5),
          reason: '${language.name} seated the mark on the wrong cell',
        );
      }
    });

    testWidgets('the dark ramp keeps the same shapes', (tester) async {
      for (final entry in _height.entries) {
        await _pump(tester, language: entry.key, brightness: Brightness.dark);
        expect(tester.takeException(), isNull, reason: '${entry.key.name} failed in dark');
        expect(
          tester.getSize(find.byKey(_branch(entry.key))).height,
          entry.value,
          reason: '${entry.key.name} re-picked its geometry in dark',
        );
      }
    });
  });

  group('selection', () {
    testWidgets('a tap reports the destination index, in every language', (tester) async {
      for (final language in PureDesignLanguage.values) {
        final picked = <int>[];
        await _pump(tester, language: language, onChanged: picked.add);
        await tester.tap(find.text('Me'));
        await tester.pumpAndSettle();
        expect(picked, [2], reason: '${language.name} lost the tap');
      }
    });

    testWidgets('the mark slides to an outside choice', (tester) async {
      for (final language in PureDesignLanguage.values) {
        if (language == PureDesignLanguage.cupertino) {
          continue;
        }
        await _pump(tester, language: language, index: 1, onChanged: (_) {});
        final start = tester.getRect(find.byKey(_mark)).center.dx;
        expect(start, moreOrLessEquals(_cellCenter(tester, 1), epsilon: 0.5));

        await _pump(tester, language: language, index: 2, onChanged: (_) {});
        final end = tester.getRect(find.byKey(_mark)).center.dx;
        expect(end, moreOrLessEquals(_cellCenter(tester, 2), epsilon: 0.5), reason: '${language.name} never re-seated');
        expect(end, greaterThan(start), reason: '${language.name} slid the wrong way');
      }
    });

    testWidgets('an inert bar answers nothing', (tester) async {
      // `enabled: false` and a null callback are the same inert answer.
      final picked = <int>[];
      await _pump(tester, enabled: false, onChanged: picked.add);
      await tester.tap(find.text('Me'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(picked, isEmpty, reason: 'a disabled bar took a tap');
      expect(find.byKey(_branch(PureDesignLanguage.material)), findsOneWidget);

      await _pump(tester);
      await tester.tap(find.text('Me'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(picked, isEmpty, reason: 'a null-callback bar took a tap');
    });

    testWidgets('a disabled destination answers nothing while its neighbours do', (tester) async {
      final picked = <int>[];
      const items = [
        PureNavBarItem(label: 'Home', icon: Icons.home_outlined),
        PureNavBarItem(label: 'Pulse', icon: Icons.local_fire_department_outlined, enabled: false),
        PureNavBarItem(label: 'Me', icon: Icons.person_outline),
      ];
      await _pump(tester, items: items, onChanged: picked.add);

      await tester.tap(find.text('Pulse'));
      await tester.pumpAndSettle();
      expect(picked, isEmpty, reason: 'a disabled destination answered a tap');

      await tester.tap(find.text('Me'));
      await tester.pumpAndSettle();
      expect(picked, [2], reason: 'a disabled neighbour swallowed the whole bar');
    });

    testWidgets('an out-of-range index clamps into the bar', (tester) async {
      await _pump(tester, index: -1, onChanged: (_) {});
      expect(tester.takeException(), isNull);
      expect(_cellSemantics(tester, 'Home').properties.selected, isTrue, reason: '-1 did not clamp to the first cell');

      await _pump(tester, index: 99, onChanged: (_) {});
      expect(_cellSemantics(tester, 'Me').properties.selected, isTrue, reason: '99 did not clamp to the last cell');
      // A clamped bar still answers its cells.
      final picked = <int>[];
      await _pump(tester, index: 99, onChanged: picked.add);
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(picked, [0]);
    });

    testWidgets('an empty bar is an empty box', (tester) async {
      await _pump(tester, items: const []);
      expect(tester.takeException(), isNull);
      expect(find.byType(PureNavBar), findsOneWidget);
      expect(find.byWidgetPredicate(_isDelegatedBar), findsNothing);
    });
  });

  group('semantics and keyboard', () {
    testWidgets('the bar reads as a container of named, selectable buttons', (tester) async {
      await _pump(tester, index: 1, onChanged: (_) {});

      final container = tester.widget<Semantics>(
        find.descendant(of: find.byType(PureNavBar), matching: find.byType(Semantics)).first,
      );
      expect(container.container, isTrue, reason: 'the strip lost its container role');

      expect(_cellSemantics(tester, 'Pulse').properties.selected, isTrue);
      expect(_cellSemantics(tester, 'Pulse').properties.enabled, isTrue);
      expect(_cellSemantics(tester, 'Home').properties.selected, isFalse);
      expect(_cellSemantics(tester, 'Me').properties.selected, isFalse);
    });

    testWidgets('arrow keys traverse the cells and space chooses', (tester) async {
      final picked = <int>[];
      await _pump(tester, onChanged: picked.add);

      // Focus the first cell with a live tap (0), then walk right and choose.
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(picked, [0]);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(picked, [0, 1], reason: 'Right then Space did not choose the second destination');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(picked, [0, 1, 0], reason: 'Left then Enter did not choose the first destination');
    });

    testWidgets('traversal skips a disabled destination', (tester) async {
      final picked = <int>[];
      const items = [
        PureNavBarItem(label: 'Home', icon: Icons.home_outlined),
        PureNavBarItem(label: 'Pulse', icon: Icons.local_fire_department_outlined, enabled: false),
        PureNavBarItem(label: 'Me', icon: Icons.person_outline),
      ];
      await _pump(tester, items: items, onChanged: picked.add);

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(picked, [0, 2], reason: 'the keyboard stepped into a disabled destination');
    });

    testWidgets('an inert bar takes no keys', (tester) async {
      final picked = <int>[];
      await _pump(tester, enabled: false, onChanged: picked.add);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(picked, isEmpty, reason: 'the keyboard woke a disabled bar');
    });
  });
}
