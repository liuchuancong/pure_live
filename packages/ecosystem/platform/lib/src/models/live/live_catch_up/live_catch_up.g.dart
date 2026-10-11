// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_catch_up.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LiveCatchUp _$LiveCatchUpFromJson(Map<String, dynamic> json) => _LiveCatchUp(
  active: json['active'] as bool? ?? false,
  url: _text(json['url']),
  start: _seconds(json['start']),
  end: _seconds(json['end']),
  mode: _text(json['mode']),
  source: _text(json['source']),
  days: _number(json['days']),
  correctionHours: _number(json['correctionHours']),
);

Map<String, dynamic> _$LiveCatchUpToJson(_LiveCatchUp instance) => <String, dynamic>{
  'active': instance.active,
  'url': instance.url,
  'start': _seconds(instance.start),
  'end': _seconds(instance.end),
  'mode': instance.mode,
  'source': instance.source,
  'days': _number(instance.days),
  'correctionHours': _number(instance.correctionHours),
};
