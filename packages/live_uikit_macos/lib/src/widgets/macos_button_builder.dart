import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';
import 'package:macos_ui/macos_ui.dart' as macos;

/// Builds a native macOS push button from a [LanguageButtonSpec] (§9 Button).
/// The core [ControlSize] maps onto `macos_ui`'s control sizes; the label,
/// loading and enabled logic come from the shared seam.
///
/// `expand` wraps the button in a full-width box and `tooltip` uses the core's
/// language-neutral [LiveTooltip] plus the fork's own `semanticLabel`, which is
/// also the accessible name. `focusNode` and `autofocus` are recorded as
/// unexpressible: `PushButton` creates and owns its focus handler internally, and
/// a second `Focus` above it would hold the focus that actually handles keyboard
/// activation (§9/§15).
abstract final class MacosButtonBuilder {
  /// Builds the button for [spec]; [seam] supplies shared label/state logic.
  static Widget build(BuildContext context, LanguageButtonSpec spec, SharedLanguageAdapter seam) {
    final theme = LiveTheme.of(context);
    Widget button = macos.PushButton(
      controlSize: switch (spec.size) {
        ControlSize.sm => macos.ControlSize.small,
        ControlSize.md => macos.ControlSize.regular,
        ControlSize.lg => macos.ControlSize.large,
      },
      onPressed: seam.interactive(spec) ? spec.onPressed : null,
      semanticLabel: spec.tooltip ?? (spec.icon != null ? spec.label : null),
      child: seam.buttonLabel(
        spec,
        theme,
        foreground: spec.variant == ButtonVariant.ghost ? theme.colors.primary : null,
      ),
    );
    if (spec.expand) {
      button = SizedBox(width: double.infinity, child: button);
    }
    final hint = spec.tooltip;
    if (hint != null) {
      button = LiveTooltip(message: hint, child: button);
    }
    return button;
  }
}
