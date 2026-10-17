import 'package:flutter/widgets.dart';
import 'package:pure_settings_ui/src/vendor/sections/abstract_settings_section.dart';

/// Shows [child] as a section, as it is.
///
/// Inside a `SettingsList`, `SettingsTheme.of(context)` gives the resolved
/// colors and style.
class CustomSettingsSection extends AbstractSettingsSection {
  /// Creates a section that shows [child].
  const CustomSettingsSection({required this.child, super.key});

  /// The widget to show in place of a section.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
