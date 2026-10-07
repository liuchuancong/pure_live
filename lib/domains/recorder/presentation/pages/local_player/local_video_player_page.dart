import 'dart:io';
import 'dart:async';

import 'package:remixicon/remixicon.dart';
import 'package:pure_live/core/index.dart';
import 'package:media_core_ui/media_core_ui.dart';
import 'package:pure_live/core/consts/app_consts.dart';
import 'package:media_core/media_core.dart' show MediaPlayerView;
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:pure_live/core/player/presentation/player_back_scope.dart';
import 'package:pure_live/core/player/presentation/windows_pip_driver.dart';
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:pure_live/core/player/presentation/player_ui_controller.dart';
import 'package:pure_live/core/player/presentation/compact_playback_progress.dart';
import 'package:pure_live/core/player/presentation/danmaku/player_danmaku_actions.dart';
import 'package:pure_live/domains/recorder/presentation/pages/local_player/local_video_player_controller.dart';

/// One recording, played.
///
/// The page carries only what is specific to a *recording*: the file list, the
/// folder actions, the replayed chat. Everything a player surface does is the
/// shared Core one — [PlayerGestureLayer] for brightness/volume/scroll,
/// [PlayerUiController] for the transport, and [MediaCorePlayerView]'s own bar
/// for play/pause, skip, timeline, speed, fullscreen and picture-in-picture. A
/// live room drives exactly the same three; the difference between the two pages
/// is where the media comes from, not how it is watched.
class LocalVideoPlayerPage extends GetView<LocalVideoPlayerController> {
  const LocalVideoPlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    // The keyboard owner sits above the layout switch: a resize that flips
    // narrow/wide, or a presentation change that replaces the page's shape,
    // must not take the focus node with it.
    return RecordingKeyboardShortcuts(
      controller: controller,
      child: _RecordingBackBoundary(
        controller: controller,
        child: Get.width <= 680 ? _MobileLayout(controller: controller) : _DesktopLayout(controller: controller),
      ),
    );
  }
}

/// The recording player's system-Back owner.
///
/// It exists because Back here is not a Flutter-level event. Android 13+ hands
/// the gesture and the button to the Activity, where Flutter registers its own
/// callback at **DEFAULT** priority — so the route is popped before any
/// `PopScope` runs. The host keeps a **PRIORITY_OVERLAY** callback instead and
/// forwards it over `pure_live/predictive_back`, and that interception has to be
/// switched on for this route. The live room does exactly that through
/// `PlayerBackScope`.
///
/// A bare `PopScope` here looked right and never received the event; a scope
/// whose `presentationActive` was hardcoded false was no better, because
/// `canPop: true` is precisely what lets the route pop before any handler runs.
///
/// So the fullscreen state is handed to the scope as its presentation:
///
/// - fullscreen → `canPop` is false, Back leaves fullscreen and keeps the page;
/// - not fullscreen → `canPop` is true, and the controller still gets a say
///   first, only so the feed can be handed to the small window — the live room's
///   own "back floats the player" rule.
/// The scope stays one widget for the whole route — it must, because the native
/// interception has a single callback slot — and the fullscreen state is pushed
/// into it by a listener on the controller's own observable.
class _RecordingBackBoundary extends StatefulWidget {
  const _RecordingBackBoundary({required this.controller, required this.child});

  final LocalVideoPlayerController controller;
  final Widget child;

  @override
  State<_RecordingBackBoundary> createState() => _RecordingBackBoundaryState();
}

class _RecordingBackBoundaryState extends State<_RecordingBackBoundary> {
  StreamSubscription<bool>? _fullscreenSub;
  bool _fullscreen = false;

  LocalVideoPlayerController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _fullscreen = controller.fullscreenActive.value;
    _fullscreenSub = controller.fullscreenActive.listen((value) {
      if (!mounted || value == _fullscreen) return;
      setState(() => _fullscreen = value);
    });
  }

  @override
  void dispose() {
    _fullscreenSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PlayerBackScope(
      // `canPop` follows the real state: a scope that kept saying false here is
      // what let Android pop the page straight out of fullscreen.
      presentationActive: _fullscreen,
      onExitPresentation: () async {
        await controller.exitFullscreen();
      },
      onBackRequest: () => controller.handleBackRequest(),
      child: widget.child,
    );
  }
}

// ---------------------------------------------------------------------------
// Shared pieces
// ---------------------------------------------------------------------------

