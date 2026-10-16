import 'package:flutter/widgets.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:live_uikit/live_uikit.dart';

/// Builds a Neumorphic segmented control from a [LanguageSegmentedSpec]
/// (§9 Segmented).
///
/// **Composed, not mapped.** `flutter_neumorphic_ui_kit` ships no segmented
/// track: its surfaces are button, card, container, field, switch, checkbox,
/// slider, progress, app bar and bottom nav, none of which is "one choice out of
/// a row". The style answers that question with depth rather than with colour
/// fill, so the group is built out of the library's own primitives — a recessed
/// dish (`NeuContainer` in [neu.NeuShape.pressed]) holding one cell per segment,
/// where the chosen cell is the same plane pushed back out as a dome
/// ([neu.NeuShape.convex]) at [neu.NeuThemeData.depth]. That is the library's own
/// idle/pressed pair (`NeuButton`, `NeuBottomNav`'s active item) read as a
/// selection instead of as a touch, and the selected label takes
/// [neu.NeuThemeData.accentColor] the way its bottom bar tints the active item.
///
/// Radii come from the theme: the track takes [neu.NeuThemeData.borderRadius] and
/// a cell takes that radius minus the track's inset, so the dome nests inside the
/// dish instead of clipping it. [LanguageSegmentedSpec.expand] gives every cell an
/// equal share of the row; a disabled group is cells with no callback and the
/// token's disabled text role, which is the library's inert state.
abstract final class NeumorphicSegmentedBuilder {
  /// Builds the segmented track for [spec].
  static Widget build(BuildContext context, LanguageSegmentedSpec spec) {
    final theme = LiveTheme.of(context);
    final surface = neu.NeuTheme.of(context);
    final select = spec.enabled ? spec.onChanged : null;
    final inset = theme.token.scale.sizes.xs;
    final trackRadius = surface.borderRadius.resolve(Directionality.of(context));
    final cellRadius = BorderRadius.circular(trackRadius.topLeft.x <= inset ? 0.0 : trackRadius.topLeft.x - inset);

    Widget cell(int index) => _Cell(
      label: spec.labels[index],
      selected: index == spec.index,
      enabled: spec.enabled,
      onTap: select == null ? null : () => select(index),
      radius: cellRadius,
      surface: surface,
      theme: theme,
    );

    return neu.NeuContainer(
      shape: neu.NeuShape.pressed,
      borderRadius: trackRadius,
      baseColor: surface.baseColor,
      depth: 2.5,
      padding: EdgeInsets.all(inset),
      child: Row(
        mainAxisSize: spec.expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (var index = 0; index < spec.labels.length; index++)
            if (spec.expand) Expanded(child: cell(index)) else cell(index),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const new({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.radius,
    required this.surface,
    required this.theme,
  });

  final String label;
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
      tint = theme.colors.text;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: neu.NeuContainer(
        shape: selected ? neu.NeuShape.convex : neu.NeuShape.flat,
        borderRadius: radius,
        baseColor: surface.baseColor,
        depth: selected ? surface.depth : 0.0,
        distance: selected ? surface.distance : 0.0,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: theme.token.scale.sizes.md, vertical: theme.token.scale.sizes.sm),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: selected
              ? theme.text.body.copyWith(color: tint, fontWeight: FontWeight.w600)
              : theme.text.body.copyWith(color: tint),
        ),
      ),
    );
  }
}
