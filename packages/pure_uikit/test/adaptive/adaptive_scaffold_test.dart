import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_uikit/pure_uikit.dart';

const _destinations = <PureNavDestination>[
  PureNavDestination(
    id: 'home',
    label: 'Home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
  ),
  PureNavDestination(
    id: 'live',
    label: 'Live',
    icon: Icons.live_tv_outlined,
    selectedIcon: Icons.live_tv_rounded,
  ),
  PureNavDestination(
    id: 'settings',
    label: 'Settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings_rounded,
  ),
];

Widget _harness({
  bool television = false,
  PureCompactNavigationStyle compactStyle = PureCompactNavigationStyle.bottomBar,
  ValueChanged<PureNavDestination>? onSelected,
  bool withDrawer = false,
}) {
  return PureConfigProvider(
    config: const UiConfig(language: PureDesignLanguage.material),
    child: MaterialApp(
      home: AdaptiveScaffold(
        destinations: _destinations,
        compactDestinations: _destinations,
        selectedId: 'home',
        onDestinationSelected: onSelected ?? (destination) {},
        compactNavigation: compactStyle,
        isTelevision: television,
        accountSubtitle: 'Sync your follows and settings',
        drawer: withDrawer
            ? PureNavigationDrawer(
                destinations: _destinations,
                selectedId: 'home',
                onDestinationSelected: onSelected ?? (destination) {},
                accountSubtitle: 'Sync your follows and settings',
              )
            : null,
        body: const ColoredBox(color: Colors.white, child: SizedBox.expand()),
      ),
    ),
  );
}

Future<void> _setSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('compact width uses the bottom navigation', (tester) async {
    await _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.byType(PureBottomNavigation), findsOneWidget);
    expect(find.byType(PureNavigationRail), findsNothing);
    expect(find.byType(DesktopNavigation), findsNothing);
  });

  testWidgets('medium width uses the icon rail', (tester) async {
    await _setSize(tester, const Size(800, 900));
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.byType(PureNavigationRail), findsOneWidget);
    expect(find.byType(PureBottomNavigation), findsNothing);
    expect(find.byType(DesktopNavigation), findsNothing);
  });

  testWidgets('expanded width uses the labelled desktop sidebar', (tester) async {
    await _setSize(tester, const Size(1280, 900));
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.byType(DesktopNavigation), findsOneWidget);
    expect(find.byType(PureNavigationRail), findsNothing);
    expect(find.byType(PureBottomNavigation), findsNothing);
  });

  testWidgets('television flag switches to TV navigation', (tester) async {
    await _setSize(tester, const Size(1280, 900));
    await tester.pumpWidget(_harness(television: true));
    await tester.pumpAndSettle();

    expect(find.byType(PureTvNavigation), findsOneWidget);
    expect(find.byType(DesktopNavigation), findsNothing);
  });

  testWidgets('compact drawer style opens the default drawer', (tester) async {
    await _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(_harness(compactStyle: PureCompactNavigationStyle.drawer));
    await tester.pumpAndSettle();

    expect(find.byType(PureBottomNavigation), findsNothing);
    expect(find.byType(PureNavigationDrawer), findsNothing);

    await tester.tap(find.byTooltip('Open navigation'));
    await tester.pumpAndSettle();

    expect(find.byType(PureNavigationDrawer), findsOneWidget);
    expect(find.text('Sync your follows and settings'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.byType(PureNavigationDrawer), findsNothing);
  });

  testWidgets('bottom bar selection reports the destination', (tester) async {
    await _setSize(tester, const Size(390, 844));
    PureNavDestination? selected;

    await tester.pumpWidget(
      _harness(
        onSelected: (destination) {
          selected = destination;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Live'));
    await tester.pumpAndSettle();

    expect(selected?.id, 'live');
  });

  testWidgets('drawer menu button only appears when a drawer exists', (tester) async {
    await _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.byTooltip('Open navigation'), findsNothing);

    await tester.pumpWidget(_harness(withDrawer: true));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Open navigation'), findsOneWidget);
  });
}
