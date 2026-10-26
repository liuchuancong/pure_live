import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show StatefulNavigationShell;
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:pure_live/app/navigation/module_navigation.dart';
import 'package:pure_live/app/providers/environment_providers.dart' show platformRuntimeProvider;
import 'package:pure_live/app/providers/module_providers.dart';
import 'package:pure_live/app/providers/nav_visibility_providers.dart'
    show kHomeMenuItems, navMenuProvider, showMultiviewProvider;
import 'package:pure_live/app/providers/navigation_providers.dart';
import 'package:pure_live/app/providers/settings_section_provider.dart' show settingsSectionProvider;
import 'package:pure_live/app/providers/sidebar_providers.dart';
import 'package:pure_live/features/settings/settings_page.dart' show SettingsPage;
import 'package:pure_live/features/settings/settings_sections.dart' show SettingsSection;
import 'package:pure_live/features/settings/tv_preferences.dart' show tvMenuExpandedProvider;
import 'package:pure_live/layouts/desktop/desktop_layout.dart';
import 'package:pure_live/layouts/mobile/mobile_layout.dart';
import 'package:pure_live/shared/enums/app_module.dart';
import 'package:pure_live/shared/enums/navigation_item.dart';
import 'package:pure_live/shared/enums/tool_order.dart' show toolOrderProvider;
import 'package:responsive_breakpoints/responsive_breakpoints.dart' show TailwindBreakpoint;

// No `show` clause: a wrapped import is what the save-time import
// organizer kept breaking apart.

/// The Tailwind breakpoint under which a shrinking window folds the
/// sidebar once, on the crossing: xl (<1280px). The toggle always gets it
/// back — the fold nudges, it does not outvote the viewer.
const TailwindBreakpoint kExpandedSidebarBreakpoint = TailwindBreakpoint.xl;

/// The Tailwind breakpoint below which a touch device takes the bottom
/// bar: under md (<768px).
const TailwindBreakpoint kBottomBarBreakpoint = TailwindBreakpoint.md;

/// Resolves [width] to the package's breakpoint scale: the last
/// breakpoint whose minimum width the window meets.
TailwindBreakpoint _breakpointOf(double width) => TailwindBreakpoint.values.lastWhere(
  (breakpoint) => width >= breakpoint.breakpoint,
  orElse: () => TailwindBreakpoint.xs,
);

/// The branches the router built, in branch order — the index a
/// destination maps to when its page exists.
const List<NavigationItem> _kBranchOrder = [
  NavigationItem.hot,
  NavigationItem.zones,
  NavigationItem.live,
  NavigationItem.favorites,
  NavigationItem.history,
  NavigationItem.search,
  NavigationItem.multiview,
  NavigationItem.record,
  NavigationItem.toolbox,
  NavigationItem.settings,
];

int? _branchIndexOf(NavigationItem item) {
  final index = _kBranchOrder.indexOf(item);
  return index < 0 ? null : index;
}

/// The shell every branch renders inside: the device profile and the
/// window width pick the layout — desktop expanded, desktop compact, or
/// the mobile bottom bar — and the content area is the router's indexed
/// stack, one navigator per branch.
///
/// A TV runs the desktop shell too: every page is already reachable by a
/// D-pad (the sidebar takes the first focus, the card grids walk by index
/// and scroll their target into view), so there is no second UI to keep in
/// step.
///
/// The desktop title bar's back and forward arrows walk the trail of
/// destinations the viewer visited, this widget's own record: go_router's
/// typed `go` navigation has no forward history of its own.
///
/// Destinations whose pages have not arrived yet sit in the sidebar but
/// do not navigate; a selection only moves when the destination has a
/// branch, so the highlight never lies about what is on screen.
final class AppLayout extends ConsumerStatefulWidget {
  /// The app's layout shell around the router's [shell].
  const AppLayout({required this.shell, super.key});

  /// The indexed-stack shell the router built.
  final StatefulNavigationShell shell;

  @override
  ConsumerState<AppLayout> createState() => _AppLayoutState();
}

