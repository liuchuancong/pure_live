import 'package:fluent_2/fluent_2.dart' as f2;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:forui/forui.dart' as forui;
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:macos_ui/macos_ui.dart' as macos;
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';
import 'package:pure_uikit/src/styling/style/style.dart' show InteractionState, Style;
import 'package:pure_uikit/src/styling/widgets/layout/pure_box.dart';

/// The public checkbox: one widget, every theme and density. It carries only
/// semantics (`value`, `onChanged`, `label`, `enabled`); its appearance comes
/// straight from the active design language's own widget library. [build]
/// switches on `UiConfig.language` and constructs the library's real component
/// directly — fluent_2's `FluentCheckbox` under fluent, `MacosCheckbox` under
/// macOS, `CupertinoCheckbox` under iOS — so what the user sees is exactly what
/// that library's own documentation shows. Switching `UiConfig.language`
/// re-skins every checkbox.
class PureCheckbox extends StatelessWidget {
  /// A checkbox.
  const new({
    required this.value,
    required this.onChanged,
    this.label,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    super.key,
  });

  /// Whether the box is checked.
  final bool value;

  /// Called with the next value; null (or `enabled: false`) disables it.
  final ValueChanged<bool>? onChanged;

  /// An optional trailing label.
  final String? label;

  /// Whether the box responds to input.
  final bool enabled;

  /// An externally managed focus node.
  final FocusNode? focusNode;

  /// Whether it takes focus on first appearance.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final onChanged = this.onChanged;
    final text = label;
    final labelText = text == null ? null : Text(text, style: theme.text.body.copyWith(color: theme.colors.text));

    final box = switch (theme.config.language) {
      // fluent_2's checkbox takes a label of its own, laid out the way Fluent
      // lays one out — the branch passes it straight into that slot.
      PureDesignLanguage.fluent => f2.FluentCheckbox(
        checked: value,
        onChanged: _triStateSelect,
        label: labelText,
        focusNode: focusNode,
        autofocus: autofocus,
      ),
      // `MacosCheckbox` derives its disabled look from a null callback and
      // takes no focus node.
      PureDesignLanguage.macos => _labelled(
        labelText,
        theme.token.scale.sizes.sm,
        macos.MacosCheckbox(value: value, onChanged: enabled ? onChanged : null),
      ),
      PureDesignLanguage.cupertino => _labelled(
        labelText,
        theme.token.scale.sizes.xs,
        cupertino.CupertinoCheckbox(
          value: value,
          onChanged: _triStateSelect,
          // The fill and the tick follow the token, the geometry and the
          // pressed halo follow the library.
          activeColor: theme.checkbox.checkedBackground,
          checkColor: theme.checkbox.checkedIcon,
          focusNode: focusNode,
          autofocus: autofocus,
          semanticLabel: text,
        ),
      ),
      // forui's checkbox draws its own label row, so the label travels in that
      // slot in the library's own type rather than in a hand-built row.
      PureDesignLanguage.forui => forui.FCheckbox(
        value: value,
        // A null callback reaches the fork as null, which is how it disables
        // itself.
        onChange: _triStateSelect,
        enabled: enabled,
        label: text == null ? null : Text(text),
        focusNode: focusNode,
        autofocus: autofocus,
      ),
      // Hand-rolled glass-style composition: glass_morphism_plus ships no box,
      // so it is a small frosted [glass.GlassContainer] — the library's own
      // sheet, checked by swapping its tint for the primary colour — with the
      // tap, the focus node and the interaction tint on the core's [PureBox],
      // and the label beside it in the token's body role.
      PureDesignLanguage.glass => _GlassCheckbox(
        value: value,
        label: text,
        enabled: enabled,
        onChanged: onChanged,
        focusNode: focusNode,
        autofocus: autofocus,
      ),
      PureDesignLanguage.neumorphic => _labelled(
        labelText,
        theme.token.scale.sizes.sm,
        // The fork's callback receives `bool?`; `_triStateSelect` is the bridge
        // — null when the box is disabled, the null a tri-state may hand back
        // dropped, because the contract has no mixed state.
        neu.NeuCheckbox(value: value, onChanged: _triStateSelect),
      ),
      // Wind paints its own `disabled:` state from this flag, so the flag and
      // the nulled callback come from the same verdict.
      PureDesignLanguage.wind => _labelled(
        labelText,
        theme.token.scale.sizes.sm,
        wind.WCheckbox(
          value: value,
          onChanged: enabled ? onChanged : null,
          disabled: !enabled || onChanged == null,
        ),
      ),
      // Yaru IS Material theming — its character comes from the host theme, not
      // from a different checkbox.
      PureDesignLanguage.material || PureDesignLanguage.yaru => _labelled(
        labelText,
        theme.token.scale.sizes.sm,
        Checkbox(value: value, onChanged: _triStateSelect, focusNode: focusNode, autofocus: autofocus),
      ),
    };

