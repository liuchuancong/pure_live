import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';

/// Builds a native Fluent button from a [LanguageButtonSpec] (§9 Button).
///
/// Primary and danger map to `FilledButton`, secondary/ghost to `Button`; the
/// enabled/loading/label logic is reused from the shared seam so a disabled or
/// loading button behaves identically across every style. Business actions stay
/// in the spec's `onPressed` — never here.
abstract final class FluentButtonBuilder {
  /// Builds the button for [spec]; [seam] supplies the shared label/state logic.
  static Widget build(BuildContext context, LanguageButtonSpec spec, SharedLanguageAdapter seam) {
    final theme = LiveTheme.of(context);
    final onPressed = seam.interactive(spec) ? spec.onPressed : null;
    final child = seam.buttonLabel(
      spec,
      theme,
      foreground: spec.variant == ButtonVariant.ghost ? theme.colors.primary : null,
    );
    final filled = spec.variant == ButtonVariant.primary || spec.variant == ButtonVariant.danger;
    Widget button = filled
        ? fluent.FilledButton(onPressed: onPressed, focusNode: spec.focusNode, autofocus: spec.autofocus, child: child)
        : fluent.Button(onPressed: onPressed, focusNode: spec.focusNode, autofocus: spec.autofocus, child: child);
    if (spec.expand) {
      button = SizedBox(width: double.infinity, child: button);
    }
    final hint = spec.tooltip;
    if (hint != null) {
      // `TooltipButton` is Fluent's own hint affordance and only exists on
      // `Button`, so the shared language-neutral tooltip wraps either class
      // identically rather than dropping the filled variant to get it (§9).
      button = LiveTooltip(message: hint, child: button);
    }
    return button;
  }
}
