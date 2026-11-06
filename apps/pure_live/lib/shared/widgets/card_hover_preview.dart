import 'dart:async' show Timer;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';

/// A card's hover preview: on a pointer that can hover, resting on the card
/// half a second floats a panel beside it — an enlarged cover and the words
/// the card was too small to hold — and leaving the card takes the panel
/// back. A phone has no hover to speak of and a TV's D-pad would trip the
/// panel on every walk down the grid, so the caller turns it off there.
///
/// The panel itself is the popover: it follows the card while scrolling and
/// yields to a tap outside, the overlay's own manners.
final class CardHoverPreview extends StatefulWidget {
  /// The preview over [child]; [content] builds the floated panel.
  const CardHoverPreview({required this.content, required this.child, this.enabled = true, super.key});

  /// Builds the floated panel.
  final WidgetBuilder content;

  /// The card the panel hangs from.
  final Widget child;

  /// Whether hover previews at all; false on a narrow page.
  final bool enabled;

  @override
  State<CardHoverPreview> createState() => _CardHoverPreviewState();
}

class _CardHoverPreviewState extends State<CardHoverPreview> {
  final DsOverlayController _controller = DsOverlayController();

  /// The dwell between arriving and floating: a grid walk must not flash a
  /// panel under every card the pointer crosses.
  static const Duration _dwellBefore = Duration(milliseconds: 500);

  Timer? _dwell;
  bool _pointerInside = false;

  void _enter() {
    if (!widget.enabled) return;
    _pointerInside = true;
    _dwell ??= Timer(_dwellBefore, () {
      _dwell = null;
      if (_pointerInside && mounted) _controller.open();
    });
  }

  void _exit() {
    _pointerInside = false;
    _dwell?.cancel();
    _dwell = null;
    if (_controller.isOpen) _controller.close();
  }

  @override
  void dispose() {
    _dwell?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DsPopover(
      controller: _controller,
      side: DsSide.end,
      contentBuilder: (context) => widget.content(context),
      child: MouseRegion(onEnter: (_) => _enter(), onExit: (_) => _exit(), child: widget.child),
    );
  }
}
