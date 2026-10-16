import 'package:flutter/material.dart';
import 'package:flutter_adaptive_layout/flutter_adaptive_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:live_uikit/styling.dart' show LiveScaffold;

import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/shell/shell_destinations.dart';
import 'package:pure_live/platforms/desktop/shell/shell_preferences.dart' show ShellWindowChrome;
import 'package:pure_live/platforms/desktop/shell/window_title_bar.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';

/// The desktop chrome: the app's caption strip over a side rail whose
/// labelling follows the window's own width through `AdaptiveLayout` —
/// icon-only while narrow, labelled once there is room. Desktop windows
/// resize; the chrome follows.
final class DesktopShell extends ConsumerWidget {
  /// Wraps [navigationShell] in the desktop chrome.
  const new({required this.navigationShell, super.key});

  /// The indexed stack of shell branches the router owns.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selfDrawn = ref.watch(windowChromeProvider) == ShellWindowChrome.app;
    return AdaptiveLayout(
      mediumBuilder: (context, _) => _scaffold(context, selfDrawn: selfDrawn, labelled: false),
      largeBuilder: (context, _) => _scaffold(context, selfDrawn: selfDrawn, labelled: true),
    );
  }

  Widget _scaffold(BuildContext context, {required bool selfDrawn, required bool labelled}) => LiveScaffold(
    body: Column(
      children: [
        // The strip exists only when this start was set up for it: the frame
        // takeover is configured before the window exists, so a mid-session
        // flip would leave a Flutter strip over an OS caption.
        if (selfDrawn) const WindowTitleBar(),
        Expanded(
          child: Row(
            children: [
              SafeArea(
                child: NavigationRail(
                  // A Material rail for now: `LiveNavBar` is the bottom-bar
                  // dispatch, so the vertical rail has no dispatched form yet.
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: _goBranch,
                  labelType: labelled ? NavigationRailLabelType.all : NavigationRailLabelType.none,
                  destinations: [
                    for (final (:label, :icon) in shellDestinations(context))
                      NavigationRailDestination(icon: Icon(icon), label: Text(label)),
                  ],
                  trailing: const Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(padding: EdgeInsets.only(bottom: 16), child: SettingsEntryButton()),
                    ),
                  ),
                ),
              ),
              Expanded(child: navigationShell),
            ],
          ),
        ),
      ],
    ),
  );

  void _goBranch(int index) {
    final branch = ShellBranch.at(index);
    navigationShell.goBranch(branch.branchIndex, initialLocation: branch.branchIndex == navigationShell.currentIndex);
  }
}
