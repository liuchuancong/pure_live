import 'dart:ui' show ImageFilter, TileMode;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

/// The ink an overlay draws on a picture: white whatever the app's theme,
/// because the frame behind it is dark and the theme's own text would turn
/// dark-on-dark in a light app.
const Color playerInk = Color(0xFFFFFFFF);
const Color playerInkMuted = Color(0xCCFFFFFF);
const Color playerInkSubtle = Color(0x99FFFFFF);
const Color playerInkHover = Color(0x24FFFFFF);

/// One frosted chip over the picture: a dark glass the frame's own motion
/// bleeds through, rounded to a pill, quiet enough to sit under words.
final class PlayerGlassPill extends StatelessWidget {
  /// The pill's contents.
  const PlayerGlassPill({required this.child, super.key});

  /// What the pill holds, usually a row of icon buttons or badges.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(DsRadii.pill),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14, tileMode: TileMode.decal),
        child: Container(
          decoration: BoxDecoration(color: const Color(0x59000000), borderRadius: BorderRadius.circular(DsRadii.pill)),
          child: child,
        ),
      ),
    );
  }
}

/// The line left at the picture's bottom edge while the bar is away.
///
/// A seekable picture shows how far it has played; a live one has no end to
/// draw against, so [position] and [duration] stay null and the line is the
/// live edge alone. The strip is taller than the line it draws, so the
/// pointer finds it without aiming, and resting on it wakes the full bar.
final class PlayerIdleProgress extends StatelessWidget {
  /// The idle line; [onWake] brings the bar back.
  const PlayerIdleProgress({required this.onWake, this.position, this.duration, super.key});

  /// How far the picture has played; null for a live stream.
  final Duration? position;

  /// The picture's whole length; null for a live stream.
  final Duration? duration;

  /// Wakes the bar the line belongs to.
  final VoidCallback onWake;

  @override
  Widget build(BuildContext context) {
    final total = duration?.inMilliseconds ?? 0;
    final played = total <= 0 ? null : ((position?.inMilliseconds ?? 0) / total).clamp(0.0, 1.0);
    final track = Container(height: 3, color: const Color(0x33FFFFFF));
    final fill = Container(height: 3, color: const Color(0xFFFFFFFF));
    return MouseRegion(
      onHover: (_) => onWake(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onWake,
        child: SizedBox(
          height: 14,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: 3,
              width: double.infinity,
              child: played == null
                  ? track
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        track,
                        FractionallySizedBox(
                          alignment: AlignmentDirectional.centerStart,
                          widthFactor: played,
                          child: fill,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The panel a picker drops over the picture: a dark glass card with the
/// catalogue's name and its rows, the tick on the one in force.
///
/// It is the one popup language of the app's players: the live room's strip
/// and the video page's bar both hang the same card under their control, so
/// "choose a rendition" reads the same wherever it is offered.
final class PlayerOverlayPanel extends StatelessWidget {
  /// A panel titled [title] holding [children], usually [PlayerPanelOption]s.
  const PlayerOverlayPanel({required this.title, required this.children, this.width = 220, super.key});

  /// The catalogue's name, e.g. "清晰度".
  final String title;

  /// The panel's rows.
  final List<Widget> children;

  /// The card's width; a line's catalogue gets a little more for its detail.
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    // A card wider than the picture it hangs over loses its start edge to
    // the picture's own rounded clip, so the host's measure wins over the
    // card's ideal where the two disagree.
    return LayoutBuilder(
      builder: (context, constraints) {
        final effective = constraints.maxWidth < width ? constraints.maxWidth : width;
        return Container(
          width: effective,
          padding: const EdgeInsets.symmetric(vertical: DsSpace.s6),
          decoration: BoxDecoration(
            color: const Color(0xF2131519),
            borderRadius: BorderRadius.circular(theme.radii.card),
            border: Border.all(color: const Color(0x24FFFFFF)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(DsSpace.s12, DsSpace.s4, DsSpace.s12, DsSpace.s6),
                child: Text(
                  title,
                  style: theme.typography.caption.copyWith(color: playerInkSubtle, fontWeight: FontWeight.w600),
                ),
              ),
              // A long catalogue — a multi-part upload's parts — scrolls
              // inside the card instead of growing it past the picture.
              Flexible(
                child: SingleChildScrollView(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One row of a picker panel: the choice, an optional second line, and the
/// tick when it is the one in force.
final class PlayerPanelOption extends StatelessWidget {
  /// A row choosing [label], marked [selected] and fired by [onPressed].
  const PlayerPanelOption({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.detail,
    super.key,
  });

  /// The choice's name.
  final String label;

  /// A muted second line, e.g. what a line's container and codec are.
  final String? detail;

  /// Whether this is the choice in force.
  final bool selected;

  /// What choosing it does.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return DsPressable(
      semanticLabel: label,
      onPressed: onPressed,
      builder: (context, states, _) {
        final hovered = states.contains(WidgetState.hovered);
        return Container(
          color: hovered ? playerInkHover : null,
          padding: const EdgeInsets.symmetric(horizontal: DsSpace.s12, vertical: DsSpace.s6),
          child: Row(
            spacing: DsSpace.s8,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 1,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.caption.copyWith(
                        color: selected ? playerInk : playerInkMuted,
                        fontWeight: selected ? FontWeight.w600 : null,
                      ),
                    ),
                    if (detail case final detail?)
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption.copyWith(fontSize: 11, color: playerInkSubtle),
                      ),
                  ],
                ),
              ),
              if (selected) const DsIcon(DsIcons.check, size: 14, color: playerInk),
            ],
          ),
        );
      },
    );
  }
}
