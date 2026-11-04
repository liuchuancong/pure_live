import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/layouts/app_switcher.dart';
import 'package:pure_live/layouts/desktop/sidebar_resizer.dart';
import 'package:pure_live/layouts/desktop/title_bar.dart';
import 'package:pure_live/layouts/mobile/liquid_glass.dart';
import 'package:pure_live/layouts/page_inline_search.dart';
import 'package:pure_live/modules/live/areas/areas.dart';
import 'package:pure_live/modules/live/favorites/favorites.dart';
import 'package:pure_live/modules/live/popular/popular.dart';
import 'package:pure_live/modules/live/toolbox/toolbox_page.dart' show LogsSettingsButton;
import 'package:pure_live/shared/shared.dart';

// No `show` clause: a wrapped import is what the save-time import organizer
// kept breaking apart.

/// The width the navigation drawer opens to.
const double kNavigationDrawerWidth = 320;

/// The head's search field: comfortable at 320 wide, still readable at 160.
/// Below that the head shows the magnifier instead.
const double _kToolbarSearchWidth = 320;
const double _kToolbarSearchMinWidth = 160;

/// The folded rail's item: a 40px tile with a 24px icon — the header's module
/// mark and the rail's items read at one weight.
const DsSidebarItemStyle _collapsedItem = DsSidebarItemStyle(height: 40, iconSize: 24);

/// How many destinations a phone's bottom bar keeps; the platform guidance and
/// every common client agree on five.
const int _kMaxBottomTabs = 5;

/// The one shell: the width decides the navigation's shape, not the widget.
///
/// Wide, the sidebar holds the menu and the head line carries the breadcrumb;
/// narrow, the bottom bar holds the module's feeds, the drawer holds the rest,
/// and the same head line turns into the app bar with a menu button. The head
/// itself is one row in both shapes — breadcrumb (or the page's title), the
/// page's search, then the page's own verbs — so a page hands its actions to
/// the shell once and the shell puts them wherever it has room.
final class AppShell extends ConsumerStatefulWidget {
  /// The shell around [content].
  const AppShell({
    required this.content,
    required this.module,
    required this.selected,
    required this.onSelected,
    required this.onModuleSelected,
    required this.breadcrumb,
    required this.canBack,
    required this.onBack,
    required this.onForward,
    required this.canForward,
    required this.onBackToApp,
    required this.menuGroups,
    required this.menuGroupLabels,
    required this.menuValue,
    required this.onMenu,
    required this.expanded,
    required this.sidebarWidth,
    required this.onToggleSidebar,
    required this.onSidebarWidthChanged,
    this.settingsSection,
    this.settingsCategoryKey,
    this.settingsSectionOpen = false,
    this.homeMenuItems = kHomeMenuItems,
    this.badges = const {},
    this.tv = false,
    super.key,
  });

  /// The current screen.
  final Widget content;

  /// The module whose navigation the shell shows.
  final AppModule module;

  /// The selected destination.
  final NavigationItem selected;

  /// Fired when the viewer picks a destination from the phone's bars.
  final ValueChanged<NavigationItem> onSelected;

  /// Fired when the app switcher picks a module.
  final ValueChanged<AppModule> onModuleSelected;

  /// The where-am-I path the head shows.
  final Widget breadcrumb;

  /// Whether there is a destination behind the one on screen.
  final bool canBack;

  /// Fired by the title bar's back arrow and the phone's own back button.
  final VoidCallback onBack;

  /// Fired by the title bar's forward arrow.
  final VoidCallback onForward;

  /// Whether the trail has a destination ahead of the current one.
  final bool canForward;

  /// Leaves the settings surface for the app: the foot's own entry while the
  /// settings menu is what the sidebar shows.
  final VoidCallback onBackToApp;

  /// The sidebar's menu, one list per block; a divider separates the blocks.
  final List<List<Object>> menuGroups;

  /// One label key per [menuGroups] entry, or null for an unlabelled block.
  final List<String?> menuGroupLabels;

  /// The selected entry of the menu, when one is.
  final Object? menuValue;

