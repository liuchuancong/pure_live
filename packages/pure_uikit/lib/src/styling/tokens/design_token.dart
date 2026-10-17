import 'package:flutter/widgets.dart';
import 'package:pure_uikit/src/styling/tokens/color_engine.dart';
import 'package:pure_uikit/src/styling/tokens/seed_token.dart';

/// The resolved design token a component reads — the equivalent of Ant
/// Design's `AliasToken`: the seed and map layers collapsed into semantic,
/// ready-to-use values. It is produced by a theme algorithm (see
/// `theme_algorithm.dart`) and is immutable and cheap to hand down the tree.
@immutable
final class DesignToken {
  /// A resolved token; built by the algorithms, not by hand.
  const new({
    required this.seed,
    required this.color,
    required this.type,
    required this.scale,
    required this.motion,
    required this.isDark,
  });

  /// Derives the full token set from [seed] for light or dark.
  ///
  /// This is `derivative` + `formatToken` from Ant's theme pipeline: build the
  /// ten-step colour ramps, the neutral text/fill/background ramps, then the
  /// font/size/radius/height scales, then the semantic aliases and shadows.
  factory derive(SeedToken seed, {required bool dark}) {
    final textBase = seed.colorTextBase ?? (dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000));
    var bgBase = seed.colorBgBase ?? (dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF));
    if (dark && seed.pureBlack) {
      bgBase = const Color(0xFF000000);
    }

    final primary = ColorRamp.of(seed.colorPrimary, dark: dark);
    final success = ColorRamp.of(seed.colorSuccess, dark: dark);
    final warning = ColorRamp.of(seed.colorWarning, dark: dark);
    final error = ColorRamp.of(seed.colorError, dark: dark);
    final info = ColorRamp.of(seed.colorInfo, dark: dark);
    final link = ColorRamp.of(seed.colorLink ?? seed.colorInfo, dark: dark);

    final color = ColorTokens(
      dark: dark,
      primary: primary.base,
      primaryHover: primary.hover,
      primaryActive: primary.active,
      primaryBg: primary.bg,
      primaryBgHover: primary.bgHover,
      primaryBorder: primary.border,
      primaryText: primary.text,
      success: success.base,
      successBg: success.bg,
      successBorder: success.border,
      warning: warning.base,
      warningBg: warning.bg,
      warningBorder: warning.border,
      error: error.base,
      errorHover: error.hover,
      errorActive: error.active,
      errorBg: error.bg,
      errorBorder: error.border,
      info: info.base,
      infoBg: info.bg,
      link: link.base,
      linkHover: link.hover,
      linkActive: link.active,
      // Neutral text ramp (ant defaults: 0.88 / 0.65 / 0.45 / 0.25 light, 0.85…
      // dark).
      text: ColorEngine.alpha(textBase, dark ? 0.85 : 0.88),
      textSecondary: ColorEngine.alpha(textBase, 0.65),
      textTertiary: ColorEngine.alpha(textBase, 0.45),
      textQuaternary: ColorEngine.alpha(textBase, 0.25),
      // Neutral fill ramp (0.15/0.06/0.04/0.02 light; 0.18/0.12/0.08/0.04 dark).
      fill: ColorEngine.alpha(textBase, dark ? 0.18 : 0.15),
      fillSecondary: ColorEngine.alpha(textBase, dark ? 0.12 : 0.06),
      fillTertiary: ColorEngine.alpha(textBase, dark ? 0.08 : 0.04),
      fillQuaternary: ColorEngine.alpha(textBase, dark ? 0.04 : 0.02),
      // Surfaces. Light: layout darken(4), container/elevated base(0);
      // dark: elevated lighten(12), container(8), layout(0).
      bgLayout: ColorEngine.solid(bgBase, dark ? 0 : 4, dark: dark),
      bgContainer: ColorEngine.solid(bgBase, dark ? 8 : 0, dark: dark),
      bgElevated: ColorEngine.solid(bgBase, dark ? 12 : 0, dark: dark),
      bgSpotlight: dark ? ColorEngine.solid(bgBase, 26, dark: true) : ColorEngine.alpha(textBase, 0.85),
      mask: const Color(0x73000000),
      border: ColorEngine.solid(bgBase, dark ? 26 : 15, dark: dark),
      borderSecondary: ColorEngine.solid(bgBase, dark ? 19 : 6, dark: dark),
      textLightSolid: const Color(0xFFFFFFFF),
      white: const Color(0xFFFFFFFF),
      shadowBase: dark ? const Color(0x33FFFFFF) : const Color(0xFF000000),
    );

    final font = genFontSizes(seed.fontSize);
    final type = TypeTokens(
      fontFamily: seed.fontFamily,
      fontFamilyCode: seed.fontFamilyCode,
      fontSizeSM: font[0].size,
      fontSize: font[1].size,
      fontSizeLG: font[2].size,
      fontSizeXL: font[3].size,
      fontSizeHeading5: font[2].size,
      fontSizeHeading4: font[3].size,
      fontSizeHeading3: font[4].size,
      fontSizeHeading2: font[5].size,
      fontSizeHeading1: font[6].size,
      lineHeight: font[1].lineHeight,
      lineHeightSM: font[0].lineHeight,
      lineHeightLG: font[2].lineHeight,
    );

    final sizes = genSizes(seed.sizeUnit, seed.sizeStep);
    final radii = genRadii(seed.borderRadius);
    final heights = genControlHeight(seed.controlHeight);
    final scale = ScaleTokens(
      sizes: sizes,
      radii: radii,
      controlHeight: seed.controlHeight,
      controlHeightLG: heights.lg,
      controlHeightSM: heights.sm,
      controlHeightXS: heights.xs,
    );

    final fast = _sec(seed.motionBase + seed.motionUnit);
    final motion = MotionTokens(
      durationFast: seed.motion ? fast : Duration.zero,
      durationMid: seed.motion ? _sec(seed.motionBase + seed.motionUnit * 2) : Duration.zero,
      durationSlow: seed.motion ? _sec(seed.motionBase + seed.motionUnit * 3) : Duration.zero,
      lineWidth: seed.lineWidth,
      lineWidthBold: seed.lineWidth + 1,
      lineWidthFocus: seed.focusOutline ? seed.lineWidth * 3 : 0,
      opacityLoading: 0.65,
      zIndexBase: seed.zIndexBase,
      zIndexPopupBase: seed.zIndexPopupBase,
      boxShadow: _shadows(color.shadowBase, 0.08, 0.12, 0.05),
      boxShadowTertiary: _shadows(color.shadowBase, 0.05, 0.03, 0.03),
    );

    return DesignToken(seed: seed, color: color, type: type, scale: scale, motion: motion, isDark: dark);
  }

  /// The seed this token was derived from (kept for nested override merges).
  final SeedToken seed;

  /// The colour roles.
  final ColorTokens color;

  /// The typography scale.
  final TypeTokens type;

  /// The spacing / radius / control-size scale.
  final ScaleTokens scale;

  /// Motion, borders, elevation and stacking.
  final MotionTokens motion;

  /// Whether this token set is the dark variant.
  final bool isDark;

  static Duration _sec(double seconds) => Duration(milliseconds: (seconds * 1000).round());

  static List<BoxShadow> _shadows(Color tint, double a1, double a2, double a3) => [
    BoxShadow(
      color: tint.withValues(alpha: a1),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
    BoxShadow(
      color: tint.withValues(alpha: a2),
      blurRadius: 6,
      offset: const Offset(0, 3),
      spreadRadius: -4,
    ),
    BoxShadow(
      color: tint.withValues(alpha: a3),
      blurRadius: 28,
      offset: const Offset(0, 9),
      spreadRadius: 8,
    ),
  ];
}

