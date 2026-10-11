import 'package:flutter/widgets.dart';

import 'package:live_uikit/src/theme/live_theme.dart';

/// Wraps a control so it can be focused the same way in every design
/// language.
///
/// The highlight owns the [FocusNode] when the caller does not supply one
/// and hands it to the builder, which is what makes one node drive both the
/// inner control's focus handling and the ring drawn here. The ring is an
/// overlay: it never inserts padding or changes the control's size, so
/// focus moving through a list does not shift the layout.
///
/// This is the shared piece of the focus infrastructure; the TV-specific
/// behaviour (focus memory, d-pad navigation, boundary rules) is added on
/// top of it, not instead of it.
class LiveFocusHighlight extends StatefulWidget {
  /// A highlight around the widget [childBuilder] returns.
  const new({
    required this.childBuilder,
    required this.radius,
    this.focusNode,
    this.scale,
    this.enabled = true,
    super.key,
  });

  /// Builds the control, with the node that receives focus.
  final Widget Function(BuildContext context, FocusNode focusNode) childBuilder;

  /// The corner radius the ring follows.
  final double radius;

  /// How much the control grows while focused; null uses the theme's focus
  /// token, 1 disables growth.
  final double? scale;

  /// The caller's node; one is created and disposed when null.
  final FocusNode? focusNode;

  /// Whether the control can take focus at all.
  final bool enabled;

  @override
  State<LiveFocusHighlight> createState() => _LiveFocusHighlightState();
}

class _LiveFocusHighlightState extends State<LiveFocusHighlight> {
  FocusNode? _owned;
  FocusNode? _listened;
  bool _focused = false;

  FocusNode get _node => widget.focusNode ?? (_owned ??= FocusNode(debugLabel: 'live-uikit control'));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attach();
  }

  @override
  void didUpdateWidget(LiveFocusHighlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _attach();
    }
  }

  void _attach() {
    final node = _node;
    if (identical(_listened, node)) {
      return;
    }
    _listened?.removeListener(_onFocusChanged);
    _listened = node;
    node.addListener(_onFocusChanged);
    _focused = node.hasFocus;
  }

  void _onFocusChanged() {
    if (!mounted) {
      return;
    }
    final focused = _listened?.hasFocus ?? false;
    if (focused != _focused) {
      setState(() => _focused = focused);
    }
  }

  @override
  void dispose() {
    _listened?.removeListener(_onFocusChanged);
    _owned?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final focus = theme.focus;
    final scale = widget.scale ?? focus.scale;
    final control = widget.childBuilder(context, _node);
    if (!widget.enabled) {
      return control;
    }
    final highlighted = Stack(
      clipBehavior: Clip.none,
      children: [
        control,
        if (_focused && focus.showRing)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colors.focus, width: focus.ringWidth),
                  borderRadius: BorderRadius.circular(widget.radius + focus.ringOffset),
                ),
              ),
            ),
          ),
      ],
    );
    if (scale == 1 || !_focused) {
      return highlighted;
    }
    return AnimatedScale(scale: scale, duration: focus.duration, curve: Curves.easeOut, child: highlighted);
  }
}
