import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pure_live/app/providers/loading_style_provider.dart';

/// The app's loading animation, following the appearance choice.
///
/// The styles are drawn with Flutter primitives rather than the reference's
/// three animation packages, so only the animations this build can reproduce
/// faithfully are offered; [kLoadingStyleKeys] is that list. The default is
/// the design system's own spinner, which keeps its reduced-motion pulse.
///
/// Use this for page, panel and list loading states. An inline busy mark on
/// a small control keeps `DsSpinner`: the multi-dot styles are not legible
/// at 12–14 px.
class AppLoadingIndicator extends ConsumerWidget {
  /// Creates the loader.
  ///
  /// [size] defaults to the ambient icon size like `DsSpinner`; [color]
  /// defaults to the appearance setting, then the ambient icon colour and
  /// the theme's accent.
  const AppLoadingIndicator({this.size, this.color, this.semanticLabel, super.key});

  /// The box's square side in logical pixels; null follows the icon theme.
  final double? size;

  /// The animation's ink; null follows the loading-colour setting and the
  /// ambient icon colour.
  final Color? color;

  /// Announced by screen readers; null keeps the loader decorative.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(loadingStyleProvider);
    final configured = ref.watch(loadingColorProvider);
    final icon = IconTheme.of(context);
    final dimension = size ?? (icon.size == null ? 14.0 : icon.size! * 14 / 16);
    final tint = color ?? configured ?? icon.color ?? DsTheme.colorsOf(context).accent;
    final loading = style == 'default'
        ? DsSpinner(
            style: DsSpinnerStyle(size: dimension, color: tint),
          )
        : _LoadingAnimation(style: style, size: dimension, color: tint);
    if (semanticLabel == null) return loading;
    return Semantics(label: semanticLabel, liveRegion: true, child: loading);
  }
}

/// Owns the one ticker the styles share; a style change only repaints.
final class _LoadingAnimation extends StatefulWidget {
  const _LoadingAnimation({required this.style, required this.size, required this.color});

  final String style;
  final double size;
  final Color color;

  @override
  State<_LoadingAnimation> createState() => _LoadingAnimationState();
}

final class _LoadingAnimationState extends State<_LoadingAnimation> with SingleTickerProviderStateMixin {
  late final AnimationController _turns = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduced) {
      if (_turns.isAnimating) _turns.stop();
      _turns.value = 0.5;
    } else if (!_turns.isAnimating) {
      _turns.repeat();
    }
  }

  @override
  void dispose() {
    _turns.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _turns,
          builder: (context, _) => CustomPaint(
            painter: _LoadingPainter(style: widget.style, progress: _turns.value, color: widget.color),
          ),
        ),
      ),
    );
  }
}

/// One frame of every non-default style, all inside the same square box.
final class _LoadingPainter extends CustomPainter {
  const _LoadingPainter({required this.style, required this.progress, required this.color});

