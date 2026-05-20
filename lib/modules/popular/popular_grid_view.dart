import 'package:pure_live/common/index.dart';
import 'package:waterfall_flow/waterfall_flow.dart';
import 'package:pure_live/modules/popular/popular_grid_controller.dart';

class PopularGridView extends StatefulWidget {
  final String tag;

  const PopularGridView(this.tag, {super.key});

  @override
  State<PopularGridView> createState() => _PopularGridViewState();
}

class _PopularGridViewState extends State<PopularGridView> {
  PopularGridController get controller => Get.find<PopularGridController>(tag: widget.tag);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraint) {
        final width = constraint.maxWidth;
        final crossAxisCount = width > 1280 ? 5 : (width > 960 ? 4 : (width > 640 ? 3 : 2));
        return Obx(
          () => EasyRefresh(
            controller: controller.easyRefreshController,
            onRefresh: controller.refreshData,
            onLoad: controller.loadData,
            child: controller.list.isNotEmpty
                ? WaterfallFlow.builder(
                    padding: const EdgeInsets.all(0),
                    controller: controller.scrollController,
                    gridDelegate: SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 3,
                      mainAxisSpacing: 3,
                    ),
                    itemCount: controller.list.length,
                    itemBuilder: (context, index) => RoomCard(room: controller.list[index], dense: true),
                  )
                : EmptyView(
                    icon: Icons.live_tv_rounded,
                    title: i18n("empty_live_title"),
                    subtitle: i18n("empty_live_subtitle"),
                  ),
          ),
        );
      },
    );
  }
}
