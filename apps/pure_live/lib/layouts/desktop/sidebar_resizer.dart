// Every import stays on one line with no `show` clause: the save-time
// import organizer used to tear wrapped imports apart, so nothing here
// may wrap. Do not add a wrapped import to this file.
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:pure_live/app/app.dart';

/// The resizer's hit strip; the visible line sits centered in it. Wide on
/// purpose: the line is 1px, the hand should not have to be.
const double _kResizerStripWidth = 14;

/// The strip between the sidebar and the content: a hairline that hovers
/// to the accent, drags the sidebar's width, snaps the sidebar shut when
/// dragged far enough toward it, and resets the width on a double-tap.
final class SidebarResizer extends StatefulWidget {
  /// The strip over [onWidthChanged], [onCollapse] and [onReset].
  const SidebarResizer({
    required this.width,
    required this.onWidthChanged,
    required this.onCollapse,
    required this.onReset,
    required this.onDragging,
    super.key,
  });

  /// The sidebar's current width, where a drag starts from.
  final double width;

  /// Fired on every drag update with the new width.
  final ValueChanged<double> onWidthChanged;

  /// Fired once when a drag travels far enough left to put the sidebar
  /// away.
  final VoidCallback onCollapse;

  /// Fired on a double-tap.
  final VoidCallback onReset;

  /// Tells the layout whether a drag is live.
  final ValueChanged<bool> onDragging;

  @override
  State<SidebarResizer> createState() => _SidebarResizerState();
}

final class _SidebarResizerState extends State<SidebarResizer> {
  bool _hovering = false;
  bool _dragging = false;

  /// Set when the drag collapsed the sidebar: the rest of that gesture
  /// then reports nothing, so the rail is not dragged about.
  bool _sentCollapse = false;

  /// The width the live drag started from; null between gestures.
  double? _dragStartWidth;

  /// The pointer's screen x where the drag began. The travelled distance
  /// is measured from here, in screen coordinates: the strip itself moves
  /// with every width change, so a position local to it would drift.
  double? _dragStartX;

  void _dragged(DragUpdateDetails details) {
    final start = _dragStartWidth;
    final startX = _dragStartX;
    if (start == null || startX == null || _sentCollapse) return;
    final width = start + details.globalPosition.dx - startX;
    // Dragged under the collapse width, the gesture is "put it away":
    // the sidebar folds at once and the rest of the drag is ignored.
    if (width < kSidebarCollapseDragWidth) {
      _sentCollapse = true;
      widget.onCollapse();
      return;
    }
    // Between the collapse width and the minimum the sidebar pins at its
    // minimum, as VSCode's does; it never grows past its own cap or into
    // the content's floor, and the clamp's lower bound keeps a shrunken
    // window from turning the maximum under the minimum.
    final window = MediaQuery.sizeOf(context).width;
    final maxWidth = math.max(kSidebarMinWidth, math.min(kSidebarMaxWidth, window - kSidebarContentFloor));
    widget.onWidthChanged(width.clamp(kSidebarMinWidth, maxWidth));
  }

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final motion = DsTheme.of(context).motion;
    final active = _hovering || _dragging;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onHorizontalDragStart: (details) {
          _dragStartWidth = widget.width;
          _dragStartX = details.globalPosition.dx;
          _sentCollapse = false;
          widget.onDragging(true);
          setState(() => _dragging = true);
        },
        onHorizontalDragUpdate: _dragged,
        onHorizontalDragEnd: (_) => _ended(),
        onHorizontalDragCancel: _ended,
        onDoubleTap: widget.onReset,
        child: SizedBox(
          width: _kResizerStripWidth,
          height: double.infinity,
          child: Center(
            child: AnimatedContainer(
              duration: active ? motion.toneDuration : Duration.zero,
              curve: motion.toneCurve,
              width: active ? 2.0 : 1.0,
              height: double.infinity,
              color: active ? colors.accent : colors.border,
            ),
          ),
        ),
      ),
    );
  }

  void _ended() {
    _dragStartWidth = null;
    _dragStartX = null;
    widget.onDragging(false);
    if (mounted) setState(() => _dragging = false);
  }
}
