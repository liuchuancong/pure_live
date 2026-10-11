import 'package:flutter/widgets.dart';
import 'package:live_uikit/src/core/ui_component_registry.dart';
import 'package:live_uikit/src/core/ui_configuration.dart';
import 'package:live_uikit/src/core/ui_environment.dart';
import 'package:live_uikit/src/design_languages/neumorphic/neumorphic_components.dart';
import 'package:live_uikit/src/theme/live_theme_parts.dart';
import 'package:live_uikit/src/tokens/radii.dart';

/// The Neumorphic design language.
///
/// Soft-embossed surfaces: every control is the same colour as the page and
/// only its light and shadow say whether it stands out or is pressed in.
/// That single rule drives everything here — the palette is flattened to one
/// base tone (the surface tinted slightly towards the accent, so the
/// shadows have something to fall on), corners are round (20px, the
/// language's most recognisable trait), and there is no border anywhere,
/// because a border would break the illusion of a single moulded surface.
///
/// The depth values come from the layout mode rather than the library's
/// defaults: a TV needs deeper shadows to read at distance, while a desktop
/// with a mouse shows them at a glance.
abstract final class NeumorphicLanguage {
  /// The language's component implementation.
  static const NeumorphicComponents components = NeumorphicComponents();

  /// The language's adapter, for the registry.
  static const LiveDesignLanguageAdapter adapter = LiveDesignLanguageAdapter(
    theme: _buildTheme,
    components: components,
  );

  static LiveThemeParts _buildTheme(LiveDesignLanguageContext context) {
    final base = context.base;
    final density = base.componentTheme;
    final radius = density.density == LiveUiDensity.spacious ? LiveRadii.lg : 20.0;
    // One base tone for the whole surface: the page colour carried a few
    // percent towards the accent, which is what makes a neumorphic screen
    // read as a single sheet rather than as tiles on a background.
    final baseColor = Color.alphaBlend(base.colors.primary.withValues(alpha: 0.05), base.colors.surfaceVariant);
    final colors = base.colors.copyWith(
      surface: baseColor,
      surfaceElevated: baseColor,
      surfaceVariant: Color.alphaBlend(base.colors.textPrimary.withValues(alpha: 0.04), baseColor),
      outline: const Color(0x00000000),
      divider: base.colors.textPrimary.withValues(alpha: 0.08),
    );
    final geometry = density.copyWith(
      controlRadius: radius,
      cardRadius: radius,
      cardElevation: 0,
      dialogRadius: radius,
      menuRadius: radius,
      inputRadius: radius,
      inputHeight: density.inputHeight,
      cardPadding: const EdgeInsets.all(16),
      cardPaddingDense: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      heightSmall: 34,
      heightMedium: 46,
      heightLarge: 58,
    );
    return base.withParts(
      colors: colors,
      componentTheme: geometry,
      focus: base.focus.copyWith(
        // Neumorphism says "focused" with depth, not with ink: the ring is
        // off and the surface lifts instead.
        showRing: false,
        ringWidth: 0,
        ringOffset: 0,
        ringRadius: radius,
        liftElevation: 10,
        scale: context.environment.layoutMode == LiveLayoutMode.tv ? 1.04 : 1,
      ),
    );
  }
}
