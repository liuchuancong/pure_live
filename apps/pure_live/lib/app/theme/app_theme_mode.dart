import 'package:desen_ui/desen_ui.dart';

/// How the app picks between light and dark.
enum AppThemeMode {
  /// Follow the platform's switch.
  system,

  /// Always light.
  light,

  /// Always dark.
  dark;

  /// The `desen_ui` setting this mode turns into.
  DsThemeMode get dsThemeMode => switch (this) {
    AppThemeMode.system => DsThemeMode.system,
    AppThemeMode.light => DsThemeMode.light,
    AppThemeMode.dark => DsThemeMode.dark,
  };
}
