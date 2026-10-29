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
/// The bottom bar carries the module's feeds only. A page entered below
/// those feeds — multi-view, a tool, the settings surface — turns the top
/// bar's leading into a back arrow, names the whole path as a breadcrumb
/// and puts the bottom bar away, so the bar never sits under a page it does
/// not lead to. The drawer lists what the bottom bar does not.
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
    required this.breadcrumb,
    required this.canBack,
    required this.onBack,
    this.homeMenuItems = kHomeMenuItems,
    this.badges = const {},
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

  /// The where-am-I path the top bar shows on a page below the bar's tabs.
  final Widget breadcrumb;

  /// Whether there is a destination behind the one on screen.
  final bool canBack;

  /// Fired by the top bar's back arrow.
  final VoidCallback onBack;

  /// The live home menu's visible entries in the viewer's order (the
  /// navigation setting's list); other modules keep their own tabs.
  final List<NavigationItem> homeMenuItems;

  /// Count badges the drawer's rows show at their end, keyed by
  /// destination — the hongguo shelf's new episodes, for now. The bottom
  /// bar has no badge slot; a destination missing here shows none.
  final Map<NavigationItem, int> badges;

  /// The bar's destinations: the module's feeds, the shape a phone's tab
  /// bar takes in every common client. Live follows the navigation
  /// setting's saved menu, the recording centre included. Settings is not a
  /// tab: it opens from the drawer and steps back from its own top bar.
  List<NavigationItem> bottomTabsOf(AppModule module) => switch (module) {
    AppModule.live => homeMenuItems.isEmpty ? kHomeMenuItems : homeMenuItems,
    AppModule.iptv => const [
      NavigationItem.channels,
      NavigationItem.iptvFavorites,
      NavigationItem.iptvRecent,
      NavigationItem.iptvGuide,
    ],
    AppModule.vod => const [
      NavigationItem.vodSearch,
      NavigationItem.vod,
      NavigationItem.vodRegions,
      NavigationItem.vodPgc,
    ],
    AppModule.music => const [
      NavigationItem.music,
      NavigationItem.musicSonglist,
      NavigationItem.musicToplist,
      NavigationItem.musicLibrary,
    ],
    AppModule.hongguo => const [
      NavigationItem.hongguoHome,
      NavigationItem.hongguoFind,
      NavigationItem.hongguoRank,
      NavigationItem.hongguoFavorites,
    ],
  };

  /// The top bar's title on a tab: the page on screen, not the app's name
  /// (the drawer's head already carries the name).
  String _title(Translations t) => selected.label(t);

  /// One menu block as the drawer shows it: the live home block is the
  /// navigation setting's list (membership and order), a block made
  /// entirely of tools follows the tool-order setting, and every other
  /// block keeps the registry's order.
  List<NavigationItem> _menuItems(List<NavigationItem> block, List<NavigationItem> toolOrder) {
    if (module == AppModule.live && block.every(kHomeMenuItems.contains)) {
      return homeMenuItems.isEmpty ? kHomeMenuItems : homeMenuItems;
    }
    if (block.isNotEmpty && block.every(toolOrder.contains)) {
      return [
        for (final item in toolOrder)
          if (block.contains(item)) item,
      ];
    }
    return block;
  }

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
    // The bar carries the module's feeds. A page below them — a tool,
    // history, settings — is not a tab: the top bar leads back to the feeds
    // and the bar itself steps aside.
    final tabs = bottomTabsOf(module);
    final atTab = tabs.contains(selected);
    final current = atTab ? selected : tabs.first;
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
        leading: atTab
            ? Builder(
                builder: (context) => IconButton(
                  tooltip: t.common.openNavigation,
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: DsIcon(DsIcons.menu, size: 20, color: colors.text),
                ),
              )
            : IconButton(
                tooltip: t.common.back,
                // A deep link can land on a page with an empty trail; the
                // back arrow then returns to the module's first tab rather
                // than leaving the viewer nowhere to go.
                onPressed: canBack ? onBack : () => onSelected(tabs.first),
                icon: DsIcon(DsIcons.arrowLeft, size: 20, color: colors.text),
              ),
        title: atTab
            ? Text(
                _title(t),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.title.copyWith(color: colors.text),
              )
            : breadcrumb,
        centerTitle: false,
        actions: [
          // A window strip above this bar already carries the switch; two
          // moons stacked on a narrow desktop window would be one too many.
          if (!WindowChromeState.drawsStrip) const ThemeModeToggle(size: 48, iconSize: 20),
          const SizedBox(width: DsSpace.s4),
        ],
      ),
      bottomNavigationBar: !atTab
          ? null
          : glass
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

          // The drawer holds what the bar does not: the module's other
          // pages and settings. Repeating the bar's four feeds here was a
          // second copy of the same destinations.
          final groups = [
            for (final group in navigationOf(module).menu)
              [
                for (final item in _menuItems(group, ref.watch(toolOrderProvider)))
                  if (!tabs.contains(item)) item,
              ],
          ].where((group) => group.isNotEmpty).toList();
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
                  // The module's remaining menu, block by block; a divider
                  // separates the blocks. Settings follows under its own
                  // divider.
                  for (final (index, group) in groups.indexed) ...[
                    if (index > 0) const SidebarDivider(),
                    for (final item in group)
                      DsSidebarItem(
                        value: item,
                        leading: DsIcon(item.icon),
                        label: Text(item.label(t)),
                        count: badges[item],
                        countSemanticLabel: switch (badges[item]) {
                          final count? => t.hongguo.favoriteAdded(count: count),
                          null => null,
                        },
                      ),
                  ],
                  if (groups.isNotEmpty) const SidebarDivider(),
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
      body: glass && atTab
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
