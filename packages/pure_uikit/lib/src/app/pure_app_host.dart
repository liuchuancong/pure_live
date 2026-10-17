import 'package:flutter/widgets.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// Everything a design-language host needs, resolved once by [PureApp] and
/// handed to one host builder of the app widget.
///
/// The binding is the whole contract between the app-facing widget and the
/// per-language host functions: a host reads the resolved [theme] for its
/// palette and fonts, installs its own theme scope above [builder], and wires
/// the routing and localisation plumbing verbatim. A host never reaches back
/// into the widget.
final class PureAppHostBinding {
  /// A binding for one build pass.
  const new({
    required this.theme,
    required this.routerConfig,
    required this.title,
    required this.onGenerateTitle,
    required this.localizationsDelegates,
    required this.supportedLocales,
    required this.locale,
    required this.builder,
    required this.debugShowCheckedModeBanner,
  });

  /// The resolved design theme: palette, type and brightness, already folded
  /// with the user's configuration.
  final PureTheme theme;

  /// The app-owned router. Hosts swap freely around it — the route stack
  /// lives in the router, not in the host, so a design-language switch keeps
  /// the navigation state.
  final RouterConfig<Object>? routerConfig;

  /// The window title; ignored when [onGenerateTitle] is given.
  final String title;

  /// Resolves the title once localizations are in scope.
  final GenerateAppTitle? onGenerateTitle;

  /// The delegates every host below needs, in priority order.
  final List<LocalizationsDelegate<dynamic>> localizationsDelegates;

  /// The locales the app declares.
  final List<Locale> supportedLocales;

  /// The forced locale; null follows the platform.
  final Locale? locale;

  /// Wraps the navigator — where a translation provider belongs. Every host
  /// invokes it exactly once per frame, inside its own theme scope, so the
  /// builder sees the language's theme and the router's child.
  final TransitionBuilder? builder;

  /// Whether the debug banner shows.
  final bool debugShowCheckedModeBanner;
}
