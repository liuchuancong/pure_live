import 'package:flutter/material.dart';
import 'package:pure_uikit/src/app/pure_app_host.dart';
import 'package:yaru/yaru.dart' as yaru;

/// The Yaru host: Material 3 wearing Ubuntu's token tables — the same
/// `MaterialApp` host as the Material one, themed by yaru's own factories so
/// the accent seeds Ubuntu's palette and the controls pick up its shapes and
/// motion. The theme fills both slots; the host never re-picks the brightness.
MaterialApp buildYaruAppHost(PureAppHostBinding b) {
  final token = b.theme.token;
  final data = token.isDark
      ? yaru.createYaruDarkTheme(primaryColor: token.color.primary)
      : yaru.createYaruLightTheme(primaryColor: token.color.primary);
  return MaterialApp.router(
    routerConfig: b.routerConfig,
    title: b.title,
    onGenerateTitle: b.onGenerateTitle,
    localizationsDelegates: b.localizationsDelegates,
    supportedLocales: b.supportedLocales,
    locale: b.locale,
    builder: b.builder,
    debugShowCheckedModeBanner: b.debugShowCheckedModeBanner,
    theme: data,
    darkTheme: data,
  );
}
