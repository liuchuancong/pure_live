import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'background_style.freezed.dart';

/// One page or surface background.
///
/// A closed set of treatments instead of a raw `BoxDecoration`: the point
/// is that pages never spell out gradients, scrims or blurs themselves, so
/// the platform policy (a TV build does not pay for backdrop filters, a
/// low-end phone gets a flat tint) has exactly one place to live — the
/// `PureTheme.canBlur` gate inside `PureBackground`, which folds the user's
/// `UiConfig.reduceTransparency` with the host-reported hardware capability.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
sealed class PureBackgroundStyle with _$PureBackgroundStyle {
  /// A flat colour.
  const factory PureBackgroundStyle.solid({
    /// The fill colour.
    required Color color,
  }) = PureSolidBackground;

  /// A linear gradient, optionally darkened by a scrim so text stays
  /// readable over a bright end of the ramp.
  const factory PureBackgroundStyle.gradient({
    /// The gradient's colours, in order.
    required List<Color> colors,

    /// Where the gradient starts.
    @Default(Alignment.topLeft) Alignment begin,

    /// Where the gradient ends.
    @Default(Alignment.bottomRight) Alignment end,

    /// Optional stop positions; must match `colors` in length when given.
    @Default(<double>[]) List<double> stops,

    /// A translucent colour painted over the gradient; null paints none.
    Color? scrim,

    /// How strongly `scrim` is applied, 0..1.
    @Default(0.3) double scrimStrength,
  }) = PureGradientBackground;

  /// A cover image, optionally darkened and blurred, for room and IPTV
  /// pages behind the player.
  const factory PureBackgroundStyle.image({
    /// The image to paint.
    required ImageProvider image,

    /// How the image fills the surface.
    @Default(BoxFit.cover) BoxFit fit,

    /// A translucent colour painted over the image; null paints none.
    Color? scrim,

    /// How strongly `scrim` is applied, 0..1.
    @Default(0.45) double scrimStrength,

    /// The blur radius over the image; 0 keeps it sharp. Ignored when the
    /// resolved theme reports a backdrop filter is not affordable.
    @Default(0) double blurSigma,
  }) = PureImageBackground;

  /// A frosted surface: a translucent fill over a blurred backdrop.
  ///
  /// [sigma] is a design choice; whether the backdrop filter is drawn at all is
  /// not — `PureBackground` drops it when `PureTheme.canBlur` is false and keeps
  /// the translucent fill.
  const factory PureBackgroundStyle.glass({
    /// The translucent fill colour.
    required Color color,

    /// The backdrop blur radius.
    @Default(16) double sigma,

    /// An optional hairline border colour.
    Color? border,
  }) = PureGlassBackground;

  /// A soft-embossed surface: two shadows, one light from the top-left and
  /// one dark from the bottom-right, over a flat base.
  const factory PureBackgroundStyle.raised({
    /// The base fill.
    required Color base,

    /// The highlight colour (the light source).
    required Color light,

    /// The shadow colour.
    required Color dark,

    /// How far the surface appears to stand out.
    @Default(6) double depth,
  }) = PureRaisedBackground;
}
