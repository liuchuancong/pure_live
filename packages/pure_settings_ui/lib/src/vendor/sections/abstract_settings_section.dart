import 'package:flutter/widgets.dart';

/// Base class for anything `SettingsList.sections` accepts. Use
/// `SettingsSection` or `CustomSettingsSection`.
abstract class AbstractSettingsSection extends StatelessWidget {
  /// Lets subclasses be const.
  const AbstractSettingsSection({super.key});
}
