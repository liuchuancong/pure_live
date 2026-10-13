import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';
import 'package:macos_ui/macos_ui.dart' as macos;

/// Builds a native macOS text field from a [LanguageTextFieldSpec] (§9 Text
/// field), passing the caller's controller and focus node straight through.
abstract final class MacosTextFieldBuilder {
  /// Builds the field for [spec].
  static Widget build(BuildContext context, LanguageTextFieldSpec spec) {
    final theme = LiveTheme.of(context);
    return macos.MacosTextField(
      controller: spec.controller,
      focusNode: spec.focusNode,
      placeholder: spec.placeholder,
      enabled: spec.enabled,
      readOnly: spec.readOnly,
      obscureText: spec.obscure,
      keyboardType: spec.keyboardType,
      onSubmitted: spec.onSubmitted,
      onChanged: spec.onChanged,
      style: theme.text.body.copyWith(color: theme.colors.text),
    );
  }
}
