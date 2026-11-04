import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/layouts/app_switcher.dart';
import 'package:pure_live/layouts/desktop/sidebar_resizer.dart';
import 'package:pure_live/layouts/desktop/title_bar.dart';
import 'package:pure_live/layouts/location_breadcrumb.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_feeds.dart';
import 'package:pure_live/modules/iptv/controllers/iptv_controller.dart';
import 'package:pure_live/modules/live/areas/areas.dart';
import 'package:pure_live/modules/live/favorites/favorites.dart';
import 'package:pure_live/modules/live/history/history.dart';
import 'package:pure_live/modules/live/multiview/multiview.dart' show multiviewSearchHandoffProvider;
import 'package:pure_live/modules/live/popular/popular.dart';
import 'package:pure_live/modules/live/recorder/recorder.dart' show recorderSearchHandoffProvider;
import 'package:pure_live/modules/live/toolbox/toolbox_page.dart' show LogsSettingsButton;
import 'package:pure_live/modules/music/controller/music_search.dart';
import 'package:pure_live/modules/vod/controller/vod_controller.dart';
import 'package:pure_live/shared/shared.dart';

// Every import stays on one line with no `show` clause: the save-time
// import organizer used to tear wrapped imports apart, so nothing here
// may wrap. Do not add a wrapped import to this file.

/// The folded rail's item: a 40px tile with a 24px icon — the header's
/// module mark and the rail's items read at one weight.
const DsSidebarItemStyle _collapsedItem = DsSidebarItemStyle(height: 40, iconSize: 24);

/// The head's search field: comfortable at 320 wide, still readable at 160.
/// Below that the row shows the magnifier instead.
const double _kToolbarSearchWidth = 320;
const double _kToolbarSearchMinWidth = 160;

/// The desktop layout, following the v4 navigation design: the self-drawn
/// title bar above ([WindowTitleBar] — its left corner holds the app icon
/// that hovers into the sidebar toggle, and the back and forward arrows
/// over the caller's visit trail) — below it the sidebar: the app
/// switcher on top ("Pure Live" and a dropdown chevron opening the
/// content types), the module's menu under it in its blocks (a divider
/// between blocks — the live module's read the reference's rail), and
/// settings pinned to the foot — the menu scrolls when it must, settings
/// never do; expanded with labels at wide widths and folded to an icon rail
/// with tooltips below the breakpoint; a [SidebarResizer] between the
/// sidebar and the content drags the width (double-tap resets it, dragging
/// it far left puts the sidebar away); a search field above the content
/// that searches what the browsed page is — each page's own content in
/// place, a module's own search surface when the page has none.
///
/// The caption and the drag band go to the window host — the layout is the
/// app's, the window behaviour is `live_shell_desktop`'s. Which widths get
/// which sidebar is the caller's breakpoints, not this widget's.
final class DesktopLayout extends ConsumerStatefulWidget {
  /// A desktop layout over [content].
  const DesktopLayout({
    required this.content,
    required this.menuGroups,
    required this.menuGroupLabels,
    required this.menuValue,
    required this.onMenu,
    required this.expanded,
    required this.module,
    required this.onModuleSelected,
    required this.sidebarWidth,
    required this.onToggleSidebar,
    required this.onSidebarWidthChanged,
    required this.canBack,
    required this.canForward,
    required this.onBack,
    required this.onForward,
    required this.onBackToApp,
    this.settingsSection,
    this.settingsCategoryKey,
    this.settingsSectionOpen = false,
    this.badges = const {},
    this.tv = false,
    super.key,
  });

  /// The current screen.
  final Widget content;

  /// The sidebar's menu, one list per block; a divider separates the
  /// blocks. The app menu's entries are [NavigationItem]s (the module's
  /// blocks, read from the navigation registry); the settings surface's are
  /// first-level category keys — the same menu either way, which is the
  /// point: entering settings swaps the entries, not the sidebar.
  final List<List<Object>> menuGroups;

  /// One label key per [menuGroups] entry, or null for an unlabelled block.
  /// The settings menu prints the group's name above its rows; the app
  /// menu's blocks keep their divider-only rhythm.
  final List<String?> menuGroupLabels;

