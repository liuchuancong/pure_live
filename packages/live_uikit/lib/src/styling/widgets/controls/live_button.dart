import 'package:flutter/material.dart';
import 'package:live_uikit/src/styling/contracts/live_ui_adapter.dart';
import 'package:live_uikit/src/styling/provider/live_config_provider.dart';
import 'package:live_uikit/src/styling/style/recipe.dart';
import 'package:live_uikit/src/styling/style/style.dart';
import 'package:live_uikit/src/styling/widgets/layout/live_box.dart';

/// A button in the token model: one widget, every theme and density.
///
/// It carries only semantics (`variant`, `size`, `enabled`, `loading`) plus an
/// optional inline [style], and delegates its whole appearance to
/// [LiveTheme.resolveButton] fed through [LiveBox]. There is no branch on a
/// design language anywhere: light/dark, compact and a custom accent are all
/// just different resolved tokens the same widget reads. This is the template
/// every live_uikit component follows.
class LiveButton extends StatelessWidget {
  /// A button labelled [label].
  const new({
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = ButtonVariant.primary,
    this.size = ControlSize.md,
    this.loading = false,
    this.expand = false,
    this.autofocus = false,
    this.focusNode,
    this.tooltip,
    this.style,
    super.key,
  });

  /// The button text.
  final String label;

  /// The callback; null disables the button.
  final VoidCallback? onPressed;

  /// An optional leading icon.
  final IconData? icon;

  /// The semantic kind.
  final ButtonVariant variant;

  /// The size step.
  final ControlSize size;

  /// Whether a spinner replaces the content and input is rejected.
  final bool loading;

  /// Whether the button fills its parent's width.
  final bool expand;

  /// Whether it takes focus on first appearance.
  final bool autofocus;

  /// An externally managed focus node.
  final FocusNode? focusNode;

  /// Hover/long-press hint and the accessible description of the action.
  final String? tooltip;

  /// An inline style override (the `style=` attribute).
  final Style? style;

  @override
  Widget build(BuildContext context) {
    // Delegates to the active language adapter: Material/Cupertino/macOS/…
    // each draw it with their own library's widgets, or compose that library's
    // parts where it has none. Switching UiConfig.language re-skins every button.
    return LiveTheme.of(context).adapter.button(
      context,
      LanguageButtonSpec(
        label: label,
        icon: icon,
        variant: variant,
        size: size,
        enabled: onPressed != null,
        loading: loading,
        expand: expand,
        onPressed: onPressed,
        focusNode: focusNode,
        autofocus: autofocus,
        tooltip: tooltip,
        style: style,
      ),
    );
  }
}

/// A square icon-only button — the Ant `Button` icon variant. It always carries
/// a [tooltip] (an icon alone is not a readable label) and takes the same
/// `variant` / `size` semantics as [LiveButton], so it re-skins identically: it
/// dispatches through the active adapter with `iconOnly` and `selected` set on the
/// spec instead of painting a token box of its own.
class LiveIconButton extends StatelessWidget {
  /// An icon button.
  const new({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.variant = ButtonVariant.ghost,
    this.size = ControlSize.md,
    this.selected = false,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    super.key,
  });

  /// The glyph to draw.
  final IconData icon;

  /// The tooltip and accessibility label.
  final String tooltip;

  /// The callback; null disables the button.
  final VoidCallback? onPressed;

  /// The semantic kind.
  final ButtonVariant variant;

  /// The size step; drives the square side length.
  final ControlSize size;

  /// Whether the control shows a mode that is currently on.
  final bool selected;

  /// Whether the button accepts input.
  final bool enabled;

  /// Whether it takes focus on first appearance.
  final bool autofocus;

  /// An externally managed focus node.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    // The same contract `LiveButton` uses: `label` is required by the spec and
    // empty here, and `iconOnly` tells the renderer never to paint it.
    return LiveTheme.of(context).adapter.button(
      context,
      LanguageButtonSpec(
        label: '',
        icon: icon,
        iconOnly: true,
        selected: selected,
        variant: variant,
        size: size,
        enabled: enabled && onPressed != null,
        tooltip: tooltip,
        onPressed: onPressed,
        focusNode: focusNode,
        autofocus: autofocus,
      ),
    );
  }
}

/// A standalone circular spinner tinted with the primary colour — the small
/// loading indicator used inline (a table cell, a section header).
class LiveSpinner extends StatelessWidget {
  /// A spinner.
  const new({this.size = 18, this.color, super.key});

  /// The diameter.
  final double size;

  /// An optional colour override.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    return SizedBox.square(
      dimension: size,
      child: CircularProgressIndicator(strokeWidth: 2, color: color ?? theme.colors.primary),
    );
  }
}
