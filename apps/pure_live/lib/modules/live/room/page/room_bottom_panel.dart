import 'dart:math' as math;
import 'dart:ui' show clampDouble;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

import 'package:pure_live/modules/live/room/page/room_glass_card.dart';

/// Which of the narrow room's three stops the panel opens at.
enum RoomPanelStop { minimum, middle, maximum }

/// The narrow room's arrangement, the reference's portrait panel: the picture
/// fills the window and the room's facts and chat ride over it on a sheet that
/// stops at three heights.
///
/// Three stops rather than a free drag because the room has two real questions —
/// "how is the stream" and "what are they saying" — and a panel that can rest
/// anywhere hands the viewer a third one to answer every time they move it. The
/// lowest stop is a fixed number of pixels instead of a fraction so a short
/// window still shows a readable line of chat and the composer; the highest
/// leaves a strip of picture free, because a sheet that covers the whole stream
/// is a chat page with a black border.
///
/// The picture is never resized by a drag: only the bars over it lift, and they
/// learn the panel's settled height through [onCoverChanged]. A stream's control
/// row therefore is never under the sheet, and the video is never rebuilt — or
/// re-buffered — because the viewer moved a panel.
final class RoomBottomPanel extends StatefulWidget {
  /// The panel over [picture].
  ///
  /// [handle] is what the handle row shows in its centre — a way into the room's
  /// own full screen on a phone; null draws the grip that says "drag me" to a
  /// pointer. [pill] is the row's trailing action, where a thumb reaches.
  const RoomBottomPanel({
    required this.picture,
    required this.panel,
    required this.preferred,
    this.handle,
    this.pill,
    this.onCoverChanged,
    super.key,
  });

  /// The layer under the panel, given the whole window.
  final Widget picture;

  /// What the panel carries: the room's facts and the chat column.
  final Widget panel;

  /// The stop the sheet opens at, and the one a resize falls back to.
  final RoomPanelStop preferred;

  /// The handle row's centre, or null for the grip.
  final Widget? handle;

  /// The handle row's trailing action.
  final Widget? pill;

  /// Says how much of the window the panel covers once it settles, so the
  /// picture's own bars can stand above it.
  final ValueChanged<double>? onCoverChanged;

  /// The lowest stop, in pixels: enough for a readable line of chat and the
  /// composer on any window that can show this layout at all.
  static const double least = 250;

  /// The free picture the highest stop leaves, in pixels.
  static const double freeFloor = 120;

  /// The handle row's height: the app's touch floor, so the grip is a hold a
  /// thumb lands on without aiming.
  static const double handleHeight = 48;

  /// A flick at least this fast (pixels per second) decides the stop for the
  /// viewer instead of where the panel happened to be when the finger left.
  static const double fling = 600;

  @override
  State<RoomBottomPanel> createState() => _RoomBottomPanelState();
}

final class _RoomBottomPanelState extends State<RoomBottomPanel> with SingleTickerProviderStateMixin {
  late final AnimationController _offset = AnimationController.unbounded(vsync: this);
  bool _placed = false;

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  /// The window's three stops: the floor, the reading height, and the most a
  /// sheet may take of a live picture.
  ({double least, double middle, double greatest}) _stops(double area) {
    final least = math.min(RoomBottomPanel.least, area);
    final greatest = clampDouble(area * 0.68, least, math.max(least, area - RoomBottomPanel.freeFloor));
    final middle = clampDouble(area * 0.44, least, greatest);
    return (least: least, middle: middle, greatest: greatest);
  }

  double _stopOf(({double least, double middle, double greatest}) stops, RoomPanelStop stop) => switch (stop) {
    RoomPanelStop.minimum => stops.least,
    RoomPanelStop.middle => stops.middle,
    RoomPanelStop.maximum => stops.greatest,
  };

  /// The nearest stop, with a fling taking precedence over position: a viewer
  /// who throws the sheet up means the biggest stop even if it only crossed the
  /// halfway mark on the way.
  double _target(double from, double velocityY, ({double least, double middle, double greatest}) stops) {
    final candidates = [stops.least, stops.middle, stops.greatest];
    if (velocityY.abs() >= RoomBottomPanel.fling) {
      // Dragging up (a negative velocity) grows the panel.
      final rising = velocityY < 0;
      final ahead = candidates.where((stop) => rising ? stop > from : stop < from).toList();
      if (ahead.isNotEmpty) return rising ? ahead.first : ahead.last;
    }
    var best = candidates.first;
    for (final stop in candidates) {
      if ((stop - from).abs() < (best - from).abs()) best = stop;
    }
    return best;
  }

  void _settle(double target) {
    widget.onCoverChanged?.call(target);
    final motion = DsTheme.of(context).motion;
    final spring = motion.moveSpringOrNull;
    if (spring == null) {
      // The system's own reduce-motion: the height jumps; the choice of stop
      // still stands.
      _offset.value = target;
      return;
    }
    _offset.animateTo(target, duration: spring.settleDuration, curve: motion.moveCurve);
  }

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final area = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : (constraints.maxWidth.isFinite ? constraints.maxWidth * 2 : RoomBottomPanel.least * 3);
        final stops = _stops(area);
        if (!_placed) {
          _placed = true;
          _offset.value = _stopOf(stops, widget.preferred);
          // The host keeps the cover height in its own state, so the first
          // report waits for this frame to finish building.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onCoverChanged?.call(_offset.value);
          });
        } else if (_offset.value < stops.least || _offset.value > stops.greatest) {
          // A rotation, a keyboard or a window resize moved the stops under the
          // panel; it goes to the edge it left rather than hanging over black.
          _offset.value = clampDouble(_offset.value, stops.least, stops.greatest);
          widget.onCoverChanged?.call(_offset.value);
        }
        return AnimatedBuilder(
          animation: _offset,
          builder: (context, _) => Stack(
            fit: StackFit.expand,
            children: [
              widget.picture,
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: _offset.value,
                child: GestureDetector(
                  onVerticalDragUpdate: (details) =>
                      _offset.value = clampDouble(_offset.value - details.delta.dy, stops.least, stops.greatest),
                  onVerticalDragEnd: (details) => _settle(_target(_offset.value, details.primaryVelocity ?? 0, stops)),
                  child: RoomGlassCard(
                    topOnly: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: RoomBottomPanel.handleHeight,
                          child: Stack(
                            children: [
                              widget.handle ??
                                  Container(
                                    width: 38,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: colors.textMuted.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                              if (widget.pill case final pill?)
                                PositionedDirectional(
                                  top: 0,
                                  bottom: 0,
                                  end: DsSpace.s8,
                                  child: Center(child: pill),
                                ),
                            ],
                          ),
                        ),
                        Expanded(child: widget.panel),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
