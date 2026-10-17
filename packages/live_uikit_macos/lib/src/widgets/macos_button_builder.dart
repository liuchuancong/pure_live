import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:macos_ui/macos_ui.dart' as macos;

/// Builds a native macOS push button from a [LanguageButtonSpec] (§9 Button).
/// The core [ControlSize] maps onto `macos_ui`'s control sizes; the label,
///
/// Variants ride on `PushButton.color`, the one variant affordance the fork
/// exposes: `primary` becomes the macOS prominent button (accent fill, solid
/// label), `danger` the same shape in the token error, and `secondary` stays
/// the library's own standard grey. `ghost` keeps its primary-tinted label.
///
/// `expand` wraps the button in a full-width box and `tooltip` uses the core's
/// language-neutral [LiveTooltip] plus the fork's own `semanticLabel`, which is
/// also the accessible name. `focusNode` and `autofocus` are recorded as
/// unexpressible: `PushButton` creates and owns its focus handler internally, and
/// a second `Focus` above it would hold the focus that actually handles keyboard
/// activation (§9/§15).
abstract final class MacosButtonBuilder {
  /// Builds the button for [spec], drawn from this library's own widgets part for part.
  static Widget build(BuildContext context, LanguageButtonSpec spec) {
    final theme = LiveTheme.of(context);
    final fill = switch (spec.variant) {
      ButtonVariant.primary => theme.colors.primary,
      ButtonVariant.danger => theme.colors.error,
      ButtonVariant.secondary || ButtonVariant.ghost => null,
    };
    final foreground = switch (spec.variant) {
      ButtonVariant.primary || ButtonVariant.danger => theme.colors.onPrimary,
      ButtonVariant.ghost => theme.colors.primary,
      ButtonVariant.secondary => null,
    };
    Widget button = macos.PushButton(
      controlSize: switch (spec.size) {
        ControlSize.sm => macos.ControlSize.small,
        ControlSize.md => macos.ControlSize.regular,
        ControlSize.lg => macos.ControlSize.large,
      },
      color: fill,
      onPressed: spec.enabled && !spec.loading && spec.onPressed != null ? spec.onPressed : null,
      semanticLabel: spec.tooltip ?? (spec.icon != null ? spec.label : null),
      child: _label(spec, theme, foreground: foreground),
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

  /// The button's content, built from this library's own parts: the label, an
  /// optional leading glyph, a spinner while loading, and the bare glyph of an
  /// icon-only button, whose empty label is never painted. There is no shared
  /// renderer to inherit this from any more, so this language composes it —
  /// the loading state maps to the library's own spinner (§9 Button).
  static Widget _label(LanguageButtonSpec spec, LiveTheme theme, {Color? foreground}) {
    final step = theme.text.label.fontSize ?? 14;
    if (spec.loading) {
      return const macos.ProgressCircle();
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
