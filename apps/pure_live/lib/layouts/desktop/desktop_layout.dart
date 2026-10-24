import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/providers/sidebar_providers.dart';
import 'package:pure_live/app/providers/sites_providers.dart' show selectedSiteIdProvider;
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

/// The desktop layout, following the v4 navigation design: the self-drawn
/// title bar above ([WindowTitleBar] — its left corner holds the app icon
/// that hovers into the sidebar toggle, and the back and forward arrows
/// over the caller's visit trail) — below it the sidebar: the app
/// switcher on top ("Pure Live" and a dropdown chevron opening the
/// content types), the module's business menu under it (no section
/// headings), the shared tools under a divider, and settings pinned to
/// the foot — the menu scrolls when it must, settings never do; expanded
/// with labels at wide widths and folded to an icon rail with tooltips
/// below the breakpoint; a [SidebarResizer] between the sidebar and the
/// content drags the width (double-tap resets it, dragging it far left
/// puts the sidebar away); a search field opening the search destination
/// above the content.
///
/// The caption and the drag band go to the window host — the layout is the
/// app's, the window behaviour is `live_shell_desktop`'s. Which widths get
/// which sidebar is the caller's breakpoints, not this widget's.
final class DesktopLayout extends ConsumerStatefulWidget {
  /// A desktop layout over [content].
  const DesktopLayout({
    required this.content,
    required this.menuGroups,
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
    super.key,
  });

  /// The current screen.
  final Widget content;

  /// The sidebar's menu, one list per block; a divider separates the
  /// blocks. A live module's entries are [NavigationItem]s, the settings
  /// surface's are [SettingsSection]s — the same menu either way, which is
  /// the point: entering settings swaps the entries, not the sidebar.
  final List<List<Object>> menuGroups;

  /// The selected entry of the menu, when one is.
  final Object? menuValue;

  /// Fired when the viewer picks an entry.
  final ValueChanged<Object> onMenu;

  /// The section on screen while the settings surface is showing; null
  /// elsewhere, where only the foot's settings entry highlights.
  final SettingsSection? settingsSection;

  /// Leaves the settings surface for the app: the foot's own entry while
  /// the settings menu is what the sidebar shows (the reference's
  /// 返回应用), instead of stacking a second menu or a button on the page.
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

  void _setResizing(bool resizing) {
    if (_resizing != resizing) setState(() => _resizing = resizing);
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
  Widget _menuItem(Translations t, Object value) => switch (value) {
    final NavigationItem item => DsSidebarItem<Object>(
      value: item,
      leading: DsIcon(item.icon),
      label: Text(item.label(t)),
    ),
    final SettingsSection section => DsSidebarItem<Object>(
      value: section,
      leading: DsIcon(section.icon),
      label: Text(section.label(t)),
    ),
    _ => const SizedBox.shrink(),
  };

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final t = context.t;
    final theme = DsTheme.of(context);
    // A width remembered from a wider window yields to the content's
    // floor until the window grows again.
    final sidebarWidth = math.min(widget.sidebarWidth, MediaQuery.sizeOf(context).width - kSidebarContentFloor);
    final items = <Widget>[
      for (final (index, group) in widget.menuGroups.indexed) ...[
        if (index > 0) const SidebarDivider(),
        for (final entry in group) _menuItem(t, entry),
      ],
    ];
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyB, control: true): widget.onToggleSidebar,
        const SingleActivator(LogicalKeyboardKey.keyB, meta: true): widget.onToggleSidebar,
      },
      // The autofocus node keeps the shortcut alive when nothing on a page
      // holds focus; it is skipped in traversal, so Tab never lands here.
      child: Focus(
        autofocus: true,
        skipTraversal: true,
        child: ColoredBox(
          color: colors.surface,
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
                              style: DsSidebarStyle(width: sidebarWidth),
                              children: items,
                            ),
                          ),
                          // Settings stays in the foot whatever the menu's
                          // length: a second sidebar of one item, its top
                          // padding handed to the divider instead.
                          // The foot carries the one way in and the one way
                          // out: the settings entry on the app's menu, and
                          // 返回应用 while the settings menu is showing —
                          // the reference's arrangement.
                          DsSidebar<Object>(
                            collapsed: !widget.expanded,
                            value: widget.settingsSection == null ? null : NavigationItem.settings,
                            onChanged: widget.settingsSection == null
                                ? widget.onMenu
                                : (_) => widget.onBackToApp(),
                            style: DsSidebarStyle(width: sidebarWidth),
                            children: widget.settingsSection == null
                                ? [
                                    DsSidebarItem<Object>(
                                      value: NavigationItem.settings,
                                      leading: const DsIcon(DsIcons.settings),
                                      label: Text(t.navigation.settings),
                                    ),
                                  ]
                                : [
                                    DsSidebarItem<Object>(
                                      value: NavigationItem.settings,
                                      leading: const DsIcon(DsIcons.arrowLeft),
                                      label: Text(t.settings.backHome),
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
                                        ref.read(searchSiteIdProvider.notifier).selected = ref.read(selectedSiteIdProvider);
                                        ref.read(pendingSearchProvider.notifier).hand(word);
                                        widget.onMenu(NavigationItem.search);
                                      }
                                    },
                                  ),
                                ),
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
  const _ToolbarSearch({required this.hint, required this.onSubmitted});

  final String hint;
  final ValueChanged<String> onSubmitted;

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
      placeholder: widget.hint,
      onSubmitted: (word) {
        if (word.trim().isEmpty) return;
        widget.onSubmitted(word.trim());
        _field.clear();
      },
    );
  }
}
