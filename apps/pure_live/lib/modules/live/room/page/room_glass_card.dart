import 'dart:ui' show ImageFilter;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:pure_live/app/background/glass/live_glass.dart' show LiveGlassLevel;

/// The room's frosted card: the chat column's surface when it floats over the
/// picture, and the bottom panel's surface in the narrow room.
///
/// One widget for both, because a layer that is glass in one arrangement and
/// paper in the next reads as two different apps; the rounding differs only
/// where the card meets the picture — a floating column rounds on every side,
/// a sheet rising off the bottom edge rounds only along its top.
final class RoomGlassCard extends StatelessWidget {
  /// The card holding [child].
  const RoomGlassCard({required this.child, this.topOnly = false, super.key});

  /// The layer inside.
  final Widget child;

  /// Whether only the top edge is rounded and bordered (a sheet over a
  /// picture) rather than a free-standing card.
  final bool topOnly;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final frost = LiveGlassLevel.standard.blurSigma;
    final radius = topOnly
        ? BorderRadius.vertical(top: Radius.circular(theme.radii.card))
        : BorderRadius.circular(theme.radii.card);
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
