import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsAction, SemanticsData, SemanticsFlag;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// One painted layer of the track: where it sits and what it is wearing.
typedef _Layer = ({Rect rect, BoxDecoration decoration});

/// The branch key the public widget hangs on its body: the language whose
/// shape a slider is drawing is addressable in tests and diagnostics.
Key _branch(PureDesignLanguage language) => ValueKey('PureSlider.${language.name}');

/// Which branches give their track a bed of their own — M3's outlined keyline,
/// the Aqua well, WinUI's rail line, the frost, the moulded groove — and so lay
/// three layers before the handle. The rest read as two runs of colour alone.
const Set<PureDesignLanguage> _bedded = {
  PureDesignLanguage.material,
  PureDesignLanguage.macos,
  PureDesignLanguage.fluent,
  PureDesignLanguage.glass,
  PureDesignLanguage.neumorphic,
};

bool _hasBed(PureDesignLanguage language) => _bedded.contains(language);

/// The theme the host resolved, captured from inside the provider so an
/// assertion can name the token a shape came from rather than a number copied
/// out of it.
PureTheme? _resolvedTheme;

PureTheme _themeOf() => _resolvedTheme!;

Finder _within(WidgetTester tester, Type type) =>
    find.descendant(of: find.byType(PureSlider), matching: find.byType(type));

Rect _box(WidgetTester tester) => tester.getRect(find.byType(PureSlider));

/// The track's layers in paint order — the bed where the branch draws one, the
/// run ahead of the handle and the run the value has passed over. The handle
/// and the bubble ride over them and are read by their own helpers.
List<_Layer> _track(WidgetTester tester, PureDesignLanguage language) {
  final layers = _within(tester, DecoratedBox);
  final count = _hasBed(language) ? 3 : 2;
  return [
    for (var index = 0; index < count; index++)
      (
        rect: tester.getRect(layers.at(index)),
        decoration: tester.widget<DecoratedBox>(layers.at(index)).decoration! as BoxDecoration,
      ),
  ];
}

/// The run the value has passed over, and the rail ahead of it.
_Layer _passed(WidgetTester tester, PureDesignLanguage language) => _track(tester, language).last;

_Layer _ahead(WidgetTester tester, PureDesignLanguage language) => _track(tester, language)[_hasBed(language) ? 1 : 0];

/// The knob: the last animated layer of the body, since the state layer a
/// language swells behind it is built before it.
BoxDecoration _knob(WidgetTester tester) =>
    (tester.widget<AnimatedContainer>(_within(tester, AnimatedContainer).last).decoration!) as BoxDecoration;

Size _knobSize(WidgetTester tester) => tester.getSize(_within(tester, AnimatedContainer).last);

/// Where the handle sits: the point the rail's runs and the bubble all ride to.
Offset _knobCentre(WidgetTester tester) => tester.getRect(_within(tester, AnimatedContainer).last).center;

/// The bubble a language raises: its size promise, which is zero until a drag
/// asks for it, and the words it carries. A branch with no indicator at all
/// answers null — iOS, WinUI and shadcn leave the naming to the knob.
double? _indicatorScale(WidgetTester tester) {
  final found = _within(tester, AnimatedScale);
  if (found.evaluate().isEmpty) {
    return null;
  }
  return tester.widget<AnimatedScale>(found).scale;
}

bool _raisesIndicator(WidgetTester tester) => _indicatorScale(tester) != null;

/// The hairline a language puts around its knob, read off the border it drew.
BorderSide _knobEdge(WidgetTester tester) => (_knob(tester).border! as Border).top;

/// The bubble's words, or null when no drag is running — or the language draws
/// no bubble at all, which is most of them.
String? _bubble(WidgetTester tester) {
  final found = _within(tester, Text);
  if (found.evaluate().isEmpty) {
    return null;
  }
  return tester.widget<Text>(found.first).data;
}

