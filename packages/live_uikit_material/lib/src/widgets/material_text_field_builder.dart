import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';
import 'package:material_ui/material_ui.dart' as mu;

/// Builds a Material UI text field from a [LanguageTextFieldSpec] (§9 Text
/// field), passing the caller's controller/focus node through and mapping hint,
/// error, prefix and suffix into the fork's [mu.InputDecoration]. The field only
/// owns a controller when the caller did not supply one (§9).
abstract final class MaterialTextFieldBuilder {
  /// Builds the field for [spec].
  static Widget build(BuildContext context, LanguageTextFieldSpec spec) {
    final theme = LiveTheme.of(context);
    return mu.TextField(
      controller: spec.controller,
      focusNode: spec.focusNode,
      enabled: spec.enabled,
      readOnly: spec.readOnly,
      obscureText: spec.obscure,
      maxLines: spec.obscure ? 1 : spec.maxLines,
      keyboardType: spec.keyboardType,
      textInputAction: spec.textInputAction,
      onChanged: spec.onChanged,
      onSubmitted: spec.onSubmitted,
      style: _textStyle(theme, spec),
      decoration: mu.InputDecoration(
        hintText: spec.placeholder,
        errorText: spec.errorText,
        prefixIcon: spec.prefix == null
            ? null
            : mu.IconTheme.merge(
                data: mu.IconThemeData(color: theme.colors.icon),
                child: spec.prefix!,
              ),
        suffixIcon: spec.suffix,
      ),
    );
  }

  /// The token body text, with whatever the spec's inline [Style] overrides.
  /// [TextStyle.copyWith] keeps the base for a null argument, so only the named
  /// properties move (§9 "preserve `style`").
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
      letterSpacing: override.letterSpacing,
      height: override.lineHeight,
    );
  }
}
