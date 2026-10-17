import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_theme.dart';

/// Windows 11 (WinUI 3, Fluent 2) theme resources used by the Fluent style.
///
/// Values come from microsoft-ui-xaml `Common_themeresources_any.xaml` and
/// `ToggleSwitch_themeresources.xaml`. Colors that WinUI defines with alpha
/// are kept as alpha when they are drawn on top of something (the switch,
/// borders, focus rings). Page, card and text colors are flattened onto the
/// Mica fallback page (#F3F3F3 / #202020) or the card, so that they fit the
/// opaque colors of [SettingsThemeData].
@immutable
class FluentTokens {
  const FluentTokens._({
    required this.page,
    required this.card,
    required this.cardStroke,
    required this.cardPressed,
    required this.cardHoverOverlay,
    required this.cardDisabledOverlay,
    required this.controlStroke,
    required this.controlStrokeSecondary,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.navItemSelected,
    required this.navItemPressed,
    required this.divider,
    required this.overlayPane,
    required this.overlayStroke,
    required this.focusOuter,
    required this.focusInner,
    required this.accent,
    required this.switchOffFill,
    required this.switchOffFillHover,
    required this.switchOffFillPressed,
    required this.switchOffStroke,
    required this.switchOffStrokeDisabled,
    required this.switchOffKnob,
    required this.switchOffKnobDisabled,
    required this.switchOnDisabled,
    required this.switchOnKnobDisabled,
  });

  /// `SolidBackgroundFillColorBase`, the Mica fallback.
  final Color page;

  /// `CardBackgroundFillColorDefault` on [page].
  final Color card;

  /// `CardStrokeColorDefault` on [page].
  final Color cardStroke;

  /// `ControlFillColorTertiary` on [page]: a pressed clickable card.
  final Color cardPressed;

  /// Turns [card] into `ControlFillColorSecondary` on [page]: a hovered
  /// clickable card.
  final Color cardHoverOverlay;

  /// Turns [card] into `ControlFillColorDisabled` on [page].
  final Color cardDisabledOverlay;

  /// `ControlStrokeColorDefault` (alpha). Border of a pressed or disabled
  /// card, and of a hovered one except for its bottom (light) or top (dark)
  /// edge.
  final Color controlStroke;

  /// `ControlStrokeColorSecondary` (alpha). The darker bottom edge (light) or
  /// lighter top edge (dark) of a hovered card.
  final Color controlStrokeSecondary;

  /// `TextFillColorPrimary` on [card].
  final Color textPrimary;

  /// `TextFillColorSecondary` on [card].
  final Color textSecondary;

  /// `TextFillColorDisabled` on [card].
  final Color textDisabled;

  /// `SubtleFillColorSecondary` on [page]: the selected (and hovered) item
  /// of a NavigationView pane.
  final Color navItemSelected;

  /// `SubtleFillColorTertiary` on [page]: a pressed NavigationView item, and
  /// a hovered selected one.
  final Color navItemPressed;

  /// `DividerStrokeColorDefault` (alpha): NavigationView separators.
  final Color divider;

  /// The NavigationView pane opened over the content from the compact rail
  /// (`NavigationViewDefaultPaneBackground`, acrylic; its flat fallback).
  final Color overlayPane;

  /// `SurfaceStrokeColorFlyout` (alpha): the edge of that pane.
  final Color overlayStroke;

  /// `FocusStrokeColorOuter` (alpha), the 2px outer focus ring.
  final Color focusOuter;

  /// `FocusStrokeColorInner` (alpha), the 1px inner focus ring.
  final Color focusInner;

  /// `AccentFillColorDefault` for the default Windows 11 accent, as the
  /// Settings app shows it: #0067C0 in light mode, #4CC2FF in dark mode.
  /// (WinUI's built-in fallback, used when there is no system accent, is
  /// #005FB8 / #60CDFF.)
  final Color accent;

  /// `ControlAltFillColorSecondary` / `Tertiary` / `Quarternary` (alpha):
  /// the fill of an OFF switch at rest, hovered and pressed.
  final Color switchOffFill;
  final Color switchOffFillHover;
  final Color switchOffFillPressed;

  /// `ControlStrongStrokeColorDefault` / `Disabled` (alpha): the outline of
  /// an OFF switch.
  final Color switchOffStroke;
  final Color switchOffStrokeDisabled;

  /// `TextFillColorSecondary` / `Disabled` (alpha): the knob of an OFF switch.
  final Color switchOffKnob;
  final Color switchOffKnobDisabled;

  /// `AccentFillColorDisabled` (alpha): the track of a disabled ON switch.
  final Color switchOnDisabled;

  /// `TextOnAccentFillColorDisabled` (alpha): the knob of a disabled ON
  /// switch.
  final Color switchOnKnobDisabled;

