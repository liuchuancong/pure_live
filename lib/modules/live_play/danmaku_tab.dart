import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:pure_live/modules/live_play/live_play_controller.dart';
import 'package:pure_live/modules/live_play/widgets/danmaku_list_view.dart';
import 'package:pure_live/modules/live_play/widgets/keyword_block_page.dart';
import 'package:pure_live/modules/live_play/widgets/danmaku_settings_page.dart';

class DanmakuTabView extends GetView<LivePlayController> {
  const DanmakuTabView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.detail.value == null || controller.videoController.value == null) {
        return const Center(child: CircularProgressIndicator());
      }

      return Column(
        children: [
          Container(
            color: Get.theme.colorScheme.surface,
            child: TabBar(
              controller: controller.tabController,
              tabs: controller.tabs.map((name) => Tab(text: name)).toList(),
              labelColor: Get.theme.colorScheme.primary,
              unselectedLabelColor: Get.theme.colorScheme.onSurfaceVariant,
              indicatorColor: Get.theme.colorScheme.primary,
              indicatorSize: TabBarIndicatorSize.label,
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: controller.tabController,
              children: [
                DanmakuListView(room: controller.detail.value!),
                DanmakuSettingsPage(controller: controller.videoController.value!),
                const KeywordBlockPage(),
              ],
            ),
          ),
        ],
      );
    });
  }
}
