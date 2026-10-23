// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_gift.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LiveGift _$LiveGiftFromJson(Map<String, dynamic> json) => _LiveGift(
  giftId: json['giftId'] as String? ?? '',
  name: json['name'] as String? ?? '',
  iconUrl: json['iconUrl'] as String?,
  kind:
      $enumDecodeNullable(_$LiveGiftKindEnumMap, json['kind']) ??
      LiveGiftKind.normal,
  count: (json['count'] as num?)?.toInt() ?? 1,
  value: json['value'] == null
      ? const LiveGiftValue()
      : LiveGiftValue.fromJson(json['value'] as Map<String, dynamic>),
  combo: json['combo'] == null
      ? const LiveGiftCombo()
      : LiveGiftCombo.fromJson(json['combo'] as Map<String, dynamic>),
  recipientName: json['recipientName'] as String? ?? '',
);

Map<String, dynamic> _$LiveGiftToJson(_LiveGift instance) => <String, dynamic>{
  'giftId': instance.giftId,
  'name': instance.name,
  'iconUrl': instance.iconUrl,
  'kind': _$LiveGiftKindEnumMap[instance.kind]!,
  'count': instance.count,
  'value': instance.value,
  'combo': instance.combo,
  'recipientName': instance.recipientName,
};

const _$LiveGiftKindEnumMap = {
  LiveGiftKind.normal: 'normal',
  LiveGiftKind.subscription: 'subscription',
  LiveGiftKind.tip: 'tip',
};