  static const FluentTokens light = FluentTokens._(
    page: Color(0xFFF3F3F3),
    card: Color(0xFFFBFBFB),
    cardStroke: Color(0xFFE5E5E5),
    cardPressed: Color(0xFFF5F5F5),
    cardHoverOverlay: Color(0x05000000),
    cardDisabledOverlay: Color(0x06000000),
    controlStroke: Color(0x0F000000),
    controlStrokeSecondary: Color(0x29000000),
    textPrimary: Color(0xFF1B1B1B),
    textSecondary: Color(0xFF5F5F5F),
    textDisabled: Color(0xFFA0A0A0),
    navItemSelected: Color(0xFFEAEAEA),
    navItemPressed: Color(0xFFEDEDED),
    divider: Color(0x0F000000),
    overlayPane: Color(0xFFF9F9F9),
    overlayStroke: Color(0x0F000000),
    focusOuter: Color(0xE4000000),
    focusInner: Color(0xB3FFFFFF),
    accent: Color(0xFF0067C0),
    switchOffFill: Color(0x06000000),
    switchOffFillHover: Color(0x0F000000),
    switchOffFillPressed: Color(0x18000000),
    switchOffStroke: Color(0x72000000),
    switchOffStrokeDisabled: Color(0x37000000),
    switchOffKnob: Color(0x9E000000),
    switchOffKnobDisabled: Color(0x5C000000),
    switchOnDisabled: Color(0x37000000),
    switchOnKnobDisabled: Color(0xFFFFFFFF),
  );

  static const FluentTokens dark = FluentTokens._(
    page: Color(0xFF202020),
    card: Color(0xFF2B2B2B),
    cardStroke: Color(0xFF1D1D1D),
    cardPressed: Color(0xFF272727),
    cardHoverOverlay: Color(0x08FFFFFF),
    cardDisabledOverlay: Color(0x06000000),
    controlStroke: Color(0x12FFFFFF),
    controlStrokeSecondary: Color(0x18FFFFFF),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFCFCFCF),
    textDisabled: Color(0xFF787878),
    navItemSelected: Color(0xFF2D2D2D),
    navItemPressed: Color(0xFF292929),
    divider: Color(0x15FFFFFF),
    overlayPane: Color(0xFF2C2C2C),
    overlayStroke: Color(0x33000000),
    focusOuter: Color(0xFFFFFFFF),
    focusInner: Color(0xB3000000),
    accent: Color(0xFF4CC2FF),
    switchOffFill: Color(0x19000000),
    switchOffFillHover: Color(0x0BFFFFFF),
    switchOffFillPressed: Color(0x12FFFFFF),
    switchOffStroke: Color(0x8BFFFFFF),
    switchOffStrokeDisabled: Color(0x28FFFFFF),
    switchOffKnob: Color(0xC5FFFFFF),
    switchOffKnobDisabled: Color(0x5DFFFFFF),
    switchOnDisabled: Color(0x28FFFFFF),
    switchOnKnobDisabled: Color(0x87FFFFFF),
  );

  static FluentTokens of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// Whether Fluent controls in [context] should use the dark resources.
  ///
  /// Inside a settings list this follows the card color, so the translucent
  /// control colors always suit the surface they are drawn on, also when
  /// `SettingsList.brightness` or a custom card color differs from the app
  /// theme. Elsewhere it follows the [CupertinoTheme], which follows the
  /// Material theme in a `MaterialApp`, and then the platform.
  static Brightness brightnessOf(BuildContext context) {
    final Color? card = context
        .dependOnInheritedWidgetOfExactType<SettingsTheme>()
        ?.themeData
        .settingsSectionBackground;
    if (card != null) return ThemeData.estimateBrightnessForColor(card);
    return CupertinoTheme.maybeBrightnessOf(context) ?? Brightness.light;
  }
}

/// The WinUI theme resources for [context], light or dark as
/// [FluentTokens.brightnessOf] says.
FluentTokens fluentTokensOf(BuildContext context) =>
    FluentTokens.of(FluentTokens.brightnessOf(context));

/// The Windows 11 type ramp (Segoe UI Variable). The font itself comes from
/// the app: Flutter uses Segoe UI on Windows.
abstract final class FluentTypography {
  /// Body: 14/20 regular.
  static const TextStyle body = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// BodyStrong: 14/20 semibold.
  static const TextStyle bodyStrong = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Caption: 12/16 regular.
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );
}

/// WinUI motion durations: ControlFasterAnimationDuration and
/// ControlNormalAnimationDuration.
const Duration kFluentFasterDuration = Duration(milliseconds: 83);
const Duration kFluentNormalDuration = Duration(milliseconds: 167);

/// ControlFastOutSlowInKeySpline (0,0,0,1).
const Curve kFluentFastOutSlowIn = Cubic(0, 0, 0, 1);

/// Paints the WinUI keyboard focus visual around [rect]: a 2px outer ring
/// and a 1px inner ring, both outside [rect] (FocusVisualMargin -3), with
/// corners following [radius].
void paintFluentFocusRing(
  Canvas canvas,
  Rect rect,
  double radius,
  FluentTokens tokens,
) {
  final RRect edge = RRect.fromRectAndRadius(rect, Radius.circular(radius));
  final RRect middle = edge.inflate(1);
  final RRect outer = edge.inflate(3);
  canvas.drawDRRect(outer, middle, Paint()..color = tokens.focusOuter);
  canvas.drawDRRect(middle, edge, Paint()..color = tokens.focusInner);
}
