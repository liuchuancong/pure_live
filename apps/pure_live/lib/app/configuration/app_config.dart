/// The app's static configuration: facts fixed at compile time, with no
/// reading, no environment and no I/O.
final class AppConfig {
  /// A configuration.
  const new({required this.appName, required this.channel});

  /// The shipped configuration.
  static const AppConfig standard = AppConfig(appName: 'Pure Live', channel: 'standard');

  /// The name shown in the window title, the tray and the stores.
  final String appName;

  /// The release channel this build was made for.
  final String channel;
}
