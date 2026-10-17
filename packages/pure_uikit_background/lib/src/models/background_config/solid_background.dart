part of 'background_config.dart';

/// A flat, single-color background.
@immutable
final class SolidBackground extends BackgroundConfig {
  /// Paints [color] across the whole area.
  const new({required this.color, super.overlay});

  /// The base fill color.
  final Color color;
}
