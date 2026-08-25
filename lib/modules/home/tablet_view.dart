import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/common/consts/app_consts.dart';

class HomeTabletView extends StatelessWidget {
  final Widget body;
  final int index;
  final List<String> activeMenuIds;
  final bool showRecord;
  final void Function(int) onDestinationSelected;

  const HomeTabletView({
    super.key,
    required this.body,
    required this.index,
    required this.activeMenuIds,
    required this.showRecord,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Builder(
          builder: (context) {
            final List<NavigationRailDestination> destinations = [];
            final List<int> virtualToRealMap = [];

            for (String id in activeMenuIds) {
              final menu = HomeMenu.fromId(id);
              if (menu != null) {
                virtualToRealMap.add(menu.index);

                switch (menu) {
                  case HomeMenu.favorites:
                    destinations.add(
                      NavigationRailDestination(
                        icon: const Icon(Remix.heart_3_line),
                        selectedIcon: const Icon(Remix.heart_3_fill),
                        label: Text(i18n("favorites_title")),
                      ),
                    );
                    break;
                  case HomeMenu.popular:
                    destinations.add(
                      NavigationRailDestination(
                        icon: const Icon(Remix.fire_line),
                        selectedIcon: const Icon(Remix.fire_fill),
                        label: Text(i18n("popular_title")),
                      ),
                    );
                    break;
                  case HomeMenu.areas:
                    destinations.add(
                      NavigationRailDestination(
                        icon: const Icon(Remix.apps_2_line),
                        selectedIcon: const Icon(Remix.apps_2_fill),
                        label: Text(i18n("areas_title")),
                      ),
                    );
                    break;
                  case HomeMenu.record:
                    destinations.add(
                      NavigationRailDestination(
                        icon: const Icon(Remix.download_2_line),
                        selectedIcon: const Icon(Remix.download_2_fill),
                        label: Text(i18n("record_center")),
                      ),
                    );
                    break;
                }
              }
            }

            int? activeSelectedIndex;
            final pos = virtualToRealMap.indexOf(index);
            if (pos >= 0 && pos < destinations.length) {
              activeSelectedIndex = pos;
            } else {
              activeSelectedIndex = null;
            }

            return Row(
              children: [
                NavigationRail(
                  groupAlignment: 0.9,
                  labelType: NavigationRailLabelType.all,
                  leading: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(padding: EdgeInsets.all(12), child: MenuButton()),
                      Obx(
                        () => SettingsService.to.app.enableMultiView.v
                            ? Padding(
                                padding: const EdgeInsets.only(top: 0, bottom: 12, left: 12, right: 12),
                                child: IconButton(
                                  onPressed: () => AppNavigator.toMultiview(),
                                  tooltip: i18n("multiview_title"),
                                  icon: const Icon(Remix.layout_grid_line),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 0, bottom: 12, left: 12, right: 12),
                        child: IconButton(
                          onPressed: () => Get.toNamed(RoutePath.kToolbox),
                          icon: const Icon(Remix.link),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 0, bottom: 12, left: 12, right: 12),
                        child: IconButton(
                          onPressed: () => Get.toNamed(RoutePath.kSearch),
                          icon: const Icon(CustomIcons.search),
                        ),
                      ),
                      if (showRecord)
                        Padding(
                          padding: const EdgeInsets.only(top: 0, bottom: 12, left: 12, right: 12),
                          child: IconButton(
                            onPressed: () => Get.toNamed(RoutePath.kRecordPage),
                            icon: const Icon(Remix.download_2_line),
                          ),
                        ),
                    ],
                  ),
                  destinations: destinations,
                  selectedIndex: activeSelectedIndex,
                  onDestinationSelected: (int virtualIndex) {
                    if (virtualIndex >= 0 && virtualIndex < virtualToRealMap.length) {
                      onDestinationSelected(virtualToRealMap[virtualIndex]);
                    }
                  },
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: destinations.isEmpty
                      ? AppStatusView(
                          type: AppStatusType.empty,
                          icon: Remix.menu_2_fill,
                          title: i18n("no_menu_title"),
                          subtitle: i18n("no_menu_subtitle"),
                        )
                      : body,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
