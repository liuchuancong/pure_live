import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/pure/pure_settings_palette.dart';
import 'package:pure_settings_ui/src/pure/pure_settings_style.dart';
import 'package:pure_settings_ui/src/vendor/utils/platform_utils.dart' show DevicePlatform;

/// Fluent's settings theme.
///
/// Its rendering is upstream's Windows 11 style: one card per tile with four px
/// corners and a hairline border, 3px apart, 70px minimum height, 14px titles,
/// 12px grey descriptions, `FluentSettingsSwitch`, hover, pressed and focus
/// states on clickable cards, and a 1000px column.
///
/// Forced to the pure rendering, `FluentList` owns its items — selection,
/// keyboard handling and the roving focus are the list's, not the row's — so
/// this is the theme that draws no separator of its own: Windows 11 gives a
/// card its breathing room with margins, not with a line through it.
const fluentSettingsLanguage = SettingsLanguage(
  platform: DevicePlatform.windows,
  style: PureSettingsStyle(
    palette: pureSettingsPalette,
    cardPadding: EdgeInsets.zero,
    cardBordered: false,
    rowDividers: false,
  ),
);
