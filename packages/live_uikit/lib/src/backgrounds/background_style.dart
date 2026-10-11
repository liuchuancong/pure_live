import 'package:flutter/widgets.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'background_style.freezed.dart';

/// One page or surface background.
///
/// A closed set of treatments instead of a raw `BoxDecoration`: the point
/// is that pages never spell out gradients, scrims or blurs themselves, so
/// the platform policy (a TV build does not pay for backdrop filters, a
/// low-end phone gets a flat tint) has exactly one place to live —
/// `LiveBackgroundPresets`.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
sealed class LiveBackgroundStyle with _$LiveBackgroundStyle {
  /// A flat colour.
  const factory LiveBackgroundStyle.solid({
    /// The fill colour.
    required Color color,
  }) = LiveSolidBackground;

  /// A linear gradient, optionally darkened by a scrim so text stays
  /// readable over a bright end of the ramp.
  const factory LiveBackgroundStyle.gradient({
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
  }) = LiveGradientBackground;

  /// A cover image, optionally darkened and blurred, for room and IPTV
  /// pages behind the player.
  const factory LiveBackgroundStyle.image({
    /// The image to paint.
    required ImageProvider image,

    /// How the image fills the surface.
    @Default(BoxFit.cover) BoxFit fit,

    /// A translucent colour painted over the image; null paints none.
    Color? scrim,

    /// How strongly `scrim` is applied, 0..1.
    @Default(0.45) double scrimStrength,

    /// The blur radius over the image; 0 keeps it sharp. Presets set 0
    /// where the environment cannot afford a backdrop filter.
    @Default(0) double blurSigma,
  }) = LiveImageBackground;

  /// A frosted surface: a translucent fill over a blurred backdrop.
  ///
  /// The caller is responsible for a sensible [sigma] on platforms where
  /// blur is expensive; `LiveBackgroundPresets` already decides that from
  /// the environment.
  const factory LiveBackgroundStyle.glass({
    /// The translucent fill colour.
    required Color color,

    /// The backdrop blur radius.
    @Default(16) double sigma,

    /// An optional hairline border colour.
    Color? border,
  }) = LiveGlassBackground;

  /// A soft-embossed surface: two shadows, one light from the top-left and
  /// one dark from the bottom-right, over a flat base.
  const factory LiveBackgroundStyle.raised({
    /// The base fill.
    required Color base,

    /// The highlight colour (the light source).
    required Color light,

    /// The shadow colour.
    required Color dark,

    /// How far the surface appears to stand out.
    @Default(6) double depth,
  }) = LiveRaisedBackground;
}
