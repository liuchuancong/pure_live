import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:pure_live/core/player/kernel/floating_handle_keeper.dart';
import 'package:pure_live/core/config/settings_service.dart';
import 'package:pure_live/core/config/float_window_geometry.dart';
import 'package:pure_live/core/player/presentation/compact_playback_progress.dart';
import 'package:pure_live/core/player/presentation/compact_source_orientation.dart';
import 'package:pure_live/core/utils/i18n.dart';
import 'package:pure_live/get/get.dart';
import 'package:media_core_floating/media_core_floating.dart';
import 'package:media_core/media_core.dart'
    show MediaPlayerView, PlayerHandle, PlayerHandlePlayback, PlayerId, PlayerKernel, PlayerTransportState;

/// Host small-window surface for the kernel's shared [FloatingDriver].
///
/// The driver ships with a null presenter, so a `floating` request was silently
/// dropped; this installs the real surface: a [FloatingWindowOverlay] inserted
/// above the app's overlay that renders whichever player the driver names, by
/// looking its handle up on [kernel]. It stays generic over the player id so the
/// live room's own floating path (which never goes through the driver) is
/// untouched, and any host that calls `kernel.enterFloating(playerId)` — the
/// local video player today — gets a window for that exact handle.
///
/// The window's geometry and its control surface mirror what the live room's
/// own small window shows, so both windows look and behave the same: every edge
/// resizes freely, the position is remembered, a tap pins the controls for a
/// few seconds (hover on desktop), the primary play/pause sits centered, and
/// the expand/close pair stays in the corner.
final class KernelFloatingWindowPresenter implements FloatingWindowPresenter {
  KernelFloatingWindowPresenter({required this.kernel, required this.driver});

  final PlayerKernel kernel;
  final FloatingDriver driver;

  OverlayEntry? _entry;

  /// The window's last rect for a picture of this shape, remembered through
  /// the same settings entry the live room's small window uses.
  ///
  /// The shape comes from the player being floated, not from
  /// [CompactSourceOrientation]: that global reads the live room's player, so
  /// a recording would have opened in whatever orientation the last live
  /// stream had — a vertical video in a horizontal window. Portrait and
  /// landscape keep separate slots, exactly like the room's window.
  Rect? _rememberedRect(bool isPortrait) {
    final geometry = FloatWindowGeometry.decode(SettingsService.to.player.floatWindowGeometry.value);
    return geometry.forPortrait(isPortrait);
  }

  void _rememberRect(bool isPortrait, Rect rect) {
    if (!rect.isFinite || rect.isEmpty) return;
    final settings = SettingsService.to.player;
    final geometry = FloatWindowGeometry.decode(settings.floatWindowGeometry.value);
    settings.floatWindowGeometry.value = geometry.withRect(isPortrait: isPortrait, rect: rect).encode();
  }

  /// The floated picture's size: what the driver was told, or the handle's own
  /// snapshot when no host ever fed the driver a size. Null means there is no
  /// shape to follow yet.
  Size? _floatedVideoSize(PlayerId playerId, FloatingWindowRequest request) {
    if (request.videoWidth > 0 && request.videoHeight > 0) {
      return Size(request.videoWidth.toDouble(), request.videoHeight.toDouble());
    }
    final snapshot = kernel.get(playerId)?.combinedSnapshot.geometry.videoSize;
    if (snapshot == null) return null;
    return Size(snapshot.width.toDouble(), snapshot.height.toDouble());
  }

  @override
  bool get isSupported => true;

  @override
  Future<void> show(FloatingWindowRequest request) async {
    if (_entry != null) return;
    final overlayContext = Get.overlayContext;
    if (overlayContext == null) return;
    final playerId = PlayerId(request.playerId);
    final size = _floatedVideoSize(playerId, request);
    final isPortrait = size != null && CompactSourceOrientation.isPortraitSize(size.width, size.height);
    final width = size?.width.round() ?? 0;
    final height = size?.height.round() ?? 0;
    final entry = OverlayEntry(
      builder: (context) => FloatingWindowOverlay(
        visible: driver.onFloatingChanged,
        initiallyVisible: driver.isFloating,
        // The overlay derives the window's shape from this size, which is what
        // opens a vertical recording as a tall window instead of a wide one.
        videoWidth: width > 0 ? width : null,
        videoHeight: height > 0 ? height : null,
        // Same placement the live room's window ships with: every edge and
        // corner resizes freely (the viewer picks width and height), and the
        // window may use the whole surface.
        placement: const FloatingWindowPlacement(
          config: FloatingPlacementConfig(
            width: 380,
            height: 214,
            minWidth: 200,
            minHeight: 112,
            maxWidthFraction: 1.0,
            resizableByDrag: true,
            resizeHandles: FloatingResizeHandle.all,
            resizeKeepsAspectRatio: false,
          ),
        ),
        initialRect: _rememberedRect(isPortrait),
        onRectChanged: (rect) => _rememberRect(isPortrait, rect),
        // The corner actions belong to the surface below, not to the library's
        // own built-in buttons: the live room's small window draws its own
        // expand/close pair that appears with the rest of the controls, and the
        // built-ins are always-on text glyphs that made the two windows look
        // like different features.
        child: _KernelFloatingSurface(
          kernel: kernel,
          playerId: playerId,
          // Leave the window: the driver goes back to normal (which hides this
          // entry) and the keeper releases the handle the page handed over, so a
          // feed that outlived its page is disposed exactly once, here.
          // Expanding asks the host for the full page back instead of only
          // closing.
          onExpand: () async {
            await kernel.exitFloating(playerId);
            await FloatingHandleKeeper.instance.expand(playerId.value);
            await FloatingHandleKeeper.instance.release(playerId.value);
          },
          onClose: () async {
            await kernel.exitFloating(playerId);
            await FloatingHandleKeeper.instance.release(playerId.value);
          },
        ),
      ),
    );
    final overlay = Overlay.maybeOf(overlayContext, rootOverlay: true) ?? Overlay.of(overlayContext);
    overlay.insert(entry);
    _entry = entry;
  }