String _sizeOf(File file) {
  try {
    final bytes = file.lengthSync();
    if (bytes >= 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  } catch (_) {
    return '';
  }
}

String _modifiedOf(File file) {
  try {
    final at = file.lastModifiedSync();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${at.year}-${two(at.month)}-${two(at.day)} ${two(at.hour)}:${two(at.minute)}';
  } catch (_) {
    return '';
  }
}

/// The system safe area the page's own chrome has to add.
///
/// `viewPadding` is the raw inset the system reports — nothing above this page
/// consumes it, so it is exactly what a positioned control adds itself. The
/// picture underneath stays full-bleed; only the bars move in.
EdgeInsets _edgeInsets(BuildContext context) => MediaQuery.viewPaddingOf(context);

/// The video surface: the shared gesture layer over the library's own player.
///
/// The gesture layer sits *above* the picture so a drag anywhere on it means
/// brightness or volume even while the library's bars are on screen, and the
/// replayed chat is drawn between the two. No second transport bar is built
/// here on purpose: the library's bar is the same one every other surface in the
/// app shows.
/// The control-bar palette the recording page shows: the library's Material
/// bar with its fixed red accent replaced by the app theme's primary — the
/// same color the live room's own controls follow.
PlayerControlsTheme _controlsTheme(ThemeData theme) {
  final primary = theme.colorScheme.primary;
  return PlayerControlsTheme.material().copyWith(accent: primary, progressPlayed: primary, progressThumb: primary);
}

/// The bar's presentation actions, routed the way the live room routes them.
///
/// The kernel's default fullscreen is a desktop window request and a no-op on a
/// phone; the live room instead locks landscape (mobile) or fullscreens the
/// window (desktop). PiP and the small window go through this controller, so
/// their page-side behavior (state tracking, handle handover) applies.
PlayerControlActions _recordingActions(LocalVideoPlayerController controller) {
  return PlayerControlActions(
    enterFullscreen: controller.toggleFullscreen,
    exitFullscreen: controller.toggleFullscreen,
  );
}

/// The video area the layouts consume: the picture, the gesture layer, the
/// replayed chat, and the recording control bar styled after the live room's
/// own bottom bar.
///
/// Visibility follows the same rules the room's panel follows: on desktop the
/// bar shows while the pointer is over the picture and hides when it leaves,
/// on touch a tap toggles it, and while playing it hides itself after a few
/// seconds. When hidden the cursor disappears too — the live room's
/// fullscreen behavior. While paused the bar stays up.
class _PlayerArea extends StatefulWidget {
  const _PlayerArea({required this.controller, this.keyboardShortcuts = false});

  final LocalVideoPlayerController controller;
  final bool keyboardShortcuts;

  @override
  State<_PlayerArea> createState() => _RecordingPlayerAreaState();
}

class _RecordingPlayerAreaState extends State<_PlayerArea> {
  bool get _isTouchDevice =>
      defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

  LocalVideoPlayerController get controller => widget.controller;

  void _onSurfaceTap() {
    if (_isTouchDevice) {
      controller.toggleControls();
      return;
    }
    unawaited(controller.togglePlayPause());
    controller.revealControls();
  }

  void _onSurfaceDoubleTap() => unawaited(controller.toggleFullscreen());

  @override
  Widget build(BuildContext context) {
    return GetBuilder<LocalVideoPlayerController>(
      builder: (_) {
        final handle = controller.handle;
        if (handle == null) return const ColoredBox(color: Colors.black);
        return Obx(() {
          if (controller.isInPip.value) {
            return _RecordingPipOverlay(controller: controller);
          }
          final visible = controller.controlsVisible.value;
          return MouseRegion(
            onEnter: (_) => controller.setControlsHovering(true),
            onExit: (_) => controller.setControlsHovering(false),
            cursor: visible ? MouseCursor.defer : SystemMouseCursors.none,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTap: _onSurfaceDoubleTap,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _RecordingVideoFace(
                    controller: controller,
                    keyboardShortcuts: widget.keyboardShortcuts,
                    onSurfaceTap: _onSurfaceTap,
                  ),
                  // The picture's own entries float here on a roomy window. NOT
                  // while the page is fullscreen: the fullscreen chrome draws
                  // them in its top bar, and two copies of the same row landed on
                  // top of each other — the upper one took the tap, so the visible
                  // buttons did nothing.
                  if (Get.width > 680 && !controller.fullscreenActive.value)
                    Positioned(
                      top: 8 + _edgeInsets(context).top,
                      right: 8 + _edgeInsets(context).right,
                      child: _RecordingCornerActions(controller: controller),
                    ),
                  // The bar rides above the picture, revealed by the rules above.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      ignoring: !visible,
                      child: AnimatedOpacity(
                        opacity: visible ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: _RecordingControlBar(controller: controller),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }
}

/// Page-level keyboard owner, the shape the live room uses.
///
/// The recorder used to carry its key handler on a Focus inside the player
/// area. Every presentation change rebuilds that subtree — fullscreen and PiP
/// replace the page's shape — and the focus node went away with it, so the
/// keys stopped answering exactly when the viewer is fullscreen and wants them
/// most. Living above the shape switch keeps one node alive, and the node is
/// re-asserted after a transition because the desktop window's fullscreen
/// change can drop the OS-level focus along with it.
class RecordingKeyboardShortcuts extends StatefulWidget {
  const RecordingKeyboardShortcuts({super.key, required this.controller, required this.child});

  final LocalVideoPlayerController controller;
  final Widget child;

  @override
  State<RecordingKeyboardShortcuts> createState() => _RecordingKeyboardShortcutsState();
}

class _RecordingKeyboardShortcutsState extends State<RecordingKeyboardShortcuts> {
  final FocusNode _node = FocusNode(debugLabel: 'LocalVideoPlayerKeys');

  final List<StreamSubscription<bool>> _presentationSubs = <StreamSubscription<bool>>[];

  LocalVideoPlayerController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    for (final presentation in <RxBool>[
      controller.fullscreenActive,
      controller.portraitFullscreen,
      controller.isFullscreen,
      controller.isInPip,
    ]) {
      _presentationSubs.add(presentation.listen((_) => _reassertFocus()));
    }
    _reassertFocus();
  }

  @override
  void dispose() {
    for (final subscription in _presentationSubs) {
      subscription.cancel();
    }
    _node.dispose();
    super.dispose();
  }

  /// Takes focus back after a transition, and only when nothing else holds it:
  /// a dialog, menu or text field the viewer opened keeps the keyboard.
  void _reassertFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _node.hasFocus) return;
      if (FocusManager.instance.primaryFocus != null) return;
      _node.requestFocus();
    });
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyK) {
      unawaited(controller.togglePlayPause());
      controller.revealControls();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      unawaited(controller.seekBy(const Duration(seconds: -10)));
      controller.revealControls();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      unawaited(controller.seekBy(const Duration(seconds: 10)));
      controller.revealControls();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyF) {
      unawaited(controller.toggleFullscreen());
      controller.revealControls();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      // Escape only ever leaves a mode: fullscreen drops back to the page, and
      // outside it pops the route — desktop Flutter does not turn an unhandled
      // Escape into a Navigator pop, and PopScope still decides whether that
      // leaves the page or hands the feed to the small window.
      if (controller.fullscreenActive.value) {
        unawaited(controller.exitFullscreen());
        controller.revealControls();
        return KeyEventResult.handled;
      }
      unawaited(Navigator.of(context).maybePop());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown) {
      unawaited(() async {
        final current = await controller.uiVolume() ?? 1.0;
        final next = (current + (key == LogicalKeyboardKey.arrowUp ? 0.1 : -0.1)).clamp(0.0, 1.0);
        await controller.uiSetVolume(next);
      }());
      controller.revealControls();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(focusNode: _node, autofocus: true, onKeyEvent: _handleKey, child: widget.child);
  }
}

/// The picture's top-right cluster: back, audio-only, screenshot and
/// picture-in-picture.
///
/// It floats over a roomy window's picture, and the fullscreen chrome reuses the
/// same row inside its top bar — there [includeBack] is false, because that bar
/// already has the page's back button and two back arrows in one row is a coin
/// toss for the viewer.
class _RecordingCornerActions extends StatelessWidget {
  const _RecordingCornerActions({required this.controller, this.includeBack = true});

  final LocalVideoPlayerController controller;
  final bool includeBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fullscreen has no app bar, so the way out lives here: back leaves
          // the fullscreen shape first, and only a page that is not fullscreen
          // is allowed to be left (the room's rule, same handler as the
          // physical back button).
          if (includeBack)
            Obx(
              () => !controller.fullscreenActive.value
                  ? const SizedBox.shrink()
                  : IconButton(
                      color: Colors.white,
                      iconSize: 20,
                      tooltip: i18n('local_player_back'),
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () async {
                        if (await controller.handleBackRequest()) Get.back<void>();
                      },
                    ),
            ),
          Obx(
            () => IconButton(
              color: controller.isAudioOnly.value ? const Color(0xFFFFD166) : Colors.white,
              iconSize: 20,
              tooltip: controller.isAudioOnly.value ? i18n('restore_video_mode') : i18n('switch_audio_only_mode'),
              icon: Icon(controller.isAudioOnly.value ? Remix.headphone_fill : Remix.headphone_line),
              onPressed: () => controller.isAudioOnly.toggle(),
            ),
          ),
          IconButton(
            color: Colors.white,
            iconSize: 20,
            tooltip: i18n('local_player_screenshot'),
            icon: const Icon(Icons.photo_camera_rounded),
            onPressed: () async {
              final name = await controller.saveScreenshot();
              ToastUtil.show(name ?? i18n('path_or_permission_error'));
            },
          ),
          IconButton(
            color: Colors.white,
            iconSize: 20,
            tooltip: i18n('pip_window_play'),
            icon: const Icon(Remix.picture_in_picture_line),
            onPressed: () => unawaited(_enterRecordingPip(controller)),
          ),
        ],
      ),
    );
  }
}

