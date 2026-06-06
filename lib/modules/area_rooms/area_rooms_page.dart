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
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
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
          child: CircleAvatar(
            foregroundImage: (area.areaPic == '') ? null : NetworkImage(area.areaPic!),
            radius: 18,
            backgroundColor: Theme.of(context).disabledColor,
          ),
        );
      }
      return FloatingActionButton.extended(
        elevation: 2,
        backgroundColor: Theme.of(context).cardColor,
        onPressed: () {
          final list = List<LiveArea>.from(SettingsService.to.fav.favoriteAreas.v)..add(area);
          SettingsService.to.fav.favoriteAreas.v = list;
        },
        icon: CircleAvatar(
          foregroundImage: (area.areaPic == '') ? null : NetworkImage(area.areaPic!),
          radius: 18,
          backgroundColor: Theme.of(context).disabledColor,
        ),
        label: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(i18n("follow"), style: Theme.of(context).textTheme.bodySmall),
            Text(area.areaName!, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      );
    });
  }
}
