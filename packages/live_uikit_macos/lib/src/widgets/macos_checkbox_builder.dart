import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:macos_ui/macos_ui.dart' as macos;

/// Builds a native macOS checkbox from a [LanguageCheckboxSpec] (§9 Checkbox),
/// applying the optional trailing label through its own label row.
///
/// `MacosCheckbox` derives its disabled look from a null `onChanged`
/// (`isDisabled => onChanged == null`), so the spec's callback is passed through
/// as it is: wrapping it in a closure that swallows the value would leave a
/// live-looking box that never calls the caller (§9/§15).
abstract final class MacosCheckboxBuilder {
  /// Builds the checkbox for [spec], drawn from this library's own widgets part for part.
  static Widget build(BuildContext context, LanguageCheckboxSpec spec) => _labelled(
    context,
    spec.label,
    macos.MacosCheckbox(value: spec.value, onChanged: spec.enabled ? spec.onChanged : null),
  );

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