/// The picture face: gesture layer over the (chrome-less) library view, the
/// replayed chat between them, and the audio-only shroud on top of all.
class _RecordingVideoFace extends StatelessWidget {
  const _RecordingVideoFace({required this.controller, required this.keyboardShortcuts, required this.onSurfaceTap});

  final LocalVideoPlayerController controller;
  final bool keyboardShortcuts;
  final VoidCallback onSurfaceTap;

  @override
  Widget build(BuildContext context) {
    final handle = controller.handle;
    if (handle == null) return const ColoredBox(color: Colors.black);
    return PlayerGestureLayer(
      controller: controller,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MediaCorePlayerView(
            handle: handle,
            actions: _recordingActions(controller),
            theme: _controlsTheme(Theme.of(context)),
            fit: BoxFit.contain,
            showControls: false,
            keyboardShortcuts: keyboardShortcuts,
            onTapVideo: onSurfaceTap,
          ),
          Obx(() => Positioned.fill(child: controller.buildDanmakuSurface(context) ?? const SizedBox.shrink())),
          Obx(
            () => controller.isAudioOnly.value
                ? Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Remix.headphone_fill, size: 56, color: Colors.white70),
                            const SizedBox(height: 14),
                            Text(
                              controller.roomTitle ?? i18n('recorder_local_player_title'),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Remix.headphone_line, size: 14, color: Colors.white70),
                                  const SizedBox(width: 6),
                                  Text(
                                    i18n('audio_only_mode'),
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// Puts the recording into the system picture-in-picture window.
///
/// The controller drives the same Core transition the live room uses, so the
/// window is shaped, placed and remembered identically; a platform without a
/// working implementation reports it instead of failing silently.
Future<void> _enterRecordingPip(LocalVideoPlayerController controller) async {
  try {
    await controller.enterPip();
  } catch (_) {
    ToastUtil.show(i18n('pip_enter_failed'));
  }
}

/// The compact face the recording shows while the window is in PiP.
///
/// Deliberately the live room's PiP face: rounded contain picture, single tap
/// toggles playback, double tap leaves PiP, dragging the picture moves the
/// window, a hover reveals a large center play/pause plus the corner
/// restore/close pair, and the replayed chat keeps flowing over the picture.
class _RecordingPipOverlay extends StatefulWidget {
  const _RecordingPipOverlay({required this.controller});

  final LocalVideoPlayerController controller;

  @override
  State<_RecordingPipOverlay> createState() => _RecordingPipOverlayState();
}

class _RecordingPipOverlayState extends State<_RecordingPipOverlay> {
  bool _hovered = false;

  bool get _isTouchDevice =>
      defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

  bool get _showControls => !_isTouchDevice && _hovered;

  Future<void> _exitPip() => widget.controller.exitPip();

  @override
  Widget build(BuildContext context) {
    final handle = widget.controller.handle;
    if (handle == null) return const ColoredBox(color: Colors.black);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Scaffold(
        // Transparent, not black: the compact window is the whole Composition
        // surface on a phone, and any opaque page background shows as a frame
        // around the picture. The live room's compact face does the same.
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // No clip while the system draws the window. Android's and iOS's
            // PiP windows own their own shape, and a 12 px clip here cut the
            // picture's corners off and let the page behind show through them —
            // which is exactly what "the window still has a background" was.
            // The desktop compact window has no such system rounding, so it
            // keeps its soft corners.
            ClipRRect(
              borderRadius: _isTouchDevice ? BorderRadius.zero : BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // A touch device hands the window to the system: consuming a
                  // drag or a tap here stops the native PiP window from being
                  // dragged and from opening its own play/close menu. The
                  // desktop compact window has no system gestures, so there the
                  // surface is the only way to move or pause it.
                  if (_isTouchDevice)
                    MediaPlayerView(handle: handle, fit: BoxFit.contain)
                  else
                    GestureDetector(
                      onDoubleTap: () => unawaited(_exitPip()),
                      onTap: widget.controller.togglePlayPause,
                      onPanStart: (_) => unawaited(windowsPipWindow.startDragging()),
                      child: MediaPlayerView(handle: handle, fit: BoxFit.contain),
                    ),
                  Obx(
                    () => Positioned.fill(
                      child: widget.controller.buildDanmakuSurface(context) ?? const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: AnimatedOpacity(
                  opacity: _showControls ? 1 : 0,
                  duration: const Duration(milliseconds: 160),
                  child: Obx(
                    () => CompactPlaybackProgress(
                      position: widget.controller.position.value,
                      duration: widget.controller.duration.value,
                      onSeek: (target) => unawaited(widget.controller.seekTo(target)),
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: IgnorePointer(
                ignoring: !_showControls,
                child: AnimatedOpacity(
                  opacity: _showControls ? 1 : 0,
                  duration: const Duration(milliseconds: 160),
                  child: Obx(
                    () => IconButton.filledTonal(
                      iconSize: 56,
                      tooltip: widget.controller.isPlaying.value
                          ? i18n('local_player_pause')
                          : i18n('local_player_play'),
                      style: IconButton.styleFrom(backgroundColor: Colors.black45, foregroundColor: Colors.white),
                      icon: Icon(widget.controller.isPlaying.value ? Icons.pause_rounded : Icons.play_arrow_rounded),
                      onPressed: widget.controller.togglePlayPause,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: AnimatedOpacity(
                  opacity: _showControls ? 1 : 0,
                  duration: const Duration(milliseconds: 160),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _pipControlButton(
                        icon: Icons.open_in_full_rounded,
                        semanticLabel: i18n('local_player_back_to_page'),
                        onTap: _exitPip,
                      ),
                      const SizedBox(width: 6),
                      _pipControlButton(
                        icon: Icons.close_rounded,
                        semanticLabel: i18n('close'),
                        onTap: () async {
                          await _exitPip();
                          if (Get.currentRoute == RoutePath.kLocalVideoPlayer) Get.back<void>();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pipControlButton({
    required IconData icon,
    required String semanticLabel,
    required Future<void> Function() onTap,
  }) {
    return IconButton(
      iconSize: 26,
      tooltip: semanticLabel,
      style: IconButton.styleFrom(backgroundColor: Colors.black45, foregroundColor: Colors.white),
      icon: Icon(icon),
      onPressed: () => unawaited(onTap()),
    );
  }
}

String _fmtTime(Duration d) {
  String two(int v) => v.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final sec = d.inSeconds % 60;
  return h > 0 ? '$h:$m:${two(sec)}' : '$m:${two(sec)}';
}

/// The recording control bar, laid out like the live room's bottom bar:
/// timeline on top, then play / skip pair / volume / rate on the left and
/// fit / fullscreen on the right. The audio-only, screenshot and picture-in-
/// picture entries are not here — they live in [_RecordingCornerActions],
/// where they stay reachable after this bar fades out.
class _RecordingControlBar extends StatelessWidget {
  const _RecordingControlBar({required this.controller});

  final LocalVideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    // The bar is pinned to the bottom of the picture, and the picture reaches the
    // bottom of the screen in every shape this page has: on a phone with gesture
    // navigation the seek bar and the transport row sat under the system bar.
    // The inset goes into the padding so the gradient still covers the edge.
    final padding = _edgeInsets(context);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black87],
        ),
      ),
      padding: EdgeInsets.fromLTRB(12 + padding.left, 22, 12 + padding.right, 4 + padding.bottom),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showVolumeSlider = constraints.maxWidth >= recordingVolumeSliderMinWidth;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Timeline row.
              Row(
                children: [
                  Obx(
                    () => Text(
                      _fmtTime(controller.position.value),
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                  Expanded(
                    child: Obx(() {
                      final durationMs = controller.duration.value.inMilliseconds;
                      final positionMs = controller.position.value.inMilliseconds;
                      final max = durationMs <= 0 ? 1.0 : durationMs / 1000.0;
                      final value = (positionMs / 1000.0).clamp(0.0, max);
                      return SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                          activeTrackColor: primary,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: primary,
                          overlayColor: primary.withValues(alpha: 0.2),
                        ),
                        child: Slider(
                          value: value,
                          max: max,
                          onChanged: (v) => unawaited(controller.seekTo(Duration(milliseconds: (v * 1000).round()))),
                        ),
                      );
                    }),
                  ),
                  Obx(
                    () => Text(
                      _fmtTime(controller.duration.value),
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ],
              ),
              // Button row.
              Row(
                children: [
                  Obx(
                    () => IconButton(
                      color: Colors.white,
                      iconSize: 26,
                      tooltip: controller.isPlaying.value ? i18n('local_player_pause') : i18n('local_player_play'),
                      icon: Icon(controller.isPlaying.value ? Icons.pause_rounded : Icons.play_arrow_rounded),
                      onPressed: controller.togglePlayPause,
                    ),
                  ),
                  IconButton(
                    color: Colors.white,
                    iconSize: 26,
                    tooltip: i18n('local_player_seek_back'),
                    icon: const Icon(Icons.replay_10_rounded),
                    onPressed: () => unawaited(controller.seekBy(const Duration(seconds: -10))),
                  ),
                  IconButton(
                    color: Colors.white,
                    iconSize: 26,
                    tooltip: i18n('local_player_seek_forward'),
                    icon: const Icon(Icons.forward_10_rounded),
                    onPressed: () => unawaited(controller.seekBy(const Duration(seconds: 10))),
                  ),
                  Obx(
                    () => controller.hasDanmaku.value
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PlayerDanmakuButton(controller: controller, iconColor: Colors.white),
                              PlayerDanmakuSettingsButton(controller: controller, iconColor: Colors.white),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                  if (Get.width > 680) _VolumeControls(controller: controller, showSlider: showVolumeSlider),
                  if (Get.width > 680) _RateButton(controller: controller),
                  const Spacer(),
                  _FitButton(),
                  Obx(
                    () => IconButton(
                      color: Colors.white,
                      iconSize: 24,
                      tooltip: i18n('fullscreen_watch'),
                      icon: Icon(
                        controller.fullscreenActive.value ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                      ),
                      onPressed: controller.toggleFullscreen,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Volume icon plus a compact slider, the live room's transport arrangement.
class _VolumeControls extends StatefulWidget {
  const _VolumeControls({required this.controller, this.showSlider = true});

  final LocalVideoPlayerController controller;

  /// Narrow layouts drop the slider and keep only the mute toggle; the row
  /// cannot carry both.
  final bool showSlider;

  @override
  State<_VolumeControls> createState() => _VolumeControlsState();
}

class _VolumeControlsState extends State<_VolumeControls> {
  double? _volume;
  double _lastAudible = 1.0;

  LocalVideoPlayerController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.uiVolume().then((v) {
      if (mounted && v != null) setState(() => _volume = v);
    });
  }

  Future<void> _write(double v) async {
    setState(() => _volume = v);
    await controller.uiSetVolume(v);
  }

  @override
  Widget build(BuildContext context) {
    final volume = _volume ?? 1.0;
    final muted = volume <= 0.001;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          color: Colors.white,
          iconSize: 22,
          tooltip: muted ? i18n('local_player_unmute') : i18n('local_player_mute'),
          icon: Icon(
            muted
                ? Icons.volume_off_rounded
                : volume < 0.5
                ? Icons.volume_down_rounded
                : Icons.volume_up_rounded,
          ),
          onPressed: () {
            if (muted) {
              unawaited(_write(_lastAudible <= 0.001 ? 1.0 : _lastAudible));
            } else {
              _lastAudible = volume;
              unawaited(_write(0.0));
            }
          },
        ),
        if (widget.showSlider)
          SizedBox(
            width: 100,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2.5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: Theme.of(context).colorScheme.primary,
                inactiveTrackColor: Colors.white24,
                thumbColor: Theme.of(context).colorScheme.primary,
                overlayColor: Colors.transparent,
              ),
              child: Slider(value: volume, max: 1.0, onChanged: (v) => unawaited(_write(v))),
            ),
          ),
      ],
    );
  }
}

/// The speed label; tapping opens the rate dialog like the room's bar.
class _RateButton extends StatelessWidget {
  const _RateButton({required this.controller});

  final LocalVideoPlayerController controller;

  Future<void> _pick(BuildContext context) async {
    final theme = Theme.of(context);
    final rate = await showDialog<double>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(i18n('playback_rate')),
        children: [
          for (final rate in LocalVideoPlayerController.defaultRates)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(rate),
              child: Obx(() {
                final current = controller.playbackRate.value;
                final selected = (current - rate).abs() < 0.001;
                return Row(
                  children: [
                    SizedBox(
                      width: 20,
                      child: selected ? Icon(Icons.check_rounded, size: 20, color: theme.colorScheme.primary) : null,
                    ),
                    const SizedBox(width: 10),
                    Text('${rate.toStringAsFixed(rate == rate.roundToDouble() ? 1 : 2)}x'),
                  ],
                );
              }),
            ),
        ],
      ),
    );
    if (rate != null) await controller.setRate(rate);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => TextButton(
        onPressed: () => unawaited(_pick(context)),
        child: Text(
          '${controller.playbackRate.value.toStringAsFixed(controller.playbackRate.value == controller.playbackRate.value.roundToDouble() ? 1 : 2)}x',
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// The fit label; tapping opens the six stored fit modes like the room's bar.
class _FitButton extends StatelessWidget {
  const _FitButton();

  Future<void> _pick(BuildContext context) async {
    final theme = Theme.of(context);
    final options = AppConsts().videoFitType;
    final settings = SettingsService.to.player;
    final picked = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(i18n('video_fit')),
        children: [
          for (var i = 0; i < options.length; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(i),
              child: Obx(() {
                final current = settings.resolvedVideoFitIndex;
                final selected = current == i;
                return Row(
                  children: [
                    SizedBox(
                      width: 20,
                      child: selected ? Icon(Icons.check_rounded, size: 20, color: theme.colorScheme.primary) : null,
                    ),
                    const SizedBox(width: 10),
                    Text(i18n(options[i]['desc'] as String)),
                  ],
                );
              }),
            ),
        ],
      ),
    );
    if (picked != null) settings.videoFitIndex.v = picked;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => TextButton(
        onPressed: () => unawaited(_pick(context)),
        child: Text(
          i18n(AppConsts().videoFitType[SettingsService.to.player.resolvedVideoFitIndex]['desc'] as String),
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ),
    );
  }
}

/// File name plus how big it is and when it was written.
class _FileRow extends StatelessWidget {
  const _FileRow({required this.controller, required this.index, this.dense = false, this.onPicked});

  final LocalVideoPlayerController controller;
  final int index;
  final bool dense;
  final VoidCallback? onPicked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = controller.videoFiles[index];
    final name = file.uri.pathSegments.last;
    return Obx(() {
      final active = controller.currentIndex.value == index;
      final accent = theme.colorScheme.primary;
      final details = <String>[
        if (_sizeOf(file).isNotEmpty) _sizeOf(file),
        if (_modifiedOf(file).isNotEmpty) _modifiedOf(file),
      ].join(' · ');
      return InkWell(
        onTap: () {
          unawaited(controller.showIndex(index));
          onPicked?.call();
        },
        onLongPress: () => _showMenu(context),
        onSecondaryTap: () => _showMenu(context),
        child: Container(
          decoration: BoxDecoration(
            color: active ? accent.withValues(alpha: 0.12) : Colors.transparent,
            border: Border(left: BorderSide(color: active ? accent : Colors.transparent, width: 3)),
          ),
          padding: EdgeInsets.fromLTRB(dense ? 10 : 12, 8, 4, 8),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? accent : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: active
                    ? Icon(Icons.graphic_eq_rounded, size: 15, color: theme.colorScheme.onPrimary)
                    : Text('${index + 1}', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                        color: active ? accent : theme.colorScheme.onSurface,
                      ),
                    ),
                    if (details.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          details,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                color: theme.colorScheme.onSurfaceVariant,
                icon: const Icon(Icons.more_vert_rounded),
                onPressed: () => _showMenu(context),
              ),
            ],
          ),
        ),
      );
    });
  }

  Future<void> _showMenu(BuildContext context) async {
    final file = controller.videoFiles[index];
    final name = file.uri.pathSegments.last;
    final box = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        box.localToGlobal(Offset.zero, ancestor: overlay) & box.size,
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(value: 'play', child: _menuRow(Icons.play_arrow_rounded, i18n('recorder_play_video'))),
        PopupMenuItem(value: 'open_dir', child: _menuRow(Icons.folder_open_rounded, i18n('recorder_open_task_folder'))),
        PopupMenuItem(value: 'rename', child: _menuRow(Icons.edit_rounded, i18n('local_player_rename'))),
        PopupMenuItem(value: 'delete', child: _menuRow(Icons.delete_outline_rounded, i18n('local_player_delete'))),
      ],
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case 'play':
        await controller.showIndex(index);
      case 'open_dir':
        await controller.openFileDir();
      case 'rename':
        await _promptRename(context, name);
      case 'delete':
        await _confirmDelete(context, name);
    }
  }

  Widget _menuRow(IconData icon, String text) => Row(
    children: [
      Icon(icon, size: 18),
      const SizedBox(width: 10),
      Text(text, style: const TextStyle(fontSize: 13)),
    ],
  );

  Future<void> _promptRename(BuildContext context, String name) async {
    final textController = TextEditingController(text: name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(i18n('local_player_rename')),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: InputDecoration(hintText: i18n('local_player_rename_hint')),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(i18n('cancel'))),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(textController.text), child: Text(i18n('done'))),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty && newName != name) {
      await controller.renameFile(index, newName);
    }
  }

  Future<void> _confirmDelete(BuildContext context, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(i18n('local_player_delete')),
        content: Text(i18n('local_player_delete_confirm', args: {'name': name})),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(i18n('cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(i18n('local_player_delete')),
          ),
        ],
      ),
    );
    if (ok == true) await controller.deleteFile(index);
  }
}

/// The recording list, used as the desktop panel and inside the phone sheet.
///
/// Every reactive read sits inside an `Obx`: `videoFiles` is an observable list,
/// so the builder attaches to it and the list stays live as files are recorded
/// or deleted — a builder with no observable at all is an error in GetX, not an
/// empty list.
class _PlaylistPanel extends StatelessWidget {
  const _PlaylistPanel({required this.controller, this.dense = false, this.onPicked});

  final LocalVideoPlayerController controller;
  final bool dense;
  final VoidCallback? onPicked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(12, dense ? 10 : 14, 4, 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      controller.roomTitle ?? i18n('recorder_local_player_title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                    ),
                    Obx(
                      () => Text(
                        i18n('local_player_files', args: {'count': '${controller.videoFiles.length}'}),
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                iconSize: 18,
                color: theme.colorScheme.onSurfaceVariant,
                tooltip: i18n('recorder_open_task_folder'),
                icon: const Icon(Remix.folder_open_line),
                onPressed: () => unawaited(controller.openFileDir()),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Obx(
            () => ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: controller.videoFiles.length,
              itemBuilder: (_, i) => _FileRow(controller: controller, index: i, dense: dense, onPicked: onPicked),

              physics: const PureLiveScrollPhysics(),
            ),
          ),
        ),
      ],
    );
  }
}

Widget _emptyState(BuildContext context, LocalVideoPlayerController controller, {bool onDark = false}) {
  final color = onDark ? Colors.white54 : Theme.of(context).colorScheme.outline;
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Remix.film_line, size: 56, color: color),
        const SizedBox(height: 14),
        Text(i18n('recorder_local_player_playlist_empty'), style: TextStyle(color: color, fontSize: 13)),
        const SizedBox(height: 18),
        FilledButton.tonalIcon(
          onPressed: () => unawaited(controller.openFileDir()),
          icon: const Icon(Remix.folder_open_line, size: 18),
          label: Text(i18n('local_player_folder_empty_action')),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Phone: short-video shape, after the reference app — a dark top bar with the
// title, the speed chip and the ⋮ overflow; the overflow opens the settings
// under the context panel opens the episode list. Landscape is the fullscreen
// shape.
// ---------------------------------------------------------------------------

class _MobileLayout extends StatefulWidget {
  const _MobileLayout({required this.controller});

  final LocalVideoPlayerController controller;

  @override
  State<_MobileLayout> createState() => _MobileLayoutState();
}

class _MobileLayoutState extends State<_MobileLayout> {
  LocalVideoPlayerController get controller => widget.controller;

  /// Whether the phone is currently held sideways.
  bool get isLandscape {
    final size = MediaQuery.sizeOf(context);
    return size.width > size.height;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Back belongs to the page's [PlayerBackScope] above this layout: a bare
    // `PopScope` here never received Android's back at all, and a second handler
    // would answer the same gesture twice on the platforms where it does.
    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(() {
        // Picture-in-picture owns the whole body, exactly like the live room:
        // only the compact picture and its chat are visible — no page chrome.
        if (controller.isInPip.value) {
          return _RecordingPipOverlay(controller: controller);
        }
        // Scanning the folder is the only true "nothing to show yet" state; once
        // a file is open the player surface itself carries its own loading.
        if (controller.isLoading.value && controller.videoFiles.isEmpty) {
          // Folder scan: a small themed indicator on the video's own black, not
          // a full-screen white spinner page.
          return Center(
            child: SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: theme.colorScheme.primary),
            ),
          );
        }
        if (controller.videoFiles.isEmpty) {
          return SafeArea(child: _emptyState(context, controller, onDark: true));
        }
        // The page's SHAPE follows the fullscreen state, not the device's
        // orientation. Rotating the phone used to be enough to be "fullscreen"
        // — which is how the page ended up in a fullscreen-looking shape with
        // the episode panel still under it, and how leaving fullscreen changed
        // nothing on screen: the shape was already the rotated one.
        final fullscreen = controller.fullscreenActive.value;
        final landscapeShape = fullscreen || isLandscape;
        if (landscapeShape) {
          return Stack(
            fit: StackFit.expand,
            children: [
              _PlayerArea(controller: controller, keyboardShortcuts: true),
              _LandscapeTopBar(controller: controller, showCornerActions: fullscreen),
            ],
          );
        }
        // No `SafeArea` around this shape on purpose. A `SafeArea` here consumes
        // the insets for everything below it, so the bars inside — which add
        // `viewPadding` themselves — would read zero and slide back under the
        // status bar and the gesture bar. Each bar owns its own inset instead:
        // the top bar its top/side inset, the context panel its bottom one.
        return Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: Colors.black,
                    child: _PlayerArea(controller: controller),
                  ),
                  _PortraitTopBar(controller: controller),
                ],
              ),
            ),
            _ContextPanel(controller: controller),
          ],
        );
      }),
    );
  }
}

