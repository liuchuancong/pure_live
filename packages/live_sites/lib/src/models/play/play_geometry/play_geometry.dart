import 'package:freezed_annotation/freezed_annotation.dart';

// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
part 'play_geometry.freezed.dart';

/// The resolution/frame-rate/bitrate a platform declared for a play line.
///
/// Declared, not probed: values stay null when the platform says nothing.
@freezed
abstract class PlayGeometry with _$PlayGeometry {
  /// Creates a PlayGeometry with already-normalized fields.
  const factory PlayGeometry({int? width, int? height, int? frameRate, int? bitrateKbps}) = _PlayGeometry;

  const PlayGeometry._();

  /// The declared aspect ratio, or null when width/height are missing or not
  /// positive.
  double? get declaredAspectRatio {
    final w = width;
    final h = height;
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    return w / h;
  }
}