/// The slider's own semantics node. `Focus` contributes one of its own above
/// this, so the match is by the flag the control sets rather than by position.
/// `testWidgets` enables semantics for the suite by default, so the tree is
/// already annotated when a test reads it.
SemanticsData _semantics(WidgetTester tester) => tester
    .getSemantics(
      find.descendant(
        of: find.byType(PureSlider),
        matching: find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.slider == true),
      ),
    )
    .getSemanticsData();

/// The value the control announces — which is the value the caller handed back,
/// since a slider is controlled.
String _announced(WidgetTester tester) => _semantics(tester).value;

double _fade(WidgetTester tester) => tester.widget<AnimatedOpacity>(_within(tester, AnimatedOpacity)).opacity;

/// The point on the track a fraction of the control's box sits at.
Offset _on(WidgetTester tester, double fraction) {
  final box = _box(tester);
  return Offset(box.left + box.width * fraction, box.center.dy);
}

/// Runs a pointer along the track from one fraction of the box to another,
/// pumping a frame per step so every update reaches the control.
Future<void> _drag(WidgetTester tester, {required double from, required double to, int steps = 3}) async {
  final finger = await _press(tester, from);
  for (var step = 1; step <= steps; step++) {
    await finger.moveTo(_on(tester, from + (to - from) * step / steps));
    await tester.pump();
  }
  await finger.up();
  await tester.pumpAndSettle();
}

/// Puts a pointer on the track and leaves it down.
Future<TestGesture> _press(WidgetTester tester, double fraction) async {
  final finger = await tester.startGesture(_on(tester, fraction));
  await tester.pump();
  return finger;
}

/// The mounted slider and every value it reported.
class _Mounted {
  _Mounted(this.reports);

  final List<double> reports;

  double get last => reports.last;
}

Future<_Mounted> _mount(
  WidgetTester tester, {
  PureDesignLanguage language = PureDesignLanguage.material,
  double value = 40,
  double min = 0,
  double max = 100,
  int? divisions,
  bool enabled = true,
  bool live = true,
  bool react = true,
  String? semanticLabel,
  FocusNode? focusNode,
}) async {
  final seen = <double>[];
  await tester.pumpWidget(
    _ControlledSlider(
      language: language,
      value: value,
      min: min,
      max: max,
      divisions: divisions,
      enabled: enabled,
      live: live,
      react: react,
      semanticLabel: semanticLabel,
      focusNode: focusNode,
      reports: seen,
    ),
  );
  await tester.pumpAndSettle();
  return _Mounted(seen);
}

/// The kit's own host: a provider for the theme, an app shell for the text and
/// directionality, and a box wide enough for a drag to run across. The slider
/// is controlled, so this is where the caller answers its callback — and where
/// a test that only wants the raw reports can decline to.
class _ControlledSlider extends StatefulWidget {
  const _ControlledSlider({
    required this.language,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.enabled,
    required this.live,
    required this.react,
    required this.semanticLabel,
    required this.focusNode,
    required this.reports,
  });

  final PureDesignLanguage language;

  final double value;

  final double min;

  final double max;

  final int? divisions;

  final bool enabled;

  /// Whether the host hands the slider a callback at all; false is the null
  /// `onChanged` that renders a slider inert.
  final bool live;

  /// Whether the host gives the reported value back as its own, which is what
  /// a live caller does. False leaves the slider holding the value it was
  /// given and keeps every report for the test to read.
  final bool react;

  final String? semanticLabel;

  final FocusNode? focusNode;

  final List<double> reports;

  @override
  State<_ControlledSlider> createState() => _ControlledSliderState();
}

class _ControlledSliderState extends State<_ControlledSlider> {
  late double _value = widget.value;

