import 'dart:async' show Completer, StreamSubscription, unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// The playback commands (open/play/pause/seek) are an extension on
// PlayerHandle, so the barrel import stays whole — a `show` list would
// leave the extension behind.
import 'package:media_core/media_core.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/player/media_bar_button.dart';
import 'package:pure_live/shared/player/on_video_colors.dart';
import 'package:pure_live/shared/player/player_teardown.dart' show silencePlayer;

/// What a playing page hands the floating mini window (小窗播放).
///
/// The window never inherits the page's [PlayerHandle]: handles belong to
/// their module's kernel, and the module wall disposes the kernel — handles
/// and all — the moment the shell moves on, which is exactly when a mini
/// window must keep playing. Instead the handoff carries the source the page
/// was playing, and the window opens its own handle on the app-level
/// [floatingVideoKernelProvider], seeking to [resume] so nothing is lost but
/// the reopening beat.
final class FloatingVideoHandoff {
  /// Creates the handoff.
  const FloatingVideoHandoff({
    required this.title,
    required this.open,
    this.resume = Duration.zero,
    this.rate,
    this.muted,
    this.onClose,
  });

  /// What the window's drag bar says.
  final String title;

  /// Opens the picture on the window's kernel. The closure captures whatever
  /// the page needed at handoff time (the source, the preferred backend), so
  /// the window stays a bystander to the page's own wiring.
  final Future<PlayerHandle> Function(PlayerKernel kernel) open;

  /// Where the page had got to; the window seeks here once its own handle is
  /// open.
  final Duration resume;

  /// The page's playback rate, kept so a 2× take stays 2× in the window.
  final double? rate;

  /// The page's mute state, kept so a muted take stays muted.
  final bool? muted;

  /// Hears the window's last position when it closes, whichever way it
  /// closes — the ✕, the expand button, or a newer video superseding it.
  /// `reopen` says the viewer asked for the page back; the page pushes its
  /// own route there, resuming from `position` where it supports one.
  final void Function(Duration position, {required bool reopen})? onClose;
}

/// The app-wide floating mini window for VOD-class playback. The live room
/// keeps its own danmaku-aware window (`floating_room_player.dart`) — the
/// flying danmaku needs the room's controllers, which a generic handoff
/// does not carry, so this window plays the picture alone.
///
/// One window at a time: a handoff while one shows supersedes it, closing
/// the old window (its `onClose` still hears the old position) before the
/// new one opens.
final class FloatingVideoWindow {
  FloatingVideoWindow._();

  static OverlayEntry? _entry;
  static bool _scheduled = false;
  static int _generation = 0;
  static Completer<bool>? _showCompleter;

  /// The showing view's own close path, so a supersede can run the same
  /// checkpoint a viewer's ✕ would. Set by the view, cleared by its dispose.
  static void Function()? _activeClose;

  /// Whether the window is on screen (or about to be inserted).
  static bool get isShowing => _entry != null || _scheduled;

  /// Inserts the window above every route once the current frame is done;
  /// the future answers whether the window is (or will be) on screen. A
  /// caller that goes on to leave its page must treat a false answer as
  /// "nothing was handed over" and keep its own playback.
  static Future<bool> show(FloatingVideoHandoff handoff) {
    if (_entry != null) {
      // One at a time: the old window's close path runs first, checkpointing
      // its position, then this handoff takes the overlay on the next frame.
      final previous = _activeClose;
      _activeClose = null;
      previous?.call();
    }
    if (_scheduled) {
      final completer = _showCompleter!;
      final previous = _handoff;
      _handoff = handoff;
      previous?.onClose?.call(previous.resume, reopen: false);
      return completer.future;
    }
    _scheduled = true;
    _showCompleter = Completer<bool>();
    final generation = ++_generation;
    final completer = _showCompleter!;
    _handoff = handoff;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      void abort() {
        _scheduled = false;
        if (_showCompleter == completer) _showCompleter = null;
        if (!completer.isCompleted) completer.complete(false);
      }

      if (generation != _generation) {
        abort();
        return;
      }
      final context = rootNavigatorKey.currentContext;
      if (context == null) {
        abort();
        return;
      }
      // The root navigator owns its overlay; an ancestor lookup from the
      // navigator's own element finds nothing (the overlay is its child),
      // so the state's own handle is the way in.
      final navigator = rootNavigatorKey.currentState;
      final overlay = (navigator != null && navigator.mounted) ? navigator.overlay : null;
      if (overlay == null) {
        abort();
        return;
      }
      final entry = OverlayEntry(builder: (_) => const FloatingVideoView());
      overlay.insert(entry);
      _entry = entry;
      _scheduled = false;
      if (_showCompleter == completer) _showCompleter = null;
      if (!completer.isCompleted) completer.complete(true);
    });
    return completer.future;
  }

  /// Removes the window. The showing view's close path runs first — the
  /// checkpoint a ✕ would write — so a page that starts a new video while a
  /// mini window plays loses nothing of the old one.
  static void dismiss() {
    final close = _activeClose;
    _activeClose = null;
    if (close != null) {
      close();
      return;
    }
    _removeEntry();
  }

  static void _removeEntry() {
    _generation++;
    _scheduled = false;
    final completer = _showCompleter;
    _showCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete(false);
    final entry = _entry;
    _entry = null;
    _handoff = null;
    if (entry != null && entry.mounted) entry.remove();
  }

  static FloatingVideoHandoff? _handoff;
}

