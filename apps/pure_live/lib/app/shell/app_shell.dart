import 'package:flutter/material.dart';
import 'package:flutter_adaptive_layout/flutter_adaptive_layout.dart';
import 'package:go_router/go_router.dart';

import 'package:pure_live/app/routing/routes/settings_routes.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';

/// The navigation chrome around the shell branches, driven by the window's
/// own size through `AdaptiveLayout`: a bottom bar on small screens, an
/// icon-only rail on medium and a labelled rail on large.
///
/// Only the chrome swaps — every branch is the same indexed stack in every
/// size, so state survives a window resize and a page never learns which
/// chrome is showing it. The device form factor (a TV build's focus
/// treatment, the remote-input wrapping) is a separate axis and joins with
/// the TV wave; the sized chrome is the honest minimum.
final class AppShell extends StatelessWidget {
  /// Wraps [navigationShell] in the size's chrome.
  const new({required this.navigationShell, super.key});

  /// The indexed stack of shell branches the router owns.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) => AdaptiveLayout(
    smallBuilder: (context, _) => _BottomBarShell(navigationShell: navigationShell),
    mediumBuilder: (context, _) => _RailShell(navigationShell: navigationShell, labelled: false),
    largeBuilder: (context, _) => _RailShell(navigationShell: navigationShell, labelled: true),
  );

  static List<({String label, IconData icon})> _destinations(BuildContext context) => [
    (label: context.t.tabs.home, icon: Icons.home_outlined),
    (label: context.t.tabs.follow, icon: Icons.favorite_border),
    (label: context.t.tabs.history, icon: Icons.history),
  ];
}

/// The small-screen chrome: the three branches under a bottom bar.
final class _BottomBarShell extends StatelessWidget {
  const new({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: navigationShell,
    bottomNavigationBar: NavigationBar(
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: _goBranch,
      destinations: [
        for (final (:label, :icon) in AppShell._destinations(context))
          NavigationDestination(icon: Icon(icon), label: label),
      ],
    ),
  );

  void _goBranch(int index) => navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
}

/// The medium and large chrome: a side rail, icon-only or labelled.
final class _RailShell extends StatelessWidget {
  const new({required this.navigationShell, required this.labelled});

  final StatefulNavigationShell navigationShell;

  /// Whether the rail carries text labels; medium stays icon-only.
  final bool labelled;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Row(
      children: [
        SafeArea(
          child: NavigationRail(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _goBranch,
            labelType: labelled ? NavigationRailLabelType.all : NavigationRailLabelType.none,
            destinations: [
              for (final (:label, :icon) in AppShell._destinations(context))
                NavigationRailDestination(icon: Icon(icon), label: Text(label)),
            ],
            trailing: const Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(padding: EdgeInsets.only(bottom: 16), child: SettingsEntryButton()),
              ),
            ),
          ),
        ),
        Expanded(child: navigationShell),
      ],
    ),
  );

  void _goBranch(int index) => navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
}

/// The chrome's way into settings: the rail's trailing corner on desktop,
/// the page app bars under touch. A push, not a branch switch — the route
/// is a full page above the shell.
final class SettingsEntryButton extends StatelessWidget {
  /// The settings entry.
  const new({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    icon: const Icon(Icons.settings_outlined),
    tooltip: context.t.tabs.settings,
    onPressed: () => const SettingsRoute().push<void>(context),
  );
}
