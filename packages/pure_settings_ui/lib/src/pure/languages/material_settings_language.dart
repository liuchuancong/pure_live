import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/pure/pure_settings_palette.dart';
import 'package:pure_settings_ui/src/pure/pure_settings_style.dart';
import 'package:pure_settings_ui/src/vendor/utils/platform_utils.dart' show DevicePlatform;

/// Material's settings theme.
///
/// Its rendering is upstream's Android 16 style: each tile on its own card, two
/// dp apart, twenty dp corners at the ends of a group, colours from the active
/// `ColorScheme`, and no chevron because Android Settings marks a tappable row
/// by making it tappable.
///
/// Forced to the pure rendering instead, Material still separates with its own
/// `Divider` and still lets the row state selection — Material 3 fills a
/// selected list item with `surfaceVariant`, so a card recoloured underneath it
/// would be two fills answering one tap.
const materialSettingsLanguage = SettingsLanguage(
  platform: DevicePlatform.android,
  style: PureSettingsStyle(
    palette: pureSettingsPalette,
    cardPadding: EdgeInsets.zero,
    cardBordered: false,
    rowDividers: true,
  ),
);
