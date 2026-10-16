import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_fluent/src/theme/fluent_theme_builder.dart';

/// Builds the Fluent app host from a [LanguageHostSpec] (§9 app host).
///
/// `FluentApp` is the library's own host, and it is what makes a Fluent page
/// behave like Windows rather than merely look like it for one frame: the route
/// transition, the overlay a `ContentDialog` or `Flyout` opens into, the Fluent
/// scrollbar and the navigation-view strings all come from here. Hosting the
/// same tree in `MaterialApp` instead would keep Material's page slide, its
/// dialog barrier and its ink splash underneath the Fluent controls.
abstract final class FluentHostBuilder {
  /// Builds the host for [spec].
  static Widget build(BuildContext context, LanguageHostSpec spec) {
    final theme = FluentThemeBuilder.build(LiveTheme.of(context).token);
    return fluent.FluentApp.router(
      routerConfig: spec.routerConfig,
      title: spec.title,
      onGenerateTitle: spec.onGenerateTitle,
      localizationsDelegates: spec.localizationsDelegates,
      supportedLocales: spec.supportedLocales,
      locale: spec.locale,
      builder: spec.builder,
      // The token has already picked the brightness, so both slots carry the
      // same resolved theme: the host must not re-pick it from the platform.
      theme: theme,
      darkTheme: theme,
      debugShowCheckedModeBanner: spec.debugShowCheckedModeBanner,
    );
  }
}
