import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/states/ui_state.dart';
import 'package:pure_live/player/core/portrait_stream_support.dart';
import 'package:pure_live/modules/live_play/controllers/player_state.dart';
import 'package:pure_live/modules/live_play/widgets/danmaku/danmaku_tab.dart';
import 'package:pure_live/modules/live_play/widgets/layout/live_play_video.dart';
import 'package:pure_live/modules/live_play/widgets/layout/live_play_header.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';
import 'package:pure_live/modules/live_play/widgets/resolution_selector/resolutions_row.dart';

enum LivePlayNormalLayoutKind { portraitStack, desktopSplit }

LivePlayNormalLayoutKind resolveLivePlayNormalLayout(double width) {
  return width <= 680 ? LivePlayNormalLayoutKind.portraitStack : LivePlayNormalLayoutKind.desktopSplit;
}

/// Stable normal-room composition shared by production and widget tests.
///
/// The video, quality selector and danmaku list must remain simultaneously
/// visible on a phone. Hiding them behind a full-surface flip/drawer makes a
/// normal room indistinguishable from fullscreen and leaves no discoverable
/// interaction surface.
class LivePlayNormalLayout extends StatelessWidget {
  const LivePlayNormalLayout({
    super.key,
    required this.video,
    required this.resolution,
    required this.danmaku,
    this.showPanel = true,
    this.isPortraitSource = false,
    this.sourceAspectRatio = 16 / 9,
    this.adaptivePortraitHeight = false,
    this.portraitLayoutMode = PortraitLayoutMode.balanced,
  });

  final Widget video;
  final Widget resolution;
  final Widget danmaku;
  final bool showPanel;
  final bool isPortraitSource;
  final double sourceAspectRatio;
  final bool adaptivePortraitHeight;
  final PortraitLayoutMode portraitLayoutMode;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!showPanel) {
          return Align(
            key: const ValueKey('live-play-video-only-layout'),
            alignment: Alignment.topCenter,
            child: video,
          );
        }
        if (resolveLivePlayNormalLayout(constraints.maxWidth) == LivePlayNormalLayoutKind.portraitStack) {
          final useAdaptivePortraitFrame =
              isPortraitSource && adaptivePortraitHeight && portraitLayoutMode != PortraitLayoutMode.compatibility;
          return Column(
            key: const ValueKey('live-play-portrait-stack'),
            children: [
              if (useAdaptivePortraitFrame)
                AnimatedContainer(
                  key: const ValueKey('live-play-adaptive-video-frame'),
                  width: constraints.maxWidth,
                  height: PortraitPresentationPolicy.resolveNormalVideoHeight(
                    availableWidth: constraints.maxWidth,
                    availableHeight: constraints.maxHeight,
                    isPortraitSource: true,
                    sourceAspectRatio: sourceAspectRatio,
                    adaptiveHeightEnabled: true,
                    mode: portraitLayoutMode,
                  ),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  clipBehavior: Clip.hardEdge,
                  decoration: const BoxDecoration(color: Colors.black),
                  child: video,
                )
              else
                video,
              resolution,
              const Divider(height: 1),
              Expanded(
                key: const ValueKey('live-play-portrait-danmaku'),
                child: ColoredBox(color: Theme.of(context).colorScheme.surface, child: danmaku),
              ),
            ],
          );
        }

        final panelWidth = (constraints.maxWidth * 0.34).clamp(300.0, 400.0);
        return Row(
          key: const ValueKey('live-play-desktop-split'),
          children: [
            Expanded(child: video),
            SizedBox(
              key: const ValueKey('live-play-desktop-panel'),
              width: panelWidth,
              child: Column(
                children: [
                  resolution,
                  const Divider(height: 1),
                  Expanded(child: danmaku),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

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
      return ColoredBox(
        key: const ValueKey('normal'),
        color: Theme.of(context).scaffoldBackgroundColor,
        child: _buildNormalView(context),
      );
    }

    return Container(
      color: Colors.black,
      child: LivePlayVideo(controller: controller, expandToParent: true),
    );
  }

  Widget _buildNormalView(BuildContext context) {
    final compactHeader = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: LivePlayHeader(controller: controller, compactHeader: compactHeader),
      body: SafeArea(
        child: Obx(() {
          final manager = GlobalPlayerService.instance.player;
          final settings = SettingsService.to.player;
          final isPortrait = manager.isVerticalVideo.value;
          final useAdaptivePortraitFrame =
              MediaQuery.sizeOf(context).width <= 680 &&
              isPortrait &&
              settings.enablePortraitStreamAdaptation.v &&
              settings.portraitAdaptiveHeight.v &&
              settings.portraitLayoutMode != PortraitLayoutMode.compatibility;
          return LivePlayNormalLayout(
            video: LivePlayVideo(controller: controller, expandToParent: useAdaptivePortraitFrame),
            resolution: const ResolutionsRow(),
            danmaku: _buildDanmaku(),
            showPanel: controller.site != Sites.iptvSite,
            isPortraitSource: isPortrait,
            sourceAspectRatio: manager.currentPresentationAspectRatio,
            adaptivePortraitHeight: settings.enablePortraitStreamAdaptation.v && settings.portraitAdaptiveHeight.v,
            portraitLayoutMode: settings.portraitLayoutMode,
          );
        }),
      ),
    );
  }

  Widget _buildDanmaku() {
    return Obx(() {
      final state = controller.state.value;
      if (!state.room.success || controller.site == Sites.iptvSite) {
        return const SizedBox.shrink();
      }
      final globalState = GlobalPlayerState.to;
      if (globalState.isFullscreen.value || globalState.isWindowFullscreen.value) {
        return const SizedBox.shrink();
      }
      return const DanmakuTabView();
    });
  }
}
