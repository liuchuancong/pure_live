import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:live_uikit/styling.dart' show LiveNavBar, LiveNavBarItem, LiveScaffold;

import 'package:pure_live/app/shell/shell_destinations.dart';

/// The phone chrome: the three branches under a bottom bar.
final class MobileShell extends StatelessWidget {
  /// Wraps [navigationShell] in the phone chrome.
  const new({required this.navigationShell, super.key});

  /// The indexed stack of shell branches the router owns.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) => LiveScaffold(
    body: navigationShell,
    bottomBar: LiveNavBar(
      items: [for (final (:label, :icon) in shellDestinations(context)) LiveNavBarItem(label: label, icon: icon)],
      index: navigationShell.currentIndex,
      onChanged: _goBranch,
    ),
  );

  void _goBranch(int index) {
    final branch = ShellBranch.at(index);
    navigationShell.goBranch(branch.branchIndex, initialLocation: branch.branchIndex == navigationShell.currentIndex);
  }
}
