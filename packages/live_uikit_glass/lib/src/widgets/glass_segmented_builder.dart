import 'package:flutter/widgets.dart';
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:live_uikit/live_uikit.dart';

/// Builds a frosted segmented control from a [LanguageSegmentedSpec] (§9
/// Segmented).
///
/// Composed, not mapped: `glass_morphism_plus` ships no choice track, so the
/// groove is a [glass.GlassContainer] sheet and the chosen segment is a second,
/// brighter one sitting in it — the way glassmorphism marks a selection (a lit
/// surface, not a filled shape), with the library's own blur, tint, radius and
/// stroke inherited from [glass.GlassTheme] (§8). The unchosen segments get no
/// sheet at all, which is also what the token base does: only the active pill has
/// a surface.
///
/// Taps and interaction tints ride on the core's [LiveBox], for the reason every
/// composed glass control gives: the library's own ink host would carry a focus
/// node the spec cannot reach (§15). [LanguageSegmentedSpec.expand] gives every
/// segment an equal share of the row; a disabled group keeps its labels and stops
/// reporting.
abstract final class GlassSegmentedBuilder {
  /// Builds the segmented track for [spec].
  static Widget build(BuildContext context, LanguageSegmentedSpec spec) {
    final theme = LiveTheme.of(context);
    final glassTheme = glass.GlassTheme.of(context);
    final select = spec.enabled ? spec.onChanged : null;
    final radius = BorderRadius.circular(glassTheme.borderRadius - theme.token.motion.lineWidth);

    Widget segment(int index) {
      final label = spec.labels[index];
      final selected = index == spec.index;
      final text = Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: theme.text.label.copyWith(color: selected ? theme.colors.text : theme.colors.textSecondary),
      );
      return LiveBox(
        style: (state) => Style(
          borderRadius: radius,
          background: switch (state) {
            InteractionState.hovered || InteractionState.pressed || InteractionState.focused => _tint(glassTheme, 1.8),
            InteractionState.disabled => null,
            InteractionState.normal => null,
          },
          opacity: state == InteractionState.disabled ? theme.token.motion.opacityLoading : null,
        ),
        onTap: select == null ? null : () => select(index),
        enabled: spec.enabled,
        child: selected
            ? glass.GlassContainer(
                padding: EdgeInsets.symmetric(
                  horizontal: theme.tabs.horizontalPadding,
                  vertical: theme.token.scale.sizes.xs,
                ),
                customBorderRadius: radius,
                color: theme.colors.primary,
                opacity: (glassTheme.opacity * 2.6).clamp(0.0, 1.0),
                child: text,
              )
            : Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: theme.tabs.horizontalPadding,
                  vertical: theme.token.scale.sizes.xs,
                ),
                child: text,
              ),
      );
    }

    final track = glass.GlassContainer(
      padding: EdgeInsets.all(theme.token.motion.lineWidth),
      child: Row(
        mainAxisSize: spec.expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (var index = 0; index < spec.labels.length; index++)
            if (spec.expand) Expanded(child: segment(index)) else segment(index),
        ],
      ),
    );
    return spec.expand ? SizedBox(width: double.infinity, child: track) : track;
  }

  /// The library's own tint at [multiplier] times the theme opacity — the value a
  /// frosted sheet brightens to when a pointer is on it.
  static Color _tint(glass.GlassThemeData data, double multiplier) =>
      data.color.withValues(alpha: (data.opacity * multiplier).clamp(0.0, 1.0));
}
