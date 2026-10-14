import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';

/// Builds a Fluent text input from a [LanguageTextFieldSpec] (§9 Text field).
///
/// The controller and focus node pass through untouched, and the fork carries
/// placeholder, enable, read-only, obscuring, keyboard hints, line count and the
/// leading/trailing slots. It has no error slot, so `errorText` is drawn the way
/// the token renderer draws it — a caption in the error colour under the box —
/// while the inline [Style] layers onto the token body text (§9).
abstract final class FluentTextFieldBuilder {
  /// Builds the field for [spec].
  static Widget build(BuildContext context, LanguageTextFieldSpec spec) {
    final theme = LiveTheme.of(context);
    final field = fluent.TextBox(
      controller: spec.controller,
      focusNode: spec.focusNode,
      placeholder: spec.placeholder,
      enabled: spec.enabled,
      readOnly: spec.readOnly,
      obscureText: spec.obscure,
      maxLines: spec.obscure ? 1 : spec.maxLines,
      keyboardType: spec.keyboardType,
      textInputAction: spec.textInputAction,
      prefix: spec.prefix,
      suffix: spec.suffix,
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
