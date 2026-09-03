import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:waterfall_flow/waterfall_flow.dart';
import 'package:pure_live/modules/areas/widgets/area_card.dart';
import 'package:pure_live/modules/areas/favorite_areas_controller.dart';

class FavoriteAreasPage extends GetView<FavoriteAreasController> {
  const FavoriteAreasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraint) {
        final width = constraint.maxWidth;
        final crossAxisCount = width > 1280 ? 9 : (width > 960 ? 7 : (width > 640 ? 5 : 3));
        return Scaffold(
          appBar: AppBar(title: Text(i18n('favorite_areas'))),
          body: Column(
            children: [
              TabBar(
                key: const ValueKey('favorite-areas-platform-tabs'),
                controller: controller.tabSiteController,
                isScrollable: true,
                physics: const PureLiveBoundedScrollPhysics(),
                tabs: Sites()
                    .availableSites(containsAll: true)
                    .map<Widget>((e) => Tab(text: e.name))
                    .toList(),
              ),
              Expanded(
                child: Obx(() {
                  return TabBarView(
                    controller: controller.tabSiteController,
                    physics: const PureLiveBoundedScrollPhysics(),
                    children: Sites()
                        .availableSites(containsAll: true)
                        .map((e) => e.id)
                        .toList()
                        .map((e) => buildTabView(context, crossAxisCount, e))
                        .toList(),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildTabView(BuildContext context, int crossAxisCount, String siteId) {
    return Obx(() {
      final areas = siteId == Sites.allSite
          ? controller.favoriteAreas.toList(growable: false)
          : controller.favoriteAreas
                .where((area) => area.platform == siteId)
                .toList(growable: false);
      return areas.isNotEmpty
          ? WaterfallFlow.builder(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              physics: const PureLiveScrollPhysics(),
              gridDelegate: SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
                lastChildLayoutTypeBuilder: (index) => LastChildLayoutType.none,
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: SettingsService.to.theme.crossAxisSpacing.v,
                mainAxisSpacing: SettingsService.to.theme.mainAxisSpacing.v,
              ),
              itemCount: areas.length,
              itemBuilder: (context, index) => AreaCard(category: areas[index]),
            )
          : EmptyView(icon: Remix.apps_2_line, title: i18n('empty_areas_title'), subtitle: '');
    });
  }
}
