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

  /// The default registry: material in full, the other five as distinct
  /// visual variants built from documented ThemeData knobs - platform (which
  /// changes the rendered controls), density, corner geometry and the
  /// decoration thickness. Dedicated packages replace a variant when a style
  /// needs what ThemeData cannot express.
  AdaptiveStyleRegistry.withAllVariants() : this(styles: _allVariantEntries());

  static List<StyleEntry> _allVariantEntries() => <StyleEntry>[
    defaultMaterialEntry,
    StyleEntry(style: AdaptiveUiStyle.cupertino, defaultSeed: const Color(0xFF007AFF), factory: _buildCupertino),
    StyleEntry(style: AdaptiveUiStyle.fluent, defaultSeed: const Color(0xFF0078D4), factory: _buildFluent),
    StyleEntry(style: AdaptiveUiStyle.macos, defaultSeed: const Color(0xFF0A84FF), factory: _buildMacos),
    StyleEntry(style: AdaptiveUiStyle.neumorphic, defaultSeed: const Color(0xFF8A8A9E), factory: _buildNeumorphic),
    StyleEntry(style: AdaptiveUiStyle.yaru, defaultSeed: const Color(0xFFE95420), factory: _buildYaru),
  ];

  static ThemeData _base(ColorScheme scheme) => ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    appBarTheme: AppBarTheme(backgroundColor: scheme.surface, centerTitle: false),
    navigationBarTheme: NavigationBarThemeData(backgroundColor: scheme.surfaceContainer),
    navigationRailTheme: NavigationRailThemeData(backgroundColor: scheme.surface),
  );

  static ThemeData _buildMaterial(ColorScheme scheme, TextTheme? textTheme, TargetPlatform platform) => _base(scheme);

  static ThemeData _buildCupertino(ColorScheme scheme, TextTheme? textTheme, TargetPlatform platform) {
    // iOS controls (switches, sliders, progress) come from the platform;
    // continuous corners and comfortable density carry the rest.
    return _base(scheme).copyWith(
      platform: TargetPlatform.iOS,
      visualDensity: VisualDensity.comfortable,
      cardTheme: const CardThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
      ),
    );
  }

  static ThemeData _buildFluent(ColorScheme scheme, TextTheme? textTheme, TargetPlatform platform) {
    // Windows/Fluent reads dense and square: acrylic-like surfaces, 4px
    // geometry, compact controls.
    return _base(scheme).copyWith(
      platform: TargetPlatform.windows,
      visualDensity: VisualDensity.compact,
      cardTheme: const CardThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4)))),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }

  static ThemeData _buildMacos(ColorScheme scheme, TextTheme? textTheme, TargetPlatform platform) {
    return _base(scheme).copyWith(
      platform: TargetPlatform.macOS,
      visualDensity: VisualDensity.standard,
      cardTheme: const CardThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
      ),
      sliderTheme: const SliderThemeData(trackShape: RoundedRectSliderTrackShape()),
    );
  }

  static ThemeData _buildNeumorphic(ColorScheme scheme, TextTheme? textTheme, TargetPlatform platform) {
    // The soft-plastic feel through surface treatment: same-hue surfaces,
    // zero elevation with hairline outlines, generous radii.
    final surface = scheme.surfaceContainerHighest;
    return _base(scheme).copyWith(
      scaffoldBackgroundColor: surface,
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
  }

  static ThemeData _buildYaru(ColorScheme scheme, TextTheme? textTheme, TargetPlatform platform) {
    // Ubuntu-adjacent: linux controls, warm rounded geometry, bold app bar.
    return _base(scheme).copyWith(
      platform: TargetPlatform.linux,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        centerTitle: false,
        titleTextStyle: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w700, fontSize: 20),
      ),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(shape: const StadiumBorder())),
    );
  }
}
