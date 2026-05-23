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
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraint) {
        final width = constraint.maxWidth;
        final crossAxisCount = width > 1280 ? 5 : (width > 960 ? 4 : (width > 640 ? 3 : 2));

        return Obx(() {
          if (controller.list.isEmpty) {
            return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary, strokeWidth: 3));
          }

          return EasyRefresh(
            controller: controller.easyRefreshController,
            onRefresh: controller.refreshData,
            onLoad: controller.loadData,
            child: WaterfallFlow.builder(
              padding: const EdgeInsets.all(0),
              controller: controller.scrollController,
              gridDelegate: SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
                lastChildLayoutTypeBuilder: (index) => LastChildLayoutType.none,
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 3,
                mainAxisSpacing: 3,
              ),
              itemCount: controller.list.length,
              itemBuilder: (context, index) => RoomCard(room: controller.list[index], dense: true),
            ),
          );
        });
      },
    );
  }
}
