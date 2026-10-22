import 'dart:math' show cos, pi, sin;
import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:pure_uikit/src/scales/radii.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// A marquee for work of unknown length: the indeterminate
/// bar, filling whatever box it is given. [PureProgress] is the control; this is
/// the one call that always wants the running shape and never a fraction, so it
/// carries nothing but the thickness the kit's densest scale asks for.
class LinearIndeterminate extends StatelessWidget {
  /// An indeterminate bar.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    return SizedBox.expand(child: PureProgress(value: null, height: theme.token.scale.sizes.xs));
  }
}

/// Which of the two progress shapes a [PureProgress] draws.
///
/// Both shapes exist: a bar for work with a measurable length and a ring for
/// work without one. The style — the WinUI dot chase, the sliding segment —
/// comes from the language; this decides which of the two the call site wants,
/// so a page can put a spinner where a bar would still show a fraction.
enum PureProgressShape {
  /// A horizontal track with the fill running along it.
  linear,

  /// A ring: a determinate arc, or the spinner for unknown work.
  circular,
}

/// The kit's progress: one widget that draws the real shape of the control in
/// the WinUI grammar — the ring of four dots that chase each other around the
/// circle over the 3px rail whose third-of-a-track segment eases across and
/// leaves. All of it is painted here, from the theme's own tokens — colours,
/// radii and motion. Drawn once, one contract holds everywhere: a null `value`
/// is the repeating animation, `UiConfig.animations: false` stills it on a
/// resting pose instead of freezing a frame, the controller is released when
/// the bar leaves the tree, and a screen reader hears the same `progressBar`
/// value.
class PureProgress extends StatelessWidget {
  /// A progress indicator at [value] (0..1), or an indeterminate one when it is
  /// null.
  const new({
    required this.value,
    this.height,
    this.shape = PureProgressShape.linear,
    this.size,
    this.showLabel = false,
    this.barColor,
    this.trackColor,
    this.semanticLabel,
    super.key,
  });

  /// The completion fraction, or null for indeterminate — the two states the
  /// shape answers to.
  final double? value;

  /// The linear track's thickness, or null to keep the language's own: 3 for
  /// WinUI's rail. Ignored by the [PureProgressShape.circular] shape, whose
  /// ring stroke is the language's own.
  final double? height;

  /// The shape. [PureProgressShape.linear] is the default, so a bar stays a
  /// bar; [PureProgressShape.circular] asks for the ring.
  final PureProgressShape shape;

  /// The ring's diameter, or null to keep the language's own: 32. Ignored by
  /// the linear shape.
  final double? size;

  /// Whether to show the percentage. A linear bar answers with a trailing label
  /// and a ring with its own centred one; a spinner has no percentage to name,
  /// so the label waits for a [value].
  final bool showLabel;

  /// An optional fill colour override.
  final Color? barColor;

  /// An optional groove colour override.
  final Color? trackColor;

  /// The name a screen reader reads beside the value; a bar with no text of its
  /// own is otherwise announced as a bare percentage.
  final String? semanticLabel;

  /// The geometry, colours and motion the shape is drawn with.
  _ProgressVisual _visual(PureTheme theme) {
    final palette = _ProgressPalette(theme: theme, thickness: height, diameter: size);
    return _ProgressVisual.fluent(palette);
  }

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final language = theme.config.language;
    final visual = _visual(theme);
    final fraction = value?.clamp(0.0, 1.0);

    final bar = _ProgressCore(
      // The branch a language draws is its identity in tests and diagnostics.
      key: ValueKey('PureProgress.${language.name}'),
      visual: visual,
      shape: shape,
      fraction: fraction,
      // The kit's own reduced-motion contract: `animations: false` stills the
      // loop, and the token ladder has already zeroed every duration with it.
      animate: theme.config.animations,
      cycle: visual.cycle,
      fillOverride: barColor,
      trackOverride: trackColor,
    );
    return Semantics(
      container: true,
      // The two states the control is defined by, in the two roles a screen
      // reader already knows: a bar with a value, a spinner without one.
      role: fraction == null ? SemanticsRole.loadingSpinner : SemanticsRole.progressBar,
      label: semanticLabel,
      value: fraction == null ? null : '${(fraction * 100).round()}',
      minValue: fraction == null ? null : '0',
      maxValue: fraction == null ? null : '100',
      // The percentage a labelled bar prints is the same number this node
      // already carries; hiding the text keeps it from being read twice.
      excludeSemantics: true,
      child: _labelled(theme, visual, bar, fraction),
    );
  }

  /// The shape, plus the percentage where [showLabel] asks for one and the
  /// fraction is known. A bar takes the label beside it in the secondary text
  /// role; a ring wears it in its own centre, over the surface rather than the
  /// fill, so it reads in the primary role.
  Widget _labelled(PureTheme theme, _ProgressVisual visual, Widget bar, double? fraction) {
    if (!showLabel || fraction == null) {
      return bar;
    }
    final percentage = '${(fraction * 100).round()}%';
    if (shape == PureProgressShape.circular) {
      final dimension = size ?? visual.diameter;
      // The ring's centre is the label's whole box; a diameter too small for the
      // caption keeps the number beside the ring instead of over the arc.
      if (dimension < 40) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            bar,
            SizedBox(width: theme.token.scale.sizes.sm),
            Text(percentage, style: theme.text.caption.copyWith(color: theme.colors.textSecondary)),
          ],
        );
      }
      return Stack(
        alignment: AlignmentDirectional.center,
        children: [
          SizedBox.square(dimension: dimension, child: bar),
          Text(percentage, style: theme.text.caption.copyWith(color: theme.colors.text)),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: bar),
        SizedBox(width: theme.token.scale.sizes.sm),
        Text(percentage, style: theme.text.caption.copyWith(color: theme.colors.textSecondary)),
      ],
    );
  }
}

