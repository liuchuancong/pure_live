import 'package:flutter/material.dart';

import 'package:pure_uikit/src/bootstrap/pure_ui_startup_config.dart';
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';

/// The parameters the app widget needs, as one object.
///
/// The spec (§5.2) keeps app-level parameters out of the widget's
/// constructor so they can grow without widening the call site: build a
/// [PureAppConfig] once — usually in the composition root, right after the
/// startup configuration has been resolved — and hand it to
/// `PureApp.fromConfig`.
///
/// The router is deliberately part of this object because its owner is the
/// application bootstrap, not the widget: [routerConfig] is created once
/// before the first frame and every host receives the same instance, which
/// is what makes a design-language change keep the navigation stack.
final class PureAppConfig {
  /// An app-level configuration.
  const new({
    required this.routerConfig,
    required this.startupConfig,
    this.title = '',
    this.onGenerateTitle,
    this.localizationsDelegates = const <LocalizationsDelegate<dynamic>>[],
    this.supportedLocales = const <Locale>[Locale('en')],
    this.locale,
    this.builder,
    this.debugShowCheckedModeBanner = false,
  });

  /// The app-owned router, created once by the route owner and reused by
  /// every host.
  final RouterConfig<Object>? routerConfig;

  /// The startup configuration the process was launched with: [language]
  /// picks the host and, through the frozen configuration below, the look of
  /// every Pure widget.
  final PureUiStartupConfig startupConfig;

  /// The language this process renders with, frozen at startup.
  PureDesignLanguage get language => startupConfig.language;

  /// The window title; ignored when [onGenerateTitle] is given.
  final String title;

  /// Resolves the title once localizations are in scope.
  final GenerateAppTitle? onGenerateTitle;

  /// The delegates every language needs, in priority order.
  final List<LocalizationsDelegate<dynamic>> localizationsDelegates;

  /// The locales the app declares.
  final List<Locale> supportedLocales;

  /// The forced locale; null follows the platform.
  final Locale? locale;

  /// Wraps the navigator — where a translation provider belongs. Every host
  /// invokes it once per frame inside its own theme scope.
  final TransitionBuilder? builder;

  /// Whether the debug banner shows.
  final bool debugShowCheckedModeBanner;
}
