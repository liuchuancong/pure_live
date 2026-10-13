import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';

/// Builds a native Fluent checkbox from a [LanguageCheckboxSpec] (§9 Checkbox),
/// with the optional trailing label applied through the shared seam so label
/// layout matches every other style.
abstract final class FluentCheckboxBuilder {
  /// Builds the checkbox for [spec]; [seam] supplies the shared label row.
  static Widget build(BuildContext context, LanguageCheckboxSpec spec, SharedLanguageAdapter seam) => seam.labelled(
    context,
    spec.label,
    fluent.Checkbox(checked: spec.value, onChanged: spec.enabled ? (v) => spec.onChanged?.call(v ?? false) : null),
  );
}
