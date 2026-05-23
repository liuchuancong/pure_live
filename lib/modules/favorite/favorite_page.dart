import 'package:pure_live/common/index.dart';
import 'package:waterfall_flow/waterfall_flow.dart';
import 'package:pure_live/common/widgets/common_appbar_actions.dart';

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
            actions: showAction ? [CommonAppBarActions()] : null,
            title: TabBar(
              controller: controller.tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              labelStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              labelPadding: const EdgeInsets.symmetric(horizontal: 12),
              indicatorSize: TabBarIndicatorSize.label,
              tabs: [
                Tab(text: i18n("online_room_title")),
                Tab(text: i18n("offline_room_title")),
              ],
            ),
          ),
          // 🎯 ✨【核心修正】：用一个总的 Obx 包裹整个平台切换体系
          body: Obx(() {
            // 1. 实时获取经过排序和过滤的最新平台列表
            final availableSitesList = Sites().availableSites(containsAll: true);

            if (availableSitesList.isEmpty) return const SizedBox.shrink();

            return Column(
              children: [
                // 2. 这里的 TabBar 已经安全地吃到了响应式状态，会跟着设置实时刷新顺序和增减
                TabBar(
                  controller: controller.tabSiteController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.center,
                  indicatorSize: TabBarIndicatorSize.label,
                  tabs: availableSitesList.map<Widget>((e) => Tab(text: e.name)).toList(),
                ),
                Expanded(
                  child: TabBarView(
                    controller: controller.tabSiteController,
                    children: controller.tabOnlineIndex.value == 0
                        ? availableSitesList.map((e) => e.id).map((e) => _RoomOnlineGridView(e)).toList()
                        : availableSitesList.map((e) => e.id).map((e) => _RoomOfflineGridView(e)).toList(),
                  ),
                ),
              ],
            );
          }),
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
                      lastChildLayoutTypeBuilder: (index) => LastChildLayoutType.none,
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
                    title: i18n("empty_favorite_online_title"),
                    subtitle: i18n("empty_favorite_online_subtitle"),
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
                      lastChildLayoutTypeBuilder: (index) => LastChildLayoutType.none,
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
                    title: i18n("empty_favorite_offline_title"),
                    subtitle: i18n("empty_favorite_offline_subtitle"),
                  ),
          ),
        );
      },
    );
  }
}