  @override
  Future<void> hide() async {
    final entry = _entry;
    _entry = null;
    if (entry != null && entry.mounted) {
      await Future<void>.delayed(Duration.zero);
      entry.remove();
    }
  }
}

/// Renders the video of [playerId] for as long as the kernel still holds it,
/// with the control surface the live room's small window shows.
///
/// Control visibility splits by input device: a touch screen has no pointer to
/// leave behind, so a tap pins the controls and a timer releases them, while a
/// desktop window shows them while the pointer is inside. Play/pause is the
/// primary action, centered at a size a thumb can hit; expand and close stay
/// in the corner. The seek bar rides the same reveal: a recording is the media
/// that has a duration, and in a window this small the viewer wants to know —
/// and set — where they are in it.
class _KernelFloatingSurface extends StatefulWidget {
  const _KernelFloatingSurface({
    required this.kernel,
    required this.playerId,
    required this.onExpand,
    required this.onClose,
  });

  final PlayerKernel kernel;
  final PlayerId playerId;
  final Future<void> Function() onExpand;
  final Future<void> Function() onClose;

  @override
  State<_KernelFloatingSurface> createState() => _KernelFloatingSurfaceState();
}

class _KernelFloatingSurfaceState extends State<_KernelFloatingSurface> {
  static const Duration _autoHideAfter = Duration(seconds: 5);

  bool _hovered = false;
  bool _pinned = false;
  Timer? _hideTimer;
  StreamSubscription<PlayerTransportState>? _playbackSub;
  bool _playing = true;

  bool get _isTouchDevice =>
      defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

  bool get _showControls => _isTouchDevice ? _pinned : _hovered;

  PlayerHandle? get _handle => widget.kernel.get(widget.playerId);

  @override
  void initState() {
    super.initState();
    final handle = _handle;
    if (handle != null) {
      _playing = handle.isPlaying;
      _playbackSub = handle.playbackStream.listen((state) {
        if (mounted) setState(() => _playing = state.isPlaying);
      });
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _playbackSub?.cancel();
    super.dispose();
  }

  void _togglePlayPause() {
    final handle = _handle;
    if (handle == null || handle.disposed) return;
    unawaited(_playing ? handle.pause() : handle.play());
    _restartAutoHide();
  }

  void _tapSurface() {
    if (!_isTouchDevice) {
      _togglePlayPause();
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
    final handle = _handle;
    final video = handle == null || handle.disposed
        ? const ColoredBox(color: Colors.black)
        : MediaPlayerView(handle: handle, fit: BoxFit.contain);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Stack(
        fit: StackFit.expand,
        children: [
          video,
          Positioned.fill(
            child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _tapSurface),
          ),
          IgnorePointer(
            ignoring: !_showControls,
            child: AnimatedOpacity(
              opacity: _showControls ? 1 : 0,
              duration: const Duration(milliseconds: 160),
              child: Center(
                child: IconButton.filledTonal(
                  iconSize: 44,
                  tooltip: _playing ? i18n('local_player_pause') : i18n('local_player_play'),
                  style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
                  icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  onPressed: _togglePlayPause,
                ),
              ),
            ),
          ),
          // The same corner pair the live room's small window draws, with the
          // same reveal: it is one feature seen from two players, not two.
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
                    _cornerButton(
                      icon: Icons.open_in_full_rounded,
                      semanticLabel: i18n('local_player_back_to_page'),
                      onTap: widget.onExpand,
                    ),
                    const SizedBox(width: 4),
                    _cornerButton(icon: Icons.close_rounded, semanticLabel: i18n('close'), onTap: widget.onClose),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 6,
            right: 6,
            bottom: 6,
            child: IgnorePointer(
              ignoring: !_showControls,
              child: AnimatedOpacity(
                opacity: _showControls ? 1 : 0,
                duration: const Duration(milliseconds: 160),
                child: handle == null || handle.disposed
                    ? const SizedBox.shrink()
                    : StreamBuilder<PlayerTransportState>(
                        stream: handle.playbackStream,
                        initialData: handle.playback,
                        builder: (context, snapshot) {
                          final state = snapshot.data;
                          return CompactPlaybackProgress(
                            position: state?.position ?? Duration.zero,
                            duration: state?.duration ?? Duration.zero,
                            onSeek: (target) => unawaited(handle.seek(target)),
                          );
                        },
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
