// These value classes spell their class name in the constructor; the shorthand
// would read as a method declaration.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:live_sites/src/models/live_message_placement/live_message_placement.dart';
import 'package:meta/meta.dart';

/// Presentation of a locally composed danmaku; platform messages use the room's
/// danmaku settings.
@immutable
final class LiveMessageStyle {
  /// Creates a style.
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

  /// Font size.
  final double fontSize;

  /// Scrolling speed.
  final double baseSpeed;

  /// Font weight (100-900).
  final int fontWeight;

  /// Whether to draw an outline.
  final bool showStroke;

  /// Outline width.
  final double strokeWidth;

  /// Placement.
  final LiveMessagePlacement placement;

  /// Font family, or null for the default.
  final String? fontFamily;

  /// Italic.
  final bool italic;

  /// Opacity 0-1.
  final double opacity;

  /// Letter spacing.
  final double letterSpacing;

  /// Outline colour, ARGB.
  final int strokeColor;

  /// Whether to draw a shadow.
  final bool showShadow;

  /// Shadow colour, ARGB.
  final int shadowColor;

  /// Shadow blur.
  final double shadowBlur;

  /// Shadow offset.
  final double shadowOffset;

  /// How long a fixed (top or bottom) message stays, in milliseconds.
  final int fixedDurationMs;
}
