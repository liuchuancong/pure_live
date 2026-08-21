import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/tags/tag_management_controller.dart';

class RoomGridView extends GetView<FavoriteController> {
  const RoomGridView({
    super.key,
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
                  physics: const PureLiveScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  itemCount: controller.visibleTags.length + 1,
                  itemBuilder: (context, index) {
                    final isAll = index == 0;
                    final isSelected = isAll
                        ? controller.selectedTagId.value == TagManagementController.allTagKey
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
                            final targetTagId = isAll
                                ? TagManagementController.allTagKey
                                : controller.visibleTags[index - 1].id;
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
                final spacing = SettingsService.to.theme.crossAxisSpacing.v;
                final isVerifyingFavorites = controller.isVerifyingFavorites.value;
                final itemWidth = (width - 24 - spacing * (crossAxisCount - 1)) / crossAxisCount;
                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  controller: scrollController,
                  scrollCacheExtent: ScrollCacheExtent.pixels(width > 680 ? 480 : 320),
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: true,
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: SettingsService.to.theme.mainAxisSpacing.v,
                    mainAxisExtent: itemWidth * 9 / 16 + (dense ? 72 : 84),
                  ),
                  itemCount: displayList.length,
                  itemBuilder: (context, index) {
                    final room = displayList[index];
                    return RoomCard(
                      key: ValueKey('${room.platform}:${room.roomId}'),
                      room: room,
                      dense: dense,
                      audiencePending: isVerifyingFavorites,
                    );
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
