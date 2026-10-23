import 'package:pure_live/app/configuration/app_config.dart';
import 'package:pure_live/app/configuration/build_variant.dart' show kBuildVariant;

/// Loads the app configuration.
///
/// Phase one ships the compile-time constants only; when configuration moves
/// to a bundled asset, this is the one function that changes and the callers
/// stay untouched.
Future<AppConfig> loadAppConfig() async {
  return AppConfig(appName: AppConfig.standard.appName, channel: kBuildVariant.name);
}
