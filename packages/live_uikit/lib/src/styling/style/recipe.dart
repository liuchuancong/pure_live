import 'package:flutter/widgets.dart';
import 'package:live_uikit/src/styling/style/style.dart';
import 'package:live_uikit/src/styling/tokens/component_token.dart';
import 'package:live_uikit/src/styling/tokens/design_token.dart';

/// The size steps a control can be drawn at.
enum ControlSize {
  /// A small control (dense toolbars, chips).
  sm,

  /// The default control.
  md,

  /// A large control (touch targets, TV).
  lg,
}

/// The semantic button kinds, mapped onto Ant's `type` (`primary` / `default` /
/// `text` / `link` / `danger`).
enum ButtonVariant {
  /// The single most important action on a view.
  primary,

  /// A supporting action on a bordered surface.
  secondary,

  /// A quiet action: label only, no fill.
  ghost,

  /// A destructive action.
  danger,
}

/// The Button's style recipe: base ⊕ variant ⊕ size ⊕ state — the CVA /
/// stitches pattern over the design + component tokens.
///
/// It reads only the resolved [DesignToken] and [ButtonComponentToken], never a
/// hardcoded colour or a language check, so the identical recipe paints an Ant
/// Material button, a compact one, or (once a component-token override is wired)
/// a fully custom one — the look is entirely data.
@immutable
final class ButtonRecipe {
  /// The button recipe.
  const new();

  /// Resolves the button style for a [variant], [size] and interaction [state].
  Style resolve(
    DesignToken token,
    ButtonComponentToken button, {
    required ButtonVariant variant,
    required ControlSize size,
    required InteractionState state,
  }) => _base(
    token,
    button,
  ).merge(_variant(button, variant)).merge(_size(token, button, size)).merge(_state(token, button, variant, state));

  Style _base(DesignToken token, ButtonComponentToken button) => Style(
    borderRadius: BorderRadius.circular(button.borderRadius),
    minHeight: button.controlHeight,
    padding: EdgeInsets.symmetric(horizontal: button.paddingInline),
    alignment: Alignment.center,
    fontWeight: button.fontWeight,
    fontFamily: token.type.fontFamily,
  );

  Style _variant(ButtonComponentToken b, ButtonVariant variant) => switch (variant) {
    ButtonVariant.primary => Style(background: b.primaryBg, foreground: b.onPrimary, shadow: b.shadow),
    ButtonVariant.secondary => Style(
      background: b.defaultBg,
      foreground: b.defaultText,
      borderColor: b.defaultBorder,
      borderWidth: 1,
    ),
    ButtonVariant.ghost => Style(foreground: b.ghostText),
    ButtonVariant.danger => Style(background: b.dangerBg, foreground: b.onPrimary),
  };

  Style _size(DesignToken t, ButtonComponentToken b, ControlSize size) => switch (size) {
    ControlSize.sm => Style(
      minHeight: b.controlHeightSM,
      fontSize: t.type.fontSizeSM,
      padding: EdgeInsets.symmetric(horizontal: b.paddingInline * 0.66),
    ),
    ControlSize.md => Style(minHeight: b.controlHeight, fontSize: t.type.fontSize),
    ControlSize.lg => Style(
      minHeight: b.controlHeightLG,
      fontSize: t.type.fontSizeLG,
      padding: EdgeInsets.symmetric(horizontal: b.paddingInline * 1.33),
    ),
  };

  Style _state(DesignToken t, ButtonComponentToken b, ButtonVariant variant, InteractionState state) {
    if (state == InteractionState.disabled) {
      return Style(opacity: b.opacityLoading);
    }
    return switch (state) {
      InteractionState.pressed => Style(
        background: switch (variant) {
          ButtonVariant.primary => b.primaryActiveBg,
          ButtonVariant.danger => b.dangerBg,
          ButtonVariant.secondary || ButtonVariant.ghost => null,
        },
      ),
      InteractionState.hovered => _hover(t, b, variant),
      InteractionState.focused => Style(borderColor: t.color.primary, borderWidth: t.motion.lineWidth),
      InteractionState.normal || InteractionState.disabled => Style.empty,
    };
  }

  Style _hover(DesignToken t, ButtonComponentToken b, ButtonVariant variant) => switch (variant) {
    ButtonVariant.primary => Style(background: b.primaryHoverBg),
    ButtonVariant.danger => Style(background: b.dangerHoverBg),
    ButtonVariant.secondary => Style(background: t.color.fillQuaternary, borderColor: t.color.primary),
    ButtonVariant.ghost => Style(background: t.color.bgTextHover),
  };
}
