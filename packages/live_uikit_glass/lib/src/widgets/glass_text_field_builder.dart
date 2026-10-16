import 'package:flutter/widgets.dart';
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:live_uikit/live_uikit.dart';

/// Builds a frosted glass text input from a [LanguageTextFieldSpec] (§9 Text
/// field).
///
/// The controller and focus node pass through untouched, and the fork carries
/// hint, obscuring, keyboard hints, line count, enable and read-only state, plus
/// leading and trailing slots. It has no error slot, so `errorText` is drawn the
/// way the token renderer draws it — a caption in the error colour under the
/// field — and the field itself keeps the library's own focus treatment rather
/// than an approximation of a Material error border (§15).
abstract final class GlassTextFieldBuilder {
  /// Builds the field for [spec].
  static Widget build(BuildContext context, LanguageTextFieldSpec spec) {
    final theme = LiveTheme.of(context);
    final field = glass.GlassTextField(
      controller: spec.controller,
      focusNode: spec.focusNode,
      hintText: spec.placeholder,
      enabled: spec.enabled,
      readOnly: spec.readOnly,
      obscureText: spec.obscure,
      maxLines: spec.obscure ? 1 : (spec.maxLines ?? 1),
      keyboardType: spec.keyboardType,
      textInputAction: spec.textInputAction,
      prefixIcon: spec.prefix,
      suffixIcon: spec.suffix,
      onChanged: spec.onChanged,
      onSubmitted: spec.onSubmitted,
      style: _textStyle(theme, spec),
    );
    final error = spec.errorText;
    if (error == null) {
      return field;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        field,
        Padding(
          padding: EdgeInsets.only(top: theme.token.scale.sizes.xxs),
          child: Text(error, style: theme.text.caption.copyWith(color: theme.colors.error)),
        ),
      ],
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
