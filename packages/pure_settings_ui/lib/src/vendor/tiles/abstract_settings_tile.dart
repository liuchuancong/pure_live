import 'package:flutter/widgets.dart';

/// Base class for anything `SettingsSection.tiles` accepts. Use
/// `SettingsTile` or `CustomSettingsTile`.
abstract class AbstractSettingsTile extends StatelessWidget {
  /// Lets subclasses be const.
  const AbstractSettingsTile({super.key});
}
