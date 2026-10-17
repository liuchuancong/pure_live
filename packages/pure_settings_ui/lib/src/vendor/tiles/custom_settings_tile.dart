import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/vendor/tiles/abstract_settings_tile.dart';

/// Shows [child] as a tile, as it is.
///
/// Inside a `SettingsList`, `SettingsTheme.of(context)` gives the resolved
/// colors and style.
class CustomSettingsTile extends AbstractSettingsTile {
  /// Creates a tile that shows [child].
  const CustomSettingsTile({required this.child, super.key});

  /// The widget to show in place of a tile.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
