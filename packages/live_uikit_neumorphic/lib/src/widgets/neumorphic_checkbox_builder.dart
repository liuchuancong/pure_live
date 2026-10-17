import 'package:flutter/widgets.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:live_uikit/live_uikit.dart';

/// Builds a Neumorphic checkbox from a [LanguageCheckboxSpec] (§9 Checkbox),
/// applying the optional trailing label through its own label row.
///
/// The fork's callback receives `bool?`, so a bridge closure is unavoidable —
/// but it is built only when the caller can be called back. A null `onChanged`
/// (or `enabled: false`) reaches the fork as null, which is what makes the box
/// render disabled; a closure that swallowed the value would leave a
/// live-looking control that never reports (§9/§15).
abstract final class NeumorphicCheckboxBuilder {
  /// Builds the checkbox for [spec], drawn from this library's own widgets part for part.
  static Widget build(BuildContext context, LanguageCheckboxSpec spec) {
    final onChanged = spec.onChanged;
    return _labelled(
      context,
      spec.label,
      neu.NeuCheckbox(
        value: spec.value,
        onChanged: spec.enabled && onChanged != null ? (v) => onChanged(v ?? false) : null,
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
