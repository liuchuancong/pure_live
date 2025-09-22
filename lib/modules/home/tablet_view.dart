import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/search/search_controller.dart' as pure_live;

class HomeTabletView extends StatelessWidget {
  final Widget body;
  final int index;
  final void Function(int) onDestinationSelected;

  const HomeTabletView({
    super.key,
    required this.body,
    required this.index,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, constraint) {
        bool showAction = constraint.maxWidth > 680;
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
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: MenuButton(),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 0, bottom: 12, left: 12, right: 12),
                            child: IconButton(
                                onPressed: () {
                                  Get.toNamed(RoutePath.kToolbox);
                                },
                                icon: const Icon(Icons.link)),
                          ),
                          FloatingActionButton(
                            key: UniqueKey(),
                            heroTag: UniqueKey(),
                            elevation: 0,
                            onPressed: () {
                              Get.put(pure_live.SearchController());
                              onDestinationSelected(3);
                            },
                            child: const Icon(CustomIcons.search),
                          ),
                        ],
                      )
                    : Container(),
                destinations: [
                  NavigationRailDestination(
                    icon: const Icon(Icons.favorite_rounded),
                    label: Text(S.current.favorites_title),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(CustomIcons.popular),
                    label: Text(S.current.popular_title),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.area_chart_rounded),
                    label: Text(S.current.areas_title),
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
      }),
    );
  }
}
