import 'package:flutter/widgets.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_glass/src/theme/glass_theme_scope.dart';

/// Builds a Glass application host from a [LanguageHostSpec] (§ surfaces).
///
/// `glass_morphism_plus` ships no application widget — the library is a theme and
/// a set of frosted surfaces, and nothing in it owns a route, a title or a locale
/// — so the host is Flutter's own `WidgetsApp` with this language's [GlassThemeScope]
/// installed above the routed tree.
///
/// That is still this language's host and not the shared one, which is the point
/// of the surface (§9 app host). The shared base hosts everything in a
/// `MaterialApp`, and an app widget — not the controls — is what decides how a
/// route slides in, which physics a scroll view obeys and where a dialog's modal
/// barrier lives: on the Material host every Glass page transitioned, scrolled
/// and dimmed like Material however its buttons were drawn. `WidgetsApp` asks
/// nothing of Material and gives nothing to it, so all three now come from the
/// widgets-layer defaults, and the surface the barrier covers is the library's
/// own frosted one.
///
/// [LanguageHostSpec.localizationsDelegates] carries what the app needs from
/// here: with no Material application widget above, the strings Glass's composed
/// controls and its `TextFormField` field ask for have to arrive through that
/// list, and the composition root installs them for every language up front.
abstract final class GlassHostBuilder {
  /// Builds the host for [spec].
  static Widget build(BuildContext context, LanguageHostSpec spec) {
    final theme = LiveTheme.of(context);
    return WidgetsApp.router(
      routerConfig: spec.routerConfig,
      title: spec.title,
      onGenerateTitle: spec.onGenerateTitle,
      localizationsDelegates: spec.localizationsDelegates,
      supportedLocales: spec.supportedLocales,
      locale: spec.locale,
      // The theme scope is the outermost thing inside the app so a route's own
      // overlay content resolves it too; the caller's builder — the ink surface
      // and the translation scope — stays inside it.
      builder: (context, child) => GlassThemeScope(
        token: theme.token,
        // The app widget hands its builder a child it has not built yet when the
        // router has nothing to show; the theme scope still has to wrap
        // something.
        child: spec.builder?.call(context, child) ?? child ?? const SizedBox.shrink(),
      ),
      // `WidgetsApp` asks for one colour outright; it is the token's accent, so
      // the host's own chrome (a scrollbar thumb, a selection handle) is on-theme
      // even where no glass surface paints it.
      color: theme.colors.primary,
      debugShowCheckedModeBanner: spec.debugShowCheckedModeBanner,
    );
  }
}
