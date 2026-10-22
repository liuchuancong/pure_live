import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The key on the language's self-painted plate — the layer every visual
/// assertion reads its resolved decoration off.
const Key _plateKey = ValueKey<String>('PureTextField.plate');

/// The key on the disabled dim, so the grey-out can be read without tripping
/// over any opacity the editing engine happens to animate on its own.
const Key _dimKey = ValueKey<String>('PureTextField.dim');

/// The key on the accent rule the fluent plate lays over its bottom edge. The
/// rule is a layer of its own — Flutter paints a rounded box only with a
/// single-colour border, so WinUI's underline cannot be the plate's bottom side
/// — and it is read here rather than off [_plateKey].
const Key _edgeKey = ValueKey<String>('PureTextField.edge');

/// The branch key the public widget hangs on its body: the language whose plate
/// a field is drawing is addressable in tests and diagnostics.
Key _branch(PureDesignLanguage language) => ValueKey('PureTextField.${language.name}');

/// The resolved theme above the field, read from its own element so a test can
/// compare a painted colour against the exact token the plate should use.
PureTheme _theme(WidgetTester tester) => PureTheme.of(tester.element(find.byType(PureTextField)));

/// The plate's resolved decoration — the AnimatedContainer carries the target
/// decoration, so this reads the settled state a branch promises.
BoxDecoration _plate(WidgetTester tester) =>
    (tester.widget<AnimatedContainer>(find.byKey(_plateKey)).decoration!) as BoxDecoration;

/// One side of the plate's border; the box-drawing languages share a [Border].
BorderSide _side(WidgetTester tester, {String side = 'top'}) => switch (side) {
  'top' => _plate(tester).border!.top,
  'bottom' => _plate(tester).border!.bottom,
  _ => throw ArgumentError('unknown side $side'),
};

Finder _semanticsNode() => find.descendant(
  of: find.byType(PureTextField),
  matching: find.byKey(const ValueKey<String>('PureTextField.semantics')),
);

/// The thickness the plate's bottom accent rule settles to; the rule animates
/// its own height, so the layer's constraints carry it.
double _edgeWidth(WidgetTester tester) => tester.widget<AnimatedContainer>(find.byKey(_edgeKey)).constraints!.maxHeight;

/// The ink the plate's bottom accent rule settles to.
Color _edgeColor(WidgetTester tester) =>
    (tester.widget<AnimatedContainer>(find.byKey(_edgeKey)).decoration! as BoxDecoration).color!;

