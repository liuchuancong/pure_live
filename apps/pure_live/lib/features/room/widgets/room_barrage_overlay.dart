import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_interaction/live_interaction.dart' show InteractionSession;
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/features/room/room_providers.dart';

/// One barrage in flight.
final class _Barrage {
  new({required this.message, required this.row, required this.pinned, required this.startedAt});

  final LiveMessage message;

  /// The scroll row it owns, 0-based; ignored when [pinned].
  final int row;

  /// Whether it sits in the pinned band under the top edge instead of scrolling.
  final bool pinned;

  final DateTime startedAt;
}

/// The danmaku drawn over the video — the reference's `PlayerDanmakuSurface`.
///
/// [lanes] scroll rows carry the traffic and a pinned band under the top edge
/// catches a burst that found every row busy. A message that cannot fit is
/// dropped rather than queued: a backlog would replay the room when the phone
/// is turned back, which is not what a barrage is for.
final class RoomBarrageOverlay extends ConsumerStatefulWidget {
  /// A barrage over [identity]'s video.
  const new({required this.identity, this.lanes = 4, this.fontSize, this.showSender = true, super.key});

  /// The room whose messages are drawn.
  final RoomIdentity identity;

  /// How many rows may scroll at once.
  final int lanes;

  /// The text size; null takes the barrage size from settings — a TV passes an
  /// explicit one for the 10-foot view.
  final double? fontSize;

  /// Whether the sender's name rides in front of the text.
  final bool showSender;

  @override
  ConsumerState<RoomBarrageOverlay> createState() => _RoomBarrageOverlayState();
}

final class _RoomBarrageOverlayState extends ConsumerState<RoomBarrageOverlay> with SingleTickerProviderStateMixin {
  /// How long a line takes to cross, and how long a pinned one stays.
  static const _scrollSeconds = 8.0;
  static const _pinnedSeconds = 5.0;

  /// What a burst may hold at once, and how close behind another line the same
  /// row may start (so two lines never stack).
  static const _maxLive = 48;
  static const _rowGapMilliseconds = 700;

  late final AnimationController _ticker = AnimationController(vsync: this, duration: const Duration(milliseconds: 33))
    ..repeat();

  final List<_Barrage> _live = [];
  StreamSubscription<LiveMessage>? _sub;
  StreamSubscription<LiveMessage>? _busSub;
  int _cursor = 0;

  @override
  void initState() {
    super.initState();
    _bind(ref.read(danmakuSessionProvider(widget.identity)).value);
    // The local-message bus is the reference's delivery queue: what the
    // viewer types crosses the video beside the platform's own traffic,
    // bypassing the session's shield (it never shielded the sender themself).
    _busSub = ref.read(roomLocalMessageBusProvider(widget.identity)).messages.listen(_onMessage);
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    unawaited(_busSub?.cancel());
    _ticker.dispose();
    super.dispose();
  }

  /// Follows the session the provider currently holds — a retry or a shield
  /// edit hands over a different one, and the barrage moves with it.
  void _bind(InteractionSession? session) {
    unawaited(_sub?.cancel());
    _live.clear();
    _sub = session?.messages.listen(_onMessage);
  }

  @override
  void didUpdateWidget(covariant RoomBarrageOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity) {
      _bind(ref.read(danmakuSessionProvider(widget.identity)).value);
    }
  }

  void _onMessage(LiveMessage message) {
    if (message.type != LiveMessageType.chat || message.text.isEmpty || !mounted) {
      return;
    }
    setState(() {
      if (_live.length >= _maxLive) {
        _live.removeAt(0);
      }
      final row = _freeRow();
      _live.add(_Barrage(message: message, row: row ?? -1, pinned: row == null, startedAt: DateTime.now()));
    });
  }

  /// The scroll row whose last line has cleared enough of the head of the row,
  /// or null when every row is still busy.
  int? _freeRow() {
    final now = DateTime.now();
    for (var offset = 0; offset < widget.lanes; offset++) {
      final row = (_cursor + offset) % widget.lanes;
      _Barrage? last;
      for (final entry in _live) {
        if (!entry.pinned && entry.row == row) {
          last = entry;
        }
      }
      if (last == null || now.difference(last.startedAt).inMilliseconds > _rowGapMilliseconds) {
        _cursor = (row + 1) % widget.lanes;
        return row;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // The pane's settings tab edits these two answers and the surface honours
    // them live; a caller that pinned a size (the TV) keeps its own.
    final fontSize = widget.fontSize ?? ref.watch(appPreferencesProvider).barrageFontSize;
    final opacity = ref.watch(appPreferencesProvider).barrageOpacity.clamp(0.2, 1.0);
    final laneHeight = fontSize * 1.6;
    final now = DateTime.now();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ticker,
        builder: (context, _) {
          // Entries leave on the frame after they clear rather than on their
          // own timers: a paused app does not tick, and a queue would then
          // grow until the video is unreadable.
          _live.removeWhere((entry) => _elapsed(entry, now) >= (entry.pinned ? _pinnedSeconds : _scrollSeconds));
          final pinned = _live.where((entry) => entry.pinned).toList(growable: false);
          return ClipRect(
            child: Stack(
              children: [
                for (var index = 0; index < pinned.length; index++)
                  Positioned(
                    left: 12,
                    top: 8 + index * laneHeight,
                    child: _line(pinned[index], width, fontSize, opacity),
                  ),
                for (final entry in _live)
                  if (!entry.pinned)
                    Positioned(
                      left: width - _travel(entry, now, width, fontSize),
                      top: 8 + (entry.row + 1) * laneHeight,
                      child: _line(entry, width, fontSize, opacity),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }

  double _elapsed(_Barrage entry, DateTime now) => now.difference(entry.startedAt).inMilliseconds / 1000;

  /// How far the line has travelled: from just off the right edge to just off
  /// the left one, so the exit is as smooth as the entry.
  double _travel(_Barrage entry, DateTime now, double width, double fontSize) {
    final progress = (_elapsed(entry, now) / _scrollSeconds).clamp(0.0, 1.0);
    final estimated = entry.message.text.length * fontSize * 0.62;
    return progress * (width + estimated);
  }

  Widget _line(_Barrage entry, double width, double fontSize, double opacity) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: width * 0.62),
    child: Text(
      widget.showSender && entry.message.effectiveSender.userName.isNotEmpty
          ? '${entry.message.effectiveSender.userName}  ${entry.message.text}'
          : entry.message.text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: _readable(entry.message.effectiveColor).withValues(alpha: opacity),
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        shadows: const [Shadow(color: Colors.black87, blurRadius: 3, offset: Offset(1, 1))],
      ),
    ),
  );

  /// Keeps the platform's colour legible over a video that is usually dark or
  /// busy: a near-black line is lifted toward white, everything else is used
  /// as the platform sent it.
  Color _readable(LiveMessageColor color) {
    final base = Color.fromARGB(255, color.r, color.g, color.b);
    final lifted = HSLColor.fromColor(base).withLightness(HSLColor.fromColor(base).lightness.clamp(0.62, 1)).toColor();
    return HSLColor.fromColor(base).lightness < 0.35 ? lifted : base;
  }
}
