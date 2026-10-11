import 'package:flutter/widgets.dart';

/// The focus tokens: what focused looks like.
///
/// Focus *behaviour* lives in the focus infrastructure, but focus
/// *appearance* is design language: Material draws a ring, Fluent draws a
/// thinner border, Neumorphic lifts the surface, TV grows the whole card.
/// Every component therefore reads these tokens instead of drawing its own
/// interpretation of "focused", which is also why focus stays visible when
/// the user switches design language.
///
/// The scale is the one exception to per-language styling: it is a *sizing*
/// decision driven by viewing distance, so the environment's layout mode
/// picks it (TV grows, desktop does not).
@immutable
final class LiveFocusTokens {
  /// Focus appearance tokens.
  const new({
    this.ringWidth = defaultRingWidth,
    this.ringOffset = defaultRingOffset,
    this.ringRadius = LiveFocusTokens.defaultRingRadius,
    this.scale = 1,
    this.duration = const Duration(milliseconds: 150),
    this.showRing = true,
    this.liftElevation = LiveFocusTokens.defaultLiftElevation,
  });

  /// The default ring stroke width.
  static const double defaultRingWidth = 2;

  /// The default ring gap between the control and the stroke.
  static const double defaultRingOffset = 2;

  /// The default ring corner radius, for controls that do not say.
  static const double defaultRingRadius = 12;

  /// The default elevation a focused surface lifts to.
  static const double defaultLiftElevation = 8;

  /// The animated surface scale used for TV focus.
  static const double tvScale = 1.08;

  /// Stroke width of the focus ring; 0 draws none.
  final double ringWidth;

  /// Distance between the control's edge and the ring.
  final double ringOffset;

  /// Corner radius of the ring, when the control does not supply its own.
  final double ringRadius;

  /// How much a focused control grows; 1 keeps layout size.
  final double scale;

  /// How long focus appearance takes to settle.
  final Duration duration;

  /// Whether the ring is drawn; Neumorphic and some TV styles replace it
  /// with a lift and keep the ring off.
  final bool showRing;

  /// How far a focused surface lifts, in elevation levels.
  final double liftElevation;

  /// The tokens with some values replaced.
  LiveFocusTokens copyWith({
    double? ringWidth,
    double? ringOffset,
    double? ringRadius,
    double? scale,
    Duration? duration,
    bool? showRing,
    double? liftElevation,
  }) => LiveFocusTokens(
    ringWidth: ringWidth ?? this.ringWidth,
    ringOffset: ringOffset ?? this.ringOffset,
    ringRadius: ringRadius ?? this.ringRadius,
    scale: scale ?? this.scale,
    duration: duration ?? this.duration,
    showRing: showRing ?? this.showRing,
    liftElevation: liftElevation ?? this.liftElevation,
  );

  /// The tokens for a TV layout: a thick ring and a grow effect, both sized
  /// for a viewer three metres away.
  static const LiveFocusTokens tv = LiveFocusTokens(
    ringWidth: 3,
    ringOffset: 4,
    scale: tvScale,
    duration: Duration(milliseconds: 180),
    liftElevation: 16,
  );

  /// The tokens for a touch or pointer layout: a subtle ring, no scaling.
  static const LiveFocusTokens pointer = LiveFocusTokens();

  @override
  bool operator ==(Object other) =>
      other is LiveFocusTokens &&
      other.ringWidth == ringWidth &&
      other.ringOffset == ringOffset &&
      other.ringRadius == ringRadius &&
      other.scale == scale &&
      other.duration == duration &&
      other.showRing == showRing &&
      other.liftElevation == liftElevation;

  @override
  int get hashCode => Object.hash(ringWidth, ringOffset, ringRadius, scale, duration, showRing, liftElevation);
}
