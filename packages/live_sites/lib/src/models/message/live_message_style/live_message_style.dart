// The named constructor spells its class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:live_sites/src/models/enums/live_message_placement.dart';
import 'package:meta/meta.dart';

/// Presentation of a locally composed danmaku message.
///
/// Platform messages keep the room-wide danmaku configuration; only
/// `isLocal` messages carry a style. Purely a UI-facing value object — it is
/// never persisted by this package, so it stays a hand-written immutable:
/// no builder, no serializer.
@immutable
final class LiveMessageStyle {
  /// Creates a LiveMessageStyle with already-normalized fields.
  const LiveMessageStyle({
    required this.fontSize,
    required this.baseSpeed,
    required this.fontWeight,
    required this.showStroke,
    required this.strokeWidth,
    this.placement = LiveMessagePlacement.scroll,
    this.fontFamily,
    this.italic = false,
    this.opacity = 1,
    this.letterSpacing = 0,
    this.strokeColor = 0xFF000000,
    this.showShadow = false,
    this.shadowColor = 0xFF000000,
    this.shadowBlur = 2,
    this.shadowOffset = 1,
    this.fixedDurationMs = 4000,
  });

  /// The text size, logical pixels.
  final double fontSize;

  /// The scroll speed baseline, logical pixels per second.
  final double baseSpeed;

  /// The text weight.
  final int fontWeight;

  /// Whether a stroke is drawn.
  final bool showStroke;

  /// The stroke width.
  final double strokeWidth;

  /// Where the message is placed.
  final LiveMessagePlacement placement;

  /// A specific face, when one was chosen.
  final String? fontFamily;

  /// Whether the text leans.
  final bool italic;

  /// The text opacity, 0–1.
  final double opacity;

  /// Letter spacing, logical pixels.
  final double letterSpacing;

  /// The stroke's color.
  final int strokeColor;

  /// Whether a shadow is drawn.
  final bool showShadow;

  /// The shadow's color.
  final int shadowColor;

  /// The shadow's blur radius.
  final double shadowBlur;

  /// The shadow's offset.
  final double shadowOffset;

  /// How long a fixed message stays, milliseconds.
  final int fixedDurationMs;

  @override
  bool operator ==(Object other) =>
      other is LiveMessageStyle &&
      other.fontSize == fontSize &&
      other.baseSpeed == baseSpeed &&
      other.fontWeight == fontWeight &&
      other.showStroke == showStroke &&
      other.strokeWidth == strokeWidth &&
      other.placement == placement &&
      other.fontFamily == fontFamily &&
      other.italic == italic &&
      other.opacity == opacity &&
      other.letterSpacing == letterSpacing &&
      other.strokeColor == strokeColor &&
      other.showShadow == showShadow &&
      other.shadowColor == shadowColor &&
      other.shadowBlur == shadowBlur &&
      other.shadowOffset == shadowOffset &&
      other.fixedDurationMs == fixedDurationMs;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    fontSize,
    baseSpeed,
    fontWeight,
    showStroke,
    strokeWidth,
    placement,
    fontFamily,
    italic,
    opacity,
    letterSpacing,
    strokeColor,
    showShadow,
    shadowColor,
    shadowBlur,
    shadowOffset,
    fixedDurationMs,
  ]);
}