/// The mini window: the picture, a drag bar (title, play/pause, the way
/// back, the ✕) and a resize corner. The controls stay text-free with
/// semantics labels, the way the live room's own window does.
final class FloatingVideoView extends ConsumerStatefulWidget {
  /// Creates the overlay content.
  const FloatingVideoView({super.key});

  @override
  ConsumerState<FloatingVideoView> createState() => _FloatingVideoViewState();
}

final class _FloatingVideoViewState extends ConsumerState<FloatingVideoView> {
  PlayerHandle? _handle;
  PlayerKernel? _kernel;
  StreamSubscription<void>? _transportSub;
  StreamSubscription<void>? _geometrySub;
  bool _failed = false;

  /// The facts the window's own chrome reads: the transport's playing state
  /// and the picture's aspect. The streams beneath them move per tick, the
  /// window rebuilds only when one of these two actually turns — the video
  /// view inside repaints on its own.
  bool _playing = false;
  double _aspect = 0;

  /// The width the viewer pulled, or null to follow the size preset.
  double? _width;
  Offset? _origin;

  @override
  void initState() {
    super.initState();
    _kernel = ref.read(floatingVideoKernelProvider);
    FloatingVideoWindow._activeClose = () {
      if (mounted) _close(reopen: false);
    };
    unawaited(_open());
  }

  @override
  void dispose() {
    FloatingVideoWindow._activeClose = null;
    unawaited(_transportSub?.cancel() ?? Future<void>.value());
    unawaited(_geometrySub?.cancel() ?? Future<void>.value());
    final kernel = _kernel;
    final handle = _handle;
    _handle = null;
    if (kernel != null && handle != null) {
      silencePlayer(handle);
      unawaited(kernel.release(handle.id));
    }
    super.dispose();
  }

