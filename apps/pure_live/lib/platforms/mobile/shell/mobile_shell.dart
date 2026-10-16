import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:live_uikit/styling.dart' show LiveAppShell, LiveShellPlacement;

import 'package:pure_live/app/shell/shell_destinations.dart';

/// The phone chrome: the three branches under a bottom bar.
///
/// The shell is dispatched, not composed: it hands the destinations to the active
/// language and lets that library decide what a bottom strip is made of. The page
/// inside keeps its own frame, which is why there is no scaffold out here.
final class MobileShell extends StatelessWidget {
  /// Wraps [navigationShell] in the phone chrome.
  const new({required this.navigationShell, super.key});

  /// The indexed stack of shell branches the router owns.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) => LiveAppShell(
    destinations: shellDestinations(context),
    selectedId: ShellBranch.at(navigationShell.currentIndex).name,
    onSelected: _goBranch,
    placement: LiveShellPlacement.bottom,
    child: navigationShell,
  );

  void _goBranch(String id) {
    final branch = ShellBranch.fromId(id);
    navigationShell.goBranch(branch.branchIndex, initialLocation: branch.branchIndex == navigationShell.currentIndex);
  }
}
