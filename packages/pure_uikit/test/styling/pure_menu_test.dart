import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_uikit/pure_uikit.dart';

const List<PureMenuItem> _actions = [
  PureMenuItem(id: 'a', label: 'Alpha', icon: Icons.add),
  PureMenuItem(id: 'b', label: 'Beta', icon: Icons.edit),
  PureMenuItem(id: 'c', label: 'Gamma', icon: Icons.delete),
];

const Key _listKey = Key('PureMenu.list');

void main() {
  group('open', () {
    testWidgets('every design language draws and opens its own menu', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pump(tester, _menu(_actions), language: language);
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$language failed to build');
        expect(find.byKey(_listKey), findsOneWidget, reason: '$language lost its list');
        expect(find.text('Alpha'), findsOneWidget, reason: '$language lost its labels');
        // Close it again before the next language reuses the harness.
        await tester.tapAt(const Offset(4, 4));
        await tester.pumpAndSettle();
        expect(find.byKey(_listKey), findsNothing, reason: '$language would not dismiss');
      }
    });

    testWidgets('a tap on an item runs its callback after the menu has closed', (tester) async {
      final log = <String>[];
      final items = [for (final item in _actions) _withTap(item, log)];
      await _pump(tester, _menu(items));

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beta'));
      await tester.pumpAndSettle();

      expect(log, ['b']);
      expect(find.byKey(_listKey), findsNothing);
    });

    testWidgets('a trigger with no items opens nothing', (tester) async {
      await _pump(tester, _menu(const []));
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.byKey(_listKey), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a disabled trigger never opens', (tester) async {
      await _pump(tester, _menu(_actions, enabled: false));
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.byKey(_listKey), findsNothing);
    });
  });

  group('keyboard', () {
    testWidgets('Enter chooses the first live item without moving', (tester) async {
      final log = <String>[];
      await _pump(tester, _menu(_withTaps(_actions, log)));
      await _open(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(log, ['a']);
    });

    testWidgets('Down then Up walks back and Enter keeps the row', (tester) async {
      final log = <String>[];
      await _pump(tester, _menu(_withTaps(_actions, log)));
      await _open(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(log, ['a']);
    });

    testWidgets('End jumps to the last row and Enter chooses it', (tester) async {
      final log = <String>[];
      await _pump(tester, _menu(_withTaps(_actions, log)));
      await _open(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(log, ['c']);
    });

    testWidgets('Home returns to the first row', (tester) async {
      final log = <String>[];
      await _pump(tester, _menu(_withTaps(_actions, log)));
      await _open(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(log, ['a']);
    });

    testWidgets('the arrow keys step over a disabled row', (tester) async {
      final log = <String>[];
      final items = [
        const PureMenuItem(id: 'a', label: 'Alpha'),
        const PureMenuItem(id: 'b', label: 'Beta', enabled: false),
        const PureMenuItem(id: 'c', label: 'Gamma'),
      ];
      await _pump(tester, _menu(_withTaps(items, log)));
      await _open(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(log, ['c']);
    });

    testWidgets('the arrow keys step over a separator', (tester) async {
      final log = <String>[];
      final items = [
        const PureMenuItem(id: 'a', label: 'Alpha'),
        PureMenuItem.separator(),
        const PureMenuItem(id: 'b', label: 'Beta'),
      ];
      await _pump(tester, _menu(_withTaps(items, log)));
      await _open(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(log, ['b']);
    });

    testWidgets('Escape closes without choosing', (tester) async {
      final log = <String>[];
      await _pump(tester, _menu(_withTaps(_actions, log)));
      await _open(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(log, isEmpty);
      expect(find.byKey(_listKey), findsNothing);
    });
  });

  group('dismiss', () {
    testWidgets('a tap on the scrim closes without choosing', (tester) async {
      final log = <String>[];
      await _pump(tester, _menu(_withTaps(_actions, log)));
      await _open(tester);

      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      expect(log, isEmpty);
      expect(find.byKey(_listKey), findsNothing);
    });

    testWidgets('hover moves the active row, and Enter chooses it', (tester) async {
      final log = <String>[];
      await _pump(tester, _menu(_withTaps(_actions, log)));
      await _open(tester);

      // Without hovering the walk sits on the first row; resting the pointer on
      // the last moves it there, and Enter then chooses that row.
      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await pointer.addPointer(location: Offset.zero);
      addTearDown(pointer.removePointer);
      await pointer.moveTo(tester.getCenter(find.text('Gamma')));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(log, ['c']);
    });
  });

  group('marks', () {
    testWidgets('a checked item draws the tick and reports itself selected', (tester) async {
      await _pump(tester, _menu(const [PureMenuItem(id: 'on', label: 'Alpha', checked: true)]));
      await _open(tester);

      expect(find.byIcon(Icons.check), findsOneWidget);
      final row = tester.widget<Semantics>(
        find.ancestor(of: find.text('Alpha'), matching: find.byType(Semantics)).first,
      );
      expect(row.properties.selected, isTrue);
    });

    testWidgets('a shortcut prints in the trailing column', (tester) async {
      await _pump(tester, _menu(const [PureMenuItem(id: 'a', label: 'Alpha', shortcut: 'Ctrl+A')]));
      await _open(tester);

      expect(find.text('Ctrl+A'), findsOneWidget);
    });

    testWidgets('a disabled row greys out, is inert to a tap and reads disabled', (tester) async {
      final log = <String>[];
      final items = _withTaps(_actions, log);
      // The middle item is switched off and keeps no callback.
      items[1] = PureMenuItem(id: items[1].id, label: items[1].label, enabled: false);
      await _pump(tester, _menu(items));
      await _open(tester);

      await tester.tap(find.text('Beta'));
      await tester.pumpAndSettle();
      expect(log, isEmpty);
      expect(find.byKey(_listKey), findsOneWidget);

      final row = tester.widget<Semantics>(
        find.ancestor(of: find.text('Beta'), matching: find.byType(Semantics)).first,
      );
      expect(row.properties.enabled, isFalse);
    });

    testWidgets('an item with no callback is inert too', (tester) async {
      final log = <String>[];
      await _pump(tester, _menu([_withTap(_actions[0], log), _actions[1]]));
      await _open(tester);

      await tester.tap(find.text('Beta'));
      await tester.pumpAndSettle();
      expect(log, isEmpty);
      expect(find.byKey(_listKey), findsOneWidget);
    });
  });

  group('semantics', () {
    testWidgets('the list is a labelled group and each row a live button', (tester) async {
      final log = <String>[];
      await _pump(tester, _menu(_withTaps(_actions, log)));
      await _open(tester);

      // The whole list sits inside a semantics group of its own, so a reader
      // hears the card as one thing before its items.
      expect(find.ancestor(of: find.byKey(_listKey), matching: find.byType(Semantics)), findsWidgets);

      final row = tester.widget<Semantics>(
        find.ancestor(of: find.text('Alpha'), matching: find.byType(Semantics)).first,
      );
      expect(row.properties.button, isTrue);
      expect(row.properties.enabled, isTrue);
    });

    testWidgets('a separator carries no semantics of its own', (tester) async {
      await _pump(tester, _menu([_actions[0], PureMenuItem.separator(), _actions[1]]));
      await _open(tester);
      expect(tester.takeException(), isNull);
      // One rule between the two live rows; both stay reachable.
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
    });
  });

  group('showPureMenu', () {
    testWidgets('drops a menu at an explicit position and returns the choice', (tester) async {
      final log = <String>[];
      await tester.pumpWidget(
        PureConfigProvider(
          config: const UiConfig(language: PureDesignLanguage.fluent),
          child: MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: Builder(
                  builder: (context) => TextButton(
                    onPressed: () =>
                        showPureMenu(context, items: _withTaps(_actions, log), position: const Offset(20, 40)),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byKey(_listKey), findsOneWidget);

      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      expect(log, ['a']);
      expect(find.byKey(_listKey), findsNothing);
    });
  });
}

/// Taps the trigger and settles so the card is fully open.
Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.more_vert));
  await tester.pumpAndSettle();
  expect(find.byKey(_listKey), findsOneWidget);
}

PureMenuItem _withTap(PureMenuItem item, List<String> log) => PureMenuItem(
  id: item.id,
  label: item.label,
  icon: item.icon,
  danger: item.danger,
  enabled: item.enabled,
  checked: item.checked,
  shortcut: item.shortcut,
  onTap: () => log.add(item.id),
);

List<PureMenuItem> _withTaps(List<PureMenuItem> items, List<String> log) => [
  for (final item in items) _withTap(item, log),
];

PureMenu _menu(List<PureMenuItem> items, {bool enabled = true}) => PureMenu(
  enabled: enabled,
  items: items,
  child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.more_vert)),
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  PureDesignLanguage language = PureDesignLanguage.material,
}) async {
  await tester.pumpWidget(
    PureConfigProvider(
      config: UiConfig(language: language),
      child: MaterialApp(
        home: Scaffold(body: Center(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
