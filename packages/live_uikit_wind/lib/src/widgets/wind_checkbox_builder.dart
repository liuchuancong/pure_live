import 'package:flutter/widgets.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:live_uikit/live_uikit.dart';

/// Builds a native Wind checkbox from a [LanguageCheckboxSpec] (§9 Checkbox),
/// applying the optional trailing label through the shared seam.
abstract final class WindCheckboxBuilder {
  /// Builds the checkbox for [spec]; [seam] supplies the shared label row.
  static Widget build(BuildContext context, LanguageCheckboxSpec spec, SharedLanguageAdapter seam) {
    final onChanged = spec.onChanged;
    return seam.labelled(
      context,
      spec.label,
      wind.WCheckbox(
        value: spec.value,
        // A null callback means disabled (§9), so the fork's own disabled state
        // follows it rather than leaving a live-looking box that does nothing.
        onChanged: spec.enabled ? onChanged : null,
        disabled: !spec.enabled || onChanged == null,
      ),
    );
  }
}
