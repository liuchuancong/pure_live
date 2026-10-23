import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:responsive_breakpoints/responsive_breakpoints.dart' show TailwindBreakpoint;
import 'package:go_router/go_router.dart' show StatefulNavigationShell;

import 'package:pure_live/app/providers/environment_providers.dart' show DeviceProfile, deviceProfileProvider;
import 'package:pure_live/app/providers/navigation_providers.dart' show selectedNavItemProvider;
import 'package:pure_live/layouts/desktop/desktop_layout.dart' show DesktopLayout;
import 'package:pure_live/layouts/mobile/mobile_layout.dart' show MobileLayout;
import 'package:pure_live/layouts/tv/tv_layout.dart' show TvLayout;
import 'package:pure_live/shared/enums/navigation_item.dart'
    show NavigationItem, kContentItems, kMobileNavigationItems, kPersonalItems, kPrimaryItems;

/// The Tailwind breakpoint from which the desktop sidebar shows its
/// labels: xl (≥1280px). Below it the sidebar folds to icons.
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
  NavigationItem.live,
  NavigationItem.favorites,
  NavigationItem.history,
  NavigationItem.search,
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
/// Destinations whose pages have not arrived yet sit in the sidebar but
/// do not navigate; a selection only moves when the destination has a
/// branch, so the highlight never lies about what is on screen.
final class AppLayout extends ConsumerWidget {
  /// The app's layout shell around the router's [shell].
  const AppLayout({required this.shell, super.key});

  /// The indexed-stack shell the router built.
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(deviceProfileProvider);
    final breakpoint = _breakpointOf(MediaQuery.sizeOf(context).width);
    final selected = ref.watch(selectedNavItemProvider);

    void handleSelected(NavigationItem item) {
      final branch = _branchIndexOf(item);
      if (branch == null) {
        return; // the page has not arrived yet.
      }
      ref.read(selectedNavItemProvider.notifier).selected = item;
      shell.goBranch(branch, initialLocation: branch == shell.currentIndex);
    }

    if (device == DeviceProfile.tv) {
      const items = kPrimaryItems;
      final index = items.indexOf(selected);
      return TvLayout(
        content: shell,
        items: items,
        selectedIndex: index < 0 ? 0 : index,
        onSelected: (index) => handleSelected(items[index]),
      );
    }
    if (device == DeviceProfile.mobile || breakpoint.index < kBottomBarBreakpoint.index) {
      const items = kMobileNavigationItems;
      final index = items.indexOf(selected);
      return MobileLayout(
        content: shell,
        items: items,
        selectedIndex: index < 0 ? 0 : index,
        onSelected: (index) => handleSelected(items[index]),
      );
    }
    return DesktopLayout(
      content: shell,
      groups: const [
        ('groupPrimary', kPrimaryItems),
        ('groupContent', kContentItems),
        ('groupPersonal', kPersonalItems),
      ],
      selected: selected,
      onSelected: handleSelected,
      expanded: breakpoint.index >= kExpandedSidebarBreakpoint.index,
    );
  }
}
