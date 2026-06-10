import 'dart:ui';
import 'package:pure_live/common/index.dart';
import 'package:waterfall_flow/waterfall_flow.dart';
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
      Get.find<BasePageScrollAndStateBone<LiveRoom>>(tag: "${widget.site.id}_${widget.subCategory.areaId}");

  @override
  void initState() {
    super.initState();
    controller.refreshData();
  }

  @override
  Widget build(BuildContext context) {
    return KeepAliveWrapper(
      child: Scaffold(
        appBar: AppBar(title: Text(widget.subCategory.areaName!)),
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
            return LayoutBuilder(
              builder: (context, constraint) {
                final width = constraint.maxWidth;
                final crossAxisCount = width > 1280 ? 5 : (width > 960 ? 4 : (width > 640 ? 3 : 2));
                return WaterfallFlow.builder(
                  gridDelegate: SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
                    lastChildLayoutTypeBuilder: (index) => LastChildLayoutType.none,
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: SettingsService.to.theme.crossAxisSpacing.v,
                    mainAxisSpacing: SettingsService.to.theme.mainAxisSpacing.v,
                  ),
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 80),
                  controller: scrollController,
                  itemCount: list.length,
                  itemBuilder: (context, index) => RoomCard(room: list[index], dense: true),
                );
              },
            );
          },
        ),
        floatingActionButton: FavoriteAreaFloatingButton(area: widget.subCategory),
      ),
    );
  }
}

class FavoriteAreaFloatingButton extends StatelessWidget {
  const FavoriteAreaFloatingButton({super.key, required this.area});

  final LiveArea area;

  Widget _buildAvatar(BuildContext context) {
    final theme = Theme.of(context);
    final String firstChar = (area.areaName?.isNotEmpty ?? false) ? area.areaName!.substring(0, 1) : "";
    final bool hasPic = area.areaPic != null && area.areaPic!.isNotEmpty;

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.primaryContainer),
      child: ClipOval(
        child: hasPic
            ? Image.network(
                area.areaPic!,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
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
      final isFavorite = SettingsService.to.fav.favoriteAreas.v.any((e) => e.areaId == area.areaId);

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
          height: 48,
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
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
              child: InkWell(
                borderRadius: BorderRadius.circular(isFavorite ? 24 : 16),
                onTap: () {
                  if (isFavorite) {
                    showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(i18n("unfollow")),
                        content: Text(i18n("unfollow_message", args: {"name": area.areaName!})),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(i18n("cancel"))),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: Text(i18n("confirm")),
                          ),
                        ],
                      ),
                    ).then((value) {
                      if (value == true) {
                        final list = List<LiveArea>.from(SettingsService.to.fav.favoriteAreas.v);
                        list.removeWhere((e) => e.areaId == area.areaId);
                        SettingsService.to.fav.favoriteAreas.v = list;
                      }
                    });
                  } else {
                    final list = List<LiveArea>.from(SettingsService.to.fav.favoriteAreas.v)..add(area);
                    SettingsService.to.fav.favoriteAreas.v = list;
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
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
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).hintColor,
                                          height: 1.1,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      ConstrainedBox(
                                        constraints: BoxConstraints(maxWidth: Get.width > 680 ? 120 : 80),
                                        child: Text(
                                          area.areaName!,
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
