import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';

class HomeTabletView extends StatelessWidget {
  final Widget body;
  final int index;
  final void Function(int) onDestinationSelected;

  const HomeTabletView({super.key, required this.body, required this.index, required this.onDestinationSelected});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraint) {
          bool showAction = Get.width > 680;
          return SafeArea(
            child: Row(
              children: [
                NavigationRail(
                  groupAlignment: 0.9,
                  labelType: NavigationRailLabelType.all,
                  leading: showAction
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Padding(padding: EdgeInsets.all(12), child: MenuButton()),
                            Padding(
                              padding: const EdgeInsets.only(top: 0, bottom: 12, left: 12, right: 12),
                              child: IconButton(
                                onPressed: () {
                                  Get.toNamed(RoutePath.kToolbox);
                                },
                                icon: const Icon(Icons.link),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 0, bottom: 12, left: 12, right: 12),
                              child: IconButton(
                                onPressed: () {
                                  Get.toNamed(RoutePath.kSearch);
                                },
                                icon: const Icon(CustomIcons.search),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 0, bottom: 12, left: 12, right: 12),
                              child: IconButton(
                                onPressed: () {
                                  Get.toNamed(RoutePath.kRecordPage);
                                },
                                icon: Icon(Remix.download_2_fill),
                              ),
                            ),
                          ],
                        )
                      : Container(),
                  destinations: [
                    NavigationRailDestination(
                      icon: const Icon(Icons.favorite_rounded),
                      label: Text(i18n("favorites_title")),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(CustomIcons.popular),
                      label: Text(i18n("popular_title")),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.area_chart_rounded),
                      label: Text(i18n("areas_title")),
                    ),
                  ],
                  selectedIndex: index > 2 ? 0 : index,
                  onDestinationSelected: onDestinationSelected,
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
          );
        },
      ),
    );
  }
}
