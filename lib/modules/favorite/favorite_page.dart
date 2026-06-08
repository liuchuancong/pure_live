import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/favorite/room_grid_view.dart';
import 'package:pure_live/common/widgets/common_appbar_actions.dart';
import 'package:pure_live/modules/tags/tag_management_controller.dart';

class FavoritePage extends GetView<FavoriteController> {
  const FavoritePage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraint) {
        return Obx(() {
          bool showAction = Get.width <= 680;
          final menuCount = SettingsService.to.app.savedMenuIds.v.length;
          final availableSitesList = Sites().availableSites(containsAll: true);

          return Scaffold(
            appBar: AppBar(
              centerTitle: true,
              leading: (showAction || menuCount <= 1) ? const MenuButton() : null,
              actions: showAction ? [CommonAppBarActions()] : null,
              title: TabBar(
                controller: controller.tabController,
                isScrollable: true,
                tabs: [
                  Tab(text: i18n("online_room_title")),
                  Tab(text: i18n("offline_room_title")),
                ],
              ),
            ),
            body: DefaultTabController(
              length: availableSitesList.length,
              child: Builder(
                builder: (context) {
                  final tabController = DefaultTabController.of(context);
                  tabController.addListener(() {
                    if (!tabController.indexIsChanging) {
                      if (controller.tabSiteIndex.value != tabController.index) {
                        controller.selectedTagId.value = TagManagementController.allTagKey;
                        controller.tabSiteIndex.value = tabController.index;
                        controller.currentPage = 1;
                        controller.applyLocalFilter();
                      }
                    }
                  });

                  return Column(
                    children: [
                      TabBar(isScrollable: true, tabs: availableSitesList.map((e) => Tab(text: e.name)).toList()),
                      Expanded(
                        child: BasePageView<FavoriteController, LiveRoom>(
                          controller: controller,
                          enableRefresh: true,
                          enableLoadMore: true,
                          emptyBuilder: (context) => AppStatusView(
                            type: AppStatusType.empty,
                            icon: Remix.heart_3_fill,
                            title: i18n("empty_favorite_online_title"),
                            subtitle: i18n("empty_favorite_online_subtitle"),
                          ),
                          showScrollToTopBtn: SettingsService.to.page.showScrollToTopBtn.v,
                          showPageSizeSelector: SettingsService.to.page.showPageSizeSelector.v,
                          pageSizeOptions: SettingsService.to.page.pageSizeOptions,
                          contentBuilder: (context, list, scrollController) {
                            return TabBarView(
                              children: availableSitesList.map((e) {
                                return RoomGridView(
                                  site: e.id,
                                  isOnline: controller.tabOnlineIndex.value == 0,
                                  scrollController: scrollController,
                                  displayList: list,
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        });
      },
    );
  }
}
