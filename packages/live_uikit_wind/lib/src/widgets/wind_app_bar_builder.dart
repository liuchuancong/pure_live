import 'package:flutter/widgets.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:live_uikit/live_uikit.dart';

/// Builds a Wind top bar from a [LanguageAppBarSpec] (§9 AppBar).
///
/// Composed, not mapped: the fork has no bar of any kind. The surface is its own
/// container — a `WDiv` panel in the library's `bg-white dark:bg-gray-900` pair,
/// closed by the `border-b border-gray-200 dark:border-gray-700` hairline that is
/// Tailwind's own header rule — with the title in `WText` at the library's
/// `text-lg font-semibold` step and the actions appended as the widgets the
/// caller already dispatched.
///
/// [LanguageAppBarSpec.height] and [LanguageAppBarSpec.background] are both
/// runtime values, so neither is interpolated into a className (the library
/// caches parsed class strings): the height goes to a `SizedBox` over the title
/// row and the colour override to the container's inline `backgroundColor` hook,
/// which wins over the `bg-*` class when the caller names one.
/// [LanguageAppBarSpec.bottom] — a dispatched tab strip — stacks under the row in
/// the same panel, because a Wind page header is one box with one rule under it.
///
/// [LanguageAppBarSpec.centerTitle] defaults to left, which is what this library's
/// own headers do; asking for the centre is answered with `text-center` on a title
/// that already takes the leftover width, so the glyphs move and the actions stay
/// at the trailing edge.
abstract final class WindAppBarBuilder {
  /// Builds the bar for [spec].
  static Widget build(BuildContext context, LanguageAppBarSpec spec) {
    final theme = LiveTheme.of(context);
    final geometry = LiveEnvironmentScope.maybeOf(context)?.geometry;
    final height = spec.height ?? geometry?.appBarHeight ?? 56;
    final padding = geometry?.pagePadding ?? theme.token.scale.sizes.md;
    final centered = (spec.centerTitle ?? false) ? ' text-center' : '';

    final title = wind.WText(
      spec.title,
      className: 'text-lg font-semibold text-gray-900 dark:text-gray-100 truncate$centered',
    );

    final row = wind.WDiv(
      className: 'flex flex-row items-center gap-2 w-full h-full',
      children: [
        ?spec.leading,
        Expanded(child: title),
        for (final action in spec.actions) action,
      ],
    );

    return wind.WDiv(
      className: 'flex flex-col w-full bg-white dark:bg-gray-900 border-b border-gray-200 dark:border-gray-700',
      backgroundColor: spec.background,
      children: [
        SizedBox(
          height: height,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: padding),
            child: row,
          ),
        ),
        ?spec.bottom,
      ],
    );
  }
}
