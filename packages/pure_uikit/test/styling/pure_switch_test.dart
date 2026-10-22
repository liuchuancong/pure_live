import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The branch key the public widget hangs on its body: the language whose
/// shape a switch is drawing is addressable in tests and diagnostics.
Key _branch(PureDesignLanguage language) => ValueKey('PureSwitch.${language.name}');

/// The track is the first animated layer of the body (the knob rides over it
/// inside the stack), so `.first` reads its resolved decoration.
Color _trackColor(WidgetTester tester) =>
    ((tester.widget<AnimatedContainer>(find.byType(AnimatedContainer).first).decoration!) as BoxDecoration).color!;

/// The knob's live rect, straight off the layer that slides it.
Rect _knob(WidgetTester tester) => tester.getRect(find.byType(AnimatedPositioned));

/// The disabled fade the switch runs over its own shape: the target opacity
/// the animated layer promises (its rendered child here is a fade, not a
/// bare `Opacity` widget, so the verdict is read off the animation itself).
double _opacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(find.descendant(of: find.byType(PureSwitch), matching: find.byType(AnimatedOpacity)))
    .opacity;

/// The switch's own toggle semantics: the framework's `Focus` and `Icon`
/// widgets contribute plain semantics nodes too, so the match is by the
/// flags the control sets rather than by position.
Semantics _semantics(WidgetTester tester) => tester.widget<Semantics>(
  find
      .descendant(
        of: find.byType(PureSwitch),
        matching: find.byWidgetPredicate(
          (widget) => widget is Semantics && (widget.properties.toggled != null || widget.properties.enabled != null),
        ),
      )
      .first,
);

