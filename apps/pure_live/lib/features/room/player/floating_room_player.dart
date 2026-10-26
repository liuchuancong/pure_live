import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart' show Icon, Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:media_core/media_core.dart' show MediaPlayerView, PlayerHandle;

import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/room/controller/room_controller.dart' show roomProvider;
import 'package:pure_live/features/room/page/audio_only_cover.dart' show AudioOnlyCover;
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';

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

  /// Inserts the window above every route once the current frame is done.
  static void show() {
    if (_entry != null || _scheduled) return;
    _scheduled = true;
    final generation = ++_generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (generation != _generation) return;
      _scheduled = false;
      if (_entry != null) return;
      final context = rootNavigatorKey.currentContext;
      if (context == null) return;
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay == null) return;
      final entry = OverlayEntry(builder: (_) => const FloatingRoomPlayerView());
      overlay.insert(entry);
      _entry = entry;
    });
  }

  /// Removes the window; the caller decides whether to stop the room.
  static void hide() {
    _generation++;
    _scheduled = false;
    final entry = _entry;
    _entry = null;
    if (entry != null && entry.mounted) entry.remove();
  }
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

  void _close() {
    FloatingRoomPlayer.hide();
    unawaited(ref.read(roomProvider.notifier).close());
  }

  void _returnToRoom() {
    final room = ref.read(roomProvider).room;
    FloatingRoomPlayer.hide();
    if (room == null) return;
    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    unawaited(context.push('/room/${Uri.encodeComponent(room.ref.platform)}/${Uri.encodeComponent(room.ref.roomId)}'));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final room = ref.watch(roomProvider);
    ref.listen<PlayerHandle?>(roomProvider.select((state) => state.handle), (previous, next) {
      if (next == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => FloatingRoomPlayer.hide());
      }
    });
    final handle = room.handle;
    final liveRoom = room.room;
    if (handle == null || liveRoom == null) return const SizedBox.shrink();

    final screen = MediaQuery.sizeOf(context);
    final floating = ref.watch(floatingWindowSettingsProvider);
    ref.listen(floatingWindowSettingsProvider.select((value) => value.size), (previous, next) {
      if (previous != next && mounted) setState(() => _width = null);
    });
    final detected = handle.combinedSnapshot.geometry.aspectRatio;
    final ratio = detected > 0 && detected.isFinite ? detected.clamp(0.5, 2.4) : 16 / 9;
    final portrait = ratio < 1;
    final base = kFloatingWindowBaseWidth * floatingWindowSizeFactor(floating.size);
    final scale = portrait ? floating.portraitScale : floating.landscapeScale;
    final maxWidth = math
        .min(screen.width - 16, math.max(220, (screen.height - 16) * ratio))
        .toDouble();
    final width = (_width ?? base * scale).clamp(200, math.max(200, maxWidth)).toDouble();
    final height = width / ratio;
    final maxX = math.max(0, screen.width - width - 8).toDouble();
    final maxY = math.max(0, screen.height - height - 8).toDouble();
    final origin = _origin ?? Offset(maxX, maxY);
    final left = origin.dx.clamp(0, maxX).toDouble();
    final top = origin.dy.clamp(0, maxY).toDouble();
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
                  MediaPlayerView(
                    handle: handle,
                    fit: ref.watch(playbackSettingsProvider).fit.boxFit,
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
                            _FloatingButton(
                              icon: room.playback.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              label: room.playback.playing ? t.room.pause : t.room.play,
                              onPressed: () => unawaited(ref.read(roomProvider.notifier).togglePlayPause()),
                            ),
                            _FloatingButton(
                              icon: Icons.open_in_full_rounded,
                              label: t.room.backToRoom,
                              onPressed: _returnToRoom,
                            ),
                            _FloatingButton(icon: Icons.close_rounded, label: t.common.close, onPressed: _close),
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
                        child: Icon(Icons.open_in_full, size: 12, color: Color(0x80FFFFFF)),
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

/// A small overlay control: no Material dependency, just a hit target and an
/// icon.
final class _FloatingButton extends StatelessWidget {
  const _FloatingButton({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(DsSpace.s6),
          child: Icon(icon, size: 18, color: const Color(0xE6FFFFFF)),
        ),
      ),
    );
  }
}
