import 'package:flutter/widgets.dart';
import 'package:live_uikit/src/core/ui_component_registry.dart';
import 'package:live_uikit/src/design_languages/yaru/yaru_components.dart';
import 'package:live_uikit/src/theme/live_theme_parts.dart';
import 'package:live_uikit/src/tokens/radii.dart';
import 'package:yaru/yaru.dart' show YaruColors, YaruVariant;

/// The Yaru design language.
///
/// Ubuntu's visual language is rounder and softer than Material's — 8px
/// corners, ~36px controls, generous padding, and the Ubuntu orange as the
/// accent unless the user has chosen another. The accent handling is where
/// this language differs from the other five: when the user has not picked
/// a colour, the Ubuntu variant colour is used rather than the derived
/// seed, so a Linux desktop build looks like Ubuntu rather than like a
/// generic Material app; a user's own accent still wins.
abstract final class YaruLanguage {
  /// The language's component implementation.
  static const YaruComponents components = YaruComponents();

  /// The language's adapter, for the registry.
  static const LiveDesignLanguageAdapter adapter = LiveDesignLanguageAdapter(
    theme: _buildTheme,
    components: components,
  );

  /// The Ubuntu accent, used when the user has not chosen an accent.
  static const Color ubuntuAccent = YaruColors.orange;

  static LiveThemeParts _buildTheme(LiveDesignLanguageContext context) {
    final base = context.base;
    final density = base.componentTheme;
    final geometry = density.copyWith(
      controlRadius: LiveRadii.sm,
      cardRadius: LiveRadii.sm,
      cardElevation: 0,
      dialogRadius: LiveRadii.md,
      menuRadius: LiveRadii.sm,
      inputRadius: LiveRadii.sm,
      inputHeight: density.inputHeight,
      cardPadding: const EdgeInsets.all(16),
      cardPaddingDense: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      pagePadding: const EdgeInsets.all(16),
      pagePaddingWide: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    );
    final colors = context.configuration.accentColor == null
        ? base.colors.copyWith(
            primary: ubuntuAccent,
            onPrimary: _readableOn(ubuntuAccent, context.base.typography.body.color),
          )
        : base.colors;
    return base.withParts(
      colors: colors,
      componentTheme: geometry,
      focus: base.focus.copyWith(ringWidth: 2, ringOffset: 2, ringRadius: geometry.controlRadius, scale: 1),
    );
  }

  /// Black or white text on [background], by its luminance.
  ///
  /// Ubuntu orange is bright enough that white text on it is uncomfortable,
  /// so the on-accent colour is computed rather than assumed.
  static Color _readableOn(Color background, Color? fallback) =>
      background.computeLuminance() > 0.55 ? const Color(0xFF1A1A1A) : (fallback ?? const Color(0xFFFFFFFF));

  /// The Yaru variants the settings page can offer, by display name.
  static List<(YaruVariant, String)> get variants => [
    for (final variant in YaruVariant.values) (variant, variant.name),
  ];
}
