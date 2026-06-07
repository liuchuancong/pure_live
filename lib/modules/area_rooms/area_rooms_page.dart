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

    return CircleAvatar(
      radius: 18,
      backgroundColor: theme.colorScheme.primaryContainer,
      child: ClipOval(
        child: hasPic
            ? Image.network(
                area.areaPic!,
                width: 36,
                height: 36,
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
      if (isFavorite) {
        return FloatingActionButton(
          elevation: 2,
          backgroundColor: Theme.of(context).cardColor,
          tooltip: i18n("unfollow"),
          onPressed: () {
            Get.dialog(
              AlertDialog(
                title: Text(i18n("unfollow")),
                content: Text(i18n("unfollow_message", args: {"name": area.areaName!})),
                actions: [
                  TextButton(onPressed: () => Navigator.of(Get.context!).pop(false), child: Text(i18n("cancel"))),
                  ElevatedButton(onPressed: () => Navigator.of(Get.context!).pop(true), child: Text(i18n("confirm"))),
                ],
              ),
            ).then((value) {
              if (value == true) {
                final list = List<LiveArea>.from(SettingsService.to.fav.favoriteAreas.v);
                list.removeWhere((e) => e.areaId == area.areaId);
                SettingsService.to.fav.favoriteAreas.v = list;
              }
            });
          },
          child: _buildAvatar(context),
        );
      }
      return FloatingActionButton.extended(
        elevation: 2,
        backgroundColor: Theme.of(context).cardColor,
        onPressed: () {
          final list = List<LiveArea>.from(SettingsService.to.fav.favoriteAreas.v)..add(area);
          SettingsService.to.fav.favoriteAreas.v = list;
        },
        icon: _buildAvatar(context),
        label: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(i18n("follow"), style: Theme.of(context).textTheme.bodySmall),
            Text(area.areaName!, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      );
    });
  }
}
