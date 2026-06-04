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
          final int menuCount = SettingsService.to.app.savedMenuIds.v.length;
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
                              controller.currentPage = 1;
                              controller.syncRooms();
                            }
                          }
                        });

                        return BasePageView<FavoriteController, LiveRoom>(
                          controller: controller,
                          enableRefresh: true,
                          enableLoadMore: false,
                          showScrollToTopBtn: true,
                          contentBuilder: (context, list, scrollController) {
                            return Column(
                              children: [
                                TabBar(
                                  isScrollable: true,
                                  tabs: availableSitesList.map<Widget>((e) => Tab(text: e.name)).toList(),
                                ),
                                Expanded(
                                  child: TabBarView(
                                    controller: tabController,
                                    children: availableSitesList
                                        .map(
                                          (e) => _RoomGridView(
                                            site: e.id,
                                            isOnline: controller.tabOnlineIndex.value == 0,
                                            scrollController: scrollController,
                                            displayList: list,
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                              ],
                            );
                          },
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
  const _RoomGridView({
    required this.site,
    required this.isOnline,
    required this.scrollController,
    required this.displayList,
  });

  final String site;
  final bool isOnline;
  final ScrollController scrollController;
  final List<LiveRoom> displayList;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dense = SettingsService.to.app.enableDenseFavorites.v;

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
                return WaterfallFlow.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  controller: scrollController,
                  gridDelegate: SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: SettingsService.to.theme.crossAxisSpacing.v,
                    mainAxisSpacing: SettingsService.to.theme.mainAxisSpacing.v,
                  ),
                  itemCount: displayList.length,
                  itemBuilder: (context, index) {
                    return RoomCard(room: displayList[index], dense: dense);
                  },
                );
              }),
            ),
          ],
        );
      },
    );
  }
}
