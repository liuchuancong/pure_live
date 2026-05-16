import 'package:get/get.dart';
import 'popular_grid_view.dart';
import 'package:flutter/material.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/common/widgets/index.dart';
import 'package:pure_live/modules/popular/popular_controller.dart';
import 'package:pure_live/common/widgets/common_appbar_actions.dart';

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
            children: Sites().availableSites().map((e) => PopularGridView(e.id)).toList(),
          ),
        );
      },
    );
  }
}
