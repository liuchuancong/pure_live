// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_gift_value.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LiveGiftValue _$LiveGiftValueFromJson(Map<String, dynamic> json) =>
    _LiveGiftValue(
      unit:
          $enumDecodeNullable(_$LiveGiftUnitEnumMap, json['unit']) ??
          LiveGiftUnit.other,
      unitPrice: (json['unitPrice'] as num?)?.toDouble(),
      totalValue: (json['totalValue'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$LiveGiftValueToJson(_LiveGiftValue instance) =>
    <String, dynamic>{
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
  LiveGiftUnit.fen: 'fen',
  LiveGiftUnit.yuan: 'yuan',
  LiveGiftUnit.goldSeed: 'goldSeed',
  LiveGiftUnit.diamond: 'diamond',
  LiveGiftUnit.redBean: 'redBean',
  LiveGiftUnit.bits: 'bits',
  LiveGiftUnit.kicks: 'kicks',
  LiveGiftUnit.cheese: 'cheese',
  LiveGiftUnit.starBalloon: 'starBalloon',
  LiveGiftUnit.douyinCoin: 'douyinCoin',
  LiveGiftUnit.sixCoin: 'sixCoin',
  LiveGiftUnit.acCoin: 'acCoin',
  LiveGiftUnit.banana: 'banana',
  LiveGiftUnit.starCoin: 'starCoin',
  LiveGiftUnit.heart: 'heart',
  LiveGiftUnit.note: 'note',
};
