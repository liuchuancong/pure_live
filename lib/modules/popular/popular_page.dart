import 'package:get/get.dart';
import 'package:pure_live/common/l10n/generated/l10n.dart';
import 'package:pure_live/common/widgets/keep_alive_wrapper.dart';
import 'package:pure_live/modules/util/site_logo_widget.dart';
import 'popular_grid_view.dart';
import 'package:flutter/material.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/routes/route_path.dart';
import 'package:pure_live/common/widgets/index.dart';
import 'package:pure_live/modules/popular/popular_controller.dart';

class PopularPage extends GetView<PopularController> {
  const PopularPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraint) {
      bool showAction = constraint.maxWidth <= 680;
      return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          scrolledUnderElevation: 0,
          leading: showAction ? const MenuButton() : null,
          actions: showAction
              ? [
                  PopupMenuButton(
                    tooltip: S.current.search,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    offset: const Offset(12, 0),
                    position: PopupMenuPosition.under,
                    icon: const Icon(Icons.read_more_sharp),
                    onSelected: (int index) {
                      if (index == 0) {
                        Get.toNamed(RoutePath.kSearch);
                      } else {
                        Get.toNamed(RoutePath.kToolbox);
                      }
                    },
                    itemBuilder: (BuildContext context) {
                      return [
                        PopupMenuItem(
                          value: 0,
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: MenuListTile(
                            leading: Icon(CustomIcons.search),
                            text: S.current.live_room_search,
                          ),
                        ),
                        PopupMenuItem(
                          value: 1,
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: MenuListTile(
                            leading: Icon(Icons.link),
                            text: S.current.live_room_link_access,
                          ),
                        ),
                      ];
                    },
                  )
                ]
              : null,
          title: TabBar(
            controller: controller.tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            labelPadding: const EdgeInsets.symmetric(horizontal: 12),
            indicatorSize: TabBarIndicatorSize.label,
            tabs: SiteWidget.availableSitesTabList,
          ),
        ),
        body: TabBarView(
          controller: controller.tabController,
          children: Sites().availableSites().map((e) => KeepAliveWrapper(child: PopularGridView(e.id))).toList(),
        ),
      );
    });
  }
}
