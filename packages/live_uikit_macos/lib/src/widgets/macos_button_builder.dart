import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';
import 'package:macos_ui/macos_ui.dart' as macos;

/// Builds a native macOS push button from a [LanguageButtonSpec] (§9 Button).
/// The core [ControlSize] maps onto `macos_ui`'s control sizes; the label,
/// loading and enabled logic come from the shared seam.
abstract final class MacosButtonBuilder {
  /// Builds the button for [spec]; [seam] supplies shared label/state logic.
  static Widget build(BuildContext context, LanguageButtonSpec spec, SharedLanguageAdapter seam) {
    final theme = LiveTheme.of(context);
    return macos.PushButton(
      controlSize: switch (spec.size) {
        ControlSize.sm => macos.ControlSize.small,
        ControlSize.md => macos.ControlSize.regular,
        ControlSize.lg => macos.ControlSize.large,
      },
      onPressed: seam.interactive(spec) ? spec.onPressed : null,
      child: seam.buttonLabel(
        spec,
        theme,
        foreground: spec.variant == ButtonVariant.ghost ? theme.colors.primary : null,
      ),
    );
  }
}
