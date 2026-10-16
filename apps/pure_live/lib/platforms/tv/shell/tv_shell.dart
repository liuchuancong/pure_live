import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:pure_live/app/shell/shell_destinations.dart';

/// The TV chrome: a labelled rail the D-pad walks top to bottom.
///
/// The rail is asked for explicitly rather than left to `adaptive`: the 10-foot
/// geometry reports no rail width, because a television's navigation is a wide
/// horizontal strip, and this start wants the column. The focus traversal, the
/// remote-input wrapping and the overscan-safe padding join with the TV wave; the
/// navigable minimum is honest until then.
final class TvShell extends StatelessWidget {
  /// Wraps [navigationShell] in the TV chrome.
  const new({required this.navigationShell, super.key});

  /// The indexed stack of shell branches the router owns.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) => LiveAppShell(
    destinations: shellDestinations(context),
    selectedId: ShellBranch.at(navigationShell.currentIndex).name,
    onSelected: _goBranch,
    placement: LiveShellPlacement.rail,
    child: navigationShell,
  );

  void _goBranch(String id) {
    final branch = ShellBranch.fromId(id);
    navigationShell.goBranch(branch.branchIndex, initialLocation: branch.branchIndex == navigationShell.currentIndex);
  }
}
