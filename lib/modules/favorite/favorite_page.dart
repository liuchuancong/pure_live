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
                        final tabController = DefaultTabController.of(context);
                        tabController.addListener(() {
                          if (!tabController.indexIsChanging) {
                            if (controller.tabSiteIndex.value != tabController.index) {
                              controller.selectedTagId.value = 'ALL';
                              controller.tabSiteIndex.value = tabController.index;
                            }
                          }
                        });

                        return Column(
                          children: [
                            TabBar(
                              isScrollable: true,
                              tabs: availableSitesList.map<Widget>((e) => Tab(text: e.name)).toList(),
                            ),
                            Expanded(
                              child: Obx(
                                () => TabBarView(
                                  children: availableSitesList
                                      .map((e) => e.id)
                                      .map(
                                        (e) => _RoomGridView(site: e, isOnline: controller.tabOnlineIndex.value == 0),
                                      )
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

class _RoomGridView extends GetView<FavoriteController> {
  _RoomGridView({required this.site, required this.isOnline});

  final String site;
  final bool isOnline;
  final dense = Get.find<SettingsService>().enableDenseFavorites.value;
  final offlineRefreshController = EasyRefreshController(controlFinishRefresh: true, controlFinishLoad: true);

  Future onRefresh() async {
    if (isOnline) {
      bool result = await controller.onRefresh();
      if (!result) {
        controller.refreshController.finishRefresh(IndicatorResult.success);
        controller.refreshController.resetFooter();
      } else {
        controller.refreshController.finishRefresh(IndicatorResult.fail);
      }
    } else {
      await controller.onRefresh();
      offlineRefreshController.finishRefresh(IndicatorResult.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraint) {
        final width = constraint.maxWidth;
        int crossAxisCount = width > 1280 ? 4 : (width > 960 ? 3 : (width > 640 ? 2 : 1));
        if (dense) {
          crossAxisCount = width > 1280 ? 5 : (width > 960 ? 4 : (width > 640 ? 3 : 2));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Obx(() {
              if (controller.visibleTags.isEmpty) {
                return const SizedBox.shrink();
              }
              return Container(
                height: 44,
                width: double.infinity,
                color: Colors.transparent,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  itemCount: controller.visibleTags.length + 1,
                  itemBuilder: (context, index) {
                    final isAll = index == 0;
                    final isSelected = isAll
                        ? controller.selectedTagId.value == 'ALL'
                        : controller.selectedTagId.value == controller.visibleTags[index - 1].id;

                    final String label = isAll ? (i18n('recorder_tab_all')) : controller.visibleTags[index - 1].name;

                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        showCheckmark: false,
                        avatar: null,
                        label: Text(
                          label,
                          style: AppTextStyles.t12.copyWith(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: theme.colorScheme.primary,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isSelected ? Colors.transparent : theme.dividerColor.withValues(alpha: 0.04),
                            width: 0.5,
                          ),
                        ),
                        onSelected: (bool selected) {
                          if (selected) {
                            final targetTagId = isAll ? 'ALL' : controller.visibleTags[index - 1].id;
                            controller.changeSelectedTag(targetTagId);
                          }
                        },
                      ),
                    );
                  },
                ),
              );
            }),

            Expanded(
              child: Obx(() {
                final baseRooms = isOnline ? controller.onlineRooms : controller.offlineRooms;
                final currentRefreshController = isOnline ? controller.refreshController : offlineRefreshController;

                final List<dynamic> platformFilteredRooms = site == Sites.allSite
                    ? baseRooms
                    : baseRooms.where((el) => el.platform == site).toList();

                final List<dynamic> displayRooms = controller.selectedTagId.value == 'ALL'
                    ? platformFilteredRooms
                    : platformFilteredRooms
                          .where(
                            (room) =>
                                controller.tagController.getTagsForRoom(room).contains(controller.selectedTagId.value),
                          )
                          .toList();

                if (baseRooms.isEmpty &&
                    currentRefreshController.controlFinishRefresh &&
                    controller.selectedTagId.value == 'ALL') {
                  return AppStatusView(type: AppStatusType.loading, title: i18n('refresh_loading'), subtitle: '');
                }

                return EasyRefresh(
                  controller: currentRefreshController,
                  onRefresh: onRefresh,
                  onLoad: () {
                    currentRefreshController.finishLoad(isOnline ? IndicatorResult.success : IndicatorResult.noMore);
                  },
                  child: displayRooms.isNotEmpty
                      ? WaterfallFlow.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                          controller: ScrollController(),
                          gridDelegate: SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
                            lastChildLayoutTypeBuilder: (index) => LastChildLayoutType.none,
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: controller.settings.crossAxisSpacing.value,
                            mainAxisSpacing: controller.settings.mainAxisSpacing.value,
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
                                title: i18n(isOnline ? "empty_favorite_online_title" : "empty_favorite_offline_title"),
                                subtitle: i18n(
                                  isOnline ? "empty_favorite_online_subtitle" : "empty_favorite_offline_subtitle",
                                ),
                              ),
                            ),
                          ],
                        ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}
