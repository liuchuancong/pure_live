import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// The one contract of the theme adapter layer: turn the resolved
/// [PureTheme] into the theme object a third-party UI library consumes.
///
/// An adapter is a pure function of the theme — it never reads the persisted
/// configuration, the system brightness, an app provider or the platform.
/// Whatever a library cannot map stays unmapped and is said so in the
/// adapter's docs; an adapter never fakes support.
abstract interface class PureThemeAdapter<TTheme> {
  /// Resolves the library's theme object for [theme].
  TTheme resolve(PureTheme theme);
}