  /// The selected entry of the menu, when one is.
  final Object? menuValue;

  /// Fired when the viewer picks an entry.
  final ValueChanged<Object> onMenu;

  /// The section on screen while the settings surface is showing; null
  /// elsewhere, where only the foot's settings entry highlights.
  final SettingsSection? settingsSection;

  /// The settings category the surface is on, for the breadcrumb; null
  /// outside settings.
  final String? settingsCategoryKey;

  /// Whether a section page is open below [settingsCategoryKey].
  final bool settingsSectionOpen;

  /// Count badges the menu rows show at their end, keyed by destination —
  /// the hongguo shelf's new episodes, for now. A destination missing here
  /// shows none.
  final Map<NavigationItem, int> badges;

  /// A TV build: the sidebar and pages are the same, but the toolbar's
  /// text field is left out — a remote's arrows would move its caret
  /// instead of the focus, and the module's own search entries are the way
  /// in.
  final bool tv;

  /// Leaves the settings surface for the app: the foot's own entry while
  /// the settings menu is what the sidebar shows (the reference's
  /// "Back to app"), instead of stacking a second menu or a button on the page.
  final VoidCallback onBackToApp;

  /// Whether the sidebar shows its labels (the expanded rail) or folds to
  /// icons with tooltips.
  final bool expanded;

  /// The module whose navigation the sidebar shows.
  final AppModule module;

  /// Fired when the app switcher picks that module.
  final ValueChanged<AppModule> onModuleSelected;

  /// The sidebar's dragged width, when [expanded].
  final double sidebarWidth;

  /// Fired when the toggle button (or Ctrl+B) flips the sidebar.
  final VoidCallback onToggleSidebar;

  /// Fired with the width a drag (or the reset) produced.
  final ValueChanged<double> onSidebarWidthChanged;

  /// Whether the trail has a destination behind the current one.
  final bool canBack;

  /// Whether the trail has a destination ahead of the current one.
  final bool canForward;

  /// Fired when the back arrow moves one destination back.
  final VoidCallback onBack;

  /// Fired when the forward arrow moves one destination ahead.
  final VoidCallback onForward;

  @override
  ConsumerState<DesktopLayout> createState() => _DesktopLayoutState();
}

final class _DesktopLayoutState extends ConsumerState<DesktopLayout> {
  /// Whether a width drag is live: while it is, the sidebar's width
  /// follows the pointer at once instead of chasing it on the theme's
  /// motion.
  bool _resizing = false;

  /// The toolbar search's field, so the title bar's magnifier and Ctrl+K
  /// can put the caret in it from anywhere.
  final FocusNode _searchFocus = FocusNode();

