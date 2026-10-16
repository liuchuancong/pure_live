import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:macos_ui/macos_ui.dart' as macos;

/// Builds a native macOS text field from a [LanguageTextFieldSpec] (§9 Text
/// field), passing the caller's controller and focus node straight through.
abstract final class MacosTextFieldBuilder {
  /// Builds the field for [spec].
  static Widget build(BuildContext context, LanguageTextFieldSpec spec) {
    final theme = LiveTheme.of(context);
    final field = macos.MacosTextField(
      controller: spec.controller,
      focusNode: spec.focusNode,
      placeholder: spec.placeholder,
      enabled: spec.enabled,
      readOnly: spec.readOnly,
      obscureText: spec.obscure,
      keyboardType: spec.keyboardType,
      textInputAction: spec.textInputAction,
      maxLines: spec.obscure ? 1 : (spec.maxLines ?? 1),
      prefix: spec.prefix,
      suffix: spec.suffix,
      onSubmitted: spec.onSubmitted,
      onChanged: spec.onChanged,
      // The fork has no error slot: an error redraws the border with the token
      // error colour — the same signal the token renderer sends — and the message
      // rides underneath it (§9).
      decoration: BoxDecoration(
        border: Border.all(color: spec.errorText == null ? theme.colors.border : theme.colors.error),
        borderRadius: BorderRadius.circular(theme.input.borderRadius),
      ),
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
