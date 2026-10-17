import 'package:flutter/widgets.dart';

import 'package:pure_uikit/src/styling/tokens/design_token.dart';

/// The Button's component tokens — the Ant `ButtonComponentToken` idea: the
/// handful of values the button recipe paints with, each defaulting to a global
/// design token but independently overridable through `PureConfigProvider`
/// without touching any other component.
@immutable
final class ButtonComponentToken {
  /// A button token set.
  const new({
    required this.fontWeight,
    required this.borderRadius,
    required this.controlHeight,
    required this.controlHeightSM,
    required this.controlHeightLG,
    required this.paddingInline,
    required this.primaryBg,
    required this.primaryHoverBg,
    required this.primaryActiveBg,
    required this.onPrimary,
    required this.defaultBg,
    required this.defaultBorder,
    required this.defaultText,
    required this.dangerBg,
    required this.dangerHoverBg,
    required this.ghostText,
    required this.opacityLoading,
    required this.shadow,
  });

  /// Derives the button tokens from the global [token], the Ant default
  /// behaviour when a component is not explicitly overridden.
  factory of(DesignToken token) {
    final c = token.color;
    return ButtonComponentToken(
      fontWeight: FontWeight.w600,
      borderRadius: token.scale.radii.base,
      controlHeight: token.scale.controlHeight,
      controlHeightSM: token.scale.controlHeightSM,
      controlHeightLG: token.scale.controlHeightLG,
      paddingInline: token.scale.controlPaddingHorizontal,
      primaryBg: c.primary,
      primaryHoverBg: c.primaryHover,
      primaryActiveBg: c.primaryActive,
      onPrimary: c.textLightSolid,
      defaultBg: c.bgContainer,
      defaultBorder: c.border,
      defaultText: c.text,
      dangerBg: c.error,
      dangerHoverBg: c.errorHover,
      ghostText: c.primary,
      opacityLoading: token.motion.opacityLoading,
      shadow: const <BoxShadow>[],
    );
  }

  /// The label font weight.
  final FontWeight fontWeight;

  /// The control corner radius.
  final double borderRadius;

  /// The base control height.
  final double controlHeight;

  /// The small control height.
  final double controlHeightSM;

  /// The large control height.
  final double controlHeightLG;

  /// The horizontal padding of the label.
  final double paddingInline;

  /// The filled (primary) background.
  final Color primaryBg;

  /// The filled background on hover.
  final Color primaryHoverBg;

  /// The filled background when active.
  final Color primaryActiveBg;

  /// The label colour drawn on a filled brand background.
  final Color onPrimary;

  /// The outlined button surface.
  final Color defaultBg;

  /// The outlined button border.
  final Color defaultBorder;

  /// The outlined button text.
  final Color defaultText;

  /// The danger button background.
  final Color dangerBg;

  /// The danger background on hover.
  final Color dangerHoverBg;

  /// The ghost button's label colour.
  final Color ghostText;

  /// The opacity of a loading button.
  final double opacityLoading;

  /// The button's drop shadow (empty in Ant's default, a per-theme choice).
  final List<BoxShadow> shadow;

  /// The tokens with some fields replaced, for a provider-level override.
  ButtonComponentToken copyWith({
    FontWeight? fontWeight,
    double? borderRadius,
    double? controlHeight,
    double? controlHeightSM,
    double? controlHeightLG,
    double? paddingInline,
    Color? primaryBg,
    Color? primaryHoverBg,
    Color? primaryActiveBg,
    Color? onPrimary,
    Color? defaultBg,
    Color? defaultBorder,
    Color? defaultText,
    Color? dangerBg,
    Color? dangerHoverBg,
    Color? ghostText,
    double? opacityLoading,
    List<BoxShadow>? shadow,
  }) => ButtonComponentToken(
    fontWeight: fontWeight ?? this.fontWeight,
    borderRadius: borderRadius ?? this.borderRadius,
    controlHeight: controlHeight ?? this.controlHeight,
    controlHeightSM: controlHeightSM ?? this.controlHeightSM,
    controlHeightLG: controlHeightLG ?? this.controlHeightLG,
    paddingInline: paddingInline ?? this.paddingInline,
    primaryBg: primaryBg ?? this.primaryBg,
    primaryHoverBg: primaryHoverBg ?? this.primaryHoverBg,
    primaryActiveBg: primaryActiveBg ?? this.primaryActiveBg,
    onPrimary: onPrimary ?? this.onPrimary,
    defaultBg: defaultBg ?? this.defaultBg,
    defaultBorder: defaultBorder ?? this.defaultBorder,
    defaultText: defaultText ?? this.defaultText,
    dangerBg: dangerBg ?? this.dangerBg,
    dangerHoverBg: dangerHoverBg ?? this.dangerHoverBg,
    ghostText: ghostText ?? this.ghostText,
    opacityLoading: opacityLoading ?? this.opacityLoading,
    shadow: shadow ?? this.shadow,
  );
}

