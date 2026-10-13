import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:live_uikit/src/styling/component_token.dart' show CheckboxComponentToken;

import 'package:live_uikit/src/styling/contracts/live_ui_adapter.dart';
import 'package:live_uikit/src/styling/root/live_config_provider.dart';

/// The token-driven checkbox renderer (box surface, checked fill, border, tick
/// and hover/focus/disabled states from [CheckboxComponentToken]) — the base
/// for languages that do not map a checkbox to their own widget.
class TokenCheckbox extends StatefulWidget {
  /// A token checkbox built from [spec].
  const new({required this.spec, super.key});

  /// The checkbox configuration.
  final LanguageCheckboxSpec spec;

  @override
  State<TokenCheckbox> createState() => _TokenCheckboxState();
}

class _TokenCheckboxState extends State<TokenCheckbox> {
  final FocusNode _focus = FocusNode();
  bool _hovered = false;
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
    final ct = theme.checkbox;
    final borderColor = widget.spec.value
        ? ct.checkedBorder
        : _hovered || _focused
        ? ct.hoverBorder
        : ct.boxBorder;
    final fill = widget.spec.value ? ct.checkedBackground : ct.boxBackground;
    final opacity = widget.spec.enabled ? 1.0 : ct.disabledOpacity;

    final box = AnimatedContainer(
      duration: theme.duration,
      width: ct.boxSize,
      height: ct.boxSize,
      decoration: BoxDecoration(
        color: fill.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(ct.borderRadius),
        border: Border.all(
          color: borderColor.withValues(alpha: opacity),
          width: theme.token.motion.lineWidth,
        ),
      ),
      child: widget.spec.value
          ? Icon(
              Icons.check,
              size: ct.boxSize * 0.82,
              color: ct.checkedIcon.withValues(alpha: opacity),
            )
          : null,
    );

    final label = widget.spec.label;
    return MouseRegion(
      cursor: _interactive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Focus(
        focusNode: _node,
        autofocus: widget.spec.autofocus,
        canRequestFocus: _interactive,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.space ||
                  event.logicalKey == LogicalKeyboardKey.select)) {
            _toggle();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _interactive ? _toggle : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(checked: widget.spec.value, enabled: _interactive, child: box),
              if (label != null) ...[
                SizedBox(width: theme.token.scale.sizes.sm),
                Text(
                  label,
                  style: theme.text.body.copyWith(color: theme.colors.text.withValues(alpha: opacity)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The public checkbox: a thin dispatcher to the active language adapter, so
/// switching `UiConfig.language` re-renders it with the real library's control.
class LiveCheckbox extends StatelessWidget {
  /// A checkbox.
  const new({
    required this.value,
    required this.onChanged,
    this.label,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    super.key,
  });

  /// Whether the box is checked.
  final bool value;

  /// Called with the next value; null (or `enabled: false`) disables it.
  final ValueChanged<bool>? onChanged;

  /// An optional trailing label.
  final String? label;

  /// Whether the box responds to input.
  final bool enabled;

  /// An externally managed focus node.
  final FocusNode? focusNode;

  /// Whether it takes focus on first appearance.
  final bool autofocus;

  @override
  Widget build(BuildContext context) => LiveTheme.of(context).adapter.checkbox(
    context,
    LanguageCheckboxSpec(
      value: value,
      onChanged: onChanged,
      label: label,
      enabled: enabled,
      focusNode: focusNode,
      autofocus: autofocus,
    ),
  );
}
