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
///
/// Pulled under its lowest stop the sheet resists, with the reference's rubber
/// band, and a release far enough down — or a downward flick — carries it on
/// out of the window and hands the room to its portrait full screen through
/// [onPortraitFullscreen], the verb the handle row's button carries. The
/// resistance is what tells a finger that only meant the lowest stop it has
/// gone past the end; let go short of the threshold, the sheet springs back.
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
    this.onPortraitFullscreen,
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

  /// Enters the room's portrait full screen when the sheet is pulled past its
  /// lowest stop and let go; null where the room has none (a pointer's
  /// window), and the sheet then only springs back to that stop.
  final VoidCallback? onPortraitFullscreen;

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

  /// A downward flick at least this fast (pixels per second) under the lowest
  /// stop enters the portrait full screen, once the finger has pulled
  /// [fullscreenFlingDistance] past that stop (the reference's 900 and 28): a
  /// throw means "away", even before the pull alone would.
  static const double fullscreenFling = 900;

  /// How far under the lowest stop a flick has to have pulled first, so a
  /// quick settle onto that stop is never read as a throw past it.
  static const double fullscreenFlingDistance = 28;

  /// The window's three stops: the floor, the reading height, and the most a
  /// panel may take of a live picture.
  static RoomPanelStops stopsOf(double area) {
    final least = math.min(RoomBottomPanel.least, area);
    final greatest = clampDouble(area * 0.68, least, math.max(least, area - RoomBottomPanel.freeFloor));
    final middle = clampDouble(area * 0.44, least, greatest);
    return (least: least, middle: middle, greatest: greatest);
  }

  /// The height of one [stop] within [stops].
  static double stopOf(RoomPanelStops stops, RoomPanelStop stop) => switch (stop) {
    RoomPanelStop.minimum => stops.least,
    RoomPanelStop.middle => stops.middle,
    RoomPanelStop.maximum => stops.greatest,
  };

  /// The nearest stop, with a fling taking precedence over position: a viewer
  /// who throws the panel up means the biggest stop even if it only crossed
  /// the halfway mark on the way.
  static double nearestStop(double from, double velocityY, RoomPanelStops stops) {
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

  /// Whether a release [dismissed] under the lowest stop enters the portrait
  /// full screen (the reference's `panelDragEntersFullscreen`): 30 % of the
  /// panel's height, kept between 72 and 144 px, or a downward flick of
  /// [RoomBottomPanel.fullscreenFling] once [RoomBottomPanel.fullscreenFlingDistance]
  /// is behind it.
  static bool entersFullscreen({required double dismissed, required double panel, required double velocity}) {
    if (dismissed <= 0 || panel <= 0) return false;
    final distance = clampDouble(panel * 0.3, 72, 144);
    return dismissed >= distance ||
        (velocity >= RoomBottomPanel.fullscreenFling && dismissed >= RoomBottomPanel.fullscreenFlingDistance);
  }

  @override
  State<RoomBottomPanel> createState() => _RoomBottomPanelState();
}

/// The window's three stops, lowest first. Both narrow hosts read their
/// geometry from [RoomBottomPanel.stopsOf]: the sheet over a portrait stream
/// and the compact room's docked panel are the same three questions.
typedef RoomPanelStops = ({double least, double middle, double greatest});

final class _RoomBottomPanelState extends State<RoomBottomPanel> with SingleTickerProviderStateMixin {
  /// Where the sheet's top stands above the window's bottom edge: its height
  /// between the stops. Under the lowest one the sheet keeps that stop's height
  /// and slides down past the edge instead, so its chat is never squeezed into
  /// a strip on the way out.
  late final AnimationController _offset = AnimationController.unbounded(vsync: this);
  bool _placed = false;

  /// Where the finger has taken the sheet's top, before the band under the
  /// lowest stop: the band moves the sheet less than the finger, and the way
  /// into the portrait full screen is read off the finger's own travel — a
  /// band that gives at most a third of the stop could never show the
  /// threshold on a short window.
  double _drag = 0;
  bool _dragging = false;

  /// The sheet is on its way out under the window's edge, with the portrait
  /// full screen to follow: no drag catches it and no resize moves it meanwhile.
  bool _entering = false;

  /// Where the sheet's top goes on its way out: under the window's bottom
  /// edge by a little more than its glass's own shadow (the reference's 36).
  static const double _outOfSight = -36;

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  /// The window's three stops: the floor, the reading height, and the most a
  /// sheet may take of a live picture.
  RoomPanelStops _stops(double area) => RoomBottomPanel.stopsOf(area);

  double _stopOf(RoomPanelStops stops, RoomPanelStop stop) => RoomBottomPanel.stopOf(stops, stop);

  /// The nearest stop, with a fling taking precedence over position: a viewer
  /// who throws the sheet up means the biggest stop even if it only crossed the
  /// halfway mark on the way.
  double _target(double from, double velocityY, RoomPanelStops stops) =>
      RoomBottomPanel.nearestStop(from, velocityY, stops);

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

  /// Where a finger at [drag] shows the sheet's top: one to one between the
  /// stops, and under the lowest one with a resistance that grows the further
  /// it goes — at most a third of that stop's height.
  double _banded(double drag, RoomPanelStops stops) =>
      drag < stops.least ? stops.least + _rubberBand(drag - stops.least, stops.least) : drag;

