import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:forui/forui.dart' as forui;
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:pure_uikit/src/app/pure_app_host.dart';
import 'package:pure_uikit/src/styling/adapters/forui_theme_adapter.dart';
import 'package:pure_uikit/src/styling/adapters/glass_theme_adapter.dart';
import 'package:pure_uikit/src/styling/adapters/neumorphic_theme_adapter.dart';
import 'package:pure_uikit/src/styling/adapters/wind_theme_adapter.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

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
///
/// The Material scope below answers the other half. Each of these four
/// languages falls back to Flutter's official Material widget for whatever its
/// library does not ship — a slider, a badge, a tooltip, a settings row, the
/// indeterminate progress bar — and under a bare `WidgetsApp` those widgets
/// build the framework's own default theme: Material 3's baseline purple and
/// the platform default font, whatever the user chose. Seeding the scheme from
/// the token is what makes a fallback read as the same language as the controls
/// beside it.
Widget _materialScope(PureTheme theme, Widget child) {
  final token = theme.token;
  final data = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: token.color.primary,
      brightness: token.isDark ? Brightness.dark : Brightness.light,
    ).copyWith(primary: token.color.primary, onPrimary: token.color.onPrimary),
  );
  final family = token.type.fontFamily;
  return Theme(
    data: family == null ? data : data.copyWith(textTheme: data.textTheme.apply(fontFamily: family)),
    child: child,
  );
}

/// The forui host: the mapped `FThemeData` installed above the routed tree.
/// The palette *variant* and the chosen font family are what the token decides;
/// the rest is forui's own look, and it is [ForuiThemeAdapter] that says how the
/// mapping goes.
WidgetsApp buildForuiAppHost(PureAppHostBinding b) {
  return WidgetsApp.router(
    routerConfig: b.routerConfig,
    title: b.title,
    onGenerateTitle: b.onGenerateTitle,
    localizationsDelegates: b.localizationsDelegates,
    supportedLocales: b.supportedLocales,
    locale: b.locale,
    builder: (context, child) => forui.FTheme(
      data: const ForuiThemeAdapter().resolve(b.theme),
      // The app widget hands its builder a child it has not built yet when
      // the router has nothing to show; the theme scope still has to wrap
      // something.
      child: _materialScope(b.theme, b.builder?.call(context, child) ?? child ?? const SizedBox.shrink()),
    ),
    color: b.theme.colors.primary,
    debugShowCheckedModeBanner: b.debugShowCheckedModeBanner,
  );
}

/// The glass host: the mapped `GlassTheme` installed above the routed tree —
/// the panel's tint, corner radius and shadow follow the resolved token, so a
/// brightness, accent or surface change re-skins the glass surfaces. The mapping
/// itself is [GlassThemeAdapter]'s; the library's theme object has no font slot,
/// so the chosen family reaches this language through the Material scope below
/// and the token-typed text of the controls drawn here.
WidgetsApp buildGlassAppHost(PureAppHostBinding b) {
  return WidgetsApp.router(
    routerConfig: b.routerConfig,
    title: b.title,
    onGenerateTitle: b.onGenerateTitle,
    localizationsDelegates: b.localizationsDelegates,
    supportedLocales: b.supportedLocales,
    locale: b.locale,
    builder: (context, child) => glass.GlassTheme(
      data: const GlassThemeAdapter().resolve(b.theme),
      child: _materialScope(b.theme, b.builder?.call(context, child) ?? child ?? const SizedBox.shrink()),
    ),
    color: b.theme.colors.primary,
    debugShowCheckedModeBanner: b.debugShowCheckedModeBanner,
  );
}

/// The neumorphic host: the base surface, accent, corner radius and shadow tint
/// come from the token through [NeumorphicThemeAdapter]. Light source / depth /
/// curvature are the style's fixed geometry, not token-driven, so they stay at
/// the library defaults.
WidgetsApp buildNeumorphicAppHost(PureAppHostBinding b) {
  return WidgetsApp.router(
    routerConfig: b.routerConfig,
    title: b.title,
    onGenerateTitle: b.onGenerateTitle,
    localizationsDelegates: b.localizationsDelegates,
    supportedLocales: b.supportedLocales,
    locale: b.locale,
    builder: (context, child) => neu.NeuTheme(
      data: const NeumorphicThemeAdapter().resolve(b.theme),
      child: _materialScope(b.theme, b.builder?.call(context, child) ?? child ?? const SizedBox.shrink()),
    ),
    color: b.theme.colors.primary,
    debugShowCheckedModeBanner: b.debugShowCheckedModeBanner,
  );
}

/// The wind host: the brightness, the accent's tonal ramp and the chosen font
/// family are mapped by [WindThemeAdapter]; Wind keeps the rest of its
/// colour/space/typography maps at their defaults rather than being
/// half-mapped, and `syncWithSystem` is forced false because the core owns the
/// brightness decision.
WidgetsApp buildWindAppHost(PureAppHostBinding b) {
  return WidgetsApp.router(
    routerConfig: b.routerConfig,
    title: b.title,
    onGenerateTitle: b.onGenerateTitle,
    localizationsDelegates: b.localizationsDelegates,
    supportedLocales: b.supportedLocales,
    locale: b.locale,
    builder: (context, child) => wind.WindTheme(
      data: const WindThemeAdapter().resolve(b.theme),
      child: _materialScope(b.theme, b.builder?.call(context, child) ?? child ?? const SizedBox.shrink()),
    ),
    color: b.theme.colors.primary,
    debugShowCheckedModeBanner: b.debugShowCheckedModeBanner,
  );
}
