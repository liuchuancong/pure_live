import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

@visibleForTesting
bool shouldWrapFavoritePullToRefresh({required double viewportWidth, required bool isMobilePlatform}) {
  // A wide Android/iOS tablet still uses the touch-first home shell and must
  // keep pull-to-refresh. Width alone only selects the responsive grid; it is
  // not a reliable desktop-platform signal.
  return isMobilePlatform || viewportWidth <= 680;
}

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

          Widget buildScrollable(ScrollPhysics physics) {
            if (displayList.isEmpty) {
              return CustomScrollView(
                controller: scrollController,
                physics: physics,
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
              physics: physics,
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
                  statusPending: isVerifyingFavorites || room.isLiveStatusPending,
                  statusPendingLabel: isVerifyingFavorites
                      ? i18n('favorite_status_verifying')
                      : i18n('favorite_status_unknown'),
                );
              },
            );
          }

          if (!shouldWrapFavoritePullToRefresh(viewportWidth: width, isMobilePlatform: PlatformUtils.isMobile)) {
            return buildScrollable(const PureLiveScrollPhysics(parent: AlwaysScrollableScrollPhysics()));
          }

          // EasyRefresh must own the exact physics installed on the vertical
          // child. Supplying PureLiveScrollPhysics directly made Android's
          // outer ClampingScrollPhysics consume boundary movement before the
          // refresh header could observe it, so the callback existed while the
          // pull animation never armed.
          return buildFavoritePullToRefresh(
            siteId: siteId,
            onRefresh: controller.refreshData,
            childBuilder: (_, physics) => buildScrollable(physics),
          );
        });
      },
    );
  }
}

@visibleForTesting
Widget buildFavoritePullToRefresh({
  required String siteId,
  required Future<void> Function() onRefresh,
  required ERChildBuilder childBuilder,
}) {
  return EasyRefresh.builder(
    key: ValueKey('favorite_pull_to_refresh_$siteId'),
    header: MaterialHeader(
      key: ValueKey('favorite_pull_to_refresh_indicator_$siteId'),
      triggerOffset: 72,
      triggerWhenRelease: true,
      clamping: true,
    ),
    triggerAxis: Axis.vertical,
    onRefresh: onRefresh,
    childBuilder: childBuilder,
  );
}
