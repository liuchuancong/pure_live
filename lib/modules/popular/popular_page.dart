import 'popular_grid_view.dart';

import 'package:flutter/gestures.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/widgets/common_appbar_actions.dart';

class PopularPage extends GetView<PopularController> {
  const PopularPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraint) {
        return Obx(() {
          bool showAction = Get.width <= 680;

          final availableSitesList = Sites().availableSites();

          if (availableSitesList.isEmpty) return const Scaffold();

          return Scaffold(
            appBar: AppBar(
              centerTitle: true,
              leading: showAction ? const MenuButton() : null,
              actions: showAction ? [CommonAppBarActions()] : null,
              title: TabBar(
                controller: controller.tabController,
                isScrollable: true,
                physics: const PureLiveScrollPhysics(),
                dragStartBehavior: DragStartBehavior.down,
                tabs: availableSitesList.map((e) => Tab(text: e.name)).toList(),
              ),
            ),
            body: TabBarView(
              controller: controller.tabController,
              physics: const PureLiveScrollPhysics(),
              dragStartBehavior: DragStartBehavior.down,
              children: availableSitesList.map((e) => PopularGridView(e.id)).toList(),
            ),
          );
        });
      },
    );
  }
}
