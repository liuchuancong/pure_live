// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:live_sites/src/models/serializers.dart';

part 'live_super_chat_price.g.dart';

/// A super chat's price: the platform's number, the currency, and the
/// pre-formatted display text.
///
/// [displayText] is what the platform itself shows ("￥50"); [amount] and
/// [currency] stay null when the platform only gives the text.
abstract class SuperChatPrice implements Built<SuperChatPrice, SuperChatPriceBuilder> {
  /// Builds from a builder [updates] callback — the codegen entry.
  factory SuperChatPrice([void Function(SuperChatPriceBuilder)? updates]) = _$SuperChatPrice;

  /// Creates a SuperChatPrice with already-normalized fields.
  factory SuperChatPrice.of({int? amount, String? currency, String displayText = ''}) => SuperChatPrice(
    (b) => b
      ..amount = amount
      ..currency = currency
      ..displayText = displayText,
  );

  SuperChatPrice._();

  /// Deserializes a stored JSON record.
  factory SuperChatPrice.fromJson(Map<String, Object?> json) =>
      serializers.deserializeWith(SuperChatPrice.serializer, json)!;

  /// The serializer built_value registers in [serializers].
  static Serializer<SuperChatPrice> get serializer => _$superChatPriceSerializer;

  @BuiltValueHook(initializeBuilder: true)
  static void _initialize(SuperChatPriceBuilder b) => b..displayText = '';

  /// The price as a number, when the platform gives one.
  int? get amount;

  /// The price's currency, when the platform gives one.
  String? get currency;

  /// The platform's own formatted price text.
  String get displayText;
}
