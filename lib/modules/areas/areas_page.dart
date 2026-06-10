import 'dart:ui';
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
            floatingActionButton: Padding(
              padding: EdgeInsets.only(bottom: Get.width > 680 ? 24 : 0, right: 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15), width: 1),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Get.toNamed(RoutePath.kFavoriteAreas),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Remix.heart_add_2_line, size: 16, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              i18n("favorite_areas"),
                              style: AppTextStyles.t12Bold.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        });
      },
    );
  }
}
