import 'package:pure_live/common/index.dart';
import 'package:waterfall_flow/waterfall_flow.dart';
import 'package:pure_live/common/widgets/common_appbar_actions.dart';

class FavoritePage extends GetView<FavoriteController> {
  const FavoritePage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraint) {
        return Obx(() {
          bool showAction = Get.width <= 680;
          final int menuCount = Get.find<SettingsService>().savedMenuIds.length;
          final availableSitesList = Sites().availableSites(containsAll: true);

          return Scaffold(
            appBar: AppBar(
              centerTitle: true,
              scrolledUnderElevation: 0,
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
            body: availableSitesList.isEmpty
                ? const SizedBox.shrink()
                : DefaultTabController(
                    length: availableSitesList.length,
                    child: Builder(
                      builder: (context) {
                        return Column(
                          children: [
                            TabBar(
                              isScrollable: true,
                              tabs: availableSitesList.map<Widget>((e) => Tab(text: e.name)).toList(),
                            ),
                            Expanded(
                              child: Obx(
                                () => TabBarView(
                                  children: controller.tabOnlineIndex.value == 0
                                      ? availableSitesList.map((e) => e.id).map((e) => _RoomOnlineGridView(e)).toList()
                                      : availableSitesList
                                            .map((e) => e.id)
                                            .map((e) => _RoomOfflineGridView(e))
                                            .toList(),
                                ),
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

class _RoomOnlineGridView extends GetView<FavoriteController> {
  _RoomOnlineGridView(this.site);
  final String site;
  final dense = Get.find<SettingsService>().enableDenseFavorites.value;

  Future onRefresh() async {
    bool result = await controller.onRefresh();
    if (!result) {
      controller.refreshController.finishRefresh(IndicatorResult.success);
      controller.refreshController.resetFooter();
    } else {
      controller.refreshController.finishRefresh(IndicatorResult.fail);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraint) {
        final width = constraint.maxWidth;
        int crossAxisCount = width > 1280 ? 4 : (width > 960 ? 3 : (width > 640 ? 2 : 1));
        if (dense) {
          crossAxisCount = width > 1280 ? 5 : (width > 960 ? 4 : (width > 640 ? 3 : 2));
        }
        return Obx(() {
          final displayRooms = site == Sites.allSite
              ? controller.onlineRooms
              : controller.onlineRooms.where((el) => el.platform == site).toList();

          if (controller.onlineRooms.isEmpty && controller.refreshController.controlFinishRefresh) {
            return AppStatusView(type: AppStatusType.loading, title: i18n('refresh_loading'), subtitle: '');
          }

          return EasyRefresh(
            controller: controller.refreshController,
            onRefresh: onRefresh,
            onLoad: () {
              controller.refreshController.finishLoad(IndicatorResult.success);
            },
            child: displayRooms.isNotEmpty
                ? WaterfallFlow.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    controller: ScrollController(),
                    gridDelegate: SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
                      lastChildLayoutTypeBuilder: (index) => LastChildLayoutType.none,
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                      closeToTrailing: false,
                    ),
                    itemCount: displayRooms.length,
                    itemBuilder: (context, index) => RoomCard(room: displayRooms[index], dense: dense),
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: constraint.maxHeight * 0.8,
                        child: AppStatusView(
                          type: AppStatusType.empty,
                          icon: Icons.favorite_rounded,
                          title: i18n("empty_favorite_online_title"),
                          subtitle: i18n("empty_favorite_online_subtitle"),
                        ),
                      ),
                    ],
                  ),
          );
        });
      },
    );
  }
}

class _RoomOfflineGridView extends GetView<FavoriteController> {
  _RoomOfflineGridView(this.site);
  final String site;
  final refreshController = EasyRefreshController(controlFinishRefresh: true, controlFinishLoad: true);
  final dense = Get.find<SettingsService>().enableDenseFavorites.value;

  Future onRefresh() async {
    await controller.onRefresh();
    refreshController.finishRefresh(IndicatorResult.success);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraint) {
        final width = constraint.maxWidth;
        int crossAxisCount = width > 1280 ? 4 : (width > 960 ? 3 : (width > 640 ? 2 : 1));
        if (dense) {
          crossAxisCount = width > 1280 ? 5 : (width > 960 ? 4 : (width > 640 ? 3 : 2));
        }

        return Obx(() {
          final displayRooms = site == Sites.allSite
              ? controller.offlineRooms
              : controller.offlineRooms.where((el) => el.platform == site).toList();

          if (controller.offlineRooms.isEmpty && refreshController.controlFinishRefresh) {
            return AppStatusView(type: AppStatusType.loading, title: i18n('refresh_loading'), subtitle: '');
          }

          return EasyRefresh(
            controller: refreshController,
            onRefresh: onRefresh,
            onLoad: () {
              refreshController.finishLoad(IndicatorResult.noMore);
            },
            child: displayRooms.isNotEmpty
                ? WaterfallFlow.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    controller: ScrollController(),
                    gridDelegate: SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
                      lastChildLayoutTypeBuilder: (index) => LastChildLayoutType.none,
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                    ),
                    itemCount: displayRooms.length,
                    itemBuilder: (context, index) => RoomCard(room: displayRooms[index], dense: dense),
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: constraint.maxHeight * 0.8,
                        child: AppStatusView(
                          type: AppStatusType.empty,
                          icon: Icons.favorite_rounded,
                          title: i18n("empty_favorite_offline_title"),
                          subtitle: i18n("empty_favorite_offline_subtitle"),
                        ),
                      ),
                    ],
                  ),
          );
        });
      },
    );
  }
}
