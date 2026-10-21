import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_interaction/live_interaction.dart' show InteractionSession;
import 'package:live_sites/live_sites.dart';
import 'package:pure_live/features/room/danmaku_fps.dart' show displayRefreshRateProvider, resolvedDanmakuFps;
import 'package:pure_live/features/room/local/local_catalog.dart';
import 'package:pure_live/features/room/room_controller.dart' show roomControllerProvider;
import 'package:pure_live/features/room/room_providers.dart';
import 'package:pure_live/features/room/widgets/room_emote_text.dart';
import 'package:pure_live/features/room/widgets/room_message_actions.dart' show showRoomMessageActions;
import 'package:pure_live/system/configuration/app_preferences.dart';
import 'package:pure_live/system/configuration/app_preferences_providers.dart';

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

/// The lane budget and travel clock the surface computes from the settings —
/// broken out so the geometry is testable without pumping the animation.
final class BarrageGeometry {
  /// From the stored answers and the box the video gets.
  const new({
    required this.preferences,
    required this.width,
    required this.height,
    this.laneCap = 0,
    this.areaOverride,
    this.fps = 0,
  });

  /// The stored answers the geometry reads.
  final AppPreferences preferences;

  /// The width of the picture.
  final double width;

  /// The height of the picture.
  final double height;

  /// A caller's own row limit (the TV, the tall portrait panel); 0 takes the
  /// full band the display area allows.
  final int laneCap;

  /// A caller's own share of the picture (the portrait page's 顶部 25%
  /// barrage rule); null takes the stored 显示范围.
  final double? areaOverride;

  /// The frame rate in use, resolved by [resolvedDanmakuFps] from the
  /// automatic clock and the display; 0 falls back to the stored number.
  final int fps;

  static const _minLanes = 1;
  static const _maxLanes = 16;

  /// The pixels a new line keeps between itself and the tail of the line in
  /// front of it.
  static const rowGapPixels = 24.0;

  /// The lowest pixel the flying band may use.
  double get bandBottom => _bandBottom;

  /// The vertical pitch of one row.
  double get laneHeight => fontSize * 1.6;

  /// The text size in force — the caller's pin first, then the setting.
  double get fontSize => preferences.barrageFontSize;

  /// The band the barrage may fly in: the configured share of the picture,
  /// squeezed by the pixel margins kept free at both edges.
  double get _bandBottom {
    final top = _top;
    final area = areaOverride ?? preferences.barrageArea;
    final usable = ((height - preferences.barrageBottomArea - top) * area.clamp(0.1, 1)).floorToDouble();
    return top + usable.clamp(laneHeight, height - top);
  }

  double get _top => 8 + preferences.barrageTopArea;

  /// How many rows fit the band.
  int get lanes {
    final budget = ((_bandBottom - _top) / laneHeight).floor().clamp(_minLanes, _maxLanes);
    return laneCap > 0 ? budget.clamp(_minLanes, laneCap) : budget;
  }

  /// Where row [row] draws, in the band's pixel space.
  double topOf(int row) => _top + row * laneHeight;

  /// How long a message of [message]'s length takes to cross the picture at the configured px/s speed: its own
  /// estimated width plus the screen, so long lines are not faster than short
  /// ones (3.x's `danmakuSpeed` arithmetic).
  double secondsFor(LiveMessage message) {
    final estimated = estimatedWidth(message);
    return ((width + estimated) / _pixelsPerSecond).clamp(2, 60).toDouble();
  }

  /// The text's own width. The drawn string is the sender plus the message, cut
  /// at the line's cap, and a CJK glyph takes a whole em where a latin one takes
  /// about half: `length * 0.62` under-counted a Chinese room by half, so a row
  /// was called free while the line in front still covered the entry edge.
  double estimatedWidth(LiveMessage message) {
    final name = preferences.barrageShowSender ? message.effectiveSender.userName.trim() : '';
    final drawn = name.isEmpty ? message.text : '$name  ${message.text}';
    var ems = 0.0;
    for (final rune in drawn.runes) {
      ems += rune >= 0x2e80 ? 1.0 : 0.55;
    }
    return math.min(ems * fontSize, width * 0.62);
  }

