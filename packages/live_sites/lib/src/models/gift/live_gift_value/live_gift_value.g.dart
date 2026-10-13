// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_gift_value.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LiveGiftValue _$LiveGiftValueFromJson(Map<String, dynamic> json) => _LiveGiftValue(
  unit: $enumDecodeNullable(_$LiveGiftUnitEnumMap, json['unit']) ?? LiveGiftUnit.other,
  unitPrice: (json['unitPrice'] as num?)?.toDouble(),
  totalValue: (json['totalValue'] as num?)?.toDouble(),
);

Map<String, dynamic> _$LiveGiftValueToJson(_LiveGiftValue instance) => <String, dynamic>{
  'unit': _$LiveGiftUnitEnumMap[instance.unit]!,
  'unitPrice': instance.unitPrice,
  'totalValue': instance.totalValue,
};

const _$LiveGiftUnitEnumMap = {
  LiveGiftUnit.silver: 'silver',
  LiveGiftUnit.gold: 'gold',
  LiveGiftUnit.rmb: 'rmb',
  LiveGiftUnit.point: 'point',
  LiveGiftUnit.free: 'free',
  LiveGiftUnit.other: 'other',
};
