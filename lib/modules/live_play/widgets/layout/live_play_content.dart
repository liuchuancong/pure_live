import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/states/ui_state.dart';
import 'package:pure_live/modules/live_play/controllers/player_state.dart';
import 'package:pure_live/modules/live_play/widgets/danmaku/danmaku_tab.dart';
import 'package:pure_live/modules/live_play/widgets/layout/live_play_video.dart';
import 'package:pure_live/modules/live_play/widgets/layout/live_play_header.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';
import 'package:pure_live/modules/live_play/widgets/resolution_selector/resolutions_row.dart';

class LivePlayContent extends StatelessWidget {
  const LivePlayContent({super.key, required this.controller, required this.isInPip, required this.mode});

  final LivePlayController controller;
  final bool isInPip;
  final VideoMode mode;

  @override
  Widget build(BuildContext context) {
    final manager = GlobalPlayerService.instance.player;

    if (isInPip) {
      return Theme(
        data: ThemeData.dark(),
        child: Container(key: const ValueKey('pip'), color: Colors.transparent, child: manager.buildPiPOverlay()),
      );
    }

    if (mode == VideoMode.normal) {
      return Container(key: const ValueKey('normal'), color: Colors.black, child: _buildNormalView(context));
    }

    return Container(
      key: const ValueKey('widescreen'),
      color: Colors.black,
      child: LivePlayVideo(controller: controller, widescreen: true),
    );
  }

  Widget _buildNormalView(BuildContext context) {
    final compactHeader = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      appBar: LivePlayHeader(controller: controller, compactHeader: compactHeader),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = Get.width;

          return SafeArea(child: width <= 680 ? _buildMobileLayout() : _buildDesktopLayout());
        },
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        LivePlayVideo(controller: controller),

        const ResolutionsRow(),

        const Divider(height: 1),

        _buildDanmaku(expanded: true),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(child: LivePlayVideo(controller: controller)),

        Obx(() {
          final state = controller.state.value;
          final detail = state.room.detail;

          if (detail == null) {
            return const SizedBox.shrink();
          }

          if (detail.platform == Sites.iptvSite) {
            return const SizedBox.shrink();
          }

          return SizedBox(
            width: 400,
            child: Column(
              children: [
                const ResolutionsRow(),

                const Divider(height: 1),

                if (state.room.success) _buildDanmaku(expanded: true),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDanmaku({required bool expanded}) {
    return Obx(() {
      final state = controller.state.value;

      if (!state.room.success || controller.site == Sites.iptvSite) {
        return const SizedBox.shrink();
      }

      final globalState = GlobalPlayerState.to;

      if (globalState.isFullscreen.value || globalState.isWindowFullscreen.value) {
        return const SizedBox.shrink();
      }

      final child = DanmakuTabView(key: ValueKey(globalState.isFullscreen.value));

      return expanded ? Expanded(child: child) : child;
    });
  }
}
