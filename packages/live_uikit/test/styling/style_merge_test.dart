import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/live_uikit.dart';

/// `Style` is the toolkit's cascade (§4): a nullable bag where null means
/// *unset*, so layering styles overrides only what a layer actually names.
/// Everything the recipes and inline overrides depend on is decided here, which
/// makes these the cheapest tests in the package to get wrong.
void main() {
  const bg = Color(0xFF112233);
  const fg = Color(0xFF445566);

  group('merge is the CSS cascade', () {
    test('a later style wins over the properties it names', () {
      final merged = const Style(background: bg, foreground: fg).merge(const Style(background: fg));
      expect(merged.background, fg);
      expect(merged.foreground, fg, reason: 'unnamed in the top layer, so the base falls through');
    });

    test('every property participates in the cascade', () {
      final base = Style(
        padding: const EdgeInsets.all(1),
        margin: const EdgeInsets.all(2),
        minWidth: 3,
        minHeight: 4,
        maxWidth: 5,
        background: bg,
        foreground: fg,
        borderColor: bg,
        borderWidth: 1,
        borderRadius: BorderRadius.circular(2),
        opacity: 0.5,
        blur: 6,
        shadow: const [],
        fontSize: 12,
        fontFamily: 'Base',
        fontWeight: FontWeight.w400,
        letterSpacing: 1,
        lineHeight: 1.5,
        alignment: Alignment.centerLeft,
        textAlign: TextAlign.start,
      );
      final top = Style(
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.all(20),
        minWidth: 30,
        minHeight: 40,
        maxWidth: 50,
        background: fg,
        foreground: bg,
        borderColor: fg,
        borderWidth: 10,
        borderRadius: BorderRadius.circular(20),
        opacity: 1,
        blur: 60,
        shadow: const [BoxShadow(color: bg)],
        fontSize: 120,
        fontFamily: 'Top',
        fontWeight: FontWeight.w900,
        letterSpacing: 10,
        lineHeight: 2.5,
        alignment: Alignment.bottomRight,
        textAlign: TextAlign.end,
      );
      expect(base.merge(top), top);
    });

    test('merging null is a no-op on the same object', () {
      const style = Style(background: bg);
      expect(style.merge(null), same(style));
    });

    test('merging the empty style changes nothing', () {
      const style = Style(background: bg, padding: EdgeInsets.all(4));
      expect(style.merge(Style.empty), style);
    });

    test('a property cannot be unset by merging — null always means unset', () {
      // The recipes rely on this: `_state()` returns a delta that names only the
      // properties an interaction changes, and the variant fill has to survive.
      const base = Style(background: bg);
      expect(base.merge(const Style(foreground: fg)).background, bg);
      expect(base.merge(Style.empty).background, bg);
    });

    test('the hand-written merge list covers every property', () {
      // `merge` is spelled out field by field because Freezed's `copyWith` cannot
      // express "null means unset". This is the guard against that list drifting:
      // a property `merge` forgot to carry is a property this loop reports.
      for (var i = 0; i < _properties.length; i++) {
        final merged = _everyPropertyStyle().merge(_properties[i].$3);
        for (var j = 0; j < _properties.length; j++) {
          final (name, read, _) = _properties[j];
          expect(
            read(merged),
            j == i ? read(_properties[i].$3) : read(_everyPropertyStyle()),
            reason: 'merging ${_properties[i].$1} must ${j == i ? 'take' : 'keep'} $name',
          );
        }
      }
    });
  });

  group('isEmpty answers "does this style name anything?"', () {
    test('the empty style is empty', () {
      expect(Style.empty.isEmpty, isTrue);
    });

    test('any single property makes it non-empty, including the quiet ones', () {
      final named = [
        const Style(padding: EdgeInsets.all(1)),
        const Style(margin: EdgeInsets.all(1)),
        const Style(minWidth: 1),
        const Style(minHeight: 1),
        const Style(maxWidth: 1),
        const Style(background: bg),
        const Style(foreground: fg),
        const Style(borderColor: bg),
        const Style(borderWidth: 1),
        Style(borderRadius: BorderRadius.circular(1)),
        const Style(opacity: 0.5),
        const Style(blur: 1),
        const Style(shadow: [BoxShadow()]),
        const Style(fontSize: 1),
        const Style(fontFamily: 'X'),
        const Style(fontWeight: FontWeight.bold),
        const Style(letterSpacing: 1),
        const Style(lineHeight: 1),
        const Style(alignment: Alignment.center),
        const Style(textAlign: TextAlign.end),
      ];
      for (final style in named) {
        expect(style.isEmpty, isFalse, reason: '$style names a property');
      }
    });
  });

  group('applyText layers a role', () {
    const base = TextStyle(fontFamily: 'Role', fontWeight: FontWeight.w300, fontSize: 10, color: fg);

    test('an unstyled override keeps the role whole', () {
      expect(Style.empty.applyText(base), base);
    });

    test('only the named text properties are painted over', () {
      final result = const Style(foreground: bg, fontSize: 20).applyText(base);
      expect(result.color, bg);
      expect(result.fontSize, 20);
      expect(result.fontFamily, 'Role', reason: 'the style stays silent about the family');
      expect(result.fontWeight, FontWeight.w300);
    });

    test('family, weight, tracking and leading all reach the text style', () {
      final result = const Style(
        fontFamily: 'Other',
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
        lineHeight: 1.8,
      ).applyText(base);
      expect(result.fontFamily, 'Other');
      expect(result.fontWeight, FontWeight.w900);
      expect(result.letterSpacing, 2);
      expect(result.height, 1.8);
    });
  });

  group('toDecoration answers "does this style paint a box?"', () {
    test('a style that paints nothing returns null', () {
      expect(Style.empty.toDecoration(), isNull);
      expect(const Style(fontSize: 12, foreground: fg).toDecoration(), isNull);
    });

    test('a fill, a radius or a shadow is a box', () {
      expect(const Style(background: bg).toDecoration()!.color, bg);
      expect(Style(borderRadius: BorderRadius.circular(4)).toDecoration()!.borderRadius, BorderRadius.circular(4));
      final shadowed = const Style(shadow: [BoxShadow(color: bg, blurRadius: 3)]).toDecoration();
      expect(shadowed!.boxShadow, hasLength(1));
    });

    test('an empty shadow list is not a box', () {
      expect(const Style(shadow: <BoxShadow>[]).toDecoration(), isNull);
    });

    test('a border needs a colour and a positive width', () {
      expect(const Style(borderColor: bg).toDecoration(), isNull, reason: 'no width means nothing to draw');
      expect(const Style(borderColor: bg, borderWidth: 0).toDecoration(), isNull);
      expect(const Style(borderWidth: 2).toDecoration(), isNull, reason: 'a width with no colour is silent');
    });

    test('the width defaults to one when only the colour and a radius are named', () {
      final decoration = Style(borderColor: bg, borderRadius: BorderRadius.circular(2)).toDecoration()!;
      final border = decoration.border! as Border;
      expect(border.top.width, 1);
      expect(border.top.color, bg);
    });

    test('the named width is used verbatim', () {
      final decoration = const Style(borderColor: bg, borderWidth: 3).toDecoration()!;
      expect((decoration.border! as Border).bottom.width, 3);
    });
  });
}

