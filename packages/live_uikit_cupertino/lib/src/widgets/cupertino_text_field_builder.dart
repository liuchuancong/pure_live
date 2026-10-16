import 'package:cupertino_ui/cupertino_ui.dart' as cu;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';

/// Builds a native Cupertino UI text field from a [LanguageTextFieldSpec]
/// (§9 Text field), passing the caller's controller and focus node through and
/// styling the decoration from the resolved theme tokens. An error redraws the
/// border and adds the caption line, the same two signals the token renderer
/// uses, so a field does not change meaning when the style is switched (§9/§15).
abstract final class CupertinoTextFieldBuilder {
  /// Builds the field for [spec].
  static Widget build(BuildContext context, LanguageTextFieldSpec spec) {
    final theme = LiveTheme.of(context);
    final field = cu.CupertinoTextField(
      controller: spec.controller,
      focusNode: spec.focusNode,
      placeholder: spec.placeholder,
      enabled: spec.enabled,
      readOnly: spec.readOnly,
      obscureText: spec.obscure,
      maxLines: spec.obscure ? 1 : (spec.maxLines ?? 1),
      keyboardType: spec.keyboardType,
      textInputAction: spec.textInputAction,
      prefix: spec.prefix,
      suffix: spec.suffix,
      onSubmitted: spec.onSubmitted,
      onChanged: spec.onChanged,
      style: _textStyle(theme, spec),
      decoration: BoxDecoration(
        color: theme.colors.bgContainer,
        borderRadius: BorderRadius.circular(theme.input.borderRadius),
        border: Border.all(color: spec.errorText != null ? theme.colors.error : theme.colors.border),
      ),
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
