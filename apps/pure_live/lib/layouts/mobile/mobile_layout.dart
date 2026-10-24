import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart';

import 'package:pure_live/app/navigation/module_navigation.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/layouts/app_switcher.dart';
import 'package:pure_live/shared/enums/app_module.dart';
import 'package:pure_live/shared/enums/navigation_item.dart';

/// The width the navigation drawer opens to.
const double kNavigationDrawerWidth = 320;

/// The mobile layout: the content under a slim top bar whose menu button
/// opens the navigation drawer — the same navigation the desktop sidebar
/// shows (the app switcher, the module's business menu, the shared tools,
/// settings last), not a compressed sidebar.
///
/// The drawer closes on a selection; a destination whose page has not
/// arrived yet still closes it, so the drawer never hangs open on a dead
/// tap.
final class MobileLayout extends StatelessWidget {
  /// A mobile layout over [content].
  const MobileLayout({
    required this.content,
    required this.module,
    required this.selected,
    required this.onSelected,
    required this.onModuleSelected,
    super.key,
  });

  /// The current screen.
  final Widget content;

  /// The module whose navigation the drawer shows.
  final AppModule module;

  /// The selected destination.
  final NavigationItem selected;

  /// Fired when the viewer picks a destination.
  final ValueChanged<NavigationItem> onSelected;

  /// Fired when the app switcher picks a module.
  final ValueChanged<AppModule> onModuleSelected;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: colors.surface,
        surfaceTintColor: const Color(0x00000000),
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: t.common.openNavigation,
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: DsIcon(DsIcons.menu, size: 20, color: colors.text),
          ),
        ),
        title: Text(
          t.common.appTitle,
          style: theme.typography.title.copyWith(color: colors.text),
        ),
        centerTitle: false,
      ),
      drawer: Builder(
        builder: (context) {
          void pick(NavigationItem item) {
            Scaffold.of(context).closeDrawer();
            onSelected(item);
          }

          return Drawer(
            width: kNavigationDrawerWidth,
            backgroundColor: colors.sidebar,
            surfaceTintColor: const Color(0x00000000),
            elevation: 0,
            shape: const RoundedRectangleBorder(),
            child: SafeArea(
              child: DsSidebar(
                header: AppSwitcher(module: module, onModule: onModuleSelected),
                value: selected,
                onChanged: pick,
                style: const DsSidebarStyle(width: kNavigationDrawerWidth),
                children: [
                  for (final item in navigationOf(module).business)
                    DsSidebarItem(value: item, leading: DsIcon(item.icon), label: Text(item.label(t))),
                  const SidebarDivider(),
                  for (final item in navigationOf(module).tools)
                    DsSidebarItem(value: item, leading: DsIcon(item.icon), label: Text(item.label(t))),
                  const SidebarDivider(),
                  DsSidebarItem(
                    value: NavigationItem.settings,
                    leading: const DsIcon(DsIcons.settings),
                    label: Text(t.navigation.settings),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      body: content,
    );
  }
}
