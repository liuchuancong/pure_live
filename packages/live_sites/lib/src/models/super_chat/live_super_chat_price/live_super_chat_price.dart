import 'package:freezed_annotation/freezed_annotation.dart';

// The named factories spell their class name; the `new` shorthand
// cannot carry per-constructor documentation.
// ignore_for_file: unnecessary_type_name_in_constructor
part 'live_super_chat_price.freezed.dart';
part 'live_super_chat_price.g.dart';

/// A super chat's price: the platform's number, the currency, and the
/// pre-formatted display text.
///
/// [displayText] is what the platform itself shows ("￥50"); [amount] and
/// [currency] stay null when the platform only gives the text.
@freezed
abstract class SuperChatPrice with _$SuperChatPrice {
  /// Creates a SuperChatPrice with already-normalized fields.
  const factory SuperChatPrice({int? amount, String? currency, @Default('') String displayText}) = _SuperChatPrice;

  /// Deserializes a stored JSON record.
  factory SuperChatPrice.fromJson(Map<String, Object?> json) => _$SuperChatPriceFromJson(json);
}
