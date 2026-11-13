import 'dart:ui' show ImageFilter;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:pure_live/app/background/glass/live_glass.dart' show LiveGlassLevel;

/// The players' frosted card: the surface every floating layer over a picture
/// shares — a chat column, a more panel, a bottom sheet.
///
/// One widget for all of them, because a layer that is glass in one
/// arrangement and paper in the next reads as two different apps; the
/// rounding differs only where the card meets the picture — a floating card
/// rounds on every side, a sheet rising off the bottom edge rounds only along
/// its top.
final class PlayerGlassCard extends StatelessWidget {
  /// The card holding [child].
  ///
  /// [borderRadius] reshapes the card where its host sits against an edge —
  /// a more panel docks on the window's end edge and rounds only its start
  /// side, the way the reference draws it.
  const PlayerGlassCard({required this.child, this.topOnly = false, this.borderRadius, super.key});

  /// The layer inside.
  final Widget child;

  /// Whether only the top edge is rounded and bordered (a sheet over a
  /// picture) rather than a free-standing card.
  final bool topOnly;

  /// Overrides the card's own rounding; null keeps the free-standing or
  /// sheet-top shape.
  final BorderRadiusGeometry? borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final frost = LiveGlassLevel.standard.blurSigma;
    final radius =
        borderRadius ??
        (topOnly
            ? BorderRadius.vertical(top: Radius.circular(theme.radii.card))
            : BorderRadius.circular(theme.radii.card));
    final side = BorderSide(color: colors.border);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: frost, sigmaY: frost, tileMode: TileMode.decal),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.86),
            borderRadius: radius,
            border: Border(
              top: side,
              left: topOnly ? BorderSide.none : side,
              right: topOnly ? BorderSide.none : side,
              bottom: topOnly ? BorderSide.none : side,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
