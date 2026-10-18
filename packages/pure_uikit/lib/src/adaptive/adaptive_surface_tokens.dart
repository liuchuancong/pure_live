import 'package:flutter/widgets.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// The semantic surface colours the adaptive navigation reads, resolved from
/// the active design language's `PureTheme` rather than a palette of its
/// own.
///
/// The adaptive shell is one structure shared by every design language: this
/// class is the whole reason that can hold. Each field keeps the role name the
/// Fluent reference used (`sidebar`, `brand`, `live`, …) so the navigation
/// surfaces read naturally, while the value underneath comes from whichever
/// language's tokens are in scope — Material's primary, Fluent's accent and
/// macOS's controls all land here through `PureTheme.of(context).colors`.
@immutable
final class AdaptiveSurfaceColors {
  /// Resolved roles; produced by `of`, never constructed by callers.
  const new({
    required this.brand,
    required this.brandHover,
    required this.brandPressed,
    required this.brandSubtle,
    required this.onBrand,
    required this.live,
    required this.liveSubtle,
    required this.success,
    required this.background,
    required this.surface,
    required this.surfaceSecondary,
    required this.sidebar,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.hover,
    required this.pressed,
    required this.isDark,
  });

  /// Reads the roles from the nearest [PureTheme]; asserts without one, the
  /// same contract every Pure widget carries.
  factory of(BuildContext context) {
    final theme = PureTheme.of(context);
    final colors = theme.colors;
    return AdaptiveSurfaceColors(
      brand: colors.primary,
      brandHover: colors.primaryHover,
      brandPressed: colors.primaryActive,
      brandSubtle: colors.primaryBg,
      onBrand: colors.textLightSolid,
      live: colors.error,
      liveSubtle: colors.errorBg,
      success: colors.success,
      background: colors.bgLayout,
      surface: colors.bgContainer,
      surfaceSecondary: colors.bgElevated,
      sidebar: colors.bgContainer,
      border: colors.borderSecondary,
      borderStrong: colors.border,
      textPrimary: colors.text,
      textSecondary: colors.textSecondary,
      textTertiary: colors.textTertiary,
      hover: colors.fillQuaternary,
      pressed: colors.fillTertiary,
      isDark: theme.isDark,
    );
  }

  /// The accent colour: selection marks, active glyphs.
  final Color brand;

  /// Hover state of the accent.
  final Color brandHover;

  /// Pressed state of the accent.
  final Color brandPressed;

  /// The accent's subtle background — a selected destination's pill.
  final Color brandSubtle;

  /// A readable foreground on top of `brand`.
  final Color onBrand;

  /// The "on air" colour: live badges and dots.
  final Color live;

  /// The live colour's subtle background.
  final Color liveSubtle;

  /// Success accents.
  final Color success;

  /// The page background behind scrolled content.
  final Color background;

  /// Cards, app bars, bottom bar.
  final Color surface;

  /// Secondary surfaces (list rows, wells).
  final Color surfaceSecondary;

  /// Navigation surfaces: sidebar, rail, drawer.
  final Color sidebar;

  /// The subtle hairline between navigation and content.
  final Color border;

  /// A firmer hairline for dividers inside navigation.
  final Color borderStrong;

  /// Primary text.
  final Color textPrimary;

  /// Default destination glyphs and labels.
  final Color textSecondary;

  /// Disabled and tertiary text.
  final Color textTertiary;

  /// Hover fill over a navigation row.
  final Color hover;

  /// Pressed fill over a navigation row.
  final Color pressed;

  /// Whether the resolved theme is dark.
  final bool isDark;

}

/// Convenient access to the adaptive surface roles.
extension AdaptiveSurfaceColorsContext on BuildContext {
  /// The adaptive surface roles from the nearest [PureTheme].
  AdaptiveSurfaceColors get adaptiveSurfaces => AdaptiveSurfaceColors.of(this);
}
