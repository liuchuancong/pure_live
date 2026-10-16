import 'package:flutter/widgets.dart';
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:live_uikit/live_uikit.dart';

/// Builds a frosted tab strip from a [LanguageTabsSpec] (§9 Tabs).
///
/// Composed, not mapped: the library has no tab widget at all, so the active tab
/// is a raised [glass.GlassContainer] sheet — a lit surface under the label, the
/// idiom glassmorphism uses for whatever is selected — closed by a short primary
/// rule along its bottom edge, while the inactive tabs are bare labels on the
/// page. Everything visible comes from [glass.GlassTheme] (§8): blur, tint,
/// corner radius and stroke are the library's inherited values, and the geometry
/// and colours are the tabs component token's.
///
/// [LanguageTabsSpec.spacing] maps to the gap between tabs, which a glass strip
/// does need: the sheets are rounded, so adjacent tabs would otherwise read as
/// one panel. Taps and the hover tint go through the core's [LiveBox] for the
/// reason every composed glass control gives (§15).
abstract final class GlassTabBarBuilder {
  /// Builds the strip for [spec].
  static Widget build(BuildContext context, LanguageTabsSpec spec) {
    final theme = LiveTheme.of(context);
    final glassTheme = glass.GlassTheme.of(context);
    final select = spec.enabled ? spec.onChanged : null;
    final radius = BorderRadius.circular(glassTheme.borderRadius);
    final lineWidth = theme.token.motion.lineWidthBold;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < spec.tabs.length; index++)
          Padding(
            padding: EdgeInsets.only(right: index == spec.tabs.length - 1 ? 0 : spec.spacing),
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
              child: _Tab(tab: spec.tabs[index], selected: index == spec.index, radius: radius, lineWidth: lineWidth),
            ),
          ),
      ],
    );
  }
}

/// One tab: its label and optional glyph, on a frosted sheet when it is the
/// active one, with the primary rule that says so.
class _Tab extends StatelessWidget {
  const new({required this.tab, required this.selected, required this.radius, required this.lineWidth});

  final LiveTab tab;
  final bool selected;
  final BorderRadius radius;
  final double lineWidth;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final glassTheme = glass.GlassTheme.of(context);
    final tint = selected ? theme.tabs.itemSelectedColor : theme.tabs.itemColor;

    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (tab.icon case final glyph?) ...[
          Icon(glyph, size: theme.text.label.fontSize, color: tint),
          SizedBox(width: theme.token.scale.sizes.xs),
        ],
        Text(
          tab.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.text.label.copyWith(color: tint),
        ),
      ],
    );

    final content = Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.tabs.horizontalPadding, vertical: theme.tabs.verticalGap),
      child: selected
          ? DefaultTextStyle(
              style: const TextStyle(fontWeight: FontWeight.w600),
              child: label,
            )
          : label,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (selected)
          glass.GlassContainer(
            customBorderRadius: radius,
            color: glassTheme.color,
            opacity: (glassTheme.opacity * 2.4).clamp(0.0, 1.0),
            child: content,
          )
        else
          content,
        // The selection mark. A glass sheet cannot shade itself enough to carry
        // a tab on its own, so the strip also rules the accent, as every language
        // in this contract does.
        SizedBox(
          height: lineWidth,
          child: selected ? ColoredBox(color: theme.tabs.inkBarColor) : null,
        ),
      ],
    );
  }
}
