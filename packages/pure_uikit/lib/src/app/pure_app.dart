import 'package:flutter/widgets.dart';

import 'package:pure_uikit/src/app/hosts/cupertino_app_host.dart';
import 'package:pure_uikit/src/app/hosts/fluent_app_host.dart';
import 'package:pure_uikit/src/app/hosts/macos_app_host.dart';
import 'package:pure_uikit/src/app/hosts/material_app_host.dart';
import 'package:pure_uikit/src/app/hosts/themed_widgets_app_host.dart';
import 'package:pure_uikit/src/app/hosts/yaru_app_host.dart';
import 'package:pure_uikit/src/app/pure_app_host.dart';
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

export 'package:pure_uikit/src/app/pure_app_host.dart';

/// The public host: one widget, every design language.
///
/// It replaces the app's own `MaterialApp.router`. Keeping the app widget is
/// what makes a design-language switch look like nothing has changed: the
/// host decides how a route slides in, where a dialog's barrier lives and
/// which library's strings the selection toolbar reads — and the route stack
/// itself lives in the app-owned [routerConfig], not in the host, so
/// switching languages swaps the frame and keeps the navigation.
///
/// [build] resolves the configuration into a [PureAppHostBinding] and hands
/// it to one host builder under `src/app/hosts/` — `MaterialApp`,
/// `CupertinoApp`, `MacosApp`, `FluentApp`, a yaru-themed `MaterialApp`, or
/// a `WidgetsApp` carrying the forui/glass/neumorphic/wind theme. Every host
/// seeds from the resolved [PureTheme], pins the brightness the token picked
/// (it never consults the platform), and invokes the caller's builder once
/// per frame inside its own theme scope — the one contract the hosts share,
/// so a preference change re-skins the host along with everything under it.
class PureApp extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final binding = PureAppHostBinding(
      theme: PureTheme.of(context),
      routerConfig: routerConfig,
      title: title,
      onGenerateTitle: onGenerateTitle,
      localizationsDelegates: localizationsDelegates,
      supportedLocales: supportedLocales,
      locale: locale,
      builder: builder,
      debugShowCheckedModeBanner: debugShowCheckedModeBanner,
    );
    return switch (binding.theme.config.language) {
      // Yaru draws chrome with the Material widgets — that is what Yaru
      // itself is; its character comes from the host theme (the yaru host),
      // not from a different shell.
      PureDesignLanguage.material => buildMaterialAppHost(binding),
      PureDesignLanguage.yaru => buildYaruAppHost(binding),
      PureDesignLanguage.cupertino => buildCupertinoAppHost(binding),
      PureDesignLanguage.macos => buildMacosAppHost(binding),
      PureDesignLanguage.fluent => buildFluentAppHost(binding),
      PureDesignLanguage.forui => buildForuiAppHost(binding),
      PureDesignLanguage.glass => buildGlassAppHost(binding),
      PureDesignLanguage.neumorphic => buildNeumorphicAppHost(binding),
      PureDesignLanguage.wind => buildWindAppHost(binding),
    };
  }
}
