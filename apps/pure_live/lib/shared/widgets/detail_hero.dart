/// The two pieces a record-led detail head is built from: the cover blown
/// up and blurred into the block's own backdrop, and the one accent disc
/// that anchors the verbs. The music module's hero drew them first; the
/// station's season head and archive info borrow the same two.
library;

import 'dart:ui' show ImageFilter;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

import 'package:pure_live/app/background/glass/live_glass.dart' show kLiveGlassCoverFrostSigma;

/// The backdrop of a record-led head: the block's surface, the cover blown
/// up 1.4x and frosted over it, and the canvas scrim that keeps every word
/// on top readable. The backdrop is only a tint — the scrim does the
/// reading.
final class DetailHeroBackdrop extends StatelessWidget {
  /// Draws the backdrop behind [child].
  const DetailHeroBackdrop({required this.child, this.coverImage, this.coverOpacity = 0.55, super.key});

  /// The head's content, drawn over the backdrop.
  final Widget child;

  /// The cover picture, frosted behind everything; null leaves the surface.
  final ImageProvider<Object>? coverImage;

  /// How strongly the frosted cover shows through.
  final double coverOpacity;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(DsTheme.of(context).radii.card),
      child: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: colors.surface)),
          if (coverImage != null)
            Positioned.fill(
              child: ClipRect(
                child: Opacity(
                  opacity: coverOpacity,
                  // The frost would re-filter on every repaint of the stack;
                  // the boundary keeps the blurred raster, so a hover or a
                  // label change over the head never pays for it again.
                  child: RepaintBoundary(
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: kLiveGlassCoverFrostSigma,
                        sigmaY: kLiveGlassCoverFrostSigma,
                      ),
                      child: Transform.scale(
                        scale: 1.4,
                        child: Image(image: coverImage!, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: AlignmentDirectional.topCenter,
                  end: AlignmentDirectional.bottomCenter,
                  colors: [colors.canvas.withValues(alpha: 0.86), colors.canvas.withValues(alpha: 0.64)],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// The head's anchor: one accent disc for play, so the verbs around it read
/// as its satellites the way a transport does.
final class HeroPlayDisc extends StatelessWidget {
  /// Draws the disc.
  const HeroPlayDisc({required this.onPressed, this.semanticLabel, super.key});

  /// The play verb; null draws the disc dimmed and inert.
  final VoidCallback? onPressed;

  /// The disc's screen-reader label.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    return Opacity(
      opacity: onPressed != null ? 1.0 : 0.45,
      child: DsPressable(
        onPressed: onPressed,
        semanticLabel: semanticLabel,
        builder: (context, states, _) {
          final pressed = states.contains(WidgetState.pressed);
          final hovered = states.contains(WidgetState.hovered);
          return AnimatedScale(
            scale: pressed
                ? 0.94
                : hovered
                ? 1.05
                : 1.0,
            duration: const Duration(milliseconds: 150),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.accent,
                boxShadow: [
                  BoxShadow(
                    color: colors.accent.withValues(alpha: hovered ? 0.45 : 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: SizedBox.square(
                dimension: 52,
                child: Center(child: DsIcon(DsIcons.play, size: 24, color: colors.onAccent)),
              ),
            ),
          );
        },
      ),
    );
  }
}
