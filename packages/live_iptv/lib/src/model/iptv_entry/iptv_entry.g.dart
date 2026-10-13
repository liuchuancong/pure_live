// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'iptv_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_IptvEntry _$IptvEntryFromJson(Map<String, dynamic> json) => _IptvEntry(
  name: json['name'] as String,
  url: json['url'] as String,
  group: json['group'] as String?,
  tvgId: json['tvgId'] as String?,
  tvgLogo: json['tvgLogo'] as String?,
  channelNumber: (json['channelNumber'] as num?)?.toInt(),
  headers:
      (json['headers'] as Map<String, dynamic>?)?.map((k, e) => MapEntry(k, e as String)) ?? const <String, String>{},
  alternatives: (json['alternatives'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const <String>[],
  catchupSource: json['catchupSource'] as String?,
  catchupMode: json['catchupMode'] as String?,
  catchupDays: json['catchupDays'] as String?,
);

Map<String, dynamic> _$IptvEntryToJson(_IptvEntry instance) => <String, dynamic>{
  'name': instance.name,
  'url': instance.url,
  'group': instance.group,
  'tvgId': instance.tvgId,
  'tvgLogo': instance.tvgLogo,
  'channelNumber': instance.channelNumber,
  'headers': instance.headers,
  'alternatives': instance.alternatives,
  'catchupSource': instance.catchupSource,
  'catchupMode': instance.catchupMode,
  'catchupDays': instance.catchupDays,
};
