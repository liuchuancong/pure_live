import 'package:flutter/widgets.dart' show BuildContext;
import 'package:flutter_riverpod/flutter_riverpod.dart' show WidgetRef;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:pure_live/app/routing/route_names.dart' show RouteNames;
import 'package:pure_live/app/shell/navigation/navigation_item.dart' show NavigationItem;
import 'package:pure_live/app/shell/navigation/navigation_state.dart' show selectedBranchProvider;

/// The shell's actions: the verbs a navigation control fires, kept out of
/// the widgets so a rail, a bar and a set of TV pills all behave the same.
final class ShellController {
  /// An action set over [ref] and the widget [context] that fired it.
  const new({required this.ref, required this.context});

  /// The ref the caller's widget holds, for reading providers.
  final WidgetRef ref;

  /// The context the verb fires from; the router reads routes off it.
  final BuildContext context;

  /// Jumps to a branch; tapping the already-selected branch pops it back to
  /// its root instead of doing nothing.
  void select(NavigationItem item) {
    ref.read(selectedBranchProvider.notifier).selected = item;
    context.go(item.route);
  }

  /// Opens the search branch — the title bar's field and the phone's bar
  /// both land here.
  void openSearch() {
    ref.read(selectedBranchProvider.notifier).selected = NavigationItem.search;
    context.go(RouteNames.search);
  }
}
