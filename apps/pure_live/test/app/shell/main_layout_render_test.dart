import 'package:fluent_2/fluent_2.dart' as f2;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pure_live/app/delegates.dart' show appLocalizationsDelegates, appSupportedLocales;
import 'package:pure_live/app/shell/main_page_frame.dart';
import 'package:pure_live/app/shell/main_sidebar.dart';
import 'package:pure_live/app/shell/main_workspace.dart';
import 'package:pure_live/app/shell/shell_actions.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The new shell's two layouts, run through the real Fluent host chain.
///
/// The workspace frame and the compact tablet rail are structural choices, not
/// pixel details: these tests pin which form is mounted at each width and that
/// the whole tree lays out without an exception.
void main() {
  testWidgets('wide host mounts the workspace toolbar and in-page header', (tester) async {
    await _pumpAt(
      tester,
      const Size(1400, 900),
      child: MainWorkspaceHost(
        child: MainPageFrame(
          title: '热门',
          tabs: const [
            PureTab(label: '全部'),
            PureTab(label: '斗鱼'),
          ],
          onTabChanged: (_) {},
          body: const ColoredBox(color: Color(0xFFF5F5F5), child: Text('BODY')),
        ),
      ),
    );

    expect(find.byType(MainWorkspaceBar), findsOneWidget);
    expect(find.byType(MainPageFrame), findsOneWidget);
    expect(find.text('热门'), findsOneWidget);
    expect(find.text('BODY'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone host falls back to the page app bar', (tester) async {
    await _pumpAt(
      tester,
      const Size(390, 844),
      child: MainWorkspaceHost(
        child: MainPageFrame(
          title: '热门',
          tabs: const [PureTab(label: '全部')],
          onTabChanged: (_) {},
          body: const ColoredBox(color: Color(0xFFF5F5F5), child: Text('BODY')),
        ),
      ),
    );

    expect(find.byType(MainWorkspaceBar), findsNothing);
    expect(find.byType(PureAppBar), findsOneWidget);
    expect(find.text('热门'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fluent tablet keeps the official nav drawer', (tester) async {
    await _pumpAt(
      tester,
      const Size(900, 900),
      child: PureAppShell(
        destinations: _destinations,
        selectedId: 'home',
        onSelected: (_) {},
        placement: PureShellPlacement.rail,
        leading: const MainSidebarBrand(),
        trailing: const ShellRailActions(),
        child: const ColoredBox(color: Color(0xFFF5F5F5), child: Text('PAGE')),
      ),
    );

    expect(find.byType(f2.FluentNavDrawer), findsOneWidget);
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('PureLive'), findsOneWidget);
    expect(find.text('PAGE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fluent desktop keeps the wide nav drawer', (tester) async {
    await _pumpAt(
      tester,
      const Size(1400, 900),
      child: PureAppShell(
        destinations: _destinations,
        selectedId: 'home',
        onSelected: (_) {},
        placement: PureShellPlacement.rail,
        leading: const MainSidebarBrand(),
        trailing: const ShellRailActions(),
        child: const ColoredBox(color: Color(0xFFF5F5F5), child: Text('PAGE')),
      ),
    );

    expect(find.byType(f2.FluentNavDrawer), findsOneWidget);
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('PureLive'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

const List<PureShellDestination> _destinations = <PureShellDestination>[
  PureShellDestination(id: 'home', label: '首页', icon: Icons.home_rounded),
  PureShellDestination(id: 'popular', label: '热门', icon: Icons.local_fire_department_rounded),
  PureShellDestination(id: 'areas', label: '分区', icon: Icons.apps_rounded),
];

/// Pumps [child] through the same host chain the app uses: PureTheme above
/// PureApp, which mounts FluentApp for this configuration.
Future<void> _pumpAt(WidgetTester tester, Size size, {required Widget child}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    PureConfigProvider(
      config: const UiConfig(language: PureDesignLanguage.fluent),
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
