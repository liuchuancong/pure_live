import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';

/// Builds a native Fluent text input from a [LanguageTextFieldSpec] (§9 Text
/// field). The caller's [fluent.TextBox] controller and focus node are passed
/// straight through — the builder never creates or owns a second controller —
/// preserving value, validation, enabled/read-only and keyboard semantics.
abstract final class FluentTextFieldBuilder {
  /// Builds the field for [spec].
  static Widget build(BuildContext context, LanguageTextFieldSpec spec) => fluent.TextBox(
    controller: spec.controller,
    focusNode: spec.focusNode,
    placeholder: spec.placeholder,
    enabled: spec.enabled,
    readOnly: spec.readOnly,
    obscureText: spec.obscure,
    maxLines: spec.obscure ? 1 : spec.maxLines,
    keyboardType: spec.keyboardType,
    textInputAction: spec.textInputAction,
    onChanged: spec.onChanged,
    onSubmitted: spec.onSubmitted,
  );
}