/// Every property `Style` names, as a label, a reader, and a top layer that names
/// only that property. Keeping the three in one list is what lets the cascade test
/// assert "takes this one, keeps the other nineteen" for each of them.
final _properties = <(String, Object? Function(Style), Style)>[
  ('padding', (s) => s.padding, const Style(padding: EdgeInsets.all(99))),
  ('margin', (s) => s.margin, const Style(margin: EdgeInsets.all(98))),
  ('minWidth', (s) => s.minWidth, const Style(minWidth: 97)),
  ('minHeight', (s) => s.minHeight, const Style(minHeight: 96)),
  ('maxWidth', (s) => s.maxWidth, const Style(maxWidth: 95)),
  ('background', (s) => s.background, const Style(background: Color(0xFF999999))),
  ('foreground', (s) => s.foreground, const Style(foreground: Color(0xFF888888))),
  ('borderColor', (s) => s.borderColor, const Style(borderColor: Color(0xFF777777))),
  ('borderWidth', (s) => s.borderWidth, const Style(borderWidth: 9)),
  ('borderRadius', (s) => s.borderRadius, Style(borderRadius: BorderRadius.circular(8))),
  ('opacity', (s) => s.opacity, const Style(opacity: 0.25)),
  ('blur', (s) => s.blur, const Style(blur: 7)),
  ('shadow', (s) => s.shadow, const Style(shadow: [BoxShadow(blurRadius: 6)])),
  ('fontSize', (s) => s.fontSize, const Style(fontSize: 33)),
  ('fontFamily', (s) => s.fontFamily, const Style(fontFamily: 'Delta')),
  ('fontWeight', (s) => s.fontWeight, const Style(fontWeight: FontWeight.w900)),
  ('letterSpacing', (s) => s.letterSpacing, const Style(letterSpacing: 4)),
  ('lineHeight', (s) => s.lineHeight, const Style(lineHeight: 2.25)),
  ('alignment', (s) => s.alignment, const Style(alignment: Alignment.bottomRight)),
  ('textAlign', (s) => s.textAlign, const Style(textAlign: TextAlign.end)),
];

/// A style that names all twenty properties with values none of the deltas above
/// use, so a property `merge` drops shows up as a null rather than a coincidence.
Style _everyPropertyStyle() => Style(
  padding: const EdgeInsets.all(1),
  margin: const EdgeInsets.all(2),
  minWidth: 3,
  minHeight: 4,
  maxWidth: 5,
  background: const Color(0xFF000001),
  foreground: const Color(0xFF000002),
  borderColor: const Color(0xFF000003),
  borderWidth: 1,
  borderRadius: BorderRadius.circular(2),
  opacity: 0.5,
  blur: 6,
  shadow: const [BoxShadow(blurRadius: 1)],
  fontSize: 12,
  fontFamily: 'Base',
  fontWeight: FontWeight.w400,
  letterSpacing: 1,
  lineHeight: 1.5,
  alignment: Alignment.centerLeft,
  textAlign: TextAlign.start,
);
