import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:keframe/keframe.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/widgets/keep_alive_wrapper.dart';
import 'package:pure_live/modules/areas/favorite_areas_controller.dart';
import 'package:pure_live/modules/areas/widgets/area_card.dart';
import 'package:pure_live/modules/util/site_logo_widget.dart';

import '../live_play/widgets/slide_animation.dart';

class FavoriteAreasPage extends GetView<FavoriteAreasController> {
  const FavoriteAreasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraint) {
      final width = constraint.maxWidth;
      final crossAxisCount = width > 1280 ? 9 : (width > 960 ? 7 : (width > 640 ? 5 : 3));
      return Scaffold(
        appBar: AppBar(title: Text(S.current.favorite_areas)),
        body: Column(
          children: [
            TabBar(
              controller: controller.tabSiteController,
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              tabs: SiteWidget.availableSitesWithAllTabList,
            ),
            Expanded(
              child: Obx(() {
                return TabBarView(
                    controller: controller.tabSiteController,
                    children: Sites().availableSites(containsAll: true).map((e) => e.id).toList().map((e) => KeepAliveWrapper(child: buildTabView(context, crossAxisCount, e, constraint))).toList());
              }),
            )
          ],
        ),
      );
    });
  }

  Widget buildTabView(BuildContext context, int crossAxisCount, String siteId, BoxConstraints constraint) {
    return Obx(
      () => controller.favoriteAreas.isNotEmpty
          ? SizeCacheWidget(
              estimateCount: 20 * 2,
              child: MasonryGridView.count(
                  cacheExtent: 30,
                  padding: const EdgeInsets.all(5),
                  controller: ScrollController(),
                  crossAxisCount: crossAxisCount,
                  itemCount: siteId == Sites.allSite ? controller.favoriteAreas.length : controller.favoriteAreas.where((e) => e.platform == siteId).toList().length,
                  itemBuilder: (context, index) => FrameSeparateWidget(
                      index: index,
                      placeHolder: const SizedBox(width: 220.0, height: 200),
                      child: SlideTansWidget(child: AreaCard(category: siteId == Sites.allSite ? controller.favoriteAreas[index] : controller.favoriteAreas.where((e) => e.platform == siteId).toList()[index])))))
          : EmptyView(
              icon: Icons.area_chart_outlined,
              title: S.current.empty_areas_title,
              subtitle: '',
              boxConstraints: constraint,
            ),
    );
  }
}
