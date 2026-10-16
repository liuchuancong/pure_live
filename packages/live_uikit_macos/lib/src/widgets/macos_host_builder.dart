import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_macos/src/theme/macos_theme_builder.dart';
import 'package:macos_ui/macos_ui.dart' as macos;

/// Builds the macOS app host from a [LanguageHostSpec] (§9 app host).
///
/// `MacosApp` is the library's host, and it owns what a macOS window feels
/// like: the cupertino route stack, the window-active/inactive tinting the
/// library tracks, the overlay a sheet opens into and the desktop accent colour
/// it reads from the platform. Under a Material host the controls would be
/// macOS and the behaviour Material.
abstract final class MacosHostBuilder {
  /// Builds the host for [spec].
  static Widget build(BuildContext context, LanguageHostSpec spec) {
    final theme = MacosThemeBuilder.build(LiveTheme.of(context).token);
    return macos.MacosApp.router(
      routerConfig: spec.routerConfig,
      title: spec.title,
      onGenerateTitle: spec.onGenerateTitle,
      localizationsDelegates: spec.localizationsDelegates,
      supportedLocales: spec.supportedLocales,
      locale: spec.locale,
      builder: spec.builder,
      // Both slots carry the token's one resolved theme, so the host cannot
      // second-guess the brightness the appearance setting already chose.
      theme: theme,
      darkTheme: theme,
      debugShowCheckedModeBanner: spec.debugShowCheckedModeBanner,
    );
  }
}
