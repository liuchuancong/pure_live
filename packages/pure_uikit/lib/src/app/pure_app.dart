import 'package:flutter/foundation.dart' show kDebugMode;
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
/// what makes a design-language switch look like nothing has changed: the host
/// decides how a route slides in, where a dialog's barrier lives and which
/// library's strings the selection toolbar reads.
///
/// Which language that is gets decided once, before the first frame. The app
/// resolves it into a `PureUiStartupConfig` and feeds the frozen value to
/// [PureConfigProvider], so the config reaching here cannot name a second
/// language while the app is running; [State] also pins whatever it mounted
/// first, as the last line of the same rule. Changing the language is a
/// restart, not a re-skin: the host owns the route stack, the overlays and the
/// chrome's localizations, and swapping it under a live tree does not restart
/// an app, it throws away the state below it.
///
/// [PureAppHostBinding] is what a host receives, and one host builder under
/// `src/app/hosts/` is what it becomes — `MaterialApp`, `CupertinoApp`,
/// `MacosApp`, `FluentApp`, a yaru-themed `MaterialApp`, or a `WidgetsApp`
/// carrying the forui/glass/neumorphic/wind theme. Every host seeds from the
/// resolved [PureTheme], pins the brightness the token picked (it never
/// consults the platform), and invokes the caller's builder once per frame
/// inside its own theme scope — the contract the hosts share, so a brightness,
/// accent, font or density change re-skins the host along with everything
/// under it while the language stays the one this process was born with.
class PureApp extends StatefulWidget {
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
  State<PureApp> createState() => _PureAppState();
}

class _PureAppState extends State<PureApp> {
  /// The language this process mounted, captured on the first build.
  ///
  /// The host is built from this and nothing else, for the life of the element.
  /// Null only before that first build; reading the theme there is not allowed,
  /// so the capture belongs in `build` rather than `initState`.
  PureDesignLanguage? _mounted;

  @override
  Widget build(BuildContext context) {
    final binding = PureAppHostBinding(
      theme: PureTheme.of(context),
      routerConfig: widget.routerConfig,
      title: widget.title,
      onGenerateTitle: widget.onGenerateTitle,
      localizationsDelegates: widget.localizationsDelegates,
      supportedLocales: widget.supportedLocales,
      locale: widget.locale,
      builder: widget.builder,
      debugShowCheckedModeBanner: widget.debugShowCheckedModeBanner,
    );
    final incoming = binding.theme.config.language;
    final mounted = _mounted;
    if (mounted == null) {
      _mounted = incoming;
      return _mountHost(binding, incoming);
    }
    if (incoming != mounted) {
      // The frozen startup configuration is what makes this unreachable. Reaching
      // it means a caller handed a live language to a running tree, and the host
      // keeps mounting the old one — so the widgets below would repaint to the
      // new language while the window frame, the transitions and the overlay
      // stayed on the old one. Mixed, and worth a loud log line in the build that
      // can still say it.
      if (kDebugMode) {
        debugPrint(
          '[ui] design language "$incoming" reached PureApp after boot; this process mounted "$mounted" and '
          'keeps it. Resolve the language into a PureUiStartupConfig before runApp and restart to change it.',
        );
      }
    }
    return _mountHost(binding, mounted);
  }
}

/// The host [language] ships, chosen by a switch rather than a registry.
///
/// A plain switch is the right amount of structure here: nine languages, one
/// line each. A factory registry would hide which library is about to be
/// constructed, and which library a language mounts is the one thing this file
/// exists to make readable.
Widget _mountHost(PureAppHostBinding binding, PureDesignLanguage language) => switch (language) {
  // Yaru draws chrome with the Material widgets — that is what Yaru itself
  // is; its character comes from the host theme (the yaru host), not from a
  // different shell.
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
