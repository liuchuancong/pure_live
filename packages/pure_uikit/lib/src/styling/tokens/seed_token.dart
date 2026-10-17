import 'package:flutter/widgets.dart';

/// The seed layer of the token system — the small set of values a designer or
/// user actually decides on. Everything else is *derived* from these by a theme
/// algorithm, exactly as in Ant Design v5, where the docs warn "do not
/// use a seed token directly": components read the derived alias tokens, and
/// only the seed is authored.
@immutable
final class SeedToken {
  /// A seed token; every argument defaults to Ant Design's published value.
  const new({
    this.colorPrimary = const Color(0xFF1677FF),
    this.colorSuccess = const Color(0xFF52C41A),
    this.colorWarning = const Color(0xFFFAAD14),
    this.colorError = const Color(0xFFFF4D4F),
    this.colorInfo = const Color(0xFF1677FF),
    this.colorLink,
    this.colorTextBase,
    this.colorBgBase,
    this.fontFamily,
    this.fontFamilyCode,
    this.fontSize = 14,
    this.lineWidth = 1,
    this.borderRadius = 6,
    this.sizeUnit = 4,
    this.sizeStep = 4,
    this.controlHeight = 32,
    this.zIndexBase = 0,
    this.zIndexPopupBase = 1000,
    this.opacityImage = 1,
    this.motionBase = 0,
    this.motionUnit = 0.1,
    this.motion = true,
    this.wireframe = false,
    this.focusOutline = true,
    this.pureBlack = false,
  });

  /// The brand / primary action colour; the whole primary ramp grows from it.
  final Color colorPrimary;

  /// The success colour and its ramp.
  final Color colorSuccess;

  /// The warning colour and its ramp.
  final Color colorWarning;

  /// The error / danger colour and its ramp.
  final Color colorError;

  /// The info colour and its ramp.
  final Color colorInfo;

  /// The link colour; defaults to [colorInfo] when null.
  final Color? colorLink;

  /// The base text colour the neutral text/fill ramps derive from. Defaults to
  /// black in the light algorithm and white in the dark one.
  final Color? colorTextBase;

  /// The base background colour the neutral surface ramps derive from. Defaults
  /// to white (light) or black (dark).
  final Color? colorBgBase;

  /// The default UI font family; null uses the platform default.
  final String? fontFamily;

  /// The monospace family for code; null uses the platform default.
  final String? fontFamilyCode;

  /// The base font size, from which the modular type scale is derived.
  final double fontSize;

  /// The border/divider width.
  final double lineWidth;

  /// The base corner radius, from which the radius scale is derived.
  final double borderRadius;

  /// The size-change unit (Ant's base is 4 for fine-grained steps).
  final double sizeUnit;

  /// The size base step; compact themes shrink this to tighten the layout.
  final double sizeStep;

  /// The height of base controls (buttons, inputs).
  final double controlHeight;

  /// The base stacking level.
  final double zIndexBase;

  /// The base stacking level of popups (modals, dropdowns).
  final double zIndexPopupBase;

  /// Default image opacity, useful to dim images in a dark theme.
  final double opacityImage;

  /// The animation base duration, in seconds.
  final double motionBase;

  /// The animation duration step, in seconds.
  final double motionUnit;

  /// Whether motion runs; false zeroes every duration.
  final bool motion;

  /// Wireframe style: the V4 boxier look; a style axis, not a colour.
  final bool wireframe;

  /// Whether focused controls show a visible outline.
  final bool focusOutline;

  /// Whether dark surfaces collapse to true black (OLED-friendly).
  final bool pureBlack;

  /// The seed with some fields replaced.
  SeedToken copyWith({
    Color? colorPrimary,
    Color? colorSuccess,
    Color? colorWarning,
    Color? colorError,
    Color? colorInfo,
    Color? colorLink,
    Color? colorTextBase,
    Color? colorBgBase,
    String? fontFamily,
    String? fontFamilyCode,
    double? fontSize,
    double? lineWidth,
    double? borderRadius,
    double? sizeUnit,
    double? sizeStep,
    double? controlHeight,
    double? motionUnit,
    bool? motion,
    bool? pureBlack,
    bool? focusOutline,
  }) => SeedToken(
    colorPrimary: colorPrimary ?? this.colorPrimary,
    colorSuccess: colorSuccess ?? this.colorSuccess,
    colorWarning: colorWarning ?? this.colorWarning,
    colorError: colorError ?? this.colorError,
    colorInfo: colorInfo ?? this.colorInfo,
    colorLink: colorLink ?? this.colorLink,
    colorTextBase: colorTextBase ?? this.colorTextBase,
    colorBgBase: colorBgBase ?? this.colorBgBase,
    fontFamily: fontFamily ?? this.fontFamily,
    fontFamilyCode: fontFamilyCode ?? this.fontFamilyCode,
    fontSize: fontSize ?? this.fontSize,
    lineWidth: lineWidth ?? this.lineWidth,
    borderRadius: borderRadius ?? this.borderRadius,
    sizeUnit: sizeUnit ?? this.sizeUnit,
    sizeStep: sizeStep ?? this.sizeStep,
    controlHeight: controlHeight ?? this.controlHeight,
    zIndexBase: zIndexBase,
    zIndexPopupBase: zIndexPopupBase,
    opacityImage: opacityImage,
    motionBase: motionBase,
    motionUnit: motionUnit ?? this.motionUnit,
    motion: motion ?? this.motion,
    wireframe: wireframe,
    focusOutline: focusOutline ?? this.focusOutline,
    pureBlack: pureBlack ?? this.pureBlack,
  );

  @override
  bool operator ==(Object other) =>
      other is SeedToken &&
      other.colorPrimary == colorPrimary &&
      other.colorError == colorError &&
      other.colorTextBase == colorTextBase &&
      other.colorBgBase == colorBgBase &&
      other.fontFamily == fontFamily &&
      other.fontSize == fontSize &&
      other.borderRadius == borderRadius &&
      other.sizeStep == sizeStep &&
      other.controlHeight == controlHeight &&
      other.motion == motion &&
      other.pureBlack == pureBlack;

  @override
  int get hashCode => Object.hash(
    colorPrimary,
    colorError,
    colorTextBase,
    colorBgBase,
    fontFamily,
    fontSize,
    borderRadius,
    sizeStep,
    controlHeight,
    motion,
    pureBlack,
  );
}
