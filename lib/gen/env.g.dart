/// Generated file. Do not edit.
///
/// To regenerate, run: `dart run enven --env-files .env,.env.prod --class-name AppConfig`
class AppConfig {
  /// Override this instance to mock the environment.
  /// Example: `AppConfig.instance = MockAppConfigData();`
  static AppConfigData instance = AppConfigData();

  static String get pureliveUpdateOwner => instance.pureliveUpdateOwner;
  static String get pureliveUpdateRepository => instance.pureliveUpdateRepository;
}

class AppConfigData {
  final String pureliveUpdateOwner = 'wzgrx';

  final String pureliveUpdateRepository = 'pure_live';
}
