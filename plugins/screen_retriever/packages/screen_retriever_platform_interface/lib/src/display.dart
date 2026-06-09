import 'dart:ui';

import 'package:json_annotation/json_annotation.dart';

part 'display.g.dart';

/// Description of a user display screen.
@JsonSerializable(
  converters: [_OffsetConverter(), _SizeConverter()],
)
class Display {
  const Display({
    required this.id,
    this.name,
    required this.size,
    this.visiblePosition,
    this.visibleSize,
    this.scaleFactor,
  });

  factory Display.fromJson(Map<String, dynamic> json) =>
      _$DisplayFromJson(json);

  /// Unique identifier associated with the display.
  final String id;

  /// The name of the display.
  final String? name;

  /// The size of the display in logical pixels.
  final Size size;

  /// The position of the display in logical pixels.
  final Offset? visiblePosition;

  /// The size of the display in logical pixels.
  final Size? visibleSize;

  /// The scale factor of the display.
  final num? scaleFactor;

  Map<String, dynamic> toJson() => _$DisplayToJson(this);
}

// Convert Offset to/from Map<Object?, Object?>
class _OffsetConverter extends JsonConverter<Offset, Map<Object?, Object?>> {
  const _OffsetConverter();

  @override
  Offset fromJson(json) {
    final map = json.cast<String, dynamic>();
    return Offset(map['dx'], map['dy']);
  }

  @override
  Map<String, dynamic> toJson(Offset object) =>
      {'dx': object.dx, 'dy': object.dy};
}

// Convert Size to/from Map<Object?, Object?>
class _SizeConverter extends JsonConverter<Size, Map<Object?, Object?>> {
  const _SizeConverter();

  @override
  Size fromJson(json) {
    final map = json.cast<String, dynamic>();
    return Size(map['width'], map['height']);
  }

  @override
  Map<String, dynamic> toJson(Size object) =>
      {'width': object.width, 'height': object.height};
}
