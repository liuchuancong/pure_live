import 'package:flutter/material.dart';

import 'package:live_uikit/src/styling/contracts/live_ui_adapter.dart';
import 'package:live_uikit/src/styling/recipe.dart';
import 'package:live_uikit/src/styling/root/live_config_provider.dart';
import 'package:live_uikit/src/styling/style.dart';
import 'package:live_uikit/src/styling/widgets/live_box.dart';

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

  /// An inline style override (the `style=` attribute).
  final Style? style;

  @override
  Widget build(BuildContext context) {
    // Delegates to the active language adapter: Material/Cupertino/macOS/…
    // draw it with their real widgets; languages without one fall back to the
    // shared token renderer. Switching UiConfig.language re-skins every button.
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
      ),
    );
  }
}

/// A square icon-only button — the Ant `Button` icon variant. It always carries
/// a [tooltip] (an icon alone is not a readable label) and takes the same
/// `variant` / `size` semantics as [LiveButton], so it re-skins identically.
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

  /// Whether the button renders as toggled on (primary foreground).
  final bool selected;

  /// Whether the button accepts input.
  final bool enabled;

  /// Whether it takes focus on first appearance.
  final bool autofocus;

  /// An externally managed focus node.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final edge = switch (size) {
      ControlSize.sm => theme.button.controlHeightSM,
      ControlSize.md => theme.button.controlHeight,
      ControlSize.lg => theme.button.controlHeightLG,
    };
    final foreground = selected ? theme.colors.primary : theme.colors.textSecondary;
    return LiveBox(
      style: (state) => theme
          .resolveButton(variant: variant, size: size, state: state)
          .copyWith(foreground: state == InteractionState.disabled ? theme.colors.textDisabled : foreground),
      enabled: enabled && onPressed != null,
      onTap: enabled ? onPressed : null,
      focusNode: focusNode,
      autofocus: autofocus,
      child: SizedBox.square(
        dimension: edge,
        child: Tooltip(
          message: tooltip,
          child: Icon(icon, size: theme.text.label.fontSize, semanticLabel: tooltip),
        ),
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