  /// The finger [_banded] shows at [top]: where a drag that catches the sheet
  /// on its way back carries on from, without a jump.
  double _unbanded(double top, RoomPanelStops stops) =>
      top < stops.least ? stops.least + _rubberBandDrag(top - stops.least, stops.least) : top;

  /// A finger takes the sheet, from wherever it is: one that lands on a sheet
  /// still settling stops it there rather than fighting the spring.
  void _started(RoomPanelStops stops) {
    if (_entering) return;
    _offset.stop();
    _dragging = true;
    _drag = _unbanded(_offset.value, stops);
  }

  /// Up to the highest stop and no further, since that stop's strip of free
  /// picture is the point of it; down as far as the finger goes, the band
  /// taking over under the lowest stop.
  void _dragged(DragUpdateDetails details, RoomPanelStops stops) {
    if (!_dragging) return;
    _drag = clampDouble(_drag - details.delta.dy, 0, stops.greatest);
    _offset.value = _banded(_drag, stops);
  }

  /// The finger left: far enough under the lowest stop, the portrait full
  /// screen; anywhere else, the stop the release points at.
  void _released(DragEndDetails details, RoomPanelStops stops) {
    if (!_dragging) return;
    _dragging = false;
    // Downwards positive: the direction that shrinks the sheet.
    final velocity = details.primaryVelocity ?? 0;
    if (widget.onPortraitFullscreen != null &&
        RoomBottomPanel.entersFullscreen(dismissed: stops.least - _drag, panel: stops.least, velocity: velocity)) {
      _enter(stops);
      return;
    }
    _settle(_target(clampDouble(_offset.value, stops.least, stops.greatest), velocity, stops));
  }

  /// A drag the system took back settles where it stands.
  void _cancelled(RoomPanelStops stops) {
    if (!_dragging) return;
    _dragging = false;
    _settle(_target(clampDouble(_offset.value, stops.least, stops.greatest), 0, stops));
  }

  /// Carries the pull on out of the window, then hands the room to its portrait
  /// full screen: the sheet leaves the way the finger was taking it, and the
  /// page's own swap comes once it is out of sight instead of under a sheet
  /// still on screen. The cover is not reported on the way: the page that takes
  /// the window lays its picture out without one, and the sheet it brings back
  /// later reports its own stop.
  void _enter(RoomPanelStops stops) {
    _entering = true;
    final motion = DsTheme.of(context).motion;
    final spring = motion.moveSpringOrNull;
    if (spring == null) {
      _offset.value = _outOfSight;
      _entered(stops);
      return;
    }
    _offset
        .animateTo(_outOfSight, duration: spring.settleDuration, curve: motion.moveCurve)
        .whenCompleteOrCancel(() => _entered(stops));
  }

  /// The sheet is out: the portrait full screen takes the window. The page
  /// swaps this layout away in the frame that follows, so the sheet only comes
  /// back if it is still here once that frame is drawn — the room kept its
  /// inline layout after all.
  void _entered(RoomPanelStops stops) {
    if (!_entering || !mounted) return;
    _entering = false;
    widget.onPortraitFullscreen?.call();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_dragging && _offset.value < stops.least) _settle(stops.least);
    });
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
        } else if (!_dragging && !_entering) {
          // A rotation, a keyboard or a window resize moved the stops under the
          // panel; it goes to the edge it left rather than hanging over black.
          // A sheet springing back from under its lowest stop is already on its
          // way there, and a finger or the way out owns the sheet meanwhile.
          final top = _offset.value;
          if (top > stops.greatest || (top < stops.least && !_offset.isAnimating)) {
            _offset.value = clampDouble(top, stops.least, stops.greatest);
            widget.onCoverChanged?.call(_offset.value);
          }
        }
        // Built once per layout rather than per tick: a drag moves the sheet,
        // never what is on it.
        final sheet = GestureDetector(
          onVerticalDragStart: (_) => _started(stops),
          onVerticalDragUpdate: (details) => _dragged(details, stops),
          onVerticalDragEnd: (details) => _released(details, stops),
          onVerticalDragCancel: () => _cancelled(stops),
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
        );
        return AnimatedBuilder(
          animation: _offset,
          child: sheet,
          builder: (context, sheet) {
            final top = _offset.value;
            return Stack(
              fit: StackFit.expand,
              children: [
                widget.picture,
                Positioned(
                  left: 0,
                  right: 0,
                  // Under the lowest stop the sheet keeps that stop's height
                  // and slides down past the window's edge.
                  bottom: math.min<double>(0, top - stops.least),
                  height: math.max(top, stops.least),
                  child: sheet!,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// How far something pulled [overscroll] past its edge moves, in a space
/// [extent] long — the reference's rubber band (HyperOS's): R·(x − x² + x³/3)
/// with x = overscroll ÷ R, heavier the further it goes and at most R/3.
double _rubberBand(double overscroll, double extent) {
  if (extent <= 0 || overscroll == 0) return 0;
  final x = math.min<double>(overscroll.abs() / extent, 1);
  return overscroll.sign * extent * (x - x * x + x * x * x / 3);
}

/// The pull [_rubberBand] shows as [shown]: d = R/3 · (1 − (1 − x)³), so
/// x = 1 − ∛(1 − 3d/R).
double _rubberBandDrag(double shown, double extent) {
  if (extent <= 0 || shown == 0) return 0;
  final rest = math.max(0, 1 - 3 * shown.abs() / extent).toDouble();
  return shown.sign * extent * (1 - math.pow(rest, 1 / 3).toDouble());
}
