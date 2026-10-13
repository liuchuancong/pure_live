import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';
import 'package:material_ui/material_ui.dart' as mu;

/// Builds a native Material UI button from a [LanguageButtonSpec] (§9 Button):
/// each semantic variant maps to the closest Material button; the danger variant
/// recolors via `styleFrom`. Press/label/loading come from the shared seam.
abstract final class MaterialUiButtonBuilder {
  /// Builds the button for [spec]; [seam] supplies shared label/state logic.
  static Widget build(BuildContext context, LanguageButtonSpec spec, SharedLanguageAdapter seam) {
    final theme = LiveTheme.of(context);
    final onPressed = seam.interactive(spec) ? spec.onPressed : null;
    final child = seam.buttonLabel(spec, theme);
    return switch (spec.variant) {
      ButtonVariant.primary => mu.FilledButton(
        onPressed: onPressed,
        focusNode: spec.focusNode,
        autofocus: spec.autofocus,
        child: child,
      ),
      ButtonVariant.secondary => mu.ElevatedButton(
        onPressed: onPressed,
        focusNode: spec.focusNode,
        autofocus: spec.autofocus,
        child: child,
      ),
      ButtonVariant.ghost => mu.TextButton(
        onPressed: onPressed,
        focusNode: spec.focusNode,
        autofocus: spec.autofocus,
        child: child,
      ),
      ButtonVariant.danger => mu.FilledButton(
        style: mu.FilledButton.styleFrom(backgroundColor: theme.colors.error, foregroundColor: theme.colors.onPrimary),
        onPressed: onPressed,
        focusNode: spec.focusNode,
        autofocus: spec.autofocus,
        child: child,
      ),
    };
  }
}
