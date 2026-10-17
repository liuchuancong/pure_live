import 'package:flutter/widgets.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_wind/src/theme/wind_theme_builder.dart';

/// Builds a Wind application host from a [LanguageHostSpec] (§ surfaces).
///
/// `fluttersdk_wind` 1.8.4 ships no application widget at all — the library is a
/// Tailwind-style theme plus a set of styled parts, and nothing in it owns a
/// route, a title or a locale — so the host is Flutter's own `WidgetsApp` with
/// Wind's theme installed above the routed tree.
///
/// That is a real host and a Wind one. The app widget is what decides the page
/// transition, the scroll physics and the dialog barrier colour of every page
/// below it, so a Wind page living inside a Material one keeps behaving like
/// Material however `WDiv`/`WText`/`WButton` draw its controls.
/// `WidgetsApp` hands none of that to Material either: the transitions come from
/// the router, the physics from the platform, the barrier from the route. The
/// only thing Wind cannot do for itself is supply the strings and the local
/// ordering `WidgetsApp` asks the app for, which is why
/// [LanguageHostSpec.localizationsDelegates] has to carry them and the
/// composition root installs them for every language up front.
abstract final class WindHostBuilder {
  /// Builds the host for [spec].
  static Widget build(BuildContext context, LanguageHostSpec spec) {
    final theme = WindThemeBuilder.build(LiveTheme.of(context).token);
    return WidgetsApp.router(
      routerConfig: spec.routerConfig,
      title: spec.title,
      onGenerateTitle: spec.onGenerateTitle,
      localizationsDelegates: spec.localizationsDelegates,
      supportedLocales: spec.supportedLocales,
      locale: spec.locale,
      // The theme scope is the outermost thing inside the app so a route's own
      // overlay content — a dialog body, a text-selection toolbar — still
      // resolves Wind's Tailwind maps; the caller's builder (the ink host and the
      // translation scope) stays inside it.
      builder: (context, child) => wind.WindTheme(
        data: theme,
        // The app widget hands its builder a child it has not built yet when the
        // router has nothing to show; the theme scope still has to wrap something.
        child: spec.builder?.call(context, child) ?? child ?? const SizedBox.shrink(),
      ),
      // `WidgetsApp` asks for one colour outright; it is the token's accent, so
      // the host's own chrome (a scrollbar thumb, a text selection) is on-theme
      // even where no Wind part paints it.
      color: LiveTheme.of(context).colors.primary,
      debugShowCheckedModeBanner: spec.debugShowCheckedModeBanner,
    );
  }
}
