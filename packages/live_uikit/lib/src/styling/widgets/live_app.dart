import 'package:flutter/material.dart';

import 'package:live_uikit/src/styling/contracts/live_ui_adapter.dart';
import 'package:live_uikit/src/styling/root/live_config_provider.dart';

/// The token-driven host: a Material app whose scheme comes from the resolved
/// token, standing in for a language whose library ships no app widget of its
/// own (ForUI, Glass, Neumorphic and Wind are all of that kind).
///
/// It is the fallback, not the default: a language that has a real host gets
/// [LanguageAdapter.host] overridden and this never runs, so the router's
/// transitions, the overlay dialogs open into and the chrome strings all come
/// from the library the page controls come from.
class TokenApp extends StatelessWidget {
  /// A Material host built from [spec].
  const new({required this.spec, super.key});

  /// The host configuration.
  final LanguageHostSpec spec;

  @override
  Widget build(BuildContext context) {
    final theme = LiveTheme.of(context);
    final seed = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: theme.colors.primary,
        brightness: theme.token.isDark ? Brightness.dark : Brightness.light,
      ),
      scaffoldBackgroundColor: theme.colors.bgLayout,
      fontFamily: theme.text.body.fontFamily,
      fontFamilyFallback: theme.text.body.fontFamilyFallback,
    );
    return MaterialApp.router(
      routerConfig: spec.routerConfig,
      title: spec.title,
      onGenerateTitle: spec.onGenerateTitle,
      localizationsDelegates: spec.localizationsDelegates,
      supportedLocales: spec.supportedLocales,
      locale: spec.locale,
      builder: spec.builder,
      theme: seed,
      debugShowCheckedModeBanner: spec.debugShowCheckedModeBanner,
    );
  }
}

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
  Widget build(BuildContext context) => LiveTheme.of(context).adapter.host(
    context,
    LanguageHostSpec(
      routerConfig: routerConfig,
      title: title,
      onGenerateTitle: onGenerateTitle,
      localizationsDelegates: localizationsDelegates,
      supportedLocales: supportedLocales,
      locale: locale,
      builder: _inkHost,
      debugShowCheckedModeBanner: debugShowCheckedModeBanner,
    ),
  );

  /// Gives the routes an ink host whatever the library above them is.
  ///
  /// A Fluent, macOS or Cupertino host installs no `Material`, and a page still
  /// meets Material internals that ask for one — an `InkWell` a caller left in a
  /// row, a selection toolbar, a tooltip. It paints nothing: it is the ancestor
  /// those lookups need, not a surface.
  Widget _inkHost(BuildContext context, Widget? child) {
    final wrapped = builder?.call(context, child) ?? child;
    if (wrapped == null) {
      return const SizedBox.shrink();
    }
    return Material(type: MaterialType.transparency, child: wrapped);
  }
}