  /// How long a row must wait before another line may enter it: the previous
  /// line's width plus the gap, crossed at the configured speed. A fixed slice
  /// of clock time says nothing about a line that takes seconds to cross, so a
  /// busy room stacked two and three lines into one row.
  Duration entryClearance(LiveMessage message) =>
      Duration(milliseconds: ((estimatedWidth(message) + rowGapPixels) / _pixelsPerSecond * 1000).round());

  double get _pixelsPerSecond => preferences.barrageSpeed.clamp(20, 400);

  /// How many lines may fly at once (the reference's `danmakuMaxVisibleCount`).
  int get maxLive => preferences.barrageMaxVisible.clamp(10, 120);

  /// The repaint clock: manual frame rate, 25..240 FPS; a resolved
  /// automatic rate ([fps]) wins over the stored number.
  Duration get frameInterval =>
      Duration(microseconds: (1000000 / (fps > 0 ? fps : preferences.barrageFps).clamp(25, 240)).round());
}

/// The danmaku drawn over the video — the reference's `PlayerDanmakuSurface`.
///
/// The scroll rows carry the traffic and a pinned band under the top edge
/// catches a burst that found every row busy. A message that cannot fit is
/// dropped rather than queued: a backlog would replay the room when the phone
/// is turned back, which is not what a barrage is for. Every answering knob —
/// area, margins, speed, size, weight, stroke, the same-screen cap, the frame
/// rate, the sender name, the paused behaviour and hold-on-press — reads the
/// shared barrage settings and applies live (the reference's 改动立即生效).
final class RoomBarrageOverlay extends ConsumerStatefulWidget {
  /// A barrage over [identity]'s video.
  const new({required this.identity, this.laneCap = 0, this.fontSize, this.areaOverride, super.key});

  /// The room whose messages are drawn.
  final RoomIdentity identity;

  /// A caller's row limit (the TV keeps fewer, larger rows); 0 for none.
  final int laneCap;

  /// The text size; null takes the barrage size from settings — a TV passes an
  /// explicit one for the 10-foot view.
  final double? fontSize;

  /// The portrait page's band rule (竖屏弹幕布局 顶部 25%); null follows the
  /// stored display area.
  final double? areaOverride;

  @override
  ConsumerState<RoomBarrageOverlay> createState() => _RoomBarrageOverlayState();
}

final class _RoomBarrageOverlayState extends ConsumerState<RoomBarrageOverlay> with SingleTickerProviderStateMixin {
  /// How long a pinned line stays.
  static const _pinnedSeconds = 5.0;

  late final AnimationController _ticker = AnimationController(vsync: this, duration: const Duration(milliseconds: 33))
    ..repeat();

  final List<_Barrage> _live = [];
  StreamSubscription<LiveMessage>? _sub;
  StreamSubscription<LiveMessage>? _busSub;
  int _cursor = 0;

  /// The freeze bookkeeping shared by the paused behaviour and
  /// hold-on-press: every held span is taken off a line's age, so resuming
  /// continues the crossing where it stopped instead of teleporting.
  Duration _held = Duration.zero;
  DateTime? _holdSince;

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

  /// The barrage answers of the last built frame, for messages that arrive
  /// between two frames (the gift gate below is one of them).
  AppPreferences? _preferences;

  void _onMessage(LiveMessage message) {
    final chat = message.type == LiveMessageType.chat;
    final gift = message.type == LiveMessageType.gift && (_preferences?.barrageShowGifts ?? false);
    final geometry = _measured;
    if ((!chat && !gift) || message.text.isEmpty || !mounted || geometry == null) {
      return;
    }
    setState(() {
      if (_live.length >= geometry.maxLive) {
        _live.removeAt(0);
      }
      final row = _freeRow(geometry);
      _live.add(_Barrage(message: message, row: row ?? -1, pinned: row == null, startedAt: DateTime.now()));
    });
  }

  /// The band geometry of the last built frame. Null before the first frame:
  /// with no measured picture there is no band to fly a line in.
  BarrageGeometry? _measured;

  /// The scroll row whose last line has cleared the entry edge, or null when
  /// every row is still busy.
  int? _freeRow(BarrageGeometry geometry) {
    final now = DateTime.now();
    for (var offset = 0; offset < geometry.lanes; offset++) {
      final row = (_cursor + offset) % geometry.lanes;
      _Barrage? last;
      for (final entry in _live) {
        if (!entry.pinned && entry.row == row) {
          last = entry;
        }
      }
      if (last == null || now.difference(last.startedAt) - _held >= geometry.entryClearance(last.message)) {
        _cursor = (row + 1) % geometry.lanes;
        return row;
      }
    }
    return null;
  }