    return box;
  }

  /// The callback the bool?-taking libraries (Material, Cupertino, fluent_2,
  /// neumorphic) hand their tri-state through, or null when the box is
  /// disabled: the disabled box is a null callback in every library, and the
  /// null a `ValueChanged<bool?>` may hand back is dropped, because the
  /// contract has no mixed state.
  ValueChanged<bool?>? get _triStateSelect {
    final onChanged = this.onChanged;
    if (!enabled || onChanged == null) {
      return null;
    }
    return (next) => onChanged(next ?? false);
  }

  /// The control followed by its optional label, laid out with the token body
  /// role — the libraries' own checkboxes paint no label of their own, so the
  /// label travels beside the box.
  static Widget _labelled(Widget? label, double gap, Widget control) {
    if (label == null) {
      return control;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [control, SizedBox(width: gap), label],
    );
  }
}

/// The glass checkbox: a hand-rolled glassmorphism composition — the library
/// ships no box, so it is a small frosted [glass.GlassContainer] whose blur,
/// tint, radius and stroke come from [glass.GlassTheme], checked by swapping
/// that tint for the primary colour at a raised opacity and dropping the token's
/// tick into it. The tap, the focus node and the interaction tint ride on the
/// core's [PureBox] (the container's own `onTap` would build a Material ink
/// host with a focus node of its own), and the label is the token's body role,
/// since a glass surface says nothing about type.
class _GlassCheckbox extends StatelessWidget {
  const new({
    required this.value,
    required this.label,
    required this.enabled,
    required this.onChanged,
    required this.focusNode,
    required this.autofocus,
  });

  final bool value;
  final String? label;
  final bool enabled;
  final ValueChanged<bool>? onChanged;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final glassTheme = glass.GlassTheme.of(context);
    final ct = theme.checkbox;
    final interactive = enabled && onChanged != null;

    final box = glass.GlassContainer(
      width: ct.boxSize,
      height: ct.boxSize,
      customBorderRadius: BorderRadius.circular(ct.borderRadius),
      color: value ? theme.colors.primary : glassTheme.color,
      opacity: value ? (glassTheme.opacity * 2.6).clamp(0.0, 1.0) : glassTheme.opacity,
      borderColor: value ? theme.colors.primary : ct.boxBorder,
      alignment: Alignment.center,
      child: value ? Icon(Icons.check, size: ct.boxSize * 0.82, color: ct.checkedIcon) : null,
    );

    final labelText = label;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          checked: value,
          enabled: interactive,
          child: PureBox(
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
            onTap: interactive ? () => onChanged?.call(!value) : null,
            enabled: enabled,
            focusNode: focusNode,
            autofocus: autofocus,
            child: box,
          ),
        ),
        if (labelText case final text?) ...[
          SizedBox(width: theme.token.scale.sizes.sm),
          Text(text, style: theme.text.body.copyWith(color: theme.colors.text)),
        ],
      ],
    );
  }
}