/// The Card's component tokens (Ant `CardComponentToken`).
@immutable
final class CardComponentToken {
  /// A card token set.
  const new({
    required this.background,
    required this.borderRadius,
    required this.padding,
    required this.borderColor,
    required this.shadow,
  });

  /// Derives the card tokens from the global [token].
  factory of(DesignToken token) => CardComponentToken(
    background: token.color.bgContainer,
    borderRadius: token.scale.radii.lg,
    padding: token.scale.sizes.md,
    borderColor: token.color.borderSecondary,
    shadow: token.isDark ? const <BoxShadow>[] : token.motion.boxShadowTertiary,
  );

  /// The card surface colour.
  final Color background;

  /// The card corner radius (`borderRadiusLG`).
  final double borderRadius;

  /// The inner padding.
  final double padding;

  /// The optional hairline border colour (used when `bordered`).
  final Color borderColor;

  /// The resting drop shadow.
  final List<BoxShadow> shadow;
}

/// The text input's component tokens (Ant `InputComponentToken`).
@immutable
final class InputComponentToken {
  /// An input token set.
  const new({
    required this.background,
    required this.borderColor,
    required this.hoverBorderColor,
    required this.focusBorderColor,
    required this.errorBorderColor,
    required this.placeholderColor,
    required this.textColor,
    required this.borderRadius,
    required this.paddingInline,
    required this.paddingBlock,
    required this.height,
  });

  /// Derives the input tokens from the global [token].
  factory of(DesignToken token) => InputComponentToken(
    background: token.color.bgContainer,
    borderColor: token.color.border,
    hoverBorderColor: token.color.primaryHover,
    focusBorderColor: token.color.primary,
    errorBorderColor: token.color.error,
    placeholderColor: token.color.textPlaceholder,
    textColor: token.color.text,
    borderRadius: token.scale.radii.base,
    paddingInline: token.scale.controlPaddingHorizontal,
    paddingBlock: token.scale.sizes.xs,
    height: token.scale.controlHeight,
  );

  /// The field surface colour.
  final Color background;

  /// The resting border colour.
  final Color borderColor;

  /// The hover border colour.
  final Color hoverBorderColor;

  /// The focused border colour.
  final Color focusBorderColor;

  /// The error border colour.
  final Color errorBorderColor;

  /// The placeholder colour.
  final Color placeholderColor;

  /// The text colour.
  final Color textColor;

  /// The field corner radius.
  final double borderRadius;

  /// The horizontal text padding.
  final double paddingInline;

  /// The vertical text padding.
  final double paddingBlock;

  /// The single-line control height.
  final double height;
}

/// The switch's component tokens (Ant `SwitchComponentToken`).
@immutable
final class SwitchComponentToken {
  /// A switch token set.
  const new({
    required this.checkedColor,
    required this.uncheckedColor,
    required this.handleColor,
    required this.disabledOpacity,
    required this.width,
    required this.height,
    required this.handleSize,
  });

  /// Derives the switch tokens from the global [token].
  factory of(DesignToken token) {
    final height = token.scale.controlHeightSM;
    return SwitchComponentToken(
      checkedColor: token.color.primary,
      uncheckedColor: token.color.textTertiary,
      handleColor: token.color.white,
      disabledOpacity: token.motion.opacityLoading,
      width: height * 2,
      height: height,
      handleSize: height - token.motion.lineWidth * 4,
    );
  }