/// The colour roles (a `ColorMapToken` + `AliasToken` subset): brand ramps plus
/// the neutral text/fill/background ramps and the semantic aliases components
/// actually reference.
@immutable
final class ColorTokens {
  /// Colour tokens; produced by [DesignToken.derive].
  const new({
    required this.dark,
    required this.primary,
    required this.primaryHover,
    required this.primaryActive,
    required this.primaryBg,
    required this.primaryBgHover,
    required this.primaryBorder,
    required this.primaryText,
    required this.success,
    required this.successBg,
    required this.successBorder,
    required this.warning,
    required this.warningBg,
    required this.warningBorder,
    required this.error,
    required this.errorHover,
    required this.errorActive,
    required this.errorBg,
    required this.errorBorder,
    required this.info,
    required this.infoBg,
    required this.link,
    required this.linkHover,
    required this.linkActive,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.textQuaternary,
    required this.fill,
    required this.fillSecondary,
    required this.fillTertiary,
    required this.fillQuaternary,
    required this.bgLayout,
    required this.bgContainer,
    required this.bgElevated,
    required this.bgSpotlight,
    required this.mask,
    required this.border,
    required this.borderSecondary,
    required this.textLightSolid,
    required this.white,
    required this.shadowBase,
  });

  /// Whether this is the dark variant.
  final bool dark;

