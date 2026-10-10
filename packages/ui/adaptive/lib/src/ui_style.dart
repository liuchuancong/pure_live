// Module: lib/src/ui_style.dart
// Purpose: The switchable UI styles and the factory that builds each style's theme from the design tokens.
// Author: liuchuancong
// Created: 2026-10-10
//
// Spec: the multi-style architecture the media_core_ui reference uses (material / cupertino / fluent / macos /
// neumorphic / yaru, each a directory of its own) expressed the way an app consumes it: one registry, one
// theme per (style, brightness), the user's pick swappable at runtime. The material entry is the full
// Material 3 theme the shell ships with; the other entries are distinct visual variants built from the same
// token vocabulary until dedicated packages replace them.
//
// What changed when the tokens arrived: a style used to decide sizes on its own, so switching style also
// switched density, and a TV running the Fluent variant inherited a mouse's 36-pixel button. Now every
// entry maps the *same* [DesignTokens] and differs only in decoration - corners, surfaces, control shapes.
// Input mode, readable text floor, focus weight and the motion budget are the tokens' business, which is
// what makes the six styles swappable without breaking the remote.

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';

import 'package:pure_live_design/pure_live_design.dart';
import 'package:pure_live_ui_kit/pure_live_ui_kit.dart';

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

/// Builds one style's theme from a scheme and the tokens the user's settings resolved to.
typedef StyleThemeFactory = ThemeData Function(ColorScheme scheme, DesignTokens tokens, TargetPlatform platform);

/// One style's registration: how it names itself, how it builds themes, and its default seed.
final class StyleEntry {
  const StyleEntry({required this.style, required this.factory, required this.defaultSeed});

  final AdaptiveUiStyle style;
  final StyleThemeFactory factory;
  final Color defaultSeed;
}

