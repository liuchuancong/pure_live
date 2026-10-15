import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:live_uikit/styling.dart';

import 'package:pure_live/app/router.dart';

/// The form-factor shell around the app's navigation branches: a labelled left
/// rail on desktop and TV, a bottom navigation bar on touch. Both are
/// theme-painted from the resolved token and carry no page content of their
/// own — the branches render into the same [StatefulNavigationShell], so
/// switching form factor (a window resize, a TV build) never rebuilds a page.
class AdaptiveShell extends StatelessWidget {
  /// The shell over [navigationShell].
  const new({required this.navigationShell, super.key});

  /// The shell-managed navigation stack, one per branch.
  final StatefulNavigationShell navigationShell;

  static const List<({String label, IconData icon, IconData selectedIcon})> _destinations = [
    (label: '首页', icon: Icons.live_tv_outlined, selectedIcon: Icons.live_tv),
    (label: '关注', icon: Icons.favorite_border, selectedIcon: Icons.favorite),
    (label: '历史', icon: Icons.history_outlined, selectedIcon: Icons.history),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final environment = LiveEnvironmentScope.of(context);

    if (environment.mode == LiveLayoutMode.mobile) {
      return Scaffold(
        backgroundColor: theme.colors.bgLayout,
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          backgroundColor: theme.colors.bgContainer,
          indicatorColor: theme.colors.primary.withValues(alpha: 0.14),
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: navigationShell.goBranch,
          destinations: [
            for (final destination in AdaptiveShell._destinations)
              NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: destination.label,
              ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.colors.bgLayout,
      body: Row(
        children: [
          _NavRail(currentIndex: navigationShell.currentIndex, onSelected: navigationShell.goBranch),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}

class _NavRail extends StatelessWidget {
  const new({required this.currentIndex, required this.onSelected});

  final int currentIndex;
  final void Function(int index) onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final geometry = LiveEnvironmentScope.of(context).geometry;
    final railPadding = geometry.pagePadding * 0.5;

    return ColoredBox(
      color: theme.colors.bgContainer,
      child: SizedBox(
        width: 208,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(railPadding, railPadding, railPadding, railPadding * 0.5),
              child: Text('Pure Live', style: theme.text.title.copyWith(color: theme.colors.text)),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: railPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, destination) in AdaptiveShell._destinations.indexed)
                    LiveButton(
                      label: destination.label,
                      variant: currentIndex == index ? ButtonVariant.primary : ButtonVariant.ghost,
                      onPressed: () => onSelected(index),
                    ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: EdgeInsets.all(railPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LiveButton(
                    label: '设置',
                    variant: ButtonVariant.ghost,
                    onPressed: () => const SettingsRoute().push<void>(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
