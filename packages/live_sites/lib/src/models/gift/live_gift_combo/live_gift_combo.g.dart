// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_gift_combo.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LiveGiftCombo _$LiveGiftComboFromJson(Map<String, dynamic> json) =>
    _LiveGiftCombo(
      comboKey: json['comboKey'] as String? ?? '',
      comboTotal: (json['comboTotal'] as num?)?.toInt(),
    );

Map<String, dynamic> _$LiveGiftComboToJson(_LiveGiftCombo instance) =>
    <String, dynamic>{
      'comboKey': instance.comboKey,
      'comboTotal': instance.comboTotal,
    };
