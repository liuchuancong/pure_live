import 'package:rxdart/rxdart.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/states/ui_state.dart';
import 'package:pure_live/player/core/portrait_stream_support.dart';
import 'package:pure_live/modules/live_play/controllers/player_state.dart';
import 'package:pure_live/modules/live_play/widgets/danmaku/danmaku_tab.dart';
import 'package:pure_live/modules/live_play/widgets/layout/live_play_shell.dart';
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

    if (mode != VideoMode.normal) {
      return Container(
        color: Colors.black,
        child: LivePlayVideo(controller: controller),
      );
    }

    return Container(key: const ValueKey('normal'), color: Colors.black, child: _buildPortraitLayout(context));
  }

  Widget _buildPortraitLayout(BuildContext context) {
    final settings = SettingsService.to.player;

    return switch (settings.portraitLayoutMode) {
      PortraitLayoutMode.balanced => _buildNormalView(context),
      PortraitLayoutMode.immersive => _buildImmersiveView(context),
      PortraitLayoutMode.compatibility => _buildMobileLayout(),
    };
  }

  /// 普通播放布局
  Widget _buildNormalView(BuildContext context) {
    final compactHeader = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: LivePlayHeader(controller: controller, compactHeader: compactHeader),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth <= 680) {
            return _buildMobileLayout();
          }
          return _buildDesktopLayout();
        },
      ),
    );
  }

  /// 沉浸式播放布局
  Widget _buildImmersiveView(BuildContext context) {
    final compactHeader = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: LivePlayHeader(controller: controller, compactHeader: compactHeader),
      body: LivePlayShell(controller: controller),
    );
  }

  /// 小屏普通布局
  Widget _buildMobileLayout() {
    final player = GlobalPlayerService.instance.player;
    final settings = SettingsService.to.player;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            StreamBuilder<List<int?>>(
              stream: CombineLatestStream.list([player.width, player.height]),
              builder: (context, snapshot) {
                final vW = snapshot.data?[0];
                final vH = snapshot.data?[1];

                var aspectRatio = 16 / 9;

                if (vW != null && vH != null && vW > 0 && vH > 0) {
                  final ratio = vW / vH;

                  if (ratio >= 0.5 && ratio <= 3.0) {
                    aspectRatio = ratio;
                  }
                }

                final videoWidth = constraints.maxWidth;

                if (!settings.portraitAdaptiveHeight.value) {
                  aspectRatio = 16 / 9;
                }

                final videoHeight = videoWidth / aspectRatio;

                final maxVideoHeight = constraints.maxHeight * 0.6;

                final height = videoHeight.clamp(0.0, maxVideoHeight);

                return SizedBox(
                  width: videoWidth,
                  height: height,
                  child: LivePlayVideo(controller: controller),
                );
              },
            ),
            Expanded(child: _buildSidePanel()),
          ],
        );
      },
    );
  }

  /// 大屏普通布局
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(child: LivePlayVideo(controller: controller)),
        _buildSidePanel(),
      ],
    );
  }

  Widget _buildSidePanel() {
    return Obx(() {
      final state = controller.state.value;
      final detail = state.room.detail;

      if (detail == null) {
        return const SizedBox.shrink();
      }

      if (detail.platform == Sites.iptvSite) {
        return const SizedBox.shrink();
      }

      return Material(
        color: Theme.of(Get.context!).colorScheme.surface,
        elevation: 18,
        shadowColor: Colors.black.withValues(alpha: 0.5),
        child: SizedBox(
          width: 400,
          child: Column(
            children: [
              const ResolutionsRow(),
              const Divider(height: 1),
              if (state.room.success) _buildDanmaku(expanded: true),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildDanmaku({required bool expanded}) {
    return Obx(() {
      final state = controller.state.value;

      if (!state.room.success) {
        return const SizedBox.shrink();
      }

      if (controller.site == Sites.iptvSite) {
        return const SizedBox.shrink();
      }

      final globalState = GlobalPlayerState.to;

      if (globalState.isFullscreen.value || globalState.isWindowFullscreen.value) {
        return const SizedBox.shrink();
      }

      final child = const DanmakuTabView();

      if (!expanded) {
        return child;
      }

      return Expanded(child: child);
    });
  }
}
