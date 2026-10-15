import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:pure_live/app/shell/shell_destinations.dart';

/// The TV chrome: a labelled rail the D-pad walks top to bottom. The focus
/// row, the remote-input wrapping and the overscan-safe padding join with
/// the TV wave; the navigable minimum is honest until then.
final class TvShell extends StatelessWidget {
  /// Wraps [navigationShell] in the TV chrome.
  const new({required this.navigationShell, super.key});

  /// The indexed stack of shell branches the router owns.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Row(
      children: [
        NavigationRail(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _goBranch,
          labelType: NavigationRailLabelType.all,
          destinations: [
            for (final (:label, :icon) in shellDestinations(context))
              NavigationRailDestination(icon: Icon(icon), label: Text(label)),
          ],
        ),
        Expanded(child: navigationShell),
      ],
    ),
  );

  void _goBranch(int index) {
    final branch = ShellBranch.at(index);
    navigationShell.goBranch(branch.branchIndex, initialLocation: branch.branchIndex == navigationShell.currentIndex);
  }
}
