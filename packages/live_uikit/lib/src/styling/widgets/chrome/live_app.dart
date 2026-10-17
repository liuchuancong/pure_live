import 'package:flutter/material.dart';

import 'package:live_uikit/src/styling/contracts/live_ui_adapter.dart';
import 'package:live_uikit/src/styling/provider/live_config_provider.dart';

/// The public host: a thin dispatcher to the active language adapter.
///
/// It replaces the app's own `MaterialApp.router`. Leaving that in place is what
/// makes a design-language switch look like nothing has changed: the host, not
/// the controls, decides how a route slides in, where a dialog's barrier lives
/// and which library's strings the selection toolbar reads.
class LiveApp extends StatelessWidget {
  /// A host over [routerConfig].
  const new({
    required this.routerConfig,
    this.title = '',
    this.onGenerateTitle,
    this.localizationsDelegates = const <LocalizationsDelegate<dynamic>>[],
    this.supportedLocales = const <Locale>[Locale('en')],
    this.locale,
    this.builder,
    this.debugShowCheckedModeBanner = false,
    super.key,
  });

  /// The router the app runs on.
  final RouterConfig<Object>? routerConfig;

  /// The window title; ignored when [onGenerateTitle] is given.
  final String title;

  /// Resolves the title once localizations are in scope.
  final GenerateAppTitle? onGenerateTitle;

  /// The delegates every language below needs, in priority order.
  final List<LocalizationsDelegate<dynamic>> localizationsDelegates;

  /// The locales the app declares.
  final List<Locale> supportedLocales;

  /// The forced locale; null follows the platform.
  final Locale? locale;

  /// Wraps the navigator — where a translation provider belongs.
  final TransitionBuilder? builder;

  /// Whether the debug banner shows.
  final bool debugShowCheckedModeBanner;

  @override
  Widget build(BuildContext context) => LiveTheme.of(context).adapter.appHost(
    context,
    LanguageHostSpec(
      routerConfig: routerConfig,
      title: title,
      onGenerateTitle: onGenerateTitle,
      localizationsDelegates: localizationsDelegates,
      supportedLocales: supportedLocales,
      locale: locale,
      builder: builder,
      debugShowCheckedModeBanner: debugShowCheckedModeBanner,
    ),
  );
}
