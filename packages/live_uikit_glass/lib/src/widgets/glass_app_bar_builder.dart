import 'package:flutter/widgets.dart';
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:live_uikit/live_uikit.dart';

/// Builds a frosted top bar from a [LanguageAppBarSpec] (§9 AppBar).
///
/// Composed, not mapped, and measured first: the library does have a
/// `GlassAppBar`, but it is a Material `AppBar` with a frosted `flexibleSpace`
/// pasted into it, and three things stop it being this contract's inline bar. It
/// asserts `No MaterialLocalizations found.` outside a Material host; handed loose
/// constraints it takes the whole window rather than its own `toolbarHeight`
/// (measured: 800x600 where a bar is 56), because only a Material `Scaffold` sizes
/// a `PreferredSizeWidget`; and its `bottom` slot wants a `PreferredSizeWidget`
/// while the spec hands over whatever bar the caller dispatched — a tab strip is a
/// `Row`. So the bar here is the library's *surface* instead: a floating
/// [glass.GlassContainer] sheet, squared along its bottom edge so it closes the
/// header rather than hovering over it, taking its blur, tint, stroke and radius
/// from [glass.GlassTheme] (§8).
///
/// [LanguageAppBarSpec.centerTitle] defaults to centred, because a glass header
/// reads as an iOS-style sheet and centres its title the way that platform does;
/// a caller who wants the desktop reading passes `false`. The title centres
/// within the space the leading widget and the actions leave — this bar has no
/// frame to centre against. [LanguageAppBarSpec.height] maps to the title row;
/// [LanguageAppBarSpec.bottom] stacks under it, and
/// [LanguageAppBarSpec.background] tints the sheet rather than replacing it,
/// because a glass header has no opaque side.
abstract final class GlassAppBarBuilder {
  /// Builds the bar for [spec].
  static Widget build(BuildContext context, LanguageAppBarSpec spec) {
    final theme = LiveTheme.of(context);
    final glassTheme = glass.GlassTheme.of(context);
    final geometry = LiveEnvironmentScope.maybeOf(context)?.geometry;
    final height = spec.height ?? geometry?.appBarHeight ?? 56;
    final padding = geometry?.pagePadding ?? theme.token.scale.sizes.md;
    final gap = theme.token.scale.sizes.sm;
    final center = spec.centerTitle ?? true;
    final radius = glassTheme.borderRadius;

    final row = SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: padding),
        child: Row(
          children: [
            if (spec.leading case final lead?) ...[lead, SizedBox(width: gap)],
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  spec.title,
                  textAlign: center ? TextAlign.center : TextAlign.start,
                  style: theme.text.title.copyWith(color: theme.colors.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            for (final action in spec.actions) ...[SizedBox(width: gap), action],
          ],
        ),
      ),
    );

    return glass.GlassContainer(
      padding: EdgeInsets.symmetric(vertical: theme.token.scale.sizes.xs),
      customBorderRadius: BorderRadius.only(
        topLeft: Radius.circular(radius),
        topRight: Radius.circular(radius),
        bottomLeft: Radius.circular(radius / 2),
        bottomRight: Radius.circular(radius / 2),
      ),
      color: spec.background ?? glassTheme.color,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row,
          if (spec.bottom case final strip?) Padding(padding: EdgeInsets.only(top: gap), child: strip),
        ],
      ),
    );
  }
}
