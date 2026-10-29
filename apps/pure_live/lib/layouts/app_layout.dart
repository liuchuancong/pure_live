import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show StatefulNavigationShell;
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/layouts/desktop/desktop_layout.dart';
import 'package:pure_live/layouts/mobile/mobile_layout.dart';
import 'package:pure_live/modules/hongguo/hongguo.dart' show hongguoLibraryProvider;
import 'package:pure_live/shared/shared.dart';
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

  /// Whether a selection that does not belong on screen is already waiting
  /// to move off it.
  bool _selectionFallbackScheduled = false;

  /// Moves the selection to [target] after this frame. The fallback is a
  /// microtask because a provider write during build is rejected; the build
  /// calls it when the selection is hidden by the navigation setting or
  /// belongs to another module's menu.
  void _scheduleSelectionFallback(NavigationItem target) {
    if (_selectionFallbackScheduled) return;
    _selectionFallbackScheduled = true;
    unawaited(
      Future<void>.microtask(() {
        _selectionFallbackScheduled = false;
        if (!mounted) return;
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
      }),
    );
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
    // Only a TV keeps the desktop shell at every width: a remote's D-pad
    // starts on the sidebar, and its canvas is never thumb-sized. Every
    // other platform follows the window — a Windows window dragged under
    // the bottom-bar breakpoint gets the mobile shell, whose top bar still
    // carries the caption strip and the window controls.
    final desktopShell = tv;
    final sidebar = ref.watch(sidebarProvider);
    final module = ref.watch(selectedModuleProvider);
    final homeMenu = ref.watch(navMenuProvider);
    // One registry row per module decides both menus: the settings menu
    // shows the module's settings groups (alone — no app entries mixed in),
    // the app's menu its blocks, a divider between them.
    final navigation = navigationOf(module);

    /// A home entry the navigation setting hides falls back to the first
    /// one still shown: no page may sit behind an absent menu row.
    NavigationItem visibleHomeItem(NavigationItem item) =>
        module == AppModule.live && kHomeMenuItems.contains(item) && !homeMenu.contains(item) ? homeMenu.first : item;

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
        // Settings opens on its categories again next time.
        ref.read(settingsSectionOpenProvider.notifier).open = false;
      }
      showItem(target);
    }

    // The selection must belong to the module on screen. A destination from
    // another module's menu — a hot reload can reset the selection while the
    // chosen module's state survives — would otherwise render that module's
    // page under this module's labels; a home entry the navigation setting
    // hid (startup with a restored menu list) has no row to sit on either.
    // Both land on an entry this module really shows, after this frame.
    final moduleItems = {for (final block in navigation.menu) ...block};
    final hiddenHome = module == AppModule.live && kHomeMenuItems.contains(selected) && !homeMenu.contains(selected);
    if (selected != NavigationItem.settings && (!moduleItems.contains(selected) || hiddenHome)) {
      final landing = navigation.landing;
      _scheduleSelectionFallback(
        module == AppModule.live && !homeMenu.contains(landing) && homeMenu.isNotEmpty ? homeMenu.first : landing,
      );
    }

    // Settings is a destination of the same shell: while it is selected the
    // sidebar lists the settings categories instead of the module's menu
    // blocks — one menu, not a menu inside a menu. The category and the
    // section page inside it live in providers, because the sidebar picks
    // the category and the page shows it across the shell.
    final inSettings = selected == NavigationItem.settings;
    final settingsSection = ref.watch(settingsSectionProvider);
    final settingsCategory = ref.watch(settingsCategoryProvider);
    final sectionOpen = ref.watch(settingsSectionOpenProvider);
    // The shelf's new episodes ride on the hongguo menu's favorites row,
    // the reference's badge: the number each favorite gained since the
    // series was last opened. Only the station that owns the shelf is
    // followed, so other modules never subscribe to it.
    final newEpisodes = module == AppModule.hongguo ? ref.watch(hongguoLibraryProvider).addedCount : 0;
    final badges = newEpisodes > 0 ? {NavigationItem.hongguoFavorites: newEpisodes} : const <NavigationItem, int>{};
    // The tools block follows the order the settings pane edits, not the
    // registry's fixed list; a stored order never drops a tool the
    // registry added later.
    final toolOrder = ref.watch(toolOrderProvider);
    final toolSet = toolOrder.toSet();
    final appMenu = [
      for (final block in navigation.menu)
        _orderedMenuBlock(
          block,
          toolSet: toolSet,
          toolOrder: toolOrder,
          homeMenuOrder: module == AppModule.live ? homeMenu : null,
        ),
    ]..removeWhere((block) => block.isEmpty);
    final menuGroups = <List<Object>>[];
    final menuGroupLabels = <String?>[];
    if (inSettings) {
      // One rail row per first-level category; the category's own page in
      // the content area lists the section pages under it.
      menuGroups.add([for (final group in navigation.settingsGroups) group.labelKey]);
      menuGroupLabels.add(null);
    } else {
      for (final block in appMenu) {
        menuGroups.add(block);
        menuGroupLabels.add(null);
      }
    }
    // A section page keeps its category row lit.
    final menuValue = inSettings ? settingsCategory : selected;

    void handleMenu(Object value) {
      switch (value) {
        case final NavigationItem item:
          handleSelected(item);
        case final String category:
          openSettingsCategory(ref, category);
      }
    }

    void goBack() {
      // Settings is a stack of its own: a nested section steps up to its
      // parent, a section closes to its category page, and only the
      // category level leaves the surface for the app trail.
      if (inSettings && sectionOpen) {
        final parent = settingsSection.canonical.parentSection;
        if (parent != null) {
          openSettingsSection(ref, parent);
        } else {
          closeSettingsSection(ref);
        }
        return;
      }
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
      // The module's settings menu may not carry the category or section
      // the last module was on; land on ones it does and show the category
      // page, not a stale section.
      final groups = navigationOf(next).settingsGroups;
      ref.read(settingsCategoryProvider.notifier).ensureWithin(groups);
      ref.read(settingsSectionProvider.notifier).ensureWithin(navigationOf(next).settingsSections);
      ref.read(settingsSectionOpenProvider.notifier).open = false;
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
      // An entry the module does not carry renders the module's landing
      // page, never another module's: the fallback above moves the
      // selection off it, this keeps the frame between free of the wrong
      // page.
      final page =
          (moduleItems.contains(selected) ? kModulePages[selected] : null) ?? kModulePages[navigation.landing]!;
      moduleContent = page();
    }
    // The scroll pair every page carries, mounted once here so the desktop,
    // mobile and TV shells all get it from the content area — under the
    // sidebar and the bottom bar, over the page. What is shown names it: a
    // tab the viewer switches to is kept alive off screen and never scrolls
    // on its own, so the pair has to be told to look again.
    final shownContent = ScrollEdgeControls(
      pageIdentity: inSettings
          ? '${module.name}/settings/${sectionOpen ? settingsSection.name : 'category/$settingsCategory'}'
          : '${module.name}/${selected.name}/',
      child: moduleContent,
    );

    // A TV keeps the desktop shell even on a narrow logical canvas: the
    // drawer and bottom bar belong to thumbs, and this shell's sidebar is
    // what a remote starts on. Every other platform hands the width to the
    // gate, so a Windows window shrunk past it lands on the mobile shell.
    if (breakpoint.index < kBottomBarBreakpoint.index && !desktopShell) {
      return MobileLayout(
        content: shownContent,
        module: module,
        selected: selected,
        onSelected: handleSelected,
        onModuleSelected: selectModule,
        onSearch: () => handleSelected(NavigationItem.search),
        homeMenuItems: homeMenu,
        badges: badges,
      );
    }
    return DesktopLayout(
      content: shownContent,
      module: module,
      onModuleSelected: selectModule,
      menuGroups: menuGroups,
      menuGroupLabels: menuGroupLabels,
      menuValue: menuValue,
      onMenu: handleMenu,
      badges: badges,
      settingsSection: inSettings ? settingsSection : null,
      settingsCategoryKey: inSettings ? settingsCategory : null,
      settingsSectionOpen: inSettings && sectionOpen,
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
      // A settings section page can step up even when the destination trail
      // has nothing behind it.
      canBack: _cursor > 0 || (inSettings && sectionOpen),
      canForward: _cursor < _trail.length - 1,
      onBack: goBack,
      onForward: goForward,
      tv: tv,
    );
  }

  /// One module menu block with its tools in the viewer's saved order.
  /// Only a block made entirely of tools is reordered; every other block
  /// keeps its registry order.
  static List<NavigationItem> _orderedMenuBlock(
    List<NavigationItem> block, {
    required Set<NavigationItem> toolSet,
    required List<NavigationItem> toolOrder,
    required List<NavigationItem>? homeMenuOrder,
  }) {
    // The home entries are one block: the navigation setting owns both
    // membership and order, so the tools' order must not treat the
    // recording centre's page as a tool.
    if (homeMenuOrder != null && block.every(kHomeMenuItems.contains)) {
      return [
        for (final item in homeMenuOrder)
          if (block.contains(item)) item,
      ];
    }
    // The tools block owns its order through the editor; a block that
    // mixes tools with pages keeps the rail's reading order, so only a
    // block made entirely of tools is reordered here.
    if (!block.every(toolSet.contains)) {
      return block;
    }
    final rest = [
      for (final item in block)
        if (!toolSet.contains(item)) item,
    ];
    final ordered = [
      for (final item in toolOrder)
        if (block.contains(item)) item,
    ];
    // A registry tool the editor has not stored yet keeps its place after
    // the ordered ones rather than disappearing.
    final orderedSet = ordered.toSet();
    return [
      ...rest,
      ...ordered,
      for (final item in block)
        if (toolSet.contains(item) && !orderedSet.contains(item)) item,
    ];
  }
}
