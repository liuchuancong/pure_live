import 'package:get/get.dart';
import 'areas_grid_view.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/widgets/common_appbar_actions.dart';

class AreasPage extends GetView<AreasController> {
  const AreasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraint) {
        bool showAction = Get.width <= 680;
        return Scaffold(
          appBar: AppBar(
            centerTitle: true,
            scrolledUnderElevation: 0,
            leading: showAction ? const MenuButton() : null,
            actions: showAction ? [CommonAppBarActions()] : null,
            flexibleSpace: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  height: kToolbarHeight,
                  alignment: Alignment.center,
                  child: TabBar(
                    controller: controller.tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.center,
                    labelStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                    indicatorSize: TabBarIndicatorSize.label,
                    tabs: Sites().availableSites().map((e) => Tab(text: e.name)).toList(),
                  ),
                ),
              ),
            ),
          ),
          body: TabBarView(
            controller: controller.tabController,
            children: controller.sites.map((e) => AreaGridView(e.id)).toList(),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Get.toNamed(RoutePath.kFavoriteAreas);
            },
            child: const Icon(Icons.favorite_rounded),
          ),
        );
      },
    );
  }
}
