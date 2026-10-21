import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/app/shell/shell_actions.dart' show activateShellDestination;
import 'package:pure_live/app/shell/shell_destinations.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The TV chrome: a labelled rail the D-pad walks top to bottom — the same
/// destination column the desktop sidebar draws (tabs, then the content
/// tools, then the system entries), under the brand mark.
///
/// The rail is asked for explicitly rather than left to `adaptive`: the 10-foot
/// geometry reports no rail width, because a television's navigation is a wide
/// horizontal strip, and this start wants the column. The focus traversal, the
/// remote-input wrapping and the overscan-safe padding join with the TV wave; the
/// navigable minimum is honest until then.
final class TvShell extends ConsumerWidget {
  /// Wraps [navigationShell] in the TV chrome.
  const new({required this.navigationShell, super.key});

  /// The indexed stack of shell branches the router owns.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PureAppShell(
    destinations: shellTvDestinations(context, branches: ref.watch(visibleShellBranchesProvider)),
    selectedId: ShellBranch.at(navigationShell.currentIndex).name,
    onSelected: (id) => activateShellDestination(context, ref: ref, navigationShell: navigationShell, id: id),
    leading: const Padding(padding: EdgeInsets.only(top: 12, bottom: 4), child: AdaptiveBrandMark(size: 32)),
    placement: PureShellPlacement.rail,
    child: navigationShell,
  );
}
