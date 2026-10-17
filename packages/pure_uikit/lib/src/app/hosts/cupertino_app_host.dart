import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart' show Brightness;

import 'package:pure_uikit/src/app/pure_app_host.dart';

/// The Cupertino host: `CupertinoApp.router` is the only thing that gives a
/// Cupertino page its iOS behaviour — the slide-from-right route, the
/// swipe-back gesture, the scroll physics and the text-selection toolbar. It
/// takes one theme rather than a light and a dark slot, which suits the
/// binding: the resolved theme already carries the chosen brightness.
cupertino.CupertinoApp buildCupertinoAppHost(PureAppHostBinding b) {
  final token = b.theme.token;
  return cupertino.CupertinoApp.router(
    routerConfig: b.routerConfig,
    title: b.title,
    onGenerateTitle: b.onGenerateTitle,
    localizationsDelegates: b.localizationsDelegates,
    supportedLocales: b.supportedLocales,
    locale: b.locale,
    builder: b.builder,
    theme: cupertino.CupertinoThemeData(
      brightness: token.isDark ? Brightness.dark : Brightness.light,
      primaryColor: token.color.primary,
      primaryContrastingColor: token.color.onPrimary,
      scaffoldBackgroundColor: token.color.surface,
    ),
    debugShowCheckedModeBanner: b.debugShowCheckedModeBanner,
  );
}
