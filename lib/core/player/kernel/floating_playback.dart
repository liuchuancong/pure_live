import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/player/presentation/compact_source_orientation.dart';
import 'package:pure_live/core/config/float_window_geometry.dart';
import 'package:media_core_floating/media_core_floating.dart';
import 'package:pure_live/domains/live/domain/live_player_facade.dart';

class FloatingPlayback {
  FloatingPlayback({required this.facade});

  final LivePlayerFacade facade;

  final RxBool isFloating = false.obs;
  final RxBool isFloatingVideoVisible = true.obs;
  OverlayEntry? _entry;
  FacadeStreamCommit? _reentrySeed;
  bool _prepared = false;

  final List<Future<void> Function()> _pendingOwners = <Future<void> Function()>[];

  void prepare({Future<void> Function()? onClose}) {
    if (onClose != null) _pendingOwners.add(onClose);
    final commit = facade.commit;
    _reentrySeed = commit != null && commit.room == facade.room ? commit : null;
    _prepared = true;
  }

  Future<void> stopFloatingPlayback() async {
    facade.clearFloatingDanmaku();
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

    // The window is remembered per surface orientation: a phone held upright
    // and the same phone turned sideways have different room on screen, and a
    // size that fits one of them is wrong in the other. The orientation is read
    // inside the builder so a rotation mid-float picks up the other memory
    // instead of restoring the shape of the surface that is gone.
    final entry = OverlayEntry(
      builder: (context) {
        final isPortraitSurface = _isPortraitStream();
        return FloatingWindowOverlay(
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
              // The half-screen cap the library ships with made left/right
              // resize look broken on a phone: 200 min width on a 400 px surface
              // left the width clamped to one value. The window may use the
              // whole surface and is still clamped inside it.
              maxWidthFraction: 1.0,
              // Every edge and corner resizes, freely: the viewer picks the
              // width and the height, and the window keeps what they chose.
              resizableByDrag: true,
              resizeHandles: FloatingResizeHandle.all,
              resizeKeepsAspectRatio: false,
            ),
          ),
          initialRect: _rememberedFloatRect(isPortraitSurface),
          onRectChanged: (rect) => _rememberFloatRect(isPortraitSurface, rect),
          child: _FloatingSurface(
            facade: facade,
            onExit: () async {
              final room = facade.room;
              if (room != null) await AppNavigator.toLiveRoomDetail(liveRoom: room);
            },
            onClose: stopFloatingPlayback,
            danmakuBuilder: danmakuBuilder,
          ),
        );
      },
    );
    final overlay = Overlay.maybeOf(overlayContext, rootOverlay: true) ?? Overlay.of(overlayContext);
    overlay.insert(entry);
    _entry = entry;
    isFloating.value = true;
  }

  /// Whether the stream in the window is taller than it is wide.
  ///
  /// The window is remembered per *stream* orientation, not per device one: a
  /// portrait live stream wants a tall small window with its own position, a
  /// landscape one a wide window of its own, and the viewer expects each to come
  /// back the way they left it.
  static bool _isPortraitStream() => CompactSourceOrientation.isPortrait;

  Rect? _rememberedFloatRect(bool isPortraitSurface) {
    final geometry = FloatWindowGeometry.decode(SettingsService.to.player.floatWindowGeometry.value);
    return geometry.forPortrait(isPortraitSurface);
  }

  void _rememberFloatRect(bool isPortraitSurface, Rect rect) {
    if (!rect.isFinite || rect.isEmpty) return;
    final settings = SettingsService.to.player;
    final geometry = FloatWindowGeometry.decode(settings.floatWindowGeometry.value);
    settings.floatWindowGeometry.value = geometry
        .withRect(isPortrait: isPortraitSurface, rect: rect)
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