/// The registry. Material is registered by the package itself; a host (or a later style package) adds
/// dedicated entries on top.
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
  ///
  /// [tokens] is what carries the user's density, input mode and text scale. Without it the theme is built
  /// for the running platform's default input - correct on a phone, wrong on a TV - so a host that knows
  /// which box it is on should pass them.
  ThemeData themeFor(AdaptiveUiStyle style, Brightness brightness, Color seed, {DesignTokens? tokens}) {
    final entry = entryFor(style);
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final resolved = tokens ?? resolveDesignTokens(platform: platformProfileOf(defaultTargetPlatform));
    return _applyTokens(entry.factory(scheme, resolved, resolved.targetPlatform), resolved, scheme);
  }

  /// The material entry the package ships: full Material 3.
  static const StyleEntry defaultMaterialEntry = StyleEntry(
    style: AdaptiveUiStyle.material,
    defaultSeed: Color(0xFF6A5AE0),
    factory: _buildMaterial,
  );

  /// The default registry: material in full, the other five as distinct visual variants built from
  /// documented ThemeData knobs - platform (which changes the rendered controls), corner geometry and the
  /// decoration thickness. Dedicated packages replace a variant when a style needs what ThemeData cannot
  /// express.
  AdaptiveStyleRegistry.withAllVariants() : this(styles: _allVariantEntries());

  static List<StyleEntry> _allVariantEntries() => <StyleEntry>[
    defaultMaterialEntry,
    StyleEntry(style: AdaptiveUiStyle.cupertino, defaultSeed: const Color(0xFF007AFF), factory: _buildCupertino),
    StyleEntry(style: AdaptiveUiStyle.fluent, defaultSeed: const Color(0xFF0078D4), factory: _buildFluent),
    StyleEntry(style: AdaptiveUiStyle.macos, defaultSeed: const Color(0xFF0A84FF), factory: _buildMacos),
    StyleEntry(style: AdaptiveUiStyle.neumorphic, defaultSeed: const Color(0xFF8A8A9E), factory: _buildNeumorphic),
    StyleEntry(style: AdaptiveUiStyle.yaru, defaultSeed: const Color(0xFFE95420), factory: _buildYaru),
  ];

  /// The part every style shares: density, control heights, the readable text floor, the focus weight and
  /// the motion budget. A style may not override these, which is the whole point of putting them here
  /// instead of in each variant.
  static ThemeData _applyTokens(ThemeData base, DesignTokens tokens, ColorScheme scheme) {
    final buttonHeight = tokens.height(ControlKind.button);
    final inputHeight = tokens.height(ControlKind.input);
    final iconSize = tokens.height(ControlKind.iconButton);
    final textTheme = base.textTheme.copyWith(
      titleLarge: base.textTheme.titleLarge?.copyWith(fontSize: tokens.typeSize(TypeRole.titleLarge)),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontSize: tokens.typeSize(TypeRole.titleMedium)),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: tokens.typeSize(TypeRole.bodyLarge)),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: tokens.typeSize(TypeRole.bodyMedium)),
      bodySmall: base.textTheme.bodySmall?.copyWith(fontSize: tokens.typeSize(TypeRole.bodySmall)),
      labelSmall: base.textTheme.labelSmall?.copyWith(fontSize: tokens.typeSize(TypeRole.labelSmall)),
    );
    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[DesignTokensTheme(tokens: tokens, roles: rolesOfScheme(scheme))],
      visualDensity: switch (tokens.density) {
        Density.compact => VisualDensity.compact,
        Density.standard => VisualDensity.standard,
        // comfortable, not a hypothetical "large": the SDK only guarantees standard/comfortable/compact.
        Density.comfortable => VisualDensity.comfortable,
      },
      materialTapTargetSize: tokens.input == InputMode.pointer
          ? MaterialTapTargetSize.shrinkWrap
          : MaterialTapTargetSize.padded,
      textTheme: textTheme,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: Size(buttonHeight * 2.5, buttonHeight)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(minimumSize: Size(buttonHeight * 2.5, buttonHeight)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: Size(buttonHeight * 2.5, buttonHeight)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: Size(buttonHeight * 2, buttonHeight)),
      ),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(minimumSize: Size(iconSize, iconSize))),
      listTileTheme: ListTileThemeData(
        // The row height is a floor, not a clamp: a two-line title with a subtitle has to be able to grow.
        minVerticalPadding: SpaceToken.space8.px * tokens.density.scale,
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodySmall,
        iconColor: scheme.onSurfaceVariant,
      ),
      appBarTheme: base.appBarTheme.copyWith(
        toolbarHeight: tokens.height(ControlKind.toolbar),
        backgroundColor: scheme.surface,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        isDense: tokens.density == Density.compact,
        contentPadding: EdgeInsets.symmetric(
          horizontal: SpaceToken.space12.px * tokens.density.scale,
          vertical: (inputHeight - tokens.typeSize(TypeRole.bodyLarge)) / 2,
        ),
      ),
      // A focused control on a remote needs to be findable at three metres; the ring weight comes from the
      // tokens, and the colour from the style's scheme.
      focusColor: scheme.tertiary.withValues(alpha: 0.12),
      // A reduced-motion build drops the splash. Route transitions are not mapped here:
      // PageTransitionsTheme falls back to a platform builder for anything it does not list, so an empty
      // map would mean "keep animating" rather than the "do not animate" the setting asks for. A host that
      // wants transitions suppressed passes a duration of zero to its own Navigator.
      splashFactory: tokens.motion.scaleOnFocusAllowed ? base.splashFactory : NoSplash.splashFactory,
    );
  }

  static ThemeData _base(ColorScheme scheme) => ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    appBarTheme: AppBarTheme(backgroundColor: scheme.surface, centerTitle: false),
    navigationBarTheme: NavigationBarThemeData(backgroundColor: scheme.surfaceContainer),
    navigationRailTheme: NavigationRailThemeData(backgroundColor: scheme.surface),
  );

  static ThemeData _buildMaterial(ColorScheme scheme, DesignTokens tokens, TargetPlatform platform) =>
      _base(scheme).copyWith(platform: platform);

  static ThemeData _buildCupertino(ColorScheme scheme, DesignTokens tokens, TargetPlatform platform) {
    // iOS controls (switches, sliders, progress) come from the platform; continuous corners carry the rest.
    // Density and text floors are _applyTokens' business, so a Cupertino build on a TV is not a phone build.
    final radius = BorderRadius.circular(RadiusToken.large.px);
    return _base(scheme).copyWith(
      platform: platform,
      cardTheme: CardThemeData(shape: RoundedRectangleBorder(borderRadius: radius)),
      inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: radius)),
    );
  }

  static ThemeData _buildFluent(ColorScheme scheme, DesignTokens tokens, TargetPlatform platform) {
    // Fluent reads square and dense: 4-ish geometry and sparkle-free ink. The density still comes from the
    // tokens, so a Fluent theme driven by a remote keeps the remote's target sizes.
    final radius = BorderRadius.circular(RadiusToken.small.px);
    return _base(scheme).copyWith(
      platform: platform,
      cardTheme: CardThemeData(shape: RoundedRectangleBorder(borderRadius: radius)),
      inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: radius)),
      splashFactory: InkSparkle.splashFactory,
    );
  }

  static ThemeData _buildMacos(ColorScheme scheme, DesignTokens tokens, TargetPlatform platform) => _base(scheme)
      .copyWith(
        platform: platform,
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RadiusToken.medium.px)),
        ),
        sliderTheme: const SliderThemeData(trackShape: RoundedRectSliderTrackShape()),
      );

  static ThemeData _buildNeumorphic(ColorScheme scheme, DesignTokens tokens, TargetPlatform platform) {
    // The soft-plastic feel is a surface treatment: same-hue surfaces, zero elevation with hairline
    // outlines, generous radii.
    final surface = scheme.surfaceContainerHighest;
    final radius = BorderRadius.circular(RadiusToken.extraLarge.px);
    return _base(scheme).copyWith(
      platform: platform,
      scaffoldBackgroundColor: surface,
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
  }

  static ThemeData _buildYaru(ColorScheme scheme, DesignTokens tokens, TargetPlatform platform) =>
      _base(scheme).copyWith(
        platform: platform,
        appBarTheme: AppBarTheme(
          backgroundColor: scheme.surface,
          centerTitle: false,
          titleTextStyle: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w700, fontSize: 20),
        ),
        // Yaru's pill buttons: the shape is the whole difference, and the size still comes from the tokens.
        filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(shape: const StadiumBorder())),
      );
}

extension on DesignTokens {
  /// The Flutter platform family this token set should render controls as.
  ///
  /// A TV build asks for Android controls with remote sizing, which is exactly what the profile carries;
  /// going through the tokens instead of `defaultTargetPlatform` is what makes the same theme usable on a
  /// device Flutter itself reports as something else.
  TargetPlatform get targetPlatform => switch (platform) {
    PlatformProfile.androidPhone || PlatformProfile.androidTv => TargetPlatform.android,
    PlatformProfile.ios => TargetPlatform.iOS,
    PlatformProfile.windows => TargetPlatform.windows,
    PlatformProfile.macos => TargetPlatform.macOS,
    PlatformProfile.linux => TargetPlatform.linux,
  };
}
