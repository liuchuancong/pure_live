import 'package:flutter/material.dart';
import 'package:flutter_adaptive_layout/flutter_adaptive_layout.dart';
import 'package:go_router/go_router.dart';

import 'package:pure_live/app/shell/shell_destinations.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';

/// The desktop chrome: a side rail whose labelling follows the window's
/// own width through `AdaptiveLayout` — icon-only while narrow, labelled
/// once there is room. Desktop windows resize; the chrome follows.
final class DesktopShell extends StatelessWidget {
  /// Wraps [navigationShell] in the desktop chrome.
  const new({required this.navigationShell, super.key});

  /// The indexed stack of shell branches the router owns.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) => AdaptiveLayout(
    mediumBuilder: (context, _) => _rail(context, labelled: false),
    largeBuilder: (context, _) => _rail(context, labelled: true),
  );

  Widget _rail(BuildContext context, {required bool labelled}) => Scaffold(
    body: Row(
      children: [
        SafeArea(
          child: NavigationRail(
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
  );

  void _goBranch(int index) => navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
}
