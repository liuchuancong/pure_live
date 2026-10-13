// These value classes spell their class name in the constructor; the shorthand
// would read as a method declaration.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:meta/meta.dart';

/// The picture geometry a platform declares for a stream, before any frame is
/// decoded: the player lays the picture out by it and the decoded size wins once
/// known.
@immutable
final class LivePlayGeometry {
  /// Creates the declared geometry.
  const LivePlayGeometry({this.width, this.height});

  /// Picture width the platform declares, when it does.
  final int? width;

  /// Picture height the platform declares; see [width].
  final int? height;

  /// [width] over [height], when both are declared.
  double? get declaredAspectRatio {
    final w = width;
    final h = height;
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    return w / h;
  }

  @override
  String toString() => 'LivePlayGeometry($width, $height)';
}