  /// The freeze clock: held spans (video paused with the pause behaviour on,
  /// or the finger holding the picture) stop a line's age from growing.
  void _setHeld(bool holding) {
    final now = DateTime.now();
    if (holding) {
      _holdSince ??= now;
      return;
    }
    final since = _holdSince;
    if (since != null) {
      _held += now.difference(since);
      _holdSince = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(appPreferencesProvider);
    final paused = ref.watch(roomControllerProvider(widget.identity).select((state) => state.paused));
    final rate = ref.watch(displayRefreshRateProvider).value;
    _preferences = preferences;
    final hold = preferences.barrageHoldOnPress;
    final tap = preferences.barrageTapAction;
    final longPress = preferences.barrageLongPressAction;
    _setHeld((paused && preferences.barragePausedBehavior == 'pause') || _fingerHeld || _actionsHeld);
    return LayoutBuilder(
      builder: (context, constraints) {
        final geometry = BarrageGeometry(
          preferences: _withCallerFont(preferences),
          areaOverride: widget.areaOverride,
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          laneCap: widget.laneCap,
          fps: resolvedDanmakuFps(
            automatic: preferences.barrageAutoFps,
            configured: preferences.barrageFps,
            mode: preferences.barrageFpsMode,
            maxHz: rate?.maxHz,
            currentHz: rate?.currentHz,
          ),
        );
        _measured = geometry;
        if (_ticker.duration != geometry.frameInterval) {
          _ticker.duration = geometry.frameInterval;
        }
        return Listener(
          // Hold-on-press needs the picture to answer the finger; the lines
          // themselves answer it only when the tap or the long-press switch
          // is on — otherwise the barrage stays click-through (the
          // reference's rule: the danmaku never steals a tap from the
          // video's own controls).
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) {
            if (hold) {
              setState(() => _fingerHeld = true);
            }
          },
          onPointerUp: (_) {
            if (hold) {
              setState(() => _fingerHeld = false);
            }
          },
          onPointerCancel: (_) {
            if (hold) {
              setState(() => _fingerHeld = false);
            }
          },
          child: IgnorePointer(
            ignoring: !(tap || longPress),
            child: AnimatedBuilder(animation: _ticker, builder: (context, _) => _paint(context, geometry, preferences)),
          ),
        );
      },
    );
  }

  bool _fingerHeld = false;

  /// Whether the message-actions sheet is open: the reference stands the
  /// barrage while it is read (3.x paused the barrage until the sheet closed).
  bool _actionsHeld = false;

  /// Opens the sheet of the line that was hit, and stands the barrage while
  /// it is up.
  Future<void> _openActions(LiveMessage message) async {
    if (!mounted || _actionsHeld) {
      return;
    }
    setState(() => _actionsHeld = true);
    try {
      await showRoomMessageActions(context, ref, message, identity: widget.identity, onBlockedUser: _purgeUser);
    } finally {
      if (mounted) {
        setState(() => _actionsHeld = false);
      }
    }
  }

  /// A blocked viewer's lines already in flight leave at once — the block
  /// bites without waiting for the next reconnect.
  void _purgeUser(String name) {
    if (!mounted) {
      return;
    }
    final needle = name.trim().toLowerCase();
    setState(() => _live.removeWhere((entry) => entry.message.effectiveSender.userName.trim().toLowerCase() == needle));
  }

  /// A caller that pinned a text size (the TV) keeps its own; everything else
  /// comes from the shared settings.
  AppPreferences _withCallerFont(AppPreferences preferences) =>
      widget.fontSize == null ? preferences : preferences.copyWith(barrageFontSize: widget.fontSize);

