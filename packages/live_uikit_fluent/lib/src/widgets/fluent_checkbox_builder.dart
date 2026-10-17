import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';

/// Builds a native Fluent checkbox from a [LanguageCheckboxSpec] (§9 Checkbox),
/// with the optional trailing label applied through its own label row so label
/// layout matches every other style.
///
/// Fluent's callback receives `bool?`, so the bridge closure is unavoidable — but
/// it exists only when the caller can be called back: a null `onChanged` (or
/// `enabled: false`) reaches the fork as null, which is what renders the box
/// disabled (§9/§15). The fork's own focus slots are wired, so a keyboard or remote
/// can reach the control.
abstract final class FluentCheckboxBuilder {
  /// Builds the checkbox for [spec], drawn from this library's own widgets part for part.
  static Widget build(BuildContext context, LanguageCheckboxSpec spec) {
    final onChanged = spec.onChanged;
    return _labelled(
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

  /// The control followed by its optional label, laid out with this language's
  /// own text role, because this library's checkbox paints no label of its own (§9 Checkbox).
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
