// Every import stays on one line with no `show` clause: the save-time
// import organizer used to tear wrapped imports apart, so nothing here
// may wrap. Do not add a wrapped import to this file.
import 'dart:math' as math;
import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/providers/sidebar_providers.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/layouts/app_switcher.dart';
import 'package:pure_live/layouts/desktop/sidebar_resizer.dart';
import 'package:pure_live/layouts/desktop/title_bar.dart';
import 'package:pure_live/shared/enums/app_module.dart';
import 'package:pure_live/shared/enums/navigation_item.dart';



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
    required this.business,
    required this.selected,
    required this.onSelected,
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
    super.key,
  });

  /// The current screen.
  final Widget content;

  /// The module's business menu: the sidebar's top block, no headings.
  final List<NavigationItem> business;

  /// The selected destination.
  final NavigationItem selected;

  /// Fired when the viewer picks a destination.
  final ValueChanged<NavigationItem> onSelected;

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

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final t = context.t;
    final theme = DsTheme.of(context);
    // A width remembered from a wider window yields to the content's
    // floor until the window grows again.
    final sidebarWidth = math.min(widget.sidebarWidth, MediaQuery.sizeOf(context).width - kSidebarContentFloor);
    final items = [
      for (final item in widget.business)
        DsSidebarItem(value: item, leading: DsIcon(item.icon), label: Text(item.label(t))),
      const SidebarDivider(),
      for (final item in kToolItems)
        DsSidebarItem(value: item, leading: DsIcon(item.icon), label: Text(item.label(t))),
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
                              header: AppSwitcher(
                                collapsed: !widget.expanded,
                                module: widget.module,
                                onModule: widget.onModuleSelected,
                              ),
                              value: widget.selected,
                              onChanged: widget.onSelected,
                              style: DsSidebarStyle(width: sidebarWidth),
                              children: items,
                            ),
                          ),
                          // Settings stays in the foot whatever the menu's
                          // length: a second sidebar of one item, its top
                          // padding handed to the divider instead.
                          DsSidebar(
                            collapsed: !widget.expanded,
                            value: widget.selected,
                            onChanged: widget.onSelected,
                            style: DsSidebarStyle(
                              width: sidebarWidth,
                              padding: const EdgeInsetsDirectional.only(bottom: DsSpace.s16),
                            ),
                            children: [
                              const SidebarDivider(),
                              DsSidebarItem(
                                value: NavigationItem.settings,
                                leading: const DsIcon(DsIcons.settings),
                                label: Text(t.navigation.settings),
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
                                  child: _LocationBreadcrumb(module: widget.module, selected: widget.selected),
                                ),
                                const SizedBox(width: DsSpace.s16),
                                SizedBox(
                                  width: 320,
                                  child: GestureDetector(
                                    onTap: () => widget.onSelected(NavigationItem.search),
                                    child: AbsorbPointer(child: DsSearchField(placeholder: t.common.searchHint)),
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
  const _LocationBreadcrumb({required this.module, required this.selected});

  final AppModule module;
  final NavigationItem selected;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return DsBreadcrumb(
      items: [
        DsBreadcrumbItem(label: module.label(t), icon: DsIcon(module.icon, size: 14)),
        DsBreadcrumbItem(label: selected.label(t)),
      ],
    );
  }
}
