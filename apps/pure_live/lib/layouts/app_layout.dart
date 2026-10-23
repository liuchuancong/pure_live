import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/providers/environment_providers.dart' show DeviceProfile, deviceProfileProvider;
import 'package:pure_live/app/providers/navigation_providers.dart' show selectedNavItemProvider;
import 'package:pure_live/i18n/translations.g.dart';
import 'package:pure_live/layouts/desktop/desktop_layout.dart' show DesktopLayout;
import 'package:pure_live/layouts/mobile/mobile_layout.dart' show MobileLayout;
import 'package:pure_live/layouts/tv/tv_layout.dart' show TvLayout;
import 'package:pure_live/shared/enums/navigation_item.dart' show kMobileNavigationItems, kNavigationItems;
import 'package:pure_live/shared/enums/navigation_item.dart' show NavigationItem;

/// The shell every branch renders inside: the device profile picks the
/// layout, the layouts share the navigation destinations, and the content
/// area holds the current screen.
///
/// Until the pages arrive the content area is an honest empty state naming
/// the selected destination.
final class AppLayout extends ConsumerWidget {
  /// The app's layout shell.
  const AppLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(deviceProfileProvider);
    final selected = ref.watch(selectedNavItemProvider);
    final selectedIndex = kNavigationItems.indexOf(selected);
    void handleSelected(int index) {
      ref.read(selectedNavItemProvider.notifier).selected = kNavigationItems[index];
    }

    final content = _DestinationPlaceholder(item: selected);
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
        selectedIndex: kMobileNavigationItems.indexOf(selected),
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

final class _DestinationPlaceholder extends ConsumerWidget {
  const _DestinationPlaceholder({required this.item});

  final NavigationItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return Center(
      child: DsEmptyState(title: Text(item.label(t)), icon: DsIcon(item.icon)),
    );
  }
}
