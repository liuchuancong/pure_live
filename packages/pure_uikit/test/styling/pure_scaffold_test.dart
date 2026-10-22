import 'dart:ui' show SemanticsRole;

import 'package:flutter/cupertino.dart' show CupertinoPageScaffold;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The page frame's own anchors: the plate it paints, the content box the
/// bars are measured against, and the two bar bands. Everything an assertion
/// reads lives here, so a language's grammar is addressable without walking
/// the dispatched bars.
final Finder _plate = find.byKey(const ValueKey('PureScaffold.plate'));
final Finder _body = find.byKey(const ValueKey('PureScaffold.body'));
final Finder _topSlot = find.byKey(const ValueKey('PureScaffold.topBarSlot'));
final Finder _bottomSlot = find.byKey(const ValueKey('PureScaffold.bottomBarSlot'));

Key _branch(PureDesignLanguage language) => ValueKey('PureScaffold.${language.name}');

/// The band a slot paints — the first [DecoratedBox] under the slot's
/// semantics node, before anything the bar itself brings.
BoxDecoration _band(WidgetTester tester, Finder slot) =>
    tester.widget<DecoratedBox>(find.descendant(of: slot, matching: find.byType(DecoratedBox)).first).decoration
        as BoxDecoration;

BoxDecoration _plateAt(WidgetTester tester) => tester.widget<DecoratedBox>(_plate).decoration as BoxDecoration;

/// The theme the scaffold resolved — the tokens its planes are promised from.
PureTheme _theme(WidgetTester tester) => PureTheme.of(tester.element(_plate));

/// A body big enough for every rect the tests measure to be the content
/// box's own rect.
const Widget _pageBody = ColoredBox(key: Key('PureScaffold.body'), color: Colors.transparent);

