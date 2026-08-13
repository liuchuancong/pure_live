import 'package:pure_live/common/index.dart';
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
        return AppStatusView(type: AppStatusType.loading, title: "", subtitle: "");
      }
      return Column(
        children: [
          Container(
            color: Get.theme.colorScheme.surface,
            child: TabBar(
              isScrollable: true,
              controller: controller.tabController,
              tabs: controller.tabs.map((name) => Tab(text: name)).toList(),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: controller.tabController,
              children: [
                SettingsService.to.danmaku.enableDanmakuDisplay.v
                    ? DanmakuListView(room: controller.detail.value!)
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.comments_disabled_outlined, size: 42, color: Theme.of(context).disabledColor),
                              const SizedBox(height: 12),
                              Text(
                                i18n('danmaku_display_disabled_hint'),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
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
