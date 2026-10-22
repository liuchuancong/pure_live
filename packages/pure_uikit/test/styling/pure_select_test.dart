import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_uikit/pure_uikit.dart';

const List<String> _options = ['One', 'Two', 'Three'];

const Key _menuKey = ValueKey<String>('PureSelect.menu');

/// A menu-scoped label finder: the closed field already shows the chosen
/// label, and the hidden menu keeps every option mounted, so an unscoped
/// `find.text` would answer with the trigger as well.
Finder option(String label) => find.descendant(of: find.byKey(_menuKey), matching: find.text(label));

bool _menuOpen(WidgetTester tester) => find.byKey(_menuKey).evaluate().isNotEmpty;

double _menuOpacity(WidgetTester tester) => tester.widget<FadeTransition>(find.byKey(_menuKey)).opacity.value;

void main() {
  group('the closed field', () {
    testWidgets('it carries the chosen value and the placeholder answers for nothing-chosen', (tester) async {
      await _pump(tester, _select(value: 'Two'));
      expect(find.text('Two'), findsWidgets);

      await _pump(tester, _select(placeholder: 'Pick one'));
      expect(find.text('Pick one'), findsOneWidget);
    });

    testWidgets('a value the list does not carry shows the placeholder, not a phantom selection', (tester) async {
      await _pump(tester, _select(value: 'Zulu', placeholder: 'Pick one'));

      expect(find.text('Pick one'), findsOneWidget);
      expect(find.text('Zulu'), findsNothing);
    });

    testWidgets('the field takes the control-height token', (tester) async {
      await _pump(tester, _select());

      expect(tester.getRect(find.byType(AnimatedContainer).first).height, 32);
    });

    testWidgets('an empty option list is a field that opens nothing', (tester) async {
      final picked = <String>[];
      await _pump(tester, _select(items: const [], placeholder: 'Pick one', onChanged: picked.add));

      await tester.tap(find.byType(PureSelect<String>));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(_menuOpen(tester), isFalse);
      expect(picked, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  group('opening and choosing', () {
    testWidgets('a tap opens the menu and choosing an option reports the value and closes', (tester) async {
      final picked = <String>[];
      await _pump(tester, _select(value: 'One', onChanged: picked.add));

      await tester.tap(find.byType(PureSelect<String>));
      await tester.pumpAndSettle();
      expect(_menuOpen(tester), isTrue);

      await tester.tap(option('Two'));
      await tester.pumpAndSettle();

      expect(picked, ['Two']);
      expect(_menuOpen(tester), isFalse);
    });

    testWidgets('a second tap on the field closes the menu without choosing', (tester) async {
      final picked = <String>[];
      await _pump(tester, _select(value: 'One', onChanged: picked.add));

      await tester.tap(find.byType(PureSelect<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PureSelect<String>));
      await tester.pumpAndSettle();

      expect(_menuOpen(tester), isFalse);
      expect(picked, isEmpty);
    });

    testWidgets('the menu fades and lifts in, and fades and lifts out', (tester) async {
      await _pump(tester, _select(value: 'One', onChanged: (_) {}));

      await tester.tap(find.byType(PureSelect<String>));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(_menuOpacity(tester), greaterThan(0));
      expect(_menuOpacity(tester), lessThan(1));
      await tester.pumpAndSettle();
      expect(_menuOpacity(tester), 1);

      await tester.tap(find.byType(PureSelect<String>));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(_menuOpacity(tester), greaterThan(0));
      expect(_menuOpacity(tester), lessThan(1));
      await tester.pumpAndSettle();
      expect(find.byKey(_menuKey), findsNothing);
    });

    testWidgets('hovering an option moves the highlight there', (tester) async {
      final picked = <String>[];
      await _pump(tester, _select(value: 'One', onChanged: picked.add));

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);

      await mouse.moveTo(tester.getCenter(find.byType(PureSelect<String>)));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PureSelect<String>));
      await tester.pumpAndSettle();
      await mouse.moveTo(tester.getCenter(option('Three')));
      await tester.pumpAndSettle();
      await mouse.moveTo(tester.getCenter(find.byType(PureSelect<String>)));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(picked, ['Three']);
    });

    testWidgets('a long option list scrolls under the menu ceiling', (tester) async {
      final many = [for (var i = 0; i < 20; i++) 'Item $i'];
      final picked = <String>[];
      await _pump(tester, _select(items: many, value: 'Item 0', onChanged: picked.add));

      await tester.tap(find.byType(PureSelect<String>));
      await tester.pumpAndSettle();
      expect(find.byType(Scrollable), findsWidgets);

      final menuRect = tester.getRect(find.byKey(_menuKey));
      expect(menuRect.height, lessThanOrEqualTo(300));
      expect(tester.takeException(), isNull);
    });
  });

  group('the keyboard contract', () {
    testWidgets('Enter, Space and Down open; Down moves the highlight; Enter chooses', (tester) async {
      final picked = <String>[];
      await _pump(tester, _select(value: 'One', onChanged: picked.add));

      await tester.tap(find.byType(PureSelect<String>));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_menuOpen(tester), isFalse);

      // Down re-opens — focus never left the field.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(_menuOpen(tester), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(picked, ['Two']);
      expect(_menuOpen(tester), isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(_menuOpen(tester), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(picked, ['Two']);
    });

    testWidgets('Up walks the highlight and an arrow past the edge stops there', (tester) async {
      final picked = <String>[];
      await _pump(tester, _select(value: 'One', onChanged: picked.add));

      await tester.tap(find.byType(PureSelect<String>));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Up from the first option stays at the first; Enter then chooses it.
      expect(picked, ['One']);
    });

    testWidgets('Up opens at the last option and Escape closes without choosing', (tester) async {
      final picked = <String>[];
      await _pump(tester, _select(value: 'One', onChanged: picked.add));

      await tester.tap(find.byType(PureSelect<String>));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(picked, ['Three']);
    });
  });

  group('a disabled select refuses', () {
    testWidgets('enabled: false greys the field, refuses taps and keys', (tester) async {
      final picked = <String>[];
      await _pump(tester, _select(value: 'One', enabled: false, onChanged: picked.add));

      await tester.tap(find.byType(PureSelect<String>));
      await tester.pumpAndSettle();
      expect(_menuOpen(tester), isFalse);

      final semantics = tester.widget<Semantics>(
        find.descendant(of: find.byType(PureSelect<String>), matching: find.byType(Semantics)).first,
      );
      expect(semantics.properties.enabled, isFalse);

      // Nothing to choose from: the menu never mounted, so no option answers.
      expect(find.byKey(_menuKey), findsNothing);
      expect(picked, isEmpty);
    });

    testWidgets('a null callback is the same refusal', (tester) async {
      await _pump(tester, _select(value: 'One'));

      await tester.tap(find.byType(PureSelect<String>));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(_menuOpen(tester), isFalse);
    });

    testWidgets('a select that goes inert while open closes its menu', (tester) async {
      await _pump(tester, _select(value: 'One', onChanged: (_) {}));
      await tester.tap(find.byType(PureSelect<String>));
      await tester.pumpAndSettle();
      expect(_menuOpen(tester), isTrue);

      await _pump(tester, _select(value: 'One', enabled: false));
      await tester.pumpAndSettle();
      expect(_menuOpen(tester), isFalse);
    });
  });

  group('semantics', () {
    testWidgets('the field reads as a button that says whether its menu is expanded', (tester) async {
      await _pump(tester, _select(value: 'One', onChanged: (_) {}));

      Semantics triggerSemantics() => tester.widget<Semantics>(
        find.descendant(of: find.byType(PureSelect<String>), matching: find.byType(Semantics)).first,
      );
      expect(triggerSemantics().properties.button, isTrue);
      expect(triggerSemantics().properties.expanded, isFalse);

      await tester.tap(find.byType(PureSelect<String>));
      await tester.pumpAndSettle();
      expect(triggerSemantics().properties.expanded, isTrue);
    });

    testWidgets('the chosen option reads as selected inside the open menu', (tester) async {
      await _pump(tester, _select(value: 'Two', onChanged: (_) {}));

      await tester.tap(find.byType(PureSelect<String>));
      await tester.pumpAndSettle();

      final rows = tester.widgetList<Semantics>(
        find.descendant(of: find.byKey(_menuKey), matching: find.byType(Semantics)),
      );
      expect(rows.where((row) => row.properties.selected == true), hasLength(1));
    });

    testWidgets('a closed menu keeps its options out of the tree', (tester) async {
      await _pump(tester, _select(value: 'One', onChanged: (_) {}));

      expect(_menuOpen(tester), isFalse);
      await tester.tap(find.byType(PureSelect<String>));
      await tester.pumpAndSettle();
      expect(_menuOpen(tester), isTrue);
    });
  });

  testWidgets('the menu keeps only choosable options', (tester) async {
    final picked = <String>[];
    await _pump(tester, _select(items: const ['One', 'One', 'Two'], value: 'One', onChanged: picked.add));

    await tester.tap(find.byType(PureSelect<String>));
    await tester.pumpAndSettle();

    expect(option('One'), findsOneWidget);
    expect(option('Two'), findsOneWidget);
  });

  group('every design language draws its own select', () {
    testWidgets('each opens, chooses and closes without a complaint', (tester) async {
      for (final language in PureDesignLanguage.values) {
        final picked = <String>[];
        await _pump(
          tester,
          _select(value: 'One', onChanged: picked.add),
          language: language,
          reason: '$language failed to build',
        );
        await tester.tap(find.byType(PureSelect<String>));
        await tester.pumpAndSettle();
        expect(_menuOpen(tester), isTrue, reason: '$language never opened');

        await tester.tap(option('Two'));
        await tester.pumpAndSettle();
        expect(picked, ['Two'], reason: '$language lost the choice');
        expect(tester.takeException(), isNull, reason: '$language failed');
      }
    });

    testWidgets("the trailing indicator is the language's own", (tester) async {
      await _pump(tester, _select());
      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsNothing);

      await _pump(tester, _select(), language: PureDesignLanguage.cupertino);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);

      await _pump(tester, _select(), language: PureDesignLanguage.macos);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);

      await _pump(tester, _select(), language: PureDesignLanguage.fluent);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);

      await _pump(tester, _select(), language: PureDesignLanguage.yaru);
      expect(find.byIcon(Icons.south), findsOneWidget);
    });

    testWidgets('material flips its arrow while the menu is open', (tester) async {
      await _pump(tester, _select(value: 'One', onChanged: (_) {}));

      await tester.tap(find.byType(PureSelect<String>));
      await tester.pumpAndSettle();
      final rotation = tester.widget<AnimatedRotation>(find.byType(AnimatedRotation).first);
      expect(rotation.turns, 0.5);
    });
  });
}

PureSelect<String> _select({
  List<String> items = _options,
  String? value,
  String? placeholder,
  bool enabled = true,
  ValueChanged<String>? onChanged,
}) => PureSelect<String>(
  items: items,
  value: value,
  placeholder: placeholder,
  enabled: enabled,
  itemLabel: (item) => item,
  onChanged: onChanged,
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  PureDesignLanguage language = PureDesignLanguage.material,
  String? reason,
}) async {
  await tester.pumpWidget(
    PureConfigProvider(
      config: UiConfig(language: language),
      child: MaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: 240, child: child)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: reason);
}
