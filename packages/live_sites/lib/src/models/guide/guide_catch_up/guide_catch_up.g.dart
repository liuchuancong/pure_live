// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'guide_catch_up.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GuideCatchUp _$GuideCatchUpFromJson(Map<String, dynamic> json) => _GuideCatchUp(
  url: json['url'] as String?,
  active: json['active'] as bool? ?? false,
  start: (json['start'] as num?)?.toInt(),
  end: (json['end'] as num?)?.toInt(),
  mode: json['mode'] as String?,
  urlTemplate: json['urlTemplate'] as String?,
  windowDays: (json['windowDays'] as num?)?.toDouble(),
  correctionHours: (json['correctionHours'] as num?)?.toDouble(),
  catchupId: json['catchupId'] as String?,
);

Map<String, dynamic> _$GuideCatchUpToJson(_GuideCatchUp instance) => <String, dynamic>{
  'url': instance.url,
  'active': instance.active,
  'start': instance.start,
  'end': instance.end,
  'mode': instance.mode,
  'urlTemplate': instance.urlTemplate,
  'windowDays': instance.windowDays,
  'correctionHours': instance.correctionHours,
  'catchupId': instance.catchupId,
};
