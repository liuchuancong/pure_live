import 'package:flutter/widgets.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:live_uikit/live_uikit.dart';

/// Builds a Neumorphic tab strip from a [LanguageTabsSpec] (§9 Tabs).
///
/// **Composed, not mapped.** The library's only strip widget is `NeuBottomNav`, and
/// it cannot be this control: it asserts at least two items (a strip is allowed to
/// render one, and to render none while the caller's router is still filling the
/// list), its `onTap` is a non-null `ValueChanged<int>` where the contract's
/// disabled strip is a null callback, every item must carry an icon *widget* while
/// [LiveTab.icon] is an optional glyph, and it wraps itself in `SafeArea` plus an
/// outer margin because it is a docked bottom bar, not a strip a page can place
/// under a title.
///
/// So the strip is built from the library's own plane: one `NeuContainer` cell per
/// tab, the selected one raised as a dome ([neu.NeuShape.convex]) at
/// [neu.NeuThemeData.depth] and labelled in [neu.NeuThemeData.accentColor], the
/// others left flat on the surface — the same depth-plus-accent reading the
/// library uses for its own active destination, and the reason a Neumorphic tab
/// needs no ink bar. [LanguageTabsSpec.spacing] is honoured as the gap between
/// cells; a disabled strip keeps its labels and loses its callbacks.
abstract final class NeumorphicTabBarBuilder {
  /// Builds the tab strip for [spec].
  static Widget build(BuildContext context, LanguageTabsSpec spec) {
    final theme = LiveTheme.of(context);
    final surface = neu.NeuTheme.of(context);
    final select = spec.enabled ? spec.onChanged : null;
    final radius = surface.borderRadius.resolve(Directionality.of(context));
    final cellRadius = BorderRadius.circular(radius.topLeft.x / 2.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < spec.tabs.length; index++) ...[
          if (index > 0) SizedBox(width: spec.spacing),
          _Cell(
            tab: spec.tabs[index],
            selected: index == spec.index,
            enabled: spec.enabled,
            onTap: select == null ? null : () => select(index),
            radius: cellRadius,
            surface: surface,
            theme: theme,
          ),
        ],
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const new({
    required this.tab,
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.radius,
    required this.surface,
    required this.theme,
  });

  final LiveTab tab;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;
  final BorderRadius radius;
  final neu.NeuThemeData surface;
  final LiveTheme theme;

  @override
  Widget build(BuildContext context) {
    final Color tint;
    if (!enabled) {
      tint = theme.colors.textDisabled;
    } else if (selected) {
      tint = surface.accentColor;
    } else {
      tint = theme.colors.textSecondary;
    }
    final glyph = tab.icon;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: neu.NeuContainer(
        shape: selected ? neu.NeuShape.convex : neu.NeuShape.flat,
        borderRadius: radius,
        baseColor: surface.baseColor,
        depth: selected ? surface.depth : 0.0,
        distance: selected ? surface.distance : 0.0,
        padding: EdgeInsets.symmetric(horizontal: theme.token.scale.sizes.md, vertical: theme.token.scale.sizes.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (glyph case final IconData icon) ...[
              Icon(icon, color: tint, size: theme.text.body.fontSize),
              SizedBox(width: theme.token.scale.sizes.xs),
            ],
            Text(
              tab.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.text.body.copyWith(color: tint, fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
            ),
          ],
        ),
      ),
    );
  }
}
