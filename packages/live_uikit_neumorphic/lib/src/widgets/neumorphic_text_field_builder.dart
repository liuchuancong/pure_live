import 'package:flutter/widgets.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:live_uikit/live_uikit.dart';

/// Builds a Neumorphic text field from a [LanguageTextFieldSpec] (§9 Text field),
/// passing the caller's controller and focus node through.
/// Builds a native Neumorphic text field from a [LanguageTextFieldSpec]
/// (§9 Text field). The fork's field carries hint, error, helper icons,
/// obscuring, keyboard hints, line count and enable state, so they pass straight
/// through; the inline [Style] layers onto the token body text. `readOnly` has no
/// equivalent in `NeuTextField` and is recorded as unmappable (§15) rather than
/// emulated by dropping the callback, which would change what the field means.
abstract final class NeumorphicTextFieldBuilder {
  /// Builds the field for [spec].
  static Widget build(BuildContext context, LanguageTextFieldSpec spec) {
    final theme = LiveTheme.of(context);
    return neu.NeuTextField(
      controller: spec.controller,
      focusNode: spec.focusNode,
      hintText: spec.placeholder,
      errorText: spec.errorText,
      prefixIcon: spec.prefix,
      suffixIcon: spec.suffix,
      obscureText: spec.obscure,
      maxLines: spec.obscure ? 1 : (spec.maxLines ?? 1),
      keyboardType: spec.keyboardType,
      textInputAction: spec.textInputAction,
      enabled: spec.enabled,
      onChanged: spec.onChanged,
      onSubmitted: spec.onSubmitted,
      style: _textStyle(theme, spec),
    );
  }

  /// The token body text with the spec's inline [Style] layered on top; a null
  /// property keeps the token value (§9).
  static TextStyle _textStyle(LiveTheme theme, LanguageTextFieldSpec spec) {
    final base = theme.text.body.copyWith(color: theme.colors.text);
    final override = spec.style;
    if (override == null) {
      return base;
    }
    return base.copyWith(
      color: override.foreground,
      fontFamily: override.fontFamily,
      fontSize: override.fontSize,
      fontWeight: override.fontWeight,
    );
  }
}