  /// The track colour when on.
  final Color checkedColor;

  /// The track colour when off.
  final Color uncheckedColor;

  /// The knob colour.
  final Color handleColor;

  /// The opacity of a disabled switch.
  final double disabledOpacity;

  /// The track width.
  final double width;

  /// The track height.
  final double height;

  /// The knob diameter.
  final double handleSize;
}

/// The tabs' component tokens (Ant `TabsComponentToken`).
@immutable
final class TabsComponentToken {
  /// A tabs token set.
  const new({
    required this.itemColor,
    required this.itemSelectedColor,
    required this.itemHoverColor,
    required this.inkBarColor,
    required this.horizontalPadding,
    required this.verticalGap,
  });

  /// Derives the tabs tokens from the global [token].
  factory of(DesignToken token) => TabsComponentToken(
    itemColor: token.color.textSecondary,
    itemSelectedColor: token.color.primary,
    itemHoverColor: token.color.text,
    inkBarColor: token.color.primary,
    horizontalPadding: token.scale.sizes.md,
    verticalGap: token.scale.sizes.sm,
  );

  /// The resting tab-label colour.
  final Color itemColor;

  /// The selected tab-label colour.
  final Color itemSelectedColor;

  /// The hovered tab-label colour.
  final Color itemHoverColor;

  /// The active indicator bar colour.
  final Color inkBarColor;

  /// A tab's horizontal padding.
  final double horizontalPadding;

  /// The gap between the label and the ink bar.
  final double verticalGap;
}

/// The list row's component tokens (Ant `List`/`Collapse` row surface).
@immutable
final class ListTileComponentToken {
  /// A list-row token set.
  const new({
    required this.textPaddingVertical,
    required this.paddingHorizontal,
    required this.hoverBackground,
    required this.selectedBackground,
    required this.dividerColor,
    required this.gap,
  });

  /// Derives the list-row tokens from the global [token].
  factory of(DesignToken token) => ListTileComponentToken(
    textPaddingVertical: token.scale.sizes.sm,
    paddingHorizontal: token.scale.sizes.md,
    hoverBackground: token.color.bgTextHover,
    selectedBackground: token.color.primaryBg,
    dividerColor: token.color.split,
    gap: token.scale.sizes.sm,
  );

  /// The row's vertical padding.
  final double textPaddingVertical;

  /// The row's horizontal padding.
  final double paddingHorizontal;

  /// The hovered row background.
  final Color hoverBackground;

  /// The selected row background.
  final Color selectedBackground;

  /// The divider under each row.
  final Color dividerColor;

  /// The gap between a leading/avatar and the content.
  final double gap;
}

/// The checkbox's component tokens (Ant `CheckboxComponentToken`).
@immutable
final class CheckboxComponentToken {
  /// A checkbox token set.
  const new({
    required this.boxSize,
    required this.borderRadius,
    required this.boxBackground,
    required this.boxBorder,
    required this.checkedBackground,
    required this.checkedBorder,
    required this.checkedIcon,
    required this.hoverBorder,
    required this.disabledOpacity,
  });

  /// Derives the checkbox tokens from the global [token].
  factory of(DesignToken token) => CheckboxComponentToken(
    boxSize: token.scale.controlHeight * 0.5,
    borderRadius: token.scale.radii.xs,
    boxBackground: token.color.bgContainer,
    boxBorder: token.color.border,
    checkedBackground: token.color.primary,
    checkedBorder: token.color.primary,
    checkedIcon: token.color.textLightSolid,
    hoverBorder: token.color.primaryHover,
    disabledOpacity: token.motion.opacityLoading,
  );

  /// The box edge length.
  final double boxSize;

  /// The box corner radius.
  final double borderRadius;

  /// The unchecked surface.
  final Color boxBackground;

  /// The unchecked border.
  final Color boxBorder;

  /// The checked fill.
  final Color checkedBackground;

  /// The checked border.
  final Color checkedBorder;

  /// The tick colour.
  final Color checkedIcon;

  /// The border colour on hover.
  final Color hoverBorder;