  final String style;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final center = size.center(Offset.zero);
    switch (style) {
      case 'pulse':
        _pulse(canvas, center, side);
      case 'doubleBounce':
        _doubleBounce(canvas, center, side);
      case 'threeBounce':
        _threeBounce(canvas, center, side);
      case 'wave':
        _wave(canvas, center, side);
      case 'fadingCircle':
        _fadingCircle(canvas, center, side);
      case 'cubeGrid':
        _cubeGrid(canvas, center, side);
      case 'ripple':
        _ripple(canvas, center, side);
      case 'orbit':
        _orbit(canvas, center, side);
      case 'lineScale':
        _lineScale(canvas, center, side);
      default:
        // The provider normalizes; a stale caller still sees a mark.
        canvas.drawCircle(center, side * 0.1, _fill(0.8));
    }
  }

  void _pulse(Canvas canvas, Offset center, double side) {
    final t = _wave01(progress);
    canvas
      ..drawCircle(center, side * 0.34, _stroke(side * 0.035, 0.12))
      ..drawCircle(center, side * (0.14 + 0.16 * t), _fill(0.25 + 0.6 * t));
  }

  void _doubleBounce(Canvas canvas, Offset center, double side) {
    // The larger circle sits behind the smaller, so draw it first.
    for (var i = 1; i >= 0; i--) {
      final t = _wave01(progress - i * 0.5);
      final radius = side * (0.1 + 0.24 * t);
      canvas.drawCircle(center, radius, _fill((0.18 + 0.5 * (1 - t)) * (i == 0 ? 1 : 0.7)));
    }
  }

  void _threeBounce(Canvas canvas, Offset center, double side) {
    final dot = side * 0.1;
    final gap = side * 0.26;
    for (var i = 0; i < 3; i++) {
      final phase = (progress - i / 12 + 1) % 1;
      final lift = math.max(0, math.sin(2 * math.pi * phase));
      canvas.drawCircle(
        Offset(center.dx + (i - 1) * gap, center.dy + side * 0.1 - side * 0.16 * lift),
        dot,
        _fill(0.45 + 0.55 * lift),
      );
    }
  }

  void _wave(Canvas canvas, Offset center, double side) {
    const bars = 4;
    final width = side * 0.1;
    final gap = side * 0.06;
    final total = bars * width + (bars - 1) * gap;
    final left = center.dx - total / 2;
    for (var i = 0; i < bars; i++) {
      final t = _wave01(progress - i * 0.12);
      final height = side * (0.18 + 0.5 * t);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left + i * (width + gap), center.dy - height / 2, width, height),
        Radius.circular(width / 2),
      );
      canvas.drawRRect(rect, _fill(0.4 + 0.6 * t));
    }
  }

  void _fadingCircle(Canvas canvas, Offset center, double side) {
    final orbit = side * 0.32;
    final dot = side * 0.075;
    for (var i = 0; i < 8; i++) {
      final angle = -math.pi / 2 + i * (2 * math.pi / 8);
      final alpha = 0.12 + 0.88 * _wave01(progress - i / 8);
      canvas.drawCircle(center + Offset(math.cos(angle), math.sin(angle)) * orbit, dot, _fill(alpha));
    }
  }

  void _cubeGrid(Canvas canvas, Offset center, double side) {
    final cell = side * 0.16;
    final gap = side * 0.05;
    final total = 3 * cell + 2 * gap;
    final left = center.dx - total / 2;
    final top = center.dy - total / 2;
    for (var i = 0; i < 9; i++) {
      final t = _wave01(progress - i / 9);
      final edge = cell * (0.55 + 0.45 * t);
      final cellCenter = Offset(left + (i % 3) * (cell + gap) + cell / 2, top + (i ~/ 3) * (cell + gap) + cell / 2);
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: cellCenter, width: edge, height: edge),
        Radius.circular(edge * 0.2),
      );
      canvas.drawRRect(rect, _fill(0.15 + 0.75 * t));
    }
  }

  void _ripple(Canvas canvas, Offset center, double side) {
    for (var i = 0; i < 2; i++) {
      final phase = (progress + i * 0.5) % 1;
      canvas.drawCircle(center, side * (0.08 + 0.36 * phase), _stroke(side * 0.045, 0.7 * (1 - phase)));
    }
    canvas.drawCircle(center, side * 0.06, _fill(0.8));
  }

  void _orbit(Canvas canvas, Offset center, double side) {
    final orbit = side * 0.3;
    final angle = -math.pi / 2 + 2 * math.pi * progress;
    final direction = Offset(math.cos(angle), math.sin(angle));
    canvas
      ..drawCircle(center, orbit, _stroke(side * 0.03, 0.16))
      ..drawCircle(center + direction * orbit, side * 0.08, _fill(1))
      ..drawCircle(center - direction * orbit, side * 0.04, _fill(0.3));
  }

  void _lineScale(Canvas canvas, Offset center, double side) {
    const bars = 5;
    final width = side * 0.07;
    final gap = side * 0.06;
    final total = bars * width + (bars - 1) * gap;
    final left = center.dx - total / 2;
    for (var i = 0; i < bars; i++) {
      final t = _wave01(progress - (i - 2).abs() * 0.08);
      final height = side * (0.25 + 0.5 * t);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left + i * (width + gap), center.dy - height / 2, width, height),
        Radius.circular(width / 2),
      );
      canvas.drawRRect(rect, _fill(0.45 + 0.55 * t));
    }
  }

  Paint _fill(double alpha) => Paint()
    ..color = color.withValues(alpha: alpha.clamp(0.0, 1.0))
    ..style = PaintingStyle.fill;

  Paint _stroke(double width, double alpha) => Paint()
    ..color = color.withValues(alpha: alpha.clamp(0.0, 1.0))
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(1, width)
    ..strokeCap = StrokeCap.round;

  static double _wave01(double phase) => 0.5 + 0.5 * math.sin(2 * math.pi * phase);

  @override
  bool shouldRepaint(_LoadingPainter oldDelegate) =>
      oldDelegate.style != style || oldDelegate.progress != progress || oldDelegate.color != color;
}
