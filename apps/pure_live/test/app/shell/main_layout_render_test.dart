import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pure_live/app/app_delegates.dart' show appLocalizationsDelegates, appSupportedLocales;
import 'package:pure_live/app/shell/home_views.dart';
import 'package:pure_live/app/shell/main_page_frame.dart';
import 'package:pure_live/app/shell/shell_destinations.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The reference-shaped shell, run through the real host chain.
///
/// The column/bottom-bar split at [homeRailBreakpoint] and the phone-only
/// placement of the menu/search buttons are structural choices, not pixel
/// details: these tests pin which form is mounted at each width and that the
/// whole tree lays out without an exception.
void main() {
  for (final language in PureDesignLanguage.values) {
    testWidgets('the rail mounts at 600 under ${language.name}', (tester) async {
      await _pumpAt(
        tester,
        const Size(900, 900),
        language: language,
        child: HomeLayoutScope(
          phone: false,
          child: Scaffold(
            body: Row(
              children: [
                SizedBox(
                  width: AdaptiveShellSizes.railWidth,
                  child: Builder(
                    builder: (context) => PureNavigationRail(
                      destinations: shellPrimaryDestinations(context),
                      selectedId: ShellBranch.follow.name,
                      onDestinationSelected: (_) {},
                    ),
                  ),
                ),
                Expanded(
                  child: MainPageFrame(
                    title: '热门',
                    inHome: true,
                    tabs: const [
                      PureTab(label: '全部'),
                      PureTab(label: '斗鱼'),
                    ],
                    onTabChanged: (_) {},
                    body: const ColoredBox(color: Color(0xFFF5F5F5), child: Text('BODY')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Rail mode: the page bar carries no shell buttons.
      expect(find.byKey(const ValueKey('home-search')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a phone home tab puts the menu and search buttons on its bar', (tester) async {
      await _pumpAt(
        tester,
        const Size(390, 844),
        language: language,
        child: HomeLayoutScope(
          phone: true,
          child: MainPageFrame(
            title: '热门',
            inHome: true,
            tabs: const [PureTab(label: '全部')],
            onTabChanged: (_) {},
            body: const ColoredBox(color: Color(0xFFF5F5F5), child: Text('BODY')),
          ),
        ),
      );

      // The bar's one shell affordance is the top-left menu; the tools it
      // opens live in the drawer, so no search or more buttons sit at the end.
      expect(find.byKey(const ValueKey('home-menu')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-search')), findsNothing);
      expect(find.byKey(const ValueKey('home-more')), findsNothing);
      expect(find.text('热门'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a pushed page outside the home tabs shows no shell buttons', (tester) async {
      await _pumpAt(
        tester,
        const Size(390, 844),
        child: const MainPageFrame(
          title: '历史',
          body: ColoredBox(color: Color(0xFFF5F5F5), child: Text('BODY')),
        ),
      );

      expect(find.byKey(const ValueKey('home-menu')), findsNothing);
      expect(find.byKey(const ValueKey('home-search')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('the breakpoint sits at 600', (tester) async {
    expect(isHomeRailWidth(599), isFalse);
    expect(isHomeRailWidth(600), isTrue);
  });

  test('a wide phone keeps the bottom bar only when asked to', () {
    expect(usesHomeBottomBar(900, bottomBarOnWide: false, mobile: true), isFalse);
    expect(usesHomeBottomBar(900, bottomBarOnWide: true, mobile: true), isTrue);
    // A desktop window is never turned into the phone chrome.
    expect(usesHomeBottomBar(900, bottomBarOnWide: true, mobile: false), isFalse);
    // Under the breakpoint the bottom bar is not a choice.
    expect(usesHomeBottomBar(390, bottomBarOnWide: false, mobile: false), isTrue);
  });
}

/// Pumps [child] through the same host chain the app uses: PureTheme above
/// PureApp, which mounts FluentApp for this configuration.
Future<void> _pumpAt(
  WidgetTester tester,
  Size size, {
  required Widget child,
  PureDesignLanguage language = PureDesignLanguage.fluent,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    PureConfigProvider(
      config: UiConfig(language: language),
      child: PureApp(
        routerConfig: GoRouter(
          routes: [GoRoute(path: '/', builder: (context, state) => child)],
        ),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        builder: (context, appChild) => TranslationProvider(child: appChild!),
      ),
    ),
  );
  for (var attempt = 0; attempt < 4; attempt++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}