  Future<void> _open() async {
    final handoff = FloatingVideoWindow._handoff;
    final kernel = _kernel;
    if (handoff == null || kernel == null) return;
    try {
      final handle = await handoff.open(kernel);
      if (!mounted) {
        silencePlayer(handle);
        unawaited(kernel.release(handle.id));
        return;
      }
      setState(() => _handle = handle);
      final rate = handoff.rate;
      if (rate != null && rate != 1) unawaited(handle.setRate(rate));
      final muted = handoff.muted;
      if (muted != null) unawaited(handle.setMute(muted: muted));
      final resume = handoff.resume;
      if (resume > Duration.zero) unawaited(handle.seek(resume));
      _playing = handle.isPlaying;
      _transportSub = handle.playbackStream.listen((_) {
        final now = handle.isPlaying;
        if (!mounted || now == _playing) return;
        setState(() => _playing = now);
      });
      _geometrySub = handle.geometryController.state.listen((_) {
        final detected = handle.combinedSnapshot.geometry.aspectRatio;
        if (!mounted || detected == _aspect) return;
        setState(() => _aspect = detected);
      });
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _close({required bool reopen}) {
    final handle = _handle;
    // A window whose picture never opened has no position of its own: the
    // page's handoff position is the truth there. Falling back to zero would
    // let a close that beat the first frame checkpoint a fresh start over
    // the progress the page had.
    final position = handle?.position ?? FloatingVideoWindow._handoff?.resume ?? Duration.zero;
    final onClose = FloatingVideoWindow._handoff?.onClose;
    FloatingVideoWindow._removeEntry();
    // The callback runs after the overlay is gone: a page that pushes its
    // route back does so with the window already out of the way, and one
    // that only persists progress does it before this State — and the
    // handle — is released.
    if (onClose != null) onClose(position, reopen: reopen);
  }

  void _returnToVideo() => _close(reopen: true);

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final handoff = FloatingVideoWindow._handoff;
    if (handoff == null) return const SizedBox.shrink();
    final handle = _handle;
    final screen = MediaQuery.sizeOf(context);
    final floating = ref.watch(floatingWindowSettingsProvider);
    final playback = ref.watch(playbackSettingsProvider);
    final detected = handle == null ? 0.0 : _aspect;
    final ratio = detected > 0 && detected.isFinite ? detected.clamp(0.5, 2.4) : 16 / 9;
    final portrait = ratio < 1;
    final base = kFloatingWindowBaseWidth * floatingWindowSizeFactor(floating.size);
    final scale = portrait ? floating.portraitScale : floating.landscapeScale;
    final maxWidth = math.min(screen.width - 16, math.max(220, (screen.height - 16) * ratio)).toDouble();
    final width = (_width ?? base * scale).clamp(200, math.max(200, maxWidth)).toDouble();
    final height = width / ratio;
    final maxX = math.max(0, screen.width - width - 8).toDouble();
    final maxY = math.max(0, screen.height - height - 8).toDouble();
    final origin = _origin ?? Offset(maxX, maxY);
    final left = origin.dx.clamp(0, maxX).toDouble();
    final top = origin.dy.clamp(0, maxY).toDouble();
    final playing = handle != null && _playing;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: left,
          top: top,
          width: width,
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(DsTheme.of(context).radii.card),
            child: ColoredBox(
              color: OnVideoColors.ground,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (handle != null)
                    MediaPlayerView(handle: handle, fit: playback.fit.boxFit)
                  else
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(DsSpace.s8),
                        child: Text(
                          _failed ? t.common.refreshFailed : handoff.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: DsTheme.of(context).typography.caption.copyWith(color: OnVideoColors.inkMuted),
                        ),
                      ),
                    ),
                  PositionedDirectional(
                    start: 0,
                    top: 0,
                    end: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (details) {
                        final base = _origin ?? Offset(left, top);
                        setState(() => _origin = base + details.delta);
                      },
                      child: Container(
                        color: OnVideoColors.scrim,
                        padding: const EdgeInsetsDirectional.only(start: DsSpace.s8, end: DsSpace.s4),
                        child: Row(
                          spacing: DsSpace.s4,
                          children: [
                            Expanded(
                              child: Text(
                                handoff.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DsTheme.of(context).typography.caption
                                    .copyWith(color: OnVideoColors.inkMuted, fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (handle != null)
                              MediaBarButton(
                                iconAsset: playing ? 'assets/icons/pause.svg' : 'assets/icons/play.svg',
                                label: playing ? t.player.pause : t.player.play,
                                onPressed: () => unawaited(playing ? handle.pause() : handle.play()),
                                tooltip: false,
                              ),
                            MediaBarButton(
                              icon: DsIcons.pictureInPicture2,
                              label: t.common.backToVideo,
                              onPressed: _returnToVideo,
                              tooltip: false,
                            ),
                            MediaBarButton(
                              icon: DsIcons.x,
                              label: t.common.close,
                              onPressed: () => _close(reopen: false),
                              tooltip: false,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    end: 0,
                    bottom: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (details) {
                        final limit = math.max(220, math.min(720, maxWidth)).toDouble();
                        setState(() {
                          final current = _width ?? width;
                          _width = (current + details.delta.dx).clamp(200, limit).toDouble();
                        });
                      },
                      onPanEnd: (_) {
                        final pulled = _width;
                        if (pulled != null) {
                          unawaited(
                            ref
                                .read(floatingWindowSettingsProvider.notifier)
                                .setScale(portrait: portrait, value: pulled / base),
                          );
                        }
                      },
                      child: Semantics(
                        label: context.t.common.resizeWindow,
                        child: const Padding(
                          padding: EdgeInsets.all(DsSpace.s12),
                          child: DsIcon(DsIcons.expand, size: 12, color: OnVideoColors.inkFaint),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
