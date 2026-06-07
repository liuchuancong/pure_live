import 'areas_grid_view.dart';
import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/widgets/common_appbar_actions.dart';

class AreasPage extends GetView<AreasController> {
  const AreasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraint) {
        return Obx(() {
          final availableSitesList = Sites().availableSites();
          if (availableSitesList.isEmpty) return const Scaffold();
          final int menuCount = SettingsService.to.app.savedMenuIds.v.length;
          bool showAction = Get.width <= 680;

          return Scaffold(
            appBar: AppBar(
              centerTitle: true,
              leading: (showAction || menuCount <= 1) ? const MenuButton() : null,
              actions: showAction ? [CommonAppBarActions()] : null,
              title: TabBar(
                controller: controller.tabController,
                isScrollable: true,
                tabs: availableSitesList.map((e) => Tab(text: e.name)).toList(),
              ),
            ),
            body: TabBarView(
              controller: controller.tabController,
              children: availableSitesList.map((e) => AreaGridView(e.id)).toList(),
            ),
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            floatingActionButton: FloatingActionButton.extended(
              elevation: 3,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
              onPressed: () {
                Get.toNamed(RoutePath.kFavoriteAreas);
              },
              icon: const Icon(Remix.heart_add_2_line, size: 18),
              label: Text(i18n("favorite_areas"), style: AppTextStyles.t12Bold),
            ),
          );
        });
      },
    );
  }
}
