import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show StatefulNavigationShell;
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:pure_live/app/navigation/module_navigation.dart';
import 'package:pure_live/app/providers/environment_providers.dart' show platformRuntimeProvider;
import 'package:pure_live/app/providers/module_providers.dart';
import 'package:pure_live/app/providers/navigation_providers.dart';
import 'package:pure_live/app/providers/settings_section_provider.dart' show settingsSectionProvider;
import 'package:pure_live/app/providers/sidebar_providers.dart';
import 'package:pure_live/features/settings/settings_page.dart' show SettingsPage;
import 'package:pure_live/features/settings/settings_sections.dart' show SettingsSection;
import 'package:pure_live/features/tv/tv_shell.dart' show TvShell;
import 'package:pure_live/layouts/desktop/desktop_layout.dart';
import 'package:pure_live/layouts/mobile/mobile_layout.dart';
import 'package:pure_live/shared/enums/app_module.dart';
import 'package:pure_live/shared/enums/navigation_item.dart';
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
/// window width pick the layout — desktop expanded, desktop compact,
/// mobile bottom bar, or the TV rail — and the content area is the
/// router's indexed stack, one navigator per branch.
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

  /// The last destination shown outside settings: 返回应用 goes back here.
  NavigationItem? _lastAppItem;

  /// The window width the last dependency pass saw, null on the first;
  /// the sidebar's fold watches this for the crossing under
  /// [kExpandedSidebarBreakpoint].
  double? _lastWidth;

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

    // A TV build (the leanback launcher, the dart-define at boot) gets the
    // TV shell from the first frame: a remote cannot reach a touch UI.
    if (ref.watch(platformRuntimeProvider).environment.runtime.formFactor == FormFactor.tv) {
      return const TvShell();
    }
    final sidebar = ref.watch(sidebarProvider);
    final module = ref.watch(selectedModuleProvider);

    /// Shows [item]: the live module's entries are router branches (state
    /// and deep links live there), every other module renders the entry's
    /// page in place from [kModulePages].
    void showItem(NavigationItem item) {
      ref.read(selectedNavItemProvider.notifier).selected = item;
      if (module != AppModule.live) {
        setState(() {});
        return;
      }
      final branch = _branchIndexOf(item);
      if (branch != null) {
        widget.shell.goBranch(branch, initialLocation: branch == widget.shell.currentIndex);
      }
    }

    void handleSelected(NavigationItem item) {
      if (module == AppModule.live) {
        if (_branchIndexOf(item) == null) {
          return; // the page has not arrived yet.
        }
      } else if (item != NavigationItem.settings && !kModulePages.containsKey(item)) {
        return;
      }
      setState(() {
        // A fresh selection cuts the trail's future: forward is gone
        // until back has run.
        _trail.removeRange(_cursor + 1, _trail.length);
        if (_trail[_cursor] != item) {
          _trail.add(item);
          _cursor = _trail.length - 1;
        }
      });
      if (item != NavigationItem.settings) {
        _lastAppItem = item;
      }
      showItem(item);
    }

    // Settings is a destination of the same shell: while it is selected the
    // sidebar lists the settings sections instead of the module's business
    // entries — one menu, not a menu inside a menu. The section on screen
    // lives in a provider, because the sidebar picks it and the page shows
    // it across the shell.
    final inSettings = selected == NavigationItem.settings;
    final settingsSection = ref.watch(settingsSectionProvider);
    // One registry row per module decides both menus: the settings menu
    // shows the module's settings groups (alone — no home tools mixed in),
    // the app's menu its business block and shared tools.
    final navigation = navigationOf(module);
    final menuGroups = <List<Object>>[
      if (inSettings) ...[
        for (final group in navigation.settingsGroups) group.sections,
      ] else ...[
        navigation.business,
        navigation.tools,
      ],
    ];
    final Object menuValue = inSettings ? settingsSection : selected;

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

    if (breakpoint.index < kBottomBarBreakpoint.index) {
      return MobileLayout(
        content: moduleContent,
        module: module,
        selected: selected,
        onSelected: handleSelected,
        onModuleSelected: selectModule,
      );
    }
    return DesktopLayout(
      content: moduleContent,
      module: module,
      onModuleSelected: selectModule,
      menuGroups: menuGroups,
      menuValue: menuValue,
      onMenu: handleMenu,
      settingsSection: inSettings ? settingsSection : null,
      onBackToApp: () => handleSelected(_lastAppItem ?? defaultNavigationItemFor(AppModule.live)),
      // The toggle rules; a window crossing under the breakpoint folds
      // the sidebar once (didChangeDependencies), never outvoting this.
      expanded: sidebar.expanded,
      sidebarWidth: sidebar.width,
      onToggleSidebar: () => ref.read(sidebarProvider.notifier).toggle(),
      onSidebarWidthChanged: ref.read(sidebarProvider.notifier).setWidth,
      canBack: _cursor > 0,
      canForward: _cursor < _trail.length - 1,
      onBack: goBack,
      onForward: goForward,
    );
  }

}
