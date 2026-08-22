import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:pure_live/common/index.dart';

class RoomGridView extends GetView<FavoriteController> {
  const RoomGridView({super.key, required this.scrollController, required this.displayList, this.emptyBuilder});

  final ScrollController scrollController;
  final List<LiveRoom> displayList;
  final WidgetBuilder? emptyBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraint) {
        final width = constraint.maxWidth;
        return Obx(() {
          final dense = SettingsService.to.app.enableDenseFavorites.v;
          final spacing = SettingsService.to.theme.crossAxisSpacing.v;
          final mainAxisSpacing = SettingsService.to.theme.mainAxisSpacing.v;
          final isVerifyingFavorites = controller.isVerifyingFavorites.value;
          var crossAxisCount = width > 1280 ? 4 : (width > 960 ? 3 : (width > 640 ? 2 : 1));
          if (dense) {
            crossAxisCount = width > 1280 ? 5 : (width > 960 ? 4 : (width > 640 ? 3 : 2));
          }

          if (displayList.isEmpty) {
            return CustomScrollView(
              controller: scrollController,
              physics: const PureLiveScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child:
                      emptyBuilder?.call(context) ??
                      AppStatusView(
                        type: AppStatusType.empty,
                        icon: Icons.favorite_rounded,
                        title: i18n('empty_favorite_online_title'),
                        subtitle: i18n('empty_favorite_online_subtitle'),
                      ),
                ),
              ],
            );
          }

          final itemWidth = (width - 24 - spacing * (crossAxisCount - 1)) / crossAxisCount;
          return GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            controller: scrollController,
            physics: const PureLiveScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            scrollCacheExtent: ScrollCacheExtent.pixels(width > 680 ? 480 : 320),
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: spacing,
              mainAxisSpacing: mainAxisSpacing,
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
        });
      },
    );
  }
}
