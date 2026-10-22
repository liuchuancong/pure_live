import 'dart:typed_data' show Uint8List;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The branch key the public widget hangs on its body: the language whose disc a
/// call site is drawing is addressable in tests and diagnostics.
Finder _branch(PureDesignLanguage language) => find.byKey(ValueKey('PureAvatar.${language.name}'));

/// The plate the disc is painted on.
final Finder _plate = find.byKey(const ValueKey('PureAvatar.plate'));

/// The rim painted over the plate's edge.
final Finder _rim = find.byKey(const ValueKey('PureAvatar.rim'));

/// The avatar's own semantics node: the name a screen reader hears.
final Finder _semantics = find.descendant(of: find.byType(PureAvatar), matching: find.byType(Semantics)).first;

/// The one clip every avatar is cut with, whatever shape its language draws.
final Finder _clip = find.descendant(
  of: find.byType(PureAvatar),
  matching: find.byWidgetPredicate((widget) => widget is ClipOval || widget is ClipRRect),
);

BoxDecoration _plateOf(WidgetTester tester) => tester.widget<DecoratedBox>(_plate).decoration as BoxDecoration;

BoxDecoration _rimOf(WidgetTester tester) => tester.widget<DecoratedBox>(_rim).decoration as BoxDecoration;

/// The rim's colour. A ring is drawn with a uniform `Border.all`, so any one of
/// its four sides names the whole outline, and null is a language that wears
/// none.
Color? _ringColor(WidgetTester tester) => (_rimOf(tester).border as Border?)?.top.color;

/// The initials of the name every case in this file passes.
const String _initials = 'AL';

/// An image provider that cannot decode: empty bytes are not an image, so the
/// stream reports the error and the fallback chain answers.
final ImageProvider<Object> _broken = MemoryImage(Uint8List(0));

/// The colour role each language's plate is painted from. The ramped language
/// carries no flat colour at all, so its plate reads null and its gradient is
/// asserted on its own.
Color? _expectedFill(PureTheme theme, PureDesignLanguage language) => switch (language) {
  PureDesignLanguage.material => theme.colors.primaryBg,
  PureDesignLanguage.cupertino => theme.colors.fillSecondary,
  PureDesignLanguage.macos => null,
  PureDesignLanguage.fluent => theme.colors.fillTertiary,
  PureDesignLanguage.yaru => theme.colors.fillTertiary,
  PureDesignLanguage.forui => theme.colors.fill,
  PureDesignLanguage.glass =>
    theme.isDark ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.55),
  PureDesignLanguage.neumorphic => theme.colors.bgContainer,
  PureDesignLanguage.wind => theme.colors.bgElevated,
};

/// The ring role each language wears; null is the flat discs drawn with no
/// outline at all.
Color? _expectedRing(PureTheme theme, PureDesignLanguage language) => switch (language) {
  PureDesignLanguage.fluent => theme.colors.borderSecondary,
  PureDesignLanguage.forui || PureDesignLanguage.wind => theme.colors.border,
  PureDesignLanguage.glass => theme.isDark ? Colors.white.withValues(alpha: 0.22) : Colors.white.withValues(alpha: 0.7),
  PureDesignLanguage.material ||
  PureDesignLanguage.cupertino ||
  PureDesignLanguage.macos ||
  PureDesignLanguage.yaru ||
  PureDesignLanguage.neumorphic => null,
};

/// The languages that wear a ring, in the implementation's own words.
const List<PureDesignLanguage> _ringed = [
  PureDesignLanguage.fluent,
  PureDesignLanguage.forui,
  PureDesignLanguage.glass,
  PureDesignLanguage.wind,
];

/// The languages whose disc is lifted off the page by its own cast.
const List<PureDesignLanguage> _casted = [PureDesignLanguage.macos, PureDesignLanguage.neumorphic];

