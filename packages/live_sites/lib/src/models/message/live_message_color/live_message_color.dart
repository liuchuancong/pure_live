// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_value/serializer.dart';
import 'package:meta/meta.dart';

// `white`/`numberToColor` read as factories but cannot be constructors:
// `white` is a shared constant instance, `numberToColor` normalizes
// platform-packed int colors before constructing.
// ignore_for_file: prefer_constructors_over_static_methods

/// An RGB color a platform attaches to a danmaku text or a sender name.
///
/// Hand-written, not built_value: the positional `const` constructor is the
/// ergonomics every danmaku codec already uses, and a three-int value needs
/// no builder. [serializer] carries it through the model layer's table.
@immutable
final class LiveMessageColor {
  /// Creates a LiveMessageColor with already-normalized fields.
  const LiveMessageColor(this.r, this.g, this.b);

  /// Deserializes a stored JSON record.
  factory LiveMessageColor.fromJson(Map<String, Object?> json) =>
      LiveMessageColor(json['r']! as int, json['g']! as int, json['b']! as int);

  /// Red, 0–255.
  final int r;

  /// Green, 0–255.
  final int g;

  /// Blue, 0–255.
  final int b;

  /// The plain white most platforms use as the default text color.
  static const LiveMessageColor white = LiveMessageColor(255, 255, 255);

  /// The stored JSON record.
  Map<String, Object?> toJson() => {'r': r, 'g': g, 'b': b};

  /// The serializer the model layer's table carries this type by.
  static Serializer<LiveMessageColor> get serializer => const _LiveMessageColorSerializer();

  /// Parses a platform's packed int color (`0xBBGGRR`/`0xAABBGGRR` layouts).
  ///
  /// 6-digit input is RGB; 8-digit input carries a leading alpha byte that
  /// is dropped — platforms send it, but danmaku text is opaque.
  static LiveMessageColor numberToColor(int intColor) {
    var digits = intColor.toRadixString(16);
    if (digits.length == 4) digits = '00$digits';
    if (digits.length == 6) {
      return LiveMessageColor(
        int.parse(digits.substring(0, 2), radix: 16),
        int.parse(digits.substring(2, 4), radix: 16),
        int.parse(digits.substring(4, 6), radix: 16),
      );
    }
    if (digits.length == 8) {
      return LiveMessageColor(
        int.parse(digits.substring(2, 4), radix: 16),
        int.parse(digits.substring(4, 6), radix: 16),
        int.parse(digits.substring(6, 8), radix: 16),
      );
    }
    return white;
  }

  @override
  bool operator ==(Object other) => other is LiveMessageColor && other.r == r && other.g == g && other.b == b;

  @override
  int get hashCode => Object.hash(r, g, b);

  @override
  String toString() => 'LiveMessageColor($r, $g, $b)';
}

/// Adapts the hand-written color to built_value's serializer table.
final class _LiveMessageColorSerializer implements StructuredSerializer<LiveMessageColor> {
  const _LiveMessageColorSerializer();

  @override
  Iterable<Object?> serialize(
    Serializers serializers,
    LiveMessageColor color, {
    FullType specifiedType = FullType.unspecified,
  }) => <Object?>['r', color.r, 'g', color.g, 'b', color.b];

  @override
  LiveMessageColor deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final parts = serialized as Iterable<Object?>;
    var r = 0;
    var g = 0;
    var b = 0;
    for (var i = 0; i < parts.length; i += 2) {
      switch (parts.elementAt(i)) {
        case 'r':
          r = parts.elementAt(i + 1)! as int;
        case 'g':
          g = parts.elementAt(i + 1)! as int;
        case 'b':
          b = parts.elementAt(i + 1)! as int;
      }
    }
    return LiveMessageColor(r, g, b);
  }

  @override
  Iterable<Type> get types => const <Type>[LiveMessageColor];

  @override
  String get wireName => 'LiveMessageColor';
}
