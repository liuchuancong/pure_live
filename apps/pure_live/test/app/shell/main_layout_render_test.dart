import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pure_live/app/delegates.dart' show appLocalizationsDelegates, appSupportedLocales;
import 'package:pure_live/app/shell/home_views.dart';
import 'package:pure_live/app/shell/main_page_frame.dart';
import 'package:pure_live/app/shell/shell_actions.dart';
import 'package:pure_live/app/shell/shell_destinations.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The reference-shaped shell, run through the real host chain.
///
/// The rail/bottom-bar split at [homeRailBreakpoint] and the phone-only
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
                width: HomeRailMetrics.width,
                child: HomeRail(
                  branches: ShellBranch.values,
                  selected: ShellBranch.follow,
                  onSelected: (_) {},
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

    expect(find.byKey(const ValueKey('home-rail')), findsNothing); // the rail box is the shell's; the column is here
    expect(find.byKey(const ValueKey('home-menu')), findsOneWidget);
    for (final action in homeActions()) {
      expect(find.byKey(ValueKey('home-rail-${action.name}')), findsOneWidget, reason: action.name);
    }
    expect(find.byKey(const ValueKey('home-rail-separator')), findsOneWidget);
    for (final branch in ShellBranch.values) {
      expect(find.byKey(ValueKey('home-nav-${branch.name}')), findsOneWidget, reason: branch.name);
    }
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

    expect(find.byKey(const ValueKey('home-menu')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-search')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-more')), findsOneWidget);
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
  testWidgets('the rail is 80 wide and the breakpoint is 600', (tester) async {
    expect(HomeRailMetrics.width, 80);
    expect(isHomeRailWidth(599), isFalse);
    expect(isHomeRailWidth(600), isTrue);
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
