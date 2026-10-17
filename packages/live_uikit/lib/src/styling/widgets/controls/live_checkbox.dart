import 'package:flutter/material.dart';
import 'package:live_uikit/src/styling/contracts/live_ui_adapter.dart';
import 'package:live_uikit/src/styling/provider/live_config_provider.dart';

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
