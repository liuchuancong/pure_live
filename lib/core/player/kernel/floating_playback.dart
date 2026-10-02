import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/config/float_window_geometry.dart';
import 'package:pure_live/core/player/presentation/compact_source_orientation.dart';
import 'package:media_core_floating/media_core_floating.dart';
import 'package:pure_live/domains/live/domain/live_player_facade.dart';

///

class FloatingPlayback {
  FloatingPlayback({required this.facade});

  final LivePlayerFacade facade;

  final RxBool isFloating = false.obs;
  final RxBool isFloatingVideoVisible = true.obs;
  OverlayEntry? _entry;
  FacadeStreamCommit? _reentrySeed;
  bool _prepared = false;

  /// 房间侧登记的收尾动作（停弹幕、释放 VideoController 等）。
  ///
  /// 只有用户主动关闭悬浮窗时才执行：进入房间路由时的让位关闭必须保留这些资源，
  /// 房间页面还要接着用同一个播放器继续播。
  final List<Future<void> Function()> _pendingOwners = <Future<void> Function()>[];

  void prepare({Future<void> Function()? onClose}) {
    if (onClose != null) _pendingOwners.add(onClose);
    final commit = facade.commit;
    _reentrySeed = commit != null && commit.room == facade.room ? commit : null;
    _prepared = true;
  }

  /// 用户点悬浮窗的"关闭"：先停播放器，再收起悬浮层并执行房间侧收尾。
  ///
  /// 顺序与上游一致（先 close 再收起）；[closeAppFloating] 单独调用只收起悬浮层，
  /// 不停止播放——那条路径用于进入房间路由/打开别的直播间时让位。
  Future<void> stopFloatingPlayback() async {
    await facade.close();
    await closeAppFloating();
  }

  Future<void> _releasePendingOwners() async {
    final owners = List<Future<void> Function()>.from(_pendingOwners);
    _pendingOwners.clear();
    for (final owner in owners) {
      await owner();
    }
  }

  FacadeStreamCommit? consumeRoomReentry() {
    final seed = _reentrySeed;
    _reentrySeed = null;
    _prepared = false;
    return seed;
  }

  void cancelRoomReentry() {
    _reentrySeed = null;
    _prepared = false;
  }

  bool get isAppFloatingActive => _prepared || isFloating.value || _entry != null;

  Future<void> showAppFloating({Widget Function(BuildContext)? danmakuBuilder}) async {
    if (!_prepared || _entry != null) return;
    final overlayContext = Get.overlayContext;
    if (overlayContext == null) {
      await closeAppFloating();
      return;
    }
    isFloatingVideoVisible.value = true;

    final entry = OverlayEntry(
      builder: (context) => FloatingWindowOverlay(
        visible: isFloatingVideoVisible.stream,
        initiallyVisible: true,
        // 160×90 (the library default) is a thumbnail, not a watchable
        // window: a 16:9 stream gets a 380×214 surface with a 200×112 drag
        // floor, still capped at half the screen by maxWidthFraction.
        placement: const FloatingWindowPlacement(
          config: FloatingPlacementConfig(
            width: 380,
            height: 214,
            minWidth: 200,
            minHeight: 112,
            // A corner grip resizes; dragging the picture still moves the window.
            resizableByDrag: true,
          ),
        ),
        // 上次显示时的位置与尺寸（按当前源方向选一套）；组件会按当前表面重新夹取，
        // 所以旋转或改窗口大小之后不会把悬浮窗放到看不见的地方。
        initialRect: _rememberedFloatRect(),
        onRectChanged: _rememberFloatRect,
        child: _FloatingSurface(
          facade: facade,
          onExit: () async {
            final room = facade.room;
            if (room != null) await AppNavigator.toLiveRoomDetail(liveRoom: room);
          },
          onClose: stopFloatingPlayback,
          danmakuBuilder: danmakuBuilder,
        ),
      ),
    );
    final overlay = Overlay.maybeOf(overlayContext, rootOverlay: true) ?? Overlay.of(overlayContext);
    overlay.insert(entry);
    _entry = entry;
    isFloating.value = true;
  }

  /// 悬浮窗上次显示时的矩形；方向由 Core 端口决定（Core 不能反向依赖 live 域）。
  Rect? _rememberedFloatRect() {
    final geometry = FloatWindowGeometry.decode(SettingsService.to.player.floatWindowGeometry.value);
    return geometry.forPortrait(CompactSourceOrientation.isPortrait);
  }

