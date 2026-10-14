import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';
import 'package:macos_ui/macos_ui.dart' as macos;

/// Builds a native macOS checkbox from a [LanguageCheckboxSpec] (§9 Checkbox),
/// applying the optional trailing label through the shared seam.
///
/// `MacosCheckbox` derives its disabled look from a null `onChanged`
/// (`isDisabled => onChanged == null`), so the spec's callback is passed through
/// as it is: wrapping it in a closure that swallows the value would leave a
/// live-looking box that never calls the caller (§9/§15).
abstract final class MacosCheckboxBuilder {
  /// Builds the checkbox for [spec]; [seam] supplies the shared label row.
  static Widget build(BuildContext context, LanguageCheckboxSpec spec, SharedLanguageAdapter seam) => seam.labelled(
    context,
    spec.label,
    macos.MacosCheckbox(value: spec.value, onChanged: spec.enabled ? spec.onChanged : null),
  );
}