final class _AppLayoutState extends ConsumerState<AppLayout> {
  /// The destinations the viewer visited, in visit order; the one at
  /// [_cursor] is on screen, and back and forward move along them.
  final List<NavigationItem> _trail = [NavigationItem.hot];

  int _cursor = 0;

  /// The last destination shown outside settings: "Back to app" goes back here.
  NavigationItem? _lastAppItem;

  /// The window width the last dependency pass saw, null on the first;
  /// the sidebar's fold watches this for the crossing under
  /// [kExpandedSidebarBreakpoint].
  double? _lastWidth;

  /// Whether a selected home entry that the navigation setting just hid is
  /// already waiting to fall back to the first visible one.
  bool _homeFallbackScheduled = false;

  /// Moves a selection off a home entry the navigation setting hides. The
  /// fallback is a microtask because a provider write during build is
  /// rejected; the build calls it after reading the selection.
  void _scheduleHomeFallback() {
    if (_homeFallbackScheduled) return;
    _homeFallbackScheduled = true;
    unawaited(Future<void>.microtask(() {
      _homeFallbackScheduled = false;
      if (!mounted) return;
      final home = ref.read(navMenuProvider);
      if (home.isEmpty) return;
      final target = home.first;
      _lastAppItem = target;
      ref.read(selectedNavItemProvider.notifier).selected = target;
      final branch = _branchIndexOf(target);
      if (branch != null) {
        widget.shell.goBranch(branch, initialLocation: branch == widget.shell.currentIndex);
      }
      setState(() {
        _trail
          ..clear()
          ..add(target);
        _cursor = 0;
      });
    }));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final width = MediaQuery.sizeOf(context).width;
    final previous = _lastWidth;
    _lastWidth = width;
    final under = kExpandedSidebarBreakpoint.breakpoint;
    final crossed = previous != null && previous >= under && width < under;
    if (crossed || (previous == null && width < under)) {
      // Riverpod rejects a provider write inside the build phase; the
      // fold lands a microtask later, before the frame paints.
      unawaited(
        Future<void>.microtask(() {
          if (!mounted) return;
          ref.read(sidebarProvider.notifier).collapse();
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final breakpoint = _breakpointOf(MediaQuery.sizeOf(context).width);
    final selected = ref.watch(selectedNavItemProvider);
    final formFactor = ref.watch(platformRuntimeProvider).environment.runtime.formFactor;
    final tv = formFactor == FormFactor.tv;
    // A desktop platform keeps the desktop shell at every window width: the
    // sidebar is the window's navigation, and a narrow window must not lose
    // it to the touch drawer. A phone or tablet still gets the bottom bar.
    final desktopShell = formFactor == FormFactor.desktop || tv;
    final sidebar = ref.watch(sidebarProvider);
    final module = ref.watch(selectedModuleProvider);
    final homeMenu = ref.watch(navMenuProvider);

    /// A home entry the navigation setting hides falls back to the first
    /// one still shown: no page may sit behind an absent menu row.
    NavigationItem visibleHomeItem(NavigationItem item) =>
        module == AppModule.live && kHomeMenuItems.contains(item) && !homeMenu.contains(item)
        ? homeMenu.first
        : item;

    /// Shows [item]: the live module's entries are router branches (state
    /// and deep links live there), every other module renders the entry's
    /// page in place from [kModulePages].
    void showItem(NavigationItem item) {
      final target = visibleHomeItem(item);
      ref.read(selectedNavItemProvider.notifier).selected = target;
      if (module != AppModule.live) {
        setState(() {});
        return;
      }
      final branch = _branchIndexOf(target);
      if (branch != null) {
        widget.shell.goBranch(branch, initialLocation: branch == widget.shell.currentIndex);
      }
    }

    void handleSelected(NavigationItem item) {
      final target = visibleHomeItem(item);
      if (module == AppModule.live) {
        if (_branchIndexOf(target) == null) {
          return; // the page has not arrived yet.
        }
      } else if (target != NavigationItem.settings && !kModulePages.containsKey(target)) {
        return;
      }
      setState(() {
        // A fresh selection cuts the trail's future: forward is gone
        // until back has run.
        _trail.removeRange(_cursor + 1, _trail.length);
        if (_trail[_cursor] != target) {
          _trail.add(target);
          _cursor = _trail.length - 1;
        }
      });
      if (target != NavigationItem.settings) {
        _lastAppItem = target;
      }
      showItem(target);
    }

    // A selection left on an entry the navigation setting hid (startup with
    // a restored menu list, or a restore while the page is open) moves to
    // the first visible one after this frame.
    if (module == AppModule.live && kHomeMenuItems.contains(selected) && !homeMenu.contains(selected)) {
      _scheduleHomeFallback();
    }

    // Settings is a destination of the same shell: while it is selected the
    // sidebar lists the settings sections instead of the module's menu
    // blocks — one menu, not a menu inside a menu. The section on screen
    // lives in a provider, because the sidebar picks it and the page shows
    // it across the shell.
    final inSettings = selected == NavigationItem.settings;
    final settingsSection = ref.watch(settingsSectionProvider);
    // One registry row per module decides both menus: the settings menu
    // shows the module's settings groups (alone — no app entries mixed in),
    // the app's menu its blocks, a divider between them.
    final navigation = navigationOf(module);
    // The navigation setting's entry toggle: a switched-off multi-view is
    // not listed, and an emptied block takes its divider with it.
    final showMultiview = ref.watch(showMultiviewProvider);
    // The tools block follows the order the settings pane edits, not the
    // registry's fixed list; a hidden multi-view stays out, and a stored
    // order never drops a tool the registry added later.
    final toolOrder = ref.watch(toolOrderProvider);
    final toolSet = toolOrder.toSet();
    final appMenu = [
      for (final block in navigation.menu)
        _orderedMenuBlock(
          block,
          toolSet: toolSet,
          toolOrder: toolOrder,
          showMultiview: showMultiview,
          homeMenuOrder: module == AppModule.live ? homeMenu : null,
        ),
    ]..removeWhere((block) => block.isEmpty);
    final menuGroups = <List<Object>>[];
    final menuGroupLabels = <String?>[];
    if (inSettings) {
      // The module's own settings groups, exactly as its registry row
      // declares them; the label is the group's name in the rail.
      for (final group in navigation.settingsGroups) {
        menuGroups.add(group.sections);
        menuGroupLabels.add(group.labelKey);
      }
    } else {
      for (final block in appMenu) {
        menuGroups.add(block);
        menuGroupLabels.add(null);
      }
    }
    // A page nested under Personalization keeps that row lit: the menu no
    // longer lists the children themselves.
    final Object menuValue = inSettings ? settingsSection.menuSection : selected;

    void handleMenu(Object value) {
      switch (value) {
        case final NavigationItem item:
          handleSelected(item);
        case final SettingsSection section:
          ref.read(settingsSectionProvider.notifier).section = section;
      }
    }

    void goBack() {
      if (_cursor == 0) return;
      setState(() => _cursor--);
      showItem(_trail[_cursor]);
    }

    void goForward() {
      if (_cursor >= _trail.length - 1) return;
      setState(() => _cursor++);
      showItem(_trail[_cursor]);
    }

    /// The app switcher's choice: the module's own landing page comes with
    /// it — live opens on the hot feed's branch (its content is the routed
    /// shell), the others mark their landing destination while the module's
    /// page takes the content area. The window and its chrome stay; only
    /// the business menu and the content area swap.
    void selectModule(AppModule next) {
      ref.read(selectedModuleProvider.notifier).selected = next;
      final landing = defaultNavigationItemFor(next);
      ref.read(selectedNavItemProvider.notifier).selected = landing;
      // The module's settings menu may not carry the section the last
      // module was on; keep the pane on a row that exists.
      ref.read(settingsSectionProvider.notifier).ensureWithin(navigationOf(next).settingsSections);
      _lastAppItem = landing;
      if (next == AppModule.live) {
        handleSelected(landing);
      } else {
        setState(() {});
      }
    }

    // The module's entry surface: live keeps the router's branch shell —
    // its destinations are routes — while each other module renders its
    // own entry page; a module whose page has not arrived yet falls back
    // to the placeholder rather than failing to build.
    // The live module keeps its routed branch shell; the others resolve
    // the selected entry through the registry (settings is a page there
    // too, which is what makes one settings surface work in every module).
    final Widget moduleContent;
    if (module == AppModule.live) {
      moduleContent = widget.shell;
    } else if (selected == NavigationItem.settings) {
      moduleContent = const SettingsPage();
    } else {
      final page = kModulePages[selected] ?? kModulePages[navigation.landing]!;
      moduleContent = page();
    }

    // A TV keeps the desktop shell even on a narrow logical canvas: the
    // drawer and bottom bar belong to thumbs, and this shell's sidebar is
    // what a remote starts on.
    if (breakpoint.index < kBottomBarBreakpoint.index && !desktopShell) {
      return MobileLayout(
        content: moduleContent,
        module: module,
        selected: selected,
        onSelected: handleSelected,
        onModuleSelected: selectModule,
        onSearch: () => handleSelected(NavigationItem.search),
        settingsSection: inSettings ? settingsSection : null,
        showMultiview: showMultiview,
        homeMenuItems: homeMenu,
      );
    }
    return DesktopLayout(
      content: moduleContent,
      module: module,
      onModuleSelected: selectModule,
      menuGroups: menuGroups,
      menuGroupLabels: menuGroupLabels,
      menuValue: menuValue,
      onMenu: handleMenu,
      settingsSection: inSettings ? settingsSection : null,
      onBackToApp: () => handleSelected(_lastAppItem ?? defaultNavigationItemFor(AppModule.live)),
      // The toggle rules; a window crossing under the breakpoint folds
      // the sidebar once (didChangeDependencies), never outvoting this.
      expanded: (tv && ref.watch(tvMenuExpandedProvider)) || sidebar.expanded,
      sidebarWidth: sidebar.width,
      onToggleSidebar: () {
        if (tv && ref.read(tvMenuExpandedProvider)) {
          unawaited(ref.read(tvMenuExpandedProvider.notifier).set(value: false));
        } else {
          ref.read(sidebarProvider.notifier).toggle();
        }
      },
      onSidebarWidthChanged: ref.read(sidebarProvider.notifier).setWidth,
      canBack: _cursor > 0,
      canForward: _cursor < _trail.length - 1,
      onBack: goBack,
      onForward: goForward,
      tv: tv,
    );
  }

  /// One module menu block with its tools in the viewer's saved order.
  /// Blocks without tools keep their registry order.
  static List<NavigationItem> _orderedMenuBlock(
    List<NavigationItem> block, {
    required Set<NavigationItem> toolSet,
    required List<NavigationItem> toolOrder,
    required bool showMultiview,
    required List<NavigationItem>? homeMenuOrder,
  }) {
    bool shown(NavigationItem item) => showMultiview || item != NavigationItem.multiview;
    // The home entries are one block: the navigation setting owns both
    // membership and order, so the tools' order must not treat the
    // recording centre's page as a tool.
    if (homeMenuOrder != null && block.every(kHomeMenuItems.contains)) {
      return [
        for (final item in homeMenuOrder)
          if (block.contains(item)) item,
      ];
    }
    if (!block.any(toolSet.contains)) {
      return [
        for (final item in block)
          if (shown(item)) item,
      ];
    }
    final rest = [
      for (final item in block)
        if (!toolSet.contains(item) && shown(item)) item,
    ];
    final ordered = [
      for (final item in toolOrder)
        if (block.contains(item) && shown(item)) item,
    ];
    // A registry tool the editor has not stored yet keeps its place after
    // the ordered ones rather than disappearing.
    final orderedSet = ordered.toSet();
    return [
      ...rest,
      ...ordered,
      for (final item in block)
        if (toolSet.contains(item) && !orderedSet.contains(item) && shown(item)) item,
    ];
  }
}
