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

        final layoutKind = resolveLivePlayNormalLayout(constraints.maxWidth);

        if (layoutKind == LivePlayNormalLayoutKind.portraitStack) {
          return _buildPortraitStack(context, constraints);
        }

        return _buildDesktopSplit(constraints);
      },
    );
  }

  Widget _buildPortraitStack(BuildContext context, BoxConstraints constraints) {
    final useAdaptivePortraitFrame =
        isPortraitSource && adaptivePortraitHeight && portraitLayoutMode != PortraitLayoutMode.compatibility;

    return Column(
      key: const ValueKey('live-play-portrait-stack'),
      children: [
        _buildPortraitVideo(context, constraints, useAdaptivePortraitFrame),
        resolution,
        const Divider(height: 1),
        Expanded(
          key: const ValueKey('live-play-portrait-danmaku'),
          child: ColoredBox(color: Theme.of(context).colorScheme.surface, child: danmaku),
        ),
      ],
    );
  }

  Widget _buildPortraitVideo(BuildContext context, BoxConstraints constraints, bool useAdaptivePortraitFrame) {
    if (!useAdaptivePortraitFrame) {
      return video;
    }

    final height = PortraitPresentationPolicy.resolveNormalVideoHeight(
      availableWidth: constraints.maxWidth,
      availableHeight: constraints.maxHeight,
      isPortraitSource: true,
      sourceAspectRatio: sourceAspectRatio,
      adaptiveHeightEnabled: true,
      mode: portraitLayoutMode,
    );

    return AnimatedContainer(
      key: const ValueKey('live-play-adaptive-video-frame'),
      width: constraints.maxWidth,
      height: height,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(color: Colors.black),
      child: video,
    );
  }

  Widget _buildDesktopSplit(BoxConstraints constraints) {
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
        child: _buildPortraitLayout(context),
      );
    }

    return Container(
      color: Colors.black,
      child: LivePlayVideo(controller: controller, expandToParent: true),
    );
  }

  Widget _buildPortraitLayout(BuildContext context) {
    final settings = SettingsService.to.player;

    return switch (settings.portraitLayoutMode) {
      PortraitLayoutMode.balanced => _buildNormalView(context),
      PortraitLayoutMode.immersive => _buildImmersiveView(context),
      PortraitLayoutMode.compatibility => _buildCompatibilityView(),
    };
  }

  /// 普通播放布局
  Widget _buildNormalView(BuildContext context) {
    final compactHeader = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: LivePlayHeader(controller: controller, compactHeader: compactHeader),
      body: SafeArea(
        child: Obx(() {
          final manager = GlobalPlayerService.instance.player;
          final settings = SettingsService.to.player;
          final geometry = manager.videoGeometry.value;
          final isPortrait = manager.isVerticalVideo.value;

          final width = MediaQuery.sizeOf(context).width;

          final isSmallScreen = width <= 680;

          final adaptiveHeightEnabled = settings.enablePortraitStreamAdaptation.v && settings.portraitAdaptiveHeight.v;

          final useAdaptivePortraitFrame =
              isSmallScreen &&
              isPortrait &&
              adaptiveHeightEnabled &&
              settings.portraitLayoutMode != PortraitLayoutMode.compatibility;

          final sourceAspectRatio = isPortrait && (!geometry.hasValidDimensions || !geometry.isStable)
              ? 9 / 16
              : geometry.aspectRatio;

          return LivePlayNormalLayout(
            video: LivePlayVideo(controller: controller, expandToParent: useAdaptivePortraitFrame),
            resolution: const ResolutionsRow(),
            danmaku: _buildDanmaku(),
            showPanel: controller.site != Sites.iptvSite,
            isPortraitSource: isPortrait,
            sourceAspectRatio: sourceAspectRatio,
            adaptivePortraitHeight: adaptiveHeightEnabled,
            portraitLayoutMode: settings.portraitLayoutMode,
          );
        }),
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

  Widget _buildCompatibilityView() {
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
                if (!settings.portraitAdaptiveHeight.value) {
                  aspectRatio = 16 / 9;
                }
                final videoWidth = constraints.maxWidth;
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
            Expanded(child: _buildCompatibilityPanel()),
          ],
        );
      },
    );
  }

  Widget _buildCompatibilityPanel() {
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
        child: Column(
          children: [
            const ResolutionsRow(),
            const Divider(height: 1),
            if (state.room.success) Expanded(child: _buildDanmaku(expanded: false)),
          ],
        ),
      );
    });
  }

  Widget _buildDanmaku({bool expanded = false}) {
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
