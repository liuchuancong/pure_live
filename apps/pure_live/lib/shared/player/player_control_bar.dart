import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

import 'package:pure_live/shared/player/on_video_colors.dart' show OnVideoColors;

/// The control bar's chrome, the one Container every surface's bottom bar
/// hangs in: the deep shade it melts out of and the inset it keeps from the
/// picture's edges. A surface hands its row — and, where the bar carries
/// one, the seek line above it — as the child and keeps its own width
/// tiers; the chrome is the app's, not the page's.
final class PlayerControlBar extends StatelessWidget {
  /// The chrome around [child].
  const PlayerControlBar({required this.child, super.key, this.padding});

  /// The bar's inset. The default is the shape a bar with a seek line
  /// wears; a bar standing alone passes its own.
  final EdgeInsetsGeometry? padding;

  /// The bar's rows.
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding ?? const EdgeInsetsDirectional.fromSTEB(DsSpace.s12, DsSpace.s4, DsSpace.s12, DsSpace.s12),
    decoration: BoxDecoration(
      gradient: OnVideoColors.shade(edge: VerticalDirection.down, strong: OnVideoColors.scrimDeep),
    ),
    child: child,
  );
}

/// The bar's button rows under the layout rule every player shares: the
/// transport with the tail on one line while the width carries them, the
/// catalogues folding to their own line below when it does not — two rows,
/// never a horizontal scroll. A group is handed as one widget, so the fold
/// keeps each whole: the transport never splits from its mute, a catalogue
/// never loses its chevron, and the second line reads as the same bar's
/// continuation rather than a second bar.
///
/// A Row hands its non-flex children an uncapped width on Flutter's first
/// pass, so a group holding its own [Flexible] would assert; [middle] is
/// therefore kept a flex child of this Row — the one group that may hold
/// expanding content — while [start] and [end] must shrink-wrap cleanly.
final class PlayerBarRows extends StatelessWidget {
  /// Lays the three groups out by the width they get.
  const PlayerBarRows({
    required this.start,
    required this.end,
    this.middle,
    this.foldWidth = 560,
    this.gap = DsSpace.s4,
    super.key,
  });

  /// The transport group: play, the step verbs, mute and the volume. First
  /// in the reading order, present at every width.
  final Widget start;

  /// The bar's catalogues (quality, speed, parts, the danmaku pair): the
  /// group that takes the line's slack — right-aligned against the tail —
  /// and folds to its own line when the width runs out. The one group that
  /// may hold its own [Flexible] children; null where the bar carries none,
  /// and the bar is then one line at every width.
  final Widget? middle;

  /// The tail group: the more door and the fullscreen pair. Last in the
  /// reading order, pinned to the line's end at every width.
  final Widget end;

  /// The width under which [middle] folds to its own line.
  final double foldWidth;

  /// The space between buttons, and between the folded lines.
  final double gap;

  @override
  Widget build(BuildContext context) {
    final middle = this.middle;
    return LayoutBuilder(
      builder: (context, constraints) {
        final oneLine = middle == null || constraints.maxWidth >= foldWidth;
        if (oneLine) {
          return Row(
            spacing: gap,
            children: [
              start,
              // The catalogues as a flex child: the finite cap keeps the
              // group's own flexing children legal, the end alignment keeps
              // them beside the tail, and the fold to a second line remains
              // the narrow answer.
              if (middle != null)
                Expanded(child: Align(alignment: AlignmentDirectional.centerEnd, child: middle)),
              if (middle == null) const Spacer(),
              end,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: gap,
          children: [
            Row(spacing: gap, children: [start, const Spacer(), end]),
            Row(spacing: gap, children: [middle]),
          ],
        );
      },
    );
  }
}
