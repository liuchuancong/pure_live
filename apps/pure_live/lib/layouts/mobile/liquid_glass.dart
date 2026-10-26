import 'dart:ui' show ImageFilter;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart';

/// The sizes of the floating glass bar (A01.5), the reference's
/// `GlassMetrics` for the same bar.
abstract final class LiquidGlassMetrics {
  /// The blur's sigma behind the glass.
  static const double blurSigma = 24;

  /// The capsule's corners.
  static const double barRadius = 34;

  /// The bar's own height inside the capsule.
  static const double barHeight = 68;

  /// The gap at the sides and above the system's gesture area.
  static const double barMargin = 12;

  /// How much of the page bottom the floating bar covers above the system's
  /// gesture area; scrolled content adds it to stay clear of the capsule.
  static const double barOverlap = barHeight + barMargin;
}

/// A pane of liquid glass for the floating bottom bar (A01.5): tinted,
/// rim-lit, softly shadowed, and — while [blur] — frosted, so the page
/// scrolls visibly under it. Without blur (a small-memory Android phone,
/// A01.5 c4) the same tint sits nearly opaque and nothing frosts, the
/// reference's plain fallback.
final class LiquidGlassPane extends StatelessWidget {
  /// Creates the pane around [child].
  const LiquidGlassPane({required this.child, this.blur = true, this.radius = LiquidGlassMetrics.barRadius, super.key});

  /// What sits on the glass.
  final Widget child;

  /// Whether what is behind is blurred.
  final bool blur;

  /// The corners' radius.
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final dark = DsTheme.of(context).brightness == Brightness.dark;
    final shape = BorderRadius.circular(radius);
    final tint = colors.surface;
    final pane = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        // Lighter at the top, as light falls on curved glass.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: blur
              ? [tint.withValues(alpha: dark ? 0.50 : 0.58), tint.withValues(alpha: dark ? 0.66 : 0.74)]
              : [tint.withValues(alpha: 0.92), tint.withValues(alpha: 0.96)],
        ),
      ),
      child: CustomPaint(foregroundPainter: _GlassRim(radius: radius, dark: dark), child: child),
    );
    return DecoratedBox(
      // Only floating layers carry the shadow, soft and close.
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.32 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: blur
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: LiquidGlassMetrics.blurSigma, sigmaY: LiquidGlassMetrics.blurSigma),
                child: pane,
              )
            : pane,
      ),
    );
  }
}

/// The light rim of [LiquidGlassPane]: brighter along the top-left edge and
/// a faint return along the bottom-right, the highlight a curved edge
/// catches, plus a soft sheen inside the top edge.
final class _GlassRim extends CustomPainter {
  _GlassRim({required this.radius, required this.dark});

  final double radius;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rim = RRect.fromRectAndRadius(rect.deflate(0.5), Radius.circular(radius));
    const light = Colors.white;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          light.withValues(alpha: dark ? 0.30 : 0.75),
          light.withValues(alpha: 0),
          light.withValues(alpha: 0),
          light.withValues(alpha: dark ? 0.12 : 0.35),
        ],
        stops: const [0, 0.42, 0.62, 1],
      ).createShader(rect);
    canvas.drawRRect(rim, paint);
    final sheen = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.center,
        colors: [light.withValues(alpha: dark ? 0.06 : 0.18), light.withValues(alpha: 0)],
      ).createShader(rect);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)), sheen);
  }

  @override
  bool shouldRepaint(_GlassRim oldDelegate) => oldDelegate.radius != radius || oldDelegate.dark != dark;
}
