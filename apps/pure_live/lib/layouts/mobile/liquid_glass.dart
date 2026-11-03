import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/app.dart'
    show backgroundSettingsProvider, backgroundToneProvider, liveGlassPolicyProvider, liveGlassReadabilityRaise;

/// The sizes of the floating glass bar (A01.5), the reference's
/// `GlassMetrics` for the same bar.
abstract final class LiquidGlassMetrics {
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
/// rim-lit, softly shadowed, and — while the floating glass is frosted —
/// blurred, so the page scrolls visibly under it. The capsule wears the same
/// floating opacity the dialogs and menus do, so the whole floating family
/// answers one slider; without frost the same tint sits nearly opaque and
/// nothing blurs, the reference's plain fallback.
final class LiquidGlassPane extends ConsumerWidget {
  /// Creates the pane around [child].
  const LiquidGlassPane({required this.child, this.radius = LiquidGlassMetrics.barRadius, super.key});

  /// What sits on the glass.
  final Widget child;

  /// The corners' radius.
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = DsTheme.colorsOf(context);
    final dark = DsTheme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.maybeOf(context);
    final policy = ref
        .watch(liveGlassPolicyProvider)
        .demoted(reduceVisualEffects: media?.disableAnimations == true || media?.highContrast == true);
    final settings = ref.watch(backgroundSettingsProvider);
    final raise = liveGlassReadabilityRaise(settings: settings, tone: ref.watch(backgroundToneProvider), dark: dark);
    final material = policy.floatingMaterial(opacity: settings.glassFloatingOpacity, readabilityRaise: raise);
    final shape = BorderRadius.circular(radius);
    final tint = colors.surface;
    // A device or system that cannot frost keeps the near-opaque tint the bar
    // always fell back to: a clear tint over an unblurred page would let the
    // content fight the labels.
    final top = material.frosted ? material.fillAlpha : 0.92;
    final bottom = (top + 0.08).clamp(0.0, 1.0);
    final pane = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        // Lighter at the top, as light falls on curved glass.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            tint.withValues(alpha: top),
            tint.withValues(alpha: bottom),
          ],
        ),
      ),
      child: CustomPaint(
        foregroundPainter: _GlassRim(radius: radius, dark: dark),
        child: child,
      ),
    );
    final filter = material.backdropFilter;
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
        child: filter == null ? pane : BackdropFilter(filter: filter, child: pane),
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
        colors: [
          light.withValues(alpha: dark ? 0.06 : 0.18),
          light.withValues(alpha: 0),
        ],
      ).createShader(rect);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)), sheen);
  }

  @override
  bool shouldRepaint(_GlassRim oldDelegate) => oldDelegate.radius != radius || oldDelegate.dark != dark;
}