  Widget _paint(BuildContext context, BarrageGeometry geometry, AppPreferences preferences) {
    final width = geometry.width;
    final now = DateTime.now();
    final fontSize = geometry.fontSize;
    final opacity = preferences.barrageOpacity.clamp(0.2, 1.0);
    // Entries leave on the frame after they clear rather than on their own
    // timers: a paused app does not tick, and a queue would then grow until
    // the video is unreadable.
    _live.removeWhere(
      (entry) => _elapsed(entry, now) >= (entry.pinned ? _pinnedSeconds : geometry.secondsFor(entry.message)),
    );
    final pinned = _live.where((entry) => entry.pinned).toList(growable: false);
    // Only the rows the picture still has below the flying band answer; the rest
    // of a burst is dropped, which is what a barrage is for.
    final pinnedCount = math.min(
      pinned.length,
      ((geometry.height - geometry.bandBottom - 8) / geometry.laneHeight).floor().clamp(0, 4),
    );
    return ClipRect(
      child: Stack(
        children: [
          for (var index = 0; index < pinnedCount; index++)
            Positioned(
              left: 12,
              // The overflow band sits under the flying one. Pinned lines used
              // to take rows from the same ladder the traffic flies in, so a
              // busy room drew three lines on top of each other.
              top: geometry.bandBottom + 8 + index * geometry.laneHeight,
              child: _line(pinned[index], width, fontSize, opacity, preferences),
            ),
          for (final entry in _live)
            if (!entry.pinned)
              Positioned(
                left: width - _travel(entry, now, geometry),
                top: geometry.topOf(entry.row % geometry.lanes),
                child: _line(entry, width, fontSize, opacity, preferences),
              ),
        ],
      ),
    );
  }

  double _elapsed(_Barrage entry, DateTime now) => (now.difference(entry.startedAt) - _held).inMilliseconds / 1000.0;

  /// How far the line has travelled: from just off the right edge to just off
  /// the left one, so the exit is as smooth as the entry.
  double _travel(_Barrage entry, DateTime now, BarrageGeometry geometry) {
    final progress = (_elapsed(entry, now) / geometry.secondsFor(entry.message)).clamp(0.0, 1.0);
    final estimated = entry.message.text.length * geometry.fontSize * 0.62;
    return progress * (geometry.width + estimated);
  }

  Widget _line(_Barrage entry, double width, double fontSize, double opacity, AppPreferences preferences) {
    final family = preferences.barrageFontFamily.trim();
    final tap = preferences.barrageTapAction;
    final longPress = preferences.barrageLongPressAction;
    // The viewer's own line wears the local preset; everyone else keeps the
    // shared barrage settings.
    final preset = entry.message.isLocal ? LocalCatalog.presetOf(preferences.localInteractionPreset) : null;
    final stroke = preset == null ? preferences.barrageStroke : preset.strokeWidth > 0;
    final strokeWidth = preset == null ? preferences.barrageStrokeWidth : preset.strokeWidth;
    final lineStyle = TextStyle(
      color: preset == null
          ? _readable(entry.message.effectiveColor).withValues(alpha: opacity)
          : Color(preset.color).withValues(alpha: opacity),
      fontSize: preset?.fontSize ?? fontSize,
      fontFamily: family.isEmpty ? null : family,
      fontWeight: FontWeight((preset?.fontWeight ?? preferences.barrageFontWeight).clamp(100, 900)),
      letterSpacing: preset?.letterSpacing,
      shadows: stroke
          ? [Shadow(color: Colors.black87, blurRadius: strokeWidth.clamp(0, 4), offset: const Offset(1, 1))]
          : const [],
    );
    final line = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width * 0.62),
      child: Text.rich(
        // The表情码 become the platform's own pictures, inline; the text keeps
        // the stroke and the colour because the spans carry this style.
        TextSpan(
          children: emoteSpans(
            text: preferences.barrageShowSender && entry.message.effectiveSender.userName.isNotEmpty
                ? '${entry.message.effectiveSender.userName}  ${entry.message.text}'
                : entry.message.text,
            emotes: entry.message.emotes,
            style: lineStyle,
          ),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    if (!tap && !longPress) {
      return line;
    }
    // A line answers the finger only with its own switch on; the hit area is
    // the line, so a tap on empty picture still reaches the video controls.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: tap ? () => unawaited(_openActions(entry.message)) : null,
      onLongPress: longPress ? () => unawaited(_openActions(entry.message)) : null,
      child: line,
    );
  }

  /// Keeps the platform's colour legible over a video that is usually dark or
  /// busy: a near-black line is lifted toward white, everything else is used
  /// as the platform sent it.
  Color _readable(LiveMessageColor color) {
    final base = Color.fromARGB(255, color.r, color.g, color.b);
    final lifted = HSLColor.fromColor(base).withLightness(HSLColor.fromColor(base).lightness.clamp(0.62, 1)).toColor();
    return HSLColor.fromColor(base).lightness < 0.35 ? lifted : base;
  }
}
