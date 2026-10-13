// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'epg_source.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EpgSource _$EpgSourceFromJson(Map<String, dynamic> json) => _EpgSource(
  id: json['id'] as String,
  name: json['name'] as String,
  source: json['source'] as String,
  lastRefresh: json['lastRefresh'] == null ? null : DateTime.parse(json['lastRefresh'] as String),
  createdAt: json['createdAt'] == null ? null : DateTime.parse(json['createdAt'] as String),
  autoUpdate: json['autoUpdate'] as bool? ?? true,
);

Map<String, dynamic> _$EpgSourceToJson(_EpgSource instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'source': instance.source,
  'lastRefresh': instance.lastRefresh?.toIso8601String(),
  'createdAt': instance.createdAt?.toIso8601String(),
  'autoUpdate': instance.autoUpdate,
};
