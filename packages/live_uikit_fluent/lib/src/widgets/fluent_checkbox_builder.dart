import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';

/// Builds a native Fluent checkbox from a [LanguageCheckboxSpec] (§9 Checkbox),
/// with the optional trailing label applied through the shared seam so label
/// layout matches every other style.
///
/// Fluent's callback receives `bool?`, so the bridge closure is unavoidable — but
/// it exists only when the caller can be called back: a null `onChanged` (or
/// `enabled: false`) reaches the fork as null, which is what renders the box
/// disabled (§9/§15). The fork's own focus slots are wired, so a keyboard or remote
/// can reach the control.
abstract final class FluentCheckboxBuilder {
  /// Builds the checkbox for [spec]; [seam] supplies the shared label row.
  static Widget build(BuildContext context, LanguageCheckboxSpec spec, SharedLanguageAdapter seam) {
    final onChanged = spec.onChanged;
    return seam.labelled(
      context,
      spec.label,
      fluent.Checkbox(
        checked: spec.value,
        onChanged: spec.enabled && onChanged != null ? (v) => onChanged(v ?? false) : null,
        focusNode: spec.focusNode,
        autofocus: spec.autofocus,
      ),
    );
  }
}
