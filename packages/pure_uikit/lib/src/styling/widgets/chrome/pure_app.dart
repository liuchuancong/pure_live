import 'package:fluent_2/fluent_2.dart' as f2;
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:forui/forui.dart' as forui;
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:macos_ui/macos_ui.dart' as macos;
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';
import 'package:yaru/yaru.dart' as yaru;

/// The public host: one widget, every design language.
///
/// It replaces the app's own `MaterialApp.router`. Leaving that in place is
/// what makes a design-language switch look like nothing has changed: the
/// host, not the controls, decides how a route slides in, where a dialog's
/// barrier lives and which library's strings the selection toolbar reads.
/// There is no adapter and no spec in between: [build] switches on
/// `UiConfig.language` and mounts the library's real host directly —
/// `MaterialApp`, `CupertinoApp`, `MacosApp`, `FluentApp` — or, for the
/// languages whose library ships no application widget (forui, glass,
/// neumorphic, wind), Flutter's own `WidgetsApp` with that library's theme
/// installed above the routed tree, which is what those languages' package
/// builders mounted. Every host is seeded from the resolved `PureTheme`, so a
/// preference change re-skins the host along with everything under it.
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
    final theme = PureTheme.of(context);
    return switch (theme.config.language) {
      PureDesignLanguage.material => _materialHost(theme),
      PureDesignLanguage.cupertino => _cupertinoHost(theme),
      PureDesignLanguage.macos => _macosHost(theme),
      PureDesignLanguage.fluent => _fluentHost(theme),
      PureDesignLanguage.neumorphic => _neumorphicHost(theme),
      PureDesignLanguage.glass => _glassHost(theme),
      PureDesignLanguage.wind => _windHost(theme),
      PureDesignLanguage.forui => _foruiHost(theme),
      PureDesignLanguage.yaru => _yaruHost(theme),
    };
  }

  /// The token has already picked the brightness, so every host below carries
  /// its one resolved theme in both the light and the dark slot: the host must
  /// not re-pick it from the platform.

  /// `MaterialApp` installs the fork's theme scope, its ink splash and its
  /// selection toolbar, so a page reads Material from the window frame down.
  Widget _materialHost(PureTheme theme) {
    final token = theme.token;
    final brightness = token.isDark ? Brightness.dark : Brightness.light;
    final data = ThemeData(
      brightness: brightness,
      // A seeded scheme follows the accent, while the page and card surfaces
      // and the global font family follow the resolved token.
      colorScheme: ColorScheme.fromSeed(seedColor: token.color.primary, brightness: brightness),
      fontFamily: token.type.fontFamily,
      scaffoldBackgroundColor: token.color.surface,
      cardColor: token.color.surfaceElevated,
    );
    return MaterialApp.router(
      routerConfig: routerConfig,
      title: title,
      onGenerateTitle: onGenerateTitle,
      localizationsDelegates: localizationsDelegates,
      supportedLocales: supportedLocales,
      locale: locale,
      builder: builder,
      theme: data,
      darkTheme: data,
      debugShowCheckedModeBanner: debugShowCheckedModeBanner,
    );
  }

  /// `CupertinoApp` is the only thing that gives a Cupertino page its iOS
  /// behaviour: the slide-from-right route, the swipe-back gesture, the scroll
  /// physics and the text-selection toolbar. It takes one theme rather than a
  /// light and a dark slot, which suits the token: the resolved theme already
  /// carries the chosen brightness.
  Widget _cupertinoHost(PureTheme theme) {
    final token = theme.token;
    return cupertino.CupertinoApp.router(
      routerConfig: routerConfig,
      title: title,
      onGenerateTitle: onGenerateTitle,
      localizationsDelegates: localizationsDelegates,
      supportedLocales: supportedLocales,
      locale: locale,
      builder: builder,
      theme: cupertino.CupertinoThemeData(
        brightness: token.isDark ? Brightness.dark : Brightness.light,
        primaryColor: token.color.primary,
        primaryContrastingColor: token.color.onPrimary,
        scaffoldBackgroundColor: token.color.surface,
      ),
      debugShowCheckedModeBanner: debugShowCheckedModeBanner,
    );
  }

  /// `MacosApp` owns what a macOS window feels like: the cupertino route
  /// stack, the window-active/inactive tinting the library tracks, the overlay
  /// a sheet opens into and the desktop accent colour it reads from the
  /// platform. The window canvas follows the resolved surface.
  Widget _macosHost(PureTheme theme) {
    final token = theme.token;
    final data = macos.MacosThemeData(
      brightness: token.isDark ? Brightness.dark : Brightness.light,
      primaryColor: token.color.primary,
      canvasColor: token.color.surface,
    );
    return macos.MacosApp.router(
      routerConfig: routerConfig,
      title: title,
      onGenerateTitle: onGenerateTitle,
      localizationsDelegates: localizationsDelegates,
      supportedLocales: supportedLocales,
      locale: locale,
      builder: builder,
      theme: data,
      darkTheme: data,
      debugShowCheckedModeBanner: debugShowCheckedModeBanner,
    );
  }

  /// `FluentApp` wraps `WidgetsApp` — not `MaterialApp`, so nothing in the
  /// tree pulls in Material — and supplies the `FluentTheme`, the Fluent page
  /// transitions and the Fluent scrollbar. The brand ramp is generated from
  /// the token's accent colour, so an accent change re-brands the whole fluent
  /// subtree.
  Widget _fluentHost(PureTheme theme) {
    final token = theme.token;
    final data = f2.FluentThemeData.from(
      brightness: token.isDark ? Brightness.dark : Brightness.light,
      brand: f2.FluentBrandRamp.fromKeyColor(token.color.primary),
    );
    return f2.FluentApp.router(
      routerConfig: routerConfig,
      title: title,
      onGenerateTitle: onGenerateTitle,
      localizationsDelegates: localizationsDelegates,
      supportedLocales: supportedLocales,
      locale: locale,
      builder: builder,
      theme: data,
      darkTheme: data,
      debugShowCheckedModeBanner: debugShowCheckedModeBanner,
    );
  }

  /// Yaru is Material 3 wearing Ubuntu's token tables: the same `MaterialApp`
  /// host as [_materialHost], themed by yaru's own factories so the accent
  /// seeds Ubuntu's palette and the controls pick up its shapes and motion.
  Widget _yaruHost(PureTheme theme) {
    final token = theme.token;
    final brightness = token.isDark ? Brightness.dark : Brightness.light;
    final data = brightness == Brightness.dark
        ? yaru.createYaruDarkTheme(primaryColor: token.color.primary)
        : yaru.createYaruLightTheme(primaryColor: token.color.primary);
    return MaterialApp.router(
      routerConfig: routerConfig,
      title: title,
      onGenerateTitle: onGenerateTitle,
      localizationsDelegates: localizationsDelegates,
      supportedLocales: supportedLocales,
      locale: locale,
      builder: builder,
      debugShowCheckedModeBanner: debugShowCheckedModeBanner,
      theme: data,
      darkTheme: data,
    );
  }

  /// forui ships no application widget — the library is a theme and a set of
  /// components, and nothing in it owns a route, a title or a locale — so the
  /// host is Flutter's own `WidgetsApp` with the library's theme installed
  /// above the routed tree. `WidgetsApp` is what keeps the language honest: a
  /// `MaterialApp` would hand the page transitions, the scroll physics and the
  /// dialog barrier to Material no matter which controls are drawn above them.
  ///
  /// What the token can decide is the palette *variant*: `isDark` selects
  /// forui's neutral dark theme, everything else stays on the library's own
  /// defaults — forui exposes no way for a host to recolor it (`FThemeData`
  /// has a private constructor, and its supported path for a custom palette is
  /// generating a theme file). The theme is the outermost thing inside the app
  /// so a route's own overlay content resolves it too; the caller's builder —
  /// the ink surface and the translation scope — stays inside it.
  Widget _foruiHost(PureTheme theme) {
    final token = theme.token;
    return WidgetsApp.router(
      routerConfig: routerConfig,
      title: title,
      onGenerateTitle: onGenerateTitle,
      localizationsDelegates: localizationsDelegates,
      supportedLocales: supportedLocales,
      locale: locale,
      builder: (context, child) => forui.FTheme(
        data: token.isDark ? forui.FTheme.neutral.dark.touch : forui.FTheme.neutral.light.touch,
        // The app widget hands its builder a child it has not built yet when
        // the router has nothing to show; the theme scope still has to wrap
        // something.
        child: builder?.call(context, child) ?? child ?? const SizedBox.shrink(),
      ),
      // `WidgetsApp` asks for one colour outright; it is the token's accent, so
      // the host's own chrome (a scrollbar thumb, a selection) is on-theme even
      // where no forui widget paints it.
      color: theme.colors.primary,
      debugShowCheckedModeBanner: debugShowCheckedModeBanner,
    );
  }

  /// Glass ships no application widget either — the library is a theme and a
  /// set of frosted surfaces — so the host is Flutter's own `WidgetsApp` with
  /// the mapped `GlassTheme` installed above the routed tree: the panel's
  /// tint, corner radius and shadow follow the resolved token, so a
  /// brightness, accent or surface change re-skins the glass surfaces. The
  /// frosted `blur` radius stays a constant: glassmorphism blur is a
  /// transparency *effect*, driven by `UiConfig.transparency` rather than the
  /// design token, so mapping it here would imply a token→blur link that does
  /// not exist.
  Widget _glassHost(PureTheme theme) {
    final token = theme.token;
    return WidgetsApp.router(
      routerConfig: routerConfig,
      title: title,
      onGenerateTitle: onGenerateTitle,
      localizationsDelegates: localizationsDelegates,
      supportedLocales: supportedLocales,
      locale: locale,
      builder: (context, child) => glass.GlassTheme(
        data: glass.GlassThemeData(
          blur: 16,
          color: token.color.bgContainer,
          borderRadius: token.scale.radii.lg,
          shadowColor: token.color.shadowBase,
        ),
        child: builder?.call(context, child) ?? child ?? const SizedBox.shrink(),
      ),
      color: theme.colors.primary,
      debugShowCheckedModeBanner: debugShowCheckedModeBanner,
    );
  }

  /// Neumorphic ships no application widget — the library is a theme
  /// (`NeuTheme`) plus a set of components — so the host is Flutter's own
  /// `WidgetsApp` with the mapped theme installed above the routed tree: the
  /// base surface and accent colour come straight from the token, the panel
  /// corner radius follows the token's `lg` radius and the shadow tint follows
  /// the token's shadow base. Light source / depth / curvature are the style's
  /// fixed geometry, not token-driven, so they stay at the library defaults.
  Widget _neumorphicHost(PureTheme theme) {
    final token = theme.token;
    return WidgetsApp.router(
      routerConfig: routerConfig,
      title: title,
      onGenerateTitle: onGenerateTitle,
      localizationsDelegates: localizationsDelegates,
      supportedLocales: supportedLocales,
      locale: locale,
      builder: (context, child) => neu.NeuTheme(
        data: neu.NeuThemeData(
          baseColor: token.color.bgLayout,
          accentColor: token.color.primary,
          borderRadius: BorderRadius.all(Radius.circular(token.scale.radii.lg)),
          customShadowColor: token.color.shadowBase,
        ),
        child: builder?.call(context, child) ?? child ?? const SizedBox.shrink(),
      ),
      color: theme.colors.primary,
      debugShowCheckedModeBanner: debugShowCheckedModeBanner,
    );
  }

  /// Wind is a Tailwind-style styling library with no application widget, so
  /// the host is Flutter's own `WidgetsApp` with the mapped `WindTheme`
  /// installed above the routed tree: the brightness follows the token, the
  /// accent overrides Wind's `primary` colour and a configured global font
  /// family overrides Wind's `sans` scale. Wind keeps the rest of its
  /// colour/space/typography maps at their defaults rather than being
  /// half-mapped. `syncWithSystem` is forced false: the core owns the
  /// brightness decision, so Wind must not second-guess it against the
  /// platform setting.
  Widget _windHost(PureTheme theme) {
    final token = theme.token;
    final family = token.type.fontFamily;
    // Wind's `colors` scale is typed `MaterialColor`; the token exposes a
    // single accent, so it is expanded into a flat swatch (every shade = the
    // accent) rather than inventing tonal steps Wind would then render with.
    final argb = token.color.primary.toARGB32();
    final accent = MaterialColor(argb, <int, Color>{
      for (final shade in const [50, 100, 200, 300, 400, 500, 600, 700, 800, 900]) shade: Color(argb),
    });
    return WidgetsApp.router(
      routerConfig: routerConfig,
      title: title,
      onGenerateTitle: onGenerateTitle,
      localizationsDelegates: localizationsDelegates,
      supportedLocales: supportedLocales,
      locale: locale,
      builder: (context, child) => wind.WindTheme(
        data: wind.WindThemeData(
          brightness: token.isDark ? Brightness.dark : Brightness.light,
          syncWithSystem: false,
          colors: {'primary': accent},
          fontFamilies: family == null ? null : {'sans': family},
        ),
        child: builder?.call(context, child) ?? child ?? const SizedBox.shrink(),
      ),
      color: theme.colors.primary,
      debugShowCheckedModeBanner: debugShowCheckedModeBanner,
    );
  }
}