  /// The opacity of a disabled box.
  final double disabledOpacity;
}

/// The slider's component tokens (Ant `SliderComponentToken`).
@immutable
final class SliderComponentToken {
  /// A slider token set.
  const new({
    required this.railHeight,
    required this.handleSize,
    required this.trackColor,
    required this.railColor,
    required this.handleColor,
    required this.handleBorderColor,
    required this.disabledOpacity,
  });

  /// Derives the slider tokens from the global [token].
  factory of(DesignToken token) => SliderComponentToken(
    railHeight: 4,
    handleSize: token.scale.controlHeightSM * 0.7,
    trackColor: token.color.primary,
    railColor: token.color.fillSecondary,
    handleColor: token.color.bgContainer,
    handleBorderColor: token.color.primary,
    disabledOpacity: token.motion.opacityLoading,
  );

  /// The rail thickness.
  final double railHeight;

  /// The handle diameter.
  final double handleSize;

  /// The filled (active) track colour.
  final Color trackColor;

  /// The unfilled (rail) track colour.
  final Color railColor;

  /// The handle fill colour.
  final Color handleColor;

  /// The handle border colour.
  final Color handleBorderColor;

  /// The opacity of a disabled slider.
  final double disabledOpacity;
}

/// The badge / tag's component tokens (Ant `Badge`/`Tag`).
@immutable
final class BadgeComponentToken {
  /// A badge token set.
  const new({
    required this.background,
    required this.foreground,
    required this.dotSize,
    required this.height,
    required this.offset,
    required this.fontSize,
    required this.paddingInline,
  });

  /// Derives the badge tokens from the global [token].
  factory of(DesignToken token) => BadgeComponentToken(
    background: token.color.error,
    foreground: token.color.textLightSolid,
    dotSize: token.scale.sizes.sm,
    height: token.type.fontSizeSM * 1.6,
    offset: token.scale.sizes.xxs,
    fontSize: token.type.fontSizeSM,
    paddingInline: token.scale.sizes.xs,
  );

  /// The standalone dot diameter.
  final double dotSize;

  /// The counted-pill height.
  final double height;

  /// The count text size.
  final double fontSize;

  /// The count text horizontal padding.
  final double paddingInline;

  /// The overlap offset of the badge beyond its anchor.
  final double offset;

  /// The badge fill colour.
  final Color background;

  /// The badge label colour.
  final Color foreground;
}

/// The select's component tokens (Ant `Select`), reusing the input surface.
@immutable
final class SelectComponentToken {
  /// A select token set.
  const new({
    required this.fieldBackground,
    required this.fieldBorder,
    required this.hoverBorder,
    required this.focusBorder,
    required this.borderRadius,
    required this.height,
    required this.paddingInline,
    required this.menuBackground,
    required this.itemHoverBackground,
    required this.itemSelectedBackground,
    required this.itemHeight,
  });

  /// Derives the select tokens from the global [token].
  factory of(DesignToken token) => SelectComponentToken(
    fieldBackground: token.color.bgContainer,
    fieldBorder: token.color.border,
    hoverBorder: token.color.primaryHover,
    focusBorder: token.color.primary,
    borderRadius: token.scale.radii.base,
    height: token.scale.controlHeight,
    paddingInline: token.scale.controlPaddingHorizontal,
    menuBackground: token.color.bgElevated,
    itemHoverBackground: token.color.bgTextHover,
    itemSelectedBackground: token.color.primaryBg,
    itemHeight: token.scale.controlHeightSM,
  );

  /// The closed field's surface colour.
  final Color fieldBackground;

  /// The closed field's border colour.
  final Color fieldBorder;

  /// The hover border colour.
  final Color hoverBorder;

  /// The focus border colour.
  final Color focusBorder;

  /// The field corner radius.
  final double borderRadius;

  /// The field height.
  final double height;

  /// The field inner horizontal padding.
  final double paddingInline;

  /// The popup list's background colour.
  final Color menuBackground;

  /// The popup item hover background.
  final Color itemHoverBackground;

  /// The popup item selected background.
  final Color itemSelectedBackground;

  /// The popup item height.
  final double itemHeight;
}
