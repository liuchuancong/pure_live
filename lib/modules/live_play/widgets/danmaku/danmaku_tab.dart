import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/pages/super_chat_page.dart';
import 'package:pure_live/modules/live_play/pages/keyword_block_page.dart';
import 'package:pure_live/modules/live_play/pages/danmaku_settings_page.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';
import 'package:pure_live/modules/live_play/widgets/danmaku/danmaku_list_view.dart';

class DanmakuTabView extends GetView<LivePlayController> {
  const DanmakuTabView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final state = controller.state.value;
      if (state.room.detail == null || state.player.videoController == null) {
        return AppStatusView(type: AppStatusType.loading, title: "", subtitle: "");
      }
      return ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            DanmakuSectionTabBar(controller: controller.tabController, tabs: controller.tabs),
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
                  // RxList mutations do not invalidate this outer Obx unless
                  // its value is read while building. Snapshot it here so new
                  // SC entries appear immediately without switching tabs.
                  Obx(() => SuperChatPage(messages: controller.superChats.toList(growable: false))),
                  DanmakuSettingsPage(controller: state.player.videoController!),
                  const KeywordBlockPage(),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// The four portrait room sections are navigation, not a free-scrolling chip
/// strip. Giving them equal bounded widths keeps the row fixed while the
/// associated [TabBarView] remains swipeable between its first and last page.
class DanmakuSectionTabBar extends StatelessWidget {
  const DanmakuSectionTabBar({super.key, required this.tabs, this.controller});

  final List<String> tabs;
  final TabController? controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: TabBar(
        key: const ValueKey('live-danmaku-section-tabs'),
        isScrollable: false,
        tabAlignment: TabAlignment.fill,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        controller: controller,
        tabs: tabs.map((name) => Tab(text: name)).toList(growable: false),
      ),
    );
  }
}
