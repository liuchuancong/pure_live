import 'package:flutter/widgets.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:live_uikit/styling.dart';

/// Builds a Neumorphic text field from a [LanguageTextFieldSpec] (§9 Text field),
/// passing the caller's controller and focus node through.
abstract final class NeumorphicTextFieldBuilder {
  /// Builds the field for [spec].
  static Widget build(BuildContext context, LanguageTextFieldSpec spec) =>
      neu.NeuTextField(controller: spec.controller, focusNode: spec.focusNode);
}
