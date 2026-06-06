import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/consts/app_consts.dart';

class HomeMobileView extends StatelessWidget {
  final Widget body;
  final int index;
  final void Function(int) onDestinationSelected;
  final void Function()? onFavoriteDoubleTap;

  const HomeMobileView({
    super.key,
    required this.body,
    required this.index,
    required this.onDestinationSelected,
    required this.onFavoriteDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: Obx(() {
        final List<NavigationDestination> destinations = [];
        final List<int> virtualToRealMap = [];
        final activeMenuIds = SettingsService.to.app.savedMenuIds.v;
        for (String id in activeMenuIds) {
          final menu = HomeMenu.fromId(id);
          if (menu != null) {
            virtualToRealMap.add(menu.index);
            switch (menu) {
              case HomeMenu.favorites:
                destinations.add(
                  NavigationDestination(
                    icon: GestureDetector(onDoubleTap: onFavoriteDoubleTap, child: const Icon(Icons.favorite_rounded)),
                    label: i18n("favorites_title"),
                  ),
                );
                break;
              case HomeMenu.popular:
                destinations.add(
                  NavigationDestination(icon: const Icon(CustomIcons.popular), label: i18n("popular_title")),
                );
                break;
              case HomeMenu.areas:
                destinations.add(
                  NavigationDestination(icon: const Icon(Remix.dashboard_line), label: i18n("areas_title")),
                );
                break;
              case HomeMenu.record:
                destinations.add(
                  NavigationDestination(icon: const Icon(Remix.download_2_fill), label: i18n("record_center")),
                );
                break;
            }
          }
        }
        if (destinations.length <= 1) return const SizedBox.shrink();
        int activeSelectedIndex = virtualToRealMap.indexOf(index);
        if (activeSelectedIndex == -1) {
          activeSelectedIndex = 0;
        }
        return NavigationBar(
          destinations: destinations,
          selectedIndex: activeSelectedIndex,
          onDestinationSelected: (int virtualIndex) {
            if (virtualIndex < virtualToRealMap.length) {
              onDestinationSelected(virtualToRealMap[virtualIndex]);
            }
          },
        );
      }),
      body: body,
    );
  }
}
