import 'package:flutter/widgets.dart';

import 'package:pure_uikit/src/app/hosts/fluent_app_host.dart';
import 'package:pure_uikit/src/app/pure_app_config.dart';
import 'package:pure_uikit/src/app/pure_app_host.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

export 'package:pure_uikit/src/app/pure_app_host.dart';

/// The public host: one widget, the Fluent design language.
///
/// It replaces the app's own `MaterialApp.router`. The host decides how a
/// route slides in, where a dialog's barrier lives and which library's
/// strings the selection toolbar reads.
///
/// The other design languages' hosts are retired: every configuration mounts
/// the Fluent host, and a configuration naming a non-fluent language falls
/// back to it here while the resolved [PureTheme] keeps carrying the chosen
/// language to the widgets below. The language is still resolved into a
/// `PureUiStartupConfig` once, before the first frame, and fed frozen to
/// [PureConfigProvider]; changing the language is a restart, not a re-skin:
/// the host owns the route stack, the overlays and the chrome's
/// localizations, and swapping the theme under a live tree does not restart
/// an app, it throws away the state below it.
///
/// [PureAppHostBinding] is what a host receives, and `buildFluentAppHost`
/// under `src/app/hosts/` is what it becomes — fluent_ui's `FluentApp`. The
/// host seeds from the resolved [PureTheme], pins the brightness the token
/// picked (it never consults the platform), and invokes the caller's builder
/// once per frame inside its own theme scope — the contract the host shares
/// with the widgets, so a brightness, accent, font or density change
/// re-skins the host along with everything under it.
class PureApp extends StatefulWidget {
  /// A host over [routerConfig] — the parameter form.
  const new({
    required this.routerConfig,
    this.title = '',
    this.onGenerateTitle,
    this.localizationsDelegates = const <LocalizationsDelegate<dynamic>>[],
    this.supportedLocales = const <Locale>[Locale('en')],
    this.locale,
    this.builder,
    this.debugShowCheckedModeBanner = false,
    this.config,
    super.key,
  });


  /// The config-object form, when the caller built a [PureAppConfig]; null
  /// when the parameter form above is in use. [config] folds whichever is
  /// present into one shape the build reads.
  final PureAppConfig? config;

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
  State<PureApp> createState() => _PureAppState();
}

class _PureAppState extends State<PureApp> {
  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final binding = PureAppHostBinding(
      theme: PureTheme.of(context),
      routerConfig: config?.routerConfig ?? widget.routerConfig,
      title: config?.title ?? widget.title,
      onGenerateTitle: config?.onGenerateTitle ?? widget.onGenerateTitle,
      localizationsDelegates: config?.localizationsDelegates ?? widget.localizationsDelegates,
      supportedLocales: config?.supportedLocales ?? widget.supportedLocales,
      locale: config?.locale ?? widget.locale,
      builder: config?.builder ?? widget.builder,
      debugShowCheckedModeBanner: config?.debugShowCheckedModeBanner ?? widget.debugShowCheckedModeBanner,
    );
    return _mountHost(binding);
  }
}

/// The host every language mounts: Fluent.
///
/// A plain indirection keeps the seam the hosts used to sit behind — one
/// line, one library. A configuration naming a retired language falls back
/// to Fluent here rather than failing to mount.
Widget _mountHost(PureAppHostBinding binding) => buildFluentAppHost(binding);
