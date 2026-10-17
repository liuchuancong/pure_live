import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:forui/forui.dart' as forui;
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:pure_uikit/src/app/pure_app_host.dart';

/// The hosts for the four languages whose libraries ship no application
/// widget — forui, glass, neumorphic and wind are each a theme plus a set of
/// components, and nothing in them owns a route, a title or a locale — so the
/// host is Flutter's own `WidgetsApp` with the library's theme installed
/// above the routed tree. `WidgetsApp` is what keeps these languages honest:
/// a `MaterialApp` would hand the page transitions, the scroll physics and
/// the dialog barrier to Material no matter which controls are drawn above
/// them.
///
/// The builder contract, shared by every host in this file: it runs once per
/// frame, inside the library's theme scope, so the caller's translation
/// scope and ink surface see the language's theme and the router's child.
/// `WidgetsApp` asks for one colour outright; every host answers with the
/// token's accent so the host's own chrome (a scrollbar thumb, a selection)
/// is on-theme even where no language widget paints it.

/// The forui host. What the token can decide is the palette *variant*:
/// `isDark` selects forui's neutral dark theme, everything else stays on the
/// library's own defaults — forui exposes no way for a host to recolor it
/// (`FThemeData` has a private constructor, and its supported path for a
/// custom palette is generating a theme file).
WidgetsApp buildForuiAppHost(PureAppHostBinding b) {
  final token = b.theme.token;
  return WidgetsApp.router(
    routerConfig: b.routerConfig,
    title: b.title,
    onGenerateTitle: b.onGenerateTitle,
    localizationsDelegates: b.localizationsDelegates,
    supportedLocales: b.supportedLocales,
    locale: b.locale,
    builder: (context, child) => forui.FTheme(
      data: token.isDark ? forui.FTheme.neutral.dark.touch : forui.FTheme.neutral.light.touch,
      // The app widget hands its builder a child it has not built yet when
      // the router has nothing to show; the theme scope still has to wrap
      // something.
      child: b.builder?.call(context, child) ?? child ?? const SizedBox.shrink(),
    ),
    color: b.theme.colors.primary,
    debugShowCheckedModeBanner: b.debugShowCheckedModeBanner,
  );
}

/// The glass host: the mapped `GlassTheme` installed above the routed tree —
/// the panel's tint, corner radius and shadow follow the resolved token, so
/// a brightness, accent or surface change re-skins the glass surfaces. The
/// frosted `blur` radius stays a constant: glassmorphism blur is a
/// transparency *effect*, driven by `UiConfig.transparency` rather than the
/// design token, so mapping it here would imply a token→blur link that does
/// not exist.
WidgetsApp buildGlassAppHost(PureAppHostBinding b) {
  final token = b.theme.token;
  return WidgetsApp.router(
    routerConfig: b.routerConfig,
    title: b.title,
    onGenerateTitle: b.onGenerateTitle,
    localizationsDelegates: b.localizationsDelegates,
    supportedLocales: b.supportedLocales,
    locale: b.locale,
    builder: (context, child) => glass.GlassTheme(
      data: glass.GlassThemeData(
        blur: 16,
        color: token.color.bgContainer,
        borderRadius: token.scale.radii.lg,
        shadowColor: token.color.shadowBase,
      ),
      child: b.builder?.call(context, child) ?? child ?? const SizedBox.shrink(),
    ),
    color: b.theme.colors.primary,
    debugShowCheckedModeBanner: b.debugShowCheckedModeBanner,
  );
}

/// The neumorphic host: the base surface and accent colour come straight
/// from the token, the panel corner radius follows the token's `lg` radius
/// and the shadow tint follows the token's shadow base. Light source /
/// depth / curvature are the style's fixed geometry, not token-driven, so
/// they stay at the library defaults.
WidgetsApp buildNeumorphicAppHost(PureAppHostBinding b) {
  final token = b.theme.token;
  return WidgetsApp.router(
    routerConfig: b.routerConfig,
    title: b.title,
    onGenerateTitle: b.onGenerateTitle,
    localizationsDelegates: b.localizationsDelegates,
    supportedLocales: b.supportedLocales,
    locale: b.locale,
    builder: (context, child) => neu.NeuTheme(
      data: neu.NeuThemeData(
        baseColor: token.color.bgLayout,
        accentColor: token.color.primary,
        borderRadius: BorderRadius.all(Radius.circular(token.scale.radii.lg)),
        customShadowColor: token.color.shadowBase,
      ),
      child: b.builder?.call(context, child) ?? child ?? const SizedBox.shrink(),
    ),
    color: b.theme.colors.primary,
    debugShowCheckedModeBanner: b.debugShowCheckedModeBanner,
  );
}

/// The wind host: the brightness follows the token, the accent overrides
/// Wind's `primary` colour and a configured global font family overrides
/// Wind's `sans` scale. Wind keeps the rest of its colour/space/typography
/// maps at their defaults rather than being half-mapped. `syncWithSystem` is
/// forced false: the core owns the brightness decision, so Wind must not
/// second-guess it against the platform setting.
WidgetsApp buildWindAppHost(PureAppHostBinding b) {
  final token = b.theme.token;
  final family = token.type.fontFamily;
  // Wind's `colors` scale is typed `MaterialColor`, and Wind reads shades
  // off it for hovers, presses and disabled states — so the single accent
  // seed is expanded into a real tonal ramp (500 = the seed, lighter and
  // darker steps around it) instead of a flat swatch that would flatten
  // every interaction state to the same colour.
  final accent = _windAccentSwatch(token.color.primary);
  return WidgetsApp.router(
    routerConfig: b.routerConfig,
    title: b.title,
    onGenerateTitle: b.onGenerateTitle,
    localizationsDelegates: b.localizationsDelegates,
    supportedLocales: b.supportedLocales,
    locale: b.locale,
    builder: (context, child) => wind.WindTheme(
      data: wind.WindThemeData(
        brightness: token.isDark ? Brightness.dark : Brightness.light,
        syncWithSystem: false,
        colors: {'primary': accent},
        fontFamilies: family == null ? null : {'sans': family},
      ),
      child: b.builder?.call(context, child) ?? child ?? const SizedBox.shrink(),
    ),
    color: b.theme.colors.primary,
    debugShowCheckedModeBanner: b.debugShowCheckedModeBanner,
  );
}

/// Grows a Material swatch around [seed]: 500 is the seed itself, 50–400 are
/// lighter steps and 600–900 darker ones, walked in HSL lightness so the hue
/// and saturation the user picked survive at every step.
MaterialColor _windAccentSwatch(Color seed) {
  final hsl = HSLColor.fromColor(seed);
  Color step(double delta) => hsl.withLightness((hsl.lightness + delta).clamp(0.05, 0.95)).toColor();
  return MaterialColor(seed.toARGB32(), <int, Color>{
    50: step(0.36),
    100: step(0.28),
    200: step(0.20),
    300: step(0.12),
    400: step(0.05),
    500: seed,
    600: step(-0.06),
    700: step(-0.13),
    800: step(-0.21),
    900: step(-0.30),
  });
}
