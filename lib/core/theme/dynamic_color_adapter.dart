import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart' as flutter;
import 'package:material_ui/material_ui.dart' as material;

/// Converts the decoupled Material color model used by dynamic_color 2.x to
/// Flutter's framework ColorScheme.
///
/// dynamic_color deliberately moved its public scheme type to material_ui in
/// 2.0.0. Keeping the conversion at this boundary prevents that independent
/// widget library from leaking into the rest of the application while still
/// preserving every Material 3 role supplied by the operating system.
flutter.ColorScheme toFlutterColorScheme(material.ColorScheme source) {
  final scheme = source.harmonized();
  return flutter.ColorScheme(
    brightness: scheme.brightness,
    primary: scheme.primary,
    onPrimary: scheme.onPrimary,
    primaryContainer: scheme.primaryContainer,
    onPrimaryContainer: scheme.onPrimaryContainer,
    primaryFixed: scheme.primaryFixed,
    primaryFixedDim: scheme.primaryFixedDim,
    onPrimaryFixed: scheme.onPrimaryFixed,
    onPrimaryFixedVariant: scheme.onPrimaryFixedVariant,
    secondary: scheme.secondary,
    onSecondary: scheme.onSecondary,
    secondaryContainer: scheme.secondaryContainer,
    onSecondaryContainer: scheme.onSecondaryContainer,
    secondaryFixed: scheme.secondaryFixed,
    secondaryFixedDim: scheme.secondaryFixedDim,
    onSecondaryFixed: scheme.onSecondaryFixed,
    onSecondaryFixedVariant: scheme.onSecondaryFixedVariant,
    tertiary: scheme.tertiary,
    onTertiary: scheme.onTertiary,
    tertiaryContainer: scheme.tertiaryContainer,
    onTertiaryContainer: scheme.onTertiaryContainer,
    tertiaryFixed: scheme.tertiaryFixed,
    tertiaryFixedDim: scheme.tertiaryFixedDim,
    onTertiaryFixed: scheme.onTertiaryFixed,
    onTertiaryFixedVariant: scheme.onTertiaryFixedVariant,
    error: scheme.error,
    onError: scheme.onError,
    errorContainer: scheme.errorContainer,
    onErrorContainer: scheme.onErrorContainer,
    surface: scheme.surface,
    onSurface: scheme.onSurface,
    surfaceDim: scheme.surfaceDim,
    surfaceBright: scheme.surfaceBright,
    surfaceContainerLowest: scheme.surfaceContainerLowest,
    surfaceContainerLow: scheme.surfaceContainerLow,
    surfaceContainer: scheme.surfaceContainer,
    surfaceContainerHigh: scheme.surfaceContainerHigh,
    surfaceContainerHighest: scheme.surfaceContainerHighest,
    onSurfaceVariant: scheme.onSurfaceVariant,
    outline: scheme.outline,
    outlineVariant: scheme.outlineVariant,
    shadow: scheme.shadow,
    scrim: scheme.scrim,
    inverseSurface: scheme.inverseSurface,
    onInverseSurface: scheme.onInverseSurface,
    inversePrimary: scheme.inversePrimary,
    surfaceTint: scheme.surfaceTint,
  );
}

