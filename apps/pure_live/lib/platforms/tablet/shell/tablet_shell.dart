import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:pure_live/app/shell/shell_destinations.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The tablet chrome: the reference tablet's rail — destinations in a column
/// beside the content (3.x `HomeTabletView`'s `NavigationRail`), with the
/// settings entry pinned to the column's end.
final class TabletShell extends StatelessWidget {
  /// Wraps [navigationShell] in the tablet chrome.
  const new({required this.navigationShell, super.key});

  /// The indexed stack of shell branches the router owns.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) => PureAppShell(
    destinations: shellDestinations(context),
    selectedId: ShellBranch.at(navigationShell.currentIndex).name,
    onSelected: _goBranch,
    placement: PureShellPlacement.rail,
    trailing: const Padding(padding: EdgeInsets.only(bottom: 16), child: SettingsEntryButton()),
    child: navigationShell,
  );

  void _goBranch(String id) {
    final branch = ShellBranch.fromId(id);
    navigationShell.goBranch(branch.branchIndex, initialLocation: branch.branchIndex == navigationShell.currentIndex);
  }
}
