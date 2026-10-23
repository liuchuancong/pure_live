// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/serializers.dart';

part 'live_gift_value.g.dart';

/// What a gift is worth, in the platform's own denomination.
///
/// [LiveGiftUnit.free] implies both prices are meaningless; otherwise a null
/// price means the platform did not say (never a fabricated zero).
abstract class LiveGiftValue implements Built<LiveGiftValue, LiveGiftValueBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory LiveGiftValue([void Function(LiveGiftValueBuilder)? updates]) = _$LiveGiftValue;

  /// Creates a LiveGiftValue with already-normalized fields.
  factory LiveGiftValue.of({LiveGiftUnit unit = LiveGiftUnit.other, double? unitPrice, double? totalValue}) =>
      LiveGiftValue(
        (b) => b
          ..unit = unit
          ..unitPrice = unitPrice
          ..totalValue = totalValue,
      );

  LiveGiftValue._();

  /// Deserializes a stored JSON record.
  factory LiveGiftValue.fromJson(Map<String, Object?> json) =>
      serializers.deserializeWith(LiveGiftValue.serializer, json)!;

  /// The serializer built_value registers in [serializers].
  static Serializer<LiveGiftValue> get serializer => _$liveGiftValueSerializer;

  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(LiveGiftValueBuilder b) => b..unit = LiveGiftUnit.other;

  /// The platform's own denomination.
  LiveGiftUnit get unit;

  /// What one piece costs, when the platform says so.
  double? get unitPrice;

  /// What the whole hit is worth, when the platform says so.
  double? get totalValue;
}