  /// 记住刚稳定下来的矩形：拖动/缩放结束与隐藏时各报一次。
  void _rememberFloatRect(Rect rect) {
    if (!rect.isFinite || rect.isEmpty) return;
    final settings = SettingsService.to.player;
    final geometry = FloatWindowGeometry.decode(settings.floatWindowGeometry.value);
    settings.floatWindowGeometry.value = geometry
        .withRect(isPortrait: CompactSourceOrientation.isPortrait, rect: rect)
        .encode();
  }

  Future<void> closeAppFloating() async {
    final entry = _entry;
    _entry = null;
    isFloatingVideoVisible.value = false;
    _prepared = false;
    if (entry != null && entry.mounted) {
      await Future<void>.delayed(Duration.zero);
      entry.remove();
    }
    isFloating.value = false;
    // 房间侧收尾随悬浮窗一起结束（上游同样在收起时释放这些所有者）。放在这里
    // 而不是只放在"用户点关闭"路径：让位给房间路由/多画面的关闭也必须释放，
    // 否则旧房间的弹幕连接与 VideoController 会留到下一次关闭才被误执行。
    await _releasePendingOwners();
  }
}

/// The small window's picture and control layer.
///
/// Control visibility splits by input device, because a touch screen has no
/// pointer to leave behind: a tap pins the controls and a timer releases them,
/// while a desktop window shows them while the pointer is inside. Play/pause is
/// the primary action and sits centered at a size a thumb can hit; the escape
/// and close actions stay in the corner.
class _FloatingSurface extends StatefulWidget {
  const _FloatingSurface({required this.facade, required this.onExit, required this.onClose, this.danmakuBuilder});

  final LivePlayerFacade facade;
  final Future<void> Function() onExit;
  final Future<void> Function() onClose;
  final Widget Function(BuildContext)? danmakuBuilder;

  @override
  State<_FloatingSurface> createState() => _FloatingSurfaceState();
}

class _FloatingSurfaceState extends State<_FloatingSurface> {
  static const Duration _autoHideAfter = Duration(seconds: 3);

  bool _hovered = false;
  bool _pinned = false;
  Timer? _hideTimer;

  bool get _isTouchDevice =>
      defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

  bool get _showControls => _isTouchDevice ? _pinned : _hovered;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _tapSurface() {
    if (!_isTouchDevice) {
      widget.facade.togglePlayPause();
      return;
    }
    setState(() => _pinned = !_pinned);
    _restartAutoHide();
  }

  void _restartAutoHide() {
    _hideTimer?.cancel();
    if (!_pinned) return;
    _hideTimer = Timer(_autoHideAfter, () {
      if (mounted) setState(() => _pinned = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final facade = widget.facade;
    final danmaku = widget.danmakuBuilder;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: Colors.black,
            child: Obx(
              () => facade.floating.isFloatingVideoVisible.value
                  ? facade.getVideoWidget(BoxFit.contain)
                  : const SizedBox.shrink(),
            ),
          ),
          if (danmaku != null) Positioned.fill(child: danmaku(context)),
          Positioned.fill(
            child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _tapSurface),
          ),
          IgnorePointer(
            ignoring: !_showControls,
            child: AnimatedOpacity(
              opacity: _showControls ? 1 : 0,
              duration: const Duration(milliseconds: 160),
              child: Center(
                child: StreamBuilder<bool>(
                  stream: facade.onPlaying,
                  initialData: facade.isPlayingNow,
                  builder: (context, snapshot) {
                    final isPlay = snapshot.data ?? true;
                    return IconButton.filledTonal(
                      iconSize: 44,
                      tooltip: isPlay ? '暂停' : '播放',
                      style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
                      icon: Icon(isPlay ? Icons.pause_rounded : Icons.play_arrow_rounded),
                      onPressed: () {
                        facade.togglePlayPause();
                        _restartAutoHide();
                      },
                    );
                  },
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IgnorePointer(
              ignoring: !_showControls,
              child: AnimatedOpacity(
                opacity: _showControls ? 1 : 0,
                duration: const Duration(milliseconds: 160),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _cornerButton(icon: Icons.open_in_full_rounded, semanticLabel: '回到直播间', onTap: widget.onExit),
                    const SizedBox(width: 4),
                    _cornerButton(icon: Icons.close_rounded, semanticLabel: '关闭', onTap: widget.onClose),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cornerButton({
    required IconData icon,
    required String semanticLabel,
    required Future<void> Function() onTap,
  }) {
    return IconButton(
      iconSize: 20,
      visualDensity: VisualDensity.compact,
      tooltip: semanticLabel,
      style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
      icon: Icon(icon),
      onPressed: () {
        unawaited(onTap());
        _restartAutoHide();
      },
    );
  }
}
