import 'package:flutter/widgets.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:live_uikit/styling.dart';

/// Builds a Neumorphic checkbox from a [LanguageCheckboxSpec] (§9 Checkbox),
/// applying the optional trailing label through the shared seam.
///
/// The fork's callback receives `bool?`, so a bridge closure is unavoidable —
/// but it is built only when the caller can be called back. A null `onChanged`
/// (or `enabled: false`) reaches the fork as null, which is what makes the box
/// render disabled; a closure that swallowed the value would leave a
/// live-looking control that never reports (§9/§15).
abstract final class NeumorphicCheckboxBuilder {
  /// Builds the checkbox for [spec]; [seam] supplies the shared label row.
  static Widget build(BuildContext context, LanguageCheckboxSpec spec, SharedLanguageAdapter seam) {
    final onChanged = spec.onChanged;
    return seam.labelled(
      context,
      spec.label,
      neu.NeuCheckbox(
        value: spec.value,
        onChanged: spec.enabled && onChanged != null ? (v) => onChanged(v ?? false) : null,
      ),
    );
  }
}
