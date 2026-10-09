// Module: lib/features/shell/app_shell.dart
// Purpose: Responsive navigation chrome: bottom bar on phones, rail on wide
// screens and TV.
// Author: liuchuancong
// Created: 2026-10-09

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Width at which the bottom bar gives way to a navigation rail.
const double _railBreakpoint = 900;

/// Width at which the rail shows labels permanently instead of on selection.
const double _extendedRailBreakpoint = 1280;

final class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width >= _railBreakpoint) {
          return _RailShell(navigationShell: navigationShell, onDestinationSelected: _goBranch);
        }
        return _BarShell(navigationShell: navigationShell, onDestinationSelected: _goBranch);
      },
    );
  }
}

final class _BarShell extends StatelessWidget {
  const _BarShell({required this.navigationShell, required this.onDestinationSelected});

  final StatefulNavigationShell navigationShell;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: const <Widget>[
          NavigationDestination(icon: Icon(Icons.live_tv_outlined), selectedIcon: Icon(Icons.live_tv), label: '首页'),
          NavigationDestination(icon: Icon(Icons.favorite_outline), selectedIcon: Icon(Icons.favorite), label: '关注'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}

final class _RailShell extends StatelessWidget {
  const _RailShell({required this.navigationShell, required this.onDestinationSelected});

  final StatefulNavigationShell navigationShell;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      body: Row(
        children: <Widget>[
          NavigationRail(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: onDestinationSelected,
            extended: width >= _extendedRailBreakpoint,
            labelType: width >= _extendedRailBreakpoint ? null : NavigationRailLabelType.all,
            destinations: const <NavigationRailDestination>[
              NavigationRailDestination(
                icon: Icon(Icons.live_tv_outlined),
                selectedIcon: Icon(Icons.live_tv),
                label: Text('首页'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.favorite_outline),
                selectedIcon: Icon(Icons.favorite),
                label: Text('关注'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('设置'),
              ),
            ],
          ),
          VerticalDivider(thickness: 1, width: 1),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}
