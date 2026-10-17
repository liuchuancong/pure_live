import 'package:flutter/material.dart';
import 'package:pure_uikit/src/app/pure_app_host.dart';
import 'package:pure_uikit/src/styling/adapters/material_theme_adapter.dart';

/// The Material host: `MaterialApp.router` themed by a seeded [ThemeData].
///
/// Installs the fork's theme scope, its ink splash and its selection toolbar,
/// so a page reads Material from the window frame down. The theme slot is
/// filled with the same resolved data in both the light and the dark slot —
/// the token already picked the brightness, so the host must not re-pick it
/// from the platform. The builder runs once per frame inside the theme scope.
MaterialApp buildMaterialAppHost(PureAppHostBinding b) {
  final data = const MaterialThemeAdapter().resolve(b.theme);
  return MaterialApp.router(
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