  /// The primary base colour (level 6).
  final Color primary;

  /// Primary hover (level 5).
  final Color primaryHover;

  /// Primary active (level 7).
  final Color primaryActive;

  /// Primary background tint (level 1).
  final Color primaryBg;

  /// Primary background hover tint (level 2).
  final Color primaryBgHover;

  /// Primary border (level 3).
  final Color primaryBorder;

  /// Primary as text (level 9).
  final Color primaryText;

  /// The success colour.
  final Color success;

  /// The success background.
  final Color successBg;

  /// The success border.
  final Color successBorder;

  /// The warning colour.
  final Color warning;

  /// The warning background.
  final Color warningBg;

  /// The warning border.
  final Color warningBorder;

  /// The error colour.
  final Color error;

  /// The error colour on hover.
  final Color errorHover;

  /// The error colour when active.
  final Color errorActive;

  /// The error background.
  final Color errorBg;

  /// The error border.
  final Color errorBorder;

  /// The info colour.
  final Color info;

  /// The info background.
  final Color infoBg;

  /// The link colour.
  final Color link;

  /// The link colour on hover.
  final Color linkHover;

  /// The link colour when active.
  final Color linkActive;

  /// The primary text colour.
  final Color text;

  /// The secondary text colour.
  final Color textSecondary;

  /// The tertiary text colour.
  final Color textTertiary;

  /// The quaternary (disabled) text colour.
  final Color textQuaternary;

  /// The primary fill (translucent overlay).
  final Color fill;

  /// The secondary fill.
  final Color fillSecondary;

  /// The tertiary fill.
  final Color fillTertiary;

  /// The quaternary fill.
  final Color fillQuaternary;

  /// The layout background behind pages.
  final Color bgLayout;

  /// The container background of cards and fields.
  final Color bgContainer;

  /// The elevated background of popovers, dropdowns and modals.
  final Color bgElevated;

  /// The tooltip / spotlight background.
  final Color bgSpotlight;

  /// The modal scrim.
  final Color mask;

  /// The primary border colour.
  final Color border;

  /// The secondary border colour.
  final Color borderSecondary;

  /// Text drawn on a solid brand fill (button labels).
  final Color textLightSolid;

  /// Pure white, for use on solid dark fills.
  final Color white;

  /// The tint drop shadows are drawn in.
  final Color shadowBase;

  /// `colorTextPlaceholder` / `colorTextDisabled`.
  Color get textDisabled => textQuaternary;

  /// `colorTextPlaceholder`.
  Color get textPlaceholder => textQuaternary;

  /// `colorFillContent`: the hover fill of a list item or ghost button.
  Color get fillContent => fillSecondary;

  /// `colorFillAlter`: a subtle zebra / header fill.
  Color get fillAlter => fillQuaternary;

  /// `colorBgContainerDisabled`.
  Color get bgContainerDisabled => fillTertiary;

  /// `colorBgTextHover` / `colorBgTextActive` for hoverable text controls.
  Color get bgTextHover => fillSecondary;

  /// `colorBgTextActive`.
  Color get bgTextActive => fill;

  /// `colorIcon` / `colorIconHover`.
  Color get icon => textTertiary;

  /// `colorIconHover`.
  Color get iconHover => text;

  /// `colorSplit`: the hairline divider, border colour softened over a container.
  Color get split => borderSecondary.withValues(alpha: 0.6);

  /// `colorText`: the high-emphasis text role.
  Color get textPrimary => text;