Future<void> _pump(
  WidgetTester tester, {
  required PureDesignLanguage language,
  Widget? appBar,
  Widget? bottomBar,
  Widget? floatingActionButton,
  Color? background,
  bool extendBodyBehindAppBar = false,
  bool avoidKeyboard = true,
  bool transparentCanvas = false,
  bool reduceTransparency = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 600);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    PureConfigProvider(
      config: UiConfig(language: language, reduceTransparency: reduceTransparency),
      child: MaterialApp(
        home: PureCanvasScope(
          transparent: transparentCanvas,
          child: PureScaffold(
            appBar: appBar,
            bottomBar: bottomBar,
            floatingActionButton: floatingActionButton,
            background: background,
            extendBodyBehindAppBar: extendBodyBehindAppBar,
            avoidKeyboard: avoidKeyboard,
            body: _pageBody,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// A plain bar: no [PreferredSizeWidget], so the frame's fallback slot
/// height applies, and no decoration of its own to confuse the band reads.
const Widget _plainBar = ColoredBox(key: Key('PureScaffold.testBar'), color: Colors.transparent);

/// A bar that declares its own height, the way a real dispatched app bar does.
class _DeclaredBar extends StatelessWidget implements PreferredSizeWidget {
  const new();

  @override
  Size get preferredSize => const Size.fromHeight(90);

  @override
  Widget build(BuildContext context) => const ColoredBox(color: Colors.transparent);
}

void main() {
  group('branches and planes', () {
    testWidgets('the nine languages all build their own page frame', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pump(tester, language: language, appBar: _plainBar, bottomBar: _plainBar);
        expect(tester.takeException(), isNull, reason: '$language failed to build');
        expect(find.byKey(_branch(language)), findsOneWidget, reason: '$language lost its branch');
        expect(_body, findsOneWidget, reason: '$language lost its page');
        expect(find.byType(Scaffold), findsNothing, reason: '$language borrowed Material again');
        expect(find.byType(CupertinoPageScaffold), findsNothing, reason: '$language borrowed Cupertino again');
      }
    }, timeout: const Timeout(Duration(minutes: 3)));

    testWidgets('the content keeps a Material engine host for the kit controls', (tester) async {
      // The frame paints the plate itself, but the kit's own editing and ink
      // controls still require the Material ancestor the borrowed Scaffold
      // used to carry — a transparency host answers it without a second plate.
      for (final language in PureDesignLanguage.values) {
        await _pump(tester, language: language, appBar: _plainBar, bottomBar: _plainBar);
        final host = tester.element(_body).findAncestorWidgetOfExactType<Material>();
        expect(host?.type, MaterialType.transparency, reason: '$language stranded its controls');
      }
    });

    testWidgets('each plate is the token plane its language promises', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pump(tester, language: language);
        final plate = _plateAt(tester);
        final theme = _theme(tester);
        if (language == PureDesignLanguage.neumorphic) {
          // The mouldable page is the container tone, not the layout one.
          expect(plate.color, theme.colors.bgContainer, reason: '$language lost the extruded base');
        } else if (language == PureDesignLanguage.glass) {
          expect(plate.color!.a, lessThan(1), reason: '$language frosted nothing');
          expect(plate.color!.a, greaterThan(0), reason: '$language painted the page invisible');
        } else if (language == PureDesignLanguage.fluent) {
          expect(plate.gradient, isA<LinearGradient>(), reason: '$language lost its mica scrim');
          expect(plate.color, isNull, reason: '$language flat-painted over the scrim');
        } else {
          expect(plate.color, theme.colors.bgLayout, reason: '$language left its flat plane');
        }
      }
    });

    testWidgets('the slot grammars keep their bands, hairlines and shadows', (tester) async {
      const topBanded = {
        PureDesignLanguage.cupertino,
        PureDesignLanguage.macos,
        PureDesignLanguage.fluent,
        PureDesignLanguage.glass,
        PureDesignLanguage.neumorphic,
      };
      const bottomBanded = {PureDesignLanguage.cupertino, PureDesignLanguage.glass, PureDesignLanguage.neumorphic};
      const topHairlined = {
        PureDesignLanguage.cupertino,
        PureDesignLanguage.macos,
        PureDesignLanguage.glass,
        PureDesignLanguage.wind,
        PureDesignLanguage.yaru,
      };
      const bottomHairlined = {PureDesignLanguage.cupertino, PureDesignLanguage.glass, PureDesignLanguage.forui};
      const topShadowed = {PureDesignLanguage.material, PureDesignLanguage.fluent, PureDesignLanguage.neumorphic};
      const bottomShadowed = {PureDesignLanguage.neumorphic};

      for (final language in PureDesignLanguage.values) {
        await _pump(tester, language: language, appBar: _plainBar, bottomBar: _plainBar);
        final top = _band(tester, _topSlot);
        final bottom = _band(tester, _bottomSlot);

        expect(top.color != null, topBanded.contains(language), reason: '$language changed its top band rule');
        expect(bottom.color != null, bottomBanded.contains(language), reason: '$language changed its bottom band rule');
        final topLine = (top.border is Border) ? (top.border! as Border).bottom.color : null;
        final hasTopLine = topLine != null && topLine.a > 0;
        expect(hasTopLine, topHairlined.contains(language), reason: '$language moved its header rule');
        final bottomLine = (bottom.border is Border) ? (bottom.border! as Border).top.color : null;
        final hasBottomLine = bottomLine != null && bottomLine.a > 0;
        expect(hasBottomLine, bottomHairlined.contains(language), reason: '$language moved its footer rule');
        expect(top.boxShadow != null, topShadowed.contains(language), reason: '$language re-elevated its chrome');
        expect(
          bottom.boxShadow != null,
          bottomShadowed.contains(language),
          reason: '$language re-moulded its bottom slot',
        );
      }
    });

    testWidgets('a background override paints the plane in every language', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pump(tester, language: language, background: Colors.pink);
        expect(_plateAt(tester).color, Colors.pink, reason: '$language overrode the caller');
        expect(_plateAt(tester).gradient, isNull, reason: '$language kept its scrim over the override');
      }
    });

    testWidgets('a canvas scope leaves the plate clear but keeps the chrome', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pump(tester, language: language, appBar: _plainBar, transparentCanvas: true);
        expect(_plateAt(tester).color, const Color(0x00000000), reason: '$language hid the wallpaper');
        // The edge rules still read against the wallpaper the scope reveals.
        final top = _band(tester, _topSlot);
        if (language == PureDesignLanguage.wind || language == PureDesignLanguage.yaru) {
          expect(top.border, isNotNull, reason: '$language dropped its rule into the canvas');
        }
      }
    });
  });

  group('layout contract', () {
    testWidgets('the bar slots reserve their fallback heights', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pump(tester, language: language, appBar: _plainBar, bottomBar: _plainBar);
        // No layout scope in the harness, so the frame answers with its
        // documented defaults: 56 above, 64 below.
        expect(tester.getRect(_body).top, 56, reason: '$language did not reserve the header');
        expect(tester.getRect(_body).bottom, 600 - 64, reason: '$language did not reserve the strip');
        expect(tester.getSize(_topSlot).height, 56, reason: '$language grew the header band');
        expect(tester.getSize(_bottomSlot).height, 64, reason: '$language grew the footer band');
      }
    });

    testWidgets('a PreferredSizeWidget bar keeps its own declared height', (tester) async {
      await _pump(tester, language: PureDesignLanguage.material, appBar: const _DeclaredBar());
      expect(tester.getRect(_body).top, 90, reason: 'the frame ignored the bar it was handed');
    });

    testWidgets('extendBodyBehindAppBar starts the body under the band', (tester) async {
      await _pump(tester, language: PureDesignLanguage.material, appBar: _plainBar, extendBodyBehindAppBar: true);
      expect(tester.getRect(_body).top, 0, reason: 'the body still waited below the bar');
      expect(tester.getRect(_topSlot).top, 0, reason: 'the overlay band lost its edge');
      expect(tester.getSize(_topSlot).height, 56, reason: 'the band changed height for the overlay');
    });

    testWidgets('the keyboard lifts the content only when asked', (tester) async {
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await _pump(tester, language: PureDesignLanguage.material);
      await tester.pumpAndSettle();
      expect(tester.getRect(_body).bottom, 600 - 300, reason: 'the content ignored the keyboard');

      await _pump(tester, language: PureDesignLanguage.material, avoidKeyboard: false);
      // The dodge unwinds on the theme's motion, so the settled frame is the
      // full-height one.
      await tester.pumpAndSettle();
      expect(tester.getRect(_body).bottom, 600, reason: 'a frame told not to dodge still dodged');
    });

    testWidgets('safe areas inset the bands, never the plate', (tester) async {
      tester.view.padding = const FakeViewPadding(top: 44, bottom: 34, left: 21, right: 21);
      addTearDown(tester.view.reset);
      double? barTopPadding;
      await _pump(
        tester,
        language: PureDesignLanguage.cupertino,
        appBar: Builder(
          builder: (context) {
            barTopPadding = MediaQuery.paddingOf(context).top;
            return const SizedBox.shrink();
          },
        ),
        bottomBar: _plainBar,
      );
      // The plate runs to the physical edge; the band paints behind the
      // status bar and the bar sits inside it, past the inset it consumed.
      expect(tester.getRect(_plate).top, 0, reason: 'the plate ducked the status bar');
      expect(tester.getRect(_topSlot).height, 44 + 56, reason: 'the header band lost its inset');
      expect(tester.getRect(_bottomSlot).height, 34 + 64, reason: 'the footer band lost its home-indicator inset');
      expect(barTopPadding, 0, reason: 'the bar was left its own status-bar padding to double up');
      // The content box keeps the live insets for the page's own SafeAreas,
      // exactly like the Material frame it replaced.
      expect(tester.getRect(_body).left, 0, reason: 'the frame padded the page itself');
      expect(tester.getRect(_body).top, 44 + 56, reason: 'the body did not clear the inset band');
    });

    testWidgets('the floating action rides above the reserved strip', (tester) async {
      await _pump(
        tester,
        language: PureDesignLanguage.material,
        bottomBar: _plainBar,
        floatingActionButton: const SizedBox(key: Key('PureScaffold.testFab'), width: 48, height: 48),
      );
      final margin = _theme(tester).token.scale.sizes.md;
      final fab = tester.getRect(find.byKey(const Key('PureScaffold.testFab')));
      expect(fab.right, 800 - margin, reason: 'the action ignored the page margin');
      expect(fab.bottom, 600 - 64 - margin, reason: 'the action sat on the bottom bar, not above it');
    });
  });

  group('semantics and frost policy', () {
    testWidgets('the bar slots scope their semantics and the strip is the landmark', (tester) async {
      await _pump(tester, language: PureDesignLanguage.fluent, appBar: _plainBar, bottomBar: _plainBar);
      // One navigation landmark per page: the destination strip below. The
      // header reads as a plain container scope so a page with both slots
      // never trips the unique-landmark rule.
      expect(find.byKey(const ValueKey('PureScaffold.topBarSlot')), findsOneWidget);
      expect(
        tester.widget<Semantics>(_topSlot).properties.role,
        anyOf(isNull, equals(SemanticsRole.none)),
        reason: 'the header claimed a landmark and the page lost its unique navigation',
      );
      expect(tester.widget<Semantics>(_bottomSlot).properties.role, SemanticsRole.navigation);
      expect(tester.takeException(), isNull);
    });

    testWidgets('frosted grammars blur when the device affords it', (tester) async {
      for (final language in [
        PureDesignLanguage.cupertino,
        PureDesignLanguage.macos,
        PureDesignLanguage.fluent,
        PureDesignLanguage.glass,
      ]) {
        await _pump(tester, language: language, appBar: _plainBar);
        expect(
          find.descendant(of: _topSlot, matching: find.byType(BackdropFilter)),
          findsOneWidget,
          reason: '$language frosted without a filter',
        );
      }
      await _pump(tester, language: PureDesignLanguage.material, appBar: _plainBar);
      expect(find.byType(BackdropFilter), findsNothing, reason: 'a flat plane started blurring');
    });

    testWidgets('reduced transparency makes every plane solid', (tester) async {
      for (final language in PureDesignLanguage.values) {
        await _pump(tester, language: language, appBar: _plainBar, bottomBar: _plainBar, reduceTransparency: true);
        expect(find.byType(BackdropFilter), findsNothing, reason: '$language kept its filter');
        final plate = _plateAt(tester);
        if (language == PureDesignLanguage.fluent) {
          // The mica scrim is a two-tone gradient of solid tokens; it never
          // relies on translucency and stays itself.
          expect(plate.gradient, isA<LinearGradient>());
        } else {
          expect(plate.color!.a, 1, reason: '$language stayed translucent under the policy');
          final band = _band(tester, _topSlot);
          expect(band.color?.a ?? 1, 1, reason: '$language kept a see-through band');
        }
        expect(tester.takeException(), isNull, reason: '$language failed the policy');
      }
    });
  });
}