  /// Fired when the viewer picks an entry.
  final ValueChanged<Object> onMenu;

  /// The section on screen while the settings surface is showing.
  final SettingsSection? settingsSection;

  /// The settings category the surface is on, for the breadcrumb.
  final String? settingsCategoryKey;

  /// Whether a section page is open below [settingsCategoryKey].
  final bool settingsSectionOpen;

  /// The live home menu's visible entries in the viewer's order.
  final List<NavigationItem> homeMenuItems;

  /// Count badges the menu rows show at their end, keyed by destination.
  final Map<NavigationItem, int> badges;

  /// Whether the sidebar shows its labels (the expanded rail) or folds to
  /// icons with tooltips.
  final bool expanded;

  /// The sidebar's dragged width, when [expanded].
  final double sidebarWidth;

  /// Fired when the toggle button (or Ctrl+B) flips the sidebar.
  final VoidCallback onToggleSidebar;

  /// Fired with the width a drag (or the reset) produced.
  final ValueChanged<double> onSidebarWidthChanged;

  /// A TV build: the sidebar and pages are the same, but the toolbar's field
  /// is left out — a remote's arrows would move its caret instead of the
  /// focus — and the phone's bars never appear.
  final bool tv;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

final class _AppShellState extends ConsumerState<AppShell> {
  /// Whether a width drag is live: while it is, the sidebar's width follows the
  /// pointer at once instead of chasing it on the theme's motion.
  bool _resizing = false;

  /// The toolbar search's field, so the title bar's magnifier and Ctrl+K can
  /// put the caret in it from anywhere.
  final FocusNode _searchFocus = FocusNode();

