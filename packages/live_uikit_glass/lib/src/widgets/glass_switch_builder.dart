import 'package:flutter/widgets.dart';
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:live_uikit/live_uikit.dart';

/// Builds a frosted switch from a [LanguageSwitchSpec] (§9 Switch).
///
/// Composed, not mapped: `glass_morphism_plus` carries no toggle, so the track is
/// a [glass.GlassContainer] — the library's only surface widget — with a circular
/// one for the knob, and both take their blur, tint, corner radius and stroke
/// from [glass.GlassTheme] (§8), which the theme scope seeds from the resolved
/// token. A switch is on when its sheet is tinted with the primary colour at a
/// raised opacity rather than filled opaque, so the page still reads through it.
/// The geometry is the switch component token's, because the library has no
/// metrics for a control it does not ship.
///
/// The tap, the focus node and the hover/press tint ride on the core's [LiveBox]:
/// handing the tap to [glass.GlassContainer.onTap] instead would make the
/// library build a Material ink host with a focus node of its own, and the spec's
/// [LanguageSwitchSpec.focusNode] could not reach the control through it (§15). A
/// disabled switch keeps its sheet and loses its callback.
abstract final class GlassSwitchBuilder {
  /// Builds the switch for [spec].
  static Widget build(BuildContext context, LanguageSwitchSpec spec) {
    final theme = LiveTheme.of(context);
    final glassTheme = glass.GlassTheme.of(context);
    final st = theme.switchToken;
    final interactive = spec.enabled && spec.onChanged != null;
    final lineWidth = theme.token.motion.lineWidth;

    final track = glass.GlassContainer(
      width: st.width,
      height: st.height,
      padding: EdgeInsets.all(lineWidth * 2),
      customBorderRadius: BorderRadius.circular(st.height),
      color: spec.value ? theme.colors.primary : glassTheme.color,
      opacity: spec.value ? (glassTheme.opacity * 2.4).clamp(0.0, 1.0) : glassTheme.opacity,
      child: AnimatedAlign(
        duration: theme.duration,
        curve: Curves.easeOut,
        alignment: spec.value ? Alignment.centerRight : Alignment.centerLeft,
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
      toggled: spec.value,
      enabled: interactive,
      child: LiveBox(
        style: (state) => Style(
          borderRadius: BorderRadius.circular(st.height),
          background: switch (state) {
            InteractionState.hovered || InteractionState.pressed || InteractionState.focused => glassTheme.color.withValues(
              alpha: (glassTheme.opacity * 1.8).clamp(0.0, 1.0),
            ),
            _ => null,
          },
          opacity: state == InteractionState.disabled ? st.disabledOpacity : null,
        ),
        onTap: interactive ? () => spec.onChanged?.call(!spec.value) : null,
        enabled: spec.enabled,
        focusNode: spec.focusNode,
        autofocus: spec.autofocus,
        child: track,
      ),
    );
  }
}
