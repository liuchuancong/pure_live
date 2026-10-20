import 'package:flutter/material.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The chrome that sits on a video rather than on an app surface.
///
/// Nothing here reads `PureTheme`: the picture behind these controls is not the
/// app's surface, so it does not dress them either — white glyphs on a scrim is
/// what a media bar shows in every design language. What the language does own
/// is the shape of the affordance, so the corner and the hover/press fills
/// follow Fluent's media chrome, and the tooltip is the dispatched `PureTooltip`
/// (a Material `Tooltip` would answer with a Material bubble under a Fluent
/// host).
///
/// The second reason these exist: an `Ink`/`InkWell`/`IconButton` on the video
/// throws `No Material widget found` under a non-Material host, which takes the
/// whole control bar down with it.

/// Fluent's corner radius for a media control.
const double kRoomOnVideoCorner = 4;

/// The scrim the bars sit on, so white glyphs read over a bright picture.
class RoomOnVideoScrim extends StatelessWidget {
  /// A gradient scrim under [child].
  const new({required this.child, super.key});

  /// The chrome the scrim carries.
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Color(0x99000000), Color(0x00000000)],
      ),
    ),
    child: child,
  );
}

/// A glyph button on the video: [icon], a hover/press fill and a tooltip that
/// doubles as the accessible name.
class RoomOnVideoButton extends StatefulWidget {
  /// A glyph that answers a tap.
  const new({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.selected = false,
    this.size = 44,
    this.glyphSize = 22,
    super.key,
  });

  /// The glyph to draw.
  final IconData icon;

  /// The hover hint and accessibility label.
  final String tooltip;

  /// The callback; null renders the glyph disabled.
  final VoidCallback? onPressed;

  /// Whether the mode this glyph stands for is currently on.
  final bool selected;

  /// The square side length.
  final double size;

  /// The glyph's point size.
  final double glyphSize;

  @override
  State<RoomOnVideoButton> createState() => _RoomOnVideoButtonState();
}

class _RoomOnVideoButtonState extends State<RoomOnVideoButton> {
  bool _hovering = false;
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final Color fill;
    if (!enabled) {
      fill = Colors.transparent;
    } else if (_pressing || widget.selected) {
      fill = Colors.white24;
    } else if (_hovering) {
      fill = Colors.white12;
    } else {
      fill = Colors.transparent;
    }
    return PureTooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() {
          _hovering = false;
          _pressing = false;
        }),
        child: GestureDetector(
          onTapDown: enabled ? (_) => setState(() => _pressing = true) : null,
          onTapUp: enabled ? (_) => setState(() => _pressing = false) : null,
          onTapCancel: () => setState(() => _pressing = false),
          onTap: widget.onPressed,
          child: Semantics(
            button: true,
            enabled: enabled,
            label: widget.tooltip,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(kRoomOnVideoCorner)),
              child: Center(
                child: Icon(
                  widget.icon,
                  semanticLabel: widget.tooltip,
                  color: enabled ? Colors.white : Colors.white38,
                  size: widget.glyphSize,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A labelled pill on the video — the quality/line chip and the hint the
/// portrait bar raises. [icon] is optional; the label carries the rest.
class RoomOnVideoChip extends StatefulWidget {
  /// A pill that answers a tap.
  const new({
    required this.label,
    this.onTap,
    this.icon,
    this.busy = false,
    this.dense = false,
    this.maxLabelWidth = 150,
    super.key,
  });

  /// The text inside the pill; empty leaves the glyph alone.
  final String label;

  /// The callback; null renders the pill inert.
  final VoidCallback? onTap;

  /// A leading glyph, replaced by a spinner while [busy].
  final IconData? icon;

  /// Whether the pill is waiting on something and shows a spinner.
  final bool busy;

  /// The narrow arrangement: less padding and a shorter label.
  final bool dense;

  /// How wide the label may run before it ellipsizes.
  final double maxLabelWidth;

  @override
  State<RoomOnVideoChip> createState() => _RoomOnVideoChipState();
}

class _RoomOnVideoChipState extends State<RoomOnVideoChip> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          height: 32,
          padding: EdgeInsets.symmetric(horizontal: widget.dense ? 8 : 12),
          decoration: BoxDecoration(
            color: _hovering && enabled ? const Color(0x40FFFFFF) : Colors.white24,
            borderRadius: BorderRadius.circular(kRoomOnVideoCorner),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.busy)
                const PureSpinner(size: 14)
              else if (widget.icon != null)
                Icon(widget.icon, size: 17, color: Colors.white, semanticLabel: widget.label),
              if (widget.label.isNotEmpty) ...[
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: widget.dense ? 90 : widget.maxLabelWidth),
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The volume strip on the bar: a 3px track and a small round thumb, dragged
/// rather than stepped. The token slider would paint the app's own surfaces
/// across the picture.
class RoomOnVideoSlider extends StatelessWidget {
  /// A slider over the video.
  const new({required this.value, required this.onChanged, this.width = 96, super.key});

  /// The current value, 0..1.
  final double value;

  /// Called with each new value.
  final ValueChanged<double> onChanged;

  /// How wide the strip is.
  final double width;

  static const _thumb = 5.0;

  void _emit(double boxWidth, double localX) {
    final usable = (boxWidth - _thumb * 2).clamp(1.0, double.infinity);
    onChanged(((localX - _thumb) / usable).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: 44,
    child: LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) => _emit(constraints.maxWidth, details.localPosition.dx),
        onHorizontalDragStart: (details) => _emit(constraints.maxWidth, details.localPosition.dx),
        onHorizontalDragUpdate: (details) => _emit(constraints.maxWidth, details.localPosition.dx),
        child: Center(
          child: SizedBox(
            height: _thumb * 2,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(color: Colors.white38, borderRadius: BorderRadius.circular(1.5)),
                  ),
                ),
                Positioned(
                  left: 0,
                  width: constraints.maxWidth * value.clamp(0.0, 1.0),
                  child: Container(
                    height: 3,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.all(Radius.circular(1.5)),
                    ),
                  ),
                ),
                Positioned(
                  left: (constraints.maxWidth - _thumb * 2) * value.clamp(0.0, 1.0),
                  child: Container(
                    width: _thumb * 2,
                    height: _thumb * 2,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