/// What the shape is measured against: the theme it reads its colours
/// from, and the two sizes the call site may override.
@immutable
final class _ProgressPalette {
  /// A palette.
  const new({required this.theme, required this.thickness, required this.diameter});

  /// The resolved theme.
  final PureTheme theme;

  /// The caller's thickness, or null for the language's own.
  final double? thickness;

  /// The caller's ring diameter, or null for the language's own.
  final double? diameter;
}

/// The geometry, colours and motion the progress shape is drawn with.
/// Everything is resolved from the theme when the bar builds, so a dark switch
/// and the user's motion settings all come out of the same tokens the kit's
/// other controls read.
@immutable
final class _ProgressVisual {
  /// A progress visual.
  const new({
    required this.linearThickness,
    required this.diameter,
    required this.stroke,
    required this.radius,
    required this.cap,
    required this.track,
    required this.fill,
    required this.cycle,
    required this.linear,
    required this.circular,
  });

  /// WinUI: the ring of four dots that chase each other around the circle —
  /// every dot on the same turn a beat behind the one ahead, so the ring gathers
  /// and stretches — over the 3px rail whose third-of-a-track segment eases
  /// across and leaves.
  factory fluent(_ProgressPalette palette) {
    final theme = palette.theme;
    final radius = BorderRadius.circular(PureRadii.pill);
    return _ProgressVisual(
      linearThickness: palette.thickness ?? 3,
      diameter: palette.diameter ?? 32,
      stroke: 3,
      radius: radius,
      cap: StrokeCap.butt,
      track: theme.colors.fillTertiary,
      fill: theme.colors.primary,
      cycle: theme.token.motion.durationSlow * 6,
      linear: (args) => _BarPainter(
        track: args.track,
        fill: args.fill,
        fraction: args.fraction,
        tick: args.tick,
        radius: radius,
        phase: _BarLoop.slide,
      ),
      circular: (args) => args.fraction == null
          ? _DotPainter(fill: args.fill, count: 4, dotSize: 3.5, tick: args.tick)
          : _RingPainter(
              track: args.track,
              fill: args.fill,
              stroke: args.stroke,
              cap: args.cap,
              groove: false,
              fraction: args.fraction,
              tick: args.tick,
            ),
    );
  }

  /// The linear track's thickness before the call site overrides it.
  final double linearThickness;

  /// The ring's diameter before the call site overrides it.
  final double diameter;

  /// The ring's stroke.
  final double stroke;

  /// The linear track's corner radius; also the clip a frosted groove blurs
  /// inside.
  final BorderRadius radius;

  /// The cap the ring's arc ends are drawn with.
  final StrokeCap cap;

  /// The groove's colour.
  final Color track;

  /// The fill's colour: the accent the language draws a running bar in, and the
  /// colour a call site can override with [PureProgress.barColor].
  final Color fill;

  /// One full turn of the indeterminate loop. The language's own pacing, scaled
  /// off the motion ladder, so a reduced-motion config that zeroes every
  /// duration stills the bar instead of freezing it mid-turn.
  final Duration cycle;

  /// The bar's painter for this fraction and animation position.
  final _ShapePainter linear;

  /// The ring's painter for this fraction and animation position.
  final _ShapePainter circular;
}

/// The frame a painter draws in: the fraction (null for
/// unknown-length work), the position through one cycle of the loop, and what
/// this call resolved — the language's geometry and colours, or the caller's
/// override of the two colours.
@immutable
final class _ProgressArgs {
  /// A frame.
  const new({
    required this.fraction,
    required this.tick,
    required this.track,
    required this.fill,
    required this.stroke,
    required this.cap,
  });

