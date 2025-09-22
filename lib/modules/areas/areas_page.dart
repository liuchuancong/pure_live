import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/util/site_logo_widget.dart';

import 'areas_grid_view.dart';

class AreasPage extends GetView<AreasController> {
  const AreasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraint) {
      bool showAction = constraint.maxWidth <= 680;
      return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          scrolledUnderElevation: 0,
          leading: showAction ? const MenuButton() : null,
          actions: showAction
              ? [
                  PopupMenuButton(
                    tooltip: S.current.search,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    offset: const Offset(12, 0),
                    position: PopupMenuPosition.under,
                    icon: const Icon(Icons.read_more_sharp),
                    onSelected: (int index) {
                      if (index == 0) {
                        Get.toNamed(RoutePath.kSearch);
                      } else {
                        Get.toNamed(RoutePath.kToolbox);
                      }
                    },
                    itemBuilder: (BuildContext context) {
                      return [
                        PopupMenuItem(
                          value: 0,
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: MenuListTile(
                            leading: Icon(CustomIcons.search),
                            text: S.current.live_room_search,
                          ),
                        ),
                        PopupMenuItem(
                          value: 1,
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: MenuListTile(
                            leading: Icon(Icons.link),
                            text: S.current.live_room_link_access,
                          ),
                        ),
                      ];
                    },
                  )
                ]
              : null,
          title: TabBar(
            controller: controller.tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            labelPadding: const EdgeInsets.symmetric(horizontal: 12),
            indicatorSize: TabBarIndicatorSize.label,
            tabs: SiteWidget.availableSitesTabList,
          ),
        ),
        body: TabBarView(
          controller: controller.tabController,
          children: Sites().availableSites().map((e) => AreaGridView(e.id)).toList(),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: FloatingActionButton(
          heroTag: UniqueKey(),
          onPressed: () {
            Get.toNamed(RoutePath.kFavoriteAreas);
          },
          child: const Icon(Icons.favorite_rounded),
        ),
      );
    });
  }
}
