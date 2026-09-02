import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:pure_live/modules/settings/pages/room_card_settings/room_card_config_controller.dart';

class PopularGridView extends StatelessWidget {
  final String tag;
  const PopularGridView(this.tag, {super.key});

  BasePageScrollAndStateBone<LiveRoom> get controller => Get.find<BasePageScrollAndStateBone<LiveRoom>>(tag: tag);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraint) {
        final width = constraint.maxWidth;
        final crossAxisCount = width > 1280 ? 5 : (width > 960 ? 4 : (width > 640 ? 3 : 2));
        return BasePageView<BasePageScrollAndStateBone<LiveRoom>, LiveRoom>(
          controller: controller,
          showScrollToTopBtn: SettingsService.to.page.showScrollToTopBtn.v,
          pageSizeOptions: SettingsService.to.page.pageSizeOptions,
          showPageSizeSelector: SettingsService.to.page.showPageSizeSelector.v,
          emptyBuilder: (c) => AppStatusView(
            type: AppStatusType.empty,
            icon: RemixIcons.fire_fill,
            title: i18n("empty_live_title"),
            subtitle: i18n("empty_live_subtitle"),
            buttonText: i18n('refresh'),
            onButtonPressed: () => controller.refreshData(),
          ),
          contentBuilder: (context, list, scrollController) {
            final spacing = SettingsService.to.theme.crossAxisSpacing.v;
            final itemWidth = (width - 12 - spacing * (crossAxisCount - 1)) / crossAxisCount;
            return GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              controller: scrollController,
              scrollCacheExtent: ScrollCacheExtent.pixels(width > 680 ? 480 : 320),
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: true,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: spacing,
                mainAxisSpacing: SettingsService.to.theme.mainAxisSpacing.v,
                mainAxisExtent: RoomCardConfigController.to.calculateCardHeight(itemWidth: itemWidth),
              ),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final room = list[index];
                return RoomCard(key: ValueKey('${room.platform}:${room.roomId}'), room: room, dense: true);
              },
            );
          },
        );
      },
    );
  }
}
