import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:live_uikit/live_uikit.dart';

/// Builds a Wind toast surface from a [LanguageToastSpec] (§9 Toast).
///
/// Composed, not mapped: the fork has no transient message widget at all, and the
/// core keeps the rest of one anyway — the overlay it is placed in, the
/// fade-and-slide and the dismissal timer are `LiveToast.show`'s, which is why
/// [LanguageToastSpec.duration] is not read here. What the language decides is the
/// pill, and the pill is Wind's own floating panel: `WCard` — the library's surface
/// container — with `rounded-2xl shadow-lg border` and its `bg-white
/// dark:bg-gray-800` elevated pair, and the message in `WText` at the library's own
/// `text-sm` step, sharing the row with the glyph through `gap-2`.
///
/// The status colour is the token's, not the library's: `warning` has to look like
/// this app's `warning` in every language, and Wind's palette names nothing the
/// token calls a status. It arrives through the fork's own runtime-colour channel —
/// `WIcon.foregroundColor`, the prop its widgets document for a colour that is not a
/// static class token — so the glyph is the one coloured thing on a surface that is
/// otherwise the library's. The message keeps the panel's cascaded tone.
abstract final class WindToastBuilder {
  /// Builds the toast surface for [spec].
  static Widget build(BuildContext context, LanguageToastSpec spec) {
    final theme = LiveTheme.of(context);
    final accent = spec.accent ?? _accent(theme, spec.type);
    return wind.WCard(
      className:
          'rounded-2xl shadow-lg border bg-white dark:bg-gray-800 border-gray-200 dark:border-gray-700'
          ' text-gray-900 dark:text-gray-100',
      child: wind.WDiv(
        className: 'flex flex-row items-center gap-2 px-4 py-2',
        children: [
          wind.WIcon(spec.icon ?? _glyph(spec.type), className: 'text-sm', foregroundColor: accent),
          wind.WText(spec.message, className: 'text-sm shrink'),
        ],
      ),
    );
  }

  static Color _accent(LiveTheme theme, LiveToastType type) => switch (type) {
    LiveToastType.info => theme.colors.info,
    LiveToastType.success => theme.colors.success,
    LiveToastType.warning => theme.colors.warning,
    LiveToastType.error => theme.colors.error,
  };

  static IconData _glyph(LiveToastType type) => switch (type) {
    LiveToastType.info => Icons.info_outline,
    LiveToastType.success => Icons.check_circle_outline,
    LiveToastType.warning => Icons.warning_amber_rounded,
    LiveToastType.error => Icons.error_outline,
  };
}