  /// The completion fraction, or null for indeterminate.
  final double? fraction;

  /// The position through one cycle of the indeterminate loop.
  final double tick;

  /// The groove's colour.
  final Color track;

  /// The fill's colour.
  final Color fill;

  /// The ring's stroke.
  final double stroke;

  /// How the ring's arc ends are drawn.
  final StrokeCap cap;
}

/// A painter built from one frame of the loop.
typedef _ShapePainter = CustomPainter Function(_ProgressArgs args);

/// One stretch of an indeterminate bar: where it starts and how far it reaches,
/// both as fractions of the track's width, so the loop is two numbers
/// and not a pixel guess.
@immutable
final class _BarPhase {
  /// A phase.
  const new(this.start, this.extent);

  /// The offset from the track's left edge.
  final double start;

  /// The length along the track.
  final double extent;
}

/// The loop the indeterminate bar runs across its track: a third of the track
/// eases in from the left, runs the width and leaves from the right, so the bar
/// never reads as stalled.
abstract final class _BarLoop {
  /// The crossing segment.
  static _BarPhase slide(double tick) {
    final k = Curves.easeInOutSine.transform(tick);
    return _BarPhase(1.34 * k - 0.34, 0.34);
  }
}

/// The bar: the groove, and the fill wherever the loop puts it at
/// this frame. The fill is clipped to the groove, so a fraction of 1 and a
/// segment running off the edge both read as the track they were drawn on.
class _BarPainter extends CustomPainter {
  const new({
    required this.track,
    required this.fill,
    required this.radius,
    required this.tick,
    this.fraction,
    this.phase,
  });

  /// The groove's colour.
  final Color track;

  /// The fill's colour.
  final Color fill;

  /// The groove's corner radius.
  final BorderRadius radius;

  /// The completion fraction, or null for indeterminate.
  final double? fraction;

  /// The position through one cycle of the loop.
  final double tick;

  /// Where the loop puts the stretch at this frame.
  final _BarPhase Function(double tick)? phase;

  @override
  void paint(Canvas canvas, Size size) {
    final groove = radius.toRRect(Offset.zero & size);
    canvas.drawRRect(groove, Paint()..color = track);

    final fraction = this.fraction;
    final fill = fraction == null ? _loopRect(size) : Rect.fromLTWH(0, 0, size.width * fraction, size.height);
    if (fill.width <= 0) {
      return;
    }
    final cap = radius.toRRect(fill);
    canvas
      ..save()
      ..clipRRect(groove)
      ..drawRRect(cap, Paint()..color = this.fill)
      ..restore();
  }

  /// Where the loop puts the stretch at this frame.
  Rect _loopRect(Size size) {
    final loop = (phase ?? _BarLoop.slide)(tick);
    return Rect.fromLTWH(size.width * loop.start, 0, size.width * loop.extent, size.height);
  }

  @override
  bool shouldRepaint(covariant _BarPainter oldDelegate) =>
      oldDelegate.track != track ||
      oldDelegate.fill != fill ||
      oldDelegate.fraction != fraction ||
      oldDelegate.tick != tick ||
      oldDelegate.radius != radius ||
      oldDelegate.phase != phase;
}

/// The ring: an arc of the stroke and cap, either at a fraction of
/// the turn or turning with a constant comma.
class _RingPainter extends CustomPainter {
  const new({
    required this.track,
    required this.fill,
    required this.stroke,
    required this.cap,
    required this.tick,
    this.fraction,
    this.groove = true,
  });

  /// The groove ring's colour.
  final Color track;

  /// The arc's colour.
  final Color fill;

  /// The stroke width.
  final double stroke;

  /// How the arc's ends are drawn.
  final StrokeCap cap;

  /// The completion fraction, or null for indeterminate.
  final double? fraction;

  /// The position through one turn of the loop.
  final double tick;

  /// Whether the groove ring is drawn behind the arc at all; the bare-arc
  /// reading says no.
  final bool groove;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.shortestSide / 2 - stroke / 2;
    if (radius <= 0) {
      return;
    }
    final center = size.center(Offset.zero);
    final circle = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = cap;

    if (groove) {
      canvas.drawArc(circle, 0, 2 * pi, false, paint..color = track);
    }

    final fraction = this.fraction;
    final sweep = fraction == null ? 1.5 * pi : 2 * pi * fraction;
    final start = -pi / 2 + (fraction == null ? 2 * pi * tick : 0);
    if (sweep <= 0) {
      return;
    }

