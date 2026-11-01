import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/services.dart' show HardwareKeyboard, KeyDownEvent, KeyRepeatEvent, LogicalKeyboardKey;
import 'package:flutter/widgets.dart';

/// The seam's hit strip; the visible line sits centered in it. Wider than
/// the line on purpose: the hand should not have to find a hairline.
const double kChatSplitterStripWidth = 12;

/// How far a key press moves the seam.
const double _kNudgeStep = 8;

/// How far Shift plus a key press moves it.
const double _kCoarseNudgeStep = 32;

/// The seam between the picture and the wide layout's chat column: a
/// hairline that hovers to the accent, drags the column's width and puts it
/// back on a double-tap. Arrow keys move it while it holds the focus, so the
/// width is not a pointer-only setting; the room's TV layout leaves it out of
/// the focus ring, where arrows belong to focus movement.
///
/// The column sits right of the seam, so a drag left widens the chat. Live
/// widths travel through [onResize] and only the gesture's end writes them
/// through [onResizeEnd].
final class ChatSplitter extends StatefulWidget {
  /// The seam over the column's current [width] and its [onResize] range.
  const ChatSplitter({
    required this.width,
    required this.minWidth,
    required this.maxWidth,
    required this.onResize,
    required this.onResizeEnd,
    required this.onReset,
    required this.label,
    this.keyboard = true,
    this.onDark = false,
    super.key,
  });

  /// The chat column's current width, where a drag starts from.
  final double width;

  /// The narrowest and widest the column may become in this layout.
  final double minWidth;
  final double maxWidth;

  /// Fired on every drag update with the new width.
  final ValueChanged<double> onResize;

  /// Fired once a gesture ends, with the width to store.
  final ValueChanged<double> onResizeEnd;

  /// Fired on a double-tap: the width goes back to its default.
  final VoidCallback onReset;

  /// The seam's readable name for assistive technology.
  final String label;

  /// Whether arrow keys reach the seam. A TV remote moves focus with them.
  final bool keyboard;

  /// Whether the seam lies over the picture, where the theme's border ink is
  /// not what the eye needs: the theatre's glass column is drawn on the
  /// video's own dark.
  final bool onDark;

  @override
  State<ChatSplitter> createState() => _ChatSplitterState();
}

final class _ChatSplitterState extends State<ChatSplitter> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'chat-splitter');

  bool _hovering = false;
  bool _dragging = false;
  bool _focused = false;

  /// The width the live drag started from; null between gestures.
  double? _dragStartWidth;

  /// The pointer's screen x where the drag began. The seam itself moves
  /// with every width change, so the travelled distance is measured in
  /// screen coordinates or the next update would count it twice.
  double? _dragStartX;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  double _clamped(double value) => value.clamp(widget.minWidth, widget.maxWidth);

  void _dragged(DragUpdateDetails details) {
    final start = _dragStartWidth;
    final startX = _dragStartX;
    if (start == null || startX == null) return;
    // The column is right of the seam: the seam travelling left widens it.
    widget.onResize(_clamped(start - (details.globalPosition.dx - startX)));
  }

  void _started(DragStartDetails details) {
    _dragStartWidth = widget.width;
    _dragStartX = details.globalPosition.dx;
    setState(() => _dragging = true);
  }

  void _ended() {
    final live = _dragStartWidth != null;
    _dragStartWidth = null;
    _dragStartX = null;
    if (live) widget.onResizeEnd(_clamped(widget.width));
    if (mounted) setState(() => _dragging = false);
  }

  void _nudged(double delta) {
    final next = _clamped(widget.width + delta);
    if (next == widget.width) return;
    widget.onResize(next);
    widget.onResizeEnd(next);
  }

  KeyEventResult _keyed(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    // The column sits right of the seam: left widens it, right narrows it.
    final step = HardwareKeyboard.instance.isShiftPressed ? _kCoarseNudgeStep : _kNudgeStep;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _nudged(step);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _nudged(-step);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final motion = DsTheme.of(context).motion;
    final active = _hovering || _dragging;
    return Semantics(
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: Focus(
          focusNode: widget.keyboard ? _focusNode : null,
          canRequestFocus: widget.keyboard,
          onFocusChange: (focused) => setState(() => _focused = focused),
          onKeyEvent: widget.keyboard ? (_, event) => _keyed(event) : null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down,
            onHorizontalDragStart: _started,
            onHorizontalDragUpdate: _dragged,
            onHorizontalDragEnd: (_) => _ended(),
            onHorizontalDragCancel: _ended,
            onDoubleTap: widget.onReset,
            onTap: widget.keyboard ? _focusNode.requestFocus : null,
            child: SizedBox(
              width: kChatSplitterStripWidth,
              height: double.infinity,
              child: Center(
                child: AnimatedContainer(
                  duration: active ? motion.toneDuration : Duration.zero,
                  curve: motion.toneCurve,
                  width: active || _focused ? 2.0 : 1.0,
                  height: double.infinity,
                  color: active || _focused
                      ? colors.accent
                      : widget.onDark
                      ? const Color(0x66FFFFFF)
                      : colors.border,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
