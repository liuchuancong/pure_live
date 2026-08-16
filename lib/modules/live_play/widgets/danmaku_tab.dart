import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/widgets/danmaku_list_view.dart';
import 'package:pure_live/modules/live_play/widgets/keyword_block_page.dart';
import 'package:pure_live/modules/live_play/widgets/danmaku_settings_page.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';

class DanmakuTabView extends GetView<LivePlayController> {
  const DanmakuTabView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final state = controller.state.value;
      if (state.room.detail == null || state.player.videoController == null) {
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
                    ? DanmakuListView(room: state.room.detail!)
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(i18n('danmaku_display_disabled_hint'), textAlign: TextAlign.center),
                        ),
                      ),
                DanmakuSettingsPage(controller: state.player.videoController!),
                const KeywordBlockPage(),
              ],
            ),
          ),
        ],
      );
    });
  }
}
