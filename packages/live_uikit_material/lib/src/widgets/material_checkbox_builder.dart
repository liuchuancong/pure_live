import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:material_ui/material_ui.dart' as mu;

/// Builds a native Material UI checkbox from a [LanguageCheckboxSpec]
/// (§9 Checkbox), applying the optional trailing label through its own label row.
abstract final class MaterialCheckboxBuilder {
  /// Builds the checkbox for [spec], drawn from this library's own widgets part for part.
  static Widget build(BuildContext context, LanguageCheckboxSpec spec) {
    final onChanged = spec.onChanged;
    return _labelled(
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

  /// The control followed by its optional label, laid out with this language's
  /// own text role — composed here because the shared renderer is gone (§9 Checkbox).
  static Widget _labelled(BuildContext context, String? label, Widget control) {
    if (label == null) {
      return control;
    }
    final theme = LiveTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        control,
        SizedBox(width: theme.token.scale.sizes.sm),
        Text(label, style: theme.text.body.copyWith(color: theme.colors.text)),
      ],
    );
  }
}
