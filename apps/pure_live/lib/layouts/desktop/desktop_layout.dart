import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/background/app_background.dart' show BackgroundActiveScope;
import 'package:pure_live/app/providers/sidebar_providers.dart';
import 'package:pure_live/app/providers/sites_providers.dart' show selectedSiteIdProvider;
import 'package:pure_live/app/theme/theme_mode_toggle.dart';
import 'package:pure_live/app/window_chrome.dart' show WindowChromeState;
import 'package:pure_live/features/popular/popular_controller.dart';
import 'package:pure_live/features/search/search_controller.dart';
import 'package:pure_live/features/settings/settings_sections.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/layouts/app_switcher.dart';
import 'package:pure_live/layouts/desktop/sidebar_resizer.dart';
import 'package:pure_live/layouts/desktop/title_bar.dart';
import 'package:pure_live/shared/enums/app_module.dart';
import 'package:pure_live/shared/enums/navigation_item.dart';

// Every import stays on one line with no `show` clause: the save-time
// import organizer used to tear wrapped imports apart, so nothing here
// may wrap. Do not add a wrapped import to this file.

/// The folded rail's item: a 40px tile with a 24px icon — the header's
/// module mark and the rail's items read at one weight.
const DsSidebarItemStyle _collapsedItem = DsSidebarItemStyle(height: 40, iconSize: 24);

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
/// it far left puts the sidebar away); a search field opening the search
/// destination above the content.
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
    this.tv = false,
    super.key,
  });

  /// The current screen.
  final Widget content;

  /// The sidebar's menu, one list per block; a divider separates the
  /// blocks. The app menu's entries are [NavigationItem]s (the module's
  /// blocks, read from the navigation registry), the settings surface's are
  /// [SettingsSection]s — the same menu either way, which is the point:
  /// entering settings swaps the entries, not the sidebar.
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

  /// A TV build: the sidebar and pages are the same, but the toolbar's
  /// text field is left out — a remote's arrows would move its caret
  /// instead of the focus, and the sidebar's search page is the way in.
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
    // A drag that collapsed the sidebar took the strip with it, so its
    // end-of-drag report never arrives; the layout stops resizing here.
    if (!widget.expanded && oldWidget.expanded && _resizing) {
      _resizing = false;
    }
  }

  /// One entry of either menu as the same sidebar row: a module
  /// destination or a settings section.
  ///
  /// The current page takes the focus on first build: a remote has no
  /// pointer to start from, and every arrow needs a focused stop. It is
  /// keyed by its value so a menu swap (settings in, settings out, another
  /// module) gives the new current row a fresh mount and the focus again.
  Widget _menuItem(Translations t, Object value) => switch (value) {
    final NavigationItem item => DsSidebarItem<Object>(
      key: ValueKey(item),
      value: item,
      leading: DsIcon(item.icon),
      label: Text(item.label(t)),
      style: widget.expanded ? null : _collapsedItem,
      focusNode: item == widget.menuValue ? _selectedFocus : null,
      autofocus: item == widget.menuValue,
    ),
    final SettingsSection section => DsSidebarItem<Object>(
      key: ValueKey(section),
      value: section,
      leading: DsIcon(section.icon),
      label: Text(section.label(t)),
      style: widget.expanded ? null : _collapsedItem,
      focusNode: section == widget.menuValue ? _selectedFocus : null,
      autofocus: section == widget.menuValue,
    ),
    _ => const SizedBox.shrink(),
  };

  /// The lead above a menu block: a named heading for a settings group in
  /// the expanded rail, the plain divider elsewhere, nothing above the
  /// first block.
  Widget? _groupLead(Translations t, int index) {
    final labels = widget.menuGroupLabels;
    final label = index < labels.length ? labels[index] : null;
    if (widget.expanded && label != null) return _SettingsGroupHeading(label: settingsGroupLabel(t, label));
    return index > 0 ? const SidebarDivider() : null;
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
                  onSearch: widget.tv ? null : _focusSearch,
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
                            value: widget.settingsSection == null ? null : NavigationItem.settings,
                            onChanged: widget.settingsSection == null ? widget.onMenu : (_) => widget.onBackToApp(),
                            style: sidebarStyle,
                            children: widget.settingsSection == null
                                ? [
                                    DsSidebarItem<Object>(
                                      value: NavigationItem.settings,
                                      leading: const DsIcon(DsIcons.settings),
                                      label: Text(t.navigation.settings),
                                      style: widget.expanded ? null : _collapsedItem,
                                    ),
                                  ]
                                : [
                                    DsSidebarItem<Object>(
                                      value: NavigationItem.settings,
                                      leading: const DsIcon(DsIcons.arrowLeft),
                                      label: Text(t.settings.backHome),
                                      style: widget.expanded ? null : _collapsedItem,
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
                                  child: _LocationBreadcrumb(
                                    module: widget.module,
                                    selected: widget.menuValue,
                                    settings: widget.settingsSection,
                                  ),
                                ),
                                // The settings surface has its own section
                                // search in the pane; a second, room-wide
                                // field over it reads as two searches.
                                if (!widget.tv && widget.settingsSection == null) ...[
                                  const SizedBox(width: DsSpace.s16),
                                  SizedBox(
                                    width: 320,
                                    // The toolbar search searches what the
                                    // viewer is browsing: submitting pins the
                                    // search scope to this page's platform (the
                                    // live module's selected site) and opens the
                                    // search page there — not a cold, scopeless
                                    // search.
                                    child: _ToolbarSearch(
                                      hint: t.common.searchHint,
                                      focusNode: _searchFocus,
                                      shortcut: DsTheme.of(context).platform == TargetPlatform.macOS ? '⌘K' : 'Ctrl K',
                                      onSubmitted: (word) {
                                        // Inline: the word lands in the
                                        // popular page itself — its results
                                        // grid over the browsed platform, no
                                        // navigation away. (Other modules
                                        // fall through to the search page,
                                        // where the same word waits.)
                                        if (widget.module == AppModule.live) {
                                          // The platform stays as browsed — the
                                          // inline feed reads it; switching it
                                          // here would strand the browse feed
                                          // on an unopened platform.
                                          ref.read(popularInlineSearchProvider.notifier).search(word);
                                          widget.onMenu(NavigationItem.hot);
                                        } else {
                                          ref.read(searchSiteIdProvider.notifier).selected = ref.read(
                                            selectedSiteIdProvider,
                                          );
                                          ref.read(pendingSearchProvider.notifier).hand(word);
                                          widget.onMenu(NavigationItem.search);
                                        }
                                      },
                                    ),
                                  ),
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

/// The where-am-I path at the content's head: the module, then the page.
///
/// The crumbs say where the viewer stands (the current page is the last
/// crumb, not pressed); deeper context — an area inside the areas page,
/// the query inside the search page — is that page's own breadcrumb, one
/// level below this one.
final class _LocationBreadcrumb extends StatelessWidget {
  const _LocationBreadcrumb({required this.module, required this.selected, this.settings});

  final AppModule module;
  final Object? selected;
  final SettingsSection? settings;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final section = settings;
    if (section != null) {
      return DsBreadcrumb(
        items: [
          DsBreadcrumbItem(label: t.navigation.settings, icon: const DsIcon(DsIcons.settings, size: 14)),
          DsBreadcrumbItem(label: section.label(t)),
        ],
      );
    }
    return DsBreadcrumb(
      items: [
        DsBreadcrumbItem(label: module.label(t), icon: DsIcon(module.icon, size: 14)),
        if (selected case final NavigationItem item) DsBreadcrumbItem(label: item.label(t)),
      ],
    );
  }
}

/// The toolbar's live search field: typing is real (unlike the old
/// tap-to-navigate stub), submitting pins the search scope to the
/// browsed platform and carries the word to the search page.
final class _ToolbarSearch extends StatefulWidget {
  const _ToolbarSearch({required this.hint, required this.onSubmitted, this.focusNode, this.shortcut});

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
