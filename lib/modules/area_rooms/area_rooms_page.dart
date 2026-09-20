import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/utils/category_artwork.dart';
import 'package:pure_live/modules/area_rooms/area_rooms_controller.dart';
import 'package:pure_live/plugins/cache_manager.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pure_live/common/widgets/keep_alive_wrapper.dart';

class AreasRoomPage extends StatefulWidget {
  final Site site;
  final LiveArea subCategory;

  const AreasRoomPage({super.key, required this.site, required this.subCategory});

  @override
  State<AreasRoomPage> createState() => _AreasRoomPageState();
}

class _AreasRoomPageState extends State<AreasRoomPage> {
  BasePageScrollAndStateBone<LiveRoom> get controller =>
      Get.find<BasePageScrollAndStateBone<LiveRoom>>(tag: areaRoomsControllerTag(widget.site, widget.subCategory));

  @override
  void initState() {
    super.initState();
    controller.refreshData();
  }

  @override
  Widget build(BuildContext context) {
    final rawAreaName = widget.subCategory.areaName?.trim() ?? '';
    final areaName = rawAreaName.isEmpty ? i18n('unnamed_area') : rawAreaName;
    return KeepAliveWrapper(
      child: Scaffold(
        appBar: AppBar(title: Text(areaName)),
        body: BasePageView<BasePageScrollAndStateBone<LiveRoom>, LiveRoom>(
          controller: controller,
          enableRefresh: true,
          enableLoadMore: true,
          customMobileBottomPadding: 85,
          customDesktopBottomPadding: 135,
          showScrollToTopBtn: SettingsService.to.page.showScrollToTopBtn.v,
          showPageSizeSelector: SettingsService.to.page.showPageSizeSelector.v,
          pageSizeOptions: SettingsService.to.page.pageSizeOptions,
          emptyBuilder: (context) => EmptyView(icon: Icons.live_tv_rounded, title: i18n('no_data'), subtitle: ''),
          contentBuilder: (context, list, scrollController) {
            return Obx(() {
              final roomCardAppearance = SettingsService.to.roomCard.resolve();
              return LayoutBuilder(
                builder: (context, constraint) {
                  final width = constraint.maxWidth;
                  final crossAxisCount = width > 1280 ? 5 : (width > 960 ? 4 : (width > 640 ? 3 : 2));
                  final spacing = SettingsService.to.theme.crossAxisSpacing.v;
                  final itemWidth = (width - 12 - spacing * (crossAxisCount - 1)) / crossAxisCount;
                  return GridView.builder(
                    scrollCacheExtent: ScrollCacheExtent.pixels(width > 680 ? 480 : 320),
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: SettingsService.to.theme.mainAxisSpacing.v,
                      mainAxisExtent: RoomCardLayoutMetrics.gridMainAxisExtent(
                        itemWidth: itemWidth,
                        appearance: roomCardAppearance,
                        dense: true,
                        textScaler: MediaQuery.textScalerOf(context),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(6, 6, 6, 80),
                    controller: scrollController,
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final room = list[index];
                      return RoomCard(key: ValueKey('${room.platform}:${room.roomId}'), room: room, dense: true);
                    },
                  );
                },
              );
            });
          },
        ),
        floatingActionButton: FavoriteAreaFloatingButton(area: widget.subCategory),
      ),
    );
  }
}

class FavoriteAreaFloatingButton extends StatefulWidget {
  const FavoriteAreaFloatingButton({super.key, required this.area});

  final LiveArea area;

  @override
  State<FavoriteAreaFloatingButton> createState() => _FavoriteAreaFloatingButtonState();
}

class _FavoriteAreaFloatingButtonState extends State<FavoriteAreaFloatingButton> {
  bool _busy = false;

  LiveArea get area => widget.area;

  Future<void> _toggleFavorite({required LiveArea target, required bool isFavorite}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final favorites = SettingsService.to.fav;
    try {
      if (!isFavorite) {
        await favorites.addAreaDurably(target);
        return;
      }

      final displayName = target.areaName?.trim().isNotEmpty == true ? target.areaName!.trim() : i18n('unnamed_area');
      final confirmed = await showDialog<bool>(
        context: context,
        useRootNavigator: false,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          title: Text(i18n('unfollow')),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(i18n('unfollow_message', args: {'name': displayName})),
          ),
          actionsOverflowDirection: VerticalDirection.down,
          actionsOverflowButtonSpacing: 8,
          actions: [
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(i18n('cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(i18n('confirm')),
            ),
          ],
        ),
      );
      if (confirmed == true) await favorites.removeAreaDurably(target);
    } catch (error) {
      debugPrint('Favorite area change failed: $error');
      ToastUtil.show(i18n('favorite_changes_save_failed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _buildAvatar(BuildContext context) {
    final theme = Theme.of(context);
    final rawAreaName = area.areaName?.trim() ?? '';
    final displayName = rawAreaName.isEmpty ? i18n('unnamed_area') : rawAreaName;
    final firstChar = String.fromCharCode(displayName.runes.first);
    final pictureUrl = normalizeNetworkImageUrl(area.areaPic);
    final bool hasPic = pictureUrl.isNotEmpty;

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.primaryContainer),
      child: ClipOval(
        child: hasPic
            ? CachedNetworkImage(
                imageUrl: pictureUrl,
                cacheKey: pictureUrl,
                cacheManager: CustomImageCacheManager.instance,
                httpHeaders: networkImageHeaders(pictureUrl),
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                alignment: categoryArtworkAlignment(pictureUrl),
                memCacheWidth: 64,
                // maxWidthDiskCache: 128,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                errorWidget: (context, _, _) {
                  return Center(
                    child: Text(
                      firstChar,
                      style: AppTextStyles.t12Bold.copyWith(color: theme.colorScheme.onPrimaryContainer),
                    ),
                  );
                },
              )
            : Center(
                child: Text(
                  firstChar,
                  style: AppTextStyles.t12Bold.copyWith(color: theme.colorScheme.onPrimaryContainer),
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isFavorite = SettingsService.to.fav.isFavoriteArea(area);
      final rawAreaName = area.areaName?.trim() ?? '';
      final displayName = rawAreaName.isEmpty ? i18n('unnamed_area') : rawAreaName;

      return Padding(
        padding: EdgeInsets.only(
          bottom: Get.width > 680
              ? 24
              : (MediaQuery.paddingOf(context).bottom > 0 ? MediaQuery.paddingOf(context).bottom : 12),
          right: 0,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOutCubic,
          constraints: const BoxConstraints(minHeight: 48),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(isFavorite ? 24 : 16),
            border: Border.all(
              color: isFavorite
                  ? Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)
                  : Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isFavorite ? 24 : 16),
            child: ColoredBox(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(isFavorite ? 24 : 16),
                onTap: _busy ? null : () => _toggleFavorite(target: area, isFavorite: isFavorite),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildAvatar(context),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOutCubic,
                        child: isFavorite
                            ? const SizedBox.shrink()
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        i18n("follow"),
                                        style: Theme.of(context).textTheme.bodySmall
                                            ?.copyWith(color: Theme.of(context).hintColor, height: 1.1),
                                      ),
                                      const SizedBox(height: 1),
                                      ConstrainedBox(
                                        constraints: BoxConstraints(maxWidth: Get.width > 680 ? 120 : 80),
                                        child: Text(
                                          displayName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.t12Bold.copyWith(
                                            color: Theme.of(context).colorScheme.primary,
                                            height: 1.2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
