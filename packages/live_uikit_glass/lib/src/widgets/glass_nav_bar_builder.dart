import 'package:flutter/widgets.dart';
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:live_uikit/live_uikit.dart';

/// Builds a frosted destination strip from a [LanguageNavBarSpec] (§9 NavBar).
///
/// Composed, not mapped: the library ships no bar of its own — the only bar it
/// carries is `GlassAppBar`, which is a Material `AppBar` under a frosted
/// `flexibleSpace` and so belongs to a Material frame rather than to this
/// contract — so the strip is one floating [glass.GlassContainer] sheet holding
/// the destinations, and the active destination is a second, brighter sheet
/// inside it. That is how glassmorphism marks a selection everywhere else in this
/// adapter, and it keeps the bar's blur, tint, radius and stroke on the values
/// [glass.GlassTheme] publishes (§8).
///
/// Height and glyph size come from the layout geometry, or from `LiveSizing` when
/// the environment supplies none, because a glass strip has no metrics of its own;
/// `spec.enabled` false keeps every label and stops reporting taps.
abstract final class GlassNavBarBuilder {
  /// Builds the strip for [spec].
  static Widget build(BuildContext context, LanguageNavBarSpec spec) {
    final theme = LiveTheme.of(context);
    final glassTheme = glass.GlassTheme.of(context);
    final geometry = LiveEnvironmentScope.maybeOf(context)?.geometry;
    final height = geometry?.navBarHeight ?? LiveSizing.navBarHeight;
    final iconSize = geometry?.iconSize ?? 18;
    final select = spec.enabled ? spec.onChanged : null;
    final radius = BorderRadius.circular(glassTheme.borderRadius - theme.token.motion.lineWidth);

    return glass.GlassContainer(
      padding: EdgeInsets.all(theme.token.motion.lineWidth * 2),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            for (var index = 0; index < spec.items.length; index++)
              Expanded(
                child: LiveBox(
                  style: (state) => Style(
                    borderRadius: radius,
                    background: switch (state) {
                      InteractionState.hovered || InteractionState.pressed || InteractionState.focused =>
                        glassTheme.color.withValues(alpha: (glassTheme.opacity * 1.8).clamp(0.0, 1.0)),
                      _ => null,
                    },
                    opacity: state == InteractionState.disabled ? theme.token.motion.opacityLoading : null,
                  ),
                  onTap: select == null ? null : () => select(index),
                  enabled: spec.enabled,
                  child: _Destination(
                    item: spec.items[index],
                    selected: index == spec.index,
                    radius: radius,
                    iconSize: iconSize,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One destination: its glyph over its label, on a frosted sheet when it is the
/// one the caller has selected.
class _Destination extends StatelessWidget {
  const new({required this.item, required this.selected, required this.radius, required this.iconSize});

  final LiveNavBarItem item;
  final bool selected;
  final BorderRadius radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final glassTheme = glass.GlassTheme.of(context);
    final sizes = theme.token.scale.sizes;
    final tint = selected ? theme.colors.primary : theme.colors.textSecondary;

    final label = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(item.icon, size: iconSize, color: tint),
        SizedBox(height: sizes.xxs),
        Text(
          item.label,
          style: theme.text.caption.copyWith(color: tint),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );

    return Semantics(
      selected: selected,
      child: selected
          ? glass.GlassContainer(
              customBorderRadius: radius,
              color: glassTheme.color,
              opacity: (glassTheme.opacity * 2.6).clamp(0.0, 1.0),
              padding: EdgeInsets.symmetric(horizontal: sizes.xs),
              child: label,
            )
          : Padding(
              padding: EdgeInsets.symmetric(horizontal: sizes.xs, vertical: sizes.xxs),
              child: label,
            ),
    );
  }
}
