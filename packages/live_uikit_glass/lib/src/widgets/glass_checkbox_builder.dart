import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:live_uikit/live_uikit.dart';

/// Builds a frosted checkbox from a [LanguageCheckboxSpec] (§9 Checkbox).
///
/// Composed, not mapped: the library ships no box, so it is a small
/// [glass.GlassContainer] whose radius, blur, tint and stroke come from
/// [glass.GlassTheme] (§8), checked by swapping that tint for the primary colour
/// at a raised opacity and dropping the token's tick into it. The geometry is the
/// checkbox component token's — the library has no metrics for a control it does
/// not carry — and the label is the token's body role, since a glass surface says
/// nothing about type.
///
/// As in `GlassSwitchBuilder`, the tap, the focus node and the interaction tint
/// are the core's [LiveBox] over the library's sheet: `GlassContainer.onTap`
/// would build its own Material ink host and its own focus node, and
/// [LanguageCheckboxSpec.focusNode] could not be routed to either (§15).
abstract final class GlassCheckboxBuilder {
  /// Builds the checkbox for [spec].
  static Widget build(BuildContext context, LanguageCheckboxSpec spec) {
    final theme = LiveTheme.of(context);
    final glassTheme = glass.GlassTheme.of(context);
    final ct = theme.checkbox;
    final interactive = spec.enabled && spec.onChanged != null;

    final box = glass.GlassContainer(
      width: ct.boxSize,
      height: ct.boxSize,
      customBorderRadius: BorderRadius.circular(ct.borderRadius),
      color: spec.value ? theme.colors.primary : glassTheme.color,
      opacity: spec.value ? (glassTheme.opacity * 2.6).clamp(0.0, 1.0) : glassTheme.opacity,
      borderColor: spec.value ? theme.colors.primary : ct.boxBorder,
      alignment: Alignment.center,
      child: spec.value ? Icon(Icons.check, size: ct.boxSize * 0.82, color: ct.checkedIcon) : null,
    );

    final label = spec.label;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          checked: spec.value,
          enabled: interactive,
          child: LiveBox(
            style: (state) => Style(
              borderRadius: BorderRadius.circular(ct.borderRadius),
              background: switch (state) {
                InteractionState.hovered ||
                InteractionState.pressed ||
                InteractionState.focused => ct.hoverBorder.withValues(alpha: (glassTheme.opacity * 2).clamp(0.0, 1.0)),
                _ => null,
              },
              opacity: state == InteractionState.disabled ? ct.disabledOpacity : null,
            ),
            onTap: interactive ? () => spec.onChanged?.call(!spec.value) : null,
            enabled: spec.enabled,
            focusNode: spec.focusNode,
            autofocus: spec.autofocus,
            child: box,
          ),
        ),
        if (label case final text?) ...[
          SizedBox(width: theme.token.scale.sizes.sm),
          Text(text, style: theme.text.body.copyWith(color: theme.colors.text)),
        ],
      ],
    );
  }
}
