import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The branch key the public widget hangs on its body: the language whose shape
/// a bar is drawing is addressable in tests and diagnostics.
Key _branch(PureDesignLanguage language) => ValueKey('PureProgress.${language.name}');

/// The one canvas the control paints. The app shell carries ink-effect canvases
/// and animated builders of its own, so every search stays inside the control.
final Finder _canvas = find.descendant(of: find.byType(PureProgress), matching: find.byType(CustomPaint));

/// The control's own loop, when the work it measures has no length.
final Finder _loop = find.descendant(of: find.byType(PureProgress), matching: find.byType(AnimatedBuilder));

/// The painter the control drew this frame.
CustomPainter? _painter(WidgetTester tester) => tester.widget<CustomPaint>(_canvas).painter;

/// The painter class a branch drew — the shape family, not the pixels inside it.
Type _family(WidgetTester tester) => _painter(tester)!.runtimeType;

/// The repeating controller an indeterminate shape runs its loop on.
AnimationController _motion(WidgetTester tester) =>
    tester.widget<AnimatedBuilder>(_loop).animation as AnimationController;

/// The control's own semantics node.
Semantics _semantics(WidgetTester tester) =>
    tester.widget<Semantics>(find.descendant(of: find.byType(PureProgress), matching: find.byType(Semantics)).first);

/// The thickness each language's own rail is drawn with.
const Map<PureDesignLanguage, double> _thickness = {
  PureDesignLanguage.material: 4,
  PureDesignLanguage.cupertino: 5,
  PureDesignLanguage.macos: 6,
  PureDesignLanguage.fluent: 3,
  PureDesignLanguage.yaru: 4,
  PureDesignLanguage.forui: 6,
  PureDesignLanguage.glass: 8,
  PureDesignLanguage.neumorphic: 12,
  PureDesignLanguage.wind: 5,
};

/// The diameter each language's own ring is drawn with.
const Map<PureDesignLanguage, double> _diameter = {
  PureDesignLanguage.material: 36,
  PureDesignLanguage.cupertino: 28,
  PureDesignLanguage.macos: 32,
  PureDesignLanguage.fluent: 32,
  PureDesignLanguage.yaru: 32,
  PureDesignLanguage.forui: 24,
  PureDesignLanguage.glass: 32,
  PureDesignLanguage.neumorphic: 36,
  PureDesignLanguage.wind: 26,
};

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  PureDesignLanguage language = PureDesignLanguage.material,
  bool animations = true,
  Brightness brightness = Brightness.light,
  double box = 240,
  double? height,
}) async {
  await tester.pumpWidget(
    PureConfigProvider(
      config: UiConfig(
        language: language,
        animations: animations,
        brightness: brightness == Brightness.dark ? UiBrightnessMode.dark : UiBrightnessMode.light,
      ),
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: height == null
                ? SizedBox(width: box, child: child)
                : SizedBox(width: box, height: height, child: child),
          ),
        ),
      ),
    ),
  );
  // One frame, never a settle: an indeterminate bar repeats forever, and
  // `pumpAndSettle` would only time out waiting for it to stop.
  await tester.pump();
}

