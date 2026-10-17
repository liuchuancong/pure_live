import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/app/shell/shell_destinations.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The phone chrome: the three branches under a bottom bar.
///
/// The shell is dispatched, not composed: it hands the destinations to the active
/// language and lets that library decide what a bottom strip is made of. The page
/// inside keeps its own frame, which is why there is no scaffold out here.
final class MobileShell extends ConsumerWidget {
  /// Wraps [navigationShell] in the phone chrome.
  const new({required this.navigationShell, super.key});

  /// The indexed stack of shell branches the router owns.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PureAppShell(
    destinations: shellDestinations(context, branches: ref.watch(visibleShellBranchesProvider)),
    selectedId: ShellBranch.at(navigationShell.currentIndex).name,
    onSelected: (id) => goShellBranch(ref, navigationShell, id),
    placement: PureShellPlacement.bottom,
    child: navigationShell,
  );
}
