import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/pure/pure_settings_palette.dart';
import 'package:pure_settings_ui/src/pure/pure_settings_style.dart';
import 'package:pure_settings_ui/src/vendor/utils/platform_utils.dart' show DevicePlatform;
import 'package:pure_settings_ui/src/vendor/utils/settings_theme.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The glass press is one step lighter than the token's default.
///
/// `fillSecondary` is meant to be read against an opaque surface. Composited
/// over a translucent sheet it darkens the blur twice — once in the tint, and
/// once in whatever the sheet then blurs through it — so a pressed row here
/// takes `fillTertiary` instead.
SettingsThemeData _glassPalette(PureTheme theme) =>
    pureSettingsPalette(theme).copyWith(tileHighlightColor: theme.colors.fillTertiary);

/// Glassmorphism's settings theme.
///
/// `GlassCard` is a frosted `GlassContainer` sheet: the surface, the radius, the
/// blur and the stroke are the inherited `GlassTheme`'s, and a selected sheet
/// raises its own opacity rather than changing fill — which is how this style
/// states every active thing. `GlassListTile` separates its rows with the
/// library's own `GlassDivider`.
///
/// The library hardcodes its labels white whatever the brightness, so
/// `PureListRow` re-wraps them in the token's text roles; that correction is
/// pure_uikit's, and this theme has nothing to add to it.
const glassSettingsLanguage = SettingsLanguage(
  platform: DevicePlatform.pure,
  style: PureSettingsStyle(
    palette: _glassPalette,
    cardPadding: EdgeInsets.zero,
    cardBordered: false,
    rowDividers: true,
  ),
);
