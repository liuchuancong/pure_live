import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/pure/pure_settings_palette.dart';
import 'package:pure_settings_ui/src/pure/pure_settings_style.dart';
import 'package:pure_settings_ui/src/vendor/utils/platform_utils.dart' show DevicePlatform;

/// macOS's settings theme.
///
/// Its rendering is upstream's macOS 26 System Settings style: 12pt rounded
/// cards on a white or `#1E1E1E` window, 36pt rows (48pt with a leading icon),
/// 13pt semibold headers above the cards, `MacosSettingsSwitch`, and a 640pt
/// content column. No hover highlight — System Settings has none — and pressed
/// rows tint instead.
///
/// Forced to the pure rendering, a macOS row ends at its text and its trailing
/// control sits beside it rather than pinned to the far edge, which is how
/// `MacosListTile` lays out; the card keeps its own inset-grouped edge, so the
/// rows are inset to leave it visible.
const macosSettingsLanguage = SettingsLanguage(
  platform: DevicePlatform.macOS,
  style: PureSettingsStyle(
    palette: pureSettingsPalette,
    cardPadding: EdgeInsets.symmetric(horizontal: 2),
    cardBordered: false,
    rowDividers: true,
  ),
);
