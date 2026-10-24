import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show StatefulNavigationShell;
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:pure_live/app/providers/environment_providers.dart' show platformRuntimeProvider;
import 'package:pure_live/app/providers/module_providers.dart';
import 'package:pure_live/app/providers/navigation_providers.dart';
import 'package:pure_live/app/providers/sidebar_providers.dart';
import 'package:pure_live/features/iptv/iptv_page.dart' show IptvPage;
import 'package:pure_live/features/music/music_page.dart' show MusicPage;
import 'package:pure_live/features/tv/tv_shell.dart' show TvShell;
import 'package:pure_live/features/vod/vod_page.dart' show VodPage;
import 'package:pure_live/l10n/translations.dart';
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
  NavigationItem.home,
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

/// Destinations that share a branch with another: the hot feed is the
/// home branch — "热门" is the feed's name in the navigation, "home" is
/// its route.
const Map<NavigationItem, NavigationItem> _kBranchAliases = {
  NavigationItem.hot: NavigationItem.home,
};

NavigationItem _branchItemOf(NavigationItem item) => _kBranchAliases[item] ?? item;

int? _branchIndexOf(NavigationItem item) {
  final index = _kBranchOrder.indexOf(_branchItemOf(item));
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

    void handleSelected(NavigationItem item) {
      if (_branchIndexOf(item) == null) {
        return; // the page has not arrived yet.
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
      _go(item);
    }

    void goBack() {
      if (_cursor == 0) return;
      setState(() => _cursor--);
      _go(_trail[_cursor]);
    }

    void goForward() {
      if (_cursor >= _trail.length - 1) return;
      setState(() => _cursor++);
      _go(_trail[_cursor]);
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
      if (next == AppModule.live) handleSelected(landing);
    }

    // The module's entry surface: live keeps the router's branch shell —
    // its destinations are routes — while each other module renders its
    // own entry page; a module whose page has not arrived yet falls back
    // to the placeholder rather than failing to build.
    final moduleContent = module == AppModule.live
        ? widget.shell
        : switch (module) {
            AppModule.iptv => const IptvPage(),
            AppModule.vod => const VodPage(),
            AppModule.music => const MusicPage(),
            _ => _ModulePlaceholder(module: module),
          };

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
      business: kModuleBusinessItems[module]!,
      selected: selected,
      onSelected: handleSelected,
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

  /// Shows [item]'s branch without touching the trail; a revisit of the
  /// branch the shell already shows relinks to the page's root.
  void _go(NavigationItem item) {
    final branch = _branchIndexOf(item);
    if (branch == null) return;
    ref.read(selectedNavItemProvider.notifier).selected = item;
    widget.shell.goBranch(branch, initialLocation: branch == widget.shell.currentIndex);
  }
}


/// What a module without its pages yet shows: the module's icon and its
/// name, honest about the wait.
final class _ModulePlaceholder extends StatelessWidget {
  const _ModulePlaceholder({required this.module});

  final AppModule module;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return DsEmptyState(
      icon: DsIcon(module.icon),
      title: Text(module.label(t)),
      description: Text(t.common.moduleComingSoon),
    );
  }
}
