import 'package:flutter/widgets.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:live_uikit/live_uikit.dart';

/// Builds a native Wind checkbox from a [LanguageCheckboxSpec] (§9 Checkbox),
/// applying the optional trailing label through its own label row.
abstract final class WindCheckboxBuilder {
  /// Builds the checkbox for [spec], drawn from this library's own widgets part for part.
  static Widget build(BuildContext context, LanguageCheckboxSpec spec) {
    final onChanged = spec.onChanged;
    return _labelled(
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
