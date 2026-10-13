// These value classes spell their class name in the constructor; the shorthand
// would read as a method declaration.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:meta/meta.dart';

/// A danmaku colour.
@immutable
final class LiveMessageColor {
  /// Creates a colour from its channels (0-255).
  const LiveMessageColor(this.r, this.g, this.b);

  /// The colour of a platform's integer: `0xRRGGBB`, or `0xAARRGGBB` with the
  /// alpha ignored (negative 32-bit values included).
  factory LiveMessageColor.numberToColor(int value) =>
      LiveMessageColor((value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF);

  /// White, the default.
  static const LiveMessageColor white = LiveMessageColor(255, 255, 255);

  /// Red.
  final int r;

  /// Green.
  final int g;

  /// Blue.
  final int b;

  @override
  bool operator ==(Object other) => other is LiveMessageColor && other.r == r && other.g == g && other.b == b;

  @override
  int get hashCode => Object.hash(r, g, b);

  /// `#rrggbb`.
  @override
  String toString() =>
      '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}';
}
