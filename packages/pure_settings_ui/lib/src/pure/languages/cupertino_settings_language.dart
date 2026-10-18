import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/pure/pure_settings_palette.dart';
import 'package:pure_settings_ui/src/pure/pure_settings_style.dart';
import 'package:pure_settings_ui/src/vendor/utils/platform_utils.dart' show DevicePlatform;

/// Cupertino's settings theme.
///
/// Its rendering is upstream's iOS 26 style: 26pt rounded cards with 20pt side
/// margins, 52pt rows, `description` as grey footers outside the card,
/// `CupertinoSettingsSwitch` — the Liquid-Glass lens switch — and a chevron on
/// a navigation tile. Its colours are fixed iOS system colours, deliberately
/// ignoring the app's accent, because iOS Settings does.
///
/// Forced to the pure rendering, a Cupertino row is `CupertinoListTile` inside
/// an inset-grouped section: the rows reach the card's edge because the card's
/// rounded corners clip them, and the separator is the tile's own inset
/// hairline.
const cupertinoSettingsLanguage = SettingsLanguage(
  platform: DevicePlatform.iOS,
  style: PureSettingsStyle(
    palette: pureSettingsPalette,
    cardPadding: EdgeInsets.zero,
    cardBordered: false,
    rowDividers: true,
  ),
);
