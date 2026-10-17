import 'package:flutter/material.dart';
import 'package:live_uikit/src/styling/contracts/live_ui_adapter.dart';
import 'package:live_uikit/src/styling/provider/live_config_provider.dart';
import 'package:live_uikit/src/styling/style/style.dart';

/// The public text field: a thin dispatcher to the active language adapter, so
/// switching `UiConfig.language` re-renders it with the real library's control.
class LiveTextField extends StatelessWidget {
  /// A text field.
  const new({
    this.controller,
    this.focusNode,
    this.placeholder,
    this.errorText,
    this.enabled = true,
    this.readOnly = false,
    this.obscure = false,
    this.maxLines = 1,
    this.textInputAction,
    this.keyboardType,
    this.prefix,
    this.suffix,
    this.style,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  /// The text controller; the field owns one when omitted.
  final TextEditingController? controller;

  /// An externally managed focus node.
  final FocusNode? focusNode;

  /// The empty-state hint.
  final String? placeholder;

  /// The validation message.
  final String? errorText;

  /// Whether the field responds to input.
  final bool enabled;

  /// Whether the field is read-only.
  final bool readOnly;

  /// Whether the field hides its content.
  final bool obscure;

  /// The line count.
  final int? maxLines;

  /// Keyboard action and type.
  final TextInputAction? textInputAction;

  /// The keyboard type.
  final TextInputType? keyboardType;

  /// A widget before the text.
  final Widget? prefix;

  /// A widget after the text.
  final Widget? suffix;

  /// An inline style override.
  final Style? style;

  /// Called when the text changes.
  final ValueChanged<String>? onChanged;

  /// Called when the field is submitted.
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => LiveTheme.of(context).adapter.textField(
    context,
    LanguageTextFieldSpec(
      controller: controller,
      focusNode: focusNode,
      placeholder: placeholder,
      errorText: errorText,
      enabled: enabled,
      readOnly: readOnly,
      obscure: obscure,
      maxLines: maxLines,
      textInputAction: textInputAction,
      keyboardType: keyboardType,
      prefix: prefix,
      suffix: suffix,
      style: style,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    ),
  );
}
