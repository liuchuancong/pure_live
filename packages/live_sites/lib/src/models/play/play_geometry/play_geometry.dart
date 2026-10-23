// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_value/built_value.dart';

part 'play_geometry.g.dart';

/// The resolution/frame-rate/bitrate a platform declared for a play line.
///
/// Declared, not probed: values stay null when the platform says nothing.
abstract class PlayGeometry implements Built<PlayGeometry, PlayGeometryBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory PlayGeometry([void Function(PlayGeometryBuilder)? updates]) = _$PlayGeometry;

  /// Creates a PlayGeometry with already-normalized fields.
  factory PlayGeometry.of({int? width, int? height, int? frameRate, int? bitrateKbps}) => PlayGeometry(
    (b) => b
      ..width = width
      ..height = height
      ..frameRate = frameRate
      ..bitrateKbps = bitrateKbps,
  );

  PlayGeometry._();

  /// The declared width, in pixels.
  int? get width;

  /// The declared height, in pixels.
  int? get height;

  /// The declared frame rate.
  int? get frameRate;

  /// The declared bitrate, kilobits per second.
  int? get bitrateKbps;

  /// The declared aspect ratio, or null when width/height are missing or not
  /// positive.
  double? get declaredAspectRatio {
    final w = width;
    final h = height;
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    return w / h;
  }
}