void main() {
  group('branches', () {
    testWidgets('every design language builds its own switch shape', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pump(tester, PureSwitch(value: true, onChanged: (_) {}), language: language);
        expect(tester.takeException(), isNull, reason: '$language failed to build');
        expect(find.byKey(_branch(language)), findsOneWidget, reason: '$language lost its branch');
        // Every branch slides exactly one knob.
        expect(find.byType(AnimatedPositioned), findsOneWidget, reason: '$language lost its knob');
      }
    });

    testWidgets('material 3 stretches the handle toward the thumb side, tick and all', (tester) async {
      await _pump(tester, const PureSwitch(value: false, onChanged: _discard));
      expect(find.byIcon(Icons.check), findsNothing);
      final off = _knob(tester);

      await _pump(tester, const PureSwitch(value: true, onChanged: _discard));
      final on = _knob(tester);
      expect(find.byIcon(Icons.check), findsOneWidget);
      // The checked handle is the grown one, resting against the rail's end.
      expect(on.height, greaterThan(off.height));
      expect(on.right, moreOrLessEquals(tester.getRect(find.byKey(_branch(PureDesignLanguage.material))).right - 3));

      // The press adds the teardrop's stretch while the finger still holds.
      final finger = await tester.startGesture(tester.getCenter(find.byKey(_branch(PureDesignLanguage.material))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.getRect(find.byType(AnimatedPositioned)).width, greaterThan(on.width));
      await finger.up();
      await tester.pumpAndSettle();
    });

    testWidgets('the iOS branch turns its stadium green and springs the knob', (tester) async {
      await _pump(tester, const PureSwitch(value: false, onChanged: _discard), language: PureDesignLanguage.cupertino);
      final off = _trackColor(tester);

      await _pump(tester, const PureSwitch(value: true, onChanged: _discard), language: PureDesignLanguage.cupertino);
      final track = _trackColor(tester);
      // The green is the success role, not the accent every other rail wears:
      // the same on-state under macOS paints the primary instead.
      expect(track, isNot(off));
      await _pump(tester, const PureSwitch(value: true, onChanged: _discard), language: PureDesignLanguage.macos);
      expect(_trackColor(tester), isNot(track));
    });

    testWidgets('macOS draws no checkmark; the knob rides inside the track', (tester) async {
      await _pump(tester, const PureSwitch(value: true, onChanged: _discard), language: PureDesignLanguage.macos);
      expect(find.byIcon(Icons.check), findsNothing);
      final track = tester.getRect(find.byKey(_branch(PureDesignLanguage.macos)));
      final knob = _knob(tester);
      expect(knob.right, lessThanOrEqualTo(track.right));
      expect(knob.left, greaterThan(track.left));
    });

    testWidgets('glass frosts its track when the device can afford the blur', (tester) async {
      await _pump(tester, const PureSwitch(value: true, onChanged: _discard), language: PureDesignLanguage.glass);
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('interaction', () {
    testWidgets('a tap reports the next value and the knob slides, never jumps', (tester) async {
      final seen = <bool>[];
      await _pump(tester, PureSwitch(value: false, onChanged: seen.add));
      final start = _knob(tester).center.dx;

      await tester.tap(find.byType(PureSwitch));
      await tester.pump();
      expect(seen, [true]);

      // The switch is controlled: the app answers by handing back the flipped
      // value, and the knob travels to its new side rather than teleporting.
      await _host(tester, PureSwitch(value: true, onChanged: seen.add));
      await tester.pump(const Duration(milliseconds: 40));
      final mid = _knob(tester).center.dx;
      expect(mid, greaterThan(start));

      await tester.pumpAndSettle();
      expect(_knob(tester).center.dx, greaterThan(mid));
      expect(seen, [true]);
    });

    testWidgets('a null callback renders disabled and swallows every tap', (tester) async {
      await _pump(tester, const PureSwitch(value: false, onChanged: null));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(PureSwitch));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Material 3 drops the whole control to its 38% disabled alpha.
      expect(_opacity(tester), 0.38);
    });

    testWidgets('enabled false folds into the same disabled verdict', (tester) async {
      final seen = <bool>[];
      await _pump(tester, PureSwitch(value: false, enabled: false, onChanged: seen.add));

      await tester.tap(find.byType(PureSwitch));
      await tester.pumpAndSettle();
      expect(seen, isEmpty);
      expect(_opacity(tester), lessThan(1));
    });

    testWidgets('space toggles while the switch holds focus', (tester) async {
      final seen = <bool>[];
      final node = FocusNode();
      addTearDown(node.dispose);
      await _pump(tester, PureSwitch(value: false, onChanged: seen.add, focusNode: node));

      node.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(seen, [true]);
    });

    testWidgets('enter toggles too, and a disabled switch answers nothing', (tester) async {
      final seen = <bool>[];
      final node = FocusNode();
      addTearDown(node.dispose);
      await _pump(tester, PureSwitch(value: true, onChanged: seen.add, focusNode: node));

      node.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(seen, [false]);

      await _pump(tester, PureSwitch(value: true, enabled: false, onChanged: seen.add, focusNode: node));
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(seen, [false]);
    });
  });

  group('semantics', () {
    testWidgets('the switch reads its toggle state to screen readers', (tester) async {
      await _pump(tester, const PureSwitch(value: true, onChanged: _discard, semanticLabel: 'Wi-Fi'));

      final semantics = _semantics(tester);
      expect(semantics.properties.toggled, true);
      expect(semantics.properties.enabled, true);
      expect(semantics.properties.label, 'Wi-Fi');

      await _pump(tester, const PureSwitch(value: false, onChanged: _discard));
      expect(_semantics(tester).properties.toggled, false);
    });

    testWidgets('a disabled switch reads as disabled', (tester) async {
      await _pump(tester, const PureSwitch(value: false, onChanged: null));

      final semantics = _semantics(tester);
      expect(semantics.properties.enabled, false);
      expect(semantics.properties.toggled, false);
    });
  });
}

void _discard(bool value) {}

/// Mounts the switch under a provider without settling, so a test can watch
/// an animation run instead of skipping past it.
Future<void> _host(
  WidgetTester tester,
  Widget child, {
  PureDesignLanguage language = PureDesignLanguage.material,
}) async {
  await tester.pumpWidget(
    PureConfigProvider(
      config: UiConfig(language: language, brightness: UiBrightnessMode.light),
      child: MaterialApp(
        home: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  PureDesignLanguage language = PureDesignLanguage.material,
}) async {
  await _host(tester, child, language: language);
  await tester.pumpAndSettle();
}
