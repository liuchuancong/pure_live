import 'package:flutter/widgets.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:live_uikit/live_uikit.dart';

/// Builds a Neumorphic bottom navigation bar from a [LanguageNavBarSpec]
/// (§9 NavBar).
///
/// **Composed, not mapped.** The library's `NeuBottomNav` looks like this control
/// and is not it, for four reasons tested against the widget: it asserts
/// `items.length >= 2`, so a page with one destination — or none, while a router is
/// still filling the list — throws instead of rendering; its `onTap` is a non-null
/// `ValueChanged<int>` where the contract's disabled bar is a null callback; it
/// hard-wraps itself in a `SafeArea` plus an outer `margin` because it is a floating
/// pill, so a frame that already reserves its bottom inset gets the inset twice and a
/// caller cannot take the margin back; and it reaches for `HapticFeedback` on every
/// change, which the contract does not ask for and a desktop build would feel as a
/// wrong device.
///
/// So the bar is built from the library's own faces, keeping the one thing
/// `NeuBottomNav` gets right about this style: the active destination is a **dish**,
/// not an underline. A full-width bar — a `NeuContainer` on its own default flat face,
/// raised at [neu.NeuThemeData.depth] — holds one equal-share cell per destination,
/// and the chosen cell sinks into [neu.NeuShape.pressed] with its glyph and label in
/// [neu.NeuThemeData.accentColor] — exactly that widget's selected-item pair, read
/// off its own container. That is also what separates this control from the tab
/// strip here: `tabBar` domes the chosen cell (`convex`, raised out of the plane)
/// and floats free of any bar, while a nav bar is a docked slab whose chosen cell
/// presses *into* it. [LanguageNavBarSpec.enabled] is the library's inert state —
/// the cells keep their glyphs and labels and lose their callbacks.
abstract final class NeumorphicNavBarBuilder {
  /// Builds the bar for [spec].
  static Widget build(BuildContext context, LanguageNavBarSpec spec) {
    final theme = LiveTheme.of(context);
    final surface = neu.NeuTheme.of(context);
    final select = spec.enabled ? spec.onChanged : null;
    final inset = theme.token.scale.sizes.xs;
    final barRadius = surface.borderRadius.resolve(Directionality.of(context));
    final cellRadius = BorderRadius.circular(barRadius.topLeft.x <= inset ? 0.0 : barRadius.topLeft.x - inset);

    return SafeArea(
      top: false,
      child: neu.NeuContainer(
        borderRadius: barRadius,
        baseColor: surface.baseColor,
        depth: surface.depth,
        distance: surface.distance,
        padding: EdgeInsets.symmetric(horizontal: inset, vertical: inset),
        child: Row(
          children: [
            for (var index = 0; index < spec.items.length; index++)
              Expanded(
                child: _Cell(
                  item: spec.items[index],
                  selected: index == spec.index,
                  enabled: spec.enabled,
                  onTap: select == null ? null : () => select(index),
                  radius: cellRadius,
                  surface: surface,
                  theme: theme,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const new({
    required this.item,
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.radius,
    required this.surface,
    required this.theme,
  });

  final LiveNavBarItem item;
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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: neu.NeuContainer(
        shape: selected ? neu.NeuShape.pressed : neu.NeuShape.flat,
        borderRadius: radius,
        baseColor: surface.baseColor,
        depth: selected ? surface.depth : 0.0,
        distance: selected ? surface.distance : 0.0,
        padding: EdgeInsets.symmetric(horizontal: theme.token.scale.sizes.sm, vertical: theme.token.scale.sizes.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, color: tint, size: theme.text.body.fontSize),
            SizedBox(height: theme.token.scale.sizes.xs / 2.0),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.text.caption.copyWith(color: tint, fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
            ),
          ],
        ),
      ),
    );
  }
}