  /// The current menu row, the shell's starting stop. It follows the
  /// selection and is also the rescue when a route or dialog hands focus
  /// back to the shell with no focused child (a remote would be stranded
  /// on a scope it cannot move from).
  final FocusNode _selectedFocus = FocusNode(debugLabel: 'selected menu item');

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_rescueFocus);
  }

  void _setResizing(bool resizing) {
    if (_resizing != resizing) setState(() => _resizing = resizing);
  }

  void _focusSearch() {
    // A narrow head draws no field (it keeps a magnifier instead), so the
    // shortcut opens the search page rather than focusing nothing.
    if (_searchFocus.context == null) {
      widget.onMenu(NavigationItem.search);
      return;
    }
    _searchFocus.requestFocus();
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_rescueFocus);
    _selectedFocus.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// Puts the focus back on the current menu row when the shell's own focus
  /// scope is left without a stop (a room page popped, a dialog closed with
  /// nothing to restore). It never fights a real stop, another route's
  /// scope or a popup's.
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

  @override
  void didUpdateWidget(DesktopLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The toolbar search is the browsed page's own: leaving the page drops
    // its word, so a filter never waits behind another page or module. The
    // drop waits for the frame — a provider must not move while the tree
    // is building.
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

  /// Drops every page's inline word.
  void _clearInlineSearches() {
    ref.read(popularInlineSearchProvider.notifier).clear();
    ref.read(areasInlineSearchProvider.notifier).clear();
    ref.read(favoritesInlineSearchProvider.notifier).clear();
  }

  /// The toolbar search of the page being browsed — its hint and where the
  /// word goes — or null when the page has no list of its own to search
  /// (the search pages with their own field, the multiview, the toolbox,
  /// the logs, the settings-like pages). The word lands in the page on
  /// screen: its own content in place, its module's own search surface
  /// when the module has one — never a cold, scopeless page elsewhere.
  ({String hint, void Function(String word) take})? _pageSearch(Translations t) {
    final page = widget.menuValue;
    switch (widget.module) {
      case AppModule.live:
        // Each list page narrows its own content: the popular feed its
        // rooms, the areas page its catalogue, the follows, the records.
        // The recorder and the multiview act on a room instead: their word
        // opens the room search picker and the pick becomes a task or a
        // cell.
        return switch (page) {
          NavigationItem.hot => (
            hint: t.common.searchHint,
            take: (word) => ref.read(popularInlineSearchProvider.notifier).search(word),
          ),
          NavigationItem.zones => (
            hint: t.areas.searchHint,
            take: (word) => ref.read(areasInlineSearchProvider.notifier).search(word),
          ),
          NavigationItem.favorites => (
            hint: t.common.searchHint,
            take: (word) => ref.read(favoritesInlineSearchProvider.notifier).search(word),
          ),
          NavigationItem.history => (
            hint: t.common.searchHint,
            take: (word) => ref.read(historySearchHandoffProvider.notifier).hand(word),
          ),
          NavigationItem.record => (
            hint: t.recorder.searchHint,
            take: (word) => ref.read(recorderSearchHandoffProvider.notifier).hand(word),
          ),
          NavigationItem.multiview => (
            hint: t.multiview.searchHint,
            take: (word) => ref.read(multiviewSearchHandoffProvider.notifier).hand(word),
          ),
          _ => null,
        };
      case AppModule.iptv:
        // The channel pages search their channels in place; the sources
        // and the rest have no list of channels to narrow.
        const searchable = {NavigationItem.channels, NavigationItem.iptvFavorites, NavigationItem.iptvGuide};
        if (!searchable.contains(page)) return null;
        return (hint: t.iptv.searchChannels, take: (word) => ref.read(iptvSearchHandoffProvider.notifier).hand(word));
      case AppModule.vod:
        // The station's own search page answers; it has its own field.
        if (page == NavigationItem.vodSearch) return null;
        return (
          hint: t.vod.searchHint,
          take: (word) {
            ref.read(vodPendingSearchProvider.notifier).hand(word);
            widget.onMenu(NavigationItem.vodSearch);
          },
        );
      case AppModule.music:
        // The library is the module's search: the page takes the word and
        // moves there itself.
        return (
          hint: t.music.searchHint,
          take: (word) {
            ref.read(musicSearchHandoffProvider.notifier).hand(word);
            if (page != NavigationItem.music) widget.onMenu(NavigationItem.music);
          },
        );
      case AppModule.hongguo:
        // The station's own search view answers; it has its own field.
        if (page == NavigationItem.hongguoSearch) return null;
        return (
          hint: t.hongguo.searchHint,
          take: (word) {
            ref.read(hongguoSearchHandoffProvider.notifier).hand(word);
            widget.onMenu(NavigationItem.hongguoSearch);
          },
        );
    }
  }

  /// One entry of either menu as the same sidebar row: a module
  /// destination or a settings category.
  ///
  /// The current page takes the focus on first build: a remote has no
  /// pointer to start from, and every arrow needs a focused stop. It is
  /// keyed by its value so a menu swap (settings in, settings out, another
  /// module) gives the new current row a fresh mount and the focus again.
  /// On TV the focused row grows with the rest of the shell (`tvFocusZoom`).
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
      // A settings category: the rail lists these first, and the content
      // area shows the chosen one's page.
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

  /// The lead above a menu block: a named heading for a settings group in
  /// the expanded rail, the plain divider elsewhere, nothing above the
  /// first block.
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

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final t = context.t;
    final theme = DsTheme.of(context);
    // A wallpaper sits under the whole shell: the content area must not
    // paint the theme's surface over it, and the rail turns to glass.
    final wallpaper = BackgroundActiveScope.isActiveOf(context);
    final sidebarStyle = DsSidebarStyle(
      width: math.min(widget.sidebarWidth, MediaQuery.sizeOf(context).width - kSidebarContentFloor),
      // The folded rail keeps the header's mark and gives the items a
      // 40px tile with a 22px icon: a rail is read by shape, so the icon
      // must carry the row, not sit small inside it.
      collapsedWidth: 64,
      background: wallpaper ? colors.sidebar.withValues(alpha: 0.78) : null,
    );
    // A width remembered from a wider window yields to the content's
    // floor until the window grows again.
    final sidebarWidth = sidebarStyle.width!;
    // The toolbar search is comfortable at 320 and still reads at 160; it
    // gives way to the magnifier only when the row cannot fit both it and a
    // readable breadcrumb (32 of head padding, ~220 for the trail). Only a
    // page with a list of its own to search gets the field at all.
    final pageSearch = _pageSearch(t);
    final headWidth = MediaQuery.sizeOf(context).width - sidebarWidth;
    final searchFieldWidth = math.min(_kToolbarSearchWidth, headWidth - 32 - 220);
    final showToolbarSearch =
        !widget.tv &&
        widget.settingsSection == null &&
        pageSearch != null &&
        searchFieldWidth >= _kToolbarSearchMinWidth;
    final items = <Widget>[
      for (final (index, group) in widget.menuGroups.indexed) ...[
        // In settings the groups earn their names (the reference's areas);
        // the app's own blocks keep the quieter divider. A folded rail has
        // no room for words, so it falls back to the divider too.
        ?_groupLead(t, index),
        for (final entry in group) _menuItem(t, entry),
      ],
    ];
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyB, control: true): widget.onToggleSidebar,
        const SingleActivator(LogicalKeyboardKey.keyB, meta: true): widget.onToggleSidebar,
        // The browser and editor habits: Ctrl/⌘+K goes to search,
        // Ctrl/⌘+, to the settings surface.
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): _focusSearch,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): _focusSearch,
        const SingleActivator(LogicalKeyboardKey.comma, control: true): () => widget.onMenu(NavigationItem.settings),
        const SingleActivator(LogicalKeyboardKey.comma, meta: true): () => widget.onMenu(NavigationItem.settings),
      },
      // The node keeps the shortcuts above the page's own focus stops. It
      // is skipped in traversal, so Tab never lands here, and the sidebar's
      // current row takes the initial focus instead — a focusable stop with
      // a rectangle for the first arrow to move from.
      child: Focus(
        skipTraversal: true,
        child: ColoredBox(
          color: wallpaper ? const Color(0x00000000) : colors.surface,
          child: Column(
            children: [
              // A native caption means the system already drew the strip;
              // drawing a second one under it is two title bars.
              if (WindowChromeState.drawsStrip)
                WindowTitleBar(
                  expanded: widget.expanded,
                  onToggleSidebar: widget.onToggleSidebar,
                  canBack: widget.canBack,
                  canForward: widget.canForward,
                  onBack: widget.onBack,
                  onForward: widget.onForward,
                  // The magnifier reaches the toolbar field; where the field
                  // gives way to a narrow window (or the settings surface
                  // hides it), the button goes with it instead of standing
                  // over nothing.
                ),
              Expanded(
                child: Row(
                  children: [
                    DsTheme(
                      // A live drag moves the width itself; the spring is
                      // for the toggle, not for the pointer's hand.
                      data: _resizing ? theme.copyWith(motion: theme.motion.copyWith(reduced: true)) : theme,
                      child: Column(
                        children: [
                          // The navigation itself: it scrolls when the
                          // window is too short for it; the settings entry
                          // below never leaves the foot.
                          Expanded(
                            child: DsSidebar(
                              collapsed: !widget.expanded,
                              // The app switcher belongs to the app's menu.
                              // The settings menu is the settings menu: the
                              // brand row (and its module dropdown) goes.
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
                          // Settings stays in the foot whatever the menu's
                          // length: a second sidebar of one item, its top
                          // padding handed to the divider instead.
                          // The foot carries the one way in and the one way
                          // out: the settings entry on the app's menu, and
                          // "Back to app" while the settings menu is showing —
                          // the reference's arrangement.
                          DsSidebar<Object>(
                            collapsed: !widget.expanded,
                            // The foot is a set of actions, not a location:
                            // nothing in it stays lit.
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
                      ColoredBox(
                        color: colors.border,
                        child: const SizedBox(width: 1, height: double.infinity),
                      ),
                    Expanded(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(DsSpace.s16, DsSpace.s12, DsSpace.s16, 0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: LocationBreadcrumb(
                                    module: widget.module,
                                    selected: widget.menuValue,
                                    settings: widget.settingsSection,
                                    categoryKey: widget.settingsCategoryKey,
                                    sectionOpen: widget.settingsSectionOpen,
                                  ),
                                ),
                                // The settings surface has its own section
                                // search in the pane; a second, room-wide
                                // field over it reads as two searches.
                                if (showToolbarSearch) ...[
                                  const SizedBox(width: DsSpace.s16),
                                  SizedBox(
                                    width: searchFieldWidth,
                                    // The toolbar search searches what the
                                    // viewer is browsing (see [_pageSearch]).
                                    // Keyed by the page: a word typed on one
                                    // page never lingers in the field on the
                                    // next.
                                    child: _ToolbarSearch(
                                      key: ValueKey((widget.module, widget.menuValue)),
                                      hint: pageSearch.hint,
                                      focusNode: _searchFocus,
                                      shortcut: DsTheme.of(context).platform == TargetPlatform.macOS ? '⌘K' : 'Ctrl K',
                                      onSubmitted: (word) {
                                        // Every page's inline word yields to
                                        // the new one: a stale filter must
                                        // never survive a search somewhere
                                        // else.
                                        _clearInlineSearches();
                                        pageSearch.take(word);
                                      },
                                    ),
                                  ),
                                ],
                                // A narrow head cannot hold the 320-wide
                                // field; the magnifier opens the app's search
                                // page rather than taking search away with
                                // the room.
                                if (!showToolbarSearch &&
                                    !widget.tv &&
                                    widget.settingsSection == null &&
                                    pageSearch != null) ...[
                                  const SizedBox(width: DsSpace.s8),
                                  DsButton.icon(
                                    variant: DsButtonVariant.secondary,
                                    size: DsSize.sm,
                                    semanticLabel: t.navigation.search,
                                    onPressed: () => widget.onMenu(NavigationItem.search),
                                    icon: const DsIcon(DsIcons.search, size: 16),
                                  ),
                                ],
                                // A page's own head action rides this row:
                                // the log console keeps its settings gear
                                // at the window's top-right, so the way to
                                // the rest of the log settings is where a
                                // head button belongs, narrow or wide.
                                if (widget.module == AppModule.live && widget.menuValue == NavigationItem.logs) ...[
                                  const LogsSettingsButton(),
                                  const SizedBox(width: DsSpace.s8),
                                ],
                                // The self-drawn strip carries the mode
                                // switch; a native caption leaves no strip,
                                // so the content head takes it instead.
                                if (!WindowChromeState.drawsStrip) ...[
                                  const SizedBox(width: DsSpace.s8),
                                  const ThemeModeToggle(size: 36),
                                ],
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
}

/// The toolbar's search field: typing is real, and submitting hands the
/// word to the page being browsed — its own content in place, its module's
/// own search surface when the page has none.
final class _ToolbarSearch extends StatefulWidget {
  const _ToolbarSearch({required this.hint, required this.onSubmitted, this.focusNode, this.shortcut, super.key});

  final String hint;
  final ValueChanged<String> onSubmitted;

  /// The layout's field, so Ctrl+K and the title bar's magnifier can reach
  /// it; null lets the field own one.
  final FocusNode? focusNode;

  /// The keys shown in the empty field and under the title bar's
  /// magnifier, e.g. "Ctrl K".
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

/// A settings group's name above its rows in the expanded rail — the
/// reference's areas (Interface, Live sources, Playback…), so a long menu
/// reads as a few named sections instead of one undifferentiated list.
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
