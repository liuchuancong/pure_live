import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The branch key the public widget hangs on its body: the language whose
/// grammar a badge is drawing is addressable in tests and diagnostics.
Key _branch(PureDesignLanguage language) => ValueKey('PureBadge.${language.name}');

/// The one canvas the badge paints. The key is the shape's own, so a badge
/// anchored to a child that paints (an avatar, a thumbnail) still has exactly
/// one match: the bubble.
final Finder _bubble = find.descendant(
  of: find.byType(PureBadge),
  matching: find.byKey(const ValueKey('PureBadge.shape')),
);

/// The mark's whole box — the bubble plus the knockout ring it wears when it is
/// anchored to a child.
Rect _mark(WidgetTester tester, PureDesignLanguage language) => tester.getRect(find.byKey(_branch(language)));

/// The painter class the branch drew this frame — the body family, not the
/// colours inside it.
Type _family(WidgetTester tester) => tester.widget<CustomPaint>(_bubble).painter!.runtimeType;

/// The badge's own semantics node: the framework contributes plain nodes further
/// up the tree, so the match is inside the branch, where ours is the outermost.
Semantics _semantics(WidgetTester tester, PureDesignLanguage language) => tester.widget<Semantics>(
  find.descendant(of: find.byKey(_branch(language)), matching: find.byType(Semantics)).first,
);

/// The height each language's bubble is drawn at — its platform's own size, held
/// whatever the caller's count, colour or brightness does to it.
const Map<PureDesignLanguage, double> _height = {
  PureDesignLanguage.material: 18,
  PureDesignLanguage.cupertino: 20,
  PureDesignLanguage.macos: 18,
  PureDesignLanguage.fluent: 16,
  PureDesignLanguage.yaru: 16,
  PureDesignLanguage.forui: 18,
  PureDesignLanguage.glass: 20,
  PureDesignLanguage.neumorphic: 20,
  PureDesignLanguage.wind: 16,
};

/// The marker dot's diameter each language draws.
const Map<PureDesignLanguage, double> _dot = {
  PureDesignLanguage.material: 6,
  PureDesignLanguage.cupertino: 9,
  PureDesignLanguage.macos: 8,
  PureDesignLanguage.fluent: 8,
  PureDesignLanguage.yaru: 10,
  PureDesignLanguage.forui: 8,
  PureDesignLanguage.glass: 8,
  PureDesignLanguage.neumorphic: 10,
  PureDesignLanguage.wind: 7,
};

/// How far each language lets its badge reach past the corner of its anchor.
const Map<PureDesignLanguage, double> _overlap = {
  PureDesignLanguage.material: 4,
  PureDesignLanguage.cupertino: 3,
  PureDesignLanguage.macos: 3,
  PureDesignLanguage.fluent: 4,
  PureDesignLanguage.yaru: 4,
  PureDesignLanguage.forui: 4,
  PureDesignLanguage.glass: 3,
  PureDesignLanguage.neumorphic: 4,
  PureDesignLanguage.wind: 4,
};

/// The knockout ring each language lays under an anchored badge.
const Map<PureDesignLanguage, double> _halo = {
  PureDesignLanguage.material: 2,
  PureDesignLanguage.cupertino: 2,
  PureDesignLanguage.macos: 2,
  PureDesignLanguage.fluent: 1.5,
  PureDesignLanguage.yaru: 2,
  PureDesignLanguage.forui: 2,
  PureDesignLanguage.glass: 2,
  PureDesignLanguage.neumorphic: 2,
  PureDesignLanguage.wind: 1.5,
};

/// The anchor the badge is put over: a known box at a known corner.
const Widget _anchor = SizedBox(key: ValueKey('anchor'), width: 36, height: 36);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  PureDesignLanguage language = PureDesignLanguage.material,
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    PureConfigProvider(
      config: UiConfig(
        language: language,
        brightness: brightness == Brightness.dark ? UiBrightnessMode.dark : UiBrightnessMode.light,
      ),
      child: MaterialApp(
        home: Scaffold(
          // A badge is a hug-sized inline element: it answers the type it carries
          // and the child it rides, so the harness hands it loose constraints and
          // never a box to fill — a tight slot would stretch the bubble and the
          // corner it claims would be the slot's, not the child's.
          body: Center(child: child),
        ),
      ),
    ),
  );
  // One frame, never a settle: a badge is static, and the app shells below it
  // may run their own animations.
  await tester.pump();
}

