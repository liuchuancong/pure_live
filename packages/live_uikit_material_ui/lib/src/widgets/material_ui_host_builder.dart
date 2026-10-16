import 'package:flutter/widgets.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_material_ui/src/theme/material_ui_theme_builder.dart';
import 'package:material_ui/material_ui.dart' as mu;

/// Builds the Material UI app host from a [LanguageHostSpec] (§9 app host).
///
/// The fork ships its own `MaterialApp`, and that is the point of the language:
/// the host installs the fork's theme scope, its ink splash and its selection
/// toolbar, so a page reads Material UI from the window frame down instead of
/// only where a `Live*` widget happens to reach. The SDK host would keep
/// supplying those — which is how a design-language switch ends up changing
/// nothing underneath a set of otherwise-native controls.
abstract final class MaterialUiHostBuilder {
  /// Builds the host for [spec].
  static Widget build(BuildContext context, LanguageHostSpec spec) {
    final theme = MaterialUiThemeBuilder.build(LiveTheme.of(context).token);
    return mu.MaterialApp.router(
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
