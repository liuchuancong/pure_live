import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The nine-language contract of the most-used control in the app, pinned against
/// the self-painted button. Assertions are made only against this implementation
/// (its branch key, the kit ring, its opacity sink) — never the geometry of the
/// tab bar's known-red suite.
Key _textBranch(PureDesignLanguage language) => ValueKey('PureButton.${language.name}');
Key _iconBranch(PureDesignLanguage language) => ValueKey('PureIconButton.${language.name}');

final Finder _glyph = find.byType(Icon);

/// A widget that sinks a disabled plate: the animated layer everywhere but wind,
/// whose plain `Opacity` the legacy disabled contract pins.
Finder get _sinker => find.byWidgetPredicate(
  (widget) => (widget is AnimatedOpacity && widget.opacity < 1) || (widget is Opacity && widget.opacity < 1),
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  PureDesignLanguage language = PureDesignLanguage.material,
  UiBrightnessMode brightness = UiBrightnessMode.system,
  double box = 240,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    PureConfigProvider(
      config: UiConfig(language: language, brightness: brightness),
      child: MaterialApp(
        // A loose max-width, not a tight SizedBox: a button must be free to hug
        // its content and to sit as a square, which a tight slot would flatten.
        home: Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: box),
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
  // Loading spins forever, so those tests pump a single frame instead of
  // settling (a repeating controller would never let `pumpAndSettle` return).
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  group('branches', () {
    testWidgets('every language builds every variant and keeps its branch', (tester) async {
      for (final language in PureDesignLanguage.values) {
        for (final variant in ButtonVariant.values) {
          await _pump(
            tester,
            PureButton(label: 'Go', variant: variant, onPressed: () {}),
            language: language,
          );
          expect(tester.takeException(), isNull, reason: '${language.name}/${variant.name} failed to build');
          expect(find.byKey(_textBranch(language)), findsOneWidget, reason: '${language.name} lost its branch');
        }
      }
    });

    testWidgets('every language builds every size tier', (tester) async {
      for (final language in PureDesignLanguage.values) {
        for (final size in ControlSize.values) {
          await _pump(
            tester,
            PureButton(label: 'Go', size: size, onPressed: () {}),
            language: language,
          );
          expect(tester.takeException(), isNull, reason: '${language.name}/${size.name} failed to build');
          // Each tier keeps its own height; a flattened ladder would collapse them.
          final height = tester.getSize(find.byKey(_textBranch(language))).height;
          expect(height, greaterThan(0));
        }
      }
    });

    testWidgets('the dark surface builds in every language', (tester) async {
      for (final language in PureDesignLanguage.values) {
        for (final variant in ButtonVariant.values) {
          await _pump(
            tester,
            PureButton(label: 'Go', variant: variant, onPressed: () {}),
            language: language,
            brightness: UiBrightnessMode.dark,
          );
          expect(tester.takeException(), isNull, reason: '${language.name}/${variant.name} failed in dark');
        }
      }
    });
  });

  group('loading', () {
    testWidgets('the kit ring rides beside the label', (tester) async {
      await _pump(tester, PureButton(label: 'Saving', loading: true, onPressed: () {}), settle: false);
      expect(
        find.descendant(of: find.byKey(_textBranch(PureDesignLanguage.material)), matching: find.byType(PureSpinner)),
        findsOneWidget,
        reason: 'loading did not draw the kit ring',
      );
      expect(find.text('Saving'), findsOneWidget);
    });

    testWidgets('a loading button rejects input', (tester) async {
      var fired = 0;
      await _pump(tester, PureButton(label: 'Saving', loading: true, onPressed: () => fired++), settle: false);
      await tester.tap(find.text('Saving'));
      await tester.pump();
      expect(fired, 0, reason: 'a loading button fired anyway');
    });

    testWidgets('the spinner still delegates to the kit progress', (tester) async {
      await _pump(tester, const PureSpinner(size: 20), settle: false);
      expect(
        find.descendant(of: find.byType(PureSpinner), matching: find.byType(PureProgress)),
        findsOneWidget,
        reason: 'the delegation this control relies on was broken',
      );
    });
  });

  group('disabled', () {
    testWidgets('a disabled button sinks the plate', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pump(tester, const PureButton(label: 'No'), language: language);
        expect(_sinker, findsWidgets, reason: '${language.name} did not grey a disabled button');
      }
    });

    testWidgets('a disabled button swallows taps', (tester) async {
      // An icon button with a live callback but `enabled: false` is the real
      // swallow case: it has something to fire, and must not.
      var fired = 0;
      await _pump(
        tester,
        PureIconButton(icon: Icons.close, tooltip: 'Close', enabled: false, onPressed: () => fired++),
      );
      await tester.tap(_glyph.first);
      await tester.pumpAndSettle();
      expect(fired, 0);
    });
  });

  group('input', () {
    testWidgets('a tap fires onPressed', (tester) async {
      var fired = 0;
      await _pump(tester, PureButton(label: 'Go', onPressed: () => fired++));
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();
      expect(fired, 1);
    });

    testWidgets('a tap on an icon button fires', (tester) async {
      var fired = 0;
      await _pump(tester, PureIconButton(icon: Icons.close, tooltip: 'Close', onPressed: () => fired++));
      await tester.tap(_glyph.first);
      await tester.pumpAndSettle();
      expect(fired, 1);
    });
  });

  group('layout', () {
    testWidgets('expand fills the width it is given', (tester) async {
      await _pump(tester, PureButton(label: 'Wide', expand: true, onPressed: () {}));
      final size = tester.getSize(find.byKey(_textBranch(PureDesignLanguage.material)));
      expect(size.width, 240, reason: 'expand did not fill the bounded width');
    });

    testWidgets('a plain button hugs its content', (tester) async {
      await _pump(tester, PureButton(label: 'Wide', onPressed: () {}));
      final size = tester.getSize(find.byKey(_textBranch(PureDesignLanguage.material)));
      expect(size.width, lessThan(240));
    });

    testWidgets('an icon button is a square', (tester) async {
      await _pump(tester, PureIconButton(icon: Icons.close, tooltip: 'Close', onPressed: () {}));
      final size = tester.getSize(find.byKey(_iconBranch(PureDesignLanguage.material)));
      expect(size.width, moreOrLessEquals(size.height), reason: 'the icon button was not square');
      expect(size.width, greaterThan(0));
    });
  });

  group('icon grammar', () {
    testWidgets('a selected icon button builds and keeps its glyph', (tester) async {
      await _pump(tester, PureIconButton(icon: Icons.star, tooltip: 'Favourite', selected: true, onPressed: () {}));
      expect(tester.takeException(), isNull);
      expect(_glyph, findsWidgets);
    });

    testWidgets('an explicit glyph colour reaches the icon', (tester) async {
      await _pump(tester, PureIconButton(icon: Icons.favorite, tooltip: 'Like', color: Colors.red, onPressed: () {}));
      final color = IconTheme.of(tester.element(_glyph.first)).color;
      expect(color, Colors.red, reason: 'the glyph override did not travel to the icon');
    });
  });

  group('accessibility', () {
    testWidgets('the label names the button for a screen reader', (tester) async {
      await _pump(tester, PureButton(label: 'Save', onPressed: () {}));
      final named = find.descendant(
        of: find.byKey(_textBranch(PureDesignLanguage.material)),
        matching: find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == 'Save'),
      );
      expect(named, findsWidgets);
    });

    testWidgets('an icon button is named by its tooltip', (tester) async {
      await _pump(tester, PureIconButton(icon: Icons.close, tooltip: 'Close', onPressed: () {}));
      final named = find.descendant(
        of: find.byKey(_iconBranch(PureDesignLanguage.material)),
        matching: find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == 'Close'),
      );
      expect(named, findsWidgets);
    });

    testWidgets('a tooltip wraps the button', (tester) async {
      await _pump(tester, PureButton(label: 'Save', tooltip: 'Save now', onPressed: () {}));
      final tooltip = tester.widget<Tooltip>(
        find.descendant(of: find.byKey(_textBranch(PureDesignLanguage.material)), matching: find.byType(Tooltip)),
      );
      expect(tooltip.message, 'Save now');
    });
  });

  group('keyboard', () {
    testWidgets('Enter fires the focused button', (tester) async {
      var fired = 0;
      await _pump(tester, PureButton(label: 'Go', autofocus: true, onPressed: () => fired++));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(fired, 1, reason: 'Enter did not activate the button');
    });

    testWidgets('Space fires the focused button', (tester) async {
      var fired = 0;
      await _pump(tester, PureButton(label: 'Go', autofocus: true, onPressed: () => fired++));
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(fired, 1, reason: 'Space did not activate the button');
    });
  });
}
