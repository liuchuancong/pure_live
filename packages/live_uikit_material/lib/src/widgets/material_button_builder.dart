import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:material_ui/material_ui.dart' as mu;

/// Builds a native Material UI button from a [LanguageButtonSpec] (§9 Button):
/// each semantic variant maps to the closest Material button, and the danger
/// variant takes the token's error fill on the filled class.
abstract final class MaterialButtonBuilder {
  /// Builds the button for [spec], drawn from this library's own widgets part for part.
  static Widget build(BuildContext context, LanguageButtonSpec spec) {
    final theme = LiveTheme.of(context);
    final onPressed = spec.enabled && !spec.loading && spec.onPressed != null ? spec.onPressed : null;
    final child = _label(spec, theme);
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
    // carry in its own constructor, so they are wrapped here: full width, and the
    // caller's text verbatim as the tooltip (§9).
    final sized = spec.expand ? SizedBox(width: double.infinity, child: button) : button;
    if (spec.tooltip == null) {
      return sized;
    }
    return mu.Tooltip(message: spec.tooltip, child: sized);
  }

  /// The button's content, composed from this library's own parts: the label, an
  /// optional leading glyph, a spinner while loading, and the bare glyph of an
  /// icon-only button, whose empty label is never painted. This language writes that
  /// composition itself, so its press and loading states cannot diverge from its own
  /// button — loading maps to the library's own spinner (§9 Button).
  static Widget _label(LanguageButtonSpec spec, LiveTheme theme, {Color? foreground}) {
    final step = theme.text.label.fontSize ?? 14;
    if (spec.loading) {
      return SizedBox.square(
        dimension: step,
        child: mu.CircularProgressIndicator(strokeWidth: 2, color: foreground),
      );
    }
    if (spec.iconOnly) {
      return Icon(
        spec.icon,
        size: step,
        color: foreground,
        semanticLabel: spec.tooltip ?? (spec.label.isEmpty ? null : spec.label),
      );
    }
    final text = Text(spec.label, overflow: TextOverflow.ellipsis);
    if (spec.icon == null) {
      return text;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(spec.icon, size: step, color: foreground),
        SizedBox(width: theme.token.scale.sizes.xs),
        Flexible(child: text),
      ],
    );
  }
}
