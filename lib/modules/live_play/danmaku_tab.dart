import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:pure_live/modules/live_play/live_play_controller.dart';
import 'package:pure_live/modules/live_play/widgets/danmaku_list_view.dart';
import 'package:pure_live/modules/live_play/widgets/keyword_block_page.dart';
import 'package:pure_live/modules/live_play/widgets/danmaku_settings_page.dart';

class DanmakuTabView extends StatefulWidget {
  const DanmakuTabView({super.key});

  @override
  State<DanmakuTabView> createState() => _DanmakuTabViewState();
}

class _DanmakuTabViewState extends State<DanmakuTabView> {
  final LivePlayController controller = Get.find<LivePlayController>();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Get.theme.colorScheme.surface,
          child: TabBar(
            controller: controller.tabController,
            tabs: controller.tabs.map((name) => Tab(text: name)).toList(),
            labelColor: Get.theme.colorScheme.primary, // 选中标签的颜色
            unselectedLabelColor: Get.theme.colorScheme.onSurfaceVariant, // 未选中标签的颜色
            indicatorColor: Get.theme.colorScheme.primary, // 指示器（下划线）颜色
            indicatorSize: TabBarIndicatorSize.label,
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: controller.tabController,
            children: [
              DanmakuListView(room: controller.detail.value!),
              DanmakuSettingsPage(controller: controller.videoController.value!),
              KeywordBlockPage(),
            ],
          ),
        ),
      ],
    );
  }
}
