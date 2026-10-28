import 'dart:async' show Completer, unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flame_barrage/flame_barrage.dart' show EmojiAtlas, FlameBarrageWidget;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:media_core/media_core.dart' show MediaPlayerView, PlayerHandle;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/room/controller/room_controller.dart' show barrageProvider, roomProvider;
import 'package:pure_live/modules/live/room/page/audio_only_cover.dart' show AudioOnlyCover;
import 'package:pure_live/modules/live/room/player/compact_danmaku_metrics.dart' show CompactDanmakuMetrics;
import 'package:pure_live/modules/live/room/player/room_barrage_config.dart' show roomBarrageConfig;
import 'package:pure_live/shared/shared.dart';

/// The app-level floating live-room player (the reference's `floatPlay`).
///
/// Leaving a playing room with the setting on keeps its `PlayerHandle` alive
/// and inserts this overlay above the root navigator, so browsing other pages
/// does not stop the stream. The room controller outlives the room page; the
/// page only skips its usual close when handing over.
final class FloatingRoomPlayer {
  FloatingRoomPlayer._();

  static OverlayEntry? _entry;
  static bool _scheduled = false;
  static int _generation = 0;

  /// Whether the floating window is on screen (or about to be inserted).
  static bool get isShowing => _entry != null || _scheduled;

  /// Whether the root overlay exists right now, so a leaving room can decide
  /// to hand off instead of stopping when the host is already tearing down.
  static bool get canShow {
    final context = rootNavigatorKey.currentContext;
    return context != null && Overlay.maybeOf(context, rootOverlay: true) != null;
  }

  /// Inserts the window above every route once the current frame is done;
  /// the future answers whether the window is (or will be) on screen. A
  /// caller that is about to lose its State must treat a false answer as
  /// "no handoff happened" and stop the room itself — the overlay never
  /// silently swallows a live handle.
  static Future<bool> show() {
    if (_entry != null) return Future.value(true);
    if (_scheduled) return _showCompleter!.future;
    _scheduled = true;
    _showCompleter = Completer<bool>();
    final generation = ++_generation;
    final completer = _showCompleter!;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Anything but a successful insert must complete false and release
      // the schedule flag, or the next show would be blocked forever.
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
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay == null) {
        abort();
        return;
      }
      final entry = OverlayEntry(builder: (_) => const FloatingRoomPlayerView());
      overlay.insert(entry);
      _entry = entry;
      _scheduled = false;
      if (_showCompleter == completer) _showCompleter = null;
      if (!completer.isCompleted) completer.complete(true);
    });
    return completer.future;
  }

  /// Removes the window; the caller decides whether to stop the room.
  static void hide() {
    _generation++;
    _scheduled = false;
    final completer = _showCompleter;
    _showCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete(false);
    final entry = _entry;
    _entry = null;
    if (entry != null && entry.mounted) entry.remove();
  }

  static Completer<bool>? _showCompleter;
}

/// The mini window: the live picture (or audio-only cover), a drag bar and a
/// resize corner. Controls are text-free with semantics labels so the window
/// stays usable on touch and desktop.
final class FloatingRoomPlayerView extends ConsumerStatefulWidget {
  /// Creates the overlay content.
  const FloatingRoomPlayerView({super.key});

  @override
  ConsumerState<FloatingRoomPlayerView> createState() => _FloatingRoomPlayerViewState();
}

final class _FloatingRoomPlayerViewState extends ConsumerState<FloatingRoomPlayerView> {
  /// The width the viewer pulled, or null to follow the size preset.
  double? _width;
  Offset? _origin;

  @override
  void initState() {
    super.initState();
    // The Android small window shows this same player; it fills the window.
    FloatingOverlay.active.addListener(_overlayChanged);
  }

  @override
  void dispose() {
    FloatingOverlay.active.removeListener(_overlayChanged);
    super.dispose();
  }

  void _overlayChanged() {
    if (mounted) setState(() {});
  }

  void _close() {
    final inWindow = FloatingOverlay.active.value;
    FloatingRoomPlayer.hide();
    // The ✕ means "I am done watching" on both hosts: the room stops, and the
    // page under the window leaves rather than showing an ended room next
    // time. The stop comes first — the page reads the still-playing room on a
    // pop as a leave and would hand it straight back to this overlay.
    unawaited(ref.read(roomProvider.notifier).close());
    if (inWindow) {
      unawaited(FloatingOverlay.close());
      if (context.canPop()) context.pop();
    }
  }

  void _returnToRoom() {
    final room = ref.read(roomProvider).room;
    FloatingRoomPlayer.hide();
    if (room == null) return;
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    unawaited(context.push('/room/${Uri.encodeComponent(room.ref.platform)}/${Uri.encodeComponent(room.ref.roomId)}'));
  }

