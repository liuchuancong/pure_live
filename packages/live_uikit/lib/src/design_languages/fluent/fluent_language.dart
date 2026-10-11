import 'package:flutter/widgets.dart';

import 'package:live_uikit/src/core/ui_component_registry.dart';
import 'package:live_uikit/src/design_languages/fluent/fluent_components.dart';
import 'package:live_uikit/src/theme/live_theme_parts.dart';
import 'package:live_uikit/src/tokens/radii.dart';

/// The Fluent design language.
///
/// Windows is the tightest of the six: 4px corners, 32px controls, no
/// elevation on cards (a border instead), and a type scale that starts one
/// step below Material's at the same density. The palette stays the
/// accent-derived one, and the accent is handed to Fluent as a full swatch
/// so hover and pressed states keep the Windows feel instead of turning
/// grey.
abstract final class FluentLanguage {
  /// The language's component implementation.
  static const FluentComponents components = FluentComponents();

  /// The language's adapter, for the registry.
  static const LiveDesignLanguageAdapter adapter = LiveDesignLanguageAdapter(
    theme: _buildTheme,
    components: components,
  );

  static LiveThemeParts _buildTheme(LiveDesignLanguageContext context) {
    final base = context.base;
    final density = base.componentTheme;
    final geometry = density.copyWith(
      controlRadius: LiveRadii.xs,
      cardRadius: LiveRadii.xs,
      cardElevation: 0,
      dialogRadius: LiveRadii.sm,
      menuRadius: LiveRadii.xs,
      inputRadius: LiveRadii.xs,
      inputHeight: density.inputHeight,
      cardPadding: const EdgeInsets.all(12),
      cardPaddingDense: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      // Windows controls are shorter than the touch minimum even when the
      // density is comfortable; the minimum target size still protects TV
      // builds through the environment.
      heightSmall: 24,
      heightMedium: 32,
      heightLarge: 40,
    );
    return base.withParts(
      componentTheme: geometry,
      focus: base.focus.copyWith(ringWidth: 2, ringOffset: 1, ringRadius: geometry.controlRadius, scale: 1),
    );
  }
}
