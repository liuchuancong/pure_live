// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'live_audience.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LiveAudience _$LiveAudienceFromJson(Map<String, dynamic> json) => _LiveAudience(
  onlineViewers: _count(json['onlineViewers']),
  totalViewers: _count(json['totalViewers']),
  popularity: _count(json['popularity']),
  label: _label(json['label']),
  metric: json['metric'] == null ? LiveAudienceMetric.unknown : _metric(json['metric']),
);

Map<String, dynamic> _$LiveAudienceToJson(_LiveAudience instance) => <String, dynamic>{
  'onlineViewers': _count(instance.onlineViewers),
  'totalViewers': _count(instance.totalViewers),
  'popularity': _count(instance.popularity),
  'label': instance.label,
  'metric': _$LiveAudienceMetricEnumMap[instance.metric]!,
};

const _$LiveAudienceMetricEnumMap = {
  LiveAudienceMetric.onlineViewers: 'onlineViewers',
  LiveAudienceMetric.totalViewers: 'totalViewers',
  LiveAudienceMetric.popularity: 'popularity',
  LiveAudienceMetric.unknown: 'unknown',
};