/// Portrait chrome over the picture: back, the title, and the same picture
/// actions the landscape bar carries while the page is fullscreen.
///
/// Outside fullscreen the portrait page keeps its normal app chrome: the back
/// button and the ⋮ overflow, with the same entries one sheet deeper.
class _PortraitTopBar extends StatelessWidget {
  const _PortraitTopBar({required this.controller});

  final LocalVideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    // The picture fills the page; this row is what has to stay out of the notch.
    // `viewPadding` is the raw system inset — nothing above consumes it — so the
    // bar adds it to its own padding. The gradient stays on the container so it
    // still reaches the top edge behind the status bar.
    final padding = _edgeInsets(context);
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(4 + padding.left, 4 + padding.top, 8 + padding.right, 12),
          child: Row(
            children: [
              IconButton(
                color: Colors.white,
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () async {
                  if (await controller.handleBackRequest()) Get.back<void>();
                },
              ),
              Expanded(
                child: Obx(
                  () => Text(
                    '${controller.roomTitle ?? i18n('recorder_local_player_title')}  '
                    '${i18n('local_player_index_label', args: {'index': '${controller.currentIndex.value + 1}'})}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              // A portrait fullscreen hides the page's own chrome, so the
              // picture's actions move here instead of disappearing with the
              // sheet that normally holds them.
              Obx(
                () => controller.fullscreenActive.value
                    ? _RecordingCornerActions(controller: controller, includeBack: false)
                    : IconButton(
                        color: Colors.white,
                        tooltip: i18n('settings_more'),
                        icon: const Icon(Icons.more_vert_rounded),
                        onPressed: () => _showSettingsSheet(context, controller),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The reference app's settings bottom sheet: speed, fit, danmaku, PiP, small
/// window — grouped into rounded cards like the reference panel, the episode
/// entry last.
void _showSettingsSheet(BuildContext context, LocalVideoPlayerController controller) {
  final theme = Theme.of(context);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: theme.colorScheme.surfaceContainerLowest,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (sheetContext) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Obx(() {
            final hasChat = controller.hasDanmaku.value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Playback card: speed and fit chips.
                _SheetCard(
                  theme: theme,
                  children: [
                    _SheetSpeedRow(controller: controller, theme: theme),
                    Divider(height: 1, thickness: 0.6, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                    _SheetFitRow(controller: controller, theme: theme),
                  ],
                ),
                const SizedBox(height: 10),
                // Presentation card: danmaku switch and the two windows.
                _SheetCard(
                  theme: theme,
                  children: [
                    if (hasChat) ...[
                      _SheetSwitchRow(
                        theme: theme,
                        icon: Icons.subtitles_rounded,
                        title: i18n('danmaku'),
                        value: !controller.danmakuHidden.value,
                        onChanged: (v) => controller.danmakuHidden.value = !v,
                      ),
                      Divider(
                        height: 1,
                        thickness: 0.6,
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ],
                    _SheetSwitchRow(
                      theme: theme,
                      icon: Icons.headphones_rounded,
                      title: i18n('audio_only_mode'),
                      value: controller.isAudioOnly.value,
                      onChanged: (v) => controller.isAudioOnly.value = v,
                    ),
                    Divider(height: 1, thickness: 0.6, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                    _SheetActionRow(
                      theme: theme,
                      icon: Icons.photo_camera_rounded,
                      title: i18n('local_player_screenshot'),
                      onTap: () async {
                        Navigator.of(sheetContext).pop();
                        final name = await controller.saveScreenshot();
                        ToastUtil.show(name ?? i18n('path_or_permission_error'));
                      },
                    ),
                    Divider(height: 1, thickness: 0.6, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                    _SheetActionRow(
                      theme: theme,
                      icon: Icons.picture_in_picture_rounded,
                      title: i18n('pip_window_play'),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        unawaited(_enterRecordingPip(controller));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Episodes card.
                _SheetCard(
                  theme: theme,
                  children: [
                    _SheetActionRow(
                      theme: theme,
                      icon: Icons.playlist_play_rounded,
                      title: i18n('recorder_local_player_title'),
                      trailing: i18n('local_player_files', args: {'count': '${controller.videoFiles.length}'}),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        unawaited(_openPlaylistSheet(context, controller));
                      },
                    ),
                  ],
                ),
              ],
            );
          }),
        ),
      );
    },
  );
}

/// One rounded card grouping sheet rows, the reference panel's container.
class _SheetCard extends StatelessWidget {
  const _SheetCard({required this.theme, required this.children});

  final ThemeData theme;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: Column(children: children),
    );
  }
}

/// One settings row: an icon, a label, and a trailing widget or chevron.
class _SheetRow extends StatelessWidget {
  const _SheetRow({required this.theme, required this.icon, required this.title, this.trailing, this.onTap});

  final ThemeData theme;
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: theme.colorScheme.onSurface),
            const SizedBox(width: 14),
            Expanded(
              child: Text(title, style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface)),
            ),
            ?trailing,
            if (onTap != null && trailing == null)
              Icon(Icons.chevron_right_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _SheetActionRow extends StatelessWidget {
  const _SheetActionRow({
    required this.theme,
    required this.icon,
    required this.title,
    this.trailing,
    required this.onTap,
  });

  final ThemeData theme;
  final IconData icon;
  final String title;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SheetRow(
      theme: theme,
      icon: icon,
      title: title,
      trailing: trailing == null ? null : Text(trailing!),
      onTap: onTap,
    );
  }
}

class _SheetSwitchRow extends StatelessWidget {
  const _SheetSwitchRow({
    required this.theme,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final ThemeData theme;
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SheetRow(
      theme: theme,
      icon: icon,
      title: title,
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}

/// The speed row: the label plus one chip per supported rate.
class _SheetSpeedRow extends StatelessWidget {
  const _SheetSpeedRow({required this.controller, required this.theme});

  final LocalVideoPlayerController controller;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.speed_rounded, size: 22, color: theme.colorScheme.onSurface),
          const SizedBox(width: 14),
          Text(i18n('playback_rate'), style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface)),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Obx(
                () => Row(
                  children: [
                    for (final rate in LocalVideoPlayerController.defaultRates)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('${rate.toStringAsFixed(rate == rate.roundToDouble() ? 1 : 2)}x'),
                          selected: (controller.playbackRate.value - rate).abs() < 0.001,
                          onSelected: (_) => unawaited(controller.setRate(rate)),
                          visualDensity: VisualDensity.compact,
                          labelStyle: TextStyle(
                            fontSize: 12.5,
                            color: (controller.playbackRate.value - rate).abs() < 0.001
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurface,
                          ),
                          selectedColor: theme.colorScheme.primary,
                          showCheckmark: false,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The fit row: one chip per stored fit mode, the same six the room cycles.
class _SheetFitRow extends StatelessWidget {
  const _SheetFitRow({required this.controller, required this.theme});

  final LocalVideoPlayerController controller;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final options = AppConsts().videoFitType;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.high_quality_rounded, size: 22, color: theme.colorScheme.onSurface),
          const SizedBox(width: 14),
          Text(i18n('video_fit'), style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface)),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Obx(() {
                final settings = SettingsService.to.player;
                final current = settings.resolvedVideoFitIndex;
                return Row(
                  children: [
                    for (var i = 0; i < options.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(i18n(options[i]['desc'] as String)),
                          selected: current == i,
                          onSelected: (_) => settings.videoFitIndex.v = i,
                          visualDensity: VisualDensity.compact,
                          labelStyle: TextStyle(
                            fontSize: 12.5,
                            color: current == i ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                          ),
                          selectedColor: theme.colorScheme.primary,
                          showCheckmark: false,
                        ),
                      ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the episode list sheet on top of whatever is showing.
Future<void> _openPlaylistSheet(BuildContext context, LocalVideoPlayerController controller) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (_) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.62,
      child: _PlaylistPanel(controller: controller, dense: true, onPicked: () => Navigator.of(context).pop()),
    ),
  );
}

/// floating bar from the reference app, then a thin progress line.
class _ContextPanel extends StatelessWidget {
  const _ContextPanel({required this.controller});

  final LocalVideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              controller.roomTitle ?? i18n('recorder_local_player_title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: Obx(
              () => Row(
                children: [
                  Expanded(
                    child: Material(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => unawaited(_openPlaylistSheet(context, controller)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${i18n('recorder_local_player_title')} · ${controller.currentFileName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13.5, color: theme.colorScheme.onSurface),
                                ),
                              ),
                              SizedBox(
                                width: 64,
                                child: Text(
                                  i18n('local_player_files', args: {'count': '${controller.videoFiles.length}'}),
                                  textAlign: TextAlign.right,
                                  maxLines: 1,
                                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                ),
                              ),
                              Icon(
                                Icons.keyboard_arrow_up_rounded,
                                size: 20,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // A read-only progress mirror: the real scrubber stays in the
          // library's bar over the picture, this line only says where the
          // recording is while the panel is up.
          Obx(() {
            final durationMs = controller.duration.value.inMilliseconds;
            final positionMs = controller.position.value.inMilliseconds;
            final progress = durationMs <= 0 ? 0.0 : (positionMs / durationMs).clamp(0.0, 1.0);
            return Padding(
              // The panel is the last thing on the page, so it takes the
              // home-indicator inset itself: on a phone held upright the
              // progress line used to sit under the system gesture bar.
              padding: EdgeInsets.fromLTRB(16, 2, 16, 12 + _edgeInsets(context).bottom),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  color: theme.colorScheme.primary,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Landscape keeps floating chrome: the picture is the screen and the actions
/// sit in the top gradient row.
///
/// [showCornerActions] adds the picture's own entries — audio-only, screenshot
/// and picture-in-picture — while the page is fullscreen. They used to live in a
/// separate overlay gated on `width > 680`, which a phone in landscape does not
/// reach: the three buttons existed on a tablet and were simply absent on a
/// phone, so "the top-right buttons do not respond" was them never being there.
class _LandscapeTopBar extends StatelessWidget {
  const _LandscapeTopBar({required this.controller, this.showCornerActions = false});

  final LocalVideoPlayerController controller;
  final bool showCornerActions;

  @override
  Widget build(BuildContext context) {
    // Same rule as the portrait bar: the picture stays full-bleed and this row
    // adds the raw system inset itself, so a sideways cutout and the status bar
    // are both cleared without shrinking the picture.
    final padding = _edgeInsets(context);
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(4 + padding.left, 4 + padding.top, 8 + padding.right, 12),
          child: Row(
            children: [
              IconButton(
                color: Colors.white,
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () async {
                  if (await controller.handleBackRequest()) Get.back<void>();
                },
              ),
              Expanded(
                child: Obx(
                  () => Text(
                    '${controller.roomTitle ?? i18n('recorder_local_player_title')}  '
                    '${controller.currentIndex.value + 1}/${controller.videoFiles.length}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              if (showCornerActions) _RecordingCornerActions(controller: controller, includeBack: false),
              // The portrait layout reaches the episode list through the panel
              // under the picture; the landscape shape has no panel, so the
              // list needs its own entry here or a rotated phone cannot change
              // recording at all.
              IconButton(
                color: Colors.white,
                tooltip: i18n('recorder_local_player_title'),
                icon: const Icon(Remix.play_list_line),
                onPressed: () => unawaited(_openPlaylistSheet(context, controller)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Desktop: picture and list side by side
// ---------------------------------------------------------------------------

/// The narrowest window in which the desktop player still splits into picture
/// beside list. The list pane is a fixed 320 px and the picture keeps its
/// padding, while the window's own floor is 400 px: below this threshold the
/// split leaves the video a narrow black strip, so the list moves under the
/// picture instead.
const double localPlayerSideBySideMinWidth = 760;

/// Whether the desktop recording player splits picture and list side by side.
bool localPlayerShowsSideBySide(double windowWidth) => windowWidth >= localPlayerSideBySideMinWidth;

/// The narrowest control row that can still carry the 100 px volume slider.
///
/// At 504 px the row needed 554 px — the run log's "RenderFlex overflowed by
/// 50 pixels on the right" — so below this width the slider is dropped and the
/// 40 px mute toggle stays: it is the only sound control on this bar.
const double recordingVolumeSliderMinWidth = 520;

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({required this.controller});

  final LocalVideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Back is the page's [PlayerBackScope] above this layout: same rule as the
    // room — it leaves the fullscreen shape first and only lets a page that is
    // not fullscreen be left — but exactly one handler owns it.
    return Obx(() {
      //
      if (controller.isInPip.value) {
        return _RecordingPipOverlay(controller: controller);
      }
      if (controller.isFullscreen.value) {
        // A portrait recording keeps its vertical shape in fullscreen: the
        // picture is contained at full height with the list under it, instead
        // of being stretched into a landscape frame.
        if (controller.portraitFullscreen.value) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(child: _PlayerArea(controller: controller, keyboardShortcuts: true)),
                  const Divider(height: 1),
                  SizedBox(
                    height: (MediaQuery.sizeOf(context).height * 0.3).clamp(120.0, 260.0),
                    child: _PlaylistPanel(controller: controller),
                  ),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          backgroundColor: Colors.black,
          body: _PlayerArea(controller: controller, keyboardShortcuts: true),
        );
      }
      return Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () async {
              if (await controller.handleBackRequest()) Get.back<void>();
            },
          ),
          title: Obx(
            () => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  controller.roomTitle ?? i18n('recorder_local_player_title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                Text(
                  controller.videoFiles.isEmpty
                      ? i18n('recorder_local_player_playlist_empty')
                      : '${controller.currentFileName}   ${controller.currentIndex.value + 1}/${controller.videoFiles.length}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          actions: const [SizedBox(width: 8)],
        ),
        body: Obx(() {
          // The PiP branch above already owns the whole page, so no second
          // check here. Scanning the folder is the only true "nothing to show
          // yet" state: a reload that still has files on screen keeps showing
          // the player instead of swapping it for a spinner, like the mobile
          // layout does.
          if (controller.isLoading.value && controller.videoFiles.isEmpty) {
            return Center(
              child: SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: theme.colorScheme.primary),
              ),
            );
          }
          if (controller.videoFiles.isEmpty) {
            return _emptyState(context, controller);
          }
          final videoPane = Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ColoredBox(
                  color: Colors.black,
                  child: _PlayerArea(controller: controller, keyboardShortcuts: true),
                ),
              ),
            ),
          );
          if (!localPlayerShowsSideBySide(MediaQuery.sizeOf(context).width)) {
            final panelHeight = (MediaQuery.sizeOf(context).height * 0.4).clamp(150.0, 320.0);
            return Column(
              children: [
                videoPane,
                const Divider(height: 1),
                SizedBox(
                  height: panelHeight,
                  child: _PlaylistPanel(controller: controller),
                ),
              ],
            );
          }
          return Row(
            children: [
              videoPane,
              const VerticalDivider(width: 1),
              SizedBox(width: 320, child: _PlaylistPanel(controller: controller)),
            ],
          );
        }),
      );
    });
  }
}
