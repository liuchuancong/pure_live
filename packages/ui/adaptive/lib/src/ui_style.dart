// Module: lib/src/ui_style.dart
// Purpose: The switchable UI styles and the factory that builds each style's
// themes.
// Author: liuchuancong
// Created: 2026-10-10
//
// Spec: the multi-style architecture the media_core_ui reference uses
// (material / cupertino / fluent / macos / neumorphic / yaru, each a directory
// of its own) expressed the way an app consumes it: one registry, one theme
// per (style, brightness), the user's pick swappable at runtime. The material
// entry is the full Material 3 theme the shell ships with; the other entries
// are distinct visual variants built from the same token vocabulary
// (typography, geometry, density) until dedicated packages replace them.

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';

/// The UI styles the shell can switch between.
enum AdaptiveUiStyle {
  material('Material'),
  cupertino('Cupertino'),
  fluent('Fluent'),
  macos('macOS'),
  neumorphic('Neumorphic'),
  yaru('Yaru');

  const AdaptiveUiStyle(this.label);

  final String label;

  static AdaptiveUiStyle byName(String? name) =>
      AdaptiveUiStyle.values.where((style) => style.name == name).firstOrNull ?? AdaptiveUiStyle.material;
}

/// Builds the ThemeData for one style. Implementations must be pure: same
/// inputs, same theme, no platform lookups.
typedef StyleThemeFactory = ThemeData Function(ColorScheme scheme, TextTheme? textTheme, TargetPlatform platform);

/// One style's registration: how it names itself and how it builds themes.
final class StyleEntry {
  const StyleEntry({required this.style, required this.factory, required this.defaultSeed});

  final AdaptiveUiStyle style;
  final StyleThemeFactory factory;
  final Color defaultSeed;
}

/// The registry. Material is registered by the package itself; a host (or a
/// later style package) adds the dedicated entries on top.
final class AdaptiveStyleRegistry {
  AdaptiveStyleRegistry({List<StyleEntry>? styles}) : _styles = <AdaptiveUiStyle, StyleEntry>{} {
    for (final style in styles ?? const [defaultMaterialEntry]) {
      _styles[style.style] = style;
    }
  }

  final Map<AdaptiveUiStyle, StyleEntry> _styles;

  void register(StyleEntry entry) => _styles[entry.style] = entry;

  StyleEntry entryFor(AdaptiveUiStyle style) =>
      _styles[style] ?? _styles[AdaptiveUiStyle.material] ?? defaultMaterialEntry;

  List<AdaptiveUiStyle> get available => _styles.keys.toList(growable: false);

  /// The themes for one style, light and dark, from one seed.
  ThemeData themeFor(AdaptiveUiStyle style, Brightness brightness, Color seed) {
    final entry = entryFor(style);
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    return entry.factory(scheme, null, defaultTargetPlatform);
  }

  /// The material entry the package ships: full Material 3.
  static const StyleEntry defaultMaterialEntry = StyleEntry(
    style: AdaptiveUiStyle.material,
    defaultSeed: Color(0xFF6A5AE0),
    factory: _buildMaterial,
  );

  static ThemeData _buildMaterial(ColorScheme scheme, TextTheme? textTheme, TargetPlatform platform) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(backgroundColor: scheme.surface, centerTitle: false),
      navigationBarTheme: NavigationBarThemeData(backgroundColor: scheme.surfaceContainer),
      navigationRailTheme: NavigationRailThemeData(backgroundColor: scheme.surface),
    );
  }
}
