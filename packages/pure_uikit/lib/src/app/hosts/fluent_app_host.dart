import 'package:fluent_ui/fluent_ui.dart' as fluent;

import 'package:pure_uikit/src/app/pure_app_host.dart';
import 'package:pure_uikit/src/styling/adapters/fluent_theme_adapter.dart';

/// The Fluent host: fluent_ui's `FluentApp.router` owns the route stack's
/// chrome — the `FluentTheme`, the Fluent page transitions, the Fluent
/// scrollbar and Fluent's localizations — so a page reads Fluent from the
/// window frame down. The theme fills both the light and the dark slot: the
/// token already picked the brightness, so the host never re-picks it from
/// the platform. The builder runs once per frame inside the theme scope, so
/// a brightness, accent, font or density change re-skins the host along with
/// everything under it.
fluent.FluentApp buildFluentAppHost(PureAppHostBinding b) {
  final data = const FluentThemeAdapter().resolve(b.theme);
  return fluent.FluentApp.router(
    routerConfig: b.routerConfig,
    title: b.title,
    onGenerateTitle: b.onGenerateTitle,
    localizationsDelegates: b.localizationsDelegates,
    supportedLocales: b.supportedLocales,
    locale: b.locale,
    builder: b.builder,
    theme: data,
    darkTheme: data,
    debugShowCheckedModeBanner: b.debugShowCheckedModeBanner,
  );
}