  /// The default text-on-surface role.
  Color get onSurface => text;

  /// The page background role (`colorBgLayout`).
  Color get surface => bgLayout;

  /// The raised surface role (`colorBgElevated`).
  Color get surfaceElevated => bgElevated;

  /// The secondary surface role (a soft fill).
  Color get surfaceVariant => fillSecondary;

  /// Text drawn on a solid brand fill (`colorTextLightSolid`).
  Color get onPrimary => textLightSolid;

  /// The modal dim layer (`colorBgMask`).
  Color get scrim => mask;

  /// A secondary accent role for informational status (maps to `info`).
  Color get secondary => info;

  /// The separator line (`colorSplit`).
  Color get divider => split;
}

/// The typography roles derived from `genFontMapToken`.
@immutable
final class TypeTokens {
  /// Type tokens.
  const new({
    required this.fontFamily,
    required this.fontFamilyCode,
    required this.fontSizeSM,
    required this.fontSize,
    required this.fontSizeLG,
    required this.fontSizeXL,
    required this.fontSizeHeading1,
    required this.fontSizeHeading2,
    required this.fontSizeHeading3,
    required this.fontSizeHeading4,
    required this.fontSizeHeading5,
    required this.lineHeight,
    required this.lineHeightSM,
    required this.lineHeightLG,
  });

  /// The default UI font family.
  final String? fontFamily;

  /// The code font family.
  final String? fontFamilyCode;

  /// The small body size.
  final double fontSizeSM;

  /// The base body size.
  final double fontSize;

  /// The large body size.
  final double fontSizeLG;

  /// The extra-large body size.
  final double fontSizeXL;

  /// Heading level 1 size.
  final double fontSizeHeading1;

  /// Heading level 2 size.
  final double fontSizeHeading2;

  /// Heading level 3 size.
  final double fontSizeHeading3;

  /// Heading level 4 size.
  final double fontSizeHeading4;

  /// Heading level 5 size.
  final double fontSizeHeading5;

  /// The base line height (unitless multiple).
  final double lineHeight;

  /// The small line height.
  final double lineHeightSM;

  /// The large line height.
  final double lineHeightLG;
}

/// The spacing, radius and control-height scale.
@immutable
final class ScaleTokens {
  /// Scale tokens.
  const new({
    required this.sizes,
    required this.radii,
    required this.controlHeight,
    required this.controlHeightLG,
    required this.controlHeightSM,
    required this.controlHeightXS,
  });

  /// The size (padding/margin) scale.
  final DesignSizes sizes;

  /// The corner-radius scale.
  final DesignRadii radii;

  /// The base control height.
  final double controlHeight;

  /// The large control height.
  final double controlHeightLG;

  /// The small control height.
  final double controlHeightSM;

  /// The extra-small control height.
  final double controlHeightXS;

  /// `controlPaddingHorizontal` and its small variant.
  double get controlPaddingHorizontal => sizes.md;

  /// `controlPaddingHorizontalSM`.
  double get controlPaddingHorizontalSM => sizes.sm;
}

/// Motion, line, opacity, stacking and elevation tokens.
@immutable
final class MotionTokens {
  /// Motion tokens.
  const new({
    required this.durationFast,
    required this.durationMid,
    required this.durationSlow,
    required this.lineWidth,
    required this.lineWidthBold,
    required this.lineWidthFocus,
    required this.opacityLoading,
    required this.zIndexBase,
    required this.zIndexPopupBase,
    required this.boxShadow,
    required this.boxShadowTertiary,
  });

  /// The fast transition duration.
  final Duration durationFast;

  /// The medium transition duration.
  final Duration durationMid;

  /// The slow transition duration.
  final Duration durationSlow;

  /// The base line width.
  final double lineWidth;

  /// The bold line width.
  final double lineWidthBold;

  /// The focus ring line width.
  final double lineWidthFocus;

  /// The opacity of a loading control.
  final double opacityLoading;

  /// The base stacking level.
  final double zIndexBase;

  /// The popup stacking level.
  final double zIndexPopupBase;

  /// The elevation shadow list.
  final List<BoxShadow> boxShadow;

  /// The lighter tertiary shadow list.
  final List<BoxShadow> boxShadowTertiary;
}
