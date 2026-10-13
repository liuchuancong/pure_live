import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';
import 'package:macos_ui/macos_ui.dart' as macos;

/// Builds a native macOS checkbox from a [LanguageCheckboxSpec] (§9 Checkbox),
/// applying the optional trailing label through the shared seam.
abstract final class MacosCheckboxBuilder {
  /// Builds the checkbox for [spec]; [seam] supplies the shared label row.
  static Widget build(BuildContext context, LanguageCheckboxSpec spec, SharedLanguageAdapter seam) => seam.labelled(
    context,
    spec.label,
    macos.MacosCheckbox(value: spec.value, onChanged: spec.enabled ? (v) => spec.onChanged?.call(v) : null),
  );
}
