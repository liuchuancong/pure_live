import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart' as forui;
import 'package:live_uikit/styling.dart';

/// Renders a [LanguageCheckboxSpec] with `FCheckbox` (§9 Checkbox).
abstract final class ForuiCheckboxBuilder {
  /// Builds the checkbox for [spec].
  static Widget build(BuildContext context, LanguageCheckboxSpec spec) {
    final label = spec.label;
    return forui.FCheckbox(
      value: spec.value,
      // A null callback reaches the fork as null, which is how it disables itself.
      onChange: spec.enabled ? spec.onChanged : null,
      enabled: spec.enabled,
      // The fork draws its own label row, so `label` becomes that label rather than a
      // hand-built row beside the box (§9).
      label: label == null ? null : Text(label),
      focusNode: spec.focusNode,
      autofocus: spec.autofocus,
    );
  }
}
