import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'style.freezed.dart';

/// The interaction states a [Style] can react to.
///
/// Mirrors the CSS pseudo-classes a component cares about (`:hover`,
/// `:active`, `:focus-visible`, `[disabled]`); a recipe maps each of these
/// to a style delta and the widget feeds in whichever state is live.
enum InteractionState {
  /// The resting state.
  normal,

  /// A pointer is over the control.
  hovered,

  /// The control is being pressed.
  pressed,

  /// The control holds keyboard or remote focus.
  focused,

  /// The control does not accept input.
  disabled,
}

/// A mergeable bag of paint properties — live_uikit's version of one CSS
/// rule block.
///
/// Every field is nullable and a null means *unset*, which is what makes
/// [merge] behave like the CSS cascade: a later style overrides only the
/// properties it actually names, and everything else falls through to the
/// earlier one. A component's look is therefore resolved as
/// `languageBase ⊕ recipe(variant, size, state) ⊕ userStyle` by merging,
/// never by branching on which design language is active.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class Style with _$Style {
  /// A style from its properties; omitted ones stay unset.
  const factory Style({
    /// Inner space, the CSS `padding`.
    EdgeInsetsGeometry? padding,

    /// Outer space, the CSS `margin`.
    EdgeInsetsGeometry? margin,

    /// The CSS `min-width`.
    double? minWidth,

    /// The CSS `min-height`, usually a control's tap-target height.
    double? minHeight,

    /// The CSS `max-width`.
    double? maxWidth,

    /// The fill colour, the CSS `background-color`.
    Color? background,

    /// The content colour, the CSS `color` (text and icons inherit it).
    Color? foreground,

    /// The border colour, the CSS `border-color`.
    Color? borderColor,

    /// The border width in logical pixels; 0 draws no border.
    double? borderWidth,

    /// The corner radii, the CSS `border-radius`.
    BorderRadius? borderRadius,

    /// The whole-surface opacity, the CSS `opacity` (0..1).
    double? opacity,

    /// The backdrop blur radius in logical pixels; null or 0 draws no blur.
    double? blur,

    /// The drop shadow, the CSS `box-shadow`.
    List<BoxShadow>? shadow,

    /// The CSS `font-size`, in logical pixels before the global scale.
    double? fontSize,

    /// The CSS `font-family`; the global configuration overrides it when set.
    String? fontFamily,

    /// The CSS `font-weight`.
    FontWeight? fontWeight,

    /// The CSS `letter-spacing`.
    double? letterSpacing,

    /// The CSS `line-height`, as a unitless multiple of the font size.
    double? lineHeight,

    /// How a non-text child is aligned inside the box, the flex `align-items`.
    AlignmentGeometry? alignment,

    /// The CSS `text-align`.
    TextAlign? textAlign,
  }) = _Style;

  const Style._();

  /// The empty style: names nothing, so merging it is a no-op.
  static const Style empty = Style();

  /// Whether this style names no properties.
  ///
  /// Compared against the empty style rather than against a hand-written list of
  /// fields, so adding a property here cannot silently leave this behind.
  bool get isEmpty => Style.empty == this;

  /// This style with [other] layered on top: every property [other] names
  /// wins, everything else is kept. This is the cascade — call it in
  /// increasing-precedence order (`base.merge(variant).merge(size)…`).
  ///
  /// Written field by field instead of through Freezed's `copyWith`: that
  /// generator tells "argument not passed" apart from "argument passed as null"
  /// (its `freezed` sentinel), so `copyWith(padding: null)` *clears* padding
  /// rather than leaving it alone — the exact opposite of what a null means in a
  /// [Style]. Hand-merging keeps "null means unset" true for the cascade.
  Style merge(Style? other) {
    if (other == null) {
      return this;
    }
    return Style(
      padding: other.padding ?? padding,
      margin: other.margin ?? margin,
      minWidth: other.minWidth ?? minWidth,
      minHeight: other.minHeight ?? minHeight,
      maxWidth: other.maxWidth ?? maxWidth,
      background: other.background ?? background,
      foreground: other.foreground ?? foreground,
      borderColor: other.borderColor ?? borderColor,
      borderWidth: other.borderWidth ?? borderWidth,
      borderRadius: other.borderRadius ?? borderRadius,
      opacity: other.opacity ?? opacity,
      blur: other.blur ?? blur,
      shadow: other.shadow ?? shadow,
      fontSize: other.fontSize ?? fontSize,
      fontFamily: other.fontFamily ?? fontFamily,
      fontWeight: other.fontWeight ?? fontWeight,
      letterSpacing: other.letterSpacing ?? letterSpacing,
      lineHeight: other.lineHeight ?? lineHeight,
      alignment: other.alignment ?? alignment,
      textAlign: other.textAlign ?? textAlign,
    );
  }

  /// Paints these properties onto [base]: only the ones this style names are
  /// applied, so a text role (`label`, `body`) keeps its own family and weight
  /// where a style stays silent. This is how a role becomes a concrete
  /// [TextStyle] once a component's resolved style is known.
  TextStyle applyText(TextStyle base) => base.copyWith(
    color: foreground ?? base.color,
    fontSize: fontSize ?? base.fontSize,
    fontFamily: fontFamily ?? base.fontFamily,
    fontWeight: fontWeight ?? base.fontWeight,
    letterSpacing: letterSpacing ?? base.letterSpacing,
    height: lineHeight ?? base.height,
  );

  /// The box decoration implied by the fill, border, radii and shadow; null
  /// when the style paints no box at all.
  BoxDecoration? toDecoration() {
    final hasBox =
        background != null ||
        borderRadius != null ||
        (borderColor != null && (borderWidth ?? 0) > 0) ||
        (shadow?.isNotEmpty ?? false);
    if (!hasBox) {
      return null;
    }
    final width = borderWidth ?? (borderColor == null ? 0 : 1);
    return BoxDecoration(
      color: background,
      borderRadius: borderRadius,
      boxShadow: shadow,
      border: width > 0 && borderColor != null ? Border.all(color: borderColor!, width: width) : null,
    );
  }
}
