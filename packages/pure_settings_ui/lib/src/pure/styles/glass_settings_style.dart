import 'package:flutter/widgets.dart';
import 'package:pure_uikit/pure_uikit.dart';
import 'package:pure_settings_ui/pure_settings_ui.dart';
import 'package:pure_settings_ui/src/pure/pure_settings_style.dart';
import 'package:pure_settings_ui/src/pure/styles/pure_settings_base_style.dart';

/// Glassmorphism's settings style.
///
/// `GlassCard` is a frosted `GlassContainer` sheet: the surface, the radius,
/// the blur and the stroke are the inherited `GlassTheme`'s, and a selected
/// sheet raises its own opacity rather than changing fill. So the rows go edge
/// to edge over the sheet, and `GlassListTile` separates them with the
/// library's own `GlassDivider`.
///
/// The one colour that cannot stay the token's default is the pressed-row tint.
/// `fillSecondary` is meant to be read against an opaque surface; composited
/// over a translucent sheet it darkens the blur twice — once in the tint, once
/// in whatever the sheet then blurs — so this style presses one step lighter.
SettingsThemeData _glassPalette(PureTheme theme) => pureSettingsTokenPalette(theme).copyWith(
  tileHighlightColor: theme.colors.fillTertiary,
);

/// The glass style.
const PureSettingsStyle glassSettingsStyle = PureSettingsStyle(
  name: 'glass',
  palette: _glassPalette,
  cardPadding: EdgeInsets.zero,
  rowDividers: true,
  tintsSelectedCard: true,
);
