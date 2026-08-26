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

enum LivePlayLayoutType { portrait, desktop }

LivePlayLayoutType resolveLivePlayLayoutType(double width) {
  return width <= 680 ? LivePlayLayoutType.portrait : LivePlayLayoutType.desktop;
}

class LivePlayLayout extends StatelessWidget {
  const LivePlayLayout({
    super.key,
    required this.video,
    required this.resolution,
    required this.danmaku,
    required this.layoutMode,
    this.showPanel = true,
  });

  final Widget video;
  final Widget resolution;
  final Widget danmaku;
  final PortraitLayoutMode layoutMode;
  final bool showPanel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!showPanel) {
          return _buildVideoOnlyLayout(context, constraints);
        }

        switch (resolveLivePlayLayoutType(constraints.maxWidth)) {
          case LivePlayLayoutType.portrait:
            return _buildPortraitLayout(context, constraints);
          case LivePlayLayoutType.desktop:
            return _buildDesktopLayout(context);
        }
      },
    );
  }

  Widget _buildVideoOnlyLayout(BuildContext context, BoxConstraints constraints) {
    return Align(alignment: Alignment.topCenter, child: _buildVideo(context, constraints));
  }

  Widget _buildVideo(BuildContext context, BoxConstraints constraints) {
    switch (layoutMode) {
      case PortraitLayoutMode.balanced:
        return SizedBox(
          width: constraints.maxWidth,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(color: Colors.black, child: video),
          ),
        );
      case PortraitLayoutMode.immersive:
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: ColoredBox(color: Colors.black, child: video),
        );
      case PortraitLayoutMode.compatibility:
        return _buildCompatibilityVideo(constraints);
    }
  }

  Widget _buildCompatibilityVideo(BoxConstraints constraints) {
    final player = GlobalPlayerService.instance.player;

    return StreamBuilder<List<int?>>(
      stream: CombineLatestStream.list([player.width, player.height]),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final videoWidth = data != null && data.isNotEmpty ? data[0] : null;
        final videoHeight = data != null && data.length > 1 ? data[1] : null;
        final aspectRatio = _resolveAspectRatio(videoWidth, videoHeight);
        final width = constraints.maxWidth;

        if (!constraints.hasBoundedHeight) {
          return SizedBox(
            width: width,
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: ColoredBox(color: Colors.black, child: video),
            ),
          );
        }

        final maxHeight = constraints.maxHeight * 0.6;
        final calculatedHeight = width / aspectRatio;
        final height = calculatedHeight > maxHeight ? maxHeight : calculatedHeight;

        return SizedBox(
          width: width,
          height: height,
          child: ColoredBox(color: Colors.black, child: video),
        );
      },
    );
  }

  double _resolveAspectRatio(int? width, int? height) {
    if (width == null || height == null || width <= 0 || height <= 0) {
      return 16 / 9;
    }

    final ratio = width / height;
    return ratio.isFinite && ratio > 0 ? ratio : 16 / 9;
  }

  Widget _buildPortraitLayout(BuildContext context, BoxConstraints constraints) {
    final panelColor = Theme.of(context).colorScheme.surface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildVideo(context, constraints),
        Expanded(
          child: ColoredBox(
            color: panelColor,
            child: Column(
              children: [
                resolution,
                const Divider(height: 1),
                Expanded(child: danmaku),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    const panelWidth = 340.0;
    final panelColor = Theme.of(context).colorScheme.surface;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(color: Colors.black, child: video),
        ),
        SizedBox(
          width: panelWidth,
          child: ColoredBox(
            color: panelColor,
            child: Column(
              children: [
                resolution,
                const Divider(height: 1),
                Expanded(child: danmaku),
              ],
            ),
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
    final player = GlobalPlayerService.instance.player;

    if (isInPip) {
      return Theme(
        data: ThemeData.dark(),
        child: Container(key: const ValueKey('pip'), color: Colors.transparent, child: player.buildPiPOverlay()),
      );
    }

    if (mode == VideoMode.normal) {
      return _buildNormalContent(context);
    }

    return ColoredBox(
      color: Colors.black,
      child: LivePlayVideo(controller: controller, expandToParent: true),
    );
  }

  Widget _buildNormalContent(BuildContext context) {
    final layoutMode = SettingsService.to.player.portraitLayoutMode;

    if (layoutMode == PortraitLayoutMode.immersive) {
      return _buildImmersiveLayout(context);
    }

    return _buildNormalLayout(context, layoutMode: layoutMode);
  }

  Widget _buildNormalLayout(BuildContext context, {required PortraitLayoutMode layoutMode}) {
    final compactHeader = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: LivePlayHeader(controller: controller, compactHeader: compactHeader),
      body: SafeArea(
        child: LivePlayLayout(
          layoutMode: layoutMode,
          video: LivePlayVideo(controller: controller, expandToParent: false),
          resolution: const ResolutionsRow(),
          danmaku: _buildDanmakuContent(),
          showPanel: controller.site != Sites.iptvSite,
        ),
      ),
    );
  }

  Widget _buildImmersiveLayout(BuildContext context) {
    final compactHeader = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: LivePlayHeader(controller: controller, compactHeader: compactHeader),
      body: SafeArea(child: LivePlayShell(controller: controller)),
    );
  }

  Widget _buildDanmakuContent() {
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

      return const DanmakuTabView();
    });
  }
}
