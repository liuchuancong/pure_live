import 'dart:math' as math;

import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/live_play/widgets/danmaku/danmaku_tab.dart';
import 'package:pure_live/modules/live_play/widgets/layout/live_play_video.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';
import 'package:pure_live/modules/live_play/widgets/resolution_selector/resolutions_row.dart';

class LivePlayShell extends StatefulWidget {
  const LivePlayShell({super.key, required this.controller, this.showPanel = true});

  final LivePlayController controller;
  final bool showPanel;

  @override
  State<LivePlayShell> createState() => _LivePlayShellState();
}

class _LivePlayShellState extends State<LivePlayShell> with SingleTickerProviderStateMixin {
  static const double _desktopPanelWidth = 380.0;

  late final AnimationController _drawerController;

  LivePlayController get controller => widget.controller;

  bool get showPanel => widget.showPanel;

  bool _panelOpen = false;

  @override
  void initState() {
    super.initState();
    _drawerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 240),
    );
  }

  @override
  void dispose() {
    _drawerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showPanel) {
      return const _VideoHost();
    }

    final size = MediaQuery.sizeOf(context);
    final isSmallScreen = size.shortestSide < 600;

    return ClipRect(
      child: AnimatedBuilder(
        animation: _drawerController,
        builder: (context, child) {
          final progress = Curves.easeInOutCubic.transform(_drawerController.value);

          if (isSmallScreen) {
            return _buildMobileLayout(progress);
          }

          return _buildDesktopLayout(progress);
        },
      ),
    );
  }

  Widget _buildDesktopLayout(double progress) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildDesktopVideo(progress),
        _buildDesktopPanel(progress),
        _buildToggleButton(progress),
      ],
    );
  }

  Widget _buildDesktopVideo(double progress) {
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      right: _desktopPanelWidth * progress,
      child: const _VideoHost(),
    );
  }

  Widget _buildDesktopPanel(double progress) {
    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      width: _desktopPanelWidth,
      child: IgnorePointer(
        ignoring: progress < 0.01,
        child: Opacity(opacity: progress, child: _buildPanelContent()),
      ),
    );
  }

  Widget _buildMobileLayout(double progress) {
    return Stack(
      fit: StackFit.expand,
      children: [_buildMobileFlip(progress), _buildToggleButton(progress)],
    );
  }

  Widget _buildMobileFlip(double progress) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0018)
          ..rotateY(math.pi * progress);

        return Center(
          child: Transform(
            alignment: Alignment.center,
            transform: matrix,
            child: Stack(
              fit: StackFit.expand,
              children: [_buildMobileVideoFace(progress), _buildMobilePanelFace(progress)],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileVideoFace(double progress) {
    final opacity = progress <= 0.5 ? 1.0 : 0.0;

    return IgnorePointer(
      ignoring: progress > 0.5,
      child: Opacity(opacity: opacity, child: const _VideoHost()),
    );
  }

  Widget _buildMobilePanelFace(double progress) {
    final opacity = progress >= 0.5 ? 1.0 : 0.0;
    final matrix = Matrix4.identity()..rotateY(math.pi);

    return IgnorePointer(
      ignoring: progress < 0.5,
      child: Opacity(
        opacity: opacity,
        child: Transform(
          alignment: Alignment.center,
          transform: matrix,
          child: _buildPanelContent(),
        ),
      ),
    );
  }

  Widget _buildToggleButton(double progress) {
    final isDesktop = MediaQuery.sizeOf(context).shortestSide >= 600;
    final rightOffset = isDesktop ? _desktopPanelWidth * progress : 0;

    return Positioned(
      top: 0,
      bottom: 0,
      right: rightOffset + 16,
      child: Center(
        child: SafeArea(
          child: Material(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: IconButton(
              tooltip: _panelOpen ? i18n('close_panel') : i18n('open_panel'),
              onPressed: _togglePanel,
              icon: AnimatedRotation(
                turns: _panelOpen ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                child: const Icon(Icons.keyboard_double_arrow_left, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanelContent() {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 18,
      shadowColor: Colors.black.withValues(alpha: 0.5),
      child: SafeArea(
        left: false,
        child: Column(
          children: [
            _buildResolution(),
            const Divider(height: 1),
            Expanded(child: _buildDanmaku()),
          ],
        ),
      ),
    );
  }

  Widget _buildResolution() {
    return Obx(() {
      final state = controller.state.value;
      final detail = state.room.detail;

      if (detail == null || detail.platform == Sites.iptvSite) {
        return const SizedBox.shrink();
      }

      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: ResolutionsRow(),
      );
    });
  }

  Widget _buildDanmaku() {
    return Obx(() {
      final state = controller.state.value;

      if (!state.room.success || controller.site == Sites.iptvSite) {
        return const SizedBox.shrink();
      }

      return const DanmakuTabView();
    });
  }

  Future<void> _togglePanel() async {
    if (_drawerController.isAnimating) return;

    if (_panelOpen) {
      await _closePanel();
    } else {
      await _openPanel();
    }
  }

  Future<void> _openPanel() async {
    if (_panelOpen || !mounted) return;

    setState(() => _panelOpen = true);
    await _drawerController.forward();
  }

  Future<void> _closePanel() async {
    if (!_panelOpen || _drawerController.isAnimating) return;

    await _drawerController.reverse();

    if (!mounted) return;

    setState(() => _panelOpen = false);
  }
}

class _VideoHost extends StatelessWidget {
  const _VideoHost();

  @override
  Widget build(BuildContext context) {
    final shell = context.findAncestorStateOfType<_LivePlayShellState>();

    if (shell == null) {
      return const SizedBox.shrink();
    }

    return LivePlayVideo(controller: shell.controller, expandToParent: !shell.showPanel);
  }
}
