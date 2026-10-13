// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_super_chat_price.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SuperChatPrice _$SuperChatPriceFromJson(Map<String, dynamic> json) => _SuperChatPrice(
  amount: (json['amount'] as num?)?.toInt(),
  currency: json['currency'] as String?,
  displayText: json['displayText'] as String? ?? '',
);

Map<String, dynamic> _$SuperChatPriceToJson(_SuperChatPrice instance) => <String, dynamic>{
  'amount': instance.amount,
  'currency': instance.currency,
  'displayText': instance.displayText,
};
