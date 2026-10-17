import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_press.dart';

/// What a [SidebarButton] is doing, for [SidebarButton.buildButton] to draw.
typedef SidebarButtonStates = ({bool hovered, bool pressed, bool focused});

/// A button of the desktop split views' bars (back, forward, pane toggle,
/// breadcrumb): a semantics button that Enter and Space activate, and its
/// hover, pressed and keyboard focus states. Each style draws its own
/// ([buildButton]). Internal.
abstract class SidebarButton extends StatefulWidget {
  const SidebarButton({
    super.key,
    this.semanticLabel,
    required this.onPressed,
    this.hasEnabledState = false,
    this.tracksHover = true,
    this.tracksPressed = true,
    this.mouseCursor = MouseCursor.defer,
  });

  final String? semanticLabel;

  /// Null disables the button.
  final VoidCallback? onPressed;

  /// Whether the semantics say if the button is enabled: for a button that
  /// can be disabled.
  final bool hasEnabledState;

  /// False for a button that draws no hover state (the macOS capsule), or
  /// no pressed state (a breadcrumb crumb): it doesn't rebuild for them.
  final bool tracksHover;
  final bool tracksPressed;

  final MouseCursor mouseCursor;

  /// Draws the button in its current [states].
  @protected
  Widget buildButton(BuildContext context, SidebarButtonStates states);

  @override
  State<SidebarButton> createState() => _SidebarButtonState();
}

class _SidebarButtonState extends State<SidebarButton> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focusHighlight = false;

  /// Enter is `ButtonActivateIntent` on the web, `ActivateIntent` elsewhere.
  late final Map<Type, Action<Intent>> _actions = tileActivateActions(
    () => widget.onPressed?.call(),
  );

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final onPressed = widget.onPressed;
    final enabled = onPressed != null;
    final tracksPressed = enabled && widget.tracksPressed;
    Widget button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTapDown: tracksPressed ? (_) => _setPressed(true) : null,
      onTapUp: tracksPressed ? (_) => _setPressed(false) : null,
      onTapCancel: tracksPressed ? () => _setPressed(false) : null,
      onTap: onPressed,
      child: widget.buildButton(context, (
        hovered: _hovered,
        pressed: _pressed,
        focused: _focusHighlight,
      )),
    );
    if (widget.tracksHover) {
      button = MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: button,
      );
    }
    return Semantics(
      container: true,
      button: true,
      enabled: widget.hasEnabledState ? enabled : null,
      label: widget.semanticLabel,
      onTap: onPressed,
      child: FocusableActionDetector(
        enabled: enabled,
        actions: _actions,
        mouseCursor: widget.mouseCursor,
        onShowFocusHighlight: (value) {
          if (value != _focusHighlight) {
            setState(() => _focusHighlight = value);
          }
        },
        child: button,
      ),
    );
  }
}
