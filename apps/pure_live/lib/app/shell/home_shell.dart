import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show StatefulNavigationShell;
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/app/shell/home_views.dart';
import 'package:pure_live/app/shell/shell_destinations.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The home shell, in the reference's shape (v5 `HomePage`): a bottom bar
/// below [homeRailBreakpoint], an 80px side rail from it, the same
/// destinations on both, and nothing else — no brand column, no drawer, no
/// global toolbar. The decision is width-only: a landscape phone crosses
/// onto the rail, a narrow desktop window drops to the bar.
///
/// The window's caption is not the shell's business: the app-level
/// `DesktopTitleFrame` draws it once above the whole navigator, so pushed
/// pages keep the strip (the reference frames the app, not the home page).
final class HomeShell extends ConsumerWidget {
  /// Wraps [navigationShell] in the shell chrome.
  const new({required this.navigationShell, super.key});

  /// The indexed stack of shell branches the router owns.
  final StatefulNavigationShell navigationShell;

  void _select(BuildContext context, WidgetRef ref, ShellBranch branch) {
    goShellBranch(ref, navigationShell, branch.name);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rail = isHomeRailWidth(constraints.maxWidth);
        final branches = ref.watch(visibleShellBranchesProvider);
        final current = ShellBranch.at(navigationShell.currentIndex);
        // A removed or hidden destination falls back to the first one.
        final selected = branches.contains(current) ? current : branches.first;
        final body = HomeLayoutScope(
          phone: !rail,
          child: PopScope(
            // Android's back on the home page sends the app to the
            // background (the reference's moveToBack).
            canPop: !Platform.isAndroid,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && Platform.isAndroid) unawaited(SystemNavigator.pop());
            },
            child: navigationShell,
          ),
        );
        if (rail) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  // The rail scrolls in short windows; its position must not
                  // attach to the page's primary scroll controller.
                  PrimaryScrollController.none(
                    child: Material(
                      key: const ValueKey('home-rail'),
                      color: PureTheme.of(context).colors.bgElevated,
                      child: SizedBox(
                        width: HomeRailMetrics.width,
                        child: FocusTraversalGroup(
                          child: HomeRail(
                            branches: branches,
                            selected: selected,
                            onSelected: (branch) => _select(context, ref, branch),
                          ),
                        ),
                      ),
                    ),
                  ),
                  VerticalDivider(width: 1, color: PureTheme.of(context).colors.border),
                  Expanded(child: body),
                ],
              ),
            ),
          );
        }
        if (branches.length <= 1) return Scaffold(body: body);
        return Scaffold(
          bottomNavigationBar: PureBottomNavigation(
            destinations: [
              for (final branch in branches)
                PureNavDestination(
                  id: branch.name,
                  label: branch.label(context),
                  icon: branch.icon,
                ),
            ],
            selectedId: selected.name,
            onDestinationSelected: (destination) =>
                _select(context, ref, ShellBranch.fromId(destination.id)),
          ),
          body: body,
        );
      },
    );
  }
}