    paint.color = fill;
    canvas.drawArc(circle, start, sweep, false, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.track != track ||
      oldDelegate.fill != fill ||
      oldDelegate.stroke != stroke ||
      oldDelegate.cap != cap ||
      oldDelegate.fraction != fraction ||
      oldDelegate.tick != tick ||
      oldDelegate.groove != groove;
}

/// The WinUI ring: dots on a circle, each on the same turn a beat behind the one
/// ahead and a step smaller than it, so the ring gathers and stretches as it
/// chases its own leading dot.
class _DotPainter extends CustomPainter {
  const new({required this.fill, required this.count, required this.dotSize, required this.tick});

  /// The dots' colour.
  final Color fill;

  /// How many dots the ring turns with.
  final int count;

  /// The leading dot's diameter.
  final double dotSize;

  /// The position through one turn of the loop.
  final double tick;

  @override
  void paint(Canvas canvas, Size size) {
    final orbit = size.shortestSide / 2 - dotSize / 2;
    if (orbit <= 0) {
      return;
    }
    final center = size.center(Offset.zero);
    for (var i = 0; i < count; i++) {
      // The chase is a sine on the turn: the dots spread apart and gather back
      // in, once per cycle, so the ring never reads as a fixed rotor.
      final angle = 2 * pi * (tick - i * 0.05 + 0.04 * sin(4 * pi * tick + i * pi / 2));
      final radius = dotSize * (1 - i * 0.16) / 2;
      canvas.drawCircle(
        center + Offset(sin(angle) * orbit, -cos(angle) * orbit),
        radius,
        Paint()..color = fill.withValues(alpha: 1 - i * 0.2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DotPainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.count != count ||
      oldDelegate.dotSize != dotSize ||
      oldDelegate.tick != tick;
}

/// The bar's body: the shape, turned by one repeating
/// controller while the work has no length to measure, and laid out at the
/// thickness or diameter this call asked for.
class _ProgressCore extends StatefulWidget {
  /// A progress body.
  const new({
    required this.visual,
    required this.shape,
    required this.fraction,
    required this.animate,
    required this.cycle,
    required this.fillOverride,
    required this.trackOverride,
    super.key,
  });

  final _ProgressVisual visual;

  /// Which of the two shapes is being drawn.
  final PureProgressShape shape;

  /// The completion fraction; null is the indeterminate loop.
  final double? fraction;

  /// Whether motion runs at all — the kit's `animations` flag, and the reduced
  /// motion the platform reports under it.
  final bool animate;

  /// One full turn of the loop; [Duration.zero] is the still pose.
  final Duration cycle;

  /// The caller's fill colour, or null for the language's own.
  final Color? fillOverride;

  /// The caller's groove colour, or null for the language's own.
  final Color? trackOverride;

  @override
  State<_ProgressCore> createState() => _ProgressCoreState();
}

class _ProgressCoreState extends State<_ProgressCore> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.cycle, debugLabel: 'PureProgress.indeterminate');
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant _ProgressCore oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cycle != widget.cycle) {
      _controller.duration = widget.cycle;
    }
    _syncMotion();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Whether the loop runs: unknown-length work, a language that paced it, and
  /// a user who has not asked for the motion to stop.
  bool get _runs => widget.fraction == null && widget.animate && widget.cycle > Duration.zero;

  void _syncMotion() {
    if (_runs) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
      return;
    }
    if (_controller.isAnimating) {
      _controller.stop();
    }
    // A stopped loop is the shape's own resting pose rather than a frame caught
    // mid-turn, so the reduced-motion answer looks like it was drawn still on
    // purpose.
    if (widget.fraction == null && _controller.value != 0) {
      _controller.value = 0;
    }
  }

  Widget _painted(BuildContext context, double tick) {
    final visual = widget.visual;
    final args = _ProgressArgs(
      fraction: widget.fraction,
      tick: tick,
      track: widget.trackOverride ?? visual.track,
      fill: widget.fillOverride ?? visual.fill,
      stroke: visual.stroke,
      cap: visual.cap,
    );
    Widget shape = CustomPaint(
      painter: switch (widget.shape) {
        PureProgressShape.linear => visual.linear(args),
        PureProgressShape.circular => visual.circular(args),
      },
    );
    shape = switch (widget.shape) {
      PureProgressShape.linear => SizedBox(width: double.infinity, height: visual.linearThickness, child: shape),
      PureProgressShape.circular => SizedBox.square(dimension: visual.diameter, child: shape),
    };
    if (widget.shape == PureProgressShape.circular) {
      // A ring is a square in a wide slot: it keeps the diameter it was drawn
      // at and centres in the room it was given, rather than being stretched
      // across it the way a bar is.
      return Align(alignment: AlignmentDirectional.center, child: shape);
    }
    return shape;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fraction != null) {
      // A measured length needs no loop: the bar is drawn where the fraction
      // says, and nothing ticks.
      return _painted(context, 0);
    }
    return AnimatedBuilder(animation: _controller, builder: (context, _) => _painted(context, _controller.value));
  }
}
