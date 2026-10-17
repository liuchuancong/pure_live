import 'package:flutter/material.dart' show Brightness;
import 'package:macos_ui/macos_ui.dart' as macos;

import 'package:pure_uikit/src/app/pure_app_host.dart';

/// The macOS host: `MacosApp.router` owns what a macOS window feels like —
/// the cupertino route stack, the window-active/inactive tinting the library
/// tracks, the overlay a sheet opens into and the desktop accent colour it
/// reads from the platform. The window canvas follows the resolved surface;
/// the theme fills both slots so the host never re-picks the brightness.
macos.MacosApp buildMacosAppHost(PureAppHostBinding b) {
  final token = b.theme.token;
  final data = macos.MacosThemeData(
    brightness: token.isDark ? Brightness.dark : Brightness.light,
    primaryColor: token.color.primary,
    canvasColor: token.color.surface,
  );
  return macos.MacosApp.router(
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
