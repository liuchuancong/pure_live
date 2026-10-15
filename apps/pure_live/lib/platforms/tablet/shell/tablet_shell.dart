import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:pure_live/app/shell/shell_destinations.dart';

/// The tablet chrome. Touch first, so a bottom bar today; a compact rail
/// arrives with the tablet layout pass if the landscape grid wants one.
final class TabletShell extends StatelessWidget {
  /// Wraps [navigationShell] in the tablet chrome.
  const new({required this.navigationShell, super.key});

  /// The indexed stack of shell branches the router owns.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: navigationShell,
    bottomNavigationBar: NavigationBar(
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: _goBranch,
      destinations: [
        for (final (:label, :icon) in shellDestinations(context)) NavigationDestination(icon: Icon(icon), label: label),
      ],
    ),
  );

  void _goBranch(int index) => navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
}