void main() {
  group('branches', () {
    testWidgets('every design language draws its own counted bubble', (tester) async {
      for (final entry in _height.entries) {
        final language = entry.key;
        await _pump(tester, const PureBadge(count: 5), language: language);
        expect(tester.takeException(), isNull, reason: '$language failed to build');
        expect(find.byKey(_branch(language)), findsOneWidget, reason: '$language lost its branch');
        expect(_bubble, findsOneWidget, reason: '$language drew more than one shape');
        final painted = tester.getRect(_bubble);
        expect(painted.height, entry.value, reason: '$language lost its own bubble height');
        // One digit rides a circle: the bubble is never narrower than it is tall.
        expect(painted.width, greaterThanOrEqualTo(painted.height), reason: '$language flattened its bubble');
        expect(find.text('5'), findsOneWidget, reason: '$language dropped the count');
      }
    });

    testWidgets('every design language draws its own dot', (tester) async {
      for (final entry in _dot.entries) {
        final language = entry.key;
        await _pump(tester, const PureBadge(dot: true), language: language);
        expect(tester.takeException(), isNull, reason: '$language failed to build a dot');
        expect(find.byKey(_branch(language)), findsOneWidget, reason: '$language lost its branch');
        final painted = tester.getRect(_bubble);
        expect(painted.width, entry.value, reason: '$language drew the wrong dot');
        expect(painted.height, entry.value, reason: '$language drew an ellipse');
        // A dot is the bare marker: it carries no number to read.
        expect(find.byType(Text), findsNothing, reason: '$language put type on its dot');
      }
    });

    testWidgets('the nine grammars come from the three bodies their platforms paint', (tester) async {
      final families = <PureDesignLanguage, Type>{};
      for (final language in PureDesignLanguage.values) {
        await _pump(tester, const PureBadge(count: 12), language: language);
        families[language] = _family(tester);
      }

      // The flat filled bubble: Material 3's pill, iOS's red bubble, the macOS
      // capsule and Yaru's circle are one body with different gloss and cast.
      expect(families[PureDesignLanguage.cupertino], families[PureDesignLanguage.material]);
      expect(families[PureDesignLanguage.macos], families[PureDesignLanguage.material]);
      expect(families[PureDesignLanguage.yaru], families[PureDesignLanguage.material]);
      // The neumorphic chip is the same body too — its colour is the surface,
      // its grammar is the pair of shadows laid under it.
      expect(families[PureDesignLanguage.neumorphic], families[PureDesignLanguage.material]);
      // WinUI's system stroke, shadcn's border and the wind sibling's crisper
      // rim are one outlined body.
      expect(families[PureDesignLanguage.forui], families[PureDesignLanguage.fluent]);
      expect(families[PureDesignLanguage.wind], families[PureDesignLanguage.fluent]);
      expect(
        families[PureDesignLanguage.fluent],
        isNot(families[PureDesignLanguage.material]),
        reason: 'the rimmed badge collapsed into the flat one',
      );
      // And the frosted bubble belongs to no one else.
      expect(
        families[PureDesignLanguage.glass],
        isNot(families[PureDesignLanguage.material]),
        reason: 'glass drew an ordinary flat bubble',
      );
      expect(
        families[PureDesignLanguage.glass],
        isNot(families[PureDesignLanguage.fluent]),
        reason: 'glass is just a rimmed badge',
      );
      expect(families.values.toSet(), hasLength(3), reason: 'the nine grammars are not nine shapes');
    });

    testWidgets('only the frosted language blurs the page behind its bubble', (tester) async {
      final frost = find.descendant(of: find.byType(PureBadge), matching: find.byType(BackdropFilter));
      for (final language in PureDesignLanguage.values) {
        await _pump(tester, const PureBadge(count: 5, child: _anchor), language: language);
        expect(
          frost.evaluate().length,
          language == PureDesignLanguage.glass ? 1 : 0,
          reason: '$language answered the frost contract differently',
        );
      }
    });

    testWidgets('the dark ramp keeps every language its own shape', (tester) async {
      for (final entry in _height.entries) {
        final language = entry.key;
        await _pump(tester, const PureBadge(count: 7), language: language, brightness: Brightness.dark);
        expect(tester.takeException(), isNull, reason: '$language failed in dark');
        expect(find.byKey(_branch(language)), findsOneWidget, reason: '$language lost its branch in dark');
        expect(tester.getRect(_bubble).height, entry.value, reason: '$language re-picked its geometry in dark');

        await _pump(tester, const PureBadge(dot: true), language: language, brightness: Brightness.dark);
        expect(tester.getRect(_bubble).width, _dot[language], reason: '$language resized its dot in dark');
      }
    });

    testWidgets('the colour override travels with every language', (tester) async {
      for (final entry in _height.entries) {
        final language = entry.key;
        await _pump(tester, const PureBadge(count: 5, color: Colors.teal), language: language);
        expect(tester.takeException(), isNull, reason: '$language failed on the override');
        // The override paints the body; the shape it is poured into stays the
        // language's own, so a teal badge is still an InfoBadge in fluent.
        expect(tester.getRect(_bubble).height, entry.value, reason: '$language grew around the override');
        expect(_family(tester), isNotNull);
      }
    });
  });

  group('the count contract', () {
    testWidgets('a count past the ceiling collapses to the cap', (tester) async {
      await _pump(tester, const PureBadge(count: 100));
      expect(find.text('99+'), findsOneWidget);

      await _pump(tester, const PureBadge(count: 1234));
      expect(find.text('99+'), findsOneWidget, reason: 'a longer count stopped being capped');

      await _pump(tester, const PureBadge(count: 99));
      expect(find.text('99'), findsOneWidget);
      expect(find.text('99+'), findsNothing);
    });

    testWidgets('the ceiling is the caller’s, and a zero count is a real number', (tester) async {
      await _pump(tester, const PureBadge(count: 10, max: 9));
      expect(find.text('9+'), findsOneWidget);

      await _pump(tester, const PureBadge(count: 0));
      expect(find.text('0'), findsOneWidget, reason: 'a zero count is an empty inbox, not an absent badge');

      await _pump(tester, const PureBadge(count: 5, max: 5));
      expect(find.text('5'), findsOneWidget, reason: 'the ceiling itself is not past the ceiling');
    });

    testWidgets('the bubble grows with the digits it carries', (tester) async {
      await _pump(tester, const PureBadge(count: 5));
      final short = tester.getRect(_bubble);
      expect(find.text('99+'), findsNothing);

      await _pump(tester, const PureBadge(count: 999));
      final long = tester.getRect(_bubble);
      expect(find.text('99+'), findsOneWidget);
      expect(long.width, greaterThan(short.width), reason: 'a capped count drew the same bubble as a digit');
      expect(long.height, short.height, reason: 'the bubble got taller instead of wider');
    });

    testWidgets('a label is the tag form, and a count outranks it', (tester) async {
      await _pump(tester, const PureBadge(label: 'Beta'));
      expect(find.text('Beta'), findsOneWidget);
      expect(tester.getRect(_bubble).height, _height[PureDesignLanguage.material]);

      await _pump(tester, const PureBadge(count: 3, label: 'Beta'));
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Beta'), findsNothing, reason: 'the label overrode the count it was paired with');

      // A dot is the bare marker even when the call carries both forms of text.
      await _pump(tester, const PureBadge(dot: true, count: 3, label: 'Beta'));
      expect(find.byType(Text), findsNothing);
      expect(tester.getRect(_bubble).width, _dot[PureDesignLanguage.material]);
    });

    testWidgets('a badge with nothing to say draws nothing', (tester) async {
      await _pump(tester, const PureBadge(key: ValueKey('silent')));
      expect(find.byKey(const ValueKey('silent')), findsOneWidget);
      expect(_bubble, findsNothing, reason: 'an empty call still painted a bubble');

      await _pump(tester, const PureBadge(count: 5, enabled: false, child: _anchor));
      expect(find.byKey(const ValueKey('anchor')), findsOneWidget);
      expect(_bubble, findsNothing, reason: 'a disabled badge refused to go away');
    });
  });

  group('anchored to a child', () {
    testWidgets('the badge rides its child’s top-right corner and overlaps it', (tester) async {
      for (final entry in _overlap.entries) {
        final language = entry.key;
        await _pump(tester, const PureBadge(count: 5, child: _anchor), language: language);
        expect(tester.takeException(), isNull, reason: '$language failed over a child');
        expect(_bubble, findsOneWidget, reason: '$language lost its bubble over a child');

        final anchor = tester.getRect(find.byKey(const ValueKey('anchor')));
        final mark = _mark(tester, language);
        expect(mark.top, anchor.top - entry.value, reason: '$language missed the corner vertically');
        expect(mark.right, anchor.right + entry.value, reason: '$language missed the corner horizontally');
        // The badge is laid on the anchor, not stretched by it: the bubble keeps
        // the size its language drew, whatever room the anchor's slot had.
        expect(tester.getRect(_bubble).height, _height[language], reason: '$language resized over a child');
      }
    });

    testWidgets('an anchored badge carries the knockout ring; a tag does not', (tester) async {
      for (final entry in _halo.entries) {
        final language = entry.key;
        await _pump(tester, const PureBadge(count: 5, child: _anchor), language: language);
        final painted = tester.getRect(_bubble);
        final mark = _mark(tester, language);
        expect(mark.width, painted.width + 2 * entry.value, reason: '$language missed its ring width');
        expect(mark.height, painted.height + 2 * entry.value, reason: '$language missed its ring height');

        await _pump(tester, const PureBadge(label: 'Beta'), language: language);
        expect(tester.getRect(_bubble), _mark(tester, language), reason: '$language ringed a standalone tag');
      }
    });

    testWidgets('a badge over a zero-size anchor keeps its own shape and breaks nothing', (tester) async {
      await _pump(tester, const PureBadge(count: 999, child: SizedBox.shrink()));
      expect(tester.takeException(), isNull, reason: 'a tight anchor overflowed the badge');
      expect(_bubble, findsOneWidget);
      final painted = tester.getRect(_bubble);
      expect(painted.height, _height[PureDesignLanguage.material], reason: 'the anchor squeezed the bubble flat');
      // The stack is the anchor's size: the badge paints over its corner, it does
      // not become the slot.
      expect(tester.getSize(find.byType(PureBadge)), Size.zero);
    });
  });

  group('semantics', () {
    testWidgets('a counted badge reads its number, and a label reads its name', (tester) async {
      await _pump(tester, const PureBadge(count: 12));
      expect(_semantics(tester, PureDesignLanguage.material).properties.label, '12');
      // The number is announced once: the text widget inside is excluded.
      expect(find.text('12'), findsOneWidget);

      await _pump(tester, const PureBadge(label: 'Live'));
      expect(_semantics(tester, PureDesignLanguage.material).properties.label, 'Live');
    });

    testWidgets('the cap is what a screen reader hears', (tester) async {
      await _pump(tester, const PureBadge(count: 400));
      expect(_semantics(tester, PureDesignLanguage.material).properties.label, '99+');
    });

    testWidgets('a caller’s name wins, and a bare dot stays silent until named', (tester) async {
      await _pump(tester, const PureBadge(count: 5, semanticLabel: '5 unread messages'));
      expect(_semantics(tester, PureDesignLanguage.material).properties.label, '5 unread messages');

      await _pump(tester, const PureBadge(dot: true));
      expect(
        find.descendant(of: find.byType(PureBadge), matching: find.byType(Semantics)),
        findsNothing,
        reason: 'an unnamed dot was announced as something',
      );

      await _pump(tester, const PureBadge(dot: true, semanticLabel: 'New'));
      expect(_semantics(tester, PureDesignLanguage.material).properties.label, 'New');
    });
  });
}
