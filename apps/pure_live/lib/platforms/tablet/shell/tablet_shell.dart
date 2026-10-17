import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/app/shell/shell_destinations.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The tablet chrome: the reference tablet's rail — destinations in a column
/// beside the content (3.x `HomeTabletView`'s `NavigationRail`), with the
/// settings entry pinned to the column's end.
final class TabletShell extends ConsumerWidget {
  /// Wraps [navigationShell] in the tablet chrome.
  const new({required this.navigationShell, super.key});

  /// The indexed stack of shell branches the router owns.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PureAppShell(
    destinations: shellDestinations(context, branches: ref.watch(visibleShellBranchesProvider)),
    selectedId: ShellBranch.at(navigationShell.currentIndex).name,
    onSelected: (id) => goShellBranch(ref, navigationShell, id),
    placement: PureShellPlacement.rail,
    trailing: const Padding(padding: EdgeInsets.only(bottom: 16), child: SettingsEntryButton()),
    child: navigationShell,
  );
}
