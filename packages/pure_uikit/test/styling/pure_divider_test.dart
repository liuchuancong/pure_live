import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The key every grammar puts on its own stroke.
const ValueKey<String> _strokeKey = ValueKey<String>('PureDivider.rule');

Key _branch(PureDesignLanguage language) => ValueKey('PureDivider.${language.name}');

/// The strokes the divider under test painted: one for a bare rule, two for a
/// labelled one, each carrying its language's layers.
final Finder _rule = find.descendant(of: find.byType(PureDivider), matching: find.byKey(_strokeKey));

/// The band box the rule is centred in — the outermost box PureDivider paints.
final Finder _bandBox = find.byType(PureDivider);

final Finder _label = find.byType(Semantics);

/// The slab colours of one stroke, in the order they run across the rule. A
/// hairline grammar is a single entry, the bevelled grammars two or three.
List<Color> _slabs(WidgetTester tester, [Finder? stroke]) {
  final box = tester.widget<DecoratedBox>(stroke ?? _rule);
  final gradient = (box.decoration as BoxDecoration).gradient! as LinearGradient;
  return [for (var i = 0; i < gradient.colors.length; i += 2) gradient.colors[i]];
}

/// The number of layers the active grammar stacks across its stroke.
int _slabCount(WidgetTester tester, [Finder? stroke]) => _slabs(tester, stroke).length;

/// The weight each language rules its separator with — `motion.lineWidth` for
/// the hairline grammars, the bold step and the stacked bevels for the rest.
const Map<PureDesignLanguage, double> _thickness = {
  PureDesignLanguage.material: 1,
  PureDesignLanguage.cupertino: 1,
  PureDesignLanguage.macos: 1,
  PureDesignLanguage.fluent: 1,
  PureDesignLanguage.yaru: 1,
  PureDesignLanguage.forui: 1,
  PureDesignLanguage.glass: 2,
  PureDesignLanguage.neumorphic: 3,
  PureDesignLanguage.wind: 2,
};

/// How many slabs each grammar stacks across that weight.
int _depth(PureDesignLanguage language) => switch (language) {
  PureDesignLanguage.glass => 2,
  PureDesignLanguage.neumorphic => 3,
  _ => 1,
};

/// The grammars that inset a rule by themselves; the other seven run flush.
const Map<PureDesignLanguage, (double, double)> _insets = {
  PureDesignLanguage.cupertino: (16, 0),
  PureDesignLanguage.macos: (20, 20),
};

