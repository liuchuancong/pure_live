import 'popular_grid_view.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/widgets/common_appbar_actions.dart';

class PopularPage extends GetView<PopularController> {
  const PopularPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraint) {
        bool showAction = Get.width <= 680;

        return Obx(() {
          final availableSitesList = Sites().availableSites();
          if (availableSitesList.isEmpty) return const Scaffold();
          return Scaffold(
            appBar: AppBar(
              centerTitle: true,
              scrolledUnderElevation: 0,
              leading: showAction ? const MenuButton() : null,
              actions: showAction ? [CommonAppBarActions()] : null,
              title: TabBar(
                controller: controller.tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.center,
                labelStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                indicatorSize: TabBarIndicatorSize.label,
                tabs: availableSitesList.map((e) => Tab(text: e.name)).toList(),
              ),
            ),
            body: TabBarView(
              controller: controller.tabController,
              children: availableSitesList.map((e) => PopularGridView(e.id)).toList(),
            ),
          );
        });
      },
    );
  }
}