void main() {
  group('branches', () {
    testWidgets('every design language draws its own self-painted plate over the engine', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pump(tester, language: language, placeholder: 'Search');
        expect(tester.takeException(), isNull, reason: '$language failed to build');
        // Its branch, one plate, and the editing engine underneath it.
        expect(find.byKey(_branch(language)), findsOneWidget, reason: '$language lost its branch');
        expect(find.byKey(_plateKey), findsOneWidget, reason: '$language lost its plate');
        expect(find.byType(TextField), findsOneWidget, reason: '$language lost its engine');
      }
    });

    testWidgets('material tightens to a two-width accent outline on focus', (tester) async {
      await _pump(tester, language: PureDesignLanguage.material);
      final theme = _theme(tester);
      expect(_side(tester).color, theme.colors.border);
      final resting = _side(tester).width;

      await _focus(tester);
      expect(_side(tester).color, theme.colors.primary);
      expect(_side(tester).width, greaterThan(resting));
    });

    testWidgets('fluent grows the WinUI bottom accent line, the sides stay grey', (tester) async {
      await _pump(tester, language: PureDesignLanguage.fluent);
      final theme = _theme(tester);
      // At rest the rule is just the bottom hairline the box already wears —
      // same ink, same thickness, no accent yet.
      expect(_edgeWidth(tester), _side(tester).width);
      expect(_edgeColor(tester), _side(tester).color);

      await _focus(tester);
      // The signature: the accent drops to a thick bottom rule the other three
      // sides never take.
      expect(_edgeColor(tester), theme.colors.primary);
      expect(_edgeWidth(tester), greaterThan(_side(tester).width));
      expect(_side(tester).color, isNot(theme.colors.primary));
      // The plate's own outline stays the engaged grey on every side.
      expect(_side(tester, side: 'bottom').color, theme.colors.border);
    });

    testWidgets('glass frosts its plate through a backdrop filter', (tester) async {
      await _pump(tester, language: PureDesignLanguage.glass);
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('neumorphic rests extruded and presses in with an accent hairline on focus', (tester) async {
      await _pump(tester, language: PureDesignLanguage.neumorphic);
      final theme = _theme(tester);
      // Raised: a soft shadow, no outline.
      expect(_plate(tester).boxShadow, isNotNull);
      expect(_plate(tester).border, isNull);

      await _focus(tester);
      // Sunk: the accent hairline arrives, and the shadow inverts — still set.
      expect(_plate(tester).border, isNotNull);
      expect(_side(tester).color, theme.colors.primary);
    });
  });

  group('state', () {
    testWidgets('an error recolours the plate and adds a caption in the error role', (tester) async {
      await _pump(tester, language: PureDesignLanguage.material, errorText: 'Required');
      final theme = _theme(tester);
      expect(_side(tester).color, theme.colors.error);
      expect(find.text('Required'), findsOneWidget);
      final caption = tester.widget<Text>(find.text('Required'));
      expect(caption.style!.color, theme.colors.error);
    });

    testWidgets('a disabled field greys out and stops the engine', (tester) async {
      await _pump(tester, language: PureDesignLanguage.material, enabled: false);
      final theme = _theme(tester);
      expect(tester.widget<AnimatedOpacity>(find.byKey(_dimKey)).opacity, lessThan(1));
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(_plate(tester).color, theme.colors.fillTertiary);
    });

    testWidgets('a read-only field stays live: no dim, engine still enabled', (tester) async {
      await _pump(tester, language: PureDesignLanguage.material, readOnly: true);
      expect(tester.widget<AnimatedOpacity>(find.byKey(_dimKey)).opacity, 1);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    });
  });

  group('editing', () {
    testWidgets('typing round-trips through the controller and fires onChanged', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final seen = <String>[];
      await _pump(tester, language: PureDesignLanguage.cupertino, controller: controller, onChanged: seen.add);

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pumpAndSettle();

      expect(controller.text, 'hello');
      expect(seen, contains('hello'));
    });

    testWidgets('onSubmitted fires on the keyboard action', (tester) async {
      final submitted = <String>[];
      await _pump(
        tester,
        language: PureDesignLanguage.fluent,
        textInputAction: TextInputAction.done,
        onSubmitted: submitted.add,
      );

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.showKeyboard(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'go');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(submitted, ['go']);
    });

    testWidgets('onTap reports the tap without stealing the caret', (tester) async {
      var taps = 0;
      final node = FocusNode();
      addTearDown(node.dispose);
      await _pump(tester, language: PureDesignLanguage.yaru, focusNode: node, onTap: () => taps++);

      await tester.tap(find.byKey(_plateKey));
      await tester.pumpAndSettle();

      expect(taps, 1);
      // The engine still took focus from the same tap — editing behaviour intact.
      expect(node.hasFocus, isTrue);
    });
  });

  group('semantics', () {
    testWidgets('the field exposes textField semantics that reflect enabled', (tester) async {
      await _pump(tester, language: PureDesignLanguage.material, placeholder: 'Name');
      final enabled = tester.widget<Semantics>(_semanticsNode());
      expect(enabled.properties.textField, isTrue);
      expect(enabled.properties.enabled, isTrue);

      await _pump(tester, language: PureDesignLanguage.material, enabled: false);
      expect(tester.widget<Semantics>(_semanticsNode()).properties.enabled, isFalse);
    });

    testWidgets('the placeholder renders as the hint', (tester) async {
      await _pump(tester, language: PureDesignLanguage.forui, placeholder: 'Filter by tag');
      expect(find.text('Filter by tag'), findsOneWidget);
    });
  });

  group('motion', () {
    testWidgets('a theme switch re-skins the plate without a rebuild hiccup', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pump(tester, language: language, placeholder: 'Search');
        expect(tester.takeException(), isNull, reason: '$language hiccuped on re-skin');
      }
      // A language with a focus ring followed by one without both animate clean.
      await _pump(tester, language: PureDesignLanguage.cupertino, placeholder: 'Search');
      await _focus(tester);
      expect(tester.takeException(), isNull);
    });
  });
}

/// Mounts a field under a provider for [language] and settles it.
Future<void> _pump(
  WidgetTester tester, {
  required PureDesignLanguage language,
  String? placeholder,
  String? errorText,
  bool enabled = true,
  bool readOnly = false,
  TextInputAction? textInputAction,
  TextEditingController? controller,
  FocusNode? focusNode,
  VoidCallback? onTap,
  ValueChanged<String>? onChanged,
  ValueChanged<String>? onSubmitted,
}) async {
  await tester.pumpWidget(
    PureConfigProvider(
      config: UiConfig(language: language, brightness: UiBrightnessMode.light),
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: PureTextField(
                controller: controller,
                focusNode: focusNode,
                placeholder: placeholder,
                errorText: errorText,
                enabled: enabled,
                readOnly: readOnly,
                textInputAction: textInputAction,
                onTap: onTap,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Taps the field to take focus and settles the plate's focus transition.
Future<void> _focus(WidgetTester tester) async {
  await tester.tap(find.byKey(_plateKey));
  await tester.pumpAndSettle();
}
