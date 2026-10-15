import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:live_platform/live_platform.dart' show FormFactor;

import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/router/routes/settings_routes.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';

/// The navigation chrome around the shell branches: a left rail on desktop
/// and TV, a bottom bar under touch.
///
/// Only the chrome swaps — every branch is the same indexed stack in every
/// form factor, so state survives a form-factor change and a page never
/// learns which chrome is showing it. The TV's top focus row and the remote-
/// input wrapping join when the TV wave lands; the platform rail is the
/// honest minimum until then.
final class AppShell extends ConsumerWidget {
  /// Wraps [navigationShell] in the form factor's chrome.
  const new({required this.navigationShell, super.key});

  /// The indexed stack of shell branches the router owns.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useRail = switch (ref.watch(environmentProvider).runtime.formFactor) {
      FormFactor.desktop || FormFactor.tv => true,
      FormFactor.phone || FormFactor.tablet => false,
    };
    final destinations = [
      (label: context.t.tabs.home, icon: Icons.home_outlined),
      (label: context.t.tabs.follow, icon: Icons.favorite_border),
      (label: context.t.tabs.history, icon: Icons.history),
    ];
    if (useRail) {
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              child: NavigationRail(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: _goBranch,
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final (:label, :icon) in destinations)
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
    }
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _goBranch,
        destinations: [
          for (final (:label, :icon) in destinations) NavigationDestination(icon: Icon(icon), label: label),
        ],
      ),
    );
  }

  void _goBranch(int index) => navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
}

/// The chrome's way into settings: the rail's trailing corner on desktop,
/// the page app bars under touch. A push, not a branch switch — the route
/// is a full page above the shell.
final class SettingsEntryButton extends StatelessWidget {
  /// The settings entry.
  const new({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    icon: const Icon(Icons.settings_outlined),
    tooltip: context.t.tabs.settings,
    onPressed: () => const SettingsRoute().push<void>(context),
  );
}
