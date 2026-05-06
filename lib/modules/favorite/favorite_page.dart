import 'package:get/get.dart';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

class FavoritePage extends GetView<FavoriteController> {
  const FavoritePage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraint) {
        bool showAction = Get.width <= 680;
        return Scaffold(
          appBar: AppBar(
            centerTitle: true,
            scrolledUnderElevation: 0,
            leading: showAction ? const MenuButton() : null,
            actions: showAction
                ? [
                    PopupMenuButton<int>(
                      // 更换为更简洁的更多图标
                      icon: const Icon(Remix.more_2_fill, size: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12), // 增大圆角更圆润
                      ),
                      offset: const Offset(0, 10), // 调整垂直偏移，使菜单紧贴按钮
                      position: PopupMenuPosition.under,
                      onSelected: (index) {
                        if (index == 0) {
                          Get.toNamed(RoutePath.kSearch);
                        } else {
                          Get.toNamed(RoutePath.kToolbox);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Icon(Remix.search_line, size: 20, color: Theme.of(context).primaryColor),
                              const SizedBox(width: 12),
                              const Text("搜索直播", style: TextStyle(fontSize: 14)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 1,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Icon(Remix.link, size: 20, color: Theme.of(context).primaryColor),
                              const SizedBox(width: 12),
                              const Text("链接访问", style: TextStyle(fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ]
                : [
                    IconButton(
                      onPressed: () => controller.reloadPage(),
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: '刷新',
                    ),
                  ],
            title: TabBar(
              controller: controller.tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              labelStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              labelPadding: const EdgeInsets.symmetric(horizontal: 12),
              indicatorSize: TabBarIndicatorSize.label,
              tabs: [
                Tab(text: S.of(context).online_room_title),
                Tab(text: S.of(context).offline_room_title),
              ],
            ),
          ),
          body: Column(
            children: [
              TabBar(
                controller: controller.tabSiteController,
                isScrollable: true,
                tabAlignment: TabAlignment.center,
                indicatorSize: TabBarIndicatorSize.label,
                tabs: Sites().availableSites(containsAll: true).map<Widget>((e) => Tab(text: e.name)).toList(),
              ),
              Expanded(
                child: Obx(() {
                  return TabBarView(
                    controller: controller.tabSiteController,
                    children: controller.tabOnlineIndex.value == 0
                        ? Sites()
                              .availableSites(containsAll: true)
                              .map((e) => e.id)
                              .toList()
                              .map((e) => _RoomOnlineGridView(e))
                              .toList()
                        : Sites()
                              .availableSites(containsAll: true)
                              .map((e) => e.id)
                              .toList()
                              .map((e) => _RoomOfflineGridView(e))
                              .toList(),
                  );
                }),
              ),
            ],
          ),
        );
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
        return Obx(
          () => EasyRefresh(
            controller: controller.refreshController,
            onRefresh: onRefresh,
            onLoad: () {
              controller.refreshController.finishLoad(IndicatorResult.success);
            },
            child: controller.onlineRooms.isNotEmpty
                ? WaterfallFlow.builder(
                    padding: const EdgeInsets.all(0),
                    controller: ScrollController(),
                    gridDelegate: SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 3,
                      mainAxisSpacing: 3,
                    ),
                    itemCount: site == Sites.allSite
                        ? controller.onlineRooms.length
                        : controller.onlineRooms.where((el) => el.platform == site).toList().length,
                    itemBuilder: (context, index) => RoomCard(
                      room: site == Sites.allSite
                          ? controller.onlineRooms[index]
                          : controller.onlineRooms.where((el) => el.platform == site).toList()[index],
                      dense: dense,
                    ),
                  )
                : EmptyView(
                    icon: Icons.favorite_rounded,
                    title: S.of(context).empty_favorite_online_title,
                    subtitle: S.of(context).empty_favorite_online_subtitle,
                  ),
          ),
        );
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

        return Obx(
          () => EasyRefresh(
            controller: refreshController,
            onRefresh: onRefresh,
            onLoad: () {
              refreshController.finishLoad(IndicatorResult.noMore);
            },
            child: controller.offlineRooms.isNotEmpty
                ? WaterfallFlow.builder(
                    padding: const EdgeInsets.all(0),
                    controller: ScrollController(),
                    gridDelegate: SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 3,
                      mainAxisSpacing: 3,
                    ),
                    itemCount: site == Sites.allSite
                        ? controller.offlineRooms.length
                        : controller.offlineRooms.where((el) => el.platform == site).toList().length,
                    itemBuilder: (context, index) => RoomCard(
                      room: site == Sites.allSite
                          ? controller.offlineRooms[index]
                          : controller.offlineRooms.where((el) => el.platform == site).toList()[index],
                      dense: dense,
                    ),
                  )
                : EmptyView(
                    icon: Icons.favorite_rounded,
                    title: S.of(context).empty_favorite_offline_title,
                    subtitle: S.of(context).empty_favorite_offline_subtitle,
                  ),
          ),
        );
      },
    );
  }
}
