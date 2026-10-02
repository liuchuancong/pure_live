import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('the fade-forwards box between two routes stops painting the theme colour', (tester) async {
    // The transition paints `ColorScheme.surface` behind a page while it fades
    // out; over a wallpaper that box is the flash seen on every page entry.
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

    final PageTransitionsBuilder builder = theme.pageTransitionsTheme.builders[TargetPlatform.windows]!;
    expect(builder, isA<FadeForwardsPageTransitionsBuilder>());
    expect((builder as FadeForwardsPageTransitionsBuilder).backgroundColor, Colors.transparent);
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
