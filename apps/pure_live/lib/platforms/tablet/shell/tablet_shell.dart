import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:pure_live/app/shell/shell_destinations.dart';

/// The tablet chrome. Touch first, so a bottom strip today; a compact rail
/// arrives with the tablet layout pass if the landscape grid wants one.
final class TabletShell extends StatelessWidget {
  /// Wraps [navigationShell] in the tablet chrome.
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
