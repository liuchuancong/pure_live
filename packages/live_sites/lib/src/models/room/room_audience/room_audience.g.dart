// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room_audience.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RoomAudience _$RoomAudienceFromJson(Map<String, dynamic> json) => _RoomAudience(
  popularity: const AudienceNumberConverter().fromJson(json['popularity']),
  onlineViewers: const AudienceNumberConverter().fromJson(json['onlineViewers']),
  totalViewers: const AudienceNumberConverter().fromJson(json['totalViewers']),
  primaryMetric: $enumDecodeNullable(_$LiveAudienceMetricTypeEnumMap, json['primaryMetric']),
);

Map<String, dynamic> _$RoomAudienceToJson(_RoomAudience instance) => <String, dynamic>{
  'popularity': const AudienceNumberConverter().toJson(instance.popularity),
  'onlineViewers': const AudienceNumberConverter().toJson(instance.onlineViewers),
  'totalViewers': const AudienceNumberConverter().toJson(instance.totalViewers),
  'primaryMetric': _$LiveAudienceMetricTypeEnumMap[instance.primaryMetric],
};

const _$LiveAudienceMetricTypeEnumMap = {
  LiveAudienceMetricType.popularity: 'popularity',
  LiveAudienceMetricType.onlineViewers: 'onlineViewers',
  LiveAudienceMetricType.totalViewers: 'totalViewers',
  LiveAudienceMetricType.followers: 'followers',
  LiveAudienceMetricType.unknown: 'unknown',
};
