import 'package:flutter/widgets.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:live_uikit/styling.dart';

/// Builds a native Wind checkbox from a [LanguageCheckboxSpec] (§9 Checkbox),
/// applying the optional trailing label through the shared seam.
abstract final class WindCheckboxBuilder {
  /// Builds the checkbox for [spec]; [seam] supplies the shared label row.
  static Widget build(BuildContext context, LanguageCheckboxSpec spec, SharedLanguageAdapter seam) => seam.labelled(
    context,
    spec.label,
    wind.WCheckbox(value: spec.value, onChanged: spec.enabled ? spec.onChanged : null, disabled: !spec.enabled),
  );
}
