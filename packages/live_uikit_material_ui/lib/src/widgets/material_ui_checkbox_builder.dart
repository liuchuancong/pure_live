import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';
import 'package:material_ui/material_ui.dart' as mu;

/// Builds a native Material UI checkbox from a [LanguageCheckboxSpec]
/// (§9 Checkbox), applying the optional trailing label through the shared seam.
abstract final class MaterialUiCheckboxBuilder {
  /// Builds the checkbox for [spec]; [seam] supplies the shared label row.
  static Widget build(BuildContext context, LanguageCheckboxSpec spec, SharedLanguageAdapter seam) {
    final onChanged = spec.onChanged;
    return seam.labelled(
      context,
      spec.label,
      mu.Checkbox(
        value: spec.value,
        // A null callback disables the box (§9), so the wrapper closure exists
        // only when the caller can actually be called back.
        onChanged: spec.enabled && onChanged != null ? (v) => onChanged(v ?? false) : null,
        focusNode: spec.focusNode,
        autofocus: spec.autofocus,
      ),
    );
  }
}
