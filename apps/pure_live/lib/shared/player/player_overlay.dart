import 'dart:math' as math;
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

/// Where a picker's catalogue hangs relative to the picture's edge.
enum PlayerPanelSide {
  /// Above its button, and above the bar the button sits in.
  above,

  /// Below its button — a strip that runs along the top of the picture.
  below,
}

/// A catalogue placed against the picker that opened it.
///
/// The player pages used to pin the card to the picture's end edge, so a menu
/// opened from the middle of the bar appeared several buttons away from its
/// own control and read as belonging to a neighbour. This measures the trigger
/// (and, when [barKey] names one, the bar it sits in), centres the card over
/// the trigger, and keeps it inside the picture.
///
/// With a [barKey] the host is a layer of the player's own stack and hangs
/// above the bar (or below it); without one it is an inline child of a column
/// — the live room's top strip — and only moves the card horizontally, which
/// is the placement a strip with no room above it can offer.
final class PlayerPanelHost extends StatefulWidget {
  /// Places [child] over the picker behind [anchorKey].
  const PlayerPanelHost({
    required this.anchorKey,
    required this.width,
    required this.child,
    this.barKey,
    this.side = PlayerPanelSide.above,
    this.inset = DsSpace.s8,
    this.gap = DsSpace.s4,
    super.key,
  });

  /// The picker button that opened the catalogue.
  final GlobalKey anchorKey;

  /// The bar the picker sits in; null places the card inline instead.
  final GlobalKey? barKey;

  /// The card's ideal width; the picture's own measure wins when it is
  /// narrower.
  final double width;

  /// The catalogue itself.
  final Widget child;

  /// Which side of the button the card goes to.
  final PlayerPanelSide side;

  /// The least distance the card keeps from the picture's edges.
  final double inset;

  /// The distance between the card and its button or bar.
  final double gap;

  @override
  State<PlayerPanelHost> createState() => _PlayerPanelHostState();
}

final class _PlayerPanelHostState extends State<PlayerPanelHost> {
  Rect? _anchor;
  Rect? _bar;
  bool _measureScheduled = false;

  bool get _inline => widget.barKey == null;

  @override
  void initState() {
    super.initState();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant PlayerPanelHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.anchorKey != widget.anchorKey || oldWidget.barKey != widget.barKey) {
      // The card moved to another picker: the old box says nothing about this
      // one, and a stale placement would flash it over the button just left.
      _anchor = null;
      _bar = null;
    }
    _scheduleMeasure();
  }

  /// Measures after the frame that laid the picker out. Until then the host
  /// draws nothing, which is one frame the viewer never notices.
  void _scheduleMeasure() {
    if (_measureScheduled) return;
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      if (!mounted) return;
      _measure();
    });
  }

  void _measure() {
    final self = context.findRenderObject();
    if (self is! RenderBox || !self.hasSize) return;
    final anchor = _rectOf(widget.anchorKey, self);
    if (anchor == null) {
      // The picker is not laid out yet (an inserted bar): ask again next
      // frame rather than guessing a position.
      _scheduleMeasure();
      return;
    }
    final bar = widget.barKey == null ? null : _rectOf(widget.barKey!, self);
    if (anchor == _anchor && bar == _bar) return;
    setState(() {
      _anchor = anchor;
      _bar = bar;
    });
  }

  static Rect? _rectOf(GlobalKey key, RenderBox self) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    // The picker is a sibling of this layer, not a descendant: measure both
    // in the root's coordinates and subtract, rather than naming an ancestor
    // the render tree does not have.
    return (box.localToGlobal(Offset.zero) - self.localToGlobal(Offset.zero)) & box.size;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // A resize moves the picker without moving this layer's state, so the
        // measurement follows the layout.
        _scheduleMeasure();
        final anchor = _anchor;
        final available = constraints.maxWidth;
        final width = math.min(widget.width, math.max(0, available - 2 * widget.inset).toDouble());
        if (anchor == null || width <= 0) return const SizedBox.shrink();
        final left = (anchor.center.dx - width / 2)
            .clamp(widget.inset, math.max(widget.inset, available - width - widget.inset))
            .toDouble();
        if (_inline) {
          return Padding(
            padding: EdgeInsetsDirectional.only(start: left),
            child: SizedBox(width: width, child: widget.child),
          );
        }
        final height = constraints.maxHeight;
        final barTop = _bar?.top ?? anchor.top;
        final top = widget.side == PlayerPanelSide.below ? anchor.bottom + widget.gap : null;
        final bottom = widget.side == PlayerPanelSide.above ? height - barTop + widget.gap : null;
        final room = widget.side == PlayerPanelSide.above
            ? height - (bottom ?? 0) - widget.inset
            : height - (top ?? 0) - widget.inset;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: left,
              top: top,
              bottom: bottom,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: width, maxHeight: math.max(0, room).toDouble()),
                child: SizedBox(width: width, child: widget.child),
              ),
            ),
          ],
        );
      },
    );
  }
}
