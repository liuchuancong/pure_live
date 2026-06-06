import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

class PopularGridView extends StatefulWidget {
  final String tag;
  const PopularGridView(this.tag, {super.key});
  @override
  State<PopularGridView> createState() => _PopularGridViewState();
}

class _PopularGridViewState extends State<PopularGridView> {
  BasePageScrollAndStateBone<LiveRoom> get controller =>
      Get.find<BasePageScrollAndStateBone<LiveRoom>>(tag: widget.tag);

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
          ),
          contentBuilder: (context, list, scrollController) {
            return WaterfallFlow.builder(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              controller: scrollController,
              gridDelegate: SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
                lastChildLayoutTypeBuilder: (index) => LastChildLayoutType.none,
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: SettingsService.to.theme.crossAxisSpacing.v,
                mainAxisSpacing: SettingsService.to.theme.mainAxisSpacing.v,
              ),
              itemCount: list.length,
              itemBuilder: (context, index) => RoomCard(room: list[index], dense: true),
            );
          },
        );
      },
    );
  }
}