/// Converts the framework color model back to the independent Material widget
/// library used by a few upgraded packages.
///
/// [material.ColorScheme]'s public constructor intentionally exposes only its
/// compatibility roles. Start with those required roles and use `copyWith` to
/// preserve the complete Material 3 palette instead of regenerating colors from
/// a seed (which would subtly change dynamic and user-selected themes).
material.ColorScheme toMaterialUiColorScheme(flutter.ColorScheme source) {
  return material.ColorScheme(
    brightness: source.brightness,
    primary: source.primary,
    onPrimary: source.onPrimary,
    secondary: source.secondary,
    onSecondary: source.onSecondary,
    error: source.error,
    onError: source.onError,
    surface: source.surface,
    onSurface: source.onSurface,
  ).copyWith(
    primaryContainer: source.primaryContainer,
    onPrimaryContainer: source.onPrimaryContainer,
    primaryFixed: source.primaryFixed,
    primaryFixedDim: source.primaryFixedDim,
    onPrimaryFixed: source.onPrimaryFixed,
    onPrimaryFixedVariant: source.onPrimaryFixedVariant,
    secondaryContainer: source.secondaryContainer,
    onSecondaryContainer: source.onSecondaryContainer,
    secondaryFixed: source.secondaryFixed,
    secondaryFixedDim: source.secondaryFixedDim,
    onSecondaryFixed: source.onSecondaryFixed,
    onSecondaryFixedVariant: source.onSecondaryFixedVariant,
    tertiary: source.tertiary,
    onTertiary: source.onTertiary,
    tertiaryContainer: source.tertiaryContainer,
    onTertiaryContainer: source.onTertiaryContainer,
    tertiaryFixed: source.tertiaryFixed,
    tertiaryFixedDim: source.tertiaryFixedDim,
    onTertiaryFixed: source.onTertiaryFixed,
    onTertiaryFixedVariant: source.onTertiaryFixedVariant,
    errorContainer: source.errorContainer,
    onErrorContainer: source.onErrorContainer,
    surfaceDim: source.surfaceDim,
    surfaceBright: source.surfaceBright,
    surfaceContainerLowest: source.surfaceContainerLowest,
    surfaceContainerLow: source.surfaceContainerLow,
    surfaceContainer: source.surfaceContainer,
    surfaceContainerHigh: source.surfaceContainerHigh,
    surfaceContainerHighest: source.surfaceContainerHighest,
    onSurfaceVariant: source.onSurfaceVariant,
    outline: source.outline,
    outlineVariant: source.outlineVariant,
    shadow: source.shadow,
    scrim: source.scrim,
    inverseSurface: source.inverseSurface,
    onInverseSurface: source.onInverseSurface,
    inversePrimary: source.inversePrimary,
    surfaceTint: source.surfaceTint,
  );
}

material.TextTheme _toMaterialUiTextTheme(flutter.TextTheme source) {
  return material.TextTheme(
    displayLarge: source.displayLarge,
    displayMedium: source.displayMedium,
    displaySmall: source.displaySmall,
    headlineLarge: source.headlineLarge,
    headlineMedium: source.headlineMedium,
    headlineSmall: source.headlineSmall,
    titleLarge: source.titleLarge,
    titleMedium: source.titleMedium,
    titleSmall: source.titleSmall,
    bodyLarge: source.bodyLarge,
    bodyMedium: source.bodyMedium,
    bodySmall: source.bodySmall,
    labelLarge: source.labelLarge,
    labelMedium: source.labelMedium,
    labelSmall: source.labelSmall,
  );
}

/// Mirrors the active Flutter theme into `material_ui`.
///
/// Flutter 3.47 decoupled some Material packages from `flutter/material.dart`.
/// Without this bridge those widgets silently use a light fallback theme, so a
/// color-picker dialog can look unrelated to the application's selected mode.
material.ThemeData toMaterialUiThemeData(flutter.ThemeData source) {
  return material.ThemeData(
    brightness: source.brightness,
    colorScheme: toMaterialUiColorScheme(source.colorScheme),
    platform: source.platform,
    useMaterial3: source.useMaterial3,
    canvasColor: source.canvasColor,
    cardColor: source.cardColor,
    disabledColor: source.disabledColor,
    dividerColor: source.dividerColor,
    focusColor: source.focusColor,
    highlightColor: source.highlightColor,
    hintColor: source.hintColor,
    hoverColor: source.hoverColor,
    scaffoldBackgroundColor: source.scaffoldBackgroundColor,
    shadowColor: source.shadowColor,
    splashColor: source.splashColor,
    textTheme: _toMaterialUiTextTheme(source.textTheme),
    primaryTextTheme: _toMaterialUiTextTheme(source.primaryTextTheme),
  );
}

/// Supplies the matching `material_ui` inherited theme to packages that have
/// migrated ahead of the rest of this application.
class MaterialUiThemeBridge extends flutter.StatelessWidget {
  const MaterialUiThemeBridge({super.key, required this.child});

  final flutter.Widget child;

  @override
  flutter.Widget build(flutter.BuildContext context) {
    return material.Theme(data: toMaterialUiThemeData(flutter.Theme.of(context)), child: child);
  }
}