/// The band each language reserves around a bare rule, and the label it breaks.
/// A grammar that draws the line alone answers with the line's own weight.
double _bandOf(PureDesignLanguage language) => switch (language) {
  PureDesignLanguage.material || PureDesignLanguage.yaru || PureDesignLanguage.forui => 16,
  _ => _thickness[language]!,
};

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  PureDesignLanguage language = PureDesignLanguage.material,
  Brightness brightness = Brightness.light,
  double box = 240,
  double? height,
}) async {
  await tester.pumpWidget(
    PureConfigProvider(
      config: UiConfig(
        language: language,
        brightness: brightness == Brightness.dark ? UiBrightnessMode.dark : UiBrightnessMode.light,
      ),
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            // The slot is loose on both axes, so the band box keeps the size the
            // grammar asked for and only the rule spans the width (or height).
            child: height == null
                ? SizedBox(
                    width: box,
                    child: Center(child: child),
                  )
                : SizedBox(
                    width: box,
                    height: height,
                    child: Center(child: child),
                  ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// The rule's length along its own axis.
double _length(WidgetTester tester, {bool vertical = false, Finder? stroke}) {
  final rect = tester.getRect(stroke ?? _rule);
  return vertical ? rect.height : rect.width;
}

/// The rule's weight across its own axis.
double _weight(WidgetTester tester, {bool vertical = false, Finder? stroke}) {
  final rect = tester.getRect(stroke ?? _rule);
  return vertical ? rect.width : rect.height;
}

void main() {
  group('branches', () {
    testWidgets('every design language rules its own way', (tester) async {
      for (final entry in _thickness.entries) {
        await _pump(tester, const PureDivider(), language: entry.key);
        expect(tester.takeException(), isNull, reason: '${entry.key} failed to build');
        expect(find.byKey(_branch(entry.key)), findsOneWidget, reason: '${entry.key} lost its branch');
        expect(_rule, findsOneWidget, reason: '${entry.key} drew more than one bare rule');
        expect(_weight(tester), entry.value, reason: '${entry.key} lost its own rule weight');
        expect(_slabCount(tester), _depth(entry.key), reason: '${entry.key} lost its layers');
        final inset = _insets[entry.key];
        expect(
          _length(tester),
          240 - (inset == null ? 0 : inset.$1 + inset.$2),
          reason: '${entry.key} did not span the width it was given',
        );
      }
    });

    testWidgets('the nine grammars are one, two and three slabs deep', (tester) async {
      final depths = <PureDesignLanguage, int>{};
      for (final language in PureDesignLanguage.values) {
        await _pump(tester, const PureDivider(), language: language);
        depths[language] = _slabCount(tester);
      }
      // The seven flat languages are a single tone across the stroke.
      for (final language in [
        PureDesignLanguage.material,
        PureDesignLanguage.cupertino,
        PureDesignLanguage.macos,
        PureDesignLanguage.fluent,
        PureDesignLanguage.yaru,
        PureDesignLanguage.forui,
        PureDesignLanguage.wind,
      ]) {
        expect(depths[language], 1, reason: '$language bevelled a flat rule');
      }
      // Glass paints its lit edge under the seam; neumorphic carves a wall, a
      // floor and a lip. Neither is reachable by darkening the other's line.
      expect(depths[PureDesignLanguage.glass], 2);
      expect(depths[PureDesignLanguage.neumorphic], 3);
      // The two-line grammars are told apart by weight as well as by slabs: wind
      // is one bold hairline, glass a hairline seam plus its highlight.
      expect(_thickness[PureDesignLanguage.wind], _thickness[PureDesignLanguage.glass]);
      expect(depths.values.toSet(), {1, 2, 3}, reason: 'the nine grammars collapsed into fewer shapes');
    });

    testWidgets('a horizontal rule spans whatever width it is handed', (tester) async {
      for (final entry in _thickness.entries) {
        await _pump(tester, const PureDivider(), language: entry.key, box: 320);
        final inset = _insets[entry.key];
        expect(
          _length(tester),
          320 - (inset == null ? 0 : inset.$1 + inset.$2),
          reason: '${entry.key} would not grow to the width it was given',
        );
        expect(_weight(tester), entry.value, reason: '${entry.key} stretched its stroke to match');
      }
    });

    testWidgets('a vertical rule spans the height of its slot', (tester) async {
      for (final entry in _thickness.entries) {
        await _pump(tester, const PureDivider(axis: Axis.vertical), language: entry.key, height: 240);
        expect(tester.takeException(), isNull, reason: '${entry.key} failed to build an upright rule');
        expect(_weight(tester, vertical: true), entry.value, reason: '${entry.key} lost its weight upright');
        expect(_length(tester, vertical: true), 240, reason: '${entry.key} did not fill the height it was given');
      }
    });

    testWidgets('only the inset grammars inset themselves', (tester) async {
      final inset = <PureDesignLanguage>[];
      for (final language in PureDesignLanguage.values) {
        await _pump(tester, const PureDivider(), language: language);
        if (_length(tester) < 240) {
          inset.add(language);
          final pair = _insets[language]!;
          expect(
            tester.getRect(_rule).left - tester.getRect(_bandBox).left,
            pair.$1,
            reason: '$language inset its leading end by the wrong amount',
          );
          expect(
            tester.getRect(_bandBox).right - tester.getRect(_rule).right,
            pair.$2,
            reason: '$language inset its trailing end by the wrong amount',
          );
        }
      }
      expect(inset, hasLength(_insets.length), reason: 'more grammars inset than the design sheet has');
      expect(inset.toSet(), _insets.keys.toSet());
    });

    testWidgets('a call site answers for the insets, zero included', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pump(tester, const PureDivider(indent: 24, endIndent: 24), language: language);
        expect(_length(tester), 192, reason: '$language ignored the insets it was handed');

        await _pump(tester, const PureDivider(indent: 0, endIndent: 0), language: language);
        expect(_length(tester), 240, reason: '$language would not go full-bleed when asked');

        await _pump(
          tester,
          const PureDivider(axis: Axis.vertical, indent: 30, endIndent: 30),
          language: language,
          height: 240,
        );
        expect(_length(tester, vertical: true), 180, reason: '$language did not read an upright rule it was handed');
      }
    });

    testWidgets('each language keeps its own band around a bare rule', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pump(tester, const PureDivider(), language: language);
        expect(tester.getRect(_bandBox).height, _bandOf(language), reason: '$language changed the band it reserves');

        await _pump(tester, const PureDivider(axis: Axis.vertical), language: language, height: 240);
        expect(tester.getRect(_bandBox).width, _bandOf(language), reason: '$language reserved no band upright');
      }
    });

    testWidgets('the extent is the band, never the rule', (tester) async {
      for (final entry in _thickness.entries) {
        await _pump(tester, const PureDivider(extent: 32), language: entry.key);
        final band = tester.getRect(_bandBox);
        expect(band.height, 32, reason: '${entry.key} lost the band it was asked for');
        expect(_weight(tester), entry.value, reason: '${entry.key} read extent as a stroke weight');
        expect(
          tester.getRect(_rule).center.dy,
          closeTo(band.center.dy, 0.5),
          reason: '${entry.key} did not centre its rule in the band',
        );

        await _pump(tester, const PureDivider(axis: Axis.vertical, extent: 32), language: entry.key, height: 240);
        final upright = tester.getRect(_bandBox);
        expect(upright.width, 32, reason: '${entry.key} lost its band upright');
        expect(
          tester.getRect(_rule).center.dx,
          closeTo(upright.center.dx, 0.5),
          reason: '${entry.key} ruled it off-centre',
        );
      }
    });
  });

  group('label', () {
    testWidgets('a labelled rule centres its text between two of its own strokes', (tester) async {
      await _pump(tester, const PureDivider(label: 'Followed'));

      expect(find.text('Followed'), findsOneWidget);
      expect(_rule, findsNWidgets(2), reason: 'a labelled rule stayed one uninterrupted line');
      final band = tester.getRect(_bandBox);
      final text = tester.getRect(find.text('Followed'));
      expect(text.center.dx, closeTo(band.center.dx, 1));

      final leading = tester.getRect(_rule.first);
      final trailing = tester.getRect(_rule.last);
      expect(leading.width, greaterThan(0));
      expect(trailing.width, closeTo(leading.width, 1), reason: 'the text was not centred between its segments');
      expect(leading.center.dy, closeTo(text.center.dy, 1));
      expect(leading.right, lessThanOrEqualTo(text.left));
      expect(trailing.left, greaterThanOrEqualTo(text.right));
    });

    testWidgets('a labelled rule keeps its grammar in every language', (tester) async {
      for (final entry in _thickness.entries) {
        await _pump(tester, const PureDivider(label: 'Up next'), language: entry.key);
        expect(tester.takeException(), isNull, reason: '${entry.key} failed on a labelled rule');
        expect(find.text('Up next'), findsOneWidget, reason: '${entry.key} dropped the label');
        expect(_rule, findsNWidgets(2), reason: '${entry.key} did not split its rule');
        expect(_weight(tester, stroke: _rule.first), entry.value, reason: '${entry.key} re-weighted its segments');
        expect(
          _slabCount(tester, _rule.first),
          _depth(entry.key),
          reason: '${entry.key} lost its layers beside the text',
        );
      }
    });

    testWidgets('a label is never cut by the band it sits in', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pump(tester, const PureDivider(label: 'Up next'), language: language);
        final text = tester.getRect(find.text('Up next'));
        expect(
          tester.getRect(_bandBox).height,
          greaterThanOrEqualTo(text.height),
          reason: '$language clipped the words out of its own band',
        );

        await _pump(tester, const PureDivider(extent: 32, label: 'Up next'), language: language);
        expect(tester.getRect(_bandBox).height, 32, reason: '$language dropped an asked-for labelled band');
      }
    });

    testWidgets('an upright labelled rule splits above and below its text', (tester) async {
      await _pump(
        tester,
        const PureDivider(axis: Axis.vertical, label: 'New'),
        language: PureDesignLanguage.glass,
        height: 240,
      );
      expect(_rule, findsNWidgets(2));
      expect(_weight(tester, vertical: true, stroke: _rule.first), _thickness[PureDesignLanguage.glass]);
      expect(tester.getRect(_rule.first).bottom, lessThanOrEqualTo(tester.getRect(find.text('New')).top));
      expect(tester.getRect(_rule.last).top, greaterThanOrEqualTo(tester.getRect(find.text('New')).bottom));
    });
  });

  group('colour and semantics', () {
    testWidgets('the rule answers in its own border tone', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pump(tester, const PureDivider(), language: language);
        expect(_slabs(tester).first.a, greaterThan(0), reason: '$language ruled with a clear line');
      }
    });

    testWidgets('a call-site colour replaces the tone and keeps the bevel', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pump(tester, const PureDivider(color: Colors.teal), language: language);
        final slabs = _slabs(tester);
        expect(slabs.length, _depth(language), reason: '$language flattened its grammar to answer a colour');
        // The named tone becomes the stroke's base layer everywhere but the
        // groove, which pushes it toward its own cast colour so it stays carved.
        expect(
          slabs.first,
          language == PureDesignLanguage.neumorphic ? isNot(Colors.teal) : Colors.teal,
          reason: '$language lost the colour it was handed',
        );
      }
      // The wall answers the override and the lit lip answers the theme, so a
      // named tone tints the groove without erasing it.
      await _pump(tester, const PureDivider(color: Colors.teal), language: PureDesignLanguage.neumorphic);
      final carved = _slabs(tester);
      await _pump(tester, const PureDivider(color: Colors.brown), language: PureDesignLanguage.neumorphic);
      final repainted = _slabs(tester);
      expect(repainted.first, isNot(carved.first), reason: 'the groove ignored the tone it was handed');
      expect(repainted.first, isNot(repainted[1]), reason: 'the wall stopped reading as a wall');
      expect(repainted.last, carved.last, reason: 'the lit lip stopped answering the theme');
    });

    testWidgets('a bare rule says nothing, a named one says its label', (tester) async {
      await _pump(tester, const PureDivider());
      expect(
        find.descendant(of: find.byType(PureDivider), matching: _label),
        findsNothing,
        reason: 'an unnamed separator was announced as something',
      );

      await _pump(tester, const PureDivider(semanticLabel: 'Section break'));
      final named = find.descendant(of: find.byType(PureDivider), matching: _label);
      expect(named, findsOneWidget, reason: 'a named rule stayed out of the a11y tree');
      expect(tester.widget<Semantics>(named.first).properties.label, 'Section break');
    });

    testWidgets('a labelled rule is read once, in the name it prints', (tester) async {
      await _pump(tester, const PureDivider(label: 'Up next'));
      final semantic = tester.widget<Semantics>(find.descendant(of: find.byType(PureDivider), matching: _label).first);
      expect(semantic.properties.label, 'Up next');
      expect(semantic.excludeSemantics, isTrue, reason: 'the printed text would be read a second time');
    });

    testWidgets('the dark ramp keeps the grammar and recolours the bevels', (tester) async {
      for (final entry in _thickness.entries) {
        await _pump(tester, const PureDivider(), language: entry.key);
        final light = _slabs(tester);
        await _pump(tester, const PureDivider(), language: entry.key, brightness: Brightness.dark);
        expect(tester.takeException(), isNull, reason: '${entry.key} failed in dark');
        expect(_weight(tester), entry.value, reason: '${entry.key} re-weighted its rule in dark');
        expect(_slabCount(tester), light.length, reason: '${entry.key} lost a layer in dark');
        expect(tester.getRect(_bandBox).height, _bandOf(entry.key), reason: '${entry.key} re-picked its band in dark');
        if (_depth(entry.key) > 1) {
          expect(light, isNot(_slabs(tester)), reason: '${entry.key} kept its light-mode edge in dark');
        }
      }
    });
  });

  group('compatibility', () {
    testWidgets('the shapes the pages build with all nine rules', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pump(
          tester,
          const SizedBox(
            width: 420,
            child: Column(
              children: [
                PureDivider(),
                PureDivider(indent: 24, endIndent: 24),
                PureDivider(extent: 32),
                PureDivider(indent: 16, endIndent: 16, color: Color(0xFF223344)),
                PureDivider(indent: 14, endIndent: 14, color: Color(0x80223344)),
                PureDivider(label: 'Rule in a band'),
              ],
            ),
          ),
          language: language,
          box: 440,
          height: 400,
        );
        expect(tester.takeException(), isNull, reason: '$language failed on the flat shapes');
        expect(
          find.byKey(_branch(language)),
          findsAtLeastNWidgets(6),
          reason: '$language lost its grammar on one of the shapes',
        );
        expect(find.text('Rule in a band'), findsOneWidget);

        // An upright rule needs a bounded slot, the same one a Row hands it.
        await _pump(
          tester,
          const Row(
            children: [
              Text('Left'),
              PureDivider(axis: Axis.vertical),
              Text('Right'),
            ],
          ),
          language: language,
          height: 120,
        );
        expect(tester.takeException(), isNull, reason: '$language failed on the upright shape');
      }
    });

    testWidgets('a divider keeps the key its call site gave it', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pump(tester, const PureDivider(key: ValueKey('room-rule')), language: language);
        expect(
          find.byKey(const ValueKey('room-rule')),
          findsOneWidget,
          reason: '$language dropped the key it was given',
        );
      }
    });
  });
}
