// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'epg_programme.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EpgProgramme _$EpgProgrammeFromJson(Map<String, dynamic> json) => _EpgProgramme(
  channelId: json['channelId'] as String,
  start: DateTime.parse(json['start'] as String),
  stop: DateTime.parse(json['stop'] as String),
  sourceId: json['sourceId'] as String? ?? '',
  title: json['title'] as String? ?? '',
  subtitle: json['subtitle'] as String?,
  description: json['description'] as String?,
  category: json['category'] as String?,
  episodeNum: json['episodeNum'] as String?,
  catchupId: json['catchupId'] as String?,
);

Map<String, dynamic> _$EpgProgrammeToJson(_EpgProgramme instance) => <String, dynamic>{
  'channelId': instance.channelId,
  'start': instance.start.toIso8601String(),
  'stop': instance.stop.toIso8601String(),
  'sourceId': instance.sourceId,
  'title': instance.title,
  'subtitle': instance.subtitle,
  'description': instance.description,
  'category': instance.category,
  'episodeNum': instance.episodeNum,
  'catchupId': instance.catchupId,
};
