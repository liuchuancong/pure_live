import 'package:cupertino_ui/cupertino_ui.dart' as cu;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';

/// Builds a native Cupertino UI text field from a [LanguageTextFieldSpec]
/// (§9 Text field), passing the caller's controller and focus node through and
/// styling the decoration from the resolved theme tokens.
abstract final class CupertinoUiTextFieldBuilder {
  /// Builds the field for [spec].
  static Widget build(BuildContext context, LanguageTextFieldSpec spec) {
    final theme = LiveTheme.of(context);
    return cu.CupertinoTextField(
      controller: spec.controller,
      focusNode: spec.focusNode,
      placeholder: spec.placeholder,
      enabled: spec.enabled,
      readOnly: spec.readOnly,
      obscureText: spec.obscure,
      maxLines: spec.obscure ? 1 : (spec.maxLines ?? 1),
      keyboardType: spec.keyboardType,
      onSubmitted: spec.onSubmitted,
      onChanged: spec.onChanged,
      style: theme.text.body.copyWith(color: theme.colors.text),
      decoration: BoxDecoration(
        color: theme.colors.bgContainer,
        borderRadius: BorderRadius.circular(theme.input.borderRadius),
        border: Border.all(color: spec.errorText != null ? theme.colors.error : theme.colors.border),
      ),
    );
  }
}