  /// Over other apps the window's expand brings the app back in front; the
  /// window goes as the activity starts, and the room page is still there.
  void _backToApp() => unawaited(FloatingOverlay.backToApp());

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final room = ref.watch(roomProvider);
    ref.listen<PlayerHandle?>(roomProvider.select((state) => state.handle), (previous, next) {
      if (next == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          FloatingRoomPlayer.hide();
          // A stream that stopped while the small window showed leaves nothing
          // behind on the other apps.
          if (FloatingOverlay.active.value) unawaited(FloatingOverlay.close());
        });
      }
    });
    final handle = room.handle;
    final liveRoom = room.room;
    if (handle == null || liveRoom == null) return const SizedBox.shrink();

    final screen = MediaQuery.sizeOf(context);
    // In the Android window the viewport *is* the small window: the player
    // fills it rather than sitting in its usual corner of a page-sized screen.
    final inWindow = FloatingOverlay.active.value;
    final floating = ref.watch(floatingWindowSettingsProvider);
    // The small-window danmaku settings (the same ones the PiP surface
    // follows): the flying layer keeps running over the floating picture,
    // scaled for the window's width.
    final playback = ref.watch(playbackSettingsProvider);
    final style = ref.watch(danmakuStyleProvider);
    final danmakuFps = ref.watch(danmakuEffectiveFpsProvider);
    final pipScale = ref.watch(pipDanmakuScaleProvider);
    final danmakuFamily = effectiveFontFamily(style.fontFamily, ref.watch(danmakuFontFaceProvider));
    final barrage = ref.watch(barrageProvider);
    final showDanmaku = playback.danmakuVisible && playback.miniDanmakuVisible && !room.audioOnly && barrage != null;
    ref.listen(floatingWindowSettingsProvider.select((value) => value.size), (previous, next) {
      if (previous != next && mounted) setState(() => _width = null);
    });
    final detected = handle.combinedSnapshot.geometry.aspectRatio;
    final ratio = detected > 0 && detected.isFinite ? detected.clamp(0.5, 2.4) : 16 / 9;
    final portrait = ratio < 1;
    final base = kFloatingWindowBaseWidth * floatingWindowSizeFactor(floating.size);
    final scale = portrait ? floating.portraitScale : floating.landscapeScale;
    final maxWidth = math.min(screen.width - 16, math.max(220, (screen.height - 16) * ratio)).toDouble();
    final width = inWindow ? screen.width : (_width ?? base * scale).clamp(200, math.max(200, maxWidth)).toDouble();
    final height = inWindow ? screen.height : width / ratio;
    final maxX = inWindow ? 0.0 : math.max(0, screen.width - width - 8).toDouble();
    final maxY = inWindow ? 0.0 : math.max(0, screen.height - height - 8).toDouble();
    final origin = _origin ?? Offset(maxX, maxY);
    final left = inWindow ? 0.0 : origin.dx.clamp(0, maxX).toDouble();
    final top = inWindow ? 0.0 : origin.dy.clamp(0, maxY).toDouble();
    final title = liveRoom.content.title.trim().isEmpty ? t.common.appTitle : liveRoom.content.title;

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
              color: const Color(0xFF000000),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (room.audioOnly)
                    AudioOnlyCover(room: liveRoom)
                  else
                    MediaPlayerView(handle: handle, fit: playback.fit.boxFit),
                  if (showDanmaku)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: FlameBarrageWidget(
                          config: roomBarrageConfig(
                            style,
                            danmakuFps,
                            family: danmakuFamily,
                            compact: CompactDanmakuMetrics.resolve(
                              width: width,
                              auto: pipScale.auto,
                              pinnedScale: pipScale.scale,
                              configuredFontSize: style.fontSize,
                              configuredSpeed: style.baseSpeed,
                            ),
                          ),
                          emojiAtlas: EmojiAtlas.instance,
                          controller: barrage,
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
                        if (inWindow) {
                          // Over other apps the native window itself moves;
                          // local offsets would only slide the picture inside
                          // an unmoving window.
                          unawaited(FloatingOverlay.moveBy(details.delta));
                          return;
                        }
                        final base = _origin ?? Offset(left, top);
                        setState(() => _origin = base + details.delta);
                      },
                      child: Container(
                        color: const Color(0xB3000000),
                        padding: const EdgeInsetsDirectional.only(start: DsSpace.s8, end: DsSpace.s4),
                        child: Row(
                          spacing: DsSpace.s4,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DsTheme.of(context).typography.caption
                                    .copyWith(color: const Color(0xE6FFFFFF), fontWeight: FontWeight.w600),
                              ),
                            ),
                            MediaBarButton(
                              icon: room.playback.playing ? DsIcons.pause : DsIcons.play,
                              label: room.playback.playing ? t.room.pause : t.room.play,
                              onPressed: () => unawaited(ref.read(roomProvider.notifier).togglePlayPause()),
                              tooltip: false,
                              zoomsOnTv: false,
                            ),
                            MediaBarButton(
                              icon: DsIcons.expand,
                              label: t.room.backToRoom,
                              onPressed: inWindow ? _backToApp : _returnToRoom,
                              tooltip: false,
                              zoomsOnTv: false,
                            ),
                            MediaBarButton(
                              icon: DsIcons.x,
                              label: t.common.close,
                              onPressed: _close,
                              tooltip: false,
                              zoomsOnTv: false,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (!inWindow)
                    PositionedDirectional(
                      end: 0,
                      bottom: 0,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanUpdate: (details) {
                          final limit = math.max(220, math.min(720, math.max(220, maxWidth))).toDouble();
                          setState(() {
                            final current = _width ?? width;
                            _width = (current + details.delta.dx).clamp(220, limit).toDouble();
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
                        child: const Padding(
                          padding: EdgeInsets.all(DsSpace.s4),
                          child: DsIcon(DsIcons.expand, size: 12, color: Color(0x80FFFFFF)),
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
