import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:pure_live/common/index.dart';

class RoomGridView extends GetView<FavoriteController> {
  const RoomGridView({
    super.key,
    required this.siteId,
    required this.scrollController,
    required this.displayList,
    this.emptyBuilder,
  });

  final String siteId;
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

          final Widget content;
          if (displayList.isEmpty) {
            content = CustomScrollView(
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
          } else {
            final itemWidth = (width - 24 - spacing * (crossAxisCount - 1)) / crossAxisCount;
            content = GridView.builder(
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
          }

          if (width > 680) return content;
          return buildFavoritePullToRefresh(siteId: siteId, onRefresh: controller.refreshData, child: content);
        });
      },
    );
  }
}

@visibleForTesting
Widget buildFavoritePullToRefresh({
  required String siteId,
  required Future<void> Function() onRefresh,
  required Widget child,
}) {
  return EasyRefresh(key: ValueKey('favorite_pull_to_refresh_$siteId'), onRefresh: onRefresh, child: child);
}
