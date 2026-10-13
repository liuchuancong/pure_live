import 'package:flutter/widgets.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:live_uikit/styling.dart';

/// Builds a Neumorphic checkbox from a [LanguageCheckboxSpec] (§9 Checkbox),
/// applying the optional trailing label through the shared seam.
abstract final class NeumorphicCheckboxBuilder {
  /// Builds the checkbox for [spec]; [seam] supplies the shared label row.
  static Widget build(BuildContext context, LanguageCheckboxSpec spec, SharedLanguageAdapter seam) => seam.labelled(
    context,
    spec.label,
    neu.NeuCheckbox(value: spec.value, onChanged: spec.enabled ? (v) => spec.onChanged?.call(v ?? false) : null),
  );
}
