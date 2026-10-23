import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show StatefulNavigationShell;

import 'package:pure_live/app/providers/environment_providers.dart' show DeviceProfile, deviceProfileProvider;
import 'package:pure_live/layouts/desktop/desktop_layout.dart' show DesktopLayout;
import 'package:pure_live/layouts/mobile/mobile_layout.dart' show MobileLayout;
import 'package:pure_live/layouts/tv/tv_layout.dart' show TvLayout;
import 'package:pure_live/shared/enums/navigation_item.dart' show kMobileNavigationItems, kNavigationItems;

/// The shell every branch renders inside: the device profile picks the
/// layout, the layouts share the navigation destinations, and the content
/// area is the router's indexed stack — one navigator per branch, so the
/// destinations keep their state while the chrome changes per device.
final class AppLayout extends ConsumerWidget {
  /// The app's layout shell around the router's [shell].
  const AppLayout({required this.shell, super.key});

  /// The indexed-stack shell the router built.
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(deviceProfileProvider);
    final selectedIndex = shell.currentIndex;

    void handleSelected(int index) {
      shell.goBranch(index, initialLocation: index == selectedIndex);
    }

    final content = shell;
    return switch (device) {
      DeviceProfile.tv => TvLayout(
        content: content,
        items: kNavigationItems,
        selectedIndex: selectedIndex,
        onSelected: handleSelected,
      ),
      DeviceProfile.mobile => MobileLayout(
        content: content,
        items: kMobileNavigationItems,
        selectedIndex: selectedIndex.clamp(0, kMobileNavigationItems.length - 1),
        onSelected: handleSelected,
      ),
      DeviceProfile.desktop => DesktopLayout(
        content: content,
        items: kNavigationItems,
        selectedIndex: selectedIndex,
        onSelected: handleSelected,
      ),
    };
  }
}