  /// The current menu row, the shell's starting stop. It follows the selection
  /// and is also the rescue when a route or dialog hands focus back to the
  /// shell with no focused child.
  final FocusNode _selectedFocus = FocusNode(debugLabel: 'selected menu item');

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_rescueFocus);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_rescueFocus);
    _selectedFocus.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The toolbar search is the browsed page's own: leaving the page drops its
    // word, so a filter never waits behind another page or module. The drop
    // waits for the frame — a provider must not move while the tree builds.
    if (oldWidget.menuValue != widget.menuValue || oldWidget.module != widget.module) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _clearInlineSearches();
      });
    }
    // A drag that collapsed the sidebar took the strip with it, so its
    // end-of-drag report never arrives; the layout stops resizing here.
    if (!widget.expanded && oldWidget.expanded && _resizing) {
      _resizing = false;
    }
  }

  void _setResizing(bool resizing) {
    if (_resizing != resizing) setState(() => _resizing = resizing);
  }

  void _focusSearch() {
    // A head without a field (the phone's, or a desktop row too tight for it)
    // asks for the page's word in a panel rather than focusing nothing.
    if (_searchFocus.context == null) {
      final search = _pageSearch(context.t);
      if (search != null) unawaited(showPageInlineSearch(context, search: search));
      return;
    }
    _searchFocus.requestFocus();
  }

  /// Puts the focus back on the current menu row when the shell's own focus
  /// scope is left without a stop (a room page popped, a dialog closed with
  /// nothing to restore). It never fights a real stop, another route's scope or
  /// a popup's.
  void _rescueFocus() {
    if (!mounted) return;
    final scope = FocusScope.of(context, createDependency: false);
    if (!identical(FocusManager.instance.primaryFocus, scope)) return;
    if (ModalRoute.isCurrentOf(context) != true) return;
    if (_selectedFocus.context == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ModalRoute.isCurrentOf(context) != true) return;
      final current = FocusManager.instance.primaryFocus;
      final now = FocusScope.of(context, createDependency: false);
      if (identical(current, now) && _selectedFocus.context != null) {
        _selectedFocus.requestFocus();
      }
    });
  }

  /// Drops every page's inline word.
  void _clearInlineSearches() {
    ref.read(popularInlineSearchProvider.notifier).clear();
    ref.read(areasInlineSearchProvider.notifier).clear();
    ref.read(favoritesInlineSearchProvider.notifier).clear();
  }

  /// The toolbar search of the page being browsed — its hint and where the word
  /// goes — or null when the page has no list of its own to search.
  ({String hint, void Function(String word) take})? _pageSearch(Translations t) {
    // The menu's value can also be a settings category; only a page has a list
    // to narrow.
    final page = widget.menuValue;
    if (page is! NavigationItem) return null;
    return pageInlineSearch(ref, t, widget.module, page, openPage: widget.onMenu);
  }

  /// The current page's own verbs, offered to the single head row.
  List<Widget> _pageVerbs() => switch (widget.selected) {
    NavigationItem.hot => const [PopularTopBarActions()],
    NavigationItem.zones => const [AreasTopBarActions()],
    NavigationItem.favorites => const [FavoritesTopBarActions()],
    _ => const [],
  };

  /// One entry of either menu as the same sidebar row: a module destination or
  /// a settings category.
  Widget _menuItem(Translations t, Object value) {
    final row = switch (value) {
      final NavigationItem item => DsSidebarItem<Object>(
        key: ValueKey(item),
        value: item,
        leading: DsIcon(item.icon),
        label: Text(item.label(t)),
        count: widget.badges[item],
        countSemanticLabel: switch (widget.badges[item]) {
          final count? => t.hongguo.favoriteAdded(count: count),
          null => null,
        },
        style: widget.expanded ? null : _collapsedItem,
        focusNode: item == widget.menuValue ? _selectedFocus : null,
        autofocus: item == widget.menuValue,
      ),
      // A settings category: the rail lists these first, and the content area
      // shows the chosen one's page.
      final String category => DsSidebarItem<Object>(
        key: ValueKey(category),
        value: category,
        leading: DsIcon(settingsGroupIcon(category)),
        label: Text(settingsGroupLabel(t, category)),
        style: widget.expanded ? null : _collapsedItem,
        focusNode: category == widget.menuValue ? _selectedFocus : null,
        autofocus: category == widget.menuValue,
      ),
      _ => const SizedBox.shrink(),
    };
    return _zoomOnTv(row);
  }

  /// A sidebar row that grows while focused on TV.
  Widget _zoomOnTv(Widget row) => widget.tv ? TvFocusScale(child: row) : row;

  /// The lead above a menu block: a named heading for a settings group in the
  /// expanded rail, the plain divider elsewhere, nothing above the first block.
  Widget? _groupLead(Translations t, int index) {
    final labels = widget.menuGroupLabels;
    final label = index < labels.length ? labels[index] : null;
    if (widget.expanded && label != null) return _SettingsGroupHeading(label: settingsGroupLabel(t, label));
    return index > 0 ? const SidebarDivider() : null;
  }

  void _footerChanged(Object value) {
    if (widget.settingsSection == null) {
      widget.onMenu(value);
    } else {
      widget.onBackToApp();
    }
  }

  /// The phone's bar carries the module's feeds. A page below them — a tool,
  /// history, settings — is not a tab.
  List<NavigationItem> _bottomTabs() => switch (widget.module) {
    AppModule.live => (widget.homeMenuItems.isEmpty ? kHomeMenuItems : widget.homeMenuItems).take(_kMaxBottomTabs).toList(),
    AppModule.iptv => const [
      NavigationItem.channels,
      NavigationItem.iptvFavorites,
      NavigationItem.iptvRecent,
      NavigationItem.iptvGuide,
    ],
    AppModule.vod => const [NavigationItem.vodSearch, NavigationItem.vod, NavigationItem.vodRegions, NavigationItem.vodPgc],
    AppModule.music => const [
      NavigationItem.musicRecommend,
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

  /// One menu block as the drawer shows it: the live home block is the
  /// navigation setting's list, a block made entirely of tools follows the
  /// tool-order setting, and every other block keeps the registry's order.
  List<NavigationItem> _menuItems(List<NavigationItem> block, List<NavigationItem> toolOrder) {
    if (widget.module == AppModule.live && block.every(kHomeMenuItems.contains)) {
      return widget.homeMenuItems.isEmpty ? kHomeMenuItems : widget.homeMenuItems;
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
  Widget build(BuildContext context) {
    final t = context.t;
    final width = MediaQuery.sizeOf(context).width;
    // A TV keeps the sidebar at every width: the drawer and bottom bar belong
    // to thumbs, and this shell's rail is what a remote starts on.
    final narrow = width < kBottomBarBreakpoint.breakpoint && !widget.tv;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final wallpaper = BackgroundActiveScope.isActiveOf(context);
    final chrome = wallpaper ? colors.surface.withValues(alpha: 0.82) : colors.surface;
    final rail = wallpaper ? colors.sidebar.withValues(alpha: 0.86) : colors.sidebar;
    final sidebarStyle = DsSidebarStyle(
      width: math.min(widget.sidebarWidth, width - kSidebarContentFloor),
      collapsedWidth: 64,
      background: wallpaper ? colors.sidebar.withValues(alpha: 0.78) : null,
    );
    final sidebarWidth = sidebarStyle.width!;
    // The head line: the page's search gives way before its verbs; only a page
    // with a list of its own to search gets either.
    final pageSearch = _pageSearch(t);
    final headWidth = width - (narrow ? 0 : sidebarWidth);
    // The page's own row keeps its verbs until its usable width goes under
    // the toolbar breakpoint; then this head carries them. Both sides measure
    // the same width (content minus the page's insets), so they cannot
    // disagree about a window between their thresholds.
    final hostsVerbs = LiveWindow.stacksToolbar(headWidth - 2 * LiveWindow.pageInset(width));
    final verbs = hostsVerbs ? _pageVerbs() : const <Widget>[];
    final reserve = (verbs.isEmpty ? 0.0 : 130.0) +
        (widget.selected == NavigationItem.logs ? 44.0 : 0.0) +
        (WindowChromeState.drawsStrip ? 0.0 : 48.0);
    final searchFieldWidth = math.min(_kToolbarSearchWidth, headWidth - 32 - 180 - reserve);
    final showField =
        !narrow && !widget.tv && widget.settingsSection == null && pageSearch != null && searchFieldWidth >= _kToolbarSearchMinWidth;

    Widget searchButton() => DsButton.icon(
      variant: DsButtonVariant.secondary,
      size: DsSize.sm,
      semanticLabel: t.navigation.search,
      onPressed: () => unawaited(showPageInlineSearch(context, search: pageSearch!)),
      icon: const DsIcon(DsIcons.search, size: 16),
    );
    final searchButtonShown = !widget.tv && widget.settingsSection == null && pageSearch != null && !showField;
    final logsGear = widget.module == AppModule.live && widget.selected == NavigationItem.logs;
    final themeToggle = !WindowChromeState.drawsStrip;

    final shortcuts = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.keyB, control: true): widget.onToggleSidebar,
      const SingleActivator(LogicalKeyboardKey.keyB, meta: true): widget.onToggleSidebar,
      const SingleActivator(LogicalKeyboardKey.keyK, control: true): _focusSearch,
      const SingleActivator(LogicalKeyboardKey.keyK, meta: true): _focusSearch,
      const SingleActivator(LogicalKeyboardKey.comma, control: true): () => widget.onMenu(NavigationItem.settings),
      const SingleActivator(LogicalKeyboardKey.comma, meta: true): () => widget.onMenu(NavigationItem.settings),
    };

    if (narrow) {
      final tabs = _bottomTabs();
      final atTab = tabs.contains(widget.selected);
      final current = atTab ? widget.selected : tabs.first;
      final glassPolicy = ref.watch(liveGlassPolicyProvider);
      final glass = glassPolicy.enabled;
      final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
      final navBar = DsBottomNav<NavigationItem>(
        variant: DsBottomNavVariant.bar,
        style: glass ? const DsBottomNavStyle(background: Color(0x00000000)) : null,
        value: current,
        onChanged: widget.onSelected,
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
                  onPressed: widget.canBack ? widget.onBack : () => widget.onSelected(tabs.first),
                  icon: DsIcon(DsIcons.arrowLeft, size: 20, color: colors.text),
                ),
          title: atTab
              ? Text(
                  widget.selected.label(t),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.title.copyWith(color: colors.text),
                )
              : widget.breadcrumb,
          centerTitle: false,
          actions: [
            if (searchButtonShown) ...[searchButton(), const SizedBox(width: DsSpace.s8)],
            if (verbs.isNotEmpty) ...[...verbs, const SizedBox(width: DsSpace.s8)],
            if (logsGear) ...[const LogsSettingsButton(), const SizedBox(width: DsSpace.s8)],
            if (themeToggle) const ThemeModeToggle(size: 48, iconSize: 20),
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
                  child: MediaQuery.removePadding(context: context, removeTop: true, removeBottom: true, child: navBar),
                ),
              )
            : navBar,
        drawer: _drawer(context, t, tabs, rail, wallpaper),
        body: glass && atTab
            ? MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  padding: MediaQuery.paddingOf(context).copyWith(bottom: safeBottom + LiquidGlassMetrics.barOverlap),
                ),
                child: widget.content,
              )
            : widget.content,
      );
      return CallbackShortcuts(
        bindings: shortcuts,
        child: Focus(
          skipTraversal: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (WindowChromeState.drawsStrip) const WindowCaptionBar(),
              Expanded(child: scaffold),
            ],
          ),
        ),
      );
    }

    final items = <Widget>[
      for (final (index, group) in widget.menuGroups.indexed) ...[
        ?_groupLead(t, index),
        for (final entry in group) _menuItem(t, entry),
      ],
    ];
    return CallbackShortcuts(
      bindings: shortcuts,
      child: Focus(
        skipTraversal: true,
        child: ColoredBox(
          color: wallpaper ? const Color(0x00000000) : colors.surface,
          child: Column(
            children: [
              if (WindowChromeState.drawsStrip)
                WindowTitleBar(
                  expanded: widget.expanded,
                  onToggleSidebar: widget.onToggleSidebar,
                  canBack: widget.canBack,
                  canForward: widget.canForward,
                  onBack: widget.onBack,
                  onForward: widget.onForward,
                ),
              Expanded(
                child: Row(
                  children: [
                    DsTheme(
                      // A live drag moves the width itself; the spring is for
                      // the toggle, not for the pointer's hand.
                      data: _resizing ? theme.copyWith(motion: theme.motion.copyWith(reduced: true)) : theme,
                      child: Column(
                        children: [
                          Expanded(
                            child: DsSidebar(
                              collapsed: !widget.expanded,
                              header: widget.settingsSection == null
                                  ? AppSwitcher(
                                      collapsed: !widget.expanded,
                                      module: widget.module,
                                      onModule: widget.onModuleSelected,
                                    )
                                  : null,
                              value: widget.menuValue,
                              onChanged: widget.onMenu,
                              style: sidebarStyle,
                              children: items,
                            ),
                          ),
                          DsSidebar<Object>(
                            collapsed: !widget.expanded,
                            onChanged: _footerChanged,
                            style: sidebarStyle,
                            children: [
                              if (widget.settingsSection == null)
                                _zoomOnTv(
                                  DsSidebarItem<Object>(
                                    value: NavigationItem.settings,
                                    leading: const DsIcon(DsIcons.settings),
                                    label: Text(t.navigation.settings),
                                    style: widget.expanded ? null : _collapsedItem,
                                  ),
                                )
                              else
                                _zoomOnTv(
                                  DsSidebarItem<Object>(
                                    value: NavigationItem.settings,
                                    leading: const DsIcon(DsIcons.arrowLeft),
                                    label: Text(t.settings.backHome),
                                    style: widget.expanded ? null : _collapsedItem,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (widget.expanded)
                      SidebarResizer(
                        width: sidebarWidth,
                        onWidthChanged: widget.onSidebarWidthChanged,
                        onCollapse: widget.onToggleSidebar,
                        onReset: () => widget.onSidebarWidthChanged(kSidebarDefaultWidth),
                        onDragging: _setResizing,
                      )
                    else
                      ColoredBox(color: colors.border, child: const SizedBox(width: 1, height: double.infinity)),
                    Expanded(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(DsSpace.s16, DsSpace.s12, DsSpace.s16, 0),
                            child: Row(
                              children: [
                                Expanded(child: widget.breadcrumb),
                                if (showField) ...[
                                  const SizedBox(width: DsSpace.s16),
                                  SizedBox(
                                    width: searchFieldWidth,
                                    child: _ToolbarSearch(
                                      key: ValueKey((widget.module, widget.menuValue)),
                                      hint: pageSearch.hint,
                                      focusNode: _searchFocus,
                                      shortcut: theme.platform == TargetPlatform.macOS ? '⌘K' : 'Ctrl K',
                                      onSubmitted: (word) {
                                        _clearInlineSearches();
                                        pageSearch.take(word);
                                      },
                                    ),
                                  ),
                                ],
                                if (searchButtonShown) ...[const SizedBox(width: DsSpace.s8), searchButton()],
                                if (verbs.isNotEmpty) ...[
                                  const SizedBox(width: DsSpace.s8),
                                  ...verbs,
                                ],
                                if (logsGear) ...[const LogsSettingsButton(), const SizedBox(width: DsSpace.s8)],
                                if (themeToggle) ...[const SizedBox(width: DsSpace.s8), const ThemeModeToggle(size: 36)],
                              ],
                            ),
                          ),
                          Expanded(child: widget.content),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The phone's drawer: the same navigation the sidebar shows — the app
  /// switcher, the module's menu in its blocks, settings last.
  Widget _drawer(BuildContext context, Translations t, List<NavigationItem> tabs, Color rail, bool wallpaper) {
    return Builder(
      builder: (context) {
        void pick(NavigationItem item) {
          Scaffold.of(context).closeDrawer();
          widget.onSelected(item);
        }

        final groups = [
          for (final group in navigationOf(widget.module).menu)
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
              header: AppSwitcher(module: widget.module, onModule: widget.onModuleSelected),
              value: widget.selected,
              onChanged: pick,
              style: DsSidebarStyle(width: kNavigationDrawerWidth, background: wallpaper ? const Color(0x00000000) : null),
              children: [
                for (final (index, group) in groups.indexed) ...[
                  if (index > 0) const SidebarDivider(),
                  for (final item in group)
                    DsSidebarItem(
                      value: item,
                      leading: DsIcon(item.icon),
                      label: Text(item.label(t)),
                      count: widget.badges[item],
                      countSemanticLabel: switch (widget.badges[item]) {
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
    );
  }
}

/// The toolbar's search field: typing is real, and submitting hands the word to
/// the page being browsed.
final class _ToolbarSearch extends StatefulWidget {
  const _ToolbarSearch({required this.hint, required this.onSubmitted, this.focusNode, this.shortcut, super.key});

  final String hint;
  final ValueChanged<String> onSubmitted;

  /// The shell's field, so Ctrl+K and the title bar's magnifier can reach it;
  /// null lets the field own one.
  final FocusNode? focusNode;

  /// The keys shown in the empty field, e.g. "Ctrl K".
  final String? shortcut;

  @override
  State<_ToolbarSearch> createState() => _ToolbarSearchState();
}

final class _ToolbarSearchState extends State<_ToolbarSearch> {
  final TextEditingController _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DsSearchField(
      controller: _field,
      focusNode: widget.focusNode,
      shortcut: widget.shortcut,
      placeholder: widget.hint,
      onSubmitted: (word) {
        if (word.trim().isEmpty) return;
        widget.onSubmitted(word.trim());
        _field.clear();
      },
    );
  }
}

/// A settings group's name above its rows in the expanded rail.
final class _SettingsGroupHeading extends StatelessWidget {
  const _SettingsGroupHeading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s16, DsSpace.s12, DsSpace.s12, DsSpace.s4),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(label, style: theme.typography.overline.copyWith(color: colors.textSubtle)),
      ),
    );
  }
}
