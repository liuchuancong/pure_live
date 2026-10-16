import 'package:flutter/widgets.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:live_uikit/live_uikit.dart';

/// Builds a Wind text input from a [LanguageTextFieldSpec] (§9 Text field).
///
/// `WInput` takes the caller's `controller` and `focusNode` untouched, owns one
/// only when the caller supplies neither, and carries placeholder, enabled,
/// read-only, line count, keyboard action, prefix and suffix natively. The fork
/// has no `keyboardType`/`obscureText` pair of its own: it derives both from one
/// [wind.InputType], so the spec's two fields collapse into the closest single
/// intent here (`obscure` wins, then an email/number keyboard, then the line
/// count). The error message has no slot in the fork either, so it is drawn the
/// same way the token renderer draws it — the same caption text under the same
/// error border state — rather than invented differently here (§2.3).
abstract final class WindTextFieldBuilder {
  /// Builds the field for [spec].
  static Widget build(BuildContext context, LanguageTextFieldSpec spec) {
    final theme = LiveTheme.of(context);
    final field = wind.WInput(
      controller: spec.controller,
      focusNode: spec.focusNode,
      placeholder: spec.placeholder,
      enabled: spec.enabled,
      readOnly: spec.readOnly,
      maxLines: spec.maxLines,
      textInputAction: spec.textInputAction,
      onChanged: spec.onChanged,
      onSubmitted: spec.onSubmitted,
      prefix: spec.prefix,
      suffix: spec.suffix,
      type: _inputType(spec),
      states: spec.errorText == null ? null : const {'error'},
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
          child: Text(error, style: theme.text.caption.copyWith(color: theme.input.errorBorderColor)),
        ),
      ],
    );
  }

  static wind.InputType _inputType(LanguageTextFieldSpec spec) {
    if (spec.obscure) {
      return wind.InputType.password;
    }
    return switch (spec.keyboardType) {
      TextInputType.emailAddress => wind.InputType.email,
      TextInputType.number || TextInputType.phone || TextInputType.url => wind.InputType.number,
      _ => (spec.maxLines ?? 1) > 1 ? wind.InputType.multiline : wind.InputType.text,
    };
  }
}
