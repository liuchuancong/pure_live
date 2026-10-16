import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:live_uikit/live_uikit.dart';

/// Builds a frosted toast surface from a [LanguageToastSpec] (§9 Toast).
///
/// Composed, not mapped: the library has no message widget, so the pill is a
/// [glass.GlassContainer] sheet — its blur, tint, corner radius and stroke all the
/// values [glass.GlassTheme] publishes (§8) — with the status glyph in the token's
/// status colour and the message in the token's body role. Glass marks severity on
/// the glyph and the tint rather than on a solid fill, because a translucent
/// surface cannot hold a Material-style colour block without ceasing to be glass.
///
/// Only the surface is built here. The overlay it floats in, the fade and the
/// removal timer belong to the core's `LiveToast.show`, which is why the spec's
/// [LanguageToastSpec.duration] is not read by this builder (§9).
abstract final class GlassToastBuilder {
  /// Builds the toast surface for [spec].
  static Widget build(BuildContext context, LanguageToastSpec spec) {
    final theme = LiveTheme.of(context);
    final glassTheme = glass.GlassTheme.of(context);
    final sizes = theme.token.scale.sizes;
    final accent = spec.accent ?? _accent(theme, spec.type);

    return glass.GlassContainer(
      padding: EdgeInsets.symmetric(horizontal: sizes.md, vertical: sizes.sm),
      elevation: 6,
      shadowColor: glassTheme.shadowColor ?? theme.colors.shadowBase,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(spec.icon ?? _glyph(spec.type), color: accent, size: theme.text.body.fontSize),
          SizedBox(width: sizes.sm),
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
