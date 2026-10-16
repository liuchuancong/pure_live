import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:macos_ui/macos_ui.dart' as macos;

/// Builds a macOS select control from a [LanguageSelectSpec] (§9 Select).
///
/// Mapped: `MacosPopupButton` is the library's own pop-up button — the up/down
/// caret, the menu that opens over the button and the accent highlight on the row
/// under the pointer are what make a macOS select read as one. It is generic over
/// the caller's value type, so a typed selection comes back unchanged, and
/// [LanguageSelectSpec.placeholder] rides in as the button's `hint`, the slot the
/// library shows while no value is chosen.
///
/// A disabled select is the library's own inert state (a null `onChanged` greys
/// the caret and refuses the menu), so [LanguageSelectSpec.enabled] needs no extra
/// work. The menu can hand back a null selection — `onChanged` is
/// `ValueChanged<T?>` — which the contract has no case for, so a null is dropped
/// rather than reported.
abstract final class MacosSelectBuilder {
  /// Builds the select control for [spec].
  static Widget build<T>(BuildContext context, LanguageSelectSpec<T> spec) {
    final theme = LiveTheme.of(context);
    return macos.MacosPopupButton<T>(
      items: [
        for (final item in spec.items) macos.MacosPopupMenuItem<T>(value: item, child: Text(spec.itemLabel(item))),
      ],
      value: spec.value,
      hint: spec.placeholder == null ? null : Text(spec.placeholder!),
      style: theme.text.body.copyWith(color: theme.colors.text),
      onChanged: spec.enabled
          ? (value) {
              if (value != null) {
                spec.onChanged?.call(value);
              }
            }
          : null,
    );
  }
}
