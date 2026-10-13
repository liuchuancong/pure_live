import 'package:flutter/widgets.dart';
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:live_uikit/styling.dart';

/// Builds a glass text field from a [LanguageTextFieldSpec] (§9 Text field),
/// passing the caller's controller straight through. Glass exposes only hint and
/// change callbacks today, so the rest of the spec is not representable natively.
abstract final class GlassTextFieldBuilder {
  /// Builds the field for [spec].
  static Widget build(BuildContext context, LanguageTextFieldSpec spec) => glass.GlassTextField(
    controller: spec.controller,
    hintText: spec.placeholder,
    onChanged: spec.onChanged,
    onSubmitted: spec.onSubmitted,
  );
}
