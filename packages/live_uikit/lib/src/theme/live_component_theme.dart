import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:live_uikit/src/components/contracts/live_component_specs.dart';
import 'package:live_uikit/src/core/ui_configuration.dart';
import 'package:live_uikit/src/core/ui_environment.dart';
import 'package:live_uikit/src/tokens/radii.dart';
import 'package:live_uikit/src/tokens/sizing.dart';
import 'package:live_uikit/src/tokens/spacing.dart';

part 'live_component_theme.freezed.dart';

/// The geometry every component builds with: control heights, paddings,
/// radii, gaps and minimum target sizes.
///
/// This is where density becomes numbers, in one place. Components read
/// `componentTheme` and never pick a size themselves, which is what makes
/// "compact desktop / comfortable phone / spacious TV" a single value to
/// change instead of a sweep through the widget tree. Design languages
/// override individual fields (Fluent's 4px corners, Neumorphic's 20px
/// ones) while keeping the semantic ladder intact.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class LiveComponentTheme with _$LiveComponentTheme {
  /// A component geometry; use [forDensity] to derive one from a density.
  const factory LiveComponentTheme({
    /// The density these numbers were derived from.
    required LiveUiDensity density,

    /// The corner radius of a button or other control surface.
    required double controlRadius,

    /// The height of a [LiveControlSize.small] control.
    required double heightSmall,

    /// The height of a [LiveControlSize.medium] control.
    required double heightMedium,

    /// The height of a [LiveControlSize.large] control.
    required double heightLarge,

    /// The horizontal padding inside a control.
    required double controlPadding,

    /// The gap between an icon and its label.
    required double iconGap,

    /// The default icon size inside controls.
    required double iconSize,

    /// The corner radius of cards.
    required double cardRadius,

    /// The elevation of a card at rest.
    required double cardElevation,

    /// The padding inside a card.
    required EdgeInsets cardPadding,

    /// The padding inside a dense card (list tiles, compact rows).
    required EdgeInsets cardPaddingDense,

    /// The corner radius of dialogs and sheets.
    required double dialogRadius,

    /// The maximum width of a dialog.
    required double dialogMaxWidth,

    /// The padding inside a dialog.
    required EdgeInsets dialogPadding,

    /// The corner radius of menus and popups.
    required double menuRadius,

    /// The height of a menu entry.
    required double menuItemHeight,

    /// The padding inside a menu entry.
    required EdgeInsets menuItemPadding,

    /// The corner radius of text fields.
    required double inputRadius,

    /// The border width of outlined inputs.
    required double inputBorderWidth,

    /// The height of a text field.
    required double inputHeight,

    /// The padding of a page's content on a narrow layout.
    required EdgeInsets pagePadding,

    /// The padding of a page's content on a wide layout.
    required EdgeInsets pagePaddingWide,

    /// The vertical gap between page sections.
    required double sectionGap,

    /// The height of a list tile.
    required double listTileHeight,

    /// The smallest a control may be drawn, from the input modes in force.
    required double minTargetSize,

    /// The size of the loading indicator.
    required double loadingIndicatorSize,
  }) = _LiveComponentTheme;

  /// The geometry [density] implies.
  // A constructor cannot express this: the values come from a table with
  // per-density arithmetic, not from defaults.
  // ignore: prefer_constructors_over_static_methods
  static LiveComponentTheme forDensity(LiveUiDensity density) => switch (density) {
    LiveUiDensity.compact => LiveComponentTheme(
      density: density,
      controlRadius: LiveRadii.xs,
      heightSmall: 28,
      heightMedium: LiveSizing.controlHeightCompact,
      heightLarge: 44,
      controlPadding: LiveSpacing.md,
      iconGap: LiveSpacing.xs,
      iconSize: LiveSizing.iconSm,
      cardRadius: LiveRadii.sm,
      cardElevation: 0,
      cardPadding: const EdgeInsets.all(LiveSpacing.md),
      cardPaddingDense: const EdgeInsets.symmetric(horizontal: LiveSpacing.md, vertical: LiveSpacing.sm),
      dialogRadius: LiveRadii.md,
      dialogMaxWidth: 440,
      dialogPadding: const EdgeInsets.all(LiveSpacing.lg),
      menuRadius: LiveRadii.xs,
      menuItemHeight: 32,
      menuItemPadding: const EdgeInsets.symmetric(horizontal: LiveSpacing.md, vertical: LiveSpacing.xs),
      inputRadius: LiveRadii.xs,
      inputBorderWidth: 1,
      inputHeight: 32,
      pagePadding: const EdgeInsets.all(LiveSpacing.lg),
      pagePaddingWide: const EdgeInsets.symmetric(horizontal: LiveSpacing.xl, vertical: LiveSpacing.lg),
      sectionGap: LiveSpacing.lg,
      listTileHeight: 44,
      minTargetSize: LiveSizing.minTouchTarget,
      loadingIndicatorSize: 20,
    ),
    LiveUiDensity.comfortable => LiveComponentTheme(
      density: density,
      controlRadius: LiveRadii.sm,
      heightSmall: 32,
      heightMedium: LiveSizing.controlHeight,
      heightLarge: 52,
      controlPadding: LiveSpacing.lg,
      iconGap: LiveSpacing.sm,
      iconSize: LiveSizing.iconMd,
      cardRadius: LiveRadii.md,
      cardElevation: 1,
      cardPadding: const EdgeInsets.all(LiveSpacing.md),
      cardPaddingDense: const EdgeInsets.symmetric(horizontal: LiveSpacing.md, vertical: LiveSpacing.sm),
      dialogRadius: LiveRadii.lg,
      dialogMaxWidth: 480,
      dialogPadding: const EdgeInsets.all(LiveSpacing.xl),
      menuRadius: LiveRadii.sm,
      menuItemHeight: 40,
      menuItemPadding: const EdgeInsets.symmetric(horizontal: LiveSpacing.lg, vertical: LiveSpacing.sm),
      inputRadius: LiveRadii.sm,
      inputBorderWidth: 1,
      inputHeight: 44,
      pagePadding: const EdgeInsets.all(LiveSpacing.lg),
      pagePaddingWide: const EdgeInsets.symmetric(horizontal: LiveSpacing.xl, vertical: LiveSpacing.lg),
      sectionGap: LiveSpacing.xl,
      listTileHeight: 56,
      minTargetSize: LiveSizing.minTouchTarget,
      loadingIndicatorSize: 24,
    ),
    LiveUiDensity.spacious => LiveComponentTheme(
      density: density,
      controlRadius: LiveRadii.md,
      heightSmall: 40,
      heightMedium: LiveSizing.controlHeightTv,
      heightLarge: 64,
      controlPadding: LiveSpacing.xl,
      iconGap: LiveSpacing.md,
      iconSize: LiveSizing.iconLg,
      cardRadius: LiveRadii.lg,
      cardElevation: 2,
      cardPadding: const EdgeInsets.all(LiveSpacing.xl),
      cardPaddingDense: const EdgeInsets.symmetric(horizontal: LiveSpacing.lg, vertical: LiveSpacing.md),
      dialogRadius: LiveRadii.xl,
      dialogMaxWidth: 640,
      dialogPadding: const EdgeInsets.all(LiveSpacing.xxl),
      menuRadius: LiveRadii.md,
      menuItemHeight: 56,
      menuItemPadding: const EdgeInsets.symmetric(horizontal: LiveSpacing.xl, vertical: LiveSpacing.md),
      inputRadius: LiveRadii.md,
      inputBorderWidth: 2,
      inputHeight: 56,
      pagePadding: const EdgeInsets.all(LiveSpacing.xl),
      pagePaddingWide: const EdgeInsets.symmetric(horizontal: LiveSpacing.xxl, vertical: LiveSpacing.xl),
      sectionGap: LiveSpacing.xxl,
      listTileHeight: 72,
      minTargetSize: LiveSizing.minRemoteTarget,
      loadingIndicatorSize: 32,
    ),
  };

  /// The geometry for a layout mode's default density.
  static LiveComponentTheme forLayoutMode(LiveLayoutMode mode) =>
      LiveComponentTheme.forDensity(LiveUiDensity.forLayoutMode(mode));

  /// The geometry an environment implies, with the target size raised to
  /// the remote minimum when the UI must be operable without touch.
  static LiveComponentTheme forEnvironment(LiveUiDensity density, LiveUiEnvironment environment) {
    final theme = LiveComponentTheme.forDensity(density);
    if (!environment.needsFocusNavigation) {
      return theme;
    }
    return theme.copyWith(
      minTargetSize: theme.minTargetSize < LiveSizing.minRemoteTarget
          ? LiveSizing.minRemoteTarget
          : theme.minTargetSize,
    );
  }
}

/// The geometry's derived values.
extension LiveComponentThemeX on LiveComponentTheme {
  /// The control height of a semantic [size].
  double heightFor(LiveControlSize size) => switch (size) {
    LiveControlSize.small => heightSmall,
    LiveControlSize.medium => heightMedium,
    LiveControlSize.large => heightLarge,
  };

  /// The page padding for a layout mode.
  EdgeInsets pagePaddingFor(LiveLayoutMode mode) => mode == LiveLayoutMode.mobile ? pagePadding : pagePaddingWide;
}
