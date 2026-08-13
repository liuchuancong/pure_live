import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';

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
            buttonText: i18n('refresh'),
            onButtonPressed: () => controller.refreshData(),
          ),
          contentBuilder: (context, list, scrollController) {
            final spacing = SettingsService.to.theme.crossAxisSpacing.v;
            final itemWidth = (width - 12 - spacing * (crossAxisCount - 1)) / crossAxisCount;
            return GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              controller: scrollController,
              cacheExtent: 480,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: spacing,
                mainAxisSpacing: SettingsService.to.theme.mainAxisSpacing.v,
                mainAxisExtent: itemWidth * 9 / 16 + 72,
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
