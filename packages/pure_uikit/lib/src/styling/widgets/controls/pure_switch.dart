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

/// The public switch: one widget, every theme and density. It carries only
/// semantics (`value`, `onChanged`, `enabled`); its appearance comes straight
/// from the active design language's own widget library. There is no adapter
/// and no spec in between: [build] switches on `UiConfig.language` and
/// constructs the library's real component directly — fluent_2's `FluentSwitch`
/// under fluent, `MacosSwitch` under macOS, `CupertinoSwitch` under iOS — so
/// what the user sees is exactly what that library's own documentation shows.
/// Switching `UiConfig.language` re-skins every switch.
class PureSwitch extends StatelessWidget {
  /// A switch bound to [value].
  const new({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    super.key,
  });

  /// Whether the switch is on.
  final bool value;

  /// Called with the next value; null (or `enabled: false`) disables it.
  final ValueChanged<bool>? onChanged;

  /// Whether the switch responds to input.
  final bool enabled;

  /// An externally managed focus node.
  final FocusNode? focusNode;

  /// Whether it takes focus on first appearance.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    // A null callback is every library's own inert state, so folding `enabled`
    // into it once serves all the branches below.
    final select = enabled ? onChanged : null;

    return switch (theme.config.language) {
      PureDesignLanguage.fluent => f2.FluentSwitch(
        checked: value,
        onChanged: select,
        focusNode: focusNode,
        autofocus: autofocus,
      ),
      // `MacosSwitch` derives its disabled look from the null callback and
      // takes no focus node: the control builds its own tap and drag
      // recognizers, so keyboard activation is not expressible in this library.
      PureDesignLanguage.macos => macos.MacosSwitch(value: value, onChanged: select),
      // The Cupertino switch has no focus slot either; a null callback greys it.
      PureDesignLanguage.cupertino => cupertino.CupertinoSwitch(value: value, onChanged: select),
      PureDesignLanguage.forui => forui.FSwitch(
        value: value,
        // Fully controlled: the fork reports the next value and never keeps
        // state of its own, and the null callback reaches it as null (§9).
        onChange: select,
        enabled: enabled,
        focusNode: focusNode,
        autofocus: autofocus,
      ),
      // Hand-rolled glass-style composition: glass_morphism_plus ships no
      // toggle, so the track is a frosted [glass.GlassContainer] with a solid
      // frosted disc for the knob — the library's own surfaces, themed from its
      // [glass.GlassTheme] — and the tap, focus node and hover/press tint ride
      // on the core's [PureBox], because the container's own `onTap` would
      // build a Material ink host with a focus node of its own.
      PureDesignLanguage.glass => _GlassSwitch(
        value: value,
        enabled: enabled,
        onChanged: select,
        focusNode: focusNode,
        autofocus: autofocus,
      ),
      PureDesignLanguage.neumorphic => neu.NeuSwitch(value: value, onChanged: select),
      // Wind's fork paints its own `disabled:` state from this flag, so the
      // flag and the nulled callback come from the same verdict.
      PureDesignLanguage.wind => wind.WSwitch(value: value, onChanged: select, disabled: select == null),
      // Yaru IS Material theming — its character comes from the host theme, not
      // from a different switch.
      PureDesignLanguage.material || PureDesignLanguage.yaru => Switch(
        value: value,
        onChanged: select,
        focusNode: focusNode,
        autofocus: autofocus,
      ),
    };
  }
}

/// The glass switch: a hand-rolled glassmorphism composition — the library
/// ships no toggle, so the track is a frosted [glass.GlassContainer] sheet
/// whose blur, tint, radius and stroke come from [glass.GlassTheme], tinted
/// with the primary colour when it is on, and the knob is a solid frosted disc
/// (one backdrop filter per control is the library's own budget, so the knob
/// opts out of its own). The geometry is the switch component token's, because
/// the library has no metrics for a control it does not ship; the tap, the
/// focus node and the interaction tint are the core's [PureBox].
class _GlassSwitch extends StatelessWidget {
  const new({
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.focusNode,
    required this.autofocus,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool>? onChanged;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final glassTheme = glass.GlassTheme.of(context);
    final st = theme.switchToken;
    final interactive = enabled && onChanged != null;
    final lineWidth = theme.token.motion.lineWidth;

    final track = glass.GlassContainer(
      width: st.width,
      height: st.height,
      padding: EdgeInsets.all(lineWidth * 2),
      customBorderRadius: BorderRadius.circular(st.height),
      color: value ? theme.colors.primary : glassTheme.color,
      opacity: value ? (glassTheme.opacity * 2.4).clamp(0.0, 1.0) : glassTheme.opacity,
      child: AnimatedAlign(
        duration: theme.duration,
        curve: Curves.easeOut,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: glass.GlassContainer(
          width: st.handleSize,
          height: st.handleSize,
          shape: BoxShape.circle,
          color: st.handleColor,
          opacity: 1,
          // The knob is a solid frosted disc: one backdrop filter for the whole
          // control is the library's own budget, and a second inside the first
          // would blur the track it sits on.
          isBlurEnabled: false,
          boxShadow: theme.token.motion.boxShadowTertiary,
        ),
      ),
    );

    return Semantics(
      // A switch is a toggle, not a checkbox: announcing both `toggled` and
      // `checked` asserts inside the render tree.
      toggled: value,
      enabled: interactive,
      child: PureBox(
        style: (state) => Style(
          borderRadius: BorderRadius.circular(st.height),
          background: switch (state) {
            InteractionState.hovered ||
            InteractionState.pressed ||
            InteractionState.focused => glassTheme.color.withValues(alpha: (glassTheme.opacity * 1.8).clamp(0.0, 1.0)),
            _ => null,
          },
          opacity: state == InteractionState.disabled ? st.disabledOpacity : null,
        ),
        onTap: interactive ? () => onChanged?.call(!value) : null,
        enabled: enabled,
        focusNode: focusNode,
        autofocus: autofocus,
        child: track,
      ),
    );
  }
}
