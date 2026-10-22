import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_uikit/pure_uikit.dart';

void main() {
  group('branches', () {
    testWidgets('every design language builds its box', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pump(tester, language: language, value: true, onChanged: (_) {}, label: 'Tick');
        expect(tester.takeException(), isNull, reason: '$language failed to build');
        // One face, one label — the halo only exists while the pointer is on
        // the box, and the glass blur never swallows the face.
        expect(find.byType(AnimatedContainer), findsOneWidget, reason: '$language lost its face');
        expect(find.text('Tick'), findsOneWidget, reason: '$language lost its label');
      }
    });

    testWidgets('a label-less box still draws one face', (tester) async {
      await _pump(tester, language: PureDesignLanguage.neumorphic, value: false, onChanged: (_) {});
      expect(find.byType(AnimatedContainer), findsOneWidget);
      expect(find.descendant(of: find.byType(PureCheckbox), matching: find.byType(Row)), findsNothing);
    });
  });

  group('interaction', () {
    testWidgets('a tap reports the next value, on the box and on the label', (tester) async {
      final values = <bool>[];
      await _pump(
        tester,
        language: PureDesignLanguage.material,
        value: false,
        onChanged: values.add,
        label: 'Remember me',
      );

      await tester.tap(find.byType(AnimatedContainer));
      await _pump(
        tester,
        language: PureDesignLanguage.material,
        value: true,
        onChanged: values.add,
        label: 'Remember me',
      );
      await tester.tap(find.text('Remember me'));

      expect(values, [true, false]);
    });

    testWidgets('a null callback or enabled: false answers nothing', (tester) async {
      await _pump(tester, language: PureDesignLanguage.material, value: false, onChanged: null);
      await tester.tap(find.byType(AnimatedContainer));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      var tapped = false;
      await _pump(
        tester,
        language: PureDesignLanguage.material,
        value: false,
        onChanged: (_) => tapped = true,
        enabled: false,
      );
      await tester.tap(find.byType(AnimatedContainer));
      await tester.pumpAndSettle();
      expect(tapped, isFalse);
    });

    testWidgets('a disabled box dims to its branch alpha and greys out', (tester) async {
      await _pump(tester, language: PureDesignLanguage.material, value: false, onChanged: null, label: 'Off');
      // M3's disabled ink is 38%, the spec's number. The face's enclosing
      // opacity is the wrapper around the whole box and label.
      expect(_rowOpacity(tester), moreOrLessEquals(0.38, epsilon: 0.001));

      await _pump(tester, language: PureDesignLanguage.fluent, value: false, onChanged: null, label: 'Off');
      expect(_rowOpacity(tester), lessThan(0.9));
    });

    testWidgets('space toggles while the box holds focus', (tester) async {
      final values = <bool>[];
      await _pump(tester, language: PureDesignLanguage.material, value: false, onChanged: values.add, autofocus: true);

      // The kit's focus ring is on the face once the autofocus lands.
      expect(tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).foregroundDecoration, isNotNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(values, [true, true]);
    });

    testWidgets('space answers nothing on a disabled box', (tester) async {
      var tapped = false;
      await _pump(
        tester,
        language: PureDesignLanguage.material,
        value: false,
        onChanged: (_) => tapped = true,
        enabled: false,
        autofocus: true,
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(tapped, isFalse);
    });
  });

  group('semantics', () {
    testWidgets('a checked box reads as checked, enabled and named', (tester) async {
      await _pump(tester, language: PureDesignLanguage.material, value: true, onChanged: (_) {}, label: 'Subscribe');

      final node = tester.widget<Semantics>(_checkboxSemantics());
      expect(node.properties.checked, isTrue);
      expect(node.properties.enabled, isTrue);
      expect(node.properties.label, 'Subscribe');
    });

    testWidgets('an unchecked disabled box reads as unchecked and disabled', (tester) async {
      await _pump(tester, language: PureDesignLanguage.cupertino, value: false, onChanged: null);

      final node = tester.widget<Semantics>(_checkboxSemantics());
      expect(node.properties.checked, isFalse);
      expect(node.properties.enabled, isFalse);
    });
  });

  group('motion', () {
    testWidgets('the tick scales and fades in on a toggle and pumps clean', (tester) async {
      await _pump(tester, language: PureDesignLanguage.material, value: false, onChanged: (_) {});

      await _pump(tester, language: PureDesignLanguage.material, value: true, onChanged: (_) {});
      await tester.pump(const Duration(milliseconds: 50));
      // Mid-flight: the scale animation runs; the box does not jump.
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await _pump(tester, language: PureDesignLanguage.material, value: false, onChanged: (_) {});
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a theme switch re-skins without a rebuild hiccup', (tester) async {
      await _pump(tester, language: PureDesignLanguage.material, value: true, onChanged: (_) {}, label: 'Tick');
      await _pump(tester, language: PureDesignLanguage.glass, value: true, onChanged: (_) {}, label: 'Tick');
      await _pump(tester, language: PureDesignLanguage.cupertino, value: true, onChanged: (_) {}, label: 'Tick');
      expect(tester.takeException(), isNull);
      expect(find.text('Tick'), findsOneWidget);
    });
  });
}

/// Pumps one box on the provider for [language] and settles it. The three
/// states a case reads — language, value and callback — are required so no
/// expectation hides behind a default.
Future<void> _pump(
  WidgetTester tester, {
  required PureDesignLanguage language,
  required bool value,
  required ValueChanged<bool>? onChanged,
  String? label,
  bool enabled = true,
  bool autofocus = false,
}) async {
  await tester.pumpWidget(
    PureConfigProvider(
      config: UiConfig(language: language),
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: PureCheckbox(
              value: value,
              onChanged: onChanged,
              label: label,
              enabled: enabled,
              autofocus: autofocus,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The box's own semantics node — the one carrying the checkbox traits, since
/// the gesture handler wraps the child in a trait node of its own.
Finder _checkboxSemantics() => find.descendant(
  of: find.byType(PureCheckbox),
  matching: find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.checked != null),
);

/// The settled opacity of the wrapper around the box and its label — the
/// enclosing `AnimatedOpacity` of the face, i.e. the disabled dim (the tick's
/// own opacity sits inside the face, not above it).
double _rowOpacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(
      find.ancestor(of: find.byType(AnimatedContainer), matching: find.byType(AnimatedOpacity)).last,
    )
    .opacity;