  /// Re-mounting a test reseeds the value the host holds, so a second `_mount`
  /// asks about the value it names rather than the one it replaced.
  @override
  void didUpdateWidget(covariant _ControlledSlider old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _value = widget.value;
    }
  }

  void _report(double next) {
    widget.reports.add(next);
    if (widget.react) {
      setState(() => _value = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PureConfigProvider(
      config: UiConfig(language: widget.language, brightness: UiBrightnessMode.light),
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              // The theme is read from inside the provider's own subtree, so an
              // assertion can name the token a shape was drawn from.
              child: Builder(
                builder: (context) {
                  _resolvedTheme = PureTheme.of(context);
                  return PureSlider(
                    value: _value,
                    min: widget.min,
                    max: widget.max,
                    divisions: widget.divisions,
                    enabled: widget.enabled,
                    semanticLabel: widget.semanticLabel,
                    focusNode: widget.focusNode,
                    onChanged: widget.live ? _report : null,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  group('branches', () {
    testWidgets('every design language builds its own slider shape', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _mount(tester, language: language);
        expect(tester.takeException(), isNull, reason: '$language failed to build');
        expect(find.byKey(_branch(language)), findsOneWidget, reason: '$language lost its branch');
        // Every branch rides its value with a handle over a rail painted in
        // runs of colour, and the fill stops at the handle that carries it.
        expect(_within(tester, AnimatedContainer), findsWidgets, reason: '$language lost its handle');
        expect(_ahead(tester, language).rect.width, greaterThan(0), reason: '$language lost its rail');
        expect(_passed(tester, language).rect.left, lessThanOrEqualTo(_box(tester).right));
        // Only the M3 branch lifts a bubble off the rail; the rest leave the
        // naming to the knob.
        expect(
          _raisesIndicator(tester),
          language == PureDesignLanguage.material,
          reason: '$language lost its label rule',
        );
      }
    });

    testWidgets('material 3: an outlined thin rail, a thicker active stroke and a dot for a handle', (tester) async {
      const language = PureDesignLanguage.material;
      await _mount(tester, language: language);
      final theme = _themeOf();
      final rail = theme.slider.railHeight;
      final layers = _track(tester, language);

      // The bed is the rail M3 puts its outline around, and it is the thin one.
      expect(layers.first.decoration.color, isNull);
      expect(layers.first.decoration.border, isNotNull);
      expect(layers.first.rect.height, rail);
      // The run ahead of the handle keeps that thickness in the rail's grey.
      expect(_ahead(tester, language).decoration.color, theme.colors.fillTertiary);
      expect(_ahead(tester, language).rect.height, rail);
      // The passed part is the accent, and M3's is the thicker stroke.
      expect(_passed(tester, language).decoration.color, theme.slider.trackColor);
      expect(_passed(tester, language).rect.height, greaterThan(rail));
      // The handle rests as the small dot, not the token's own control step.
      expect(_knobSize(tester).width, lessThan(theme.slider.handleSize));
      expect(_knob(tester).color, theme.slider.trackColor);
      // The bubble is the only text on a slider, and it waits for the drag.
      expect(_raisesIndicator(tester), isTrue);
      expect(_indicatorScale(tester), 0);
    });

    testWidgets('material 3: the drag swells the handle and names the value in a bubble', (tester) async {
      const language = PureDesignLanguage.material;
      await _mount(tester, language: language, divisions: 10);
      final rest = _knobSize(tester);
      final finger = await _press(tester, 0.4);
      await finger.moveTo(_on(tester, 0.9));
      await tester.pump();
      await tester.pump(_themeOf().duration);

      expect(_knobSize(tester).width, greaterThan(rest.width));
      // The bubble names the value in the very words the screen reader hears.
      expect(_indicatorScale(tester), 1);
      expect(_bubble(tester), _announced(tester));
      expect(double.parse(_announced(tester)), greaterThan(70));

      await finger.up();
      await tester.pumpAndSettle();
      expect(_indicatorScale(tester), 0);
      expect(_knobSize(tester).width, moreOrLessEquals(rest.width));
      // The active stroke ran with the value and stops at the handle it rides
      // under: M3's track is one continuous bar, not two notches.
      expect(_passed(tester, language).rect.right, closeTo(_knobCentre(tester).dx, 2));
      expect(_ahead(tester, language).rect.right, closeTo(_box(tester).right, 30));
    });

    testWidgets('iOS: two notches around a white knob, the filled part the darker one, and no label', (tester) async {
      const language = PureDesignLanguage.cupertino;
      await _mount(tester, language: language);
      final theme = _themeOf();
      final layers = _track(tester, language);

      // iOS gives its track no bed: the two runs are the whole rail.
      expect(layers.length, 2);
      expect(_ahead(tester, language).decoration.color, theme.colors.fillSecondary);
      expect(_passed(tester, language).decoration.color, theme.colors.fill);
      expect(_knob(tester).color, Colors.white);
      expect(_knob(tester).shape, BoxShape.circle);
      // The run ahead of the handle starts past it: the notches the sheet draws.
      expect(_ahead(tester, language).rect.left, greaterThan(_passed(tester, language).rect.right));

      await _drag(tester, from: 0.4, to: 0.9);
      // iOS puts no label on its slider, however the track is dragged.
      expect(_raisesIndicator(tester), isFalse);
      expect(_announced(tester), isNot('40'));
    });

    testWidgets('macOS: the Aqua pull, a rounded-square knob and one mark per division', (tester) async {
      const language = PureDesignLanguage.macos;
      await _mount(tester, language: language, divisions: 4);
      final theme = _themeOf();

      // The knob is the language's own square, and the groove is the bed with
      // its hairline around it.
      expect(_knob(tester).shape, BoxShape.rectangle);
      expect(_track(tester, language).first.decoration.border, isNotNull);
      expect(_passed(tester, language).decoration.color, theme.slider.trackColor);
      expect(_within(tester, CustomPaint), findsOneWidget);

      // A continuous track has no marks to draw.
      await _mount(tester, language: language);
      expect(_within(tester, CustomPaint), findsNothing);
      expect(_knob(tester).shape, BoxShape.rectangle);

      // The marks promise notches, and the drag lands on one: four divisions of
      // a 0..100 range is a quarter of it per step.
      final stepped = await _mount(tester, language: language, divisions: 4, value: 0, react: false);
      await _drag(tester, from: 0.2, to: 0.3);
      expect(stepped.reports, isNotEmpty);
      for (final value in stepped.reports) {
        expect(value % 25, moreOrLessEquals(0, epsilon: 1e-9));
      }
    });

    testWidgets('fluent: one thickness of track and a large bordered knob that swells on hover', (tester) async {
      const language = PureDesignLanguage.fluent;
      await _mount(tester, language: language);
      final theme = _themeOf();
      final rest = _knobSize(tester);

      // WinUI's accent run is level with its rail, and its knob carries a
      // border the other languages' knobs do not swell with.
      expect(_ahead(tester, language).rect.height, _passed(tester, language).rect.height);
      expect(_knobEdge(tester).width, greaterThan(0));
      expect(rest.width, greaterThan(theme.slider.handleSize));

      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await pointer.addPointer(location: _on(tester, 0.5));
      addTearDown(pointer.removePointer);
      await tester.pumpAndSettle();
      expect(_knobSize(tester).width, greaterThan(rest.width));

      await pointer.removePointer();
      await tester.pumpAndSettle();
      expect(_knobSize(tester).width, moreOrLessEquals(rest.width));
    });

    testWidgets('yaru: the thin dark track, the accent run and a flat round knob', (tester) async {
      const language = PureDesignLanguage.yaru;
      await _mount(tester, language: language);
      final theme = _themeOf();

      // Ubuntu's rail is the dark fill itself, with no bed under it.
      expect(_ahead(tester, language).decoration.color, theme.colors.fill);
      expect(_passed(tester, language).decoration.color, theme.slider.trackColor);
      expect(_ahead(tester, language).rect.height, theme.slider.railHeight);
      expect(_knob(tester).shape, BoxShape.circle);
      expect(_knob(tester).border, isNotNull);
    });

    testWidgets('shadcn borders its knob with the accent, and wind draws the same track', (tester) async {
      const language = PureDesignLanguage.forui;
      await _mount(tester, language: language);
      final theme = _themeOf();
      expect(_knobEdge(tester).color, theme.slider.handleBorderColor);
      expect(_knobEdge(tester).color, theme.colors.primary);
      expect(_knob(tester).shape, BoxShape.circle);
      expect(_ahead(tester, language).decoration.color, theme.colors.borderSecondary);
      final knob = _knobSize(tester);
      final rail = _ahead(tester, language).rect;

      // The family tie the tab bar's wind branch states, kept here as well:
      // one grammar, one shape, whatever language names it.
      await _mount(tester, language: PureDesignLanguage.wind);
      expect(_knobSize(tester), knob);
      expect(_ahead(tester, PureDesignLanguage.wind).rect, rail);
      expect(_knobEdge(tester).color, _themeOf().colors.primary);
    });

    testWidgets('glass frosts its rail; neumorphic presses its knob into the groove', (tester) async {
      await _mount(tester, language: PureDesignLanguage.glass);
      expect(_within(tester, BackdropFilter), findsOneWidget);
      // The frost is the bed, and it is the layer with the light hairline.
      expect(_track(tester, PureDesignLanguage.glass).first.decoration.border, isNotNull);

      const language = PureDesignLanguage.neumorphic;
      await _mount(tester, language: language);
      // The groove is the raised track's shadow pair turned inside out, so the
      // bed carries two and the knob carries its own light.
      final bed = _track(tester, language).first.decoration;
      expect(bed.boxShadow!.length, 2);
      final raised = _knob(tester).boxShadow!.first.offset;

      // The press runs a drag, which is what presses the knob into the mould.
      final finger = await _press(tester, 0.4);
      await finger.moveTo(_on(tester, 0.55));
      await tester.pump();
      expect(_knob(tester).boxShadow!.first.offset, isNot(raised));
      await finger.up();
      await tester.pumpAndSettle();
      expect(_knob(tester).boxShadow!.first.offset, raised);
    });
  });

  group('pointer', () {
    testWidgets('a drag along the track reports the values it runs over', (tester) async {
      const language = PureDesignLanguage.material;
      final seen = await _mount(tester, language: language, react: false);
      await _drag(tester, from: 0.4, to: 0.8);

      expect(seen.reports, isNotEmpty);
      expect(seen.last, greaterThan(40));
      expect(seen.last, greaterThan(seen.reports.first));
      expect(_passed(tester, language).rect.right, greaterThan(_box(tester).left + 100));
    });

    testWidgets('a tap puts the value where the finger landed', (tester) async {
      final seen = await _mount(tester, react: false);
      await tester.tapAt(_on(tester, 0.9));
      await tester.pumpAndSettle();

      expect(seen.reports.length, 1);
      // Near the far end of a 0..100 range: well past the value it was holding.
      expect(seen.last, greaterThan(70));
    });

    testWidgets('the whole track answers, not only the handle', (tester) async {
      final seen = await _mount(tester, value: 10, react: false);
      // The empty far end of the rail, with no handle anywhere near it.
      final finger = await _press(tester, 0.85);
      await finger.moveTo(_on(tester, 0.6));
      await tester.pump();
      await finger.up();
      await tester.pumpAndSettle();

      expect(seen.reports, isNotEmpty);
      expect(seen.reports.first, greaterThan(50));
    });

    testWidgets('a caller that refuses the value keeps the handle where it was', (tester) async {
      const language = PureDesignLanguage.material;
      final seen = await _mount(tester, language: language, react: false);
      final before = _passed(tester, language).rect.width;
      await _drag(tester, from: 0.4, to: 0.9);

      // The slider reported, the caller declined to hand anything back, and the
      // handle stayed on the value it was given.
      expect(seen.reports, isNotEmpty);
      expect(_passed(tester, language).rect.width, moreOrLessEquals(before));
    });
  });

  group('keyboard', () {
    testWidgets('left and right move one step, up and down answer the same way', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await _mount(tester, value: 50, divisions: 10, focusNode: node);
      node.requestFocus();
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(_announced(tester), '60');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(_announced(tester), '50');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(_announced(tester), '40');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(_announced(tester), '50');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(_announced(tester), '40');
    });

    testWidgets('home and end run to the bounds', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await _mount(tester, divisions: 10, focusNode: node);
      node.requestFocus();
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(_announced(tester), '100');

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(_announced(tester), '0');
    });

    testWidgets('a continuous track still moves by something', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await _mount(tester, value: 50, focusNode: node);
      node.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      // A twentieth of the 0..100 range, the step the kit promises a track with
      // no notches of its own.
      expect(_announced(tester), '55');
    });

    testWidgets('the focus ring circles the handle only while it holds focus', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await _mount(tester, focusNode: node);
      expect(_knob(tester).boxShadow!.every((shadow) => shadow.spreadRadius == 0), isTrue);

      node.requestFocus();
      await tester.pumpAndSettle();
      expect(_knob(tester).boxShadow!.any((shadow) => shadow.spreadRadius > 0), isTrue);

      node.unfocus();
      await tester.pumpAndSettle();
      expect(_knob(tester).boxShadow!.every((shadow) => shadow.spreadRadius == 0), isTrue);
    });
  });

  group('disabled', () {
    testWidgets('a disabled slider fades to its language and swallows pointer and keyboard', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      final seen = await _mount(tester, enabled: false, focusNode: node);
      // Material 3 answers with its spec's 38 percent.
      expect(_fade(tester), 0.38);

      await tester.tapAt(_on(tester, 0.9));
      await _drag(tester, from: 0.3, to: 0.7);
      node.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();

      expect(seen.reports, isEmpty);
      expect(_announced(tester), '40');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a null callback folds into the same inert verdict', (tester) async {
      final seen = await _mount(tester, live: false);
      expect(_fade(tester), lessThan(1));

      await _drag(tester, from: 0.4, to: 0.8);
      expect(seen.reports, isEmpty);
      expect(_semantics(tester).hasAction(SemanticsAction.increase), isFalse);
    });

    testWidgets('the other languages fade on their own disabled alpha', (tester) async {
      await _mount(tester, language: PureDesignLanguage.cupertino, enabled: false);
      expect(_fade(tester), _themeOf().slider.disabledOpacity);
      await _mount(tester, language: PureDesignLanguage.fluent, enabled: false);
      expect(_fade(tester), _themeOf().slider.disabledOpacity);
      expect(_fade(tester), isNot(0.38));
    });
  });

  group('semantics', () {
    testWidgets('a screen reader hears the slider, its value and the two actions', (tester) async {
      await _mount(tester, value: 40, divisions: 10, semanticLabel: 'Volume');
      final data = _semantics(tester);

      expect(data.hasFlag(SemanticsFlag.isSlider), isTrue);
      expect(data.value, '40');
      expect(data.increasedValue, '50');
      expect(data.decreasedValue, '30');
      expect(data.label, 'Volume');
      expect(data.hasAction(SemanticsAction.increase), isTrue);
      expect(data.hasAction(SemanticsAction.decrease), isTrue);
    });

    testWidgets('the announced value follows a controlled caller', (tester) async {
      await _mount(tester, value: 20, divisions: 10);
      expect(_announced(tester), '20');

      final finger = await _press(tester, 0.7);
      await finger.moveTo(_on(tester, 0.9));
      await tester.pump();
      await finger.up();
      await tester.pumpAndSettle();
      expect(_announced(tester), isNot('20'));
    });

    testWidgets('a stepped slider names its neighbours as notches', (tester) async {
      await _mount(tester, value: 30, divisions: 10);
      expect(_announced(tester), '30');
      expect(_semantics(tester).increasedValue, '40');
      expect(_semantics(tester).decreasedValue, '20');

      // A value that is not one of the slider's own notches is still read as
      // the caller wrote it, but the next step lands on the grid.
      await _mount(tester, value: 33, divisions: 10);
      expect(_announced(tester), '33');
      expect(_semantics(tester).increasedValue, '40');
    });

    testWidgets('a fraction keeps the digits it has', (tester) async {
      await _mount(tester, value: 0.4, min: 0, max: 1, divisions: 10);
      expect(_announced(tester), '0.4');

      await _mount(tester, value: 0.25, min: 0, max: 1, divisions: 20);
      expect(_announced(tester), '0.25');
    });
  });
}
