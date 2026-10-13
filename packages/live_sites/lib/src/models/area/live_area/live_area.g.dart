// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_area.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LiveArea _$LiveAreaFromJson(Map<String, dynamic> json) => _LiveArea(
  platform: json['platform'] as String? ?? '',
  areaId: json['areaId'] as String? ?? '',
  areaName: json['areaName'] as String? ?? '',
  parentAreaId: json['parentAreaId'] as String?,
  parentAreaName: json['parentAreaName'] as String?,
  iconUrl: json['iconUrl'] as String?,
  shortName: json['shortName'] as String?,
  position: (json['position'] as num?)?.toInt(),
);

Map<String, dynamic> _$LiveAreaToJson(_LiveArea instance) => <String, dynamic>{
  'platform': instance.platform,
  'areaId': instance.areaId,
  'areaName': instance.areaName,
  'parentAreaId': instance.parentAreaId,
  'parentAreaName': instance.parentAreaName,
  'iconUrl': instance.iconUrl,
  'shortName': instance.shortName,
  'position': instance.position,
};
