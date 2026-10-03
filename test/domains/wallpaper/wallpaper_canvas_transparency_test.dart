import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/theme/app_canvas_scope.dart';
import 'package:pure_live/domains/wallpaper/presentation/app_background.dart';

const Color _themeScaffold = Color(0xFF123456);

Future<ThemeData> _themeUnder(WidgetTester tester, {required bool ownsCanvas}) async {
  late ThemeData seen;
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(scaffoldBackgroundColor: _themeScaffold),
      home: WallpaperCanvasTheme(
        ownsCanvas: ownsCanvas,
        child: Builder(
          builder: (context) {
            seen = Theme.of(context);
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    ),
  );
  return seen;
}

void main() {
  testWidgets('a wallpaper-owned canvas stops the page painting its own colour', (tester) async {
    final ThemeData theme = await _themeUnder(tester, ownsCanvas: true);
    expect(theme.scaffoldBackgroundColor, Colors.transparent);
  });

  testWidgets('without a wallpaper the theme scaffold colour is untouched', (tester) async {
    final ThemeData theme = await _themeUnder(tester, ownsCanvas: false);
    expect(theme.scaffoldBackgroundColor, _themeScaffold);
    expect(theme.colorScheme.surface.a, 1.0);
    expect(theme.appBarTheme.backgroundColor, isNull);
    expect(theme.cardTheme.color, isNull);
  });

  testWidgets('page chrome is washed while a wallpaper shows', (tester) async {
    final ThemeData theme = await _themeUnder(tester, ownsCanvas: true);

    expect(theme.canvasColor.a, closeTo(kWallpaperSurfaceOpacity, 0.001));
    expect(theme.appBarTheme.backgroundColor?.a, closeTo(kWallpaperSurfaceOpacity, 0.001));
    expect(theme.navigationRailTheme.backgroundColor?.a, closeTo(kWallpaperSurfaceOpacity, 0.001));
    expect(theme.navigationBarTheme.backgroundColor?.a, closeTo(kWallpaperSurfaceOpacity, 0.001));
    expect(theme.chipTheme.backgroundColor?.a, closeTo(kWallpaperSurfaceOpacity, 0.001));
  });

  testWidgets('cards stay much more solid than the chrome', (tester) async {
    // Cards carry the text: a card must read the same over a bright and a dark
    // part of the picture, and the settings list reads this colour too.
    final ThemeData theme = await _themeUnder(tester, ownsCanvas: true);

    expect(theme.cardTheme.color?.a, closeTo(kWallpaperCardOpacity, 0.001));
    expect(theme.cardColor.a, closeTo(kWallpaperCardOpacity, 0.001));
    expect(kWallpaperCardOpacity, greaterThan(kWallpaperSurfaceOpacity));
  });

  testWidgets('dialogs, menus and sheets keep their opaque surfaces', (tester) async {
    // Explicit feedback: a picture behind a popup menu or a dialog reads as
    // noise, so the colour scheme those overlays resolve from stays untouched.
    final ThemeData theme = await _themeUnder(tester, ownsCanvas: true);

    expect(theme.colorScheme.surface.a, 1.0);
    expect(theme.colorScheme.surfaceContainer.a, 1.0, reason: 'popup menu background');
    expect(theme.colorScheme.surfaceContainerHigh.a, 1.0, reason: 'dialog background');
    expect(theme.colorScheme.surfaceContainerLow.a, 1.0, reason: 'bottom sheet background');
    expect(theme.dialogTheme.backgroundColor, isNull, reason: 'stock M3 dialog colour');
    expect(theme.popupMenuTheme.color, isNull, reason: 'stock M3 menu colour');
    expect(theme.colorScheme.onSurface.a, 1.0, reason: 'text keeps full contrast');
    expect(theme.colorScheme.primary, ThemeData().colorScheme.primary, reason: 'semantic colours untouched');
  });

  testWidgets('the wrapper keeps one widget shape while the state flips', (tester) async {
    // Swapping between `child` and a wrapper would deactivate the Navigator
    // subtree for a frame, which is what the earlier layer-shape bug looked
    // like; a `Theme` in both states keeps the element in place.
    Widget build(bool ownsCanvas) => MaterialApp(
      home: WallpaperCanvasTheme(
        ownsCanvas: ownsCanvas,
        child: const SizedBox(key: ValueKey<String>('page')),
      ),
    );

    await tester.pumpWidget(build(false));
    final Element before = tester.element(find.byKey(const ValueKey<String>('page')));

    await tester.pumpWidget(build(true));
    final Element after = tester.element(find.byKey(const ValueKey<String>('page')));

    expect(identical(before, after), isTrue, reason: 'the subtree is updated in place, not rebuilt');
    expect(Theme.of(after).scaffoldBackgroundColor, Colors.transparent);
  });

  testWidgets('the two pages of a push never share the screen', (tester) async {
    // The stock fade-forwards backdrop is an opaque `ColorScheme.surface`
    // (a flash of the theme colour over a wallpaper) and a transparent one
    // ghosts both translucent pages over each other (a white flash in a light
    // theme, black in a dark one). The picture owns the canvas, so the covered
    // page must be gone before the new one appears.
    for (double t = 0.0; t <= 1.0001; t += 0.05) {
      final double incoming = WallpaperFadeThroughTransitionsBuilder.incomingOpacity(t);
      final double outgoing = WallpaperFadeThroughTransitionsBuilder.outgoingOpacity(t);
      expect(incoming + outgoing, lessThanOrEqualTo(1.0 + 1e-9), reason: 'overlap at t=$t');
      // Nothing opaque hides the picture in between: there is a moment where
      // both pages are invisible and only the wallpaper is on screen.
      expect(math.min(incoming, outgoing), lessThan(0.5));
    }
    expect(WallpaperFadeThroughTransitionsBuilder.incomingOpacity(0.0), 0.0);
    expect(WallpaperFadeThroughTransitionsBuilder.incomingOpacity(1.0), 1.0);
    expect(WallpaperFadeThroughTransitionsBuilder.outgoingOpacity(0.0), 1.0);
    expect(WallpaperFadeThroughTransitionsBuilder.outgoingOpacity(1.0), 0.0);
  });

  testWidgets('a wallpaper canvas carries the fade-through transitions', (tester) async {
    late ThemeData theme;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: <TargetPlatform, PageTransitionsBuilder>{
              TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
            },
          ),
        ),
        home: WallpaperCanvasTheme(
          ownsCanvas: true,
          child: Builder(
            builder: (context) {
              theme = Theme.of(context);
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      ),
    );

    for (final TargetPlatform platform in <TargetPlatform>[
      TargetPlatform.android,
      TargetPlatform.windows,
      TargetPlatform.iOS,
    ]) {
      expect(
        theme.pageTransitionsTheme.builders[platform],
        isA<WallpaperFadeThroughTransitionsBuilder>(),
        reason: 'platform $platform',
      );
    }
  });

  testWidgets('without a wallpaper the transitions are left exactly as they are', (tester) async {
    const PageTransitionsTheme original = PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{TargetPlatform.windows: FadeForwardsPageTransitionsBuilder()},
    );
    late ThemeData theme;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(pageTransitionsTheme: original),
        home: WallpaperCanvasTheme(
          ownsCanvas: false,
          child: Builder(
            builder: (context) {
              theme = Theme.of(context);
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      ),
    );

    final PageTransitionsBuilder builder = theme.pageTransitionsTheme.builders[TargetPlatform.windows]!;
    expect((builder as FadeForwardsPageTransitionsBuilder).backgroundColor, isNull);
  });
}
