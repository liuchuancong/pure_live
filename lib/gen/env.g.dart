/// Generated file. Do not edit.
///
/// To regenerate, run: `dart run enven`
class AppConfig {
  /// Override this instance to mock the environment.
  /// Example: `AppConfig.instance = MockAppConfigData();`
  static AppConfigData instance = AppConfigData();

  static String get pureliveUpdateOwner => instance.pureliveUpdateOwner;
  static String get pureliveUpdateRepository => instance.pureliveUpdateRepository;
  static String get pureliveNativeOwner => instance.pureliveNativeOwner;
  static String get pureliveNativeRepository => instance.pureliveNativeRepository;
  static String get pureliveTvRepository => instance.pureliveTvRepository;
}

class AppConfigData {
  final String pureliveUpdateOwner = 'liuchuancong';

  final String pureliveUpdateRepository = 'pure_live';

  final String pureliveNativeOwner = 'wzgrx';

  final String pureliveNativeRepository = 'pure_live';

  final String pureliveTvRepository = 'pure_live_TV';
}
