import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_theme.dart';

/// The colors a tile takes from its state. Internal.
extension SettingsTileColors on SettingsThemeData {
  /// The title color: dimmed when disabled, or the selected tile's in the
  /// list pane of a split view.
  Color? titleColorFor({required bool enabled, bool selected = false}) {
    if (!enabled) return inactiveTitleColor;
    return (selected ? selectedTileTextColor : null) ?? settingsTileTextColor;
  }

  /// The color of leading and trailing icons: dimmed when disabled, or the
  /// selected tile's in the list pane of a split view.
  Color? iconColorFor({required bool enabled, bool selected = false}) {
    if (!enabled) return inactiveTitleColor;
    return (selected ? selectedTileIconColor : null) ?? leadingIconsColor;
  }
}
