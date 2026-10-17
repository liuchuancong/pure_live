import 'package:fluent_2/fluent_2.dart' as f2;
import 'package:flutter/material.dart' show Brightness;

import 'package:pure_uikit/src/app/pure_app_host.dart';

/// The Fluent host: `FluentApp` wraps `WidgetsApp` — not `MaterialApp`, so
/// nothing in the tree pulls in Material — and supplies the `FluentTheme`,
/// the Fluent page transitions and the Fluent scrollbar. The brand ramp is
/// generated from the binding's accent colour with Fluent's own generator
/// (this is the one place each language may speak its native palette
/// dialect: Material seeds a colour scheme, Fluent grows a brand ramp, and
/// that difference *is* each design language), so an accent change re-brands
/// the whole fluent subtree. The theme fills both slots; the host never
/// re-picks the brightness.
f2.FluentApp buildFluentAppHost(PureAppHostBinding b) {
  final token = b.theme.token;
  final data = f2.FluentThemeData.from(
    brightness: token.isDark ? Brightness.dark : Brightness.light,
    brand: f2.FluentBrandRamp.fromKeyColor(token.color.primary),
  );
  return f2.FluentApp.router(
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
