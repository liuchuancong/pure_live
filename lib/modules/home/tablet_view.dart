import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/consts/app_consts.dart';

class HomeTabletView extends StatelessWidget {
  final Widget body;
  final int index;
  final void Function(int) onDestinationSelected;

  const HomeTabletView({super.key, required this.body, required this.index, required this.onDestinationSelected});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Obx(() {
          final List<NavigationRailDestination> destinations = [];
          final List<int> virtualToRealMap = [];
          final activeMenuIds = SettingsService.to.app.savedMenuIds.v;

          for (String id in activeMenuIds) {
            final menu = HomeMenu.fromId(id);
            if (menu != null) {
              virtualToRealMap.add(menu.index);

              switch (menu) {
                case HomeMenu.favorites:
                  destinations.add(
                    NavigationRailDestination(
                      icon: const Icon(Icons.favorite_rounded),
                      label: Text(i18n("favorites_title")),
                    ),
                  );
                  break;
                case HomeMenu.popular:
                  destinations.add(
                    NavigationRailDestination(
                      icon: const Icon(CustomIcons.popular),
                      label: Text(i18n("popular_title")),
                    ),
                  );
                  break;
                case HomeMenu.areas:
                  destinations.add(
                    NavigationRailDestination(icon: const Icon(Remix.dashboard_line), label: Text(i18n("areas_title"))),
                  );
                  break;
                case HomeMenu.record:
                  destinations.add(
                    NavigationRailDestination(
                      icon: const Icon(Remix.download_2_fill),
                      label: Text(i18n("record_center")),
                    ),
                  );
                  break;
              }
            }
          }

          int activeSelectedIndex = virtualToRealMap.indexOf(index);
          if (activeSelectedIndex == -1) {
            activeSelectedIndex = 0;
          }

          final bool isRailVisible = destinations.length > 1;

          return Row(
            children: [
              if (isRailVisible) ...[
                NavigationRail(
                  groupAlignment: 0.9,
                  labelType: NavigationRailLabelType.all,
                  leading: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(padding: EdgeInsets.all(12), child: MenuButton()),
                      Padding(
                        padding: const EdgeInsets.only(top: 0, bottom: 12, left: 12, right: 12),
                        child: IconButton(
                          onPressed: () => Get.toNamed(RoutePath.kToolbox),
                          icon: const Icon(Icons.link),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 0, bottom: 12, left: 12, right: 12),
                        child: IconButton(
                          onPressed: () => Get.toNamed(RoutePath.kSearch),
                          icon: const Icon(CustomIcons.search),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 0, bottom: 12, left: 12, right: 12),
                        child: IconButton(
                          onPressed: () => Get.toNamed(RoutePath.kRecordPage),
                          icon: const Icon(Remix.download_2_fill),
                        ),
                      ),
                    ],
                  ),
                  destinations: destinations,
                  selectedIndex: activeSelectedIndex,
                  onDestinationSelected: (int virtualIndex) {
                    if (virtualIndex < virtualToRealMap.length) {
                      onDestinationSelected(virtualToRealMap[virtualIndex]);
                    }
                  },
                ),
                const VerticalDivider(width: 1),
              ],
              Expanded(child: body),
            ],
          );
        }),
      ),
    );
  }
}
