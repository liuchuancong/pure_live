import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:material_ui/material_ui.dart' as mu;

/// Builds a native Material UI button from a [LanguageButtonSpec] (§9 Button):
/// each semantic variant maps to the closest Material button; the danger variant
/// recolors via `styleFrom`. Press/label/loading come from the shared seam.
abstract final class MaterialButtonBuilder {
  /// Builds the button for [spec]; [seam] supplies shared label/state logic.
  static Widget build(BuildContext context, LanguageButtonSpec spec, SharedLanguageAdapter seam) {
    final theme = LiveTheme.of(context);
    final onPressed = seam.interactive(spec) ? spec.onPressed : null;
    final child = seam.buttonLabel(spec, theme);
    final button = switch (spec.variant) {
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
    // `expand` and `tooltip` are the two spec fields a Material button cannot
    // carry in its own constructor, so they wrap it the way the token renderer
    // wraps its buttons: full width, and the caller's text verbatim (§9).
    final sized = spec.expand ? SizedBox(width: double.infinity, child: button) : button;
    if (spec.tooltip == null) {
      return sized;
    }
    return mu.Tooltip(message: spec.tooltip, child: sized);
  }
}
