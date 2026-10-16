import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/src/styling/contracts/live_ui_adapter.dart';
import 'package:live_uikit/src/styling/provider/live_config_provider.dart';
import 'package:live_uikit/src/styling/tokens/component_token.dart' show SwitchComponentToken;

/// The token-driven switch renderer (track + knob from [SwitchComponentToken],
/// animated, keyboard/remote focusable) — the base implementation for languages
/// that do not map a switch to their own widget.
class TokenSwitch extends StatefulWidget {
  /// A token switch built from [spec].
  const new({required this.spec, super.key});

  /// The switch configuration.
  final LanguageSwitchSpec spec;

  @override
  State<TokenSwitch> createState() => _TokenSwitchState();
}

class _TokenSwitchState extends State<TokenSwitch> {
  final FocusNode _focus = FocusNode();
  bool _focused = false;

  FocusNode get _node => widget.spec.focusNode ?? _focus;

  bool get _interactive => widget.spec.enabled && widget.spec.onChanged != null;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _node.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _toggle() => widget.spec.onChanged?.call(!widget.spec.value);

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final st = theme.switchToken;
    final lineWidth = theme.token.motion.lineWidth;

    final track = AnimatedContainer(
      duration: theme.duration,
      width: st.width,
      height: st.height,
      padding: EdgeInsets.all(lineWidth * 2),
      decoration: BoxDecoration(
        color: (widget.spec.value ? st.checkedColor : st.uncheckedColor).withValues(
          alpha: widget.spec.enabled ? 1 : st.disabledOpacity,
        ),
        borderRadius: BorderRadius.circular(st.height),
      ),
      child: AnimatedAlign(
        duration: theme.duration,
        curve: Curves.easeOut,
        alignment: widget.spec.value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: st.handleSize,
          height: st.handleSize,
          decoration: BoxDecoration(
            color: st.handleColor,
            shape: BoxShape.circle,
            boxShadow: theme.token.motion.boxShadowTertiary,
          ),
        ),
      ),
    );

    return Semantics(
      // A switch is a toggle, not a checkbox: announcing both `toggled` and
      // `checked` is illegal and asserts inside the render tree.
      toggled: widget.spec.value,
      enabled: _interactive,
      child: Focus(
        focusNode: _node,
        autofocus: widget.spec.autofocus,
        canRequestFocus: _interactive,
        onKeyEvent: (node, event) => _onKey(event),
        child: GestureDetector(
          onTap: _interactive ? _toggle : null,
          child: AnimatedContainer(
            duration: theme.duration,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(st.height),
              border: _focused && theme.config.focusOutline
                  ? Border.all(color: theme.colors.primary, width: lineWidth)
                  : null,
            ),
            child: Padding(padding: EdgeInsets.all(lineWidth), child: track),
          ),
        ),
      ),
    );
  }

  KeyEventResult _onKey(KeyEvent event) {
    if (!_interactive) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.space ||
            event.logicalKey == LogicalKeyboardKey.select)) {
      _toggle();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
}

/// The public switch: a thin dispatcher to the active language adapter, so
/// switching `UiConfig.language` re-renders it with the real library's control.
class LiveSwitch extends StatelessWidget {
  /// A switch bound to [value].
  const new({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    super.key,
  });

  /// Whether the switch is on.
  final bool value;

  /// Called with the next value; null (or `enabled: false`) disables it.
  final ValueChanged<bool>? onChanged;

  /// Whether the switch responds to input.
  final bool enabled;

  /// An externally managed focus node.
  final FocusNode? focusNode;

  /// Whether it takes focus on first appearance.
  final bool autofocus;

  @override
  Widget build(BuildContext context) => LiveTheme.of(context).adapter.switchWidget(
    context,
    LanguageSwitchSpec(
      value: value,
      onChanged: onChanged,
      enabled: enabled,
      focusNode: focusNode,
      autofocus: autofocus,
    ),
  );
}
