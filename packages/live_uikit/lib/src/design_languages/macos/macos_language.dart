import 'package:flutter/widgets.dart';

import 'package:live_uikit/src/core/ui_component_registry.dart';
import 'package:live_uikit/src/design_languages/macos/macos_components.dart';
import 'package:live_uikit/src/theme/live_theme_parts.dart';
import 'package:live_uikit/src/tokens/radii.dart';

/// The macOS design language.
///
/// Flat and tight: 6px corners on controls, 8px on cards and menus, hairline
/// borders instead of elevation, and controls a step shorter than the touch
/// minimum — macOS assumes a trackpad, and a desktop UI that keeps phone
/// control heights looks broken next to native windows. The palette stays
/// the accent-derived one; macOS uses the accent sparingly (the default
/// button and selection) which is exactly where this language puts
/// `primary`.
abstract final class MacosLanguage {
  /// The language's component implementation.
  static const MacosComponents components = MacosComponents();

  /// The language's adapter, for the registry.
  static const LiveDesignLanguageAdapter adapter = LiveDesignLanguageAdapter(
    theme: _buildTheme,
    components: components,
  );

  /// The macOS corner radii, exposed because the shell widgets of the
  /// application (sidebar, tab view) follow them too.
  static const double controlRadius = 6;

  static LiveThemeParts _buildTheme(LiveDesignLanguageContext context) {
    final base = context.base;
    final density = base.componentTheme;
    final geometry = density.copyWith(
      controlRadius: controlRadius,
      cardRadius: LiveRadii.sm,
      cardElevation: 0,
      dialogRadius: LiveRadii.sm,
      menuRadius: LiveRadii.sm,
      inputRadius: 4,
      inputHeight: 28,
      cardPadding: const EdgeInsets.all(12),
      cardPaddingDense: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      heightSmall: 22,
      heightMedium: 28,
      heightLarge: 36,
      menuItemHeight: 24,
      menuItemPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    );
    return base.withParts(
      componentTheme: geometry,
      focus: base.focus.copyWith(
        // macOS shows focus as a tinted ring around the control, drawn
        // inside the border rather than outside it.
        ringWidth: 3,
        ringOffset: -1,
        ringRadius: controlRadius,
        scale: 1,
      ),
    );
  }
}