void main() {
  group('branches', () {
    testWidgets('every design language draws its own determinate bar', (tester) async {
      for (final entry in _thickness.entries) {
        await _pump(tester, const PureProgress(value: 0.4), language: entry.key);
        expect(tester.takeException(), isNull, reason: '${entry.key} failed to build');
        expect(find.byKey(_branch(entry.key)), findsOneWidget, reason: '${entry.key} lost its branch');
        // A measured length needs no loop, and every shape is one canvas.
        expect(_loop, findsNothing, reason: '${entry.key} ticked for no reason');
        expect(_canvas, findsOneWidget, reason: '${entry.key} drew more than one shape');
        final painted = tester.getRect(_canvas);
        expect(painted.height, entry.value, reason: '${entry.key} lost its own thickness');
        expect(painted.width, 240, reason: '${entry.key} did not fill the track it was given');
      }
    });

    testWidgets('every design language turns its own ring', (tester) async {
      for (final entry in _diameter.entries) {
        await _pump(tester, const PureProgress(value: null, shape: PureProgressShape.circular), language: entry.key);
        expect(tester.takeException(), isNull, reason: '${entry.key} failed to build a ring');
        expect(find.byKey(_branch(entry.key)), findsOneWidget, reason: '${entry.key} lost its branch');
        expect(_loop, findsOneWidget, reason: '${entry.key} lost its loop');
        final painted = tester.getRect(_canvas);
        expect(painted.width, entry.value, reason: '${entry.key} drew the wrong ring');
        expect(painted.height, entry.value, reason: '${entry.key} drew an ellipse');
        expect(_motion(tester).isAnimating, isTrue, reason: '${entry.key} stood still');
      }
    });

    testWidgets('the nine rings come from the three shapes their platforms draw', (tester) async {
      final families = <PureDesignLanguage, Type>{};
      for (final language in PureDesignLanguage.values) {
        await _pump(tester, const PureProgress(value: null, shape: PureProgressShape.circular), language: language);
        families[language] = _family(tester);
      }

      // Material 3, Ubuntu, glass and neumorphic all sweep an arc; the arc is
      // just capped, glowed or cast differently by each.
      expect(families[PureDesignLanguage.yaru], families[PureDesignLanguage.material]);
      expect(families[PureDesignLanguage.glass], families[PureDesignLanguage.material]);
      expect(families[PureDesignLanguage.neumorphic], families[PureDesignLanguage.material]);
      // iOS's twelve fading spokes and the macOS blades are the same mark ring.
      expect(families[PureDesignLanguage.cupertino], families[PureDesignLanguage.macos]);
      // shadcn's eight ticks and the wind sibling's are one family, too.
      expect(families[PureDesignLanguage.forui], families[PureDesignLanguage.wind]);
      // And WinUI's chasing dots belong to no one else.
      expect(families[PureDesignLanguage.fluent], isNot(families[PureDesignLanguage.material]));
      expect(
        {
          families[PureDesignLanguage.material],
          families[PureDesignLanguage.cupertino],
          families[PureDesignLanguage.fluent],
        },
        hasLength(3),
        reason: 'the arc, the mark ring and the dot chase collapsed into one shape',
      );
      expect(families[PureDesignLanguage.cupertino], isNot(families[PureDesignLanguage.material]));
    });

    testWidgets("a call site overrides the language's thickness and diameter", (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pump(tester, const PureProgress(value: 0.4, height: 2), language: language);
        expect(tester.getRect(_canvas).height, 2, reason: '$language flattened the thickness it was handed');

        await _pump(
          tester,
          const PureProgress(value: null, shape: PureProgressShape.circular, size: 20),
          language: language,
        );
        final painted = tester.getRect(_canvas);
        expect(painted.width, 20, reason: '$language ignored the ring size it was handed');
        expect(painted.height, 20, reason: '$language distorted the ring it was handed');
      }
    });

    testWidgets('a thin indeterminate slot is a running bar, not a spinner', (tester) async {
      // The pages that stream — version checks, follow sync — ask for a 2dp
      // marquee in every language, so unknown length answers with the loop the
      // bar shape draws rather than a ring that cannot fit the slot.
      for (final language in [PureDesignLanguage.cupertino, PureDesignLanguage.macos, PureDesignLanguage.fluent]) {
        await _pump(tester, const PureProgress(value: null, height: 2), language: language);
        expect(tester.getRect(_canvas).height, 2, reason: '$language grew the slot');
        expect(_motion(tester).isAnimating, isTrue, reason: '$language stalled its marquee');
      }
    });

    testWidgets('the dark ramp keeps the same shape', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pump(tester, const PureProgress(value: 0.6), language: language, brightness: Brightness.dark);
        expect(tester.takeException(), isNull, reason: '$language failed in dark');
        expect(
          tester.getRect(_canvas).height,
          _thickness[language],
          reason: '$language re-picked its geometry in dark',
        );
      }
    });
  });

  group('motion', () {
    testWidgets('the indeterminate loop advances and comes back round', (tester) async {
      await _pump(tester, const PureProgress(value: null));
      final motion = _motion(tester);
      expect(motion.isAnimating, isTrue);
      // A real pace, not a flicker: one turn is longer than half a second.
      expect(motion.duration!.inMilliseconds, greaterThan(500));

      await tester.pump(const Duration(milliseconds: 120));
      final phase = motion.value;
      expect(phase, greaterThan(0));
      expect(phase, lessThan(1));

      // One cycle later the loop has wrapped to the same phase instead of
      // finishing — an unknown-length bar has no end to reach.
      await tester.pump(motion.duration);
      expect(motion.value, moreOrLessEquals(phase, epsilon: 0.02));
      expect(motion.isAnimating, isTrue);
    });

    testWidgets('the shape is repainted as the loop turns', (tester) async {
      await _pump(tester, const PureProgress(value: null));
      final painter = _painter(tester);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_painter(tester), isNot(same(painter)), reason: 'the frame never reached the canvas');
    });

    testWidgets('a reduced-motion config stills the loop on its resting pose', (tester) async {
      await _pump(tester, const PureProgress(value: null), animations: false);
      final motion = _motion(tester);
      expect(motion.isAnimating, isFalse);
      expect(motion.value, 0);

      final painter = _painter(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(motion.isAnimating, isFalse);
      expect(motion.value, 0);
      // Nothing ticks, so the still bar rebuilds and repaints nothing at all.
      expect(_painter(tester), same(painter));

      // The shape is still there: a stopped bar is a bar, not a gap in the page.
      expect(_canvas, findsOneWidget);
      expect(tester.getRect(_canvas).height, _thickness[PureDesignLanguage.material]);
    });

    testWidgets('a language switch keeps the loop turning', (tester) async {
      await _pump(tester, const PureProgress(value: null));
      final before = _motion(tester).duration!;
      await _pump(tester, const PureProgress(value: null), language: PureDesignLanguage.fluent);

      final after = _motion(tester);
      expect(after.isAnimating, isTrue, reason: 'the re-skin left the new spinner stalled');
      expect(after.duration, isNot(before), reason: 'the new language kept the old pace');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a bar that becomes measurable gives its loop up, and takes it back', (tester) async {
      await _pump(tester, const PureProgress(value: null));
      expect(_loop, findsOneWidget);

      await _pump(tester, const PureProgress(value: 0.5));
      expect(_loop, findsNothing, reason: 'a measured bar still ticks');
      expect(_canvas, findsOneWidget);

      await _pump(tester, const PureProgress(value: null));
      expect(_motion(tester).isAnimating, isTrue, reason: 'the loop never started again');
    });

    testWidgets('a bar that leaves the tree releases its controller', (tester) async {
      await _pump(tester, const PureProgress(value: null, shape: PureProgressShape.circular));
      expect(_loop, findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(_loop, findsNothing);
      expect(tester.takeException(), isNull);
      // An undisposed AnimationController is a live ticker, and the test binding
      // fails this test at teardown for one.
    });
  });

  group('label and semantics', () {
    testWidgets('a labelled bar names the percentage beside the track', (tester) async {
      await _pump(tester, const PureProgress(value: 0.4, showLabel: true));

      expect(find.text('40%'), findsOneWidget);
      // The label takes its own room, so the rail is shorter than the box.
      expect(tester.getRect(_canvas).width, lessThan(240));
    });

    testWidgets('a spinner has no percentage to name', (tester) async {
      await _pump(tester, const PureProgress(value: null, showLabel: true));

      expect(find.textContaining('%'), findsNothing);
      expect(_loop, findsOneWidget);
    });

    testWidgets('a ring wears a wide enough label in its own centre', (tester) async {
      await _pump(
        tester,
        const PureProgress(value: 0.25, showLabel: true, shape: PureProgressShape.circular, size: 44),
      );

      expect(find.text('25%'), findsOneWidget);
      expect(tester.getCenter(find.text('25%')), tester.getRect(_canvas).center);
    });

    testWidgets('a narrow ring puts the percentage beside it instead', (tester) async {
      await _pump(
        tester,
        const PureProgress(value: 0.25, showLabel: true, shape: PureProgressShape.circular, size: 24),
      );

      expect(find.text('25%'), findsOneWidget);
      expect(tester.getCenter(find.text('25%')).dx, greaterThan(tester.getRect(_canvas).right));
    });

    testWidgets('a determinate bar reads as a progress bar with a value', (tester) async {
      await _pump(tester, const PureProgress(value: 0.75, semanticLabel: 'Buffering'));

      final node = _semantics(tester).properties;
      expect(node.role, SemanticsRole.progressBar);
      expect(node.value, '75');
      expect(node.minValue, '0');
      expect(node.maxValue, '100');
      expect(node.label, 'Buffering');
    });

    testWidgets('an indeterminate bar reads as a loading spinner with no value', (tester) async {
      await _pump(tester, const PureProgress(value: null));

      final node = _semantics(tester).properties;
      expect(node.role, SemanticsRole.loadingSpinner);
      expect(node.value, isNull);
      expect(node.minValue, isNull);
      expect(node.maxValue, isNull);
    });

    testWidgets('a fraction past the ends is read as the end it overflowed', (tester) async {
      await _pump(tester, const PureProgress(value: 1.6));
      expect(_semantics(tester).properties.value, '100');

      await _pump(tester, const PureProgress(value: -0.4));
      expect(_semantics(tester).properties.value, '0');
    });

    testWidgets('the colour and label knobs travel with every language', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pump(
          tester,
          const PureProgress(
            value: 0.3,
            showLabel: true,
            barColor: Colors.teal,
            trackColor: Colors.brown,
            semanticLabel: 'Downloading',
          ),
          language: language,
        );
        expect(tester.takeException(), isNull, reason: '$language failed on the overrides');
        expect(find.text('30%'), findsOneWidget, reason: '$language dropped its percentage');
        expect(_semantics(tester).properties.label, 'Downloading');
      }
    });
  });

  group('compatibility', () {
    testWidgets('the marquee still fills its box with a running bar', (tester) async {
      await _pump(tester, const LinearIndeterminate(), height: 20);

      final painted = tester.getRect(_canvas);
      expect(painted.width, 240);
      // The marquee is the one call that expands into whatever box hosts it, so the
      // slot's own height is what the canvas ends up filling.
      expect(painted.height, 20);
      expect(_motion(tester).isAnimating, isTrue);
      expect(_semantics(tester).properties.role, SemanticsRole.loadingSpinner);
    });

    testWidgets('the call shapes the app pages use all build', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pump(tester, const PureProgress(value: null, height: 2), language: language);
        expect(find.byKey(_branch(language)), findsOneWidget, reason: '$language lost the marquee');

        await _pump(tester, const PureProgress(key: ValueKey('web'), value: 0.5, height: 4), language: language);
        expect(find.byKey(const ValueKey('web')), findsOneWidget, reason: "$language lost the caller's key");
        expect(tester.getRect(_canvas).height, 4);
      }
    });
  });
}
