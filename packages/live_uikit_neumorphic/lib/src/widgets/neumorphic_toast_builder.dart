import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:live_uikit/live_uikit.dart';

/// Builds a Neumorphic toast surface from a [LanguageToastSpec] (§9 Toast).
///
/// **Composed, and only the surface.** `flutter_neumorphic_ui_kit` ships no
/// transient message: its widgets are all planes a caller places. The core's
/// `LiveToast.show` keeps the overlay, the fade and the removal timer, because
/// every language wants the same behaviour there, so what this method must return
/// is a widget that renders inline — no `ScaffoldMessenger`, no `Navigator`, no
/// overlay controller, no animated ancestor handed down by someone else. That is
/// also why the plane is a `NeuContainer` on its own default flat face rather
/// than a `SnackBar`-shaped thing: the pill is the only part the language gets to
/// decide.
///
/// [LanguageToastSpec.duration] is therefore unread here — the timer is the core's
/// — and so is any placement. The colour of the glyph is the token's status role
/// (`info`/`success`/`warning`/`error`), because the token decides that a warning
/// looks like *this* app's warning in every language; the plane under it, its
/// radius and its depth are the library's own [neu.NeuThemeData].
abstract final class NeumorphicToastBuilder {
  /// Builds the toast surface for [spec].
  static Widget build(BuildContext context, LanguageToastSpec spec) {
    final theme = LiveTheme.of(context);
    final surface = neu.NeuTheme.of(context);
    final accent = spec.accent ?? _accent(theme, spec.type);
    final glyph = spec.icon ?? _glyph(spec.type);

    return neu.NeuContainer(
      baseColor: surface.baseColor,
      borderRadius: surface.borderRadius,
      depth: surface.depth,
      distance: surface.distance,
      padding: EdgeInsets.symmetric(horizontal: theme.token.scale.sizes.md, vertical: theme.token.scale.sizes.sm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(glyph, color: accent, size: theme.text.body.fontSize),
          SizedBox(width: theme.token.scale.sizes.sm),
          Flexible(
            child: Text(spec.message, style: theme.text.body.copyWith(color: theme.colors.text)),
          ),
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
