import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The stepper's timing contract restated as the test's own expectation: the
/// first repeat lands 400ms after the press and every following gap takes
/// 70% of the last — 280ms, then 196ms.
const Duration _holdStart = Duration(milliseconds: 400);
const Duration _secondGap = Duration(milliseconds: 280);
const Duration _thirdGap = Duration(milliseconds: 196);

void main() {
  group('branches', () {
    testWidgets('every design language builds the stepper', (tester) async {
      for (final language in PureDesignLanguage.values) {
        final calls = <double>[];
        await _pump(tester, _stepper(calls: calls), language: language);
        expect(tester.takeException(), isNull, reason: '$language failed to build');
        expect(find.text('5'), findsOneWidget, reason: '$language lost the value');
        expect(find.byType(Icon), findsNWidgets(2), reason: '$language lost its two step cells');
      }
    });

    testWidgets('material cells are circles and the rest are not', (tester) async {
      await _pump(tester, _stepper(calls: <double>[]));
      expect(_cellDeco(tester, Icons.add).borderRadius, BorderRadius.circular(PureRadii.pill));

      await _pump(tester, _stepper(calls: <double>[]), language: PureDesignLanguage.macos);
      expect(_cellDeco(tester, Icons.expand_less).borderRadius, BorderRadius.zero);
    });

    testWidgets('fluent and macos spin chevrons; the flanking languages press plus and minus', (tester) async {
      await _pump(tester, _stepper(calls: <double>[]), language: PureDesignLanguage.fluent);
      expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      expect(find.byIcon(Icons.add), findsNothing);

      await _pump(tester, _stepper(calls: <double>[]), language: PureDesignLanguage.macos);
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);

      await _pump(tester, _stepper(calls: <double>[]), language: PureDesignLanguage.cupertino);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);
    });

    testWidgets('wind keeps its sibling grammar: the bordered, plate-filled cell', (tester) async {
      for (final language in [PureDesignLanguage.forui, PureDesignLanguage.wind]) {
        await _pump(tester, _stepper(calls: <double>[]), language: language);
        final theme = _theme(tester);
        final deco = _cellDeco(tester, Icons.add);
        expect(deco.border!.top.color, theme.colors.borderSecondary, reason: '$language lost the border');
        expect(deco.color, theme.colors.bgContainer, reason: '$language lost the plate');
      }
    });

    testWidgets('neumorphic rests raised and presses its shadow the other way', (tester) async {
      await _pump(tester, _stepper(calls: <double>[]), language: PureDesignLanguage.neumorphic);
      // The emboss is a pair — shadow bottom-right, light top-left — and the
      // press reverses both offsets.
      expect(_cellDeco(tester, Icons.add).boxShadow!.first.offset, const Offset(3, 3));

      final gesture = await tester.startGesture(tester.getCenter(find.byIcon(Icons.add)));
      await tester.pumpAndSettle();
      expect(_cellDeco(tester, Icons.add).boxShadow!.first.offset, const Offset(-3, -3));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_cellDeco(tester, Icons.add).boxShadow!.first.offset, const Offset(3, 3));
    });

    testWidgets('fluent answers hover in the accent', (tester) async {
      await _pump(tester, _stepper(calls: <double>[]), language: PureDesignLanguage.fluent);
      final upCell = find.byIcon(Icons.keyboard_arrow_up);
      final rest = tester.widget<Icon>(upCell).color;

      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await pointer.addPointer(location: Offset.zero);
      await tester.pump();
      await pointer.moveTo(tester.getCenter(upCell));
      await tester.pumpAndSettle();

      expect(tester.widget<Icon>(upCell).color, _theme(tester).colors.primary);
      expect(tester.widget<Icon>(upCell).color, isNot(rest));
      await pointer.removePointer();
      await tester.pumpAndSettle();
    });
  });

  group('value and bounds', () {
    testWidgets('a press steps by step and clamps at the bound', (tester) async {
      final calls = <double>[];
      await _pump(tester, _stepper(calls: calls, initial: 9));
      expect(find.text('9'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(calls, [10]);
      expect(find.text('10'), findsOneWidget);

      // Past the bound the cell is inert: a second press commits nothing.
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(calls, [10]);
    });

    testWidgets('the cell at a bound greys while its neighbour stays live', (tester) async {
      final calls = <double>[];
      await _pump(tester, _stepper(calls: calls, initial: 0));
      final theme = _theme(tester);
      expect(tester.widget<Icon>(find.byIcon(Icons.remove)).color, theme.colors.textQuaternary);
      expect(tester.widget<Icon>(find.byIcon(Icons.add)).color, theme.colors.text);

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
    });

    testWidgets('decimals render and step the value', (tester) async {
      final calls = <double>[];
      await _pump(tester, _stepper(calls: calls, initial: 1, step: 2.5, decimals: 1));
      expect(find.text('1.0'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(calls, [3.5]);
      expect(find.text('3.5'), findsOneWidget);
    });

    testWidgets('an inert stepper is const-constructible, greyed and pointer-deaf', (tester) async {
      await _pump(tester, const PureNumberStepper(value: 3, onChanged: null));
      expect(find.byWidgetPredicate((w) => w is IgnorePointer && w.ignoring), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      final value = _valueNode(tester);
      expect(value.properties.onIncrease, isNull);
      expect(value.properties.onDecrease, isNull);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a disabled stepper answers no one', (tester) async {
      final calls = <double>[];
      await _pump(tester, _stepper(calls: calls, enabled: false));
      expect(find.byWidgetPredicate((w) => w is IgnorePointer && w.ignoring), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
    });
  });

  group('keyboard', () {
    testWidgets('Up and Down step while the control is focused', (tester) async {
      final calls = <double>[];
      await _pump(tester, _stepper(calls: calls));

      await tester.tap(find.byIcon(Icons.add)); // focus (and one step).
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      expect(calls, [6, 7, 6]);
      expect(find.text('6'), findsOneWidget);
    });

    testWidgets('a key past the bound is left to the shell', (tester) async {
      final calls = <double>[];
      await _pump(tester, _stepper(calls: calls, initial: 10));

      await tester.tap(find.byIcon(Icons.remove)); // focus, back to 9.
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp); // to 10.
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp); // at the max: ignored.
      await tester.pumpAndSettle();

      expect(calls, [9, 10]);
    });

    testWidgets('the focused control draws the ring', (tester) async {
      await _pump(tester, _stepper(calls: <double>[]));
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      final ring = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .firstWhere((w) => w.position == DecorationPosition.foreground);
      final border = (ring.decoration as BoxDecoration).border!;
      expect(border.top.color, _theme(tester).colors.primary);
      expect(border.top.width, 2);
    });
  });

  group('hold to repeat', () {
    testWidgets('a hold keeps stepping on an accelerating gap', (tester) async {
      final calls = <double>[];
      await _pump(tester, _stepper(calls: calls, max: 50));

      final gesture = await tester.startGesture(tester.getCenter(find.byIcon(Icons.add)));
      await tester.pump();
      expect(calls, [6]); // the press's own step lands immediately.

      await tester.pump(_holdStart - const Duration(milliseconds: 1));
      expect(calls.length, 1);
      await tester.pump(const Duration(milliseconds: 2));
      expect(calls.length, 2);

      await tester.pump(_secondGap - const Duration(milliseconds: 2));
      expect(calls.length, 2);
      await tester.pump(const Duration(milliseconds: 2));
      expect(calls.length, 3);

      await tester.pump(_thirdGap - const Duration(milliseconds: 2));
      expect(calls.length, 3);
      await tester.pump(const Duration(milliseconds: 2));
      expect(calls.length, 4);

      // The gap is shrinking: all four steps are done inside a window the
      // flat-repeat contract would still be one step into.
      expect(calls, [6, 7, 8, 9]);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('the repeat stops itself at the bound', (tester) async {
      final calls = <double>[];
      await _pump(tester, _stepper(calls: calls, initial: 9));

      final gesture = await tester.startGesture(tester.getCenter(find.byIcon(Icons.add)));
      await tester.pump();
      expect(calls, [10]);

      await tester.pump(const Duration(seconds: 3));
      expect(calls, [10]); // the tick at the bound neither commits nor re-arms.
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('lifting the finger ends the repeat', (tester) async {
      final calls = <double>[];
      await _pump(tester, _stepper(calls: calls, max: 50));

      final gesture = await tester.startGesture(tester.getCenter(find.byIcon(Icons.add)));
      await tester.pump();
      await tester.pump(_holdStart + const Duration(milliseconds: 2));
      expect(calls.length, 2);

      await gesture.up();
      await tester.pump(const Duration(seconds: 5));
      expect(calls.length, 2);
    });
  });

  group('semantics', () {
    testWidgets('the value node carries increase and decrease actions', (tester) async {
      final calls = <double>[];
      await _pump(tester, _stepper(calls: calls));

      final node = _valueNode(tester);
      expect(node.properties.value, '5');
      expect(node.properties.increasedValue, '6');
      expect(node.properties.decreasedValue, '4');

      node.properties.onIncrease!.call();
      await tester.pumpAndSettle();
      expect(calls, [6]);

      node.properties.onDecrease!.call();
      await tester.pumpAndSettle();
      expect(calls, [6, 5]);
    });

    testWidgets('at the top end the increase action is gone, the decrease stays', (tester) async {
      await _pump(tester, _stepper(calls: <double>[], initial: 10));

      expect(
        tester.widgetList<Semantics>(find.byType(Semantics)).where((w) => w.properties.onIncrease != null),
        isEmpty,
      );
      final node = _valueNode(tester);
      expect(node.properties.value, '10');
      expect(node.properties.decreasedValue, '9');
    });

    testWidgets('each cell reads as a named button', (tester) async {
      await _pump(tester, _stepper(calls: <double>[], initial: 10));

      final increase = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .firstWhere((w) => w.properties.label == 'Increase');
      expect(increase.properties.button, isTrue);
      expect(increase.properties.enabled, isFalse); // at the bound.

      final decrease = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .firstWhere((w) => w.properties.label == 'Decrease');
      expect(decrease.properties.button, isTrue);
      expect(decrease.properties.enabled, isTrue);
    });
  });
}

PureTheme _theme(WidgetTester tester) => PureTheme.of(tester.element(find.byType(PureNumberStepper)));

/// The control's value node: the one `Semantics` that carries the number and
/// the increase/decrease actions.
Semantics _valueNode(WidgetTester tester) =>
    tester.widgetList<Semantics>(find.byType(Semantics)).firstWhere((w) => w.properties.value != null);

BoxDecoration _cellDeco(WidgetTester tester, IconData icon) {
  final container = tester.widget<AnimatedContainer>(
    find.ancestor(of: find.byIcon(icon), matching: find.byType(AnimatedContainer)).first,
  );
  return container.decoration! as BoxDecoration;
}

/// A controlled host: it feeds each commit back as the next value, the way a
/// real caller does, and records the sequence.
Widget _stepper({
  required List<double> calls,
  double initial = 5,
  double min = 0,
  double max = 10,
  double step = 1,
  int decimals = 0,
  bool enabled = true,
}) {
  return _Host(initial: initial, min: min, max: max, step: step, decimals: decimals, enabled: enabled, calls: calls);
}

class _Host extends StatefulWidget {
  const new({
    required this.initial,
    required this.min,
    required this.max,
    required this.step,
    required this.decimals,
    required this.enabled,
    required this.calls,
  });

  final double initial;

  final double min;

  final double max;

  final double step;

  final int decimals;

  final bool enabled;

  final List<double> calls;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late double _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return PureNumberStepper(
      value: _value,
      min: widget.min,
      max: widget.max,
      step: widget.step,
      decimals: widget.decimals,
      enabled: widget.enabled,
      onChanged: (next) {
        widget.calls.add(next);
        setState(() => _value = next);
      },
    );
  }
}

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
