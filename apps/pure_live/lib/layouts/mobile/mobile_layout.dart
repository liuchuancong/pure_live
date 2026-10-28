import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_platform/live_platform.dart' show PlatformKind;

import 'package:pure_live/app/app.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/layouts/app_switcher.dart';
import 'package:pure_live/layouts/desktop/title_bar.dart' show WindowCaptionBar;
import 'package:pure_live/layouts/mobile/liquid_glass.dart';
import 'package:pure_live/shared/shared.dart';

/// The width the navigation drawer opens to.
const double kNavigationDrawerWidth = 320;

/// The mobile layout: the content under a slim top bar whose menu button
/// opens the navigation drawer — the same navigation the desktop sidebar
/// shows (the app switcher, the module's menu in its blocks with a divider
/// between them, settings last), not a compressed sidebar.
///
/// The drawer closes on a selection; a destination whose page has not
/// arrived yet still closes it, so the drawer never hangs open on a dead
/// tap.
final class MobileLayout extends ConsumerWidget {
  /// A mobile layout over [content].
  const MobileLayout({
    required this.content,
    required this.module,
    required this.selected,
    required this.onSelected,
    required this.onModuleSelected,
    required this.onSearch,
    this.showMultiview = true,
    this.homeMenuItems = kHomeMenuItems,
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

  /// Opens the search destination — the top bar's magnifier.
  final VoidCallback onSearch;

  /// Whether the drawer lists the multi-view entry (the navigation
  /// setting's toggle, shared with the desktop sidebar).
  final bool showMultiview;

  /// The live home menu's visible entries in the viewer's order (the
  /// navigation setting's `nav.menuIds`); other modules keep their own tabs.
  final List<NavigationItem> homeMenuItems;

  /// The bar's destinations: the module's feeds plus settings, the shape a
  /// phone's tab bar takes in every common client. Live follows the
  /// navigation setting's saved menu, the recording centre included.
  List<NavigationItem> bottomTabsOf(AppModule module) => switch (module) {
    AppModule.live => [if (homeMenuItems.isEmpty) ...kHomeMenuItems else ...homeMenuItems, NavigationItem.settings],
    AppModule.iptv => const [
      NavigationItem.channels,
      NavigationItem.iptvGuide,
      NavigationItem.iptvSources,
      NavigationItem.favorites,
      NavigationItem.settings,
    ],
    AppModule.vod => const [
      NavigationItem.vod,
      NavigationItem.vodRank,
      NavigationItem.vodRegions,
      NavigationItem.history,
      NavigationItem.settings,
    ],
    AppModule.music => const [
      NavigationItem.music,
      NavigationItem.musicSonglist,
      NavigationItem.musicToplist,
      NavigationItem.musicLibrary,
      NavigationItem.settings,
    ],
  };

  /// The top bar's title: the page on screen, not the app's name (the
  /// drawer's head already carries the name). The settings list is the
  /// settings surface; its categories and sections are pushed routes with
  /// their own headers.
  String _title(Translations t) => selected == NavigationItem.settings ? t.navigation.settings : selected.label(t);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    // The wallpaper sits below the Scaffold; its surface steps aside so the
    // picture is visible, and the app bar and drawer turn glass.
    final wallpaper = BackgroundActiveScope.isActiveOf(context);
    final chrome = wallpaper ? colors.surface.withValues(alpha: 0.82) : colors.surface;
    final rail = wallpaper ? colors.sidebar.withValues(alpha: 0.86) : colors.sidebar;
    // The bar's highlight: a deep page (search, history, a tool) sits on
    // its module's first tab, so the bar always says where the app is.
    final tabs = bottomTabsOf(module);
    final current = tabs.contains(selected)
        ? selected
        : selected == NavigationItem.settings
        ? NavigationItem.settings
        : tabs.first;
    // Liquid glass (A01.5, the reference's `liquidGlass`): on the phone
    // shell the bottom bar floats over the page as a frosted capsule and
    // the page scrolls visibly under it; off keeps the full-width bar.
    final glass = ref.watch(liquidGlassProvider);
    final glassBlur = liquidGlassBlurs(
      android: ref.watch(platformKindProvider) == PlatformKind.android,
      memoryMegabytes: ref.watch(deviceMemoryMegabytesProvider).value,
    );
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    final navBar = DsBottomNav<NavigationItem>(
      variant: DsBottomNavVariant.bar,
      // The capsule behind the floating bar does the painting; the bar
      // itself turns clear so the glass shows through it.
      style: glass ? const DsBottomNavStyle(background: Color(0x00000000)) : null,
      value: current,
      onChanged: onSelected,
      items: [
        for (final item in tabs)
          DsBottomNavItem<NavigationItem>(
            value: item,
            icon: DsIcon(item.icon),
            label: Text(item.label(t)),
            semanticLabel: item.label(t),
          ),
      ],
    );
    // The window's own strip first: on Windows the caption is hidden at
    // creation (seamless self-drawn), so a narrow window still needs the
    // drag band and the window controls — without this strip a small
    // window could not be moved or closed by its own chrome.
    final scaffold = Scaffold(
      extendBody: glass,
      backgroundColor: wallpaper ? const Color(0x00000000) : colors.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: chrome,
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
          _title(t),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.typography.title.copyWith(color: colors.text),
        ),
        centerTitle: false,
        actions: [
          // The two every client pins to its top bar: search and the
          // light/dark switch. They stay reachable on every page, so the
          // drawer can stay shut.
          ChromeIconButton(
            size: 48,
            iconSize: 20,
            icon: DsIcons.search,
            semanticLabel: t.navigation.search,
            tooltip: t.navigation.search,
            onPressed: onSearch,
          ),
          // A window strip above this bar already carries the switch; two
          // moons stacked on a narrow desktop window would be one too many.
          if (!WindowChromeState.drawsStrip) const ThemeModeToggle(size: 48, iconSize: 20),
          const SizedBox(width: DsSpace.s4),
        ],
      ),
      bottomNavigationBar: glass
          ? Padding(
              key: const ValueKey('home-glass-bar'),
              padding: EdgeInsets.fromLTRB(
                LiquidGlassMetrics.barMargin,
                0,
                LiquidGlassMetrics.barMargin,
                safeBottom + LiquidGlassMetrics.barMargin,
              ),
              child: LiquidGlassPane(
                blur: glassBlur,
                // The capsule's safe area sits outside it; the bar keeps
                // the system's gesture strip to itself.
                child: MediaQuery.removePadding(context: context, removeTop: true, removeBottom: true, child: navBar),
              ),
            )
          : navBar,
      drawer: Builder(
        builder: (context) {
          void pick(NavigationItem item) {
            Scaffold.of(context).closeDrawer();
            onSelected(item);
          }

          return Drawer(
            width: kNavigationDrawerWidth,
            backgroundColor: rail,
            surfaceTintColor: const Color(0x00000000),
            elevation: 0,
            shape: const RoundedRectangleBorder(),
            child: SafeArea(
              child: DsSidebar(
                header: AppSwitcher(module: module, onModule: onModuleSelected),
                value: selected,
                onChanged: pick,
                // The Drawer's own glass is the slab; a second translucent
                // fill here would stack into an opaque one.
                style: DsSidebarStyle(
                  width: kNavigationDrawerWidth,
                  background: wallpaper ? const Color(0x00000000) : null,
                ),
                children: [
                  // The module's menu, block by block; a divider separates
                  // the blocks (the live module reads the reference's rail
                  // block for block). Settings follows under its own divider.
                  for (final (index, group) in navigationOf(module).menu.indexed) ...[
                    if (index > 0) const SidebarDivider(),
                    // Live's home block is the navigation setting's list:
                    // membership and order, not the registry's fixed order.
                    for (final item
                        in module == AppModule.live && group.every(kHomeMenuItems.contains)
                            ? (homeMenuItems.isEmpty ? kHomeMenuItems : homeMenuItems)
                            : group)
                      if (showMultiview || item != NavigationItem.multiview)
                        DsSidebarItem(value: item, leading: DsIcon(item.icon), label: Text(item.label(t))),
                  ],
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
      body: glass
          ? MediaQuery(
              // Scrolled content must be able to clear the floating capsule
              // (the reference's GlassBarInset): the bar's reach plus the
              // system strip, handed down as the bottom padding pages add.
              data: MediaQuery.of(context).copyWith(
                padding: MediaQuery.of(context).padding.copyWith(bottom: safeBottom + LiquidGlassMetrics.barOverlap),
              ),
              child: content,
            )
          : content,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (WindowChromeState.drawsStrip) const WindowCaptionBar(),
        Expanded(child: scaffold),
      ],
    );
  }
}
