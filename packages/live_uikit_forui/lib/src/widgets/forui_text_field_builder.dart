import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart' as forui;
import 'package:live_uikit/styling.dart';

/// Renders a [LanguageTextFieldSpec] with `FTextField` (§9 Text field).
abstract final class ForuiTextFieldBuilder {
  /// Builds the field for [spec].
  static Widget build(BuildContext context, LanguageTextFieldSpec spec) {
    final error = spec.errorText;
    return forui.FTextField(
      // forui owns a controller when the caller brings none, and reports through the
      // same control object — so a caller-owned controller is never replaced and a
      // null `onChanged` stays null instead of becoming a swallowing closure (§9).
      control: forui.FTextFieldControl.managed(
        controller: spec.controller,
        onChange: spec.onChanged == null ? null : (value) => spec.onChanged!(value.text),
      ),
      hint: spec.placeholder,
      // The fork carries an error slot, so `errorText` reaches it instead of being
      // drawn as an invented caption.
      error: error == null ? null : Text(error),
      enabled: spec.enabled,
      readOnly: spec.readOnly,
      obscureText: spec.obscure,
      maxLines: spec.obscure ? 1 : (spec.maxLines ?? 1),
      keyboardType: spec.keyboardType,
      textInputAction: spec.textInputAction,
      focusNode: spec.focusNode,
      // The text-field spec carries no `autofocus` (§9): the core's
      // `LanguageTextFieldSpec` never gained the field the other specs have, so there is
      // nothing to pass until the contract does.
      prefixBuilder: spec.prefix == null ? null : (context, style, variants) => spec.prefix!,
      suffixBuilder: spec.suffix == null ? null : (context, style, variants) => spec.suffix!,
      onSubmit: spec.onSubmitted,
    );
  }
}
