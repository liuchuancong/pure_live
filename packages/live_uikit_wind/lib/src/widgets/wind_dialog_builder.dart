import 'package:flutter/widgets.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:live_uikit/live_uikit.dart';

/// Builds a Wind dialog surface from a [LanguageDialogSpec] (§9 Dialog).
///
/// Composed, not mapped: `fluttersdk_wind` 1.8.4 ships no dialog, no modal and no
/// overlay host at all — it is a styling library — and the one floating panel it
/// does have, `WPopover`, is anchored to a widget rather than centred over the
/// page, so it cannot be the surface a route presents. The panel is therefore the
/// library's own elevated container doing the job a dialog surface does: a `WCard`
/// carrying `rounded-xl shadow-xl border` over the `bg-white dark:bg-gray-900`
/// pair and `border-gray-200 dark:border-gray-700` hairline, its content laid out
/// by a `flex flex-col` `WDiv` with the library's own spacing step (`gap-4`) and
/// padding (`p-6`), the heading at its `text-lg font-semibold` type step.
///
/// Only the surface lives here. The route, the barrier colour, the fade-and-scale
/// and the dismissal are core's `showLiveDialog`, which already frames what it is
/// handed (`Center → Padding → ConstrainedBox(maxWidth)`), so this builder starts
/// no overlay, adds no `Center` and does not read
/// [LanguageDialogSpec.dismissible] — that is the barrier's knob, not the
/// surface's.
///
/// Colour again comes from the token, not from a class: a dialog icon has to read
/// as this app's accent in every language, and Wind's palette names nothing the
/// token calls an accent role, so the glyph rides the fork's documented runtime
/// colour channel (`WIcon.foregroundColor`, the prop for a colour that is not a
/// static class token) while the panel and the type stay the library's own. The
/// actions are dispatched controls already, so right-aligning them is the only
/// thing the language has to say about them.
abstract final class WindDialogBuilder {
  /// Builds the surface for [spec].
  static Widget build(BuildContext context, LanguageDialogSpec spec) {
    final theme = LiveTheme.of(context);
    return wind.WCard(
      className:
          'rounded-xl shadow-xl border bg-white dark:bg-gray-900 border-gray-200 dark:border-gray-700'
          ' text-gray-900 dark:text-gray-100',
      child: wind.WDiv(
        className: 'flex flex-col gap-4 p-6',
        children: [
          if (spec.icon case final glyph?)
            wind.WIcon(glyph, className: 'text-xl', foregroundColor: theme.colors.primary),
          if (spec.title case final heading?) wind.WText(heading, className: 'text-lg font-semibold'),
          ?spec.content,
          if (spec.actions.isNotEmpty)
            wind.WDiv(className: 'flex flex-row wrap justify-end gap-2', children: spec.actions),
        ],
      ),
    );
  }
}