Future<PureTheme> _pump(
  WidgetTester tester,
  Widget child, {
  PureDesignLanguage language = PureDesignLanguage.material,
  Brightness brightness = Brightness.light,
  bool reduceTransparency = false,
  bool settle = true,
  double box = 240,
}) async {
  PureTheme? resolved;
  await tester.pumpWidget(
    PureConfigProvider(
      config: UiConfig(
        language: language,
        brightness: brightness == Brightness.dark ? UiBrightnessMode.dark : UiBrightnessMode.light,
        reduceTransparency: reduceTransparency,
      ),
      child: MaterialApp(
        home: Scaffold(
          // A bounded slot with an Align inside it, never a bare tight width:
          // an avatar is a fixed-size control, and a `RenderConstrainedBox`
          // silently keeps an incoming tight constraint instead of the edge it
          // was told to draw, so the disc would read as a 240-wide ellipse.
          body: SizedBox(
            width: box,
            height: box,
            child: Align(
              alignment: AlignmentDirectional.center,
              child: Builder(
                builder: (context) {
                  resolved ??= PureTheme.of(context);
                  return child;
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return resolved!;
}

void main() {
  group('the nine grammars', () {
    testWidgets('every design language paints its own disc from its own tokens', (tester) async {
      for (final language in PureDesignLanguage.values) {
        final theme = await _pump(tester, const PureAvatar(name: 'Ada Liu', size: 40), language: language);
        expect(tester.takeException(), isNull, reason: '$language failed to build');
        expect(_branch(language), findsOneWidget, reason: '$language lost its branch');
        expect(_plate, findsOneWidget, reason: '$language drew no plate');

        // A disc is a disc everywhere: one oval clip, no rectangle anywhere in
        // the branch, the edge the call site asked for, and the initials.
        expect(find.descendant(of: _branch(language), matching: find.byType(ClipRRect)), findsNothing);
        expect(_clip, findsOneWidget, reason: '$language cut its plate more than once');
        expect(tester.getSize(_plate), const Size(40, 40), reason: '$language resized the edge it was given');
        expect(_plateOf(tester).shape, BoxShape.circle, reason: '$language did not draw a circle');
        expect(find.text(_initials), findsOneWidget, reason: '$language dropped the initials');

        expect(_plateOf(tester).color, _expectedFill(theme, language), reason: '$language painted the wrong plate');
        expect(_ringColor(tester), _expectedRing(theme, language), reason: '$language ringed wrongly');
      }
    });

    testWidgets('the nine discs differ in structure, not only in colour', (tester) async {
      final frosted = <PureDesignLanguage>[];
      final ramped = <PureDesignLanguage>[];
      final ringed = <PureDesignLanguage>[];
      final casted = <PureDesignLanguage>[];
      for (final language in PureDesignLanguage.values) {
        await _pump(tester, const PureAvatar(name: 'Ada Liu', size: 40), language: language);
        if (find.descendant(of: _branch(language), matching: find.byType(BackdropFilter)).evaluate().isNotEmpty) {
          frosted.add(language);
        }
        if (_plateOf(tester).gradient != null) {
          ramped.add(language);
        }
        if (_rimOf(tester).border != null) {
          ringed.add(language);
        }
        if (_plateOf(tester).boxShadow != null) {
          casted.add(language);
        }
      }

      // Only glass frosts the page behind the disc.
      expect(frosted, [PureDesignLanguage.glass]);
      // Only macOS lights its plate with a ramp; every other plate is flat.
      expect(ramped, [PureDesignLanguage.macos]);
      // WinUI, shadcn, glass and wind wear an outline; the flat seven wear none.
      expect(ringed, unorderedEquals(_ringed));
      // Only the raised grammars cast: macOS's contact circle and neumorphic's
      // extruded disc.
      expect(casted, unorderedEquals(_casted));
      // Ubuntu's flat disc and WinUI's persona answer to the same plate role and
      // differ only by the ring, so the ring census is what keeps them apart.
      expect(_ringed, contains(PureDesignLanguage.fluent));
      expect(_ringed, isNot(contains(PureDesignLanguage.yaru)));
    });

    testWidgets('macOS is the contact circle: accent ramp lit from the top, letters in white', (tester) async {
      final theme = await _pump(
        tester,
        const PureAvatar(name: 'Ada Liu', size: 40),
        language: PureDesignLanguage.macos,
      );
      final gradient = _plateOf(tester).gradient! as LinearGradient;
      expect(gradient.begin, AlignmentDirectional.topCenter);
      expect(gradient.end, AlignmentDirectional.bottomCenter);
      // The bottom of the ramp is the accent itself, the top is the light on it.
      expect(gradient.colors.last, theme.colors.primary);
      expect(gradient.colors.first, isNot(theme.colors.primary));
      expect(tester.widget<Text>(find.text(_initials)).style!.color, theme.colors.textLightSolid);
      expect(_rimOf(tester).border, isNull, reason: 'the contact circle has no ring, only its cast');
    });

    testWidgets('neumorphic extrudes the disc with light from one side and cast from the other', (tester) async {
      final theme = await _pump(
        tester,
        const PureAvatar(name: 'Ada Liu', size: 40),
        language: PureDesignLanguage.neumorphic,
      );
      final shadows = _plateOf(tester).boxShadow!;
      expect(shadows, hasLength(2));
      // The pair is what makes an extrusion: opposite offsets, and the cast is
      // the token shadow while the light is the white the theme resolves.
      expect(shadows.first.offset, const Offset(3, 3));
      expect(shadows.last.offset, const Offset(-3, -3));
      expect(shadows.first.color, theme.colors.shadowBase);
      expect(_rimOf(tester).border, isNull, reason: 'an extruded disc needs no outline');
    });

    testWidgets('glass frosts its disc, and gives the blur up when transparency is reduced', (tester) async {
      final blur = find.descendant(of: find.byType(PureAvatar), matching: find.byType(BackdropFilter));
      await _pump(tester, const PureAvatar(name: 'Ada Liu', size: 40), language: PureDesignLanguage.glass);
      expect(blur, findsOneWidget, reason: 'the frost never reached the canvas');
      // The light frost is white at a little over half strength, and its rim is
      // the brighter line the plate is cut with.
      expect(_plateOf(tester).color, Colors.white.withValues(alpha: 0.55));
      expect(_ringColor(tester), Colors.white.withValues(alpha: 0.7));

      // The reduced-transparency answer: the same translucent plate, no filter.
      await _pump(
        tester,
        const PureAvatar(name: 'Ada Liu', size: 40),
        language: PureDesignLanguage.glass,
        reduceTransparency: true,
      );
      expect(blur, findsNothing, reason: 'a device that may not blur still blurs');
      expect(_plateOf(tester).color, isNotNull, reason: 'the frost gave up its colour with its filter');
      expect(find.text(_initials), findsOneWidget);
    });
  });

  group('the fallback chain', () {
    testWidgets('a picture that fails to load paints the initials instead', (tester) async {
      await _pump(tester, PureAvatar(name: 'Ada Liu', src: _broken, size: 40));
      await tester.pump();
      // Nothing decoded, so no raster was ever handed to the disc, and the
      // error's replacement is the same fallback a missing picture gets.
      expect(find.byType(RawImage), findsNothing);
      expect(find.text(_initials), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'the error escaped the errorBuilder');
    });

    testWidgets('a picture is drawn cover-fit on the plate with its failure answer wired', (tester) async {
      await _pump(tester, PureAvatar(name: 'Ada Liu', src: _broken, size: 40), settle: false);
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, _broken);
      expect(image.fit, BoxFit.cover, reason: 'a squashed face is not an avatar');
      expect(image.errorBuilder, isNotNull, reason: 'the chain lost its failure answer');
      // Nothing decoded, so no raster ever reached the disc, and the wired
      // failure answer is the initials the name gives.
      expect(find.byType(RawImage), findsNothing);
      expect(find.text(_initials), findsOneWidget);
    });

    testWidgets('the call site glyph answers a nameless row, and the initials answer first', (tester) async {
      await _pump(tester, const PureAvatar(icon: Icons.star_rounded, size: 40));
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      expect(find.byIcon(Icons.person), findsNothing);

      // A name outranks a glyph: the chain is picture, initials, icon, silhouette.
      await _pump(tester, const PureAvatar(name: 'Ada Liu', icon: Icons.star_rounded, size: 40));
      expect(find.text(_initials), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNothing);

      // And a failed picture falls through the empty initials to the glyph.
      await _pump(tester, PureAvatar(src: _broken, icon: Icons.star_rounded, size: 40));
      await tester.pump();
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    });

    testWidgets('an avatar with nothing at all takes the silhouette', (tester) async {
      await _pump(tester, const PureAvatar(size: 40));
      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(find.text(_initials), findsNothing);
      expect(_plate, findsOneWidget);
      expect(tester.widget<Semantics>(_semantics).properties.label, isNull, reason: 'an anonymous disc is anonymous');
    });

    testWidgets('WinUI keeps initials out of the Persona steps below 24', (tester) async {
      for (final edge in [16.0, 20.0]) {
        await _pump(
          tester,
          PureAvatar(name: 'Ada Liu', size: edge),
          language: PureDesignLanguage.fluent,
        );
        expect(find.text(_initials), findsNothing, reason: '$edge px of disc cannot carry two capitals');
        expect(find.byIcon(Icons.person), findsOneWidget, reason: '$edge px drew no silhouette either');
      }
      await _pump(tester, const PureAvatar(name: 'Ada Liu', size: 24), language: PureDesignLanguage.fluent);
      expect(find.text(_initials), findsOneWidget, reason: 'the persona step at 24 stopped drawing initials');
      expect(find.byIcon(Icons.person), findsNothing);
    });
  });

  group('geometry', () {
    testWidgets('the size tiers lay out the edge they are handed and size the letters with it', (tester) async {
      final painted = <double>[];
      for (final edge in [16.0, 24.0, 32.0, 48.0, 96.0]) {
        await _pump(tester, PureAvatar(name: 'Ada Liu', size: edge));
        expect(tester.getSize(_plate), Size(edge, edge), reason: 'the disc drifted off $edge');
        final fontSize = tester.widget<Text>(find.text(_initials)).style!.fontSize!;
        expect(fontSize, greaterThan(0));
        expect(fontSize, lessThanOrEqualTo(edge * 0.5 + 0.001), reason: 'the initials spill out of a $edge disc');
        painted.add(fontSize);
      }
      for (var i = 1; i < painted.length; i++) {
        expect(painted[i], greaterThan(painted[i - 1]), reason: 'the type stopped growing with the disc');
      }
    });

    testWidgets('the square form is cornered by the language and capped by the edge', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pump(
          tester,
          const PureAvatar(name: 'Ada Liu', size: 40, shape: PureAvatarShape.rounded),
          language: language,
        );
        expect(_clip, findsOneWidget, reason: '$language cut its square more than once');
        expect(find.descendant(of: _branch(language), matching: find.byType(ClipOval)), findsNothing);
        expect(_plateOf(tester).shape, BoxShape.rectangle, reason: '$language drew a circle for a square');

        final clipRadius = tester.widget<ClipRRect>(_clip).borderRadius as BorderRadius;
        expect(clipRadius.topLeft.x, greaterThan(0), reason: '$language squared its corners away');
        expect(clipRadius.topLeft.x, lessThanOrEqualTo(10), reason: '$language overflowed the quarter-edge cap');
        // The plate the ring sits on is cornered exactly like the clip, or the
        // ring would outline a circle around a square picture.
        expect(_plateOf(tester).borderRadius, clipRadius, reason: '$language ringed a different shape than it clipped');
        expect(_rimOf(tester).borderRadius, clipRadius, reason: '$language drew its rim off the plate');

        // A dense avatar keeps straight sides: the cap binds at a quarter edge.
        await _pump(
          tester,
          const PureAvatar(name: 'Ada Liu', size: 16, shape: PureAvatarShape.rounded),
          language: language,
        );
        final capped = (tester.widget<ClipRRect>(_clip).borderRadius as BorderRadius).topLeft.x;
        expect(capped, lessThanOrEqualTo(4), reason: '$language blobbed a 16dp avatar');
      }
    });

    testWidgets('every avatar is cut with exactly one clip', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pump(
          tester,
          PureAvatar(name: 'Ada Liu', src: _broken, size: 48),
          language: language,
        );
        expect(_clip, findsOneWidget, reason: '$language clipped its body more than once');
      }
    });
  });

  group('reading and dark', () {
    testWidgets('the disc is named by the display name, or the label the call site gives', (tester) async {
      await _pump(tester, const PureAvatar(name: 'Ada Liu', size: 40));
      var node = tester.widget<Semantics>(_semantics).properties;
      expect(node.label, 'Ada Liu');
      expect(node.image, isFalse, reason: 'there is no picture in this avatar');
      expect(
        tester.widget<Semantics>(_semantics).excludeSemantics,
        isTrue,
        reason: 'the painted initials would be read a second time',
      );

      await _pump(tester, const PureAvatar(name: 'Ada Liu', semanticLabel: 'Room anchor', size: 40));
      node = tester.widget<Semantics>(_semantics).properties;
      expect(node.label, 'Room anchor', reason: 'the call site label did not win');

      await _pump(tester, PureAvatar(name: 'Ada Liu', src: _broken, size: 40), settle: false);
      node = tester.widget<Semantics>(_semantics).properties;
      expect(node.image, isTrue, reason: 'a picture is an image before it fails');
    });

    testWidgets('the dark ramp keeps every grammar and its own plate role', (tester) async {
      for (final language in PureDesignLanguage.values) {
        final theme = await _pump(
          tester,
          const PureAvatar(name: 'Ada Liu', size: 40),
          language: language,
          brightness: Brightness.dark,
        );
        expect(tester.takeException(), isNull, reason: '$language failed in dark');
        expect(theme.isDark, isTrue);
        expect(_branch(language), findsOneWidget, reason: '$language lost its branch in dark');
        expect(_plateOf(tester).color, _expectedFill(theme, language), reason: '$language repainted itself in dark');
        expect(_ringColor(tester), _expectedRing(theme, language));
        expect(find.text(_initials), findsOneWidget, reason: '$language lost its letters in dark');
        expect(tester.getSize(_plate), const Size(40, 40), reason: '$language resized the edge in dark');
      }
      // Glass is the one plate named by white, so its dark frost is the lighter
      // cut of the two the implementation resolves.
      await _pump(tester, const PureAvatar(name: 'Ada Liu', size: 40), language: PureDesignLanguage.glass);
      final light = _plateOf(tester).color!;
      await _pump(
        tester,
        const PureAvatar(name: 'Ada Liu', size: 40),
        language: PureDesignLanguage.glass,
        brightness: Brightness.dark,
      );
      final dark = _plateOf(tester).color!;
      expect(dark.a, lessThan(light.a), reason: 'dark frost does not read as a hole in the page');
    });
  });

  group('compatibility', () {
    testWidgets('the edges the app pages hand all land, and the default keeps the token ladder', (tester) async {
      for (final language in PureDesignLanguage.values) {
        // The roster row, the card, the chat line, the login and the anchor card.
        for (final edge in [32.0, 36.0, 40.0, 60.0, 64.0]) {
          await _pump(
            tester,
            PureAvatar(name: 'Ada Liu', size: edge),
            language: language,
          );
          expect(tester.getSize(_plate), Size(edge, edge), reason: '$language resized $edge');
          expect(find.text(_initials), findsOneWidget, reason: '$language lost the row initials at $edge');
        }

        // A call site with no edge keeps the large control height it always had.
        final theme = await _pump(tester, const PureAvatar(name: 'Ada Liu'), language: language);
        expect(
          tester.getSize(_plate),
          Size.square(theme.token.scale.controlHeightLG),
          reason: '$language lost the default edge',
        );

        // A caller-supplied picture with no name at all still builds.
        await _pump(tester, PureAvatar(src: _broken, size: 40), language: language);
        expect(tester.takeException(), isNull, reason: '$language failed on an anonymous picture');
        expect(find.byIcon(Icons.person), findsOneWidget);
      }
    });

    testWidgets('an avatar inside a badge keeps its own geometry', (tester) async {
      await _pump(
        tester,
        const PureBadge(dot: true, child: PureAvatar(name: 'Ada Liu', size: 36)),
        language: PureDesignLanguage.forui,
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(_plate), const Size(36, 36));
      expect(find.text(_initials), findsOneWidget);
    });
  });
}
