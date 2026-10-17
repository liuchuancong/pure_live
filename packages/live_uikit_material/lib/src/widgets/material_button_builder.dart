import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:material_ui/material_ui.dart' as mu;

/// Builds a native Material UI button from a [LanguageButtonSpec] (§9 Button):
/// each semantic variant maps to the closest Material button; the danger variant
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
    // carry in its own constructor, so they wrap it the way the token renderer
    // wraps its buttons: full width, and the caller's text verbatim (§9).
    final sized = spec.expand ? SizedBox(width: double.infinity, child: button) : button;
    if (spec.tooltip == null) {
      return sized;
    }
    return mu.Tooltip(message: spec.tooltip, child: sized);
  }

  /// The button's content, built from this library's own parts: the label, an
  /// optional leading glyph, a spinner while loading, and the bare glyph of an
  /// icon-only button, whose empty label is never painted. There is no shared
  /// renderer to inherit this from any more, so this language composes it —
  /// the loading state maps to the library's own spinner (§9 Button).
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
