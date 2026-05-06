import 'package:get/get.dart';
import 'popular_grid_view.dart';
import 'package:flutter/material.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/routes/route_path.dart';
import 'package:remixicon/remixicon.dart' show Remix;
import 'package:pure_live/common/widgets/index.dart';
import 'package:pure_live/modules/popular/popular_controller.dart';

class PopularPage extends GetView<PopularController> {
  const PopularPage({super.key});

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
            actions: showAction
                ? [
                    PopupMenuButton<int>(
                      // 更换为更简洁的更多图标
                      icon: const Icon(Remix.more_2_fill, size: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12), // 增大圆角更圆润
                      ),
                      offset: const Offset(0, 10), // 调整垂直偏移，使菜单紧贴按钮
                      position: PopupMenuPosition.under,
                      onSelected: (index) {
                        if (index == 0) {
                          Get.toNamed(RoutePath.kSearch);
                        } else {
                          Get.toNamed(RoutePath.kToolbox);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Icon(Remix.search_line, size: 20, color: Theme.of(context).primaryColor),
                              const SizedBox(width: 12),
                              const Text("搜索直播", style: TextStyle(fontSize: 14)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 1,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Icon(Remix.link, size: 20, color: Theme.of(context).primaryColor),
                              const SizedBox(width: 12),
                              const Text("链接访问", style: TextStyle(fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ]
                : null,
            title: TabBar(
              controller: controller.tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              labelStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              labelPadding: const EdgeInsets.symmetric(horizontal: 12),
              indicatorSize: TabBarIndicatorSize.label,
              tabs: Sites().availableSites().map((e) => Tab(text: e.name)).toList(),
            ),
          ),
          body: TabBarView(
            controller: controller.tabController,
            children: Sites().availableSites().map((e) => PopularGridView(e.id)).toList(),
          ),
        );
      },
    );
  }
}
